/**
 * PGLite Live Query → Svelte Store
 *
 * Wraps PGLite's `live.incrementalQuery()` as Svelte readable stores.
 * When Electric syncs changes into the local PGLite table, the live query
 * detects the change and pushes only the diff to JavaScript — ideal for
 * large datasets like 19K uk_lrt records.
 */

import { readable, type Readable } from 'svelte/store';
import { getPglite } from './client';
import type { LiveQuery } from '@electric-sql/pglite/live';

/**
 * Create a Svelte readable store backed by a PGLite live incremental query.
 *
 * The store value is `T[]` (array of rows). It updates reactively whenever
 * the underlying PGLite table changes (via Electric sync or local writes).
 *
 * Uses `live.incrementalQuery()` which only transfers diffs to JS —
 * much more efficient than re-materializing 19K rows on each change.
 *
 * @param sql - SQL query string (e.g. `SELECT * FROM uk_lrt WHERE ...`)
 * @param params - Query parameters (e.g. `[2024]` for `$1`)
 * @param keyColumn - Column used for diff tracking (usually `'id'`)
 * @returns Svelte readable store of query results
 */
export function createLiveQuery<T>(
	sql: string,
	params: unknown[],
	keyColumn: string
): Readable<T[]> {
	return readable<T[]>([], (set) => {
		let liveQuery: LiveQuery<T> | null = null;
		let callback: ((res: { rows: T[] }) => void) | null = null;

		getPglite()
			.then(async (pg) => {
				const ret = await pg.live.incrementalQuery<T>({
					query: sql,
					params,
					key: keyColumn
				});

				// Set initial results
				set(ret.initialResults.rows);

				// Subscribe to updates
				callback = (res) => set(res.rows);
				ret.subscribe(callback);
				liveQuery = ret;
			})
			.catch((err) => {
				console.error('[PGLite Live] Query failed:', sql, err);
			});

		return () => {
			if (liveQuery && callback) {
				liveQuery.unsubscribe(callback);
			}
		};
	});
}

/**
 * Create a dynamic live query that can be replaced when filters change.
 *
 * Unlike `createLiveQuery` (which is static), this returns an object with
 * `store` (Svelte readable) and `update(sql, params)` / `destroy()` methods.
 * Used by the Browse page where SQL changes on each view switch.
 *
 * @param keyColumn - Column used for diff tracking (usually `'id'`)
 * @returns Object with `store`, `update(sql, params)`, and `destroy()`
 */
export function createDynamicLiveQuery<T>(keyColumn: string): {
	store: Readable<T[]>;
	update: (sql: string, params: unknown[]) => void;
	destroy: () => void;
} {
	let currentQuery: LiveQuery<T> | null = null;
	let currentCallback: ((res: { rows: T[] }) => void) | null = null;
	let setter: ((value: T[]) => void) | null = null;
	let pgReady: Promise<Awaited<ReturnType<typeof getPglite>>> | null = null;

	const store = readable<T[]>([], (set) => {
		setter = set;
		return () => {
			setter = null;
		};
	});

	function teardown() {
		if (currentQuery && currentCallback) {
			currentQuery.unsubscribe(currentCallback);
		}
		currentQuery = null;
		currentCallback = null;
	}

	async function update(sql: string, params: unknown[]) {
		teardown();

		if (!pgReady) {
			pgReady = getPglite();
		}

		try {
			const pg = await pgReady;
			const ret = await pg.live.incrementalQuery<T>({
				query: sql,
				params,
				key: keyColumn
			});

			if (setter) {
				setter(ret.initialResults.rows);
			}

			currentCallback = (res) => {
				if (setter) setter(res.rows);
			};
			ret.subscribe(currentCallback);
			currentQuery = ret;
		} catch (err) {
			console.error('[PGLite Live] Dynamic query failed:', sql, err);
		}
	}

	function destroy() {
		teardown();
	}

	return { store, update, destroy };
}

/**
 * Create a Svelte writable store backed by a one-shot PGLite query.
 *
 * Unlike `createLiveQuery`, this does NOT maintain a live subscription.
 * It runs the query once on creation and provides a `refresh()` function
 * to re-run it on demand. Ideal for large result sets (e.g. 19K admin rows)
 * where maintaining a live diff cache would use too much memory.
 *
 * @param sql - SQL query string
 * @param params - Query parameters
 * @returns Object with `store` (Readable<T[]>) and `refresh()` function
 */
export function createQueryStore<T>(
	sql: string,
	params: unknown[]
): { store: Readable<T[]>; refresh: () => void } {
	let setter: ((value: T[]) => void) | null = null;
	let pgReady: Promise<Awaited<ReturnType<typeof getPglite>>> | null = null;

	async function runQuery() {
		if (!pgReady) pgReady = getPglite();
		try {
			const pg = await pgReady;
			const result = await pg.query<T>(sql, params);
			if (setter) setter(result.rows);
		} catch (err) {
			console.error('[PGLite] Query failed:', sql, err);
		}
	}

	const store = readable<T[]>([], (set) => {
		setter = set;
		runQuery();
		return () => {
			setter = null;
		};
	});

	return { store, refresh: runQuery };
}

/**
 * Create a Svelte readable store for a single count query.
 *
 * Uses `live.query()` (simpler, re-runs full query on change — fine for
 * small result sets like a single COUNT row).
 *
 * @param sql - SQL query that returns a single `count` column
 * @param params - Query parameters
 * @returns Svelte readable store of the count value
 */
export function createLiveCount(sql: string, params: unknown[]): Readable<number> {
	return readable<number>(0, (set) => {
		let liveQuery: LiveQuery<{ count: number }> | null = null;
		let callback: ((res: { rows: { count: number }[] }) => void) | null = null;

		getPglite()
			.then(async (pg) => {
				const ret = await pg.live.query<{ count: number }>(sql, params);

				set(ret.initialResults.rows[0]?.count ?? 0);

				callback = (res) => set(res.rows[0]?.count ?? 0);
				ret.subscribe(callback);
				liveQuery = ret;
			})
			.catch((err) => {
				console.error('[PGLite Live] Count query failed:', sql, err);
			});

		return () => {
			if (liveQuery && callback) {
				liveQuery.unsubscribe(callback);
			}
		};
	});
}
