<script lang="ts">
	import { page } from '$app/stores';

	const navItems = [{ href: '/browse', label: 'Browse Laws', exact: false }];

	$: pathname = $page.url.pathname;

	function isActive(currentPath: string, href: string, exact: boolean): boolean {
		if (exact) return currentPath === href;
		return currentPath === href || currentPath.startsWith(href + '/');
	}
</script>

<div class="h-screen flex flex-col bg-gray-50">
	<!-- Top Navigation -->
	<nav class="bg-white border-b border-gray-200 flex-shrink-0">
		<div class="px-4 sm:px-6 lg:px-8">
			<div class="flex justify-between h-14">
				<div class="flex">
					<div class="flex-shrink-0 flex items-center">
						<a href="/" class="text-xl font-bold text-gray-900">SertantAI Legal</a>
					</div>

					<div class="hidden sm:ml-8 sm:flex sm:space-x-4">
						{#each navItems as item}
							<a
								href={item.href}
								class="inline-flex items-center px-3 py-2 text-sm font-medium rounded-md
								{isActive(pathname, item.href, item.exact)
									? 'bg-emerald-100 text-emerald-700'
									: 'text-gray-600 hover:text-gray-900 hover:bg-gray-100'}"
							>
								{item.label}
							</a>
						{/each}
					</div>
				</div>

				<div class="flex items-center">
					<span
						class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-800"
					>
						Blanket Bog
					</span>
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
							? 'bg-emerald-100 text-emerald-700'
							: 'text-gray-600 hover:bg-gray-100'}"
					>
						{item.label}
					</a>
				{/each}
			</div>
		</div>
	</nav>

	<!-- Main Content Area (flex-1 to fill remaining height) -->
	<div class="flex-1 overflow-hidden">
		<slot />
	</div>
</div>
