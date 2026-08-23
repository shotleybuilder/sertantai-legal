<script lang="ts">
	import { previewLatSession, type LatSessionFilters } from '$lib/api/lat';
	import { useFamilyOptionsQuery } from '$lib/query/scraper';
	import { useCreateLatSessionMutation } from '$lib/query/lat';

	let {
		open = $bindable(false),
		onclose,
		oncreated
	}: {
		open?: boolean;
		onclose?: () => void;
		oncreated?: (detail: { session_id: string }) => void;
	} = $props();

	const familyOptionsQuery = useFamilyOptionsQuery();
	const createMutation = useCreateLatSessionMutation();

	// Filter state
	let selectedFamily = $state('');
	let selectedTypeCode = $state('');
	let selectedFunction = $state('');
	let selectedQueueReason: '' | 'missing' | 'stale' = $state('');

	const liveOptions = [
		{ value: '✔ In force', label: 'In force' },
		{ value: '⭕ Part Revocation / Repeal', label: 'Part Revoked' },
		{ value: '❌ Revoked / Repealed / Abolished', label: 'Revoked' }
	];
	// Default: all checked (no live filter sent — backend excludes revoked by default)
	let selectedLive: string[] = $state([
		'✔ In force',
		'⭕ Part Revocation / Repeal',
		'❌ Revoked / Repealed / Abolished'
	]);

	// Preview state
	let previewCount: number | null = $state(null);
	let previewLoading = $state(false);
	let previewError = $state('');

	// Creating state
	let creating = $state(false);
	let createError = $state('');

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

	const functionOptions = ['Amending', 'Revoking', 'Commencing', 'Enacting'];

	const queueReasonOptions = [
		{ value: '', label: 'All (Missing + Stale)' },
		{ value: 'missing', label: 'Missing — no LAT rows' },
		{ value: 'stale', label: 'Stale — LRT updated after LAT' }
	];

	// Build session ID preview
	let sessionIdPreview = $derived(
		(() => {
			if (!selectedFamily) return '';
			const parts = ['lat-parse', slugify(selectedFamily)];
			if (selectedTypeCode) parts.push(selectedTypeCode);
			if (selectedFunction) parts.push(selectedFunction.toLowerCase());
			const today = new Date().toISOString().split('T')[0];
			parts.push(today);
			return parts.join('-');
		})()
	);

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
		if (selectedLive.length > 0 && selectedLive.length < liveOptions.length) {
			filters.live = selectedLive;
		}
		return filters;
	}

	// Preview count — debounced
	let _filterKey = $derived([
		selectedFamily,
		selectedTypeCode,
		selectedFunction,
		selectedQueueReason,
		selectedLive
	]);
	let previewTimeout: ReturnType<typeof setTimeout>;
	$effect(() => {
		// Access _filterKey to track dependencies
		void _filterKey;
		if (selectedFamily) {
			clearTimeout(previewTimeout);
			previewTimeout = setTimeout(fetchPreview, 300);
		} else {
			previewCount = null;
			previewError = '';
		}
	});

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
			const session = await createMutation.mutateAsync(buildFilters());
			oncreated?.({ session_id: session.session_id });
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
		selectedLive = [
			'✔ In force',
			'⭕ Part Revocation / Repeal',
			'❌ Revoked / Repealed / Abolished'
		];
		previewCount = null;
		previewError = '';
		createError = '';
		onclose?.();
	}
</script>

{#if open}
	<!-- svelte-ignore a11y_click_events_have_key_events -->
	<!-- svelte-ignore a11y_no_static_element_interactions -->
	<div class="fixed inset-0 z-50 overflow-y-auto">
		<div class="flex items-center justify-center min-h-screen px-4">
			<div class="fixed inset-0 bg-black bg-opacity-50" onclick={handleClose}></div>

			<div class="relative bg-white rounded-lg shadow-xl max-w-lg w-full p-6">
				<h2 class="text-lg font-semibold text-gray-900 mb-4">Parse LAT Family</h2>
				<p class="text-sm text-gray-500 mb-5">
					Create a LAT parse session. Select a family and optional filters to choose which laws to
					parse for legal articles and annotations.
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
							disabled={familyOptionsQuery.isLoading}
							class="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
						>
							<option value=""
								>{familyOptionsQuery.isLoading
									? 'Loading families...'
									: '-- Select Family --'}</option
							>
							{#if familyOptionsQuery.data?.grouped}
								<optgroup label="Health & Safety">
									{#each familyOptionsQuery.data.grouped.health_safety || [] as opt}
										<option value={opt}>{opt}</option>
									{/each}
								</optgroup>
								<optgroup label="Environment">
									{#each familyOptionsQuery.data.grouped.environment || [] as opt}
										<option value={opt}>{opt}</option>
									{/each}
								</optgroup>
								<optgroup label="HR">
									{#each familyOptionsQuery.data.grouped.hr || [] as opt}
										<option value={opt}>{opt}</option>
									{/each}
								</optgroup>
							{/if}
						</select>
						{#if familyOptionsQuery.isError}
							<p class="mt-1 text-xs text-red-600">
								Failed to load families: {familyOptionsQuery.error?.message}
							</p>
						{/if}
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

					<!-- Live Status -->
					<div>
						<span class="block text-sm font-medium text-gray-700 mb-1">Live Status</span>
						<div class="flex flex-wrap gap-3">
							{#each liveOptions as opt}
								<label class="inline-flex items-center gap-1.5 text-sm">
									<input
										type="checkbox"
										value={opt.value}
										checked={selectedLive.includes(opt.value)}
										onchange={(e) => {
											if (e.currentTarget.checked) {
												selectedLive = [...selectedLive, opt.value];
											} else {
												selectedLive = selectedLive.filter((v) => v !== opt.value);
											}
										}}
										class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
									/>
									{opt.label}
								</label>
							{/each}
						</div>
					</div>

					<!-- Function -->
					<div>
						<span class="block text-sm font-medium text-gray-700 mb-1">Function</span>
						<div class="flex flex-wrap gap-2">
							{#each functionOptions as fn}
								<button
									type="button"
									class="px-3 py-1 text-sm rounded-full border {selectedFunction === fn
										? 'bg-blue-100 border-blue-500 text-blue-700'
										: 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}"
									onclick={() => (selectedFunction = selectedFunction === fn ? '' : fn)}
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
						onclick={handleClose}
					>
						Cancel
					</button>
					<button
						type="button"
						class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
						disabled={!selectedFamily || previewCount === 0 || previewCount === null || creating}
						onclick={handleCreate}
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
