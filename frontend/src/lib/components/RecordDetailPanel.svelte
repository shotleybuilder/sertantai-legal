<!--
  RecordDetailPanel.svelte

  Pure display component for rendering all fields of a record in collapsible sections.
  Uses SECTION_CONFIG + FieldRow + CollapsibleSection from parse-review infrastructure.
  No parse logic, no streaming, no diff — just data display.

  Heavy JSONB fields (duties, rights, powers, etc.) not synced to PGLite are detected.
  When a section containing heavy fields is expanded and data is missing,
  a "Load details" button is shown. Clicking it calls the onloadheavy callback
  so the parent can fetch via REST.
-->
<script lang="ts">
	import CollapsibleSection from './CollapsibleSection.svelte';
	import FieldRow, { getFieldValue, hasData as fieldHasData } from './parse-review/FieldRow.svelte';
	import { SECTION_CONFIG, type SectionConfig } from './parse-review/field-config';

	let {
		record = null,
		sections = SECTION_CONFIG,
		hideEmpty = true,
		showFieldKeys = false,
		defaultExpanded = null,
		heavyLoaded = false,
		heavyLoading = false,
		onloadheavy
	}: {
		/** The record data to display */
		record?: Record<string, unknown> | null;
		/** Which sections to show (defaults to all SECTION_CONFIG) */
		sections?: SectionConfig[];
		/** Hide fields with no data */
		hideEmpty?: boolean;
		/** Show DB column names alongside labels */
		showFieldKeys?: boolean;
		/** Override default section expansion (null = use config defaults) */
		defaultExpanded?: boolean | null;
		/** Whether heavy JSONB data has been loaded */
		heavyLoaded?: boolean;
		/** Whether heavy JSONB data is currently loading */
		heavyLoading?: boolean;
		/** Callback when heavy data load is requested */
		onloadheavy?: () => void;
	} = $props();

	/**
	 * Heavy JSONB fields excluded from PGLite sync.
	 * Sections containing these fields show a "Load details" prompt
	 * until the parent fetches them via REST.
	 */
	const HEAVY_FIELDS = new Set([
		'role_details',
		'role_gvt_details',
		'duties',
		'responsibilities',
		'powers',
		'popimar_details',
		'rights',
		// Taxa fields (not synced to PGLite)
		'purpose',
		'duty_type',
		'duty_type_article',
		'article_duty_type',
		'duty_holder',
		'rights_holder',
		'responsibility_holder',
		'power_holder',
		'role',
		'role_gvt',
		'popimar',
		// Fitness fields (not synced to PGLite)
		'compiled_applicability'
	]);

	/** Check if a section (or its subsections) contains any heavy fields */
	function sectionHasHeavyFields(section: SectionConfig): boolean {
		if (section.fields) {
			return section.fields.some((f) => HEAVY_FIELDS.has(f.key));
		}
		if (section.subsections) {
			return section.subsections.some((sub) => sub.fields.some((f) => HEAVY_FIELDS.has(f.key)));
		}
		return false;
	}

	/** Check if a subsection contains any heavy fields */
	function subsectionHasHeavyFields(sub: { fields: { key: string }[] }): boolean {
		return sub.fields.some((f) => HEAVY_FIELDS.has(f.key));
	}

	/** Check if ALL subsections in a section are heavy (no light data to show) */
	function sectionAllSubsectionsHeavy(section: SectionConfig): boolean {
		if (!section.subsections) return false;
		return section.subsections.every((sub) => subsectionHasHeavyFields(sub));
	}

	function getSectionExpanded(section: SectionConfig): boolean {
		if (defaultExpanded !== null) return defaultExpanded;
		// Only collapse if ALL content is heavy and not yet loaded
		if (sectionAllSubsectionsHeavy(section) && !heavyLoaded) return false;
		if (!section.subsections && sectionHasHeavyFields(section) && !heavyLoaded) return false;
		return section.defaultExpanded ?? true;
	}

	function getSubsectionExpanded(defaultVal: boolean | undefined): boolean {
		if (defaultExpanded !== null) return defaultExpanded;
		return defaultVal ?? true;
	}
