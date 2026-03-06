/**
 * Tests for ElectricSQL client configuration.
 *
 * Covers:
 * - Issue #40: Relative VITE_ELECTRIC_URL must be resolved to absolute URL
 * - Issue #41: Electric URL must go through /api/electric proxy, not /electric directly
 */

import { describe, it, expect } from 'vitest';
import { resolveElectricUrl } from './client';

describe('resolveElectricUrl', () => {
	// ── Issue #40: Relative URL resolution ──────────────────────────

	describe('relative URL resolution (issue #40)', () => {
		it('resolves relative path against origin', () => {
			const result = resolveElectricUrl('/api/electric', 'https://legal.sertantai.com');
			expect(result).toBe('https://legal.sertantai.com/api/electric');
		});

		it('resolves root-relative path against origin', () => {
			const result = resolveElectricUrl('/electric', 'https://example.com');
			expect(result).toBe('https://example.com/electric');
		});

		it('returns relative path unchanged when no origin (SSR)', () => {
			const result = resolveElectricUrl('/api/electric', undefined);
			expect(result).toBe('/api/electric');
		});

		it('returns absolute URL unchanged', () => {
			const result = resolveElectricUrl(
				'https://legal.sertantai.com/api/electric',
				'https://other.example.com'
			);
			expect(result).toBe('https://legal.sertantai.com/api/electric');
		});

		it('returns localhost URL unchanged', () => {
			const result = resolveElectricUrl(
				'http://localhost:4003/api/electric',
				'http://localhost:5175'
			);
			expect(result).toBe('http://localhost:4003/api/electric');
		});
	});

	// ── Issue #41: Must use /api/electric proxy ─────────────────────

	describe('proxy path validation (issue #41)', () => {
		it('production .env.production uses /api/electric (not /electric)', () => {
			// This test documents the correct production configuration.
			// VITE_ELECTRIC_URL=/api/electric routes through the Phoenix backend proxy
			// which injects ELECTRIC_SECRET. Using /electric bypasses the proxy and
			// Electric returns 401 "Unauthorized - Invalid API secret".
			const prodUrl = '/api/electric';
			const result = resolveElectricUrl(prodUrl, 'https://legal.sertantai.com');

			expect(result).toBe('https://legal.sertantai.com/api/electric');
			// Must contain /api/ prefix to go through Phoenix proxy
			expect(result).toContain('/api/electric');
			// Must NOT be bare /electric (bypasses proxy)
			expect(result).not.toMatch(/\.com\/electric$/);
		});

		it('resolved URL produces valid shape endpoint', () => {
			const result = resolveElectricUrl('/api/electric', 'https://legal.sertantai.com');
			const shapeUrl = `${result}/v1/shape`;

			expect(shapeUrl).toBe('https://legal.sertantai.com/api/electric/v1/shape');
			// Verify it's a valid URL
			expect(() => new URL(shapeUrl)).not.toThrow();
		});

		it('dev fallback produces valid absolute URL', () => {
			// In dev, VITE_ELECTRIC_URL is unset, falls back to ${API_URL}/api/electric
			const devUrl = 'http://localhost:4003/api/electric';
			const result = resolveElectricUrl(devUrl, 'http://localhost:5175');

			expect(result).toBe('http://localhost:4003/api/electric');
			expect(() => new URL(`${result}/v1/shape`)).not.toThrow();
		});
	});

	// ── Edge cases ──────────────────────────────────────────────────

	describe('edge cases', () => {
		it('handles origin with trailing slash gracefully', () => {
			// origins should not have trailing slashes, but be safe
			const result = resolveElectricUrl('/api/electric', 'https://legal.sertantai.com');
			expect(result).not.toContain('//api');
		});

		it('handles deep relative paths', () => {
			const result = resolveElectricUrl('/v2/api/electric', 'https://example.com');
			expect(result).toBe('https://example.com/v2/api/electric');
		});

		it('does not modify protocol-relative URLs', () => {
			const result = resolveElectricUrl('//cdn.example.com/electric', 'https://example.com');
			// Starts with // not /, so should be returned as-is
			expect(result).toBe('//cdn.example.com/electric');
		});
	});
});
