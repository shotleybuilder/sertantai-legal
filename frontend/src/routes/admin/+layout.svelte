<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { adminAuth, type AdminUser } from '$lib/stores/auth';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	const navItems = [
		{ href: '/admin/lrt', label: 'LRT Data', exact: false },
		{ href: '/admin/lat', label: 'LAT Data', exact: true },
		{ href: '/admin/lat/queue', label: 'LAT Queue', exact: false },
		{ href: '/admin/scrape', label: 'New Scrape', exact: true },
		{ href: '/admin/scrape/sessions', label: 'Sessions', exact: false },
		{ href: '/admin/scrape/cascade', label: 'Cascade', exact: false },
		{ href: '/admin/zenoh', label: 'Zenoh', exact: false }
	];

	// Reactive pathname for proper updates on navigation
	$: pathname = $page.url.pathname;

	let loading = true;
	let user: AdminUser | null = null;

	adminAuth.subscribe((v) => (user = v));

	onMount(async () => {
		await adminAuth.check();
		loading = false;
	});

	function isActive(currentPath: string, href: string, exact: boolean): boolean {
		if (exact) {
			return currentPath === href;
		}
		return currentPath === href || currentPath.startsWith(href + '/');
	}
</script>

{#if loading}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-gray-500">Loading...</div>
	</div>
{:else if !user}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<h1 class="mb-6 text-2xl font-bold text-gray-900">SertantAI Legal Admin</h1>
			<p class="mb-8 text-gray-500">Sign in with GitHub to access admin tools.</p>
			<a
				href="{API_URL}/auth/user/github"
				class="inline-flex items-center gap-2 rounded-lg bg-gray-900 px-6 py-3 text-white hover:bg-gray-800"
			>
				<svg class="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
					<path
						d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"
					/>
				</svg>
				Sign in with GitHub
			</a>
		</div>
	</div>
{:else}
	<div class="min-h-screen bg-gray-50">
		<!-- Top Navigation -->
		<nav class="border-b border-gray-200 bg-white">
			<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
				<div class="flex h-16 justify-between">
					<div class="flex">
						<!-- Logo/Home -->
						<div class="flex flex-shrink-0 items-center">
							<a href="/" class="text-xl font-bold text-gray-900">SertantAI Legal</a>
						</div>

						<!-- Navigation Links -->
						<div class="hidden sm:ml-8 sm:flex sm:space-x-4">
							{#each navItems as item}
								<a
									href={item.href}
									class="inline-flex items-center rounded-md px-3 py-2 text-sm font-medium
                       {isActive(pathname, item.href, item.exact)
										? 'bg-blue-100 text-blue-700'
										: 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'}"
								>
									{item.label}
								</a>
							{/each}
						</div>
					</div>

					<!-- Right side: user info -->
					<div class="flex items-center gap-3">
						{#if user.avatar_url}
							<img
								src={user.avatar_url}
								alt={user.github_login || 'User'}
								class="h-7 w-7 rounded-full"
							/>
						{/if}
						<span class="text-sm text-gray-600">{user.github_login || user.email}</span>
						<a
							href="{API_URL}/auth/sign-out"
							class="text-sm text-gray-400 hover:text-gray-600"
						>
							Sign out
						</a>
					</div>
				</div>
			</div>

			<!-- Mobile Navigation -->
			<div class="border-t border-gray-200 py-2 px-4 sm:hidden">
				<div class="flex space-x-2">
					{#each navItems as item}
						<a
							href={item.href}
							class="rounded-md px-3 py-2 text-sm font-medium
                   {isActive(pathname, item.href, item.exact)
								? 'bg-blue-100 text-blue-700'
								: 'text-gray-600 hover:bg-gray-100'}"
						>
							{item.label}
						</a>
					{/each}
				</div>
			</div>
		</nav>

		<!-- Main Content -->
		<main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
			<slot />
		</main>
	</div>
{/if}
