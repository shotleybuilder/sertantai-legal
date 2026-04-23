<script lang="ts">
	import { onMount } from 'svelte';
	import { page } from '$app/stores';
	import { adminAuth, isAdmin, type AuthUser } from '$lib/stores/auth';

	const HUB_URL = import.meta.env.VITE_HUB_URL || 'http://localhost:5173';

	const navItems = [
		{ href: '/admin/analytics', label: 'Analytics', exact: true },
		{ href: '/admin/lrt', label: 'LRT Data', exact: false },
		{ href: '/admin/lat', label: 'LAT Data', exact: true },
		{ href: '/admin/lat/queue', label: 'LAT Queue', exact: false },
		{ href: '/admin/lat/audit', label: 'LAT Audit', exact: true },
		{ href: '/admin/scrape', label: 'New Scrape', exact: true },
		{
			label: 'Sessions',
			dropdown: [
				{ href: '/admin/scrape/sessions', label: 'LRT Sessions' },
				{ href: '/admin/lat/sessions', label: 'LAT Sessions' }
			]
		},
		{ href: '/admin/scrape/cascade', label: 'Cascade', exact: false },
		{ href: '/admin/zenoh', label: 'Zenoh', exact: false },
		{ href: '/admin/sync', label: 'Sync', exact: true }
	];

	let openDropdown: string | null = null;

	function toggleDropdown(label: string) {
		openDropdown = openDropdown === label ? null : label;
	}

	function closeDropdown() {
		openDropdown = null;
	}

	function isDropdownActive(currentPath: string, items: { href: string }[]): boolean {
		return items.some(
			(item) => currentPath === item.href || currentPath.startsWith(item.href + '/')
		);
	}

	// Reactive pathname for proper updates on navigation
	$: pathname = $page.url.pathname;

	let loading = true;
	let user: AuthUser | null = null;

	adminAuth.subscribe((v) => (user = v));

	onMount(() => {
		// adminAuth.check() is called at module scope in the root +layout.svelte
		// so the token is already restored before any child component mounts.
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
			<p class="mb-6 text-sm text-gray-500">You need to sign in to access the admin area.</p>
			<a
				href={HUB_URL}
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
				This area is restricted to administrators. If you believe you should have access, contact
				your organisation owner.
			</p>
			<div class="flex items-center justify-center gap-4">
				<a
					href="/browse"
					class="inline-block rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
				>
					Browse Laws
				</a>
				<button on:click={signOut} class="text-sm text-gray-400 hover:text-gray-600">
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
								{#if item.dropdown}
									<!-- svelte-ignore a11y-click-events-have-key-events -->
									<div class="relative inline-flex items-center">
										<button
											on:click={() => toggleDropdown(item.label)}
											class="inline-flex items-center rounded-md px-3 py-2 text-sm font-medium
												{isDropdownActive(pathname, item.dropdown)
												? 'bg-blue-100 text-blue-700'
												: 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'}"
										>
											{item.label}
											<svg
												class="ml-1 h-4 w-4"
												fill="none"
												stroke="currentColor"
												viewBox="0 0 24 24"
											>
												<path
													stroke-linecap="round"
													stroke-linejoin="round"
													stroke-width="2"
													d="M19 9l-7 7-7-7"
												/>
											</svg>
										</button>
										{#if openDropdown === item.label}
											<!-- svelte-ignore a11y-no-static-element-interactions -->
											<div class="fixed inset-0 z-10" on:click={closeDropdown}></div>
											<div
												class="absolute left-0 z-20 mt-1 w-44 rounded-md bg-white shadow-lg ring-1 ring-black ring-opacity-5"
											>
												{#each item.dropdown as sub}
													<a
														href={sub.href}
														on:click={closeDropdown}
														class="block px-4 py-2 text-sm {isActive(pathname, sub.href, false)
															? 'bg-blue-50 text-blue-700'
															: 'text-gray-700 hover:bg-gray-100'}"
													>
														{sub.label}
													</a>
												{/each}
											</div>
										{/if}
									</div>
								{:else}
									<a
										href={item.href}
										class="inline-flex items-center rounded-md px-3 py-2 text-sm font-medium
											{isActive(pathname, item.href, item.exact ?? false)
											? 'bg-blue-100 text-blue-700'
											: 'text-gray-600 hover:bg-gray-100 hover:text-gray-900'}"
									>
										{item.label}
									</a>
								{/if}
							{/each}
						</div>
					</div>

					<!-- Right side: user info -->
					<div class="flex items-center gap-3">
						<span class="text-sm text-gray-600">{user.name || user.email}</span>
						<span class="rounded bg-blue-100 px-1.5 py-0.5 text-xs text-blue-700">{user.role}</span>
						<button on:click={signOut} class="text-sm text-gray-400 hover:text-gray-600">
							Sign out
						</button>
					</div>
				</div>
			</div>

			<!-- Mobile Navigation -->
			<div class="border-t border-gray-200 py-2 px-4 sm:hidden">
				<div class="flex flex-wrap gap-1">
					{#each navItems as item}
						{#if item.dropdown}
							{#each item.dropdown as sub}
								<a
									href={sub.href}
									class="rounded-md px-3 py-2 text-sm font-medium
										{isActive(pathname, sub.href, false)
										? 'bg-blue-100 text-blue-700'
										: 'text-gray-600 hover:bg-gray-100'}"
								>
									{sub.label}
								</a>
							{/each}
						{:else}
							<a
								href={item.href}
								class="rounded-md px-3 py-2 text-sm font-medium
									{isActive(pathname, item.href, item.exact ?? false)
									? 'bg-blue-100 text-blue-700'
									: 'text-gray-600 hover:bg-gray-100'}"
							>
								{item.label}
							</a>
						{/if}
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
