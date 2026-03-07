/**
 * Electric fetch client with JWT auth header injection.
 *
 * Wraps fetch() to attach the Authorization header from localStorage
 * for Electric shape requests through the backend proxy.
 *
 * Extracted from index.client.ts for testability (Issue #42).
 */

import { getAuthToken } from '$lib/stores/auth';

/**
 * Create an Electric fetch client that injects JWT auth headers.
 *
 * @param fetchFn - The underlying fetch function (defaults to global fetch).
 *                  Accepts a custom fetch for testing.
 */
export function createElectricFetchClient(
	fetchFn: typeof fetch = fetch
): (input: RequestInfo | URL, init?: RequestInit) => Promise<Response> {
	return (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
		const token = getAuthToken();
		const headers = new Headers(init?.headers);
		if (token && !headers.has('Authorization')) {
			headers.set('Authorization', `Bearer ${token}`);
		}
		return fetchFn(input, { ...init, headers });
	};
}

/**
 * Default Electric fetch client using global fetch.
 * Used by Electric shape streams in index.client.ts.
 */
export const electricFetchClient = createElectricFetchClient();
