<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import {
		useParseOneMutation,
		useConfirmRecordMutation,
		useFamilyOptionsQuery
	} from '$lib/query/scraper';
	import type { ParseOneResult, ScrapeRecord } from '$lib/api/scraper';
	import RecordDiff from './RecordDiff.svelte';

	export let sessionId: string;
	export let records: ScrapeRecord[] = [];
	export let initialIndex: number = 0;
	export let open: boolean = false;

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

	$: currentRecord = records[currentIndex];
	$: isFirst = currentIndex === 0;
	$: isLast = currentIndex === records.length - 1;

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
		!$parseMutation.isPending
	) {
		parseCurrentRecord();
	}

	async function parseCurrentRecord() {
		if (!currentRecord) return;
		if (currentRecord.name === lastParsedName) return;
		if (failedNames.has(currentRecord.name)) return;

		parseResult = null;
		lastParsedName = currentRecord.name;

		try {
			const result = await $parseMutation.mutateAsync({
				sessionId,
				name: currentRecord.name
			});
			parseResult = result;
			// API normalizes Family to lowercase family
			selectedFamily = (result.record?.family as string) || '';
			selectedSubFamily = (result.record?.family_ii as string) || '';
		} catch (error) {
			console.error('Parse error:', error);
			// Mark this name as failed to prevent infinite retry loops
			failedNames.add(currentRecord.name);
		}
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
		currentIndex = initialIndex;  // Reset to initial index for new records
		confirmedCount = 0;
		skippedCount = 0;
		errorCount = 0;
		failedNames = new Set();
		lastParsedName = null;
		parseResult = null;
		workflowComplete = false;  // Reset workflow flag for new records
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

	// Helper to check if a field has meaningful data (not empty)
	function hasData(value: unknown): boolean {
		if (value === null || value === undefined) return false;
		if (value === '' || value === '-' || value === '(none)') return false;
		if (Array.isArray(value) && value.length === 0) return false;
		if (typeof value === 'object' && Object.keys(value).length === 0) return false;
		if (typeof value === 'number' && value === 0) return false;
		return true;
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
				{#if $parseMutation.isPending}
					<div class="flex flex-col items-center justify-center py-12">
						<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mb-4"></div>
						<p class="text-gray-500">Parsing {currentRecord?.name}...</p>
						<p class="text-sm text-gray-400 mt-1">Fetching metadata from legislation.gov.uk</p>
					</div>
				{:else if $parseMutation.isError}
					<div class="rounded-md bg-red-50 p-4">
						<p class="text-sm text-red-700">{$parseMutation.error?.message}</p>
					</div>
				{:else if parseResult}
					<!-- Title -->
					<div class="mb-6">
						<h3 class="text-xl font-medium text-gray-900">
							{getField(parseResult.record, 'title_en', 'Title_EN') || 'Untitled'}
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
									class="flex items-center space-x-2 bg-white rounded px-3 py-2 border border-gray-200"
								>
									<span class="font-mono text-lg {getStageIcon(result.status)}">
										{getStageSymbol(result.status)}
									</span>
									<span class="text-sm text-gray-700 capitalize">{stage.replace('_', ' ')}</span>
								</div>
							{/each}
						</div>
						{#if parseResult.errors.length > 0}
							<div class="mt-3 text-sm text-red-600">
								<strong>Errors:</strong>
								<ul class="list-disc list-inside mt-1">
									{#each parseResult.errors as error}
										<li>{error}</li>
									{/each}
								</ul>
							</div>
						{/if}
					</div>

					<!-- SECTION 1: CREDENTIALS -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Credentials</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Title <span class="text-xs text-gray-400">(title_en)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'title_en', 'Title_EN'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Year <span class="text-xs text-gray-400">(year)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'year', 'Year'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Number <span class="text-xs text-gray-400">(number)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'number', 'Number'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Type Code <span class="text-xs text-gray-400">(type_code)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'type_code'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Type Description <span class="text-xs text-gray-400">(type_desc)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'type_desc'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Type Class <span class="text-xs text-gray-400">(type_class)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'type_class'))}</span
								>
							</div>
						</div>
					</div>

					<!-- SECTION 2: DESCRIPTION -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Description</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2 items-center">
								<span class="text-sm text-gray-500"
									>Family <span class="text-xs text-gray-400">(family)</span></span
								>
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
												{#each $familyOptionsQuery.data?.grouped?.health_safety || [] as family}
													<option value={family}>{family}</option>
												{/each}
											</optgroup>
											<optgroup label="Environment">
												{#each $familyOptionsQuery.data?.grouped?.environment || [] as family}
													<option value={family}>{family}</option>
												{/each}
											</optgroup>
										</select>
									{/if}
								</div>
							</div>
							<div class="grid grid-cols-3 px-4 py-2 items-center">
								<span class="text-sm text-gray-500"
									>Sub-Family <span class="text-xs text-gray-400">(family_ii)</span></span
								>
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
												{#each $familyOptionsQuery.data?.grouped?.health_safety || [] as family}
													<option value={family}>{family}</option>
												{/each}
											</optgroup>
											<optgroup label="Environment">
												{#each $familyOptionsQuery.data?.grouped?.environment || [] as family}
													<option value={family}>{family}</option>
												{/each}
											</optgroup>
										</select>
									{/if}
								</div>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>SI Codes <span class="text-xs text-gray-400">(si_code)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'si_code', 'SICode'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Tags <span class="text-xs text-gray-400">(tags)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'tags'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Description <span class="text-xs text-gray-400">(md_description)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'md_description'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Subjects <span class="text-xs text-gray-400">(md_subjects)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'md_subjects'))}</span
								>
							</div>
						</div>
					</div>

					<!-- SECTION 3: STATUS -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Status</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Status <span class="text-xs text-gray-400">(live)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'live'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Status Description <span class="text-xs text-gray-400">(live_description)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'live_description'))}</span
								>
							</div>
						</div>
					</div>

					<!-- SECTION 4: GEOGRAPHIC EXTENT -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Geographic Extent</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Region <span class="text-xs text-gray-400">(geo_extent)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'geo_extent', 'extent'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Country <span class="text-xs text-gray-400">(geo_region)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'geo_region', 'extent_regions'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Detail <span class="text-xs text-gray-400">(geo_detail)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900 whitespace-pre-line"
									>{formatValue(getField(parseResult.record, 'geo_detail'))}</span
								>
							</div>
						</div>
					</div>

					<!-- SECTION 5: METADATA -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Metadata</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Primary Date <span class="text-xs text-gray-400">(md_date)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatDate(getField(parseResult.record, 'md_date'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Made Date <span class="text-xs text-gray-400">(md_made_date)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatDate(getField(parseResult.record, 'md_made_date'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Enacted Date <span class="text-xs text-gray-400">(md_enactment_date)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatDate(getField(parseResult.record, 'md_enactment_date'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>In Force Date <span class="text-xs text-gray-400"
										>(md_coming_into_force_date)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatDate(getField(parseResult.record, 'md_coming_into_force_date'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>DCT Valid Date <span class="text-xs text-gray-400">(md_dct_valid_date)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatDate(getField(parseResult.record, 'md_dct_valid_date'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Restriction Start <span class="text-xs text-gray-400"
										>(md_restrict_start_date)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatDate(getField(parseResult.record, 'md_restrict_start_date'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Total Paragraphs <span class="text-xs text-gray-400">(md_total_paras)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'md_total_paras'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Body Paragraphs <span class="text-xs text-gray-400">(md_body_paras)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'md_body_paras'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Schedule Paragraphs <span class="text-xs text-gray-400">(md_schedule_paras)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'md_schedule_paras'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Attachment Paragraphs <span class="text-xs text-gray-400"
										>(md_attachment_paras)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'md_attachment_paras'))}</span
								>
							</div>
						</div>
					</div>

					<!-- SECTION 6: FUNCTION -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div
							class="bg-gray-50 px-4 py-2 border-b border-gray-200 flex justify-between items-center"
						>
							<h4 class="text-sm font-medium text-gray-700">Function</h4>
							<div class="flex space-x-2">
								{#if parseResult.record?.is_amending}
									<span class="px-2 py-0.5 text-xs bg-blue-100 text-blue-800 rounded"
										>Amending Law</span
									>
								{/if}
								{#if parseResult.record?.is_rescinding}
									<span class="px-2 py-0.5 text-xs bg-red-100 text-red-800 rounded"
										>Rescinding Law</span
									>
								{/if}
							</div>
						</div>
						<div class="divide-y divide-gray-100">
							<!-- Function -->
							{#if hasData(getField(parseResult.record, 'function'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Function <span class="text-xs text-gray-400">(function)</span></span
									>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(getField(parseResult.record, 'function'))}</span
									>
								</div>
							{/if}

							<!-- Enacting -->
							{#if hasData(getField(parseResult.record, 'enacting'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Enacts <span class="text-xs text-gray-400">(enacting)</span></span
									>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(getField(parseResult.record, 'enacting'))}</span
									>
								</div>
							{/if}

							<!-- Enacted By -->
							{#if hasData(getField(parseResult.record, 'enacted_by')) || parseResult.record?.is_act}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Enacted By <span class="text-xs text-gray-400">(enacted_by)</span></span
									>
									<span class="col-span-2 text-sm text-gray-900">
										{#if parseResult.record?.enacted_by && Array.isArray(parseResult.record.enacted_by) && parseResult.record.enacted_by.length > 0}
											{#each parseResult.record.enacted_by as law}
												<a
													href={typeof law === 'object' && law.uri
														? law.uri
														: `https://www.legislation.gov.uk/${typeof law === 'object' ? law.name : law}`}
													target="_blank"
													rel="noopener noreferrer"
													class="text-blue-600 hover:text-blue-800 mr-2"
													title={typeof law === 'object' && law.title ? law.title : ''}
												>
													{typeof law === 'object'
														? law.title || law.name
														: law}
												</a>
											{/each}
										{:else if parseResult.record?.is_act}
											<span class="italic text-gray-500"
												>Primary legislation - not enacted by other laws</span
											>
										{/if}
									</span>
								</div>
							{/if}

							<!-- Amending section -->
							{#if hasData(getField(parseResult.record, 'amending')) || Number(parseResult.record?.amending_count) > 0}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Amends <span class="text-xs text-gray-400">(amending)</span></span
									>
									<span class="col-span-2 text-sm text-gray-900">
										{#if parseResult.record?.amending && Array.isArray(parseResult.record.amending) && parseResult.record.amending.length > 0}
											{parseResult.record.amending.join(', ')}
										{:else if Number(parseResult.record?.amending_count) > 0}
											{parseResult.record.amending_count}
											{Number(parseResult.record.amending_count) === 1 ? 'law' : 'laws'}
										{/if}
									</span>
								</div>
							{/if}

							<!-- Amending Stats -->
							{#if hasData(getField(parseResult.record, 'amending_stats_affects_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Affects Count <span class="text-xs text-gray-400">(🔺_stats_affects_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(
											getField(parseResult.record, 'amending_stats_affects_count')
										)}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'amending_stats_affected_laws_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Affected Laws Count <span class="text-xs text-gray-400">(🔺_stats_affected_laws_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(
											getField(parseResult.record, 'amending_stats_affected_laws_count')
										)}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'amending_stats_affects_count_per_law_detailed'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Affects Per Law (Detail) <span class="text-xs text-gray-400">(🔺_stats_affects_count_per_law_detailed)</span></span>
									<div class="col-span-2">
										<div class="text-xs text-gray-400 italic mb-1">Law - Count / Section Action [Status]</div>
										<span
											class="text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto block"
											>{formatValue(
												getField(parseResult.record, 'amending_stats_affects_count_per_law_detailed')
											)}</span
										>
									</div>
								</div>
							{/if}

							<!-- Amended By section -->
							{#if hasData(getField(parseResult.record, 'amended_by')) || Number(parseResult.record?.amended_by_count) > 0}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Amended By <span class="text-xs text-gray-400">(amended_by)</span></span
									>
									<span class="col-span-2 text-sm text-gray-900">
										{#if parseResult.record?.amended_by && Array.isArray(parseResult.record.amended_by) && parseResult.record.amended_by.length > 0}
											{parseResult.record.amended_by.join(', ')}
										{:else if Number(parseResult.record?.amended_by_count) > 0}
											{parseResult.record.amended_by_count}
											{Number(parseResult.record.amended_by_count) === 1 ? 'law' : 'laws'}
										{/if}
									</span>
								</div>
							{/if}

							<!-- Amended By Stats -->
							{#if hasData(getField(parseResult.record, 'amended_by_stats_affected_by_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Affected By Count <span class="text-xs text-gray-400">(🔻_stats_affected_by_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(
											getField(parseResult.record, 'amended_by_stats_affected_by_count')
										)}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'amended_by_stats_affected_by_laws_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Amending Laws Count <span class="text-xs text-gray-400">(🔻_stats_affected_by_laws_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(
											getField(parseResult.record, 'amended_by_stats_affected_by_laws_count')
										)}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'amended_by_stats_affected_by_count_per_law_detailed'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Affected By Per Law (Detail) <span class="text-xs text-gray-400">(🔻_stats_affected_by_count_per_law_detailed)</span></span>
									<div class="col-span-2">
										<div class="text-xs text-gray-400 italic mb-1">Law - Count / Section Action [Status]</div>
										<span
											class="text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto block"
											>{formatValue(
												getField(
													parseResult.record,
													'amended_by_stats_affected_by_count_per_law_detailed'
												)
											)}</span
										>
									</div>
								</div>
							{/if}

							<!-- Rescinding section -->
							{#if hasData(getField(parseResult.record, 'rescinding')) || Number(parseResult.record?.rescinding_count) > 0}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Rescinds <span class="text-xs text-gray-400">(rescinding)</span></span
									>
									<span class="col-span-2 text-sm text-gray-900">
										{#if parseResult.record?.rescinding && Array.isArray(parseResult.record.rescinding) && parseResult.record.rescinding.length > 0}
											{parseResult.record.rescinding.join(', ')}
										{:else if Number(parseResult.record?.rescinding_count) > 0}
											{parseResult.record.rescinding_count}
											{Number(parseResult.record.rescinding_count) === 1 ? 'law' : 'laws'}
										{/if}
									</span>
								</div>
							{/if}

							<!-- Rescinding Stats -->
							{#if hasData(getField(parseResult.record, 'rescinding_stats_rescinding_laws_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Rescinded Laws Count <span class="text-xs text-gray-400">(🔺_stats_rescinding_laws_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(
											getField(parseResult.record, 'rescinding_stats_rescinding_laws_count')
										)}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'rescinding_stats_rescinding_count_per_law_detailed'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Rescinding Per Law (Detail) <span class="text-xs text-gray-400">(🔺_stats_rescinding_count_per_law_detailed)</span></span>
									<div class="col-span-2">
										<div class="text-xs text-gray-400 italic mb-1">Law - Count / Section Action [Status]</div>
										<span
											class="text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto block"
											>{formatValue(
												getField(
													parseResult.record,
													'rescinding_stats_rescinding_count_per_law_detailed'
												)
											)}</span
										>
									</div>
								</div>
							{/if}

							<!-- Rescinded By section -->
							{#if hasData(getField(parseResult.record, 'rescinded_by')) || Number(parseResult.record?.rescinded_by_count) > 0}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Rescinded By <span class="text-xs text-gray-400">(rescinded_by)</span></span
									>
									<span
										class="col-span-2 text-sm {parseResult.record?.rescinded_by &&
										Array.isArray(parseResult.record.rescinded_by) &&
										parseResult.record.rescinded_by.length > 0
											? 'text-red-600 font-medium'
											: 'text-gray-900'}"
									>
										{#if parseResult.record?.rescinded_by && Array.isArray(parseResult.record.rescinded_by) && parseResult.record.rescinded_by.length > 0}
											{parseResult.record.rescinded_by.join(', ')}
										{:else if Number(parseResult.record?.rescinded_by_count) > 0}
											{parseResult.record.rescinded_by_count}
											{Number(parseResult.record.rescinded_by_count) === 1 ? 'law' : 'laws'}
										{/if}
									</span>
								</div>
							{/if}

							<!-- Rescinded By Stats -->
							{#if hasData(getField(parseResult.record, 'rescinded_by_stats_rescinded_by_laws_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Rescinding Laws Count <span class="text-xs text-gray-400">(🔻_stats_rescinded_by_laws_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(
											getField(parseResult.record, 'rescinded_by_stats_rescinded_by_laws_count')
										)}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'rescinded_by_stats_rescinded_by_count_per_law_detailed'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Rescinded By Per Law (Detail) <span class="text-xs text-gray-400">(🔻_stats_rescinded_by_count_per_law_detailed)</span></span>
									<div class="col-span-2">
										<div class="text-xs text-gray-400 italic mb-1">Law - Count / Section Action [Status]</div>
										<span
											class="text-sm text-red-600 whitespace-pre-line max-h-32 overflow-y-auto block"
											>{formatValue(
												getField(
													parseResult.record,
													'rescinded_by_stats_rescinded_by_count_per_law_detailed'
												)
											)}</span
										>
									</div>
								</div>
							{/if}

							<!-- Self Amendments (shared stat) -->
							{#if hasData(getField(parseResult.record, 'stats_self_affects_count'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500">Self Amendments <span class="text-xs text-gray-400">(🔺🔻_stats_self_affects_count)</span></span>
									<span class="col-span-2 text-sm text-gray-900"
										>{formatValue(getField(parseResult.record, 'stats_self_affects_count'))}</span
									>
								</div>
							{/if}
							{#if hasData(getField(parseResult.record, 'stats_self_affects_count_per_law_detailed'))}
								<div class="grid grid-cols-3 px-4 py-2">
									<span class="text-sm text-gray-500"
										>Self Amendments (Detail) <span class="text-xs text-gray-400"
											>(🔺🔻_stats_self_affects_count_per_law_detailed)</span
										></span
									>
									<div class="col-span-2">
										<div class="text-xs text-gray-400 italic mb-1">
											Count / Section Action [Status]
										</div>
										<span
											class="text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto block"
											>{formatValue(
												getField(parseResult.record, 'stats_self_affects_count_per_law_detailed')
											)}</span
										>
									</div>
								</div>
							{/if}
						</div>
					</div>

					<!-- SECTION 7: ROLES (DRRP Model) - Taxa Classification -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Roles (DRRP Model)</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<!-- Duty Type -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Duty Type <span class="text-xs text-gray-400">(duty_type)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'duty_type'))}</span
								>
							</div>
							{#if hasData(getField(parseResult.record, 'duty_type_article'))}
								<div class="grid grid-cols-3 px-4 py-2 bg-gray-50">
									<span class="text-sm text-gray-500 pl-4"
										>Duty Type Article <span class="text-xs text-gray-400">(duty_type_article)</span
										></span
									>
									<span
										class="col-span-2 text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto"
										>{formatValue(getField(parseResult.record, 'duty_type_article'))}</span
									>
								</div>
							{/if}

							<!-- Duty Holders -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Duty Holders <span class="text-xs text-gray-400">(duty_holder)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'duty_holder'))}</span
								>
							</div>
							{#if hasData(getField(parseResult.record, 'duty_holder_article_clause'))}
								<div class="grid grid-cols-3 px-4 py-2 bg-gray-50">
									<span class="text-sm text-gray-500 pl-4"
										>Duty Holder Clauses <span class="text-xs text-gray-400"
											>(duty_holder_article_clause)</span
										></span
									>
									<span
										class="col-span-2 text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto"
										>{formatValue(getField(parseResult.record, 'duty_holder_article_clause'))}</span
									>
								</div>
							{/if}

							<!-- Rights Holders -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Rights Holders <span class="text-xs text-gray-400">(rights_holder)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'rights_holder'))}</span
								>
							</div>
							{#if hasData(getField(parseResult.record, 'rights_holder_article_clause'))}
								<div class="grid grid-cols-3 px-4 py-2 bg-gray-50">
									<span class="text-sm text-gray-500 pl-4"
										>Rights Holder Clauses <span class="text-xs text-gray-400"
											>(rights_holder_article_clause)</span
										></span
									>
									<span
										class="col-span-2 text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto"
										>{formatValue(
											getField(parseResult.record, 'rights_holder_article_clause')
										)}</span
									>
								</div>
							{/if}

							<!-- Responsibility Holders -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Responsibility Holders <span class="text-xs text-gray-400"
										>(responsibility_holder)</span
									></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'responsibility_holder'))}</span
								>
							</div>
							{#if hasData(getField(parseResult.record, 'responsibility_holder_article_clause'))}
								<div class="grid grid-cols-3 px-4 py-2 bg-gray-50">
									<span class="text-sm text-gray-500 pl-4"
										>Responsibility Holder Clauses <span class="text-xs text-gray-400"
											>(responsibility_holder_article_clause)</span
										></span
									>
									<span
										class="col-span-2 text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto"
										>{formatValue(
											getField(parseResult.record, 'responsibility_holder_article_clause')
										)}</span
									>
								</div>
							{/if}

							<!-- Power Holders -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Power Holders <span class="text-xs text-gray-400">(power_holder)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'power_holder'))}</span
								>
							</div>
							{#if hasData(getField(parseResult.record, 'power_holder_article_clause'))}
								<div class="grid grid-cols-3 px-4 py-2 bg-gray-50">
									<span class="text-sm text-gray-500 pl-4"
										>Power Holder Clauses <span class="text-xs text-gray-400"
											>(power_holder_article_clause)</span
										></span
									>
									<span
										class="col-span-2 text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto"
										>{formatValue(
											getField(parseResult.record, 'power_holder_article_clause')
										)}</span
									>
								</div>
							{/if}

							<!-- Roles (Actors) -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Roles <span class="text-xs text-gray-400">(role)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'role'))}</span
								>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Government Roles <span class="text-xs text-gray-400">(role_gvt)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'role_gvt'))}</span
								>
							</div>

							<!-- POPIMAR -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>POPIMAR <span class="text-xs text-gray-400">(popimar)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'popimar'))}</span
								>
							</div>
							{#if hasData(getField(parseResult.record, 'popimar_article_clause'))}
								<div class="grid grid-cols-3 px-4 py-2 bg-gray-50">
									<span class="text-sm text-gray-500 pl-4"
										>POPIMAR Clauses <span class="text-xs text-gray-400"
											>(popimar_article_clause)</span
										></span
									>
									<span
										class="col-span-2 text-sm text-gray-900 whitespace-pre-line max-h-32 overflow-y-auto"
										>{formatValue(getField(parseResult.record, 'popimar_article_clause'))}</span
									>
								</div>
							{/if}

							<!-- Purpose -->
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500"
									>Purpose <span class="text-xs text-gray-400">(purpose)</span></span
								>
								<span class="col-span-2 text-sm text-gray-900"
									>{formatValue(getField(parseResult.record, 'purpose'))}</span
								>
							</div>
						</div>
					</div>

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
						{#if parseResult.duplicate.record && parseResult.record}
							<div class="mb-6">
								<RecordDiff
									existing={parseResult.duplicate.record}
									incoming={parseResult.record}
								/>
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
							disabled={isFirst || $parseMutation.isPending || $confirmMutation.isPending}
							class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
						>
							Prev
						</button>
						<button
							on:click={moveNext}
							disabled={isLast || $parseMutation.isPending || $confirmMutation.isPending}
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
						disabled={$parseMutation.isPending || $confirmMutation.isPending}
						class="px-4 py-2 text-sm text-gray-700 border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed"
					>
						Skip
					</button>
					<button
						on:click={handleConfirm}
						disabled={!parseResult || $parseMutation.isPending || $confirmMutation.isPending}
						class="px-4 py-2 text-sm text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed flex items-center"
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
						{:else}
							Confirm & Save
						{/if}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
