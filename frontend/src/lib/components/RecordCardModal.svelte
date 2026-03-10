<!--
  RecordCardModal.svelte

  "Back of card" modal for viewing a full LRT record.
  Opens instantly with PGLite data (synced fields). Heavy JSONB fields
  (duties, rights, powers, etc.) are fetched on demand via REST when
  the user clicks "Load details" in a heavy section.
-->
<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import { authFetch } from '$lib/api/client';
	import RecordDetailPanel from './RecordDetailPanel.svelte';
	import ParseReviewModal from './ParseReviewModal.svelte';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	/** Whether the modal is open */
	export let open: boolean = false;

	/** Record data from PGLite (synced fields, instant) */
	export let record: Record<string, unknown> | null = null;

	/** Record ID for REST fetch of heavy fields */
	export let recordId: string | null = null;

	const dispatch = createEventDispatcher<{ close: void }>();

	// Merged display record: PGLite data + heavy fields when loaded
	let heavyData: Record<string, unknown> | null = null;
	let heavyLoading = false;
	let heavyError: string | null = null;

	$: displayRecord = heavyData ? { ...record, ...heavyData } : record;
	$: heavyLoaded = heavyData !== null;

	// Parse & Review sub-modal state
	let parseModalOpen = false;

	// Reset state when modal opens with a new record
	let lastRecordId: string | null = null;
	$: if (open && recordId !== lastRecordId) {
		lastRecordId = recordId;
		heavyData = null;
		heavyLoading = false;
		heavyError = null;
	}

	async function loadHeavyFields() {
		if (!recordId || heavyLoading || heavyLoaded) return;

		heavyLoading = true;
		heavyError = null;

		try {
			const response = await authFetch(`${API_URL}/api/uk-lrt/${recordId}`);
			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}
			heavyData = await response.json();
		} catch (e) {
			heavyError = e instanceof Error ? e.message : 'Failed to load';
		} finally {
			heavyLoading = false;
		}
	}

	function handleClose() {
		open = false;
		dispatch('close');
	}

	function openParseReview() {
		parseModalOpen = true;
	}

	function closeParseReview() {
		parseModalOpen = false;
	}

	function handleKeydown(e: KeyboardEvent) {
		if (e.key === 'Escape') {
			handleClose();
		}
	}
</script>

<svelte:window on:keydown={open && !parseModalOpen ? handleKeydown : undefined} />

{#if open && record}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
		on:click|self={handleClose}
	>
		<div class="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden flex flex-col">
			<!-- Header -->
			<div class="px-6 py-4 border-b border-gray-200">
				<div class="flex justify-between items-start">
					<div class="flex-1 min-w-0">
						<h2 class="text-lg font-semibold text-gray-900 truncate">
							{record.title_en || 'Untitled'}
						</h2>
						<div class="flex items-center gap-3 mt-1">
							<span class="font-mono text-sm text-gray-600">{record.name}</span>
							{#if record.name}
								<a
									href="https://www.legislation.gov.uk/{record.name}"
									target="_blank"
									rel="noopener noreferrer"
									class="text-xs text-blue-600 hover:text-blue-800 hover:underline"
								>
									legislation.gov.uk
								</a>
							{/if}
						</div>
					</div>
					<button on:click={handleClose} class="ml-4 text-gray-400 hover:text-gray-600">
						<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
						</svg>
					</button>
				</div>

				<!-- Compact credentials summary -->
				<div class="mt-3 grid grid-cols-2 md:grid-cols-5 gap-3 text-sm">
					<div>
						<span class="text-gray-500">Year:</span>
						<span class="ml-1 text-gray-900">{record.year ?? '-'}</span>
					</div>
					<div>
						<span class="text-gray-500">Type:</span>
						<span class="ml-1 text-gray-900">{record.type_code ?? '-'}</span>
					</div>
					<div>
						<span class="text-gray-500">Family:</span>
						<span class="ml-1 text-gray-900">{record.family || '-'}</span>
					</div>
					<div>
						<span class="text-gray-500">Status:</span>
						<span class="ml-1 text-gray-900">{record.live || '-'}</span>
					</div>
					<div>
						<span class="text-gray-500">Making:</span>
						{#if record.is_making}
							<span class="ml-1 px-1.5 py-0.5 text-xs font-medium rounded bg-green-100 text-green-700">Yes</span>
						{:else}
							<span class="ml-1 text-gray-400">No</span>
						{/if}
					</div>
				</div>
			</div>

			<!-- Content -->
			<div class="flex-1 overflow-y-auto p-6">
				{#if heavyError}
					<div class="mb-4 px-4 py-3 text-sm bg-red-50 text-red-700 rounded-lg border border-red-200">
						Failed to load detailed data: {heavyError}
						<button
							on:click={loadHeavyFields}
							class="ml-2 text-red-800 underline hover:no-underline"
						>
							Retry
						</button>
					</div>
				{/if}

				<RecordDetailPanel
					record={displayRecord}
					{heavyLoaded}
					{heavyLoading}
					on:loadHeavy={loadHeavyFields}
				/>
			</div>

			<!-- Footer -->
			<div class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex justify-between items-center">
				<div class="text-sm text-gray-500">
					{#if record.updated_at}
						Last updated: {new Date(String(record.updated_at)).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })}
					{/if}
				</div>
				<div class="flex items-center gap-3">
					<button
						on:click={handleClose}
						class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
					>
						Close
					</button>
					<button
						on:click={openParseReview}
						class="px-4 py-2 text-sm text-white bg-indigo-600 rounded-md hover:bg-indigo-700 flex items-center gap-2"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
						</svg>
						Parse & Review
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}

<!-- Parse & Review sub-modal -->
{#if parseModalOpen && record}
	<ParseReviewModal
		records={[{
			name: String(record.name ?? ''),
			Title_EN: String(record.title_en ?? ''),
			type_code: String(record.type_code ?? ''),
			Year: Number(record.year ?? 0),
			Number: String(record.number ?? '')
		}]}
		recordId={recordId ?? undefined}
		open={parseModalOpen}
		on:close={closeParseReview}
	/>
{/if}
