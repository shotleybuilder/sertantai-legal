import { writable, get } from 'svelte/store';

const STORAGE_KEY = 'sertantai_token';

export interface AuthUser {
	id: string;
	email: string;
	name?: string;
	role: string;
	org_id?: string;
	org_name?: string;
}

/**
 * Decode a JWT payload without verifying the signature.
 * Sufficient for reading claims client-side — the backend validates signatures.
 */
function decodePayload(token: string): Record<string, unknown> | null {
	try {
		const parts = token.split('.');
		if (parts.length !== 3) return null;
		const payload = parts[1];
		const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'));
		return JSON.parse(json);
	} catch {
		return null;
	}
}

function isExpired(claims: Record<string, unknown>): boolean {
	const exp = claims.exp;
	if (typeof exp !== 'number') return true;
	return exp < Date.now() / 1000;
}

function claimsToUser(claims: Record<string, unknown>): AuthUser {
	// sub is "user?id=<uuid>" format from AshAuthentication
	let id = String(claims.sub || '');
	if (id.startsWith('user?id=')) {
		id = id.slice('user?id='.length);
	}

	return {
		id,
		email: String(claims.email || ''),
		name: claims.name ? String(claims.name) : undefined,
		role: String(claims.role || 'member'),
		org_id: claims.org_id ? String(claims.org_id) : undefined,
		org_name: claims.org_name ? String(claims.org_name) : undefined
	};
}

function createAuthStore() {
	const { subscribe, set } = writable<AuthUser | null>(null);

	return {
		subscribe,

		/**
		 * Check for an existing token in localStorage and validate it.
		 * Returns the user if a valid token exists, null otherwise.
		 */
		check: (): AuthUser | null => {
			try {
				const token = localStorage.getItem(STORAGE_KEY);
				if (!token) return null;

				const claims = decodePayload(token);
				if (!claims || isExpired(claims)) {
					localStorage.removeItem(STORAGE_KEY);
					set(null);
					return null;
				}

				const user = claimsToUser(claims);
				set(user);
				return user;
			} catch {
				set(null);
				return null;
			}
		},

		/**
		 * Store a JWT token and update the user state from its claims.
		 */
		setToken: (token: string): AuthUser | null => {
			const claims = decodePayload(token);
			if (!claims || isExpired(claims)) {
				return null;
			}

			localStorage.setItem(STORAGE_KEY, token);
			const user = claimsToUser(claims);
			set(user);
			return user;
		},

		/**
		 * Clear the stored token and user state.
		 */
		clear: () => {
			localStorage.removeItem(STORAGE_KEY);
			set(null);
		},

		/**
		 * Get the current token from localStorage (for explicit Authorization headers).
		 */
		getToken: (): string | null => {
			return localStorage.getItem(STORAGE_KEY);
		}
	};
}

export const adminAuth = createAuthStore();

/**
 * Check if the current user has admin or owner role.
 */
export function isAdmin(user: AuthUser | null): boolean {
	if (!user) return false;
	return user.role === 'admin' || user.role === 'owner';
}

/**
 * Get the current auth token. Convenience for use outside Svelte components.
 */
export function getAuthToken(): string | null {
	return localStorage.getItem(STORAGE_KEY);
}
