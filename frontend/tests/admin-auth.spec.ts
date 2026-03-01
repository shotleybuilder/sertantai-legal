/**
 * Admin authentication E2E tests.
 *
 * Tests the auth gate on /admin pages:
 * - Unauthenticated users see "Not Signed In" with link to hub
 * - Authenticated admin users see the dashboard
 * - Authenticated owner users see the dashboard
 * - Non-admin users see "Access Denied" with link to browse
 * - Auth callback stores token and redirects to dest
 */
import { test, expect } from './helpers/fixtures';

// Matches VITE_HUB_URL from .env.development
const HUB_ORIGIN = 'http://localhost:5173';

test.describe('Admin auth gate', () => {
	test('shows not-signed-in page with hub link when no token', async ({ page }) => {
		await page.goto('/admin');

		await expect(page.getByRole('heading', { name: 'Not Signed In' })).toBeVisible();
		await expect(page.getByText('You need to sign in to access the admin area')).toBeVisible();

		const hubLink = page.getByRole('link', { name: 'Go to SertantAI Hub' });
		await expect(hubLink).toBeVisible();
		expect(await hubLink.getAttribute('href')).toBe(HUB_ORIGIN);
	});

	test('admin user sees the dashboard', async ({ page, loginAsAdmin }) => {
		const user = await loginAsAdmin();

		await expect(page.getByRole('link', { name: 'SertantAI Legal' })).toBeVisible();
		await expect(page.getByRole('link', { name: 'LRT Data', exact: true })).toBeVisible();
		await expect(page.getByRole('link', { name: 'LAT Data', exact: true })).toBeVisible();
		await expect(page.getByText(user.role, { exact: true })).toBeVisible();
	});

	test('owner user sees the dashboard', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin({ role: 'owner' });

		await expect(page.getByRole('link', { name: 'SertantAI Legal' })).toBeVisible();
		await expect(page.getByRole('link', { name: 'LRT Data', exact: true })).toBeVisible();
		await expect(page.getByRole('link', { name: 'LAT Data', exact: true })).toBeVisible();
		await expect(page.getByText('owner', { exact: true })).toBeVisible();
	});

	test('non-admin user sees access denied with browse link', async ({ page, createUser }) => {
		const user = await createUser({ role: 'member' });

		await page.goto('/');
		await page.evaluate(([key, value]) => localStorage.setItem(key, value), [
			'sertantai_token',
			user.token
		] as const);
		await page.goto('/admin');

		await expect(page.getByRole('heading', { name: 'Access Denied' })).toBeVisible();
		await expect(page.getByText('This area is restricted to administrators')).toBeVisible();
		await expect(page.getByRole('link', { name: 'Browse Laws' })).toBeVisible();
	});

	test('sign out redirects to hub', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		await expect(page.getByRole('link', { name: 'LRT Data', exact: true })).toBeVisible();

		const tokenBefore = await page.evaluate(() => localStorage.getItem('sertantai_token'));
		expect(tokenBefore).not.toBeNull();

		const redirectRequest = page.waitForRequest((req) => req.url().startsWith(HUB_ORIGIN), {
			timeout: 10000
		});

		await page.getByRole('button', { name: 'Sign out' }).click();
		const req = await redirectRequest;

		expect(req.url()).toBe(`${HUB_ORIGIN}/`);
	});
});

test.describe('Auth callback', () => {
	test('stores token and redirects to dest', async ({ page, createUser }) => {
		const user = await createUser({ role: 'admin' });

		await page.goto(`/auth/callback?token=${user.token}&dest=/admin`);

		// Should briefly show success then redirect to /admin
		await expect(page.getByText('Signed in successfully')).toBeVisible();
		await page.waitForURL('**/admin', { timeout: 5000 });

		// Token should be in localStorage
		const storedToken = await page.evaluate(() => localStorage.getItem('sertantai_token'));
		expect(storedToken).toBe(user.token);

		// Should see admin dashboard
		await expect(page.getByRole('link', { name: 'LRT Data', exact: true })).toBeVisible();
	});

	test('defaults to /browse when no dest param', async ({ page, createUser }) => {
		const user = await createUser({ role: 'member' });

		await page.goto(`/auth/callback?token=${user.token}`);

		await expect(page.getByText('Signed in successfully')).toBeVisible();
		await page.waitForURL('**/browse', { timeout: 5000 });
	});
});
