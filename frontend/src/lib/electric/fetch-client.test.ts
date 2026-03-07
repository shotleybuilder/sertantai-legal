/**
 * Tests for Electric fetch client auth header injection (Issue #42)
 *
 * The electricFetchClient wraps fetch() to attach the JWT Authorization header
 * for Electric shape requests through the backend proxy.
 *
 * BUG (Issue #42): The fetch client reads the token from localStorage via
 * getAuthToken(). When a valid token exists in localStorage but the auth store
 * hasn't been initialized (adminAuth.check() not yet called), the token should
 * still be available — getAuthToken() reads localStorage directly.
 *
 * The REAL bug is timing: adminAuth.check() runs in parent onMount (which fires
 * AFTER child onMount in Svelte), so Electric sync starts before auth is initialized.
 * But we can't test Svelte mount order in a unit test — we test the fetch client
 * behavior and the auth store contract instead.
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { getAuthToken } from '$lib/stores/auth';
import { createElectricFetchClient } from './fetch-client';

// Mock global fetch
const mockFetch = vi.fn().mockResolvedValue(new Response('ok'));

/**
 * Build a minimal JWT with the given claims.
 */
function buildJwt(claims: Record<string, unknown>): string {
	const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
	const payload = btoa(JSON.stringify(claims));
	return `${header}.${payload}.test-sig`;
}

function validToken() {
	return buildJwt({
		sub: 'user?id=uuid-123',
		email: 'test@example.com',
		role: 'admin',
		exp: Math.floor(Date.now() / 1000) + 3600
	});
}

describe('createElectricFetchClient', () => {
	beforeEach(() => {
		localStorage.clear();
		mockFetch.mockClear();
	});

	afterEach(() => {
		localStorage.clear();
	});

	it('attaches Authorization header when token exists in localStorage', async () => {
		const token = validToken();
		localStorage.setItem('sertantai_token', token);

		const fetchClient = createElectricFetchClient(mockFetch);
		await fetchClient('https://example.com/v1/shape');

		expect(mockFetch).toHaveBeenCalledOnce();
		const [, init] = mockFetch.mock.calls[0];
		const headers = new Headers(init?.headers);
		expect(headers.get('Authorization')).toBe(`Bearer ${token}`);
	});

	it('does NOT attach Authorization header when no token exists', async () => {
		const fetchClient = createElectricFetchClient(mockFetch);
		await fetchClient('https://example.com/v1/shape');

		expect(mockFetch).toHaveBeenCalledOnce();
		const [, init] = mockFetch.mock.calls[0];
		const headers = new Headers(init?.headers);
		expect(headers.get('Authorization')).toBeNull();
	});

	it('does not overwrite existing Authorization header', async () => {
		localStorage.setItem('sertantai_token', validToken());

		const fetchClient = createElectricFetchClient(mockFetch);
		await fetchClient('https://example.com/v1/shape', {
			headers: { Authorization: 'Bearer existing-token' }
		});

		const [, init] = mockFetch.mock.calls[0];
		const headers = new Headers(init?.headers);
		expect(headers.get('Authorization')).toBe('Bearer existing-token');
	});

	it('passes through request URL unchanged', async () => {
		const url = 'https://legal.sertantai.com/api/electric/v1/shape?table=uk_lrt';
		const fetchClient = createElectricFetchClient(mockFetch);
		await fetchClient(url);

		expect(mockFetch.mock.calls[0][0]).toBe(url);
	});

	it('passes through other init options (method, body, etc.)', async () => {
		const fetchClient = createElectricFetchClient(mockFetch);
		await fetchClient('https://example.com', {
			method: 'POST',
			body: 'test-body'
		});

		const [, init] = mockFetch.mock.calls[0];
		expect(init.method).toBe('POST');
		expect(init.body).toBe('test-body');
	});

	it('reads token at call time, not at creation time', async () => {
		// Create client BEFORE token exists
		const fetchClient = createElectricFetchClient(mockFetch);

		// First call — no token
		await fetchClient('https://example.com/v1/shape');
		let headers = new Headers(mockFetch.mock.calls[0][1]?.headers);
		expect(headers.get('Authorization')).toBeNull();

		// Set token AFTER client was created
		localStorage.setItem('sertantai_token', validToken());

		// Second call — should pick up the new token
		await fetchClient('https://example.com/v1/shape');
		headers = new Headers(mockFetch.mock.calls[1][1]?.headers);
		expect(headers.get('Authorization')).not.toBeNull();
	});
});

describe('getAuthToken contract (for Electric fetch client)', () => {
	beforeEach(() => {
		localStorage.clear();
	});

	afterEach(() => {
		localStorage.clear();
	});

	it('reads directly from localStorage without requiring adminAuth.check()', () => {
		// This is the key contract: getAuthToken() must work even if
		// adminAuth.check() has not been called. It reads localStorage directly.
		const token = validToken();
		localStorage.setItem('sertantai_token', token);

		// Do NOT call adminAuth.check() — simulating the bug scenario
		// where child onMount fires before parent onMount
		const result = getAuthToken();
		expect(result).toBe(token);
	});

	it('returns null when localStorage is empty', () => {
		expect(getAuthToken()).toBeNull();
	});
});
