// Copy from https://github.com/electric-sql/electric/tree/main/examples/write-patterns/patterns/4-through-the-db
// With slight modifications

import { type Operation } from "@electric-sql/client";
import type { PGliteWithLive } from "@electric-sql/pglite/live";

import { API_URL } from "./env";

type Change = {
  id: number;
  operation: Operation;
  value: {
    pub_key: string;
    name: string;
  };
  write_id: string;
  transaction_id: string;
};

type SendResult = "accepted" | "rejected" | "retry";

export default class ChangeLogSynchronizer {
  #db: PGliteWithLive;
  #position: number;

  #hasChangedWhileProcessing: boolean = false;
  #shouldContinue: boolean = true;
  #status: "idle" | "processing" = "idle";

  #abortController?: AbortController;
  #unsubscribe?: () => Promise<void>;

  constructor(db: PGliteWithLive, position = 0) {
    this.#db = db;
    this.#position = position;
  }

  async start(): Promise<void> {
    this.#abortController = new AbortController();
    this.#unsubscribe = await this.#db.listen(
      "changes",
      this.handle.bind(this)
    );

    this.process();
  }

  async handle(): Promise<void> {
    if (this.#status === "processing") {
      this.#hasChangedWhileProcessing = true;

      return;
    }

    this.#status = "processing";

    this.process();
  }

  async process(): Promise<void> {
    this.#hasChangedWhileProcessing = false;

    const { changes, position } = await this.query();

    if (changes.length) {
      const result: SendResult = await this.send(changes);

      switch (result) {
        case "accepted":
          await this.proceed(position);

          break;

        case "rejected":
          await this.rollback();

          break;

        case "retry":
          this.#hasChangedWhileProcessing = true;

          break;
      }
    }

    if (this.#hasChangedWhileProcessing && this.#shouldContinue) {
      await new Promise((resolve) => setTimeout(resolve, 1000));
      return await this.process();
    }

    this.#status = "idle";
  }

  async query(): Promise<{ changes: Change[]; position: number }> {
    const { rows } = await this.#db.sql<Change>`
      SELECT * from changes
        WHERE id > ${this.#position}
        ORDER BY id asc
    `;

    const position = rows.length ? rows.at(-1)!.id : this.#position;

    return {
      changes: rows,
      position,
    };
  }

  /*
   * Send the current batch of changes to the server, grouped by transaction.
   */
  async send(changes: Change[]): Promise<SendResult> {
    const groups: Record<string, Change[]> = {};

    for (const change of changes) {
      const key = change.transaction_id;
      if (!groups[key]) {
        groups[key] = [];
      }
      groups[key].push(change);
    }

    const sorted = Object.entries(groups).sort((a, b) =>
      a[0].localeCompare(b[0])
    );
    const transactions = sorted.map(([transaction_id, changes]) => {
      return {
        id: transaction_id,
        changes: changes,
      };
    });

    const signal = this.#abortController?.signal;

    let response: Response | undefined;
    try {
      response = await fetch(API_URL + "/ingest/mutations", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          mutations: transactions.map((transaction) => {
            return {
              type: transaction.changes[0].operation,
              modified: transaction.changes[0].value,
              syncMetadata: {
                relation: "users",
              },
            };
          }),
        }),
        signal,
      });
    } catch (_err) {
      return "retry";
    }

    if (response === undefined) {
      return "retry";
    }

    if (response.ok) {
      return "accepted";
    }

    return response.status < 500 ? "rejected" : "retry";
  }

  async proceed(position: number): Promise<void> {
    await this.#db.sql`
      DELETE from changes
        WHERE id <= ${position}
    `;

    this.#position = position;
  }

  async rollback(): Promise<void> {
    await this.#db.transaction(async (tx) => {
      await tx.sql`DELETE from changes`;
      await tx.sql`DELETE from users_local`;
    });
  }

  async stop(): Promise<void> {
    this.#shouldContinue = false;

    if (this.#abortController !== undefined) {
      this.#abortController.abort();
    }

    if (this.#unsubscribe !== undefined) {
      await this.#unsubscribe();
    }
  }
}
