<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import {
		getAffectedLaws,
		batchReparse,
		clearAffectedLaws,
		updateEnactingLinks,
		parseMetadata,
		saveCascadeMetadata,
		parseOneStreamAsync,
		confirmRecord,
		type AffectedLaw,
		type AffectedLawsResult,
		type BatchReparseResult,
		type UpdateEnactingLinksResult,
		type ParseMetadataResult,
		type ParseStage
	} from '$lib/api/scraper';

	export let sessionId: string;
	export let open: boolean = false;

	const MIN_REPARSE_STAGES: ParseStage[] = ['amended_by', 'repeal_revoke'];

	const dispatch = createEventDispatcher<{
		close: void;
		complete: { reparsed: number; errors: number; enactingUpdated: number };
		reviewLaws: { laws: AffectedLaw[]; stages?: ParseStage[] };
	}>();

	// State
	let fullReparse = false;
	let loading = true;
	let error: string | null = null;
	let affectedLaws: AffectedLawsResult | null = null;
	let reparseInProgress = false;
	let reparseResults: BatchReparseResult | null = null;

	// Enacting links state
	let enactingUpdateInProgress = false;
	let enactingResults: UpdateEnactingLinksResult | null = null;

	// Not-in-DB metadata state
	let metadataResults: Map<string, ParseMetadataResult['record']> = new Map();
	let metadataFetching: Set<string> = new Set();
	let metadataErrors: Map<string, string> = new Map();

	// Selection state for individual processing
	let selectedInDb: Set<string> = new Set();
	let selectedNotInDb: Set<string> = new Set();
	let selectedEnactingParents: Set<string> = new Set();

	// Layer filtering state
	let selectedLayer: number | null = null;

	// Auto re-parse state
	let autoReparseActive = false;
	let autoReparseCancelled = false;
	let autoReparseStreamCancel: (() => void) | null = null;
	let autoReparseProgress: {
		current: number;
		total: number;
		currentName: string;
		successes: number;
		errors: number;
		errorDetails: Array<{ name: string; message: string }>;
	} | null = null;

	// Load affected laws when modal opens
	$: if (open && sessionId) {
		loadAffectedLaws();
	}

	async function loadAffectedLaws(preserveResults = false) {
		loading = true;
		error = null;
		if (!preserveResults) {
			reparseResults = null;
			enactingResults = null;
		}
		try {
			affectedLaws = await getAffectedLaws(sessionId);
			// Select all by default
			selectedInDb = new Set(affectedLaws.in_db.map((l) => l.name));
			selectedNotInDb = new Set(affectedLaws.not_in_db.map((l) => l.name));
			selectedEnactingParents = new Set(affectedLaws.enacting_parents_in_db.map((l) => l.name));

			// Pre-populate metadata from persisted cascade entries
			for (const law of affectedLaws.not_in_db) {
				if (law.metadata && !metadataResults.has(law.name)) {
					metadataResults.set(law.name, law.metadata as ParseMetadataResult['record']);
				}
			}
			metadataResults = metadataResults;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load affected laws';
		} finally {
			loading = false;
		}
	}

	// Review mode: opens ParseReviewModal for each law (default)
	// Uses filteredInDb to respect layer filter
	function handleReviewSelected() {
		if (selectedInDb.size === 0 || !affectedLaws) return;

		// Filter from filteredInDb (layer-filtered) not affectedLaws.in_db (all)
		const selectedLaws = filteredInDb.filter((law) => selectedInDb.has(law.name));
		if (selectedLaws.length === 0) return;

		const stages = fullReparse ? undefined : MIN_REPARSE_STAGES;
		dispatch('reviewLaws', { laws: selectedLaws, stages });
	}

	function handleReviewAll() {
		if (!affectedLaws || filteredInDb.length === 0) return;

		const stages = fullReparse ? undefined : MIN_REPARSE_STAGES;
		// Use filteredInDb to respect layer filter
		dispatch('reviewLaws', { laws: filteredInDb, stages });
	}

	// Auto-save mode: batch re-parse without review (kept for future use)
	// Uses filteredInDb to respect layer filter
	async function handleReparseAll() {
		if (!affectedLaws || filteredInDb.length === 0) return;

		reparseInProgress = true;
		error = null;
		try {
			// Pass filtered law names to respect layer filter
			const names = filteredInDb.map((l) => l.name);
			reparseResults = await batchReparse(sessionId, names);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to batch re-parse';
		} finally {
			reparseInProgress = false;
		}
	}

	async function handleReparseSelected() {
		if (selectedInDb.size === 0) return;

		reparseInProgress = true;
		error = null;
		try {
			// Filter to only selected laws in the current layer filter
			const selectedInFilteredLayer = filteredInDb
				.filter((law) => selectedInDb.has(law.name))
				.map((l) => l.name);
			if (selectedInFilteredLayer.length === 0) return;
			reparseResults = await batchReparse(sessionId, selectedInFilteredLayer);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to batch re-parse';
		} finally {
			reparseInProgress = false;
		}
	}

	// Auto re-parse: loop through selected laws, parse via SSE, auto-confirm
	async function handleAutoReparse() {
		if (selectedInDb.size === 0 || !affectedLaws) return;

		const selectedLaws = filteredInDb.filter((law) => selectedInDb.has(law.name));
		if (selectedLaws.length === 0) return;

		const stages = fullReparse ? undefined : MIN_REPARSE_STAGES;

		autoReparseActive = true;
		autoReparseCancelled = false;
		autoReparseProgress = {
			current: 0,
			total: selectedLaws.length,
			currentName: '',
			successes: 0,
			errors: 0,
			errorDetails: []
		};

		for (let i = 0; i < selectedLaws.length; i++) {
			if (autoReparseCancelled) break;

			const law = selectedLaws[i];
			const parseName = lawNameToParseFormat(law.name);

			autoReparseProgress = {
				...autoReparseProgress!,
				current: i + 1,
				currentName: law.name
			};

			try {
				// Parse via SSE stream
				const { promise, cancel } = parseOneStreamAsync(sessionId, parseName, stages);
				autoReparseStreamCancel = cancel;
				const result = await promise;
				autoReparseStreamCancel = null;

				if (autoReparseCancelled) break;

				// Auto-confirm: persist to DB
				if (result.record) {
					await confirmRecord(sessionId, law.name, result.record);
					autoReparseProgress = {
						...autoReparseProgress!,
						successes: autoReparseProgress!.successes + 1
					};
				} else {
					autoReparseProgress = {
						...autoReparseProgress!,
						errors: autoReparseProgress!.errors + 1,
						errorDetails: [
							...autoReparseProgress!.errorDetails,
							{ name: law.name, message: 'No record data returned' }
						]
					};
				}
			} catch (err) {
				autoReparseStreamCancel = null;
				autoReparseProgress = {
					...autoReparseProgress!,
					errors: autoReparseProgress!.errors + 1,
					errorDetails: [
						...autoReparseProgress!.errorDetails,
						{ name: law.name, message: err instanceof Error ? err.message : String(err) }
					]
				};
			}
		}

		autoReparseActive = false;
		autoReparseStreamCancel = null;

		// Refresh cascade data to reflect processed entries
		await loadAffectedLaws(true);
	}

	function handleCancelAutoReparse() {
		autoReparseCancelled = true;
		autoReparseStreamCancel?.();
		autoReparseStreamCancel = null;
		autoReparseActive = false;
	}

	// Convert law name like "UK_uksi_2025_622" to format needed for parseOne
	function lawNameToParseFormat(name: string): string {
		const parts = name.split('_');
		if (parts.length === 4 && parts[0] === 'UK') {
			return `${parts[1]}/${parts[2]}/${parts[3]}`;
		}
		return name;
	}

	// Uses filteredEnactingParents to respect layer filter
	async function handleUpdateEnactingAll() {
		if (!affectedLaws || filteredEnactingParents.length === 0) return;

		enactingUpdateInProgress = true;
		error = null;
		try {
			// Pass filtered names to respect layer filter
			const names = filteredEnactingParents.map((l) => l.name);
			enactingResults = await updateEnactingLinks(sessionId, names);
			// Reload to reflect processed entries removed from active lists
			await loadAffectedLaws(true);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to update enacting links';
		} finally {
			enactingUpdateInProgress = false;
		}
	}

	async function handleUpdateEnactingSelected() {
		if (selectedEnactingParents.size === 0) return;

		enactingUpdateInProgress = true;
		error = null;
		try {
			// Filter to only selected parents in the current layer filter
			const selectedInFilteredLayer = filteredEnactingParents
				.filter((law) => selectedEnactingParents.has(law.name))
				.map((l) => l.name);
			if (selectedInFilteredLayer.length === 0) return;
			enactingResults = await updateEnactingLinks(sessionId, selectedInFilteredLayer);
			// Reload to reflect processed entries removed from active lists
			await loadAffectedLaws(true);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to update enacting links';
		} finally {
			enactingUpdateInProgress = false;
		}
	}

	// --- Not-in-DB handlers ---
	// Uses filteredNotInDb to respect layer filter
	async function handleFetchMetadataSelected() {
		if (selectedNotInDb.size === 0) return;

		// Filter to only selected laws in the current layer filter
		const names = filteredNotInDb
			.filter((law) => selectedNotInDb.has(law.name))
			.map((l) => l.name);
		if (names.length === 0) return;

		metadataFetching = new Set(names);
		metadataErrors = new Map();

		for (const name of names) {
			try {
				const result = await parseMetadata(sessionId, name);
				metadataResults.set(name, result.record);
				metadataResults = metadataResults; // Trigger reactivity
				// Persist to cascade entry so it survives modal reopen
				saveCascadeMetadata(sessionId, name, result.record);
			} catch (e) {
				metadataErrors.set(name, e instanceof Error ? e.message : 'Failed');
				metadataErrors = metadataErrors;
			} finally {
				metadataFetching.delete(name);
				metadataFetching = metadataFetching;
			}
		}
	}

	function handleReviewNotInDbSelected() {
		if (selectedNotInDb.size === 0 || !affectedLaws) return;

		// Filter from filteredNotInDb to respect layer filter
		const selectedLaws: AffectedLaw[] = filteredNotInDb
			.filter((law) => selectedNotInDb.has(law.name))
			.map((law) => {
				const meta = metadataResults.get(law.name);
				return {
					...law,
					title_en: meta?.title_en || law.title_en || law.name,
					type_code: meta?.type_code || law.type_code,
					year: meta?.year || law.year
				};
			});
		if (selectedLaws.length === 0) return;
		dispatch('reviewLaws', { laws: selectedLaws });
	}

	async function handleClearAndClose() {
		try {
			await clearAffectedLaws(sessionId);
		} catch (e) {
			console.error('Failed to clear affected laws:', e);
		}

		dispatch('complete', {
			reparsed: reparseResults?.success || 0,
			errors: reparseResults?.errors || 0,
			enactingUpdated: enactingResults?.success || 0
		});
	}

	function handleClose() {
		dispatch('close');
	}

	function toggleInDbSelection(name: string) {
		if (selectedInDb.has(name)) {
			selectedInDb.delete(name);
		} else {
			selectedInDb.add(name);
		}
		selectedInDb = selectedInDb; // Trigger reactivity
	}

	function toggleNotInDbSelection(name: string) {
		if (selectedNotInDb.has(name)) {
			selectedNotInDb.delete(name);
		} else {
			selectedNotInDb.add(name);
		}
		selectedNotInDb = selectedNotInDb; // Trigger reactivity
	}

	function selectAllInDb() {
		// Select all from the filtered list
		selectedInDb = new Set(filteredInDb.map((l) => l.name));
	}

	function selectNoneInDb() {
		// Deselect all from the filtered list
		const filteredNames = new Set(filteredInDb.map((l) => l.name));
		selectedInDb = new Set([...selectedInDb].filter((name) => !filteredNames.has(name)));
	}

	function toggleEnactingParentSelection(name: string) {
		if (selectedEnactingParents.has(name)) {
			selectedEnactingParents.delete(name);
		} else {
			selectedEnactingParents.add(name);
		}
		selectedEnactingParents = selectedEnactingParents; // Trigger reactivity
	}

	function selectAllEnactingParents() {
		// Select all from the filtered list
		selectedEnactingParents = new Set(filteredEnactingParents.map((l) => l.name));
	}

	function selectNoneEnactingParents() {
		// Deselect all from the filtered list
		const filteredNames = new Set(filteredEnactingParents.map((l) => l.name));
		selectedEnactingParents = new Set([...selectedEnactingParents].filter((name) => !filteredNames.has(name)));
	}

	function getStatusIcon(status: string): string {
		switch (status) {
			case 'success':
				return 'text-green-600';
			case 'unchanged':
				return 'text-gray-500';
			case 'skipped':
				return 'text-yellow-600';
			default:
				return 'text-red-600';
		}
	}

	function getStatusSymbol(status: string): string {
		switch (status) {
			case 'success':
				return '+';
			case 'unchanged':
				return '=';
			case 'skipped':
				return '-';
			default:
				return 'x';
		}
	}

	function toggleLayerFilter(layer: number) {
		if (selectedLayer === layer) {
			// Deselect layer - show all
			selectedLayer = null;
		} else {
			// Select this layer
			selectedLayer = layer;
		}
	}

	// Filter laws by selected layer
	$: filteredInDb =
		affectedLaws && selectedLayer !== null
			? affectedLaws.in_db.filter((law) => law.layer === selectedLayer)
			: affectedLaws?.in_db || [];

	$: filteredNotInDb =
		affectedLaws && selectedLayer !== null
			? affectedLaws.not_in_db.filter((law) => law.layer === selectedLayer)
			: affectedLaws?.not_in_db || [];

	$: filteredEnactingParents =
		affectedLaws && selectedLayer !== null
			? affectedLaws.enacting_parents_in_db.filter((law) => law.layer === selectedLayer)
			: affectedLaws?.enacting_parents_in_db || [];

	// Count selected items from the filtered lists
	$: selectedInDbCount = [...selectedInDb].filter((name) =>
		filteredInDb.some((law) => law.name === name)
	).length;

	$: selectedNotInDbCount = [...selectedNotInDb].filter((name) =>
		filteredNotInDb.some((law) => law.name === name)
	).length;

	$: selectedEnactingParentsCount = [...selectedEnactingParents].filter((name) =>
		filteredEnactingParents.some((law) => law.name === name)
	).length;
