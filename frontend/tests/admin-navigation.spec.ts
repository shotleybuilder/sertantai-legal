/**
 * Admin navigation E2E tests.
 *
 * Smoke tests that admin pages are accessible and render correctly
 * when authenticated as an admin user.
 */
import { test, expect } from './helpers/fixtures';

test.describe('Admin navigation', () => {
	test('can navigate to LRT Data page', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		const nav = page.locator('nav');
		await nav.getByRole('link', { name: 'LRT Data' }).click();
		await page.waitForURL('/admin/lrt');

		await expect(nav.getByRole('link', { name: 'LRT Data' })).toBeVisible();
	});

	test('can navigate to LAT Data page', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		const nav = page.locator('nav');
		await nav.getByRole('link', { name: 'LAT Data', exact: true }).click();
		await page.waitForURL('/admin/lat');

		await expect(nav.getByRole('link', { name: 'LAT Data', exact: true })).toBeVisible();
	});

	test('can navigate to LAT Queue page', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		const nav = page.locator('nav');
		await nav.getByRole('link', { name: 'LAT Queue' }).click();
		await page.waitForURL('/admin/lat/queue');

		await expect(nav.getByRole('link', { name: 'LAT Queue' })).toBeVisible();
	});

	test('can navigate to Scrape page', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		const nav = page.locator('nav');
		await nav.getByRole('link', { name: 'New Scrape' }).click();
		await page.waitForURL('/admin/scrape');

		await expect(nav.getByRole('link', { name: 'New Scrape' })).toBeVisible();
	});

	test('can navigate to Zenoh page', async ({ page, loginAsAdmin }) => {
		await loginAsAdmin();

		const nav = page.locator('nav');
		await nav.getByRole('link', { name: 'Zenoh' }).click();
		await page.waitForURL('/admin/zenoh');

		await expect(nav.getByRole('link', { name: 'Zenoh' })).toBeVisible();
	});
});
