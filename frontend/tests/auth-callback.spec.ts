/**
 * Auth callback E2E tests.
 *
 * Tests the /auth/callback page that receives JWT tokens from sertantai-auth
 * after GitHub OAuth completes.
 */
import { test, expect } from './helpers/fixtures';

test.describe('Auth callback', () => {
	test('stores token and redirects to /admin on valid token', async ({
		page,
		createUser
	}) => {
		const user = await createUser({ role: 'admin' });

		await page.goto(`/auth/callback?token=${user.token}`);

		// Should show success message briefly
		await expect(page.getByText('Signed in successfully')).toBeVisible();

		// Should redirect to /admin
		await page.waitForURL('/admin');

		// Token should be stored in localStorage
		const storedToken = await page.evaluate(() =>
			localStorage.getItem('sertantai_token')
		);
		expect(storedToken).toBe(user.token);

		// Should see the admin dashboard (authenticated)
		await expect(page.getByRole('link', { name: 'LRT Data' })).toBeVisible();
	});

	test('shows error and redirects when no token provided', async ({ page }) => {
		await page.goto('/auth/callback');

		await expect(page.getByText('No token received')).toBeVisible();

		// Should redirect to /admin after delay
		await page.waitForURL('/admin', { timeout: 5000 });
	});

	test('shows error when error param is present', async ({ page }) => {
		await page.goto('/auth/callback?error=access_denied');

		await expect(page.getByText('Authentication failed')).toBeVisible();
	});
});
