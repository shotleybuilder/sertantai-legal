/**
 * Tests for auth store (Issue #42)
 *
 * Covers:
 * - Token storage and retrieval from localStorage
 * - JWT decoding and expiry checking
 * - adminAuth.check() restores user from valid token
 * - adminAuth.check() clears expired token
 * - getAuthToken() returns raw token string
 */

import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { get } from 'svelte/store';
import { adminAuth, getAuthToken, isAdmin } from './auth';

/**
 * Build a minimal JWT with the given claims.
 * No signature verification needed — client only decodes payload.
 */
function buildJwt(claims: Record<string, unknown>): string {
	const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
	const payload = btoa(JSON.stringify(claims));
	const signature = 'test-signature';
	return `${header}.${payload}.${signature}`;
}

/** JWT that expires in 1 hour */
function validToken(overrides: Record<string, unknown> = {}) {
	return buildJwt({
		sub: 'user?id=uuid-123',
		email: 'test@example.com',
		name: 'Test User',
		role: 'admin',
		org_id: 'org-456',
		org_name: 'Test Org',
		exp: Math.floor(Date.now() / 1000) + 3600,
		...overrides
	});
}

/** JWT that expired 1 hour ago */
function expiredToken() {
	return buildJwt({
		sub: 'user?id=uuid-expired',
		email: 'expired@example.com',
		role: 'member',
		exp: Math.floor(Date.now() / 1000) - 3600
	});
}

describe('auth store', () => {
	beforeEach(() => {
		localStorage.clear();
		adminAuth.clear();
	});

	afterEach(() => {
		localStorage.clear();
		adminAuth.clear();
	});

	describe('setToken', () => {
		it('stores token in localStorage and sets user', () => {
			const token = validToken();
			const user = adminAuth.setToken(token);

			expect(user).not.toBeNull();
			expect(user!.id).toBe('uuid-123');
			expect(user!.email).toBe('test@example.com');
			expect(user!.name).toBe('Test User');
			expect(user!.role).toBe('admin');
			expect(user!.org_id).toBe('org-456');
			expect(localStorage.getItem('sertantai_token')).toBe(token);
		});

		it('rejects expired token', () => {
			const token = expiredToken();
			const user = adminAuth.setToken(token);

			expect(user).toBeNull();
			expect(localStorage.getItem('sertantai_token')).toBeNull();
		});

		it('updates the svelte store', () => {
			const token = validToken();
			adminAuth.setToken(token);

			const user = get(adminAuth);
			expect(user).not.toBeNull();
			expect(user!.email).toBe('test@example.com');
		});
	});

	describe('check', () => {
		it('restores user from valid token in localStorage', () => {
			const token = validToken();
			localStorage.setItem('sertantai_token', token);

			const user = adminAuth.check();

			expect(user).not.toBeNull();
			expect(user!.id).toBe('uuid-123');
			expect(get(adminAuth)).not.toBeNull();
		});

		it('clears expired token from localStorage', () => {
			const token = expiredToken();
			localStorage.setItem('sertantai_token', token);

			const user = adminAuth.check();

			expect(user).toBeNull();
			expect(localStorage.getItem('sertantai_token')).toBeNull();
			expect(get(adminAuth)).toBeNull();
		});

		it('returns null when no token exists', () => {
			const user = adminAuth.check();

			expect(user).toBeNull();
			expect(get(adminAuth)).toBeNull();
		});

		it('handles malformed token gracefully', () => {
			localStorage.setItem('sertantai_token', 'not-a-jwt');

			const user = adminAuth.check();

			expect(user).toBeNull();
		});
	});

	describe('clear', () => {
		it('removes token from localStorage and clears store', () => {
			adminAuth.setToken(validToken());
			expect(get(adminAuth)).not.toBeNull();

			adminAuth.clear();

			expect(get(adminAuth)).toBeNull();
			expect(localStorage.getItem('sertantai_token')).toBeNull();
		});
	});

	describe('getAuthToken', () => {
		it('returns token when set', () => {
			const token = validToken();
			adminAuth.setToken(token);

			expect(getAuthToken()).toBe(token);
		});

		it('returns null when no token', () => {
			expect(getAuthToken()).toBeNull();
		});

		it('returns raw token string (not decoded)', () => {
			const token = validToken();
			adminAuth.setToken(token);

			const result = getAuthToken();
			expect(result).toContain('.');
			expect(result!.split('.').length).toBe(3);
		});
	});

	describe('isAdmin', () => {
		it('returns true for admin role', () => {
			const token = validToken({ role: 'admin' });
			const user = adminAuth.setToken(token);
			expect(isAdmin(user)).toBe(true);
		});

		it('returns true for owner role', () => {
			const token = validToken({ role: 'owner' });
			const user = adminAuth.setToken(token);
			expect(isAdmin(user)).toBe(true);
		});

		it('returns false for member role', () => {
			const token = validToken({ role: 'member' });
			const user = adminAuth.setToken(token);
			expect(isAdmin(user)).toBe(false);
		});

		it('returns false for null user', () => {
			expect(isAdmin(null)).toBe(false);
		});
	});

	describe('sub field parsing', () => {
		it('strips user?id= prefix from sub claim', () => {
			const token = validToken({ sub: 'user?id=abc-def-123' });
			const user = adminAuth.setToken(token);
			expect(user!.id).toBe('abc-def-123');
		});

		it('handles plain UUID sub claim', () => {
			const token = validToken({ sub: 'abc-def-123' });
			const user = adminAuth.setToken(token);
			expect(user!.id).toBe('abc-def-123');
		});
	});
});
