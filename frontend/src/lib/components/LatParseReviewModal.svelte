<script lang="ts">
	import { createEventDispatcher, onDestroy } from 'svelte';
	import {
		latParseStream,
		confirmLatRecord,
		type LatParseStage,
		type LatSessionRecord,
		type LatParseResult
	} from '$lib/api/lat';
	import { latKeys } from '$lib/query/lat';
	import { useQueryClient } from '@tanstack/svelte-query';

	export let sessionId: string;
	export let records: LatSessionRecord[] = [];
	export let initialIndex: number = 0;
	export let open: boolean = false;
	export let autoConfirm: boolean = false;

	const dispatch = createEventDispatcher<{
		close: void;
		complete: { confirmed: number; skipped: number; errors: number };
	}>();

	const queryClient = useQueryClient();

	// State
	let currentIndex = initialIndex;
	let parseResult: LatParseResult | null = null;
	let confirmedCount = 0;
	let skippedCount = 0;
	let errorCount = 0;
	let workflowComplete = false;

	// Streaming progress
	let isParsing = false;
	let parseError: string | null = null;
	let cleanupStream: (() => void) | null = null;
	let isConfirming = false;

	// Auto-confirm
	let autoConfirmTimer: ReturnType<typeof setTimeout> | null = null;
	let autoConfirmTriggered = false;

	// Track parsed records to prevent re-parsing
	let lastParsedName: string | null = null;
	let failedNames: Set<string> = new Set();

	// Stage progress
	type StageStatus = {
		status: 'pending' | 'running' | 'ok' | 'error' | 'skipped';
		summary: string | null;
	};

	const ALL_STAGES: LatParseStage[] = [
		'fetch_body',
		'parse_lat',
		'persist_lat',
		'parse_annotations',
		'persist_annotations'
	];

	const STAGE_LABELS: Record<LatParseStage, string> = {
		fetch_body: 'Fetch Body XML',
		parse_lat: 'Parse LAT',
		persist_lat: 'Persist LAT',
		parse_annotations: 'Parse Annotations',
		persist_annotations: 'Persist Annotations'
	};

	let stageProgress: Record<LatParseStage, StageStatus> = initStageProgress();

	function initStageProgress(): Record<LatParseStage, StageStatus> {
		return {
			fetch_body: { status: 'pending', summary: null },
			parse_lat: { status: 'pending', summary: null },
			persist_lat: { status: 'pending', summary: null },
			parse_annotations: { status: 'pending', summary: null },
			persist_annotations: { status: 'pending', summary: null }
		};
	}

	$: currentRecord = records[currentIndex];
	$: isFirst = currentIndex === 0;
	$: isLast = currentIndex === records.length - 1;

	// Parse current record when index changes
	$: if (
		open &&
		!workflowComplete &&
		currentRecord &&
		currentRecord.law_name !== lastParsedName &&
		!failedNames.has(currentRecord.law_name) &&
		!isParsing
	) {
		parseCurrentRecord();
	}

	// Auto-confirm
	$: if (
		autoConfirm &&
		parseResult &&
		!isParsing &&
		!isConfirming &&
		!autoConfirmTriggered &&
		currentRecord
	) {
		autoConfirmTriggered = true;
		autoConfirmTimer = setTimeout(() => {
			autoConfirmTimer = null;
			handleConfirm();
		}, 300);
	}

	// Stop auto-confirm on error
	$: if (autoConfirm && parseError && !isParsing) {
		autoConfirm = false;
	}

	onDestroy(() => {
		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}
		if (autoConfirmTimer) {
			clearTimeout(autoConfirmTimer);
			autoConfirmTimer = null;
		}
	});

	function parseCurrentRecord() {
		if (!currentRecord) return;
		if (currentRecord.law_name === lastParsedName) return;
		if (failedNames.has(currentRecord.law_name)) return;

		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}

		parseResult = null;
		parseError = null;
		isParsing = true;
		lastParsedName = currentRecord.law_name;
		stageProgress = initStageProgress();

		cleanupStream = latParseStream(sessionId, currentRecord.law_name, {
			onStageStart: (stage, _stageNum, _total) => {
				stageProgress = { ...stageProgress, [stage]: { status: 'running', summary: null } };
			},
			onStageComplete: (stage, status, summary) => {
				stageProgress = { ...stageProgress, [stage]: { status, summary } };
			},
			onComplete: (result) => {
				parseResult = result;
				isParsing = false;
				cleanupStream = null;
			},
			onError: (error) => {
				console.error('LAT SSE failed:', error);
				parseError = error.message;
				isParsing = false;
				cleanupStream = null;
				failedNames.add(currentRecord.law_name);
			}
		});
	}

	async function handleConfirm() {
		if (!parseResult || !currentRecord) return;

		isConfirming = true;
		try {
			await confirmLatRecord(sessionId, currentRecord.law_name);
			confirmedCount++;
			// Invalidate session queries
			queryClient.invalidateQueries({ queryKey: latKeys.sessionRecords(sessionId) });
			queryClient.invalidateQueries({ queryKey: latKeys.session(sessionId) });
			moveNext();
		} catch (error) {
			console.error('Confirm error:', error);
			errorCount++;
			if (autoConfirm) {
				autoConfirm = false;
			}
		} finally {
			isConfirming = false;
		}
	}

	function handleSkip() {
		skippedCount++;
		moveNext();
	}

	function moveNext() {
		if (isLast) {
			handleComplete();
		} else {
			currentIndex++;
			parseResult = null;
			lastParsedName = null;
			autoConfirmTriggered = false;
		}
	}

	function movePrev() {
		if (!isFirst) {
			currentIndex--;
			parseResult = null;
			lastParsedName = null;
			autoConfirmTriggered = false;
		}
	}

	function handleCancel() {
		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}
		if (autoConfirmTimer) {
			clearTimeout(autoConfirmTimer);
			autoConfirmTimer = null;
		}
		isParsing = false;
		autoConfirm = false;
		dispatch('close');
	}

	function handleComplete() {
		workflowComplete = true;
		lastParsedName = null;
		dispatch('complete', {
			confirmed: confirmedCount,
			skipped: skippedCount,
			errors: errorCount
		});
	}

	// Reset when records change
	let lastRecordsId: string = '';
	$: recordsId = records.map((r) => r.law_name).join(',');
	$: if (open && records.length > 0 && recordsId !== lastRecordsId) {
		lastRecordsId = recordsId;
		currentIndex = initialIndex;
		confirmedCount = 0;
		skippedCount = 0;
		errorCount = 0;
		failedNames = new Set();
		lastParsedName = null;
		parseResult = null;
		workflowComplete = false;
		autoConfirmTriggered = false;
	}

	// Reset on reopen
	let wasOpen = false;
	$: if (open && !wasOpen) {
		lastParsedName = null;
		parseResult = null;
		parseError = null;
		workflowComplete = false;
	}
	$: wasOpen = open;
