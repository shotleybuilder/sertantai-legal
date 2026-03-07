<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { previewReparseSession, type ReparseFilters } from '$lib/api/scraper';
	import { useFamilyOptionsQuery } from '$lib/query/scraper';
	import { useCreateReparseMutation } from '$lib/query/scraper';

	export let open = false;

	const dispatch = createEventDispatcher<{
		close: void;
		created: { session_id: string };
	}>();

	const familyOptionsQuery = useFamilyOptionsQuery();
	const createMutation = useCreateReparseMutation();

	// Filter state
	let selectedFamily = '';
	let selectedFamilyIi = '';
	let selectedTypeCode = '';
	let selectedFunction = '';

	// Preview state
	let previewCount: number | null = null;
	let previewLoading = false;
	let previewError = '';

	// Creating state
	let creating = false;
	let createError = '';

	const typeCodeOptions = [
		{ value: 'uksi', label: 'UK SI' },
		{ value: 'ukpga', label: 'UK Act' },
		{ value: 'ssi', label: 'Scottish SI' },
		{ value: 'wsi', label: 'Welsh SI' },
		{ value: 'nisr', label: 'NI SR' },
		{ value: 'asp', label: 'Scottish Act' },
		{ value: 'nia', label: 'NI Act' },
		{ value: 'nisi', label: 'NI SI' },
		{ value: 'anaw', label: 'Welsh Act' }
	];

	const functionOptions = ['Making', 'Amending', 'Revoking', 'Commencing', 'Enacting'];

	// Derive sub-family options from selected family
	$: familyGrouped = $familyOptionsQuery.data?.grouped;
	$: allFamilies = familyGrouped
		? [
				...(familyGrouped.health_safety || []),
				...(familyGrouped.environment || []),
				...(familyGrouped.hr || [])
			]
		: [];

	// Sub-families: families that start with the selected family + ":"
	$: subFamilyOptions = (() => {
		if (!selectedFamily) return [];
		// Strip emoji prefix for matching (e.g. "💙 FIRE" -> find "💙 FIRE: ...")
		return allFamilies.filter(
			(f) => f !== selectedFamily && f.startsWith(selectedFamily.replace(/^.\s/, '').split(':')[0])
		);
	})();

	// Build session ID preview
	$: sessionIdPreview = (() => {
		if (!selectedFamily) return '';
		const parts = ['reparse', slugify(selectedFamily)];
		if (selectedTypeCode) parts.push(selectedTypeCode);
		if (selectedFunction) parts.push(selectedFunction.toLowerCase());
		const today = new Date().toISOString().split('T')[0];
		parts.push(today);
		return parts.join('-');
	})();

	function slugify(name: string): string {
		return name
			.toLowerCase()
			.replace(/[&:]/g, '')
			.replace(/[^a-z0-9]+/g, '-')
			.replace(/^-|-$/g, '');
	}

	// Build filters from current selections
	function buildFilters(): ReparseFilters {
		const filters: ReparseFilters = { family: selectedFamily };
		if (selectedFamilyIi) filters.family_ii = selectedFamilyIi;
		if (selectedTypeCode) filters.type_code = selectedTypeCode;
		if (selectedFunction) filters.function = selectedFunction;
		return filters;
	}

	// Preview count — debounced
	let previewTimeout: ReturnType<typeof setTimeout>;
	$: if (selectedFamily) {
		clearTimeout(previewTimeout);
		previewTimeout = setTimeout(fetchPreview, 300);
	} else {
		previewCount = null;
		previewError = '';
	}

	async function fetchPreview() {
		if (!selectedFamily) return;
		previewLoading = true;
		previewError = '';
		try {
			const result = await previewReparseSession(buildFilters());
			previewCount = result.count;
		} catch (e) {
			previewError = e instanceof Error ? e.message : 'Preview failed';
			previewCount = null;
		} finally {
			previewLoading = false;
		}
	}

	async function handleCreate() {
		if (!selectedFamily || previewCount === 0) return;
		creating = true;
		createError = '';
		try {
			const session = await $createMutation.mutateAsync(buildFilters());
			dispatch('created', { session_id: session.session_id });
		} catch (e) {
			createError = e instanceof Error ? e.message : 'Failed to create session';
		} finally {
			creating = false;
		}
	}

	function handleClose() {
		selectedFamily = '';
		selectedFamilyIi = '';
		selectedTypeCode = '';
		selectedFunction = '';
		previewCount = null;
		previewError = '';
		createError = '';
		dispatch('close');
	}

	// Reset dependent filters when family changes
	$: if (selectedFamily) {
		selectedFamilyIi = '';
	}
</script>

