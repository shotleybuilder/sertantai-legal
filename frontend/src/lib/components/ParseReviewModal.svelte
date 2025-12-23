<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import {
		useParseOneMutation,
		useConfirmRecordMutation,
		useFamilyOptionsQuery
	} from '$lib/query/scraper';
	import type { ParseOneResult, ScrapeRecord } from '$lib/api/scraper';

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
	let confirmedCount = 0;
	let skippedCount = 0;
	let errorCount = 0;

	$: currentRecord = records[currentIndex];
	$: isFirst = currentIndex === 0;
	$: isLast = currentIndex === records.length - 1;

	// Track the last parsed record name to prevent re-parsing
	let lastParsedName: string | null = null;

	// Parse current record when index changes (only if not already parsed)
	$: if (open && currentRecord && currentRecord.name !== lastParsedName && !$parseMutation.isPending) {
		parseCurrentRecord();
	}

	async function parseCurrentRecord() {
		if (!currentRecord) return;
		if (currentRecord.name === lastParsedName) return;

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
		} catch (error) {
			console.error('Parse error:', error);
			lastParsedName = null;
		}
	}

	async function handleConfirm() {
		if (!parseResult || !currentRecord) return;

		try {
			await $confirmMutation.mutateAsync({
				sessionId,
				name: currentRecord.name,
				family: selectedFamily || undefined
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
			currentIndex++;
			parseResult = null;
			lastParsedName = null;
		}
	}

	function movePrev() {
		if (!isFirst) {
			currentIndex--;
			parseResult = null;
			lastParsedName = null;
		}
	}

	function handleCancel() {
		lastParsedName = null;
		dispatch('close');
	}

	function handleComplete() {
		lastParsedName = null;
		dispatch('complete', {
			confirmed: confirmedCount,
			skipped: skippedCount,
			errors: errorCount
		});
	}

	// Reset state when modal opens with new records
	$: if (open && records.length > 0) {
		if (currentIndex === initialIndex && !parseResult && !$parseMutation.isPending) {
			confirmedCount = 0;
			skippedCount = 0;
			errorCount = 0;
		}
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
		if (typeof value === 'object') return JSON.stringify(value);
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
	function getField(record: Record<string, unknown> | null | undefined, ...keys: string[]): unknown {
		if (!record) return null;
		for (const key of keys) {
			if (record[key] !== undefined && record[key] !== null) {
				return record[key];
			}
		}
		return null;
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
								<span class="text-sm text-gray-500">Title <span class="text-xs text-gray-400">(title_en)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'title_en', 'Title_EN'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Year <span class="text-xs text-gray-400">(year)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'year', 'Year'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Number <span class="text-xs text-gray-400">(number)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'number', 'Number'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Type Code <span class="text-xs text-gray-400">(type_code)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'type_code'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Type Description <span class="text-xs text-gray-400">(type_desc)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'type_desc'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Type Class <span class="text-xs text-gray-400">(type_class)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'type_class'))}</span>
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
								<span class="text-sm text-gray-500">Family <span class="text-xs text-gray-400">(family)</span></span>
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
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Sub-Family <span class="text-xs text-gray-400">(family_ii)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'family_ii'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">SI Codes <span class="text-xs text-gray-400">(si_code)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'si_code', 'SICode'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Tags <span class="text-xs text-gray-400">(tags)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'tags'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Description <span class="text-xs text-gray-400">(md_description)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'md_description'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Subjects <span class="text-xs text-gray-400">(md_subjects)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'md_subjects'))}</span>
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
								<span class="text-sm text-gray-500">Status <span class="text-xs text-gray-400">(live)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'live'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Status Description <span class="text-xs text-gray-400">(live_description)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'live_description'))}</span>
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
								<span class="text-sm text-gray-500">Geographic Extent <span class="text-xs text-gray-400">(geo_extent)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'geo_extent', 'extent'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Region <span class="text-xs text-gray-400">(geo_region)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'geo_region', 'extent_regions'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Country <span class="text-xs text-gray-400">(geo_country)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'geo_country'))}</span>
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
								<span class="text-sm text-gray-500">Primary Date <span class="text-xs text-gray-400">(md_date)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatDate(getField(parseResult.record, 'md_date'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Made Date <span class="text-xs text-gray-400">(md_made_date)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatDate(getField(parseResult.record, 'md_made_date'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Enacted Date <span class="text-xs text-gray-400">(md_enactment_date)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatDate(getField(parseResult.record, 'md_enactment_date'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">In Force Date <span class="text-xs text-gray-400">(md_coming_into_force_date)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatDate(getField(parseResult.record, 'md_coming_into_force_date'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">DCT Valid Date <span class="text-xs text-gray-400">(md_dct_valid_date)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatDate(getField(parseResult.record, 'md_dct_valid_date'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Restriction Start <span class="text-xs text-gray-400">(md_restrict_start_date)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatDate(getField(parseResult.record, 'md_restrict_start_date'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Total Paragraphs <span class="text-xs text-gray-400">(md_total_paras)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'md_total_paras'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Body Paragraphs <span class="text-xs text-gray-400">(md_body_paras)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'md_body_paras'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Schedule Paragraphs <span class="text-xs text-gray-400">(md_schedule_paras)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'md_schedule_paras'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Attachment Paragraphs <span class="text-xs text-gray-400">(md_attachment_paras)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'md_attachment_paras'))}</span>
							</div>
						</div>
					</div>

					<!-- SECTION 6: FUNCTION -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Function</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Function <span class="text-xs text-gray-400">(function)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'function'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Enacts <span class="text-xs text-gray-400">(enacting)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'enacting'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Enacted By <span class="text-xs text-gray-400">(enacted_by)</span></span>
								<span class="col-span-2 text-sm text-gray-900">
									{#if parseResult.record?.enacted_by && Array.isArray(parseResult.record.enacted_by) && parseResult.record.enacted_by.length > 0}
										{#each parseResult.record.enacted_by as law}
											<a
												href="https://www.legislation.gov.uk/{typeof law === 'object' ? law.name : law}"
												target="_blank"
												rel="noopener noreferrer"
												class="text-blue-600 hover:text-blue-800 mr-2"
											>
												{typeof law === 'object' ? law.name : law}
											</a>
										{/each}
									{:else if parseResult.record?.is_act}
										<span class="italic text-gray-500">Primary legislation - not enacted by other laws</span>
									{:else}
										(none)
									{/if}
								</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Amends <span class="text-xs text-gray-400">(amending)</span></span>
								<span class="col-span-2 text-sm text-gray-900">
									{#if parseResult.record?.amends && Array.isArray(parseResult.record.amends) && parseResult.record.amends.length > 0}
										{parseResult.record.amends.length} laws
									{:else}
										{formatValue(getField(parseResult.record, 'amending'))}
									{/if}
								</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Amended By <span class="text-xs text-gray-400">(amended_by)</span></span>
								<span class="col-span-2 text-sm text-gray-900">
									{#if parseResult.record?.amended_by && Array.isArray(parseResult.record.amended_by) && parseResult.record.amended_by.length > 0}
										{parseResult.record.amended_by.length} laws
									{:else}
										(none)
									{/if}
								</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Rescinds <span class="text-xs text-gray-400">(rescinding)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'rescinding'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Rescinded By <span class="text-xs text-gray-400">(rescinded_by)</span></span>
								<span class="col-span-2 text-sm text-gray-900 {getField(parseResult.record, 'rescinded_by') ? 'text-red-600 font-medium' : ''}">
									{formatValue(getField(parseResult.record, 'rescinded_by'))}
								</span>
							</div>
						</div>
					</div>

					<!-- SECTION 7: ROLES (DRRP Model) -->
					<div class="mb-6 bg-white border border-gray-200 rounded-lg overflow-hidden">
						<div class="bg-gray-50 px-4 py-2 border-b border-gray-200">
							<h4 class="text-sm font-medium text-gray-700">Roles (DRRP Model)</h4>
						</div>
						<div class="divide-y divide-gray-100">
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Duty Holders <span class="text-xs text-gray-400">(duty_holder)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'duty_holder'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Power Holders <span class="text-xs text-gray-400">(power_holder)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'power_holder'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Rights Holders <span class="text-xs text-gray-400">(rights_holder)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'rights_holder'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Responsibility Holders <span class="text-xs text-gray-400">(responsibility_holder)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'responsibility_holder'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Roles <span class="text-xs text-gray-400">(role)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'role'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Government Roles <span class="text-xs text-gray-400">(role_gvt)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'role_gvt'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">POPIMAR <span class="text-xs text-gray-400">(popimar)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'popimar'))}</span>
							</div>
							<div class="grid grid-cols-3 px-4 py-2">
								<span class="text-sm text-gray-500">Purpose <span class="text-xs text-gray-400">(purpose)</span></span>
								<span class="col-span-2 text-sm text-gray-900">{formatValue(getField(parseResult.record, 'purpose'))}</span>
							</div>
						</div>
					</div>

					<!-- Duplicate Warning -->
					{#if parseResult.duplicate?.exists}
						<div class="mb-6 bg-yellow-50 border border-yellow-200 rounded-lg p-4">
							<div class="flex">
								<svg
									class="h-5 w-5 text-yellow-400 mr-2"
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
								<div>
									<h4 class="text-sm font-medium text-yellow-800">Duplicate Warning</h4>
									<p class="text-sm text-yellow-700 mt-1">
										A record with name '{parseResult.name}' already exists in uk_lrt.
										<br />
										<span class="text-xs text-yellow-600">
											Family: {parseResult.duplicate.family || 'unset'} |
											Updated: {formatDate(parseResult.duplicate.updated_at)}
										</span>
									</p>
									<p class="text-sm text-yellow-700 mt-1">
										Confirming will <strong>update</strong> the existing record.
									</p>
								</div>
							</div>
						</div>
					{/if}
				{/if}
			</div>

			<!-- Footer -->
			<div
				class="px-6 py-4 border-t border-gray-200 bg-gray-50 flex justify-between items-center"
			>
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
