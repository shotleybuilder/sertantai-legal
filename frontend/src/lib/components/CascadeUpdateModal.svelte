<script lang="ts">
	import { createEventDispatcher, onMount } from 'svelte';
	import {
		getAffectedLaws,
		batchReparse,
		clearAffectedLaws,
		updateEnactingLinks,
		type AffectedLaw,
		type AffectedLawsResult,
		type BatchReparseResult,
		type UpdateEnactingLinksResult
	} from '$lib/api/scraper';

	export let sessionId: string;
	export let open: boolean = false;

	const dispatch = createEventDispatcher<{
		close: void;
		complete: { reparsed: number; errors: number; enactingUpdated: number };
		reviewLaws: { laws: AffectedLaw[] };
	}>();

	// State
	let loading = true;
	let error: string | null = null;
	let affectedLaws: AffectedLawsResult | null = null;
	let reparseInProgress = false;
	let reparseResults: BatchReparseResult | null = null;

	// Enacting links state
	let enactingUpdateInProgress = false;
	let enactingResults: UpdateEnactingLinksResult | null = null;

	// Selection state for individual processing
	let selectedInDb: Set<string> = new Set();
	let selectedNotInDb: Set<string> = new Set();
	let selectedEnactingParents: Set<string> = new Set();

	// Load affected laws when modal opens
	$: if (open && sessionId) {
		loadAffectedLaws();
	}

	async function loadAffectedLaws() {
		loading = true;
		error = null;
		reparseResults = null;
		enactingResults = null;
		try {
			affectedLaws = await getAffectedLaws(sessionId);
			// Select all by default
			selectedInDb = new Set(affectedLaws.in_db.map((l) => l.name));
			selectedNotInDb = new Set(affectedLaws.not_in_db.map((l) => l.name));
			selectedEnactingParents = new Set(affectedLaws.enacting_parents_in_db.map((l) => l.name));
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load affected laws';
		} finally {
			loading = false;
		}
	}

	// Review mode: opens ParseReviewModal for each law (default)
	function handleReviewSelected() {
		if (selectedInDb.size === 0 || !affectedLaws) return;

		const selectedLaws = affectedLaws.in_db.filter((law) => selectedInDb.has(law.name));
		dispatch('reviewLaws', { laws: selectedLaws });
	}

	function handleReviewAll() {
		if (!affectedLaws || affectedLaws.in_db_count === 0) return;

		dispatch('reviewLaws', { laws: affectedLaws.in_db });
	}

	// Auto-save mode: batch re-parse without review (kept for future use)
	async function handleReparseAll() {
		if (!affectedLaws || affectedLaws.in_db_count === 0) return;

		reparseInProgress = true;
		error = null;
		try {
			reparseResults = await batchReparse(sessionId);
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
			reparseResults = await batchReparse(sessionId, Array.from(selectedInDb));
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to batch re-parse';
		} finally {
			reparseInProgress = false;
		}
	}

	async function handleUpdateEnactingAll() {
		if (!affectedLaws || affectedLaws.enacting_parents_in_db_count === 0) return;

		enactingUpdateInProgress = true;
		error = null;
		try {
			enactingResults = await updateEnactingLinks(sessionId);
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
			enactingResults = await updateEnactingLinks(sessionId, Array.from(selectedEnactingParents));
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to update enacting links';
		} finally {
			enactingUpdateInProgress = false;
		}
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
		if (affectedLaws) {
			selectedInDb = new Set(affectedLaws.in_db.map((l) => l.name));
		}
	}

	function selectNoneInDb() {
		selectedInDb = new Set();
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
		if (affectedLaws) {
			selectedEnactingParents = new Set(affectedLaws.enacting_parents_in_db.map((l) => l.name));
		}
	}

	function selectNoneEnactingParents() {
		selectedEnactingParents = new Set();
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

					<!-- Laws in Database -->
					{#if affectedLaws.in_db_count > 0}
						<div class="mb-6">
							<div class="flex justify-between items-center mb-2">
								<h3 class="font-semibold text-gray-900">
									Affected Laws in Database ({affectedLaws.in_db_count})
								</h3>
								<div class="flex gap-2 text-sm">
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
								{#each affectedLaws.in_db as law}
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
							<h3 class="font-semibold text-gray-900 mb-2">
								Affected Laws NOT in Database ({affectedLaws.not_in_db_count})
							</h3>
							<p class="text-sm text-gray-500 mb-2">
								These laws will need to be scraped and added to complete the cascade.
							</p>
							<div
								class="border border-yellow-200 bg-yellow-50 rounded-lg max-h-48 overflow-y-auto"
							>
								{#each affectedLaws.not_in_db as law}
									<div
										class="flex items-center gap-3 px-4 py-2 border-b border-yellow-100 last:border-b-0"
									>
										<input
											type="checkbox"
											checked={selectedNotInDb.has(law.name)}
											on:change={() => toggleNotInDbSelection(law.name)}
											class="h-4 w-4 text-yellow-600 rounded"
										/>
										<div class="font-mono text-sm text-gray-700">{law.name}</div>
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
									<span class="text-purple-600">Enacting Parents</span> in Database ({affectedLaws.enacting_parents_in_db_count})
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
								{#each affectedLaws.enacting_parents_in_db as law}
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
					{#if selectedInDb.size > 0}
						<span>{selectedInDb.size} selected for re-parse</span>
					{/if}
					{#if selectedEnactingParents.size > 0}
						<span class="text-purple-600">{selectedEnactingParents.size} parent laws selected</span>
					{/if}
				</div>
				<div class="flex gap-3 flex-wrap justify-end">
					<!-- Review buttons (amending/rescinding) - opens ParseReviewModal for each -->
					{#if affectedLaws && affectedLaws.in_db_count > 0 && !reparseResults}
						<button
							on:click={handleReviewSelected}
							disabled={reparseInProgress || enactingUpdateInProgress || selectedInDb.size === 0}
							class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Review Selected ({selectedInDb.size})
						</button>
						<button
							on:click={handleReviewAll}
							disabled={reparseInProgress || enactingUpdateInProgress}
							class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Review All ({affectedLaws.in_db_count})
						</button>
					{/if}

					<!-- Enacting links update buttons -->
					{#if affectedLaws && affectedLaws.enacting_parents_in_db_count > 0 && !enactingResults}
						<button
							on:click={handleUpdateEnactingSelected}
							disabled={reparseInProgress ||
								enactingUpdateInProgress ||
								selectedEnactingParents.size === 0}
							class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							{#if enactingUpdateInProgress}
								Updating...
							{:else}
								Update Enacting ({selectedEnactingParents.size})
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
								Update All Parents ({affectedLaws.enacting_parents_in_db_count})
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
