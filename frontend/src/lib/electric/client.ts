/**
 * ElectricSQL Client Configuration
 *
 * Provides the base URL and utilities for connecting to the Electric sync service.
 */

/**
 * Resolve the Electric sync URL from environment variables.
 *
 * The Electric client's URL constructor requires an absolute URL.
 * In production, VITE_ELECTRIC_URL is a relative path (e.g. "/api/electric")
 * which must be resolved against the browser's origin.
 *
 * IMPORTANT: The URL must go through the Phoenix backend proxy (/api/electric),
 * NOT directly to Electric (/electric). The proxy injects the ELECTRIC_SECRET
 * server-side. Direct Electric access returns 401 "Invalid API secret".
 * See: https://github.com/shotleybuilder/sertantai-legal/issues/41
 *
 * @param rawUrl - The raw VITE_ELECTRIC_URL value (absolute or relative path)
 * @param origin - The browser origin (window.location.origin), or undefined for SSR
 * @returns Absolute URL string suitable for the Electric client
 */
export function resolveElectricUrl(rawUrl: string, origin?: string): string {
	if (rawUrl.startsWith('/') && !rawUrl.startsWith('//') && origin) {
		return `${origin}${rawUrl}`;
	}
	return rawUrl;
}

// Electric sync service URL — goes through Phoenix backend proxy (Gatekeeper pattern)
// Dev: http://localhost:4003/api/electric, Prod: https://legal.sertantai.com/api/electric
const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';
const rawElectricUrl = import.meta.env.VITE_ELECTRIC_URL || `${API_URL}/api/electric`;

export const ELECTRIC_URL = resolveElectricUrl(
	rawElectricUrl,
	typeof window !== 'undefined' ? window.location.origin : undefined
);

// Re-export for convenience
export { ELECTRIC_URL as electricUrl };
