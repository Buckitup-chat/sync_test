// Copy from https://github.com/electric-sql/electric/tree/main/examples/write-patterns/patterns/4-through-the-db
// With slight modifications

import { PGlite } from "@electric-sql/pglite";
import { type PGliteWithLive, live } from "@electric-sql/pglite/live";
import { electricSync } from "@electric-sql/pglite-sync";
import localSchema from "./schema.sql?raw";

const registry = new Map<string, Promise<PGliteWithLive>>();

export default async function loadPGlite(): Promise<PGliteWithLive> {
  let loadingPromise = registry.get("loadingPromise");

  if (loadingPromise === undefined) {
    loadingPromise = _loadPGlite();

    registry.set("loadingPromise", loadingPromise);
  }

  return loadingPromise as Promise<PGliteWithLive>;
}

async function _loadPGlite(): Promise<PGliteWithLive> {
  const pglite: PGliteWithLive = await PGlite.create("idb://my-pgdata", {
    extensions: {
      electric: electricSync(),
      live,
    },
  });

  await pglite.exec(localSchema);

  await pglite.electric.syncShapeToTable({
    shape: {
      url: window.location.origin + "/api/shapes/users",
      parser: {
        bytea: (value: string) => {
          const stringBytes = value.slice(2);
          return Uint8Array.from(
            {
              length: stringBytes.length / 2,
            },
            (n, r) => parseInt(stringBytes.substring(r * 2, (r + 1) * 2), 16)
          );
        },
      },
    },
    shapeKey: "users",
    table: "users_synced",
    primaryKey: ["pub_key"],
  });

  return pglite;
}
