<!--
  RecordCardModal.svelte

  "Back of card" modal for viewing a full LRT record.
  Opens instantly with PGLite data (synced fields). Heavy JSONB fields
  (duties, rights, powers, etc.) are fetched on demand via REST when
  the user clicks "Load details" in a heavy section.
-->
<script lang="ts">
	import { authFetch } from '$lib/api/client';
	import RecordDetailPanel from './RecordDetailPanel.svelte';
	import ParseReviewModal from './ParseReviewModal.svelte';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	let {
		open = $bindable(false),
		record = null,
		recordId = null,
		onclose
	}: {
		/** Whether the modal is open */
		open?: boolean;
		/** Record data from PGLite (synced fields, instant) */
		record?: Record<string, unknown> | null;
		/** Record ID for REST fetch of heavy fields */
		recordId?: string | null;
		/** Callback when modal is closed */
		onclose?: () => void;
	} = $props();

	// Merged display record: PGLite data + heavy fields when loaded
	let heavyData: Record<string, unknown> | null = $state(null);
	let heavyLoading = $state(false);
	let heavyError: string | null = $state(null);

	let displayRecord: Record<string, unknown> | null = $derived(
		heavyData && record
			? { ...(record as Record<string, unknown>), ...(heavyData as Record<string, unknown>) }
			: (record ?? null)
	);
	let heavyLoaded = $derived(heavyData !== null);

	// Parse & Review sub-modal state
	let parseModalOpen = $state(false);

	// Reset state when modal opens with a new record
	let lastRecordId: string | null = $state(null);
	$effect(() => {
		if (open && recordId !== lastRecordId) {
			lastRecordId = recordId;
			heavyData = null;
			heavyLoading = false;
			heavyError = null;
		}
	});

	async function loadHeavyFields() {
		if (!recordId || heavyLoading || heavyLoaded) return;

		heavyLoading = true;
		heavyError = null;

		try {
			const response = await authFetch(`${API_URL}/api/laws/${recordId}`);
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
		onclose?.();
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

<svelte:window onkeydown={open && !parseModalOpen ? handleKeydown : undefined} />

{#if open && record}
	<!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
	<div
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
		onclick={(e) => {
			if (e.target === e.currentTarget) handleClose();
		}}
	>
		<div
			class="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden flex flex-col"
		>
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
					<button onclick={handleClose} class="ml-4 text-gray-400 hover:text-gray-600">
						<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M6 18L18 6M6 6l12 12"
							/>
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
							<span
								class="ml-1 px-1.5 py-0.5 text-xs font-medium rounded bg-green-100 text-green-700"
								>Yes</span
							>
						{:else}
							<span class="ml-1 text-gray-400">No</span>
						{/if}
					</div>
				</div>
			</div>

			<!-- Content -->
			<div class="flex-1 overflow-y-auto p-6">
				{#if heavyError}
					<div
						class="mb-4 px-4 py-3 text-sm bg-red-50 text-red-700 rounded-lg border border-red-200"
					>
						Failed to load detailed data: {heavyError}
						<button
							onclick={loadHeavyFields}
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
					onloadheavy={loadHeavyFields}
				/>
			</div>

			<!-- Footer -->
			<div class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex justify-between items-center">
				<div class="text-sm text-gray-500">
					{#if record.updated_at}
						Last updated: {new Date(String(record.updated_at)).toLocaleDateString('en-GB', {
							day: '2-digit',
							month: 'short',
							year: 'numeric'
						})}
					{/if}
				</div>
				<div class="flex items-center gap-3">
					<button
						onclick={handleClose}
						class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
					>
						Close
					</button>
					<button
						onclick={openParseReview}
						class="px-4 py-2 text-sm text-white bg-indigo-600 rounded-md hover:bg-indigo-700 flex items-center gap-2"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
							/>
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
		records={[
			{
				name: String(record.name ?? ''),
				Title_EN: String(record.title_en ?? ''),
				type_code: String(record.type_code ?? ''),
				Year: Number(record.year ?? 0),
				Number: String(record.number ?? '')
			}
		]}
		recordId={recordId ?? undefined}
		open={parseModalOpen}
		onclose={closeParseReview}
	/>
{/if}
