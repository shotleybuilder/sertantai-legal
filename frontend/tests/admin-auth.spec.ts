/**
 * Admin authentication E2E tests.
 *
 * Tests the auth gate on /admin pages:
 * - Unauthenticated users are redirected to hub login
 * - Authenticated admin users see the dashboard
 * - Non-admin users see the "access denied" message
 */
import { test, expect } from './helpers/fixtures';

// Matches VITE_HUB_URL from .env.development
const HUB_ORIGIN = 'http://localhost:5173';

test.describe('Admin auth gate', () => {
	test('redirects to hub login when not authenticated', async ({ page }) => {
		// Capture the redirect request to the hub
		const redirectRequest = page.waitForRequest((req) => req.url().startsWith(HUB_ORIGIN), {
			timeout: 10000
		});

		await page.goto('/admin');
		const req = await redirectRequest;

		expect(req.url()).toContain('/login?redirect=');
	});

	test('admin user sees the dashboard', async ({ page, loginAsAdmin }) => {
		const user = await loginAsAdmin();

		// Should see the navigation with admin links (use exact to avoid matching dashboard cards)
		await expect(page.getByRole('link', { name: 'SertantAI Legal' })).toBeVisible();
		await expect(page.getByRole('link', { name: 'LRT Data', exact: true })).toBeVisible();
		await expect(page.getByRole('link', { name: 'LAT Data', exact: true })).toBeVisible();

		// Should show role badge in the nav
		await expect(page.getByText(user.role, { exact: true })).toBeVisible();
	});

	test('non-admin user sees access denied', async ({ page, createUser }) => {
		const user = await createUser({ role: 'member' });

		// Inject the member token
		await page.goto('/');
		await page.evaluate(([key, value]) => localStorage.setItem(key, value), [
			'sertantai_token',
			user.token
		] as const);
		await page.goto('/admin');

		await expect(page.getByRole('heading', { name: 'Access Denied' })).toBeVisible();
		await expect(page.getByText('Your account does not have admin privileges')).toBeVisible();
	});

	test('sign out redirects to hub', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		// Verify we're on the admin page
		await expect(page.getByRole('link', { name: 'LRT Data', exact: true })).toBeVisible();

		// Token should exist before sign out
		const tokenBefore = await page.evaluate(() => localStorage.getItem('sertantai_token'));
		expect(tokenBefore).not.toBeNull();

		// Capture the redirect request to the hub
		const redirectRequest = page.waitForRequest((req) => req.url().startsWith(HUB_ORIGIN), {
			timeout: 10000
		});

		await page.getByRole('button', { name: 'Sign out' }).click();
		const req = await redirectRequest;

		expect(req.url()).toBe(`${HUB_ORIGIN}/`);
	});
});
