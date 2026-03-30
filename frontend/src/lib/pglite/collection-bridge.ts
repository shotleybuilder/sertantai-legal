/**
 * collection-bridge.ts — Bridge PGLite live changes into TanStack DB Collections.
 *
 * Creates a CollectionConfig whose sync function:
 * 1. Subscribes to PGLite `live.changes()` for INSERT/UPDATE/DELETE events
 * 2. Maps PGLite change events to TanStack DB write operations
 * 3. Feeds them into the collection via begin/write/commit
 *
 * PGLite remains the storage layer (Electric syncs into it).
 * TanStack DB provides the reactive orchestration layer on top.
 */

import { createCollection, BasicIndex } from '@tanstack/db';
import type { CollectionConfig, ChangeMessage } from '@tanstack/db';
import type { PGLiteWithExtensions } from './client';
import type { Change, LiveChanges } from '@electric-sql/pglite/live';

export interface PGLiteCollectionOptions {
	/** PGLite instance with live extension */
	db: PGLiteWithExtensions;
	/** SQL query to execute (e.g. "SELECT id, name, ... FROM uk_lrt") */
	query: string;
	/** Unique collection ID */
	id: string;
	/** Primary key column name (default: 'id') */
	primaryKey?: string;
}

type Row = Record<string, unknown>;

/** PGLite internal fields injected by live.changes() */
const PGLITE_INTERNAL_FIELDS = new Set(['__op__', '__changed_columns__', '__after__']);

/**
 * Strip PGLite internal fields from a change row,
 * returning a clean value for TanStack DB.
 */
function stripInternalFields(row: Record<string, unknown>): Row {
	const clean: Row = {};
	for (const key of Object.keys(row)) {
		if (!PGLITE_INTERNAL_FIELDS.has(key)) {
			clean[key] = row[key];
		}
	}
	return clean;
}

/**
 * Build CollectionConfig options that sync from PGLite via live.changes().
 *
 * Returns config suitable for `createCollection(pgliteCollectionOptions(...))`.
 */
export function pgliteCollectionOptions(
	options: PGLiteCollectionOptions
): CollectionConfig<Row, string> {
	const { db, query, id, primaryKey = 'id' } = options;

	return {
		id,
		getKey: (item: Row) => item[primaryKey] as string,
		defaultIndexType: BasicIndex,
		autoIndex: 'eager' as const,
		sync: {
			sync: ({ begin, write, commit, markReady }) => {
				let destroyed = false;
				let liveChanges: LiveChanges<Row> | null = null;
				let changeCallback: ((changes: Array<Change<Row>>) => void) | null = null;

				(async () => {
					// Subscribe to live changes — returns initialChanges + subscribe
					const result = await db.live.changes<Row>(query, null, primaryKey);
					if (destroyed) return;

					liveChanges = result;

					// Initial load: all rows arrive as INSERT changes
					if (result.initialChanges.length > 0) {
						begin();
						for (const change of result.initialChanges) {
							const value = stripInternalFields(change);
							write({ type: 'insert', value } as Omit<ChangeMessage<Row, string>, 'key'>);
						}
						commit();
					}

					markReady();

					// Subscribe to subsequent changes (Electric → PGLite → here)
					changeCallback = (changes: Array<Change<Row>>) => {
						if (destroyed || changes.length === 0) return;

						begin();
						for (const change of changes) {
							const op = change.__op__;
							const value = stripInternalFields(change);

							if (op === 'INSERT') {
								write({ type: 'insert', value } as Omit<ChangeMessage<Row, string>, 'key'>);
							} else if (op === 'UPDATE') {
								write({ type: 'update', value } as Omit<ChangeMessage<Row, string>, 'key'>);
							} else if (op === 'DELETE') {
								write({ type: 'delete', key: value[primaryKey] as string });
							}
							// RESET is handled internally by PGLite — ignore
						}
						commit();
					};

					result.subscribe(changeCallback);
				})();

				// Cleanup function
				return () => {
					destroyed = true;
					if (liveChanges && changeCallback) {
						liveChanges.unsubscribe(changeCallback);
					}
				};
			},
			rowUpdateMode: 'full' as const
		}
	};
}

/**
 * Convenience: create a TanStack DB Collection backed by PGLite live changes.
 *
 * Usage:
 * ```ts
 * const collection = createPGLiteCollection({ db, query: SQL, id: 'my-collection' });
 * const adapter = createTanStackDBAdapter({ collection, columns: metadata });
 * ```
 */
export function createPGLiteCollection(options: PGLiteCollectionOptions) {
	return createCollection(pgliteCollectionOptions(options));
}
