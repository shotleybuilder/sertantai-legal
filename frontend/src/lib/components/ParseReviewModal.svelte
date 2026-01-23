<script lang="ts">
	import { createEventDispatcher, onDestroy } from 'svelte';
	import {
		useParseOneMutation,
		useConfirmRecordMutation,
		useFamilyOptionsQuery
	} from '$lib/query/scraper';
	import type { ParseOneResult, ScrapeRecord, ParseStage } from '$lib/api/scraper';
	import { parseOneStream, mapParseError, mapStageError } from '$lib/api/scraper';
	import RecordDiff from './RecordDiff.svelte';
	import CollapsibleSection from './CollapsibleSection.svelte';
	import FieldRow, { getFieldValue, hasData as fieldHasData } from './parse-review/FieldRow.svelte';
	import { SECTION_CONFIG } from './parse-review/field-config';

	// Display mode: 'create' (new law), 'update' (reparse with diff), 'read' (view DB record)
	type DisplayMode = 'create' | 'update' | 'read';

	// Props for parse workflow (Create/Update modes)
	export let sessionId: string = '';
	export let records: ScrapeRecord[] = [];
	export let initialIndex: number = 0;
	export let open: boolean = false;
	// Optional: limit which stages to run (e.g., ['amendments', 'repeal_revoke'] for cascade re-parse)
	export let stages: ParseStage[] | undefined = undefined;

	// Props for Read mode (view existing DB record without parsing)
	export let record: Record<string, unknown> | null = null;
	// Optional: force specific mode (otherwise auto-detected)
	export let mode: DisplayMode | undefined = undefined;

	const dispatch = createEventDispatcher<{
		close: void;
		complete: { confirmed: number; skipped: number; errors: number };
	}>();

	const parseMutation = useParseOneMutation();
	const confirmMutation = useConfirmRecordMutation();
	const familyOptionsQuery = useFamilyOptionsQuery();

	// State
	let currentIndex = initialIndex;
	let parseResult: ParseOneResult | null = null;
	let selectedFamily: string = '';
	let selectedSubFamily: string = '';
	let confirmedCount = 0;
	let skippedCount = 0;
	let errorCount = 0;
	// Flag to prevent reparsing after workflow is complete
	let workflowComplete = false;

	// Streaming progress state
	let isParsing = false;
	let parseError: string | null = null;
	let currentStage: ParseStage | null = null;
	let cleanupStream: (() => void) | null = null;

	// Per-stage reparse state
	let reparsingStage: ParseStage | null = null;

	// Use plain object for better Svelte reactivity (Maps don't trigger updates reliably)
	type StageStatus = {
		status: 'pending' | 'running' | 'ok' | 'error' | 'skipped';
		summary: string | null;
	};
	let stageProgress: Record<ParseStage, StageStatus> = {
		metadata: { status: 'pending', summary: null },
		extent: { status: 'pending', summary: null },
		enacted_by: { status: 'pending', summary: null },
		amending: { status: 'pending', summary: null },
		amended_by: { status: 'pending', summary: null },
		repeal_revoke: { status: 'pending', summary: null },
		taxa: { status: 'pending', summary: null }
	};

	// All stages in order
	const ALL_STAGES: ParseStage[] = [
		'metadata',
		'extent',
		'enacted_by',
		'amending',
		'amended_by',
		'repeal_revoke',
		'taxa'
	];

	// Human-readable stage names
	const STAGE_LABELS: Record<ParseStage, string> = {
		metadata: 'Metadata',
		extent: 'Extent',
		enacted_by: 'Enacted By',
		amending: 'Amending',
		amended_by: 'Amended By',
		repeal_revoke: 'Repeal/Revoke',
		taxa: 'Taxa Classification'
	};

	$: currentRecord = records[currentIndex];
	$: isFirst = currentIndex === 0;
	$: isLast = currentIndex === records.length - 1;

	// Derive effective display mode:
	// 1. Explicit mode prop takes precedence
	// 2. If record prop is set (no records array), it's Read mode
	// 3. Otherwise, Create (no duplicate) or Update (has duplicate) based on parse result
	$: effectiveMode = (mode
		? mode
		: record
			? 'read'
			: parseResult?.duplicate?.exists
				? 'update'
				: 'create') as DisplayMode;

	// For display: use record prop in Read mode, otherwise merge DB record with parsed changes
	$: displayRecord = effectiveMode === 'read'
		? record
		: parseResult?.record
			? parseResult.duplicate?.exists && parseResult.duplicate?.record
				? { ...parseResult.duplicate.record, ...parseResult.record }
				: parseResult.record
			: null;

	// Track the last parsed record name to prevent re-parsing
	let lastParsedName: string | null = null;
	// Track names that failed to parse to prevent infinite retry loops
	let failedNames: Set<string> = new Set();

	// Parse current record when index changes (only if not already parsed or failed)
	// IMPORTANT: workflowComplete guard prevents reparse after final confirm
	// Skip parsing entirely in Read mode (record prop provides the data)
	$: if (
		open &&
		effectiveMode !== 'read' &&
		!workflowComplete &&
		currentRecord &&
		currentRecord.name !== lastParsedName &&
		!failedNames.has(currentRecord.name) &&
		!isParsing
	) {
		parseCurrentRecord();
	}

	// Cleanup stream on component destroy
	onDestroy(() => {
		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}
	});

	function initStageProgress() {
		// If stages prop is set, mark non-selected stages as 'skipped' from the start
		const activeStages = stages || ALL_STAGES;
		stageProgress = {
			metadata: { status: activeStages.includes('metadata') ? 'pending' : 'skipped', summary: null },
			extent: { status: activeStages.includes('extent') ? 'pending' : 'skipped', summary: null },
			enacted_by: { status: activeStages.includes('enacted_by') ? 'pending' : 'skipped', summary: null },
			amending: { status: activeStages.includes('amending') ? 'pending' : 'skipped', summary: null },
			amended_by: { status: activeStages.includes('amended_by') ? 'pending' : 'skipped', summary: null },
			repeal_revoke: { status: activeStages.includes('repeal_revoke') ? 'pending' : 'skipped', summary: null },
			taxa: { status: activeStages.includes('taxa') ? 'pending' : 'skipped', summary: null }
		};
	}

	async function parseCurrentRecord() {
		if (!currentRecord) return;
		if (currentRecord.name === lastParsedName) return;
		if (failedNames.has(currentRecord.name)) return;

		// Cleanup any existing stream
		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}

		parseResult = null;
		parseError = null;
		isParsing = true;
		currentStage = null;
		lastParsedName = currentRecord.name;
		initStageProgress();

		// Try streaming first, fall back to non-streaming on error
		cleanupStream = parseOneStream(
			sessionId,
			currentRecord.name,
			{
				onStageStart: (stage, _stageNum, _total) => {
					currentStage = stage;
					// Use object spread to trigger Svelte reactivity
					stageProgress = { ...stageProgress, [stage]: { status: 'running', summary: null } };
				},
				onStageComplete: (stage, status, summary) => {
					// Use object spread to trigger Svelte reactivity
					stageProgress = { ...stageProgress, [stage]: { status, summary } };
				},
				onComplete: (result) => {
					parseResult = result;
					isParsing = false;
					currentStage = null;
					cleanupStream = null;
					// API normalizes Family to lowercase family
					selectedFamily = (result.record?.family as string) || '';
					selectedSubFamily = (result.record?.family_ii as string) || '';
				},
				onError: async (error) => {
					console.warn('SSE stream failed, falling back to non-streaming:', error);
					cleanupStream = null;
					// Fallback to non-streaming mutation
					try {
						const result = await $parseMutation.mutateAsync({
							sessionId,
							name: currentRecord.name
						});
						parseResult = result;
						selectedFamily = (result.record?.family as string) || '';
						selectedSubFamily = (result.record?.family_ii as string) || '';
					} catch (fallbackError) {
						console.error('Parse error:', fallbackError);
						parseError = fallbackError instanceof Error ? fallbackError.message : 'Parse failed';
						failedNames.add(currentRecord.name);
					} finally {
						isParsing = false;
						currentStage = null;
					}
				}
			},
			stages // Pass optional stages filter (e.g., ['amendments', 'repeal_revoke'] for cascade re-parse)
		);
	}

	async function handleConfirm() {
		if (!parseResult || !currentRecord || !parseResult.record) return;

		try {
			await $confirmMutation.mutateAsync({
				sessionId,
				name: currentRecord.name,
				record: parseResult.record,
				family: selectedFamily || undefined,
				overrides: selectedSubFamily ? { family_ii: selectedSubFamily } : undefined
			});
			confirmedCount++;
			moveNext();
		} catch (error) {
			console.error('Confirm error:', error);
			errorCount++;
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
			// Clear failed status for current record to allow retry on return
			const currentName = currentRecord?.name;
			if (currentName) {
				failedNames.delete(currentName);
			}
			currentIndex++;
			parseResult = null;
			lastParsedName = null;
		}
	}

	function movePrev() {
		if (!isFirst) {
			// Clear failed status for current record to allow retry on return
			const currentName = currentRecord?.name;
			if (currentName) {
				failedNames.delete(currentName);
			}
			currentIndex--;
			parseResult = null;
			lastParsedName = null;
		}
	}

	function handleCancel() {
		// Don't reset lastParsedName here - it triggers a reparse before the modal closes
		// The state will be reset when the modal reopens with new records (via recordsId check)
		dispatch('close');
	}

	function handleComplete() {
		// Set flag BEFORE dispatching to prevent reactive reparse trigger
		workflowComplete = true;
		lastParsedName = null;
		dispatch('complete', {
			confirmed: confirmedCount,
			skipped: skippedCount,
			errors: errorCount
		});
	}

	// Reset state when modal opens with new records
	// Use a separate variable to track the records array identity
	let lastRecordsId: string = '';
	$: recordsId = records.map((r) => r.name).join(',');
	$: if (open && records.length > 0 && recordsId !== lastRecordsId) {
		lastRecordsId = recordsId;
		currentIndex = initialIndex; // Reset to initial index for new records
		confirmedCount = 0;
		skippedCount = 0;
		errorCount = 0;
		failedNames = new Set();
		lastParsedName = null;
		parseResult = null;
		workflowComplete = false; // Reset workflow flag for new records
	}

	function getStageIcon(status: string): string {
		switch (status) {
			case 'ok':
				return 'text-green-600';
			case 'error':
				return 'text-red-600';
			case 'skipped':
				return 'text-gray-400';
			default:
				return 'text-gray-400';
		}
	}

	function getStageSymbol(status: string): string {
		switch (status) {
			case 'ok':
				return '+';
			case 'error':
				return 'x';
			case 'skipped':
				return '-';
			default:
				return '?';
		}
	}

	function formatValue(value: unknown): string {
		if (value === null || value === undefined) return '-';
		if (Array.isArray(value)) {
			if (value.length === 0) return '(none)';
			return value.map((v) => (typeof v === 'object' ? JSON.stringify(v) : String(v))).join(', ');
		}
		// Handle JSONB format {items: [...]} used by Taxa fields
		if (typeof value === 'object' && value !== null) {
			const obj = value as Record<string, unknown>;
			if ('items' in obj && Array.isArray(obj.items)) {
				if (obj.items.length === 0) return '(none)';
				return obj.items
					.map((v) => (typeof v === 'object' ? JSON.stringify(v) : String(v)))
					.join(', ');
			}
			return JSON.stringify(value);
		}
		return String(value);
	}

	function formatDate(dateStr: unknown): string {
		if (!dateStr || typeof dateStr !== 'string') return '-';
		try {
			return new Date(dateStr).toLocaleDateString();
		} catch {
			return String(dateStr);
		}
	}

	// Helper to get record field with fallback to alternative keys
	function getField(
		record: Record<string, unknown> | null | undefined,
		...keys: string[]
	): unknown {
		if (!record) return null;
		for (const key of keys) {
			if (record[key] !== undefined && record[key] !== null) {
				return record[key];
			}
		}
		return null;
	}

	// Get list of failed stages from parseResult
	function getFailedStages(): ParseStage[] {
		if (!parseResult?.stages) return [];
		return (Object.entries(parseResult.stages) as [ParseStage, { status: string }][])
			.filter(([_, result]) => result.status === 'error')
			.map(([stage, _]) => stage);
	}

	// Retry only the failed stages
	let isRetrying = false;
	async function retryFailedStages() {
		if (!currentRecord || !parseResult) return;

		const failedStages = getFailedStages();
		if (failedStages.length === 0) return;

		// Cleanup any existing stream
		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}

		isRetrying = true;
		parseError = null;

		// Reset progress for failed stages to pending, keep successful ones
		for (const stage of failedStages) {
			stageProgress = { ...stageProgress, [stage]: { status: 'pending', summary: null } };
		}

		// Store current successful results to merge later
		const previousResult = parseResult;

		cleanupStream = parseOneStream(
			sessionId,
			currentRecord.name,
			{
				onStageStart: (stage, _stageNum, _total) => {
					currentStage = stage;
					stageProgress = { ...stageProgress, [stage]: { status: 'running', summary: null } };
				},
				onStageComplete: (stage, status, summary) => {
					stageProgress = { ...stageProgress, [stage]: { status, summary } };
				},
				onComplete: (result) => {
					// Merge retry results with previous results
					// For stages that were retried, use new results
					// For stages that weren't retried, keep previous results
					const mergedStages = { ...previousResult.stages };
					const mergedRecord = { ...previousResult.record };
					const mergedErrors: string[] = [];

					for (const stage of ALL_STAGES) {
						if (failedStages.includes(stage)) {
							// Use new result for retried stage
							mergedStages[stage] = result.stages[stage];
							// If the retry succeeded, merge in any new data
							if (result.stages[stage]?.status === 'ok' && result.record) {
								Object.assign(mergedRecord, result.record);
							}
							// Add error if retry still failed
							if (result.stages[stage]?.status === 'error') {
								const error = result.errors.find((e) => e.startsWith(stage + ':'));
								if (error) mergedErrors.push(error);
							}
						} else {
							// Keep previous result for non-retried stage
							// Also keep any errors from previous result for this stage
							const prevError = previousResult.errors.find((e) => e.startsWith(stage + ':'));
							if (prevError) mergedErrors.push(prevError);
						}
					}

					parseResult = {
						...result,
						record: mergedRecord,
						stages: mergedStages,
						errors: mergedErrors,
						has_errors: mergedErrors.length > 0
					};

					isRetrying = false;
					currentStage = null;
					cleanupStream = null;
				},
				onError: (error) => {
					console.error('Retry failed:', error);
					parseError = error.message;
					isRetrying = false;
					currentStage = null;
					cleanupStream = null;
				}
			},
			failedStages // Only retry failed stages
		);
	}

	// Re-parse a single stage (called from section header reparse button)
	async function reparseStage(stage: ParseStage) {
		if (!currentRecord || !parseResult || reparsingStage) return;

		// Cleanup any existing stream
		if (cleanupStream) {
			cleanupStream();
			cleanupStream = null;
		}

		reparsingStage = stage;
		parseError = null;

		// Reset progress for this stage
		stageProgress = { ...stageProgress, [stage]: { status: 'pending', summary: null } };

		// Store current results to merge later
		const previousResult = parseResult;

		cleanupStream = parseOneStream(
			sessionId,
			currentRecord.name,
			{
				onStageStart: (s, _stageNum, _total) => {
					if (s === stage) {
						stageProgress = { ...stageProgress, [s]: { status: 'running', summary: null } };
					}
				},
				onStageComplete: (s, status, summary) => {
					if (s === stage) {
						stageProgress = { ...stageProgress, [s]: { status, summary } };
					}
				},
				onComplete: (result) => {
					// Merge the single stage result with previous results
					const mergedStages = { ...previousResult.stages };
					const mergedRecord = { ...previousResult.record };
					const mergedErrors: string[] = previousResult.errors.filter(
						(e) => !e.startsWith(stage + ':')
					);

					// Update with new stage result
					mergedStages[stage] = result.stages[stage];

					// If stage succeeded, merge in the new data
					if (result.stages[stage]?.status === 'ok' && result.record) {
						Object.assign(mergedRecord, result.record);
					}

					// Add error if stage failed
					if (result.stages[stage]?.status === 'error') {
						const error = result.errors.find((e) => e.startsWith(stage + ':'));
						if (error) mergedErrors.push(error);
					}

					parseResult = {
						...result,
						record: mergedRecord,
						stages: mergedStages,
						errors: mergedErrors,
						has_errors: mergedErrors.length > 0
					};

					reparsingStage = null;
					cleanupStream = null;
				},
				onError: (error) => {
					console.error('Stage reparse failed:', error);
					parseError = error.message;
					// Mark stage as error
					stageProgress = {
						...stageProgress,
						[stage]: { status: 'error', summary: error.message }
					};
					reparsingStage = null;
					cleanupStream = null;
				}
			},
			[stage] // Only parse this single stage
		);
	}
