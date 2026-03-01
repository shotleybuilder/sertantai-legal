/**
 * Authenticated fetch client for sertantai-legal API.
 *
 * Reads the JWT from localStorage and attaches it as a Bearer token
 * in the Authorization header.
 */

import { getAuthToken } from '$lib/stores/auth';

/**
 * Fetch wrapper that includes the JWT Authorization header.
 * Falls back to a regular fetch if no token is available.
 */
export async function authFetch(url: string, options: RequestInit = {}): Promise<Response> {
	const token = getAuthToken();
	const headers = new Headers(options.headers);

	if (token && !headers.has('Authorization')) {
		headers.set('Authorization', `Bearer ${token}`);
	}

	return fetch(url, { ...options, headers });
}
