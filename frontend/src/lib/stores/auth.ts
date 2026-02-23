import { writable } from 'svelte/store';

export interface AdminUser {
	id: string;
	email: string;
	name?: string;
	github_login?: string;
	avatar_url?: string;
	is_admin: boolean;
}

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

function createAuthStore() {
	const { subscribe, set } = writable<AdminUser | null>(null);

	return {
		subscribe,
		check: async (): Promise<AdminUser | null> => {
			try {
				const response = await fetch(`${API_URL}/api/auth/me`, {
					credentials: 'include'
				});
				if (response.ok) {
					const user: AdminUser = await response.json();
					set(user);
					return user;
				}
			} catch {
				// Auth check failed — user is not authenticated
			}
			set(null);
			return null;
		},
		clear: () => set(null)
	};
}

export const adminAuth = createAuthStore();
