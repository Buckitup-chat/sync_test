-- Copy from https://github.com/electric-sql/electric/tree/main/examples/write-patterns/patterns/4-through-the-db
-- With changes for new table

create table if not exists users_synced (
    pub_key bytea primary key,
    name text not null,
    write_id uuid
);

create table if not exists users_local (
    pub_key bytea primary key,
    name text not null,

    changed_columns text[],
    is_deleted boolean not null default false,
    write_id uuid not null
);

create or replace view users as
  select
    coalesce(local.pub_key, synced.pub_key) as pub_key,
    case
      when 'name' = any(local.changed_columns)
        then local.name
        else synced.name
      end as name
  from users_synced as synced
  full outer join users_local as local
    on synced.pub_key = local.pub_key
    where local.pub_key is null or local.is_deleted = false;


create or replace function delete_local_on_synced_insert_and_update_trigger()
returns trigger as $$
begin
  delete from users_local
    where pub_key = new.pub_key
      and write_id is not null
      and write_id = new.write_id;
  return new;
end;
$$ language plpgsql;


create or replace function delete_local_on_synced_delete_trigger()
returns trigger as $$
begin
  delete from users_local where pub_key = old.pub_key;
  return old;
end;
$$ language plpgsql;

create or replace trigger delete_local_on_synced_insert
after insert or update on users_synced
for each row
execute function delete_local_on_synced_insert_and_update_trigger();

create or replace trigger delete_local_on_synced_delete
after delete on users_synced
for each row
execute function delete_local_on_synced_delete_trigger();

-- The local `changes` table for capturing and persisting a log
-- of local write operations that we want to sync to the server.
create table if not exists changes (
  id bigserial primary key,
  operation text not null,
  value jsonb not null,
  write_id uuid not null,
  transaction_id xid8 not null
);

-- The following `INSTEAD OF` triggers:
-- 1. allow the app code to write directly to the view
-- 2. to capture write operations and write change messages into the

-- The insert trigger
create or replace function users_insert_trigger()
returns trigger as $$
declare
  local_write_id uuid := gen_random_uuid();
begin
  if exists (select 1 from users_synced where pub_key = new.pub_key) then
    raise exception 'Cannot insert: pub_key already exists in the synced table';
  end if;
  if exists (select 1 from users_local where pub_key = new.pub_key) then
    raise exception 'Cannot insert: pub_key already exists in the local table';
  end if;

  -- Insert into the local table.
  insert into users_local (
    pub_key,
    name,
    changed_columns,
    write_id
  )
  values (
    new.pub_key,
    new.name,
    array['name'],
    local_write_id
  );

  -- Record the write operation in the change log.
  insert into changes (
    operation,
    value,
    write_id,
    transaction_id
  )
  values (
    'insert',
    jsonb_build_object(
      'pub_key', new.pub_key,
      'name', new.name
    ),
    local_write_id,
    pg_current_xact_id()
  );

  return new;
end;
$$ language plpgsql;

-- The update trigger
create or replace function users_update_trigger()
returns trigger as $$
declare
  synced users_synced%rowtype;
  local users_local%rowtype;
  changed_cols text[] := '{}';
  local_write_id uuid := gen_random_uuid();
begin
  -- Fetch the corresponding rows from the synced and local tables
  select * into synced from users_synced where pub_key = new.pub_key;
  select * into local from users_local where pub_key = new.pub_key;

  -- If the row is not present in the local table, insert it
  if not found then
    -- Compare each column with the synced table and add to changed_cols if different
    if new.name is distinct from synced.name then
      changed_cols := array_append(changed_cols, 'name');
    end if;

    insert into users_local (
      pub_key,      
      name,
      changed_columns,
      write_id
    )
    values (
      new.pub_key,
      new.name,
      changed_cols,
      local_write_id
    );

  -- Otherwise, if the row is already in the local table, update it and adjust
  -- the changed_columns
  else
    update users_local
      set
        name =
          case
            when new.name is distinct from synced.name
              then new.name
              else local.name
            end,
        -- Set the changed_columns to columes that have both been marked as changed
        -- and have values that have actually changed.
        changed_columns = (
          select array_agg(distinct col) from (
            select unnest(local.changed_columns) as col
            union
            select unnest(array['name']) as col
          ) as cols
          where (
            case
              when col = 'name'
                then coalesce(new.name, local.name) is distinct from synced.name
              end
          )
        ),
        write_id = local_write_id
      where pub_key = new.pub_key;
  end if;

  -- Record the update into the change log.
  insert into changes (
    operation,
    value,
    write_id,
    transaction_id
  )
  values (
    'update',
    jsonb_strip_nulls(
      jsonb_build_object(
        'pub_key', new.pub_key,
        'name', new.name
      )
    ),
    local_write_id,
    pg_current_xact_id()
  );

  return new;
end;
$$ language plpgsql;

-- The delete trigger
create or replace function users_delete_trigger()
returns trigger as $$
declare
  local_write_id uuid := gen_random_uuid();
begin
  -- Upsert a soft-deletion record in the local table.
  if exists (select 1 from users_local where pub_key = old.pub_key) then
    update users_local
    set
      is_deleted = true,
      write_id = local_write_id
    where pub_key = old.pub_key;
  else
    insert into users_local (
      pub_key,
      is_deleted,
      write_id
    )
    values (
      old.pub_key,
      true,
      local_write_id
    );
  end if;

  -- Record in the change log.
  insert into changes (
    operation,
    value,
    write_id,
    transaction_id
  )
  values (
    'delete',
    jsonb_build_object(
      'pub_key', old.pub_key
    ),
    local_write_id,
    pg_current_xact_id()
  );

  return old;
end;
$$ language plpgsql;

create or replace trigger users_insert
instead of insert on users
for each row
execute function users_insert_trigger();

create or replace trigger users_update
instead of update on users
for each row
execute function users_update_trigger();

create or replace trigger users_delete
instead of delete on users
for each row
execute function users_delete_trigger();

create or replace function changes_notify_trigger()
returns trigger as $$
begin
  notify changes;
  return new;
end;
$$ language plpgsql;

create or replace trigger changes_notify
after insert on changes
for each row
execute function changes_notify_trigger();