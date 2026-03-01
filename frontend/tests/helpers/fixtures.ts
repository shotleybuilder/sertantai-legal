/**
 * Playwright test fixtures for sertantai-legal E2E tests.
 *
 * Since sertantai-legal uses GitHub OAuth (no login form), the fixtures
 * inject a JWT directly into localStorage to simulate an authenticated session.
 */
import { test as base, type Page } from '@playwright/test';
import { clearEmails, seedUser, type SeedUserOptions, type SeededUser } from './auth-test-utils';

const TOKEN_KEY = 'sertantai_token';

type LegalFixtures = {
	/** Seed a user and return their details. Cleans up test data after each test. */
	createUser: (opts?: SeedUserOptions) => Promise<SeededUser>;
	/** Seed a user, inject their JWT into localStorage, and navigate to /admin. */
	loginAsAdmin: (opts?: SeedUserOptions) => Promise<SeededUser>;
};

export const test = base.extend<LegalFixtures>({
	createUser: async ({}, use) => {
		const users: SeededUser[] = [];

		const fn = async (opts: SeedUserOptions = {}) => {
			const user = await seedUser(opts);
			users.push(user);
			return user;
		};

		await use(fn);

		// Cleanup: clear emails for seeded users
		for (const user of users) {
			await clearEmails(user.email).catch(() => {});
		}
	},

	loginAsAdmin: async ({ page, createUser }, use) => {
		const fn = async (opts: SeedUserOptions = {}) => {
			const user = await createUser({ role: 'admin', ...opts });
			await injectToken(page, user.token);
			return user;
		};

		await use(fn);
	}
});

export { expect } from '@playwright/test';

/**
 * Inject a JWT into localStorage and navigate to /admin.
 * This bypasses the GitHub OAuth flow for testing.
 */
async function injectToken(page: Page, token: string): Promise<void> {
	// Navigate to the app first so localStorage is on the correct origin
	await page.goto('/');
	await page.evaluate(
		([key, value]) => localStorage.setItem(key, value),
		[TOKEN_KEY, token] as const
	);
	await page.goto('/admin');
}
