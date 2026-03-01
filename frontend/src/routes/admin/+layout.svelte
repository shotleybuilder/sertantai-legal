<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { adminAuth, isAdmin, type AuthUser } from '$lib/stores/auth';

	const HUB_URL = import.meta.env.VITE_HUB_URL || 'http://localhost:5173';

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
	let user: AuthUser | null = null;

	adminAuth.subscribe((v) => (user = v));

	onMount(() => {
		adminAuth.check();
		loading = false;
	});

	function isActive(currentPath: string, href: string, exact: boolean): boolean {
		if (exact) {
			return currentPath === href;
		}
		return currentPath === href || currentPath.startsWith(href + '/');
	}

	function signOut() {
		adminAuth.clear();
		window.location.href = HUB_URL;
	}
</script>

{#if loading}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-gray-500">Loading...</div>
	</div>
{:else if !user}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<h1 class="mb-4 text-2xl font-bold text-gray-900">Not Signed In</h1>
			<p class="mb-6 text-sm text-gray-500">
				You need to sign in to access the admin area.
			</p>
			<a
				href="{HUB_URL}"
				class="inline-block rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
			>
				Go to SertantAI Hub
			</a>
		</div>
	</div>
{:else if !isAdmin(user)}
	<div class="flex min-h-screen items-center justify-center bg-gray-50">
		<div class="text-center">
			<h1 class="mb-4 text-2xl font-bold text-gray-900">Access Denied</h1>
			<p class="mb-4 text-sm text-gray-500">
				This area is restricted to administrators. If you believe you should have access,
				contact your organisation owner.
			</p>
			<div class="flex items-center justify-center gap-4">
				<a
					href="/browse"
					class="inline-block rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
				>
					Browse Laws
				</a>
				<button
					on:click={signOut}
					class="text-sm text-gray-400 hover:text-gray-600"
				>
					Sign out
				</button>
			</div>
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
						<span class="text-sm text-gray-600">{user.name || user.email}</span>
						<span class="rounded bg-blue-100 px-1.5 py-0.5 text-xs text-blue-700">{user.role}</span>
						<button
							on:click={signOut}
							class="text-sm text-gray-400 hover:text-gray-600"
						>
							Sign out
						</button>
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