</script>

{#if open}
	<!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
		on:click|self={handleCancel}
	>
		<div
			class="bg-white rounded-lg shadow-xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-hidden flex flex-col"
		>
			<!-- Header -->
			<div class="px-6 py-4 border-b border-gray-200 flex justify-between items-center">
				<div class="flex items-center space-x-3">
					<h2 class="text-lg font-semibold text-gray-900">
						{#if effectiveMode === 'read'}
							View Record
						{:else if effectiveMode === 'update'}
							Update Record
						{:else}
							New Record
						{/if}
					</h2>
					<span class="px-2 py-0.5 text-xs font-medium rounded-full {
						effectiveMode === 'read' ? 'bg-gray-100 text-gray-600' :
						effectiveMode === 'update' ? 'bg-amber-100 text-amber-700' :
						'bg-green-100 text-green-700'
					}">
						{effectiveMode === 'read' ? 'Read Only' : effectiveMode === 'update' ? 'Update' : 'Create'}
					</span>
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
				{#if isParsing}
					<div class="flex flex-col items-center justify-center py-8">
						<p class="text-gray-700 font-medium mb-4">Parsing {currentRecord?.name}...</p>

						<!-- Stage Progress -->
						<div class="w-full max-w-md space-y-2">
							{#each ALL_STAGES as stage}
								{@const progress = stageProgress[stage]}
								<div class="flex items-center space-x-3 py-1">
									<!-- Status Icon -->
									<div class="w-5 h-5 flex items-center justify-center">
										{#if progress?.status === 'running'}
											<div
												class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"
											></div>
										{:else if progress?.status === 'ok'}
											<span class="text-green-600 font-bold">✓</span>
										{:else if progress?.status === 'error'}
											<span class="text-red-600 font-bold">✗</span>
										{:else if progress?.status === 'skipped'}
											<span class="text-gray-400">-</span>
										{:else}
											<span class="text-gray-300">○</span>
										{/if}
									</div>

									<!-- Stage Name -->
									<span
										class="w-32 text-sm {progress?.status === 'running'
											? 'text-blue-600 font-medium'
											: progress?.status === 'ok'
												? 'text-gray-700'
												: progress?.status === 'error'
													? 'text-red-600'
													: 'text-gray-400'}"
									>
										{STAGE_LABELS[stage]}
									</span>

									<!-- Summary -->
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
					</div>
				{:else if parseError || $parseMutation.isError}
					<div class="rounded-md bg-red-50 p-4">
						<p class="text-sm text-red-700">
							{mapParseError(parseError || $parseMutation.error?.message || '')}
						</p>
					</div>
				{:else if parseResult || effectiveMode === 'read'}
					{@const recordName = effectiveMode === 'read' ? displayRecord?.name : parseResult?.name}
					<!-- Title -->
					<div class="mb-6">
						<h3 class="text-xl font-medium text-gray-900">
							{getField(displayRecord, 'title_en', 'Title_EN') || 'Untitled'}
						</h3>
						{#if recordName}
							<a
								href="https://www.legislation.gov.uk/{recordName}"
								target="_blank"
								rel="noopener noreferrer"
								class="text-sm text-blue-600 hover:text-blue-800"
							>
								View on legislation.gov.uk
							</a>
						{/if}
					</div>

					<!-- Parse Stages Status (hidden in Read mode) -->
					{#if effectiveMode !== 'read' && parseResult}
					<div class="mb-6 bg-gray-50 rounded-lg p-4">
						<h4 class="text-sm font-medium text-gray-700 mb-3">Parse Stages</h4>
						<div class="grid grid-cols-2 md:grid-cols-4 gap-3">
							{#each Object.entries(parseResult.stages) as [stage, result]}
								<div
									class="flex items-center space-x-2 bg-white rounded px-3 py-2 border {result.status ===
									'error'
										? 'border-red-200 bg-red-50'
										: 'border-gray-200'}"
								>
									<span class="font-mono text-lg {getStageIcon(result.status)}">
										{getStageSymbol(result.status)}
									</span>
									<span class="text-sm text-gray-700 capitalize">{stage.replace('_', ' ')}</span>
								</div>
							{/each}
						</div>
						{#if parseResult.has_errors}
							<div class="mt-4 rounded-md bg-amber-50 border border-amber-200 p-3">
								<div class="flex">
									<svg
										class="h-5 w-5 text-amber-400 mr-2 flex-shrink-0"
										fill="none"
										stroke="currentColor"
										viewBox="0 0 24 24"
									>
										<path
											stroke-linecap="round"
											stroke-linejoin="round"
											stroke-width="2"
											d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
										/>
									</svg>
									<div class="flex-1">
										<div class="flex justify-between items-start">
											<h4 class="text-sm font-medium text-amber-800">Partial Parse Results</h4>
											<button
												on:click={retryFailedStages}
												disabled={isRetrying}
												class="ml-3 px-2 py-1 text-xs font-medium text-amber-700 bg-amber-100 border border-amber-300 rounded hover:bg-amber-200 disabled:opacity-50 disabled:cursor-not-allowed flex items-center"
											>
												{#if isRetrying}
													<svg
														class="animate-spin -ml-0.5 mr-1.5 h-3 w-3 text-amber-700"
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
													Retrying...
												{:else}
													<svg
														class="mr-1 h-3 w-3"
														fill="none"
														stroke="currentColor"
														viewBox="0 0 24 24"
													>
														<path
															stroke-linecap="round"
															stroke-linejoin="round"
															stroke-width="2"
															d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
														/>
													</svg>
													Retry Failed
												{/if}
											</button>
										</div>
										<p class="text-sm text-amber-700 mt-1">
											Some stages could not complete. Data from successful stages is still available
											and can be saved.
										</p>
										<ul class="list-disc list-inside mt-2 text-sm text-amber-600">
											{#each parseResult.errors as error}
												{@const [stage, ...rest] = error.split(': ')}
												<li>{mapStageError(stage, rest.join(': '))}</li>
											{/each}
										</ul>
									</div>
								</div>
							</div>
						{/if}
					</div>
					{/if}

					<!-- STAGE 1 💠 metadata -->
					{@const stage1Config = SECTION_CONFIG.find(s => s.id === 'stage1_metadata')}
					{#if stage1Config?.subsections}
						<CollapsibleSection
							title={stage1Config.title}
							expanded={stage1Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'metadata'}
							on:reparse={() => reparseStage('metadata')}
						>
							{#each stage1Config.subsections as subsection}
								<CollapsibleSection
									title={subsection.title}
									expanded={subsection.defaultExpanded}
									level="subsection"
								>
									{#each subsection.fields as field}
										{@const fieldValue = getFieldValue(displayRecord, field)}
										{#if field.editable && field.key === 'family' && effectiveMode !== 'read'}
											<!-- Special: Family dropdown (editable in Create/Update modes) -->
											<div class="grid grid-cols-3 px-4 py-2 items-center border-b border-gray-100 last:border-b-0">
												<span class="text-sm text-gray-500">
													{field.label} <span class="text-xs text-gray-400">({field.key})</span>
												</span>
												<div class="col-span-2">
													{#if $familyOptionsQuery.isPending}
														<span class="text-sm text-gray-400">Loading families...</span>
													{:else if $familyOptionsQuery.isError}
														<span class="text-sm text-red-500">Error loading families</span>
													{:else}
														<select
															bind:value={selectedFamily}
															class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
														>
															<option value="">(Uncategorized)</option>
															<optgroup label="Health & Safety">
																{#each $familyOptionsQuery.data?.grouped?.health_safety || [] as fam}
																	<option value={fam}>{fam}</option>
																{/each}
															</optgroup>
															<optgroup label="Environment">
																{#each $familyOptionsQuery.data?.grouped?.environment || [] as fam}
																	<option value={fam}>{fam}</option>
																{/each}
															</optgroup>
														</select>
													{/if}
												</div>
											</div>
										{:else if field.editable && field.key === 'family_ii' && effectiveMode !== 'read'}
											<!-- Special: Sub-Family dropdown (editable in Create/Update modes) -->
											<div class="grid grid-cols-3 px-4 py-2 items-center border-b border-gray-100 last:border-b-0">
												<span class="text-sm text-gray-500">
													{field.label} <span class="text-xs text-gray-400">({field.key})</span>
												</span>
												<div class="col-span-2">
													{#if $familyOptionsQuery.isPending}
														<span class="text-sm text-gray-400">Loading families...</span>
													{:else if $familyOptionsQuery.isError}
														<span class="text-sm text-red-500">Error loading families</span>
													{:else}
														<select
															bind:value={selectedSubFamily}
															class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
														>
															<option value="">(None)</option>
															<optgroup label="Health & Safety">
																{#each $familyOptionsQuery.data?.grouped?.health_safety || [] as fam}
																	<option value={fam}>{fam}</option>
																{/each}
															</optgroup>
															<optgroup label="Environment">
																{#each $familyOptionsQuery.data?.grouped?.environment || [] as fam}
																	<option value={fam}>{fam}</option>
																{/each}
															</optgroup>
														</select>
													{/if}
												</div>
											</div>
										{:else if !field.hideWhenEmpty || fieldHasData(fieldValue)}
											<FieldRow config={field} value={fieldValue} />
										{/if}
									{/each}
								</CollapsibleSection>
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 2 📍 geographic extent -->
					{@const stage2Config = SECTION_CONFIG.find(s => s.id === 'stage2_extent')}
					{#if stage2Config?.fields}
						<CollapsibleSection
							title={stage2Config.title}
							expanded={stage2Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'extent'}
							on:reparse={() => reparseStage('extent')}
						>
							{#each stage2Config.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 3 🚀 enacted_by -->
					{@const stage3Config = SECTION_CONFIG.find(s => s.id === 'stage3_enacted_by')}
					{#if stage3Config?.fields}
						<CollapsibleSection
							title={stage3Config.title}
							expanded={stage3Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'enacted_by'}
							on:reparse={() => reparseStage('enacted_by')}
						>
							{#each stage3Config.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 4 🔄 amending (this law affects others) -->
					{@const stage4Config = SECTION_CONFIG.find(s => s.id === 'stage4_amending')}
					{#if stage4Config?.subsections}
						<CollapsibleSection
							title={stage4Config.title}
							expanded={stage4Config.defaultExpanded}
							badge={displayRecord?.is_amending ? 'Amending' : displayRecord?.is_rescinding ? 'Rescinding' : ''}
							badgeColor={displayRecord?.is_rescinding ? 'red' : 'blue'}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'amending'}
							on:reparse={() => reparseStage('amending')}
						>
							{#each stage4Config.subsections as subsection}
								<CollapsibleSection
									title={subsection.title}
									expanded={subsection.defaultExpanded}
									level="subsection"
								>
									{#each subsection.fields as field}
										{@const fieldValue = getFieldValue(displayRecord, field)}
										{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
											<FieldRow config={field} value={fieldValue} />
										{/if}
									{/each}
								</CollapsibleSection>
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 5 🔄 amended_by (this law affected by others) -->
					{@const stage5Config = SECTION_CONFIG.find(s => s.id === 'stage5_amended_by')}
					{#if stage5Config?.subsections}
						<CollapsibleSection
							title={stage5Config.title}
							expanded={stage5Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'amended_by'}
							on:reparse={() => reparseStage('amended_by')}
						>
							{#each stage5Config.subsections as subsection}
								<CollapsibleSection
									title={subsection.title}
									expanded={subsection.defaultExpanded}
									level="subsection"
								>
									{#each subsection.fields as field}
										{@const fieldValue = getFieldValue(displayRecord, field)}
										{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
											<FieldRow config={field} value={fieldValue} />
										{/if}
									{/each}
								</CollapsibleSection>
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 6 🚫 repeal_revoke -->
					{@const stage6Config = SECTION_CONFIG.find(s => s.id === 'stage6_repeal_revoke')}
					{@const hasLiveConflict = displayRecord?.live_conflict === true}
					{#if stage6Config?.subsections}
						<CollapsibleSection
							title={stage6Config.title}
							expanded={stage6Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'repeal_revoke'}
							badge={hasLiveConflict ? 'Conflict' : ''}
							badgeColor={hasLiveConflict ? 'amber' : 'gray'}
							on:reparse={() => reparseStage('repeal_revoke')}
						>
							{#each stage6Config.subsections as subsection}
								<CollapsibleSection
									title={subsection.title}
									expanded={subsection.defaultExpanded}
									level="subsection"
									badge={subsection.id === 'reconciliation' && hasLiveConflict ? '!' : ''}
									badgeColor={hasLiveConflict ? 'amber' : 'gray'}
								>
									{#each subsection.fields as field}
										{@const fieldValue = getFieldValue(displayRecord, field)}
										{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
											<FieldRow config={field} value={fieldValue} />
										{/if}
									{/each}
								</CollapsibleSection>
							{/each}
						</CollapsibleSection>
					{:else if stage6Config?.fields}
						<!-- Fallback for old config without subsections -->
						<CollapsibleSection
							title={stage6Config.title}
							expanded={stage6Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'repeal_revoke'}
							on:reparse={() => reparseStage('repeal_revoke')}
						>
							{#each stage6Config.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 7 🦋 taxa -->
					{@const stage7Config = SECTION_CONFIG.find(s => s.id === 'stage7_taxa')}
					{#if stage7Config?.subsections}
						<CollapsibleSection
							title={stage7Config.title}
							expanded={stage7Config.defaultExpanded}
							showReparse={effectiveMode !== 'read' && !!parseResult}
							isReparsing={reparsingStage === 'taxa'}
							on:reparse={() => reparseStage('taxa')}
						>
							{#each stage7Config.subsections as subsection}
								<CollapsibleSection
									title={subsection.title}
									expanded={subsection.defaultExpanded}
									level="subsection"
								>
									{#each subsection.fields as field}
										{@const fieldValue = getFieldValue(displayRecord, field)}
										{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
											<FieldRow config={field} value={fieldValue} />
										{/if}
									{/each}
								</CollapsibleSection>
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- SECTION 8: CHANGE LOGS -->
					{@const changeLogsConfig = SECTION_CONFIG.find(s => s.id === 'change_logs')}
					{#if changeLogsConfig?.fields}
						<CollapsibleSection title={changeLogsConfig.title} expanded={changeLogsConfig.defaultExpanded}>
							{#each changeLogsConfig.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- SECTION 9: TIMESTAMPS -->
					{@const timestampsConfig = SECTION_CONFIG.find(s => s.id === 'timestamps')}
					{#if timestampsConfig?.fields}
						<CollapsibleSection title={timestampsConfig.title} expanded={timestampsConfig.defaultExpanded}>
							{#each timestampsConfig.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- Duplicate Warning with Diff (Update mode only) -->
					{#if effectiveMode === 'update' && parseResult?.duplicate?.exists}
						<div class="mb-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
							<div class="flex">
								<svg
									class="h-5 w-5 text-yellow-400 mr-2 flex-shrink-0"
									fill="none"
									stroke="currentColor"
									viewBox="0 0 24 24"
								>
									<path
										stroke-linecap="round"
										stroke-linejoin="round"
										stroke-width="2"
										d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
									/>
								</svg>
								<div class="flex-1">
									<h4 class="text-sm font-medium text-yellow-800">Existing Record Found</h4>
									<p class="text-sm text-yellow-700 mt-1">
										A record with name '{parseResult.name}' already exists in uk_lrt.
										<span class="text-xs text-yellow-600">
											(Family: {parseResult.duplicate.family || 'unset'} | Updated: {formatDate(
												parseResult.duplicate.updated_at
											)})
										</span>
									</p>
									<p class="text-sm text-yellow-700 mt-1">
										Confirming will <strong>update</strong> the existing record with the changes below.
									</p>
								</div>
							</div>
						</div>

						<!-- Record Diff Viewer -->
						{#if parseResult.duplicate.record && displayRecord}
							<div class="mb-6">
								<RecordDiff existing={parseResult.duplicate.record} incoming={displayRecord} />
							</div>
						{/if}
					{/if}
				{/if}
			</div>

			<!-- Footer -->
			<div class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex justify-between items-center">
				<div class="text-sm text-gray-500">
					{#if effectiveMode === 'read'}
						{displayRecord?.name || 'Record'}
					{:else}
						Record {currentIndex + 1} of {records.length}
					{/if}
				</div>
				<div class="flex items-center space-x-3">
					{#if effectiveMode !== 'read'}
					<!-- Navigation (Create/Update modes only) -->
					<div class="flex space-x-2 mr-4">
						<button
							on:click={movePrev}
							disabled={isFirst ||
								$parseMutation.isPending ||
								$confirmMutation.isPending ||
								isRetrying}
							class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Prev
						</button>
						<button
							on:click={moveNext}
							disabled={isLast ||
								$parseMutation.isPending ||
								$confirmMutation.isPending ||
								isRetrying}
							class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Next
						</button>
					</div>
					{/if}
					<button
						on:click={handleCancel}
						class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
					>
						{effectiveMode === 'read' ? 'Close' : 'Cancel'}
					</button>
					{#if effectiveMode !== 'read'}
					<button
						on:click={handleSkip}
						disabled={$parseMutation.isPending || $confirmMutation.isPending || isRetrying}
						class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						Skip
					</button>
					<button
						on:click={handleConfirm}
						disabled={!parseResult ||
							$parseMutation.isPending ||
							$confirmMutation.isPending ||
							isRetrying}
						class="px-4 py-2 text-sm text-white rounded-md disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center {parseResult?.has_errors
							? 'bg-amber-600 hover:bg-amber-700'
							: 'bg-blue-600 hover:bg-blue-700'}"
						title={parseResult?.has_errors
							? 'Save data from successful stages only'
							: 'Save all parsed data'}
					>
						{#if $confirmMutation.isPending}
							<svg
								class="animate-spin -ml-1 mr-2 h-4 w-4 text-white"
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
							Saving...
						{:else if parseResult?.has_errors}
							Save Partial Data
						{:else}
							Confirm & Save
						{/if}
					</button>
					{/if}
				</div>
			</div>
		</div>
	</div>
{/if}
