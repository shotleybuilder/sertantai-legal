/**
 * Regression test: validate .env.production Electric URL configuration.
 *
 * Issue #41: VITE_ELECTRIC_URL=/electric bypassed the Phoenix backend proxy,
 * causing Electric to return 401 "Unauthorized - Invalid API secret".
 * The correct value is /api/electric which routes through ElectricProxyController.
 *
 * This test reads the actual .env.production file to prevent regression.
 */

import { describe, it, expect } from 'vitest';
import { readFileSync } from 'fs';
import { resolve } from 'path';

describe('.env.production Electric URL (issue #41 regression)', () => {
	// Vitest cwd is the frontend/ directory
	const envPath = resolve(process.cwd(), '.env.production');
	let envContent: string;

	try {
		envContent = readFileSync(envPath, 'utf-8');
	} catch {
		envContent = '';
	}

	it('.env.production file exists and is readable', () => {
		expect(envContent.length).toBeGreaterThan(0);
	});

	it('VITE_ELECTRIC_URL routes through /api/electric proxy', () => {
		const match = envContent.match(/^VITE_ELECTRIC_URL=(.+)$/m);
		expect(match).not.toBeNull();

		const value = match![1].trim();
		// Must go through the backend proxy at /api/electric
		expect(value).toContain('/api/electric');
	});

	it('VITE_ELECTRIC_URL does NOT point directly to /electric (bypasses proxy)', () => {
		const match = envContent.match(/^VITE_ELECTRIC_URL=(.+)$/m);
		expect(match).not.toBeNull();

		const value = match![1].trim();
		// /electric without /api/ prefix goes directly to Electric via nginx,
		// bypassing the Phoenix proxy that injects ELECTRIC_SECRET
		expect(value).not.toMatch(/^\/electric$/);
	});
});