</script>

{#if open}
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
		role="dialog"
		aria-modal="true"
	>
		<div class="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
			<!-- Header -->
			<div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
				<div>
					<h2 class="text-xl font-semibold text-gray-900">Cascade Update</h2>
					<p class="text-sm text-gray-500 mt-1">
						Session: {sessionId}
						{#if affectedLaws}
							| {affectedLaws.source_count} law{affectedLaws.source_count !== 1 ? 's' : ''} persisted
							{#if affectedLaws.current_layer}
								| Layer {affectedLaws.current_layer}
							{/if}
						{/if}
					</p>
				</div>
				<button
					on:click={handleClose}
					class="text-gray-400 hover:text-gray-600 text-2xl leading-none"
					aria-label="Close"
				>
					&times;
				</button>
			</div>

			<!-- Content -->
			<div class="flex-1 overflow-y-auto px-6 py-4">
				{#if loading}
					<div class="flex items-center justify-center py-12">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
						<span class="ml-3 text-gray-600">Loading affected laws...</span>
					</div>
				{:else if error}
					<div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
						{error}
					</div>
				{:else if affectedLaws}
					<!-- Summary -->
					<div class="mb-6">
						<div class="grid grid-cols-3 gap-4 mb-3">
							<div class="bg-blue-50 rounded-lg p-4 text-center">
								<div class="text-2xl font-bold text-blue-700">{affectedLaws.total_affected}</div>
								<div class="text-sm text-blue-600">Amending/Rescinding</div>
							</div>
							<div class="bg-green-50 rounded-lg p-4 text-center">
								<div class="text-2xl font-bold text-green-700">{affectedLaws.in_db_count}</div>
								<div class="text-sm text-green-600">In DB (Re-parse)</div>
							</div>
							<div class="bg-yellow-50 rounded-lg p-4 text-center">
								<div class="text-2xl font-bold text-yellow-700">{affectedLaws.not_in_db_count}</div>
								<div class="text-sm text-yellow-600">Not in DB</div>
							</div>
						</div>
						{#if affectedLaws.layers && affectedLaws.layers.length > 1}
							<div class="flex items-center gap-2 mb-3 text-sm">
								<span class="text-gray-500 font-medium">Layers:</span>
								{#each affectedLaws.layers as l}
									<button
										on:click={() => toggleLayerFilter(l.layer)}
										class="px-2 py-0.5 rounded text-xs font-medium cursor-pointer transition-all hover:ring-2 hover:ring-blue-400 {selectedLayer === l.layer ? 'bg-blue-600 text-white ring-2 ring-blue-400' : selectedLayer === null && l.layer === affectedLaws.current_layer ? 'bg-blue-100 text-blue-700 ring-1 ring-blue-300' : 'bg-gray-100 text-gray-600'}"
									>
										L{l.layer}: {l.count}
									</button>
								{/each}
								{#if affectedLaws.deferred_count > 0}
									<span class="px-2 py-0.5 rounded text-xs font-medium bg-amber-100 text-amber-700">
										{affectedLaws.deferred_count} deferred
									</span>
								{/if}
								{#if selectedLayer !== null}
									<button
										on:click={() => (selectedLayer = null)}
										class="px-2 py-0.5 rounded text-xs font-medium bg-gray-200 text-gray-700 hover:bg-gray-300"
									>
										Show All
									</button>
								{/if}
							</div>
						{/if}

						{#if affectedLaws.total_enacting_parents > 0}
							<div class="grid grid-cols-3 gap-4">
								<div class="bg-purple-50 rounded-lg p-4 text-center">
									<div class="text-2xl font-bold text-purple-700">
										{affectedLaws.total_enacting_parents}
									</div>
									<div class="text-sm text-purple-600">Enacting Parents</div>
								</div>
								<div class="bg-purple-50 rounded-lg p-4 text-center">
									<div class="text-2xl font-bold text-purple-700">
										{affectedLaws.enacting_parents_in_db_count}
									</div>
									<div class="text-sm text-purple-600">In DB (Direct Update)</div>
								</div>
								<div class="bg-purple-50 rounded-lg p-4 text-center opacity-60">
									<div class="text-2xl font-bold text-purple-700">
										{affectedLaws.enacting_parents_not_in_db_count}
									</div>
									<div class="text-sm text-purple-600">Not in DB</div>
								</div>
							</div>
						{/if}
					</div>

					<!-- Re-parse Results -->
					{#if reparseResults}
						<div class="mb-6 bg-gray-50 rounded-lg p-4">
							<h3 class="font-semibold text-gray-900 mb-2">
								Re-parse Results (Amending/Rescinding)
							</h3>
							<div class="flex gap-4 mb-3">
								<span class="text-green-600">{reparseResults.success} success</span>
								<span class="text-red-600">{reparseResults.errors} errors</span>
								<span class="text-gray-500">{reparseResults.total} total</span>
							</div>
							<div class="max-h-32 overflow-y-auto text-sm font-mono">
								{#each reparseResults.results as result}
									<div class="flex items-center gap-2">
										<span class={getStatusIcon(result.status)}
											>[{getStatusSymbol(result.status)}]</span
										>
										<span class="text-gray-700">{result.name}</span>
										{#if result.status === 'error'}
											<span class="text-red-500 text-xs">- {result.message}</span>
										{/if}
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<!-- Enacting Update Results -->
					{#if enactingResults}
						<div class="mb-6 bg-purple-50 rounded-lg p-4">
							<h3 class="font-semibold text-gray-900 mb-2">Enacting Links Update Results</h3>
							<div class="flex gap-4 mb-3">
								<span class="text-green-600">{enactingResults.success} updated</span>
								<span class="text-gray-500">{enactingResults.unchanged} unchanged</span>
								<span class="text-red-600">{enactingResults.errors} errors</span>
								<span class="text-gray-400">{enactingResults.total} total</span>
							</div>
							<div class="max-h-32 overflow-y-auto text-sm font-mono">
								{#each enactingResults.results as result}
									<div class="flex items-center gap-2">
										<span class={getStatusIcon(result.status)}
											>[{getStatusSymbol(result.status)}]</span
										>
										<span class="text-gray-700">{result.name}</span>
										{#if result.status === 'success' && result.added_count}
											<span class="text-green-600 text-xs">+{result.added_count} laws added</span>
										{:else if result.status === 'unchanged'}
											<span class="text-gray-500 text-xs">- already up to date</span>
										{:else if result.status === 'error'}
											<span class="text-red-500 text-xs">- {result.message}</span>
										{/if}
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<!-- Auto Re-parse Progress -->
					{#if autoReparseProgress}
						<div class="mb-6 bg-blue-50 border border-blue-200 rounded-lg p-4">
							<div class="flex items-center justify-between mb-2">
								<h4 class="text-sm font-medium text-blue-900">
									{#if autoReparseActive}
										Auto Re-parse in Progress
									{:else}
										Auto Re-parse Complete
									{/if}
								</h4>
								{#if autoReparseActive}
									<button
										on:click={handleCancelAutoReparse}
										class="text-sm text-red-600 hover:text-red-800 font-medium"
									>
										Cancel
									</button>
								{:else}
									<button
										on:click={() => (autoReparseProgress = null)}
										class="text-sm text-gray-500 hover:text-gray-700"
									>
										Dismiss
									</button>
								{/if}
							</div>
							{#if autoReparseActive}
								<div class="text-sm text-blue-800 mb-2">
									Processing {autoReparseProgress.current} of {autoReparseProgress.total}:
									<span class="font-mono">{autoReparseProgress.currentName}</span>
								</div>
							{/if}
							<div class="w-full bg-blue-200 rounded-full h-2 mb-2">
								<div
									class="bg-blue-600 h-2 rounded-full transition-all duration-300"
									style="width: {(autoReparseProgress.current / autoReparseProgress.total) * 100}%"
								/>
							</div>
							<div class="text-xs text-blue-700">
								{autoReparseProgress.successes} succeeded{#if autoReparseProgress.errors > 0},
									<span class="text-red-600">{autoReparseProgress.errors} failed</span>{/if}
							</div>
							{#if autoReparseProgress.errorDetails.length > 0}
								<div class="mt-2 max-h-24 overflow-y-auto text-xs font-mono">
									{#each autoReparseProgress.errorDetails as err}
										<div class="text-red-600">[x] {err.name}: {err.message}</div>
									{/each}
								</div>
							{/if}
						</div>
					{/if}

					<!-- Laws in Database -->
					{#if affectedLaws.in_db_count > 0}
						<div class="mb-6">
							<div class="flex justify-between items-center mb-2">
								<h3 class="font-semibold text-gray-900">
									Affected Laws in Database ({filteredInDb.length}{#if selectedLayer !== null} of {affectedLaws.in_db_count}{/if})
								</h3>
								<div class="flex items-center gap-4 text-sm">
									<label class="flex items-center gap-2 cursor-pointer" title={fullReparse
										? 'All 7 stages will be re-parsed'
										: 'Only amended_by + repeal_revoke stages'}>
										<span class="text-gray-500">{fullReparse ? 'Full' : 'Min'}</span>
										<button
											type="button"
											role="switch"
											aria-checked={fullReparse}
											on:click={() => fullReparse = !fullReparse}
											class="relative inline-flex h-5 w-9 items-center rounded-full transition-colors {fullReparse ? 'bg-blue-600' : 'bg-gray-300'}"
										>
											<span class="inline-block h-3.5 w-3.5 transform rounded-full bg-white transition-transform {fullReparse ? 'translate-x-4.5' : 'translate-x-0.5'}" />
										</button>
									</label>
									<span class="text-gray-300">|</span>
									<button on:click={selectAllInDb} class="text-blue-600 hover:underline">
										Select All
									</button>
									<span class="text-gray-300">|</span>
									<button on:click={selectNoneInDb} class="text-blue-600 hover:underline">
										Select None
									</button>
								</div>
							</div>
							<div class="border border-gray-200 rounded-lg max-h-48 overflow-y-auto">
								{#each filteredInDb as law}
									<div
										class="flex items-center gap-3 px-4 py-2 border-b border-gray-100 last:border-b-0 hover:bg-gray-50"
									>
										<input
											type="checkbox"
											checked={selectedInDb.has(law.name)}
											on:change={() => toggleInDbSelection(law.name)}
											class="h-4 w-4 text-blue-600 rounded"
										/>
										<div class="flex-1 min-w-0">
											<div class="font-mono text-sm text-gray-600">{law.name}</div>
											{#if law.title_en}
												<div class="text-sm text-gray-800 truncate">{law.title_en}</div>
											{/if}
										</div>
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<!-- Laws NOT in Database -->
					{#if affectedLaws.not_in_db_count > 0}
						<div class="mb-6">
							<div class="flex justify-between items-center mb-2">
								<h3 class="font-semibold text-gray-900">
									Affected Laws <span class="text-yellow-600">NOT</span> in Database ({filteredNotInDb.length}{#if selectedLayer !== null} of {affectedLaws.not_in_db_count}{/if})
								</h3>
								<div class="flex gap-2 text-sm">
									<button on:click={() => { if (affectedLaws) selectedNotInDb = new Set(affectedLaws.not_in_db.map(l => l.name)); }} class="text-yellow-600 hover:underline">
										Select All
									</button>
									<span class="text-gray-300">|</span>
									<button on:click={() => { selectedNotInDb = new Set(); }} class="text-yellow-600 hover:underline">
										Select None
									</button>
								</div>
							</div>
							<p class="text-sm text-gray-500 mb-2">
								These laws need to be scraped and added. Fetch metadata first, then parse & review.
							</p>
							<div
								class="border border-yellow-200 bg-yellow-50 rounded-lg max-h-48 overflow-y-auto"
							>
								{#each filteredNotInDb as law}
									{@const meta = metadataResults.get(law.name)}
									{@const isFetching = metadataFetching.has(law.name)}
									{@const fetchError = metadataErrors.get(law.name)}
									<div
										class="flex items-center gap-3 px-4 py-2 border-b border-yellow-100 last:border-b-0 hover:bg-yellow-100"
									>
										<input
											type="checkbox"
											checked={selectedNotInDb.has(law.name)}
											on:change={() => toggleNotInDbSelection(law.name)}
											class="h-4 w-4 text-yellow-600 rounded"
										/>
										<div class="flex-1 min-w-0">
											<div class="font-mono text-sm text-gray-700">{law.name}</div>
											{#if isFetching}
												<div class="text-xs text-yellow-600 animate-pulse">Fetching metadata...</div>
											{:else if fetchError}
												<div class="text-xs text-red-500">{fetchError}</div>
											{:else if meta}
												<div class="text-sm text-gray-800 truncate">{meta.title_en}</div>
												<div class="text-xs text-gray-500">
													{meta.type_code} {meta.year}/{meta.number}
												</div>
											{/if}
										</div>
										{#if meta}
											<span class="text-xs text-green-600 bg-green-100 px-2 py-0.5 rounded">Ready</span>
										{/if}
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<!-- Enacting Parents in Database -->
					{#if affectedLaws.enacting_parents_in_db_count > 0}
						<div class="mb-6">
							<div class="flex justify-between items-center mb-2">
								<h3 class="font-semibold text-gray-900">
									<span class="text-purple-600">Enacting Parents</span> in Database ({filteredEnactingParents.length}{#if selectedLayer !== null} of {affectedLaws.enacting_parents_in_db_count}{/if})
								</h3>
								<div class="flex gap-2 text-sm">
									<button
										on:click={selectAllEnactingParents}
										class="text-purple-600 hover:underline"
									>
										Select All
									</button>
									<span class="text-gray-300">|</span>
									<button
										on:click={selectNoneEnactingParents}
										class="text-purple-600 hover:underline"
									>
										Select None
									</button>
								</div>
							</div>
							<p class="text-sm text-gray-500 mb-2">
								These parent laws need their <code class="bg-gray-100 px-1 rounded">enacting</code> arrays
								updated with new child laws.
							</p>
							<div
								class="border border-purple-200 bg-purple-50 rounded-lg max-h-48 overflow-y-auto"
							>
								{#each filteredEnactingParents as law}
									<div
										class="flex items-center gap-3 px-4 py-2 border-b border-purple-100 last:border-b-0 hover:bg-purple-100"
									>
										<input
											type="checkbox"
											checked={selectedEnactingParents.has(law.name)}
											on:change={() => toggleEnactingParentSelection(law.name)}
											class="h-4 w-4 text-purple-600 rounded"
										/>
										<div class="flex-1 min-w-0">
											<div class="font-mono text-sm text-gray-600">{law.name}</div>
											{#if law.title_en}
												<div class="text-sm text-gray-800 truncate">{law.title_en}</div>
											{/if}
										</div>
										{#if law.current_enacting_count !== undefined}
											<div class="text-xs text-purple-600 bg-purple-100 px-2 py-1 rounded">
												{law.current_enacting_count} children
											</div>
										{/if}
									</div>
								{/each}
							</div>
						</div>
					{/if}

					<!-- No affected laws -->
					{#if affectedLaws.total_affected === 0 && affectedLaws.total_enacting_parents === 0}
						<div class="text-center py-8 text-gray-500">
							No affected laws to update. The cascade is complete.
						</div>
					{/if}
				{/if}
			</div>

			<!-- Footer -->
			<div class="px-6 py-4 border-t border-gray-200 flex justify-between items-center">
				<div class="text-sm text-gray-500 flex flex-col gap-1">
					{#if selectedInDbCount > 0}
						<span>{selectedInDbCount} selected for re-parse</span>
					{/if}
					{#if selectedNotInDbCount > 0}
						<span class="text-yellow-600">{selectedNotInDbCount} new laws selected</span>
					{/if}
					{#if selectedEnactingParentsCount > 0}
						<span class="text-purple-600">{selectedEnactingParentsCount} parent laws selected</span>
					{/if}
				</div>
				<div class="flex gap-3 flex-wrap justify-end">
					<!-- Review buttons (amending/rescinding) - opens ParseReviewModal for each -->
					{#if affectedLaws && affectedLaws.in_db_count > 0 && !reparseResults}
						<button
							on:click={handleReviewSelected}
							disabled={reparseInProgress || enactingUpdateInProgress || autoReparseActive || selectedInDbCount === 0}
							class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Review Selected ({selectedInDbCount})
						</button>
						<button
							on:click={handleReviewAll}
							disabled={reparseInProgress || enactingUpdateInProgress || autoReparseActive}
							class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Review All ({filteredInDb.length})
						</button>
						<button
							on:click={handleAutoReparse}
							disabled={reparseInProgress || enactingUpdateInProgress || autoReparseActive || selectedInDbCount === 0}
							class="px-4 py-2 bg-emerald-600 text-white rounded-lg hover:bg-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{#if autoReparseActive}
								Auto Re-parsing...
							{:else}
								Auto Re-parse ({selectedInDbCount})
							{/if}
						</button>
					{/if}

					<!-- Not-in-DB buttons: Get Metadata + Parse & Review -->
					{#if affectedLaws && affectedLaws.not_in_db_count > 0}
						<button
							on:click={handleFetchMetadataSelected}
							disabled={metadataFetching.size > 0 || selectedNotInDbCount === 0}
							class="px-4 py-2 bg-yellow-500 text-white rounded-lg hover:bg-yellow-600 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{#if metadataFetching.size > 0}
								Fetching ({metadataFetching.size})...
							{:else}
								Get Metadata ({selectedNotInDbCount})
							{/if}
						</button>
						<button
							on:click={handleReviewNotInDbSelected}
							disabled={metadataFetching.size > 0 || selectedNotInDbCount === 0}
							class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Parse &amp; Review ({selectedNotInDbCount})
						</button>
					{/if}

					<!-- Enacting links update buttons -->
					{#if affectedLaws && affectedLaws.enacting_parents_in_db_count > 0 && !enactingResults}
						<button
							on:click={handleUpdateEnactingSelected}
							disabled={reparseInProgress ||
								enactingUpdateInProgress ||
								selectedEnactingParentsCount === 0}
							class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{#if enactingUpdateInProgress}
								Updating...
							{:else}
								Update Enacting ({selectedEnactingParentsCount})
							{/if}
						</button>
						<button
							on:click={handleUpdateEnactingAll}
							disabled={reparseInProgress || enactingUpdateInProgress}
							class="px-4 py-2 bg-purple-700 text-white rounded-lg hover:bg-purple-800 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{#if enactingUpdateInProgress}
								Updating...
							{:else}
								Update All Parents ({filteredEnactingParents.length})
							{/if}
						</button>
					{/if}

					<!-- Done/Close buttons -->
					{#if affectedLaws}
						{@const allDone =
							(reparseResults || affectedLaws.in_db_count === 0) &&
							(enactingResults || affectedLaws.enacting_parents_in_db_count === 0)}
						{@const nothingToDo =
							affectedLaws.total_affected === 0 && affectedLaws.total_enacting_parents === 0}
						{#if allDone || nothingToDo}
							<button
								on:click={handleClearAndClose}
								class="px-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-900"
							>
								Done
							</button>
						{:else}
							<button
								on:click={handleClose}
								class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
							>
								Close
							</button>
						{/if}
					{:else}
						<button
							on:click={handleClose}
							class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50"
						>
							Close
						</button>
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}