</script>

{#if open}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
		on:click|self={handleCancel}
	>
		<div
			class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4 max-h-[90vh] overflow-hidden flex flex-col"
		>
			<!-- Header -->
			<div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
				<div class="flex items-center space-x-3">
					<h2 class="text-lg font-semibold text-gray-900">LAT Parse</h2>
					{#if autoConfirm}
						<span class="px-2 py-0.5 text-xs font-medium rounded-full bg-blue-100 text-blue-700">
							Auto
						</span>
					{/if}
				</div>
				<button on:click={handleCancel} class="text-gray-400 hover:text-gray-600">
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

			<!-- Content -->
			<div class="flex-1 overflow-y-auto p-6">
				<!-- Current record info -->
				{#if currentRecord}
					<div class="mb-4 p-3 bg-gray-50 rounded-lg border border-gray-200">
						<div class="flex items-center justify-between">
							<div>
								<h3 class="font-medium text-gray-900">
									{currentRecord.title_en || currentRecord.law_name}
								</h3>
								<p class="text-sm text-gray-500 font-mono mt-0.5">{currentRecord.law_name}</p>
							</div>
							<div class="text-right text-sm text-gray-500">
								<span>{currentRecord.type_code}</span>
								{#if currentRecord.year}
									<span class="ml-1">({currentRecord.year})</span>
								{/if}
							</div>
						</div>
					</div>
				{/if}

				<!-- Stage Progress -->
				<div class="space-y-2 mb-6">
					{#each ALL_STAGES as stage}
						{@const progress = stageProgress[stage]}
						<div class="flex items-center space-x-3 py-1.5">
							<div class="w-5 h-5 flex items-center justify-center">
								{#if progress?.status === 'running'}
									<div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
								{:else if progress?.status === 'ok'}
									<span class="text-green-600 font-bold">&#10003;</span>
								{:else if progress?.status === 'error'}
									<span class="text-red-600 font-bold">&#10007;</span>
								{:else if progress?.status === 'skipped'}
									<span class="text-gray-400">-</span>
								{:else}
									<span class="text-gray-300">&#9675;</span>
								{/if}
							</div>
							<span
								class="w-40 text-sm {progress?.status === 'running'
									? 'text-blue-600 font-medium'
									: progress?.status === 'ok'
										? 'text-gray-700'
										: progress?.status === 'error'
											? 'text-red-600'
											: 'text-gray-400'}"
							>
								{STAGE_LABELS[stage]}
							</span>
							<span class="text-sm text-gray-500 truncate flex-1">
								{#if progress?.status === 'running'}
									...
								{:else if progress?.summary}
									{progress.summary}
								{/if}
							</span>
						</div>
					{/each}
				</div>

				<!-- Parse Error -->
				{#if parseError && !parseResult}
					<div class="rounded-md bg-red-50 p-4 mb-4">
						<p class="text-sm text-red-700">{parseError}</p>
						<button
							on:click={() => {
								parseError = null;
								failedNames.delete(currentRecord?.law_name || '');
								lastParsedName = null;
								parseCurrentRecord();
							}}
							class="mt-3 px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 text-sm"
						>
							Retry Parse
						</button>
					</div>
				{/if}

				<!-- Result Summary -->
				{#if parseResult}
					<div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
						<h4 class="text-sm font-medium text-gray-700 mb-3">Results</h4>
						<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
							<div class="text-center">
								<p class="text-2xl font-semibold text-gray-900">
									{parseResult.lat?.inserted ?? 0}
								</p>
								<p class="text-xs text-gray-500">LAT Inserted</p>
							</div>
							<div class="text-center">
								<p class="text-2xl font-semibold text-gray-900">
									{parseResult.lat?.deleted ?? 0}
								</p>
								<p class="text-xs text-gray-500">LAT Deleted</p>
							</div>
							<div class="text-center">
								<p class="text-2xl font-semibold text-gray-900">
									{parseResult.annotations?.inserted ?? 0}
								</p>
								<p class="text-xs text-gray-500">Annotations</p>
							</div>
							<div class="text-center">
								<p class="text-2xl font-semibold text-gray-900">
									{parseResult.duration_ms ? (parseResult.duration_ms / 1000).toFixed(1) : '-'}
								</p>
								<p class="text-xs text-gray-500">Duration (s)</p>
							</div>
						</div>

						{#if parseResult.has_errors}
							<div class="mt-3 rounded-md bg-amber-50 border border-amber-200 p-3">
								<p class="text-sm text-amber-700">
									Parse completed with errors. Partial data may be available.
								</p>
							</div>
						{/if}
					</div>
				{/if}
			</div>

			<!-- Footer -->
			<div class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex justify-between items-center">
				<div class="text-sm text-gray-500">
					Record {currentIndex + 1} of {records.length}
					{#if confirmedCount > 0 || errorCount > 0}
						<span class="ml-2">
							({confirmedCount} confirmed{#if skippedCount > 0}, {skippedCount} skipped{/if}{#if errorCount > 0},
								{errorCount} errors{/if})
						</span>
					{/if}
				</div>
				<div class="flex items-center space-x-3">
					{#if autoConfirm}
						<span class="text-sm text-blue-600 font-medium flex items-center">
							<svg
								class="animate-spin -ml-0.5 mr-1.5 h-4 w-4 text-blue-600"
								fill="none"
								viewBox="0 0 24 24"
							>
								<circle
									class="opacity-25"
									cx="12"
									cy="12"
									r="10"
									stroke="currentColor"
									stroke-width="4"
								></circle>
								<path
									class="opacity-75"
									fill="currentColor"
									d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
								></path>
							</svg>
							Auto-parsing...
						</span>
						<button
							on:click={() => {
								autoConfirm = false;
								if (autoConfirmTimer) {
									clearTimeout(autoConfirmTimer);
									autoConfirmTimer = null;
								}
							}}
							class="px-4 py-2 text-sm text-amber-700 border border-amber-300 bg-amber-50 rounded-md hover:bg-amber-100"
						>
							Stop
						</button>
						<button
							on:click={handleCancel}
							class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
						>
							Cancel
						</button>
					{:else}
						<div class="flex space-x-2 mr-4">
							<button
								on:click={movePrev}
								disabled={isFirst || isParsing || isConfirming}
								class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
							>
								Prev
							</button>
							<button
								on:click={() => moveNext()}
								disabled={isLast || isParsing || isConfirming}
								class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
							>
								Next
							</button>
						</div>
						<button
							on:click={handleCancel}
							class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
						>
							Cancel
						</button>
						<button
							on:click={handleSkip}
							disabled={isParsing || isConfirming}
							class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Skip
						</button>
						<button
							on:click={handleConfirm}
							disabled={!parseResult || isParsing || isConfirming}
							class="px-4 py-2 text-sm text-white rounded-md disabled:bg-gray-400 disabled:cursor-not-allowed {parseResult?.has_errors
								? 'bg-amber-600 hover:bg-amber-700'
								: 'bg-blue-600 hover:bg-blue-700'}"
						>
							{#if isConfirming}
								Saving...
							{:else if parseResult?.has_errors}
								Confirm Partial
							{:else}
								Confirm
							{/if}
						</button>
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}