{#if open}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-50 overflow-y-auto">
		<div class="flex items-center justify-center min-h-screen px-4">
			<!-- Backdrop -->
			<div class="fixed inset-0 bg-black bg-opacity-50" on:click={handleClose}></div>

			<!-- Dialog -->
			<div class="relative bg-white rounded-lg shadow-xl max-w-lg w-full p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Reparse Family</h2>
				<p class="text-sm text-gray-500 mb-5">
					Create a reparse session from existing laws. Select a family and optional filters to
					narrow the set.
				</p>

				<div class="space-y-4">
					<!-- Family (required) -->
					<div>
						<label for="reparse-family" class="block text-sm font-medium text-gray-700 mb-1">
							Family <span class="text-red-500">*</span>
						</label>
						<select
							id="reparse-family"
							bind:value={selectedFamily}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
						>
							<option value="">-- Select Family --</option>
							{#if familyGrouped}
								<optgroup label="Health & Safety">
									{#each familyGrouped.health_safety || [] as opt}
										{#if !opt.includes(':')}
											<option value={opt}>{opt}</option>
										{/if}
									{/each}
								</optgroup>
								<optgroup label="Environment">
									{#each familyGrouped.environment || [] as opt}
										{#if !opt.includes(':')}
											<option value={opt}>{opt}</option>
										{/if}
									{/each}
								</optgroup>
								<optgroup label="HR">
									{#each familyGrouped.hr || [] as opt}
										{#if !opt.includes(':')}
											<option value={opt}>{opt}</option>
										{/if}
									{/each}
								</optgroup>
							{/if}
						</select>
					</div>

					<!-- Sub-Family (optional) -->
					{#if subFamilyOptions.length > 0}
						<div>
							<label
								for="reparse-family-ii"
								class="block text-sm font-medium text-gray-700 mb-1"
							>
								Sub-Family
							</label>
							<select
								id="reparse-family-ii"
								bind:value={selectedFamilyIi}
								class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
							>
								<option value="">-- All --</option>
								{#each subFamilyOptions as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</select>
						</div>
					{/if}

					<!-- Type Code (optional) -->
					<div>
						<label for="reparse-type-code" class="block text-sm font-medium text-gray-700 mb-1">
							Type Code
						</label>
						<select
							id="reparse-type-code"
							bind:value={selectedTypeCode}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
						>
							<option value="">-- All --</option>
							{#each typeCodeOptions as opt}
								<option value={opt.value}>{opt.label} ({opt.value})</option>
							{/each}
						</select>
					</div>

					<!-- Function (optional) -->
					<div>
						<label class="block text-sm font-medium text-gray-700 mb-1">Function</label>
						<div class="flex flex-wrap gap-2">
							{#each functionOptions as fn}
								<button
									type="button"
									class="px-3 py-1 text-sm rounded-full border {selectedFunction === fn
										? 'bg-blue-100 border-blue-500 text-blue-700'
										: 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}"
									on:click={() =>
										(selectedFunction = selectedFunction === fn ? '' : fn)}
								>
									{fn}
								</button>
							{/each}
						</div>
					</div>

					<!-- Preview -->
					<div class="bg-gray-50 rounded-lg p-4">
						{#if !selectedFamily}
							<p class="text-sm text-gray-400">Select a family to see record count</p>
						{:else if previewLoading}
							<p class="text-sm text-gray-500">Counting records...</p>
						{:else if previewError}
							<p class="text-sm text-red-600">{previewError}</p>
						{:else if previewCount !== null}
							<div class="flex items-center justify-between">
								<p class="text-sm text-gray-700">
									<span class="font-semibold text-gray-900">{previewCount}</span>
									{previewCount === 1 ? 'record' : 'records'} match
								</p>
								{#if previewCount === 0}
									<span class="text-xs text-amber-600">No records to reparse</span>
								{/if}
							</div>
						{/if}
						{#if sessionIdPreview}
							<p class="text-xs text-gray-400 mt-2 font-mono">{sessionIdPreview}</p>
						{/if}
					</div>

					<!-- Error -->
					{#if createError}
						<div class="rounded-md bg-red-50 p-3">
							<p class="text-sm text-red-700">{createError}</p>
						</div>
					{/if}
				</div>

				<!-- Actions -->
				<div class="mt-6 flex justify-end space-x-3">
					<button
						type="button"
						class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
						on:click={handleClose}
					>
						Cancel
					</button>
					<button
						type="button"
						class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
						disabled={!selectedFamily || previewCount === 0 || previewCount === null || creating}
						on:click={handleCreate}
					>
						{#if creating}
							Creating...
						{:else}
							Create Reparse Session
						{/if}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
