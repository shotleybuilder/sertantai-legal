<script lang="ts">
	import { slide } from 'svelte/transition';
	import { createEventDispatcher } from 'svelte';

	export let title: string;
	export let subtitle: string = '';
	export let expanded: boolean = true;
	export let level: 'section' | 'subsection' = 'section';
	// Optional badge to show in header (e.g., stage indicator)
	export let badge: string = '';
	export let badgeColor: 'blue' | 'green' | 'amber' | 'red' | 'gray' = 'gray';
	// Re-parse functionality (only for top-level sections with a stage)
	export let showReparse: boolean = false;
	export let isReparsing: boolean = false;

	const dispatch = createEventDispatcher<{ reparse: void }>();

	function toggle() {
		expanded = !expanded;
	}

	function handleReparse(e: MouseEvent) {
		e.stopPropagation(); // Don't toggle section when clicking reparse
		dispatch('reparse');
	}

	const badgeColors = {
		blue: 'bg-blue-100 text-blue-800',
		green: 'bg-green-100 text-green-800',
		amber: 'bg-amber-100 text-amber-800',
		red: 'bg-red-100 text-red-800',
		gray: 'bg-gray-100 text-gray-800'
	};
</script>

{#if level === 'section'}
	<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden {isReparsing ? 'opacity-75' : ''}">
		<!-- Section Header -->
		<button
			type="button"
			on:click={toggle}
			class="w-full bg-gray-50 px-4 py-2 border-b border-gray-200 flex justify-between items-center hover:bg-gray-100 transition-colors cursor-pointer"
		>
			<div class="flex items-center space-x-2">
				<h4 class="text-sm font-medium text-gray-700">{title}</h4>
				{#if subtitle}
					<span class="text-xs text-gray-500">{subtitle}</span>
				{/if}
				{#if badge}
					<span class="px-2 py-0.5 text-xs rounded {badgeColors[badgeColor]}">{badge}</span>
				{/if}
				{#if isReparsing}
					<span class="flex items-center text-xs text-blue-600">
						<svg class="animate-spin h-3 w-3 mr-1" fill="none" viewBox="0 0 24 24">
							<circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
							<path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
						</svg>
						Parsing...
					</span>
				{/if}
			</div>
			<div class="flex items-center space-x-2">
				{#if showReparse && !isReparsing}
					<button
						type="button"
						on:click={handleReparse}
						class="px-2 py-1 text-xs text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors"
						title="Re-parse this stage"
					>
						<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
						</svg>
					</button>
				{/if}
				<svg
					class="w-4 h-4 text-gray-500 transition-transform {expanded ? 'rotate-180' : ''}"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
				>
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
				</svg>
			</div>
		</button>

		<!-- Section Content -->
		{#if expanded}
			<div transition:slide={{ duration: 200 }} class="divide-y divide-gray-100">
				<slot />
			</div>
		{/if}
	</div>
{:else}
	<!-- Subsection (nested within a section) -->
	<div class="border-t border-gray-200 first:border-t-0">
		<button
			type="button"
			on:click={toggle}
			class="w-full px-4 py-2 bg-gray-50/50 flex justify-between items-center hover:bg-gray-100/50 transition-colors cursor-pointer"
		>
			<div class="flex items-center space-x-2">
				<h5 class="text-xs font-medium text-gray-600 uppercase tracking-wide">{title}</h5>
				{#if subtitle}
					<span class="text-xs text-gray-400">{subtitle}</span>
				{/if}
				{#if badge}
					<span class="px-1.5 py-0.5 text-xs rounded {badgeColors[badgeColor]}">{badge}</span>
				{/if}
			</div>
			<svg
				class="w-3 h-3 text-gray-400 transition-transform {expanded ? 'rotate-180' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
			</svg>
		</button>

		{#if expanded}
			<div transition:slide={{ duration: 150 }} class="divide-y divide-gray-100">
				<slot />
			</div>
		{/if}
	</div>
{/if}
