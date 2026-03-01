/**
 * Test utilities for sertantai-auth dev/test endpoints.
 * These call the auth service directly to seed users and manage test state.
 *
 * sertantai-legal has no login form — auth is via GitHub OAuth through sertantai-auth.
 * For E2E tests, we seed a user via the auth dev endpoint and inject the JWT
 * directly into localStorage, bypassing the OAuth redirect flow.
 */

const AUTH_URL = process.env.AUTH_TEST_URL || 'http://localhost:4000';

// --- Types ---

export interface SeedUserOptions {
	email?: string;
	password?: string;
	role?: 'owner' | 'admin' | 'member' | 'viewer';
	name?: string;
	tier?: 'free' | 'standard' | 'premium';
}

export interface SeededUser {
	user_id: string;
	email: string;
	name?: string;
	org_id: string;
	org_name: string;
	role: string;
	token: string;
	password: string;
}

// --- Seed & Reset ---

/**
 * Create a test user via sertantai-auth's dev seed endpoint.
 * Returns full user details including a valid JWT token.
 */
export async function seedUser(opts: SeedUserOptions = {}): Promise<SeededUser> {
	const body = { ...opts };
	if (!body.email) {
		body.email = uniqueEmail('legal');
	}
	// Ensure unique org name/slug to avoid collisions in parallel test workers
	if (!body.name) {
		const rand = Math.random().toString(36).substring(2, 8);
		body.name = `Test User ${Date.now()}-${rand}`;
	}

	// Retry on 422 (org slug collision from sertantai-auth's System.unique_integer)
	for (let attempt = 0; attempt < 3; attempt++) {
		const response = await fetch(`${AUTH_URL}/dev/test/seed`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(body)
		});

		if (response.ok) {
			return response.json();
		}

		if (response.status === 422 && attempt < 2) {
			// Likely slug collision — retry with a fresh email
			body.email = uniqueEmail('legal');
			continue;
		}

		const text = await response.text();
		throw new Error(`Failed to seed user (${response.status}): ${text}`);
	}

	throw new Error('Failed to seed user after retries');
}

/**
 * Reset test state — clear emails, rate limiter, optionally delete users.
 */
export async function resetTestData(
	opts: { clear_emails?: boolean; delete_users_matching?: string } = {}
): Promise<void> {
	const response = await fetch(`${AUTH_URL}/dev/test/reset`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(opts)
	});

	if (!response.ok) {
		const text = await response.text();
		throw new Error(`Failed to reset test data (${response.status}): ${text}`);
	}
}

/**
 * Clear stored test emails for a specific address.
 */
export async function clearEmails(email?: string): Promise<void> {
	const url = email
		? `${AUTH_URL}/dev/test/emails?to=${encodeURIComponent(email)}`
		: `${AUTH_URL}/dev/test/emails`;
	const response = await fetch(url, { method: 'DELETE' });

	if (!response.ok) {
		const text = await response.text();
		throw new Error(`Failed to clear emails (${response.status}): ${text}`);
	}
}

// --- Unique Test Data ---

/**
 * Generate a unique email address for test isolation.
 */
export function uniqueEmail(prefix = 'test'): string {
	const ts = Date.now();
	const rand = Math.random().toString(36).substring(2, 6);
	return `${prefix}+${ts}-${rand}@test.sertantai.com`;
}
