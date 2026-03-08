<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { previewLatSession, type LatSessionFilters } from '$lib/api/lat';
	import { useFamilyOptionsQuery } from '$lib/query/scraper';
	import { useCreateLatSessionMutation } from '$lib/query/lat';

	export let open = false;

	const dispatch = createEventDispatcher<{
		close: void;
		created: { session_id: string };
	}>();

	const familyOptionsQuery = useFamilyOptionsQuery();
	const createMutation = useCreateLatSessionMutation();

	// Filter state
	let selectedFamily = '';
	let selectedTypeCode = '';
	let selectedFunction = '';
	let selectedQueueReason: '' | 'missing' | 'stale' = '';

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

	const queueReasonOptions = [
		{ value: '', label: 'All (Missing + Stale)' },
		{ value: 'missing', label: 'Missing — no LAT rows' },
		{ value: 'stale', label: 'Stale — LRT updated after LAT' }
	];

	// Build session ID preview
	$: sessionIdPreview = (() => {
		if (!selectedFamily) return '';
		const parts = ['lat-parse', slugify(selectedFamily)];
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

	function buildFilters(): LatSessionFilters {
		const filters: LatSessionFilters = { family: selectedFamily };
		if (selectedTypeCode) filters.type_code = selectedTypeCode;
		if (selectedFunction) filters.function = selectedFunction;
		if (selectedQueueReason) filters.queue_reason = selectedQueueReason;
		return filters;
	}

	// Preview count — debounced
	$: _filterKey = [selectedFamily, selectedTypeCode, selectedFunction, selectedQueueReason];
	let previewTimeout: ReturnType<typeof setTimeout>;
	$: if (_filterKey) {
		if (selectedFamily) {
			clearTimeout(previewTimeout);
			previewTimeout = setTimeout(fetchPreview, 300);
		} else {
			previewCount = null;
			previewError = '';
		}
	}

	async function fetchPreview() {
		if (!selectedFamily) return;
		previewLoading = true;
		previewError = '';
		try {
			const result = await previewLatSession(buildFilters());
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
		selectedTypeCode = '';
		selectedFunction = '';
		selectedQueueReason = '';
		previewCount = null;
		previewError = '';
		createError = '';
		dispatch('close');
	}
</script>

{#if open}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-50 overflow-y-auto">
		<div class="flex items-center justify-center min-h-screen px-4">
			<div class="fixed inset-0 bg-black bg-opacity-50" on:click={handleClose}></div>

			<div class="relative bg-white rounded-lg shadow-xl max-w-lg w-full p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Parse LAT Family</h2>
				<p class="text-sm text-gray-500 mb-5">
					Create a LAT parse session. Select a family and optional filters to choose which laws
					to parse for legal articles and annotations.
				</p>

				<div class="space-y-4">
					<!-- Family (required) -->
					<div>
						<label for="lat-family" class="block text-sm font-medium text-gray-700 mb-1">
							Family <span class="text-red-500">*</span>
						</label>
						<select
							id="lat-family"
							bind:value={selectedFamily}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
						>
							<option value="">-- Select Family --</option>
							{#if $familyOptionsQuery.data?.grouped}
								<optgroup label="Health & Safety">
									{#each $familyOptionsQuery.data.grouped.health_safety || [] as opt}
										<option value={opt}>{opt}</option>
									{/each}
								</optgroup>
								<optgroup label="Environment">
									{#each $familyOptionsQuery.data.grouped.environment || [] as opt}
										<option value={opt}>{opt}</option>
									{/each}
								</optgroup>
								<optgroup label="HR">
									{#each $familyOptionsQuery.data.grouped.hr || [] as opt}
										<option value={opt}>{opt}</option>
									{/each}
								</optgroup>
							{/if}
						</select>
					</div>

					<!-- Queue Reason -->
					<div>
						<label for="lat-queue-reason" class="block text-sm font-medium text-gray-700 mb-1">
							Queue Reason
						</label>
						<select
							id="lat-queue-reason"
							bind:value={selectedQueueReason}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
						>
							{#each queueReasonOptions as opt}
								<option value={opt.value}>{opt.label}</option>
							{/each}
						</select>
					</div>

					<!-- Type Code -->
					<div>
						<label for="lat-type-code" class="block text-sm font-medium text-gray-700 mb-1">
							Type Code
						</label>
						<select
							id="lat-type-code"
							bind:value={selectedTypeCode}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
						>
							<option value="">-- All --</option>
							{#each typeCodeOptions as opt}
								<option value={opt.value}>{opt.label} ({opt.value})</option>
							{/each}
						</select>
					</div>

					<!-- Function -->
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
									<span class="text-xs text-amber-600">No records to parse</span>
								{/if}
							</div>
						{/if}
						{#if sessionIdPreview}
							<p class="text-xs text-gray-400 mt-2 font-mono">{sessionIdPreview}</p>
						{/if}
					</div>

					{#if createError}
						<div class="rounded-md bg-red-50 p-3">
							<p class="text-sm text-red-700">{createError}</p>
						</div>
					{/if}
				</div>

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
							Create LAT Session
						{/if}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