</script>

{#if record}
	{#each sections as section}
		{@const isHeavy = sectionHasHeavyFields(section)}
		{@const needsLoad = isHeavy && !heavyLoaded}

		{#if section.subsections}
			<CollapsibleSection title={section.title} expanded={getSectionExpanded(section)}>
				{#if needsLoad && sectionAllSubsectionsHeavy(section)}
					<!-- All subsections are heavy — show single load prompt -->
					<div class="px-4 py-6 text-center">
						{#if heavyLoading}
							<div class="flex items-center justify-center gap-2 text-sm text-gray-500">
								<svg class="animate-spin h-4 w-4 text-blue-500" fill="none" viewBox="0 0 24 24">
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
								Loading detailed data...
							</div>
						{:else}
							<button
								onclick={() => onloadheavy?.()}
								class="text-sm text-blue-600 hover:text-blue-800 hover:underline"
							>
								Load detailed data
							</button>
							<p class="text-xs text-gray-400 mt-1">Large JSONB fields are not synced locally</p>
						{/if}
					</div>
				{:else}
					<!-- Render each subsection; heavy ones get individual load prompts -->
					{#each section.subsections as subsection}
						{@const subHeavy = subsectionHasHeavyFields(subsection)}
						{@const subNeedsLoad = subHeavy && !heavyLoaded}
						<CollapsibleSection
							title={subsection.title}
							expanded={getSubsectionExpanded(subsection.defaultExpanded)}
							level="subsection"
						>
							{#if subNeedsLoad}
								<div class="px-4 py-4 text-center">
									{#if heavyLoading}
										<div class="flex items-center justify-center gap-2 text-sm text-gray-500">
											<svg
												class="animate-spin h-4 w-4 text-blue-500"
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
											Loading...
										</div>
									{:else}
										<button
											onclick={() => onloadheavy?.()}
											class="text-sm text-blue-600 hover:text-blue-800 hover:underline"
										>
											Load detailed data
										</button>
									{/if}
								</div>
							{:else}
								{#each subsection.fields as field}
									{@const fieldValue = getFieldValue(record, field)}
									{#if !hideEmpty || !field.hideWhenEmpty || fieldHasData(fieldValue)}
										<FieldRow config={field} value={fieldValue} showFieldKey={showFieldKeys} />
									{/if}
								{/each}
							{/if}
						</CollapsibleSection>
					{/each}
				{/if}
			</CollapsibleSection>
		{:else if section.fields}
			<CollapsibleSection title={section.title} expanded={getSectionExpanded(section)}>
				{#if needsLoad}
					<div class="px-4 py-6 text-center">
						{#if heavyLoading}
							<div class="flex items-center justify-center gap-2 text-sm text-gray-500">
								<svg class="animate-spin h-4 w-4 text-blue-500" fill="none" viewBox="0 0 24 24">
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
								Loading detailed data...
							</div>
						{:else}
							<button
								onclick={() => onloadheavy?.()}
								class="text-sm text-blue-600 hover:text-blue-800 hover:underline"
							>
								Load detailed data
							</button>
							<p class="text-xs text-gray-400 mt-1">Large JSONB fields are not synced locally</p>
						{/if}
					</div>
				{:else}
					{#each section.fields as field}
						{@const fieldValue = getFieldValue(record, field)}
						{#if !hideEmpty || !field.hideWhenEmpty || fieldHasData(fieldValue)}
							<FieldRow config={field} value={fieldValue} showFieldKey={showFieldKeys} />
						{/if}
					{/each}
				{/if}
			</CollapsibleSection>
		{/if}
	{/each}
{:else}
	<div class="px-4 py-8 text-center text-gray-400">No record data</div>
{/if}
