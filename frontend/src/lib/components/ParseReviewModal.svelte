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

	export let sessionId: string;
	export let records: ScrapeRecord[] = [];
	export let initialIndex: number = 0;
	export let open: boolean = false;
	// Optional: limit which stages to run (e.g., ['amendments', 'repeal_revoke'] for cascade re-parse)
	export let stages: ParseStage[] | undefined = undefined;

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

	// Use plain object for better Svelte reactivity (Maps don't trigger updates reliably)
	type StageStatus = {
		status: 'pending' | 'running' | 'ok' | 'error' | 'skipped';
		summary: string | null;
	};
	let stageProgress: Record<ParseStage, StageStatus> = {
		metadata: { status: 'pending', summary: null },
		extent: { status: 'pending', summary: null },
		enacted_by: { status: 'pending', summary: null },
		amendments: { status: 'pending', summary: null },
		repeal_revoke: { status: 'pending', summary: null },
		taxa: { status: 'pending', summary: null }
	};

	// All stages in order
	const ALL_STAGES: ParseStage[] = [
		'metadata',
		'extent',
		'enacted_by',
		'amendments',
		'repeal_revoke',
		'taxa'
	];

	// Human-readable stage names
	const STAGE_LABELS: Record<ParseStage, string> = {
		metadata: 'Metadata',
		extent: 'Extent',
		enacted_by: 'Enacted By',
		amendments: 'Amendments',
		repeal_revoke: 'Repeal/Revoke',
		taxa: 'Taxa Classification'
	};

	$: currentRecord = records[currentIndex];
	$: isFirst = currentIndex === 0;
	$: isLast = currentIndex === records.length - 1;

	// For display: merge existing DB record with parsed changes (for selective stage parsing)
	// This shows the user complete data with parsed updates overlaid
	$: displayRecord = parseResult?.record
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
	$: if (
		open &&
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
			amendments: { status: activeStages.includes('amendments') ? 'pending' : 'skipped', summary: null },
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
				<h2 class="text-lg font-semibold text-gray-900">Parse Review</h2>
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
				{:else if parseResult}
					<!-- Title -->
					<div class="mb-6">
						<h3 class="text-xl font-medium text-gray-900">
							{getField(displayRecord, 'title_en', 'Title_EN') || 'Untitled'}
						</h3>
						<a
							href="https://www.legislation.gov.uk/{parseResult.name}"
							target="_blank"
							rel="noopener noreferrer"
							class="text-sm text-blue-600 hover:text-blue-800"
						>
							View on legislation.gov.uk
						</a>
					</div>

					<!-- Parse Stages Status -->
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

					<!-- STAGE 1 💠 metadata -->
					{@const stage1Config = SECTION_CONFIG.find(s => s.id === 'stage1_metadata')}
					{#if stage1Config?.subsections}
						<CollapsibleSection title={stage1Config.title} expanded={stage1Config.defaultExpanded}>
							{#each stage1Config.subsections as subsection}
								<CollapsibleSection
									title={subsection.title}
									expanded={subsection.defaultExpanded}
									level="subsection"
								>
									{#each subsection.fields as field}
										{@const fieldValue = getFieldValue(displayRecord, field)}
										{#if field.editable && field.key === 'family'}
											<!-- Special: Family dropdown -->
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
										{:else if field.editable && field.key === 'family_ii'}
											<!-- Special: Sub-Family dropdown -->
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

					<!-- STAGE 2 📍 extent -->
					{@const geoConfig = SECTION_CONFIG.find(s => s.id === 'geographic_extent')}
					{#if geoConfig?.fields}
						<CollapsibleSection title={geoConfig.title} expanded={geoConfig.defaultExpanded}>
							{#each geoConfig.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- STAGE 5 🚫 repeal_revoke: Status -->
					{@const statusConfig = SECTION_CONFIG.find(s => s.id === 'status')}
					{#if statusConfig?.fields}
						<CollapsibleSection title={statusConfig.title} expanded={statusConfig.defaultExpanded}>
							{#each statusConfig.fields as field}
								{@const fieldValue = getFieldValue(displayRecord, field)}
								{#if !field.hideWhenEmpty || fieldHasData(fieldValue)}
									<FieldRow config={field} value={fieldValue} />
								{/if}
							{/each}
						</CollapsibleSection>
					{/if}

					<!-- SECTION 6: FUNCTION (with subsections) -->
					{@const functionConfig = SECTION_CONFIG.find(s => s.id === 'function')}
					{#if functionConfig?.subsections}
						<CollapsibleSection
							title={functionConfig.title}
							expanded={functionConfig.defaultExpanded}
							badge={parseResult.record?.is_amending ? 'Amending' : parseResult.record?.is_rescinding ? 'Rescinding' : ''}
							badgeColor={parseResult.record?.is_rescinding ? 'red' : 'blue'}
						>
							{#each functionConfig.subsections as subsection}
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

					<!-- SECTION 7: TAXA (with subsections) -->
					{@const taxaConfig = SECTION_CONFIG.find(s => s.id === 'taxa')}
					{#if taxaConfig?.subsections}
						<CollapsibleSection title={taxaConfig.title} expanded={taxaConfig.defaultExpanded}>
							{#each taxaConfig.subsections as subsection}
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

					<!-- Duplicate Warning with Diff -->
					{#if parseResult.duplicate?.exists}
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
					Record {currentIndex + 1} of {records.length}
				</div>
				<div class="flex items-center space-x-3">
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
					<button
						on:click={handleCancel}
						class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50"
					>
						Cancel
					</button>
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
				</div>
			</div>
		</div>
	</div>
{/if}
