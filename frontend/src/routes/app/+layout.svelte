<script lang="ts">
	import { page } from '$app/stores';
	import { adminAuth } from '$lib/stores/auth';
	import { goto } from '$app/navigation';
	import { onMount, onDestroy } from 'svelte';
	import { authFetch } from '$lib/api/client';

	const HUB_URL = import.meta.env.VITE_HUB_URL || 'http://localhost:4001';
	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	const navItems = [
		{ href: '/app/screening', label: 'Screening' },
		{ href: '/app/changes', label: 'Changes' },
		{ href: '/app/profile', label: 'Profile' },
		{ href: '/app/activity', label: 'Activity' },
		{ href: '/app/stats', label: 'Stats' }
	];

	let pendingCount = 0;
	let overdueCount = 0;
	let pollTimer: ReturnType<typeof setInterval> | null = null;

	$: pathname = $page.url.pathname;
	$: user = $adminAuth;

	async function fetchChangeSummary() {
		try {
			const res = await authFetch(`${API_URL}/api/screening/changes/summary`);
			if (res.ok) {
				const data = await res.json();
				pendingCount = data.total_pending || 0;
				overdueCount = data.overdue || 0;
			}
		} catch {
			// Silently fail — badge just won't show
		}
	}

	onMount(() => {
		fetchChangeSummary();
		pollTimer = setInterval(fetchChangeSummary, 60_000);
	});

	onDestroy(() => {
		if (pollTimer) clearInterval(pollTimer);
	});

	function isActive(currentPath: string, href: string): boolean {
		return currentPath === href || currentPath.startsWith(href + '/');
	}

	function signOut() {
		adminAuth.clear();
		goto(`${HUB_URL}/sign-out`);
	}
</script>

{#if !user}
	<div class="h-screen flex items-center justify-center bg-gray-50">
		<div class="text-center">
			<h1 class="text-xl font-semibold text-gray-900 mb-2">Sign In Required</h1>
			<p class="text-gray-600 mb-4">Please sign in to access the compliance dashboard.</p>
			<a
				href="{HUB_URL}/sign-in?redirect={encodeURIComponent($page.url.href)}"
				class="px-4 py-2 bg-emerald-600 text-white rounded-md hover:bg-emerald-700"
			>
				Sign In
			</a>
		</div>
	</div>
{:else if !user.org_id}
	<div class="h-screen flex items-center justify-center bg-gray-50">
		<div class="text-center">
			<h1 class="text-xl font-semibold text-gray-900 mb-2">No Organisation</h1>
			<p class="text-gray-600 mb-4">
				Your account is not linked to an organisation. The compliance dashboard requires an
				organisation context.
			</p>
			{#if user.role === 'admin'}
				<p class="text-sm text-gray-500 mb-4">
					You are signed in as a platform admin. Use the
					<a href="/admin" class="text-emerald-600 underline font-medium">Admin panel</a>
					for platform management, or sign in with an organisation account to access screening.
				</p>
			{/if}
		</div>
	</div>
{:else}
	<div class="h-screen flex flex-col bg-gray-50">
		<!-- Top Navigation -->
		<nav class="bg-white border-b border-gray-200 flex-shrink-0">
			<div class="px-4 sm:px-6 lg:px-8">
				<div class="flex justify-between h-14">
					<div class="flex">
						<div class="flex-shrink-0 flex items-center">
							<a href="/app/screening" class="text-xl font-bold text-gray-900">SertantAI</a>
						</div>

						<div class="hidden sm:ml-8 sm:flex sm:space-x-4">
							{#each navItems as item}
								<a
									href={item.href}
									class="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-md
									{isActive(pathname, item.href)
										? 'bg-emerald-100 text-emerald-700'
										: 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'}"
								>
									{item.label}
									{#if item.label === 'Changes' && pendingCount > 0}
										<span
											class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1.5 text-xs font-bold rounded-full
											{overdueCount > 0 ? 'bg-red-500 text-white' : 'bg-amber-400 text-amber-900'}"
										>
											{pendingCount}
										</span>
									{/if}
								</a>
							{/each}
						</div>
					</div>

					<div class="flex items-center gap-3">
						{#if user.org_name}
							<span
								class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-800"
							>
								{user.org_name}
							</span>
						{/if}
						<span class="text-sm text-gray-500">{user.email || user.name || ''}</span>
						<button on:click={signOut} class="text-sm text-gray-500 hover:text-gray-700">
							Sign out
						</button>
					</div>
				</div>
			</div>

			<!-- Mobile Navigation -->
			<div class="sm:hidden border-t border-gray-200 py-2 px-4">
				<div class="flex space-x-2">
					{#each navItems as item}
						<a
							href={item.href}
							class="inline-flex items-center gap-1 px-3 py-2 text-sm font-medium rounded-md
							{isActive(pathname, item.href)
								? 'bg-emerald-100 text-emerald-700'
								: 'text-gray-600 hover:bg-gray-100'}"
						>
							{item.label}
							{#if item.label === 'Changes' && pendingCount > 0}
								<span
									class="inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1.5 text-xs font-bold rounded-full
									{overdueCount > 0 ? 'bg-red-500 text-white' : 'bg-amber-400 text-amber-900'}"
								>
									{pendingCount}
								</span>
							{/if}
						</a>
					{/each}
				</div>
			</div>
		</nav>

		<!-- Main Content Area -->
		<div class="flex-1 overflow-hidden">
			<slot />
		</div>
	</div>
{/if}
