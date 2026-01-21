<script lang="ts">
	import { page } from '$app/stores';

	const navItems = [
		{ href: '/admin/lrt', label: 'LRT Data', exact: false },
		{ href: '/admin/scrape', label: 'New Scrape', exact: true },
		{ href: '/admin/scrape/sessions', label: 'Sessions', exact: false },
		{ href: '/admin/scrape/cascade', label: 'Cascade', exact: false }
	];

	// Reactive pathname for proper updates on navigation
	$: pathname = $page.url.pathname;

	function isActive(currentPath: string, href: string, exact: boolean): boolean {
		if (exact) {
			// Only match exactly this path
			return currentPath === href;
		}
		// Match this path and any children
		return currentPath === href || currentPath.startsWith(href + '/');
	}
</script>

<div class="min-h-screen bg-gray-50">
	<!-- Top Navigation -->
	<nav class="bg-white border-b border-gray-200">
		<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
			<div class="flex justify-between h-16">
				<div class="flex">
					<!-- Logo/Home -->
					<div class="flex-shrink-0 flex items-center">
						<a href="/" class="text-xl font-bold text-gray-900">SertantAI Legal</a>
					</div>

					<!-- Navigation Links -->
					<div class="hidden sm:ml-8 sm:flex sm:space-x-4">
						{#each navItems as item}
							<a
								href={item.href}
								class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-md
                       {isActive(pathname, item.href, item.exact)
									? 'bg-blue-100 text-blue-700'
									: 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'}"
							>
								{item.label}
							</a>
						{/each}
					</div>
				</div>

				<!-- Right side -->
				<div class="flex items-center">
					<span class="text-sm text-gray-500">Admin</span>
				</div>
			</div>
		</div>

		<!-- Mobile Navigation -->
		<div class="sm:hidden border-t border-gray-200 py-2 px-4">
			<div class="flex space-x-2">
				{#each navItems as item}
					<a
						href={item.href}
						class="px-3 py-2 text-sm font-medium rounded-md
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
	<main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
		<slot />
	</main>
</div>
