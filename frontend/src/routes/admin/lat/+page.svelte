<script lang="ts">
	import { onMount } from 'svelte';
	import {
		useLatStatsQuery,
		useLatLawsQuery,
		useLatRowsQuery,
		useAnnotationsQuery,
		useReparseMutation
	} from '$lib/query/lat';
	import type { LawSummary, LatRow, AnnotationRow } from '$lib/api/lat';

	// ── State ────────────────────────────────────────────────────────

	let searchText = '';
	let searchDebounced = '';
	let typeFilter = '';
	let debounceTimer: ReturnType<typeof setTimeout> | null = null;

	let selectedLaw: LawSummary | null = null;
	let activeTab: 'structure' | 'annotations' = 'structure';
	let expandedRows = new Set<string>();

	// Pagination
	let latLimit = 500;
	let latOffset = 0;

	// Reparse feedback
	let reparseMessage = '';
	let reparseError = '';

	// ── Queries ──────────────────────────────────────────────────────

	$: statsQuery = useLatStatsQuery();
	$: lawsQuery = useLatLawsQuery(searchDebounced || undefined, typeFilter || undefined);
	$: rowsQuery = selectedLaw
		? useLatRowsQuery(selectedLaw.law_name, latLimit, latOffset)
		: null;
	$: annotationsQuery = selectedLaw ? useAnnotationsQuery(selectedLaw.law_name) : null;
	$: reparseMutation = useReparseMutation();

	// ── Derived ──────────────────────────────────────────────────────

	$: stats = $statsQuery?.data;
	$: laws = $lawsQuery?.data?.laws ?? [];
	$: latRows = $rowsQuery?.data?.rows ?? [];
	$: totalLatCount = $rowsQuery?.data?.total_count ?? 0;
	$: hasMoreLat = $rowsQuery?.data?.has_more ?? false;
	$: annotations = $annotationsQuery?.data?.annotations ?? [];

	// ── Search debounce ─────────────────────────────────────────────

	function onSearchInput() {
		if (debounceTimer) clearTimeout(debounceTimer);
		debounceTimer = setTimeout(() => {
			searchDebounced = searchText;
		}, 300);
	}

	// ── Law selection ───────────────────────────────────────────────

	function selectLaw(law: LawSummary) {
		selectedLaw = law;
		activeTab = 'structure';
		latOffset = 0;
		expandedRows = new Set();
		reparseMessage = '';
		reparseError = '';
	}

	function deselectLaw() {
		selectedLaw = null;
		expandedRows = new Set();
		reparseMessage = '';
		reparseError = '';
	}

	// ── Pagination ──────────────────────────────────────────────────

	function loadMore() {
		latOffset += latLimit;
	}

	function resetPagination() {
		latOffset = 0;
	}

	// ── Row expansion ───────────────────────────────────────────────

	function toggleRow(sectionId: string) {
		if (expandedRows.has(sectionId)) {
			expandedRows.delete(sectionId);
		} else {
			expandedRows.add(sectionId);
		}
		expandedRows = expandedRows; // trigger reactivity
	}

	// ── Re-parse ────────────────────────────────────────────────────

	async function handleReparse() {
		if (!selectedLaw) return;
		reparseMessage = '';
		reparseError = '';

		$reparseMutation.mutate(selectedLaw.law_name, {
			onSuccess: (data) => {
				reparseMessage = `Re-parsed: ${data.lat.inserted} LAT rows, ${data.annotations.inserted} annotations (${data.duration_ms}ms)`;
				// Reset pagination to see fresh data
				latOffset = 0;
			},
			onError: (error) => {
				reparseError = error.message || 'Re-parse failed';
			}
		});
	}

	// ── Formatting helpers ──────────────────────────────────────────

	const sectionTypeColors: Record<string, string> = {
		title: 'bg-purple-100 text-purple-700',
		part: 'bg-blue-100 text-blue-700',
		chapter: 'bg-indigo-100 text-indigo-700',
		heading: 'bg-cyan-100 text-cyan-700',
		section: 'bg-green-100 text-green-700',
		article: 'bg-green-100 text-green-700',
		regulation: 'bg-green-100 text-green-700',
		rule: 'bg-green-100 text-green-700',
		paragraph: 'bg-gray-100 text-gray-600',
		sub_paragraph: 'bg-gray-100 text-gray-500',
		schedule: 'bg-amber-100 text-amber-700',
		schedule_paragraph: 'bg-amber-100 text-amber-600'
	};

	const codeTypeColors: Record<string, string> = {
		amendment: 'bg-red-100 text-red-700',
		modification: 'bg-orange-100 text-orange-700',
		commencement: 'bg-blue-100 text-blue-700',
		extent_editorial: 'bg-gray-100 text-gray-600'
	};

	function sectionTypeClass(type: string): string {
		return sectionTypeColors[type] || 'bg-gray-100 text-gray-600';
	}

	function codeTypeClass(type: string): string {
		return codeTypeColors[type] || 'bg-gray-100 text-gray-600';
	}

	function truncateText(text: string, maxLen = 120): string {
		if (text.length <= maxLen) return text;
		return text.slice(0, maxLen) + '…';
	}

	function formatCitation(row: LatRow): string {
		if (row.provision) {
			const prefix = row.section_type === 'article' ? 'art.' : 's.';
			let cite = `${prefix}${row.provision}`;
			if (row.paragraph) cite += `(${row.paragraph})`;
			if (row.sub_paragraph) cite += `(${row.sub_paragraph})`;
			return cite;
		}
		if (row.schedule) return `Sch.${row.schedule}`;
		if (row.part) return `Pt.${row.part}`;
		if (row.chapter) return `Ch.${row.chapter}`;
		return '';
	}

	function totalAnnotationCount(row: LatRow): number {
		return (
			(row.amendment_count ?? 0) +
			(row.modification_count ?? 0) +
			(row.commencement_count ?? 0) +
			(row.extent_count ?? 0) +
			(row.editorial_count ?? 0)
		);
	}

	function formatNumber(n: number): string {
		return n.toLocaleString();
	}
</script>

<svelte:head>
	<title>LAT Admin — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<h1 class="text-2xl font-bold text-gray-900">Legal Articles Table</h1>
		{#if selectedLaw}
			<button
				on:click={deselectLaw}
				class="text-sm text-gray-500 hover:text-gray-700"
			>
				&larr; Back to law list
			</button>
		{/if}
	</div>

	<!-- Stats Bar -->
	{#if stats}
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">LAT Rows</div>
				<div class="text-2xl font-bold text-gray-900">{formatNumber(stats.total_lat_rows)}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Laws with LAT</div>
				<div class="text-2xl font-bold text-gray-900">{formatNumber(stats.laws_with_lat)}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Annotations</div>
				<div class="text-2xl font-bold text-gray-900">{formatNumber(stats.total_annotations)}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Laws with Annotations</div>
				<div class="text-2xl font-bold text-gray-900">
					{formatNumber(stats.laws_with_annotations)}
				</div>
			</div>
		</div>
	{/if}

	{#if !selectedLaw}
		<!-- ── Law Selector ──────────────────────────────────────────── -->

		<!-- Search & Filter -->
		<div class="flex gap-3">
			<input
				type="text"
				bind:value={searchText}
				on:input={onSearchInput}
				placeholder="Search laws by title or name..."
				class="flex-1 px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
			/>
			<select
				bind:value={typeFilter}
				class="px-3 py-2 text-sm border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
			>
				<option value="">All Types</option>
				<option value="ukpga">Acts (ukpga)</option>
				<option value="uksi">Statutory Instruments (uksi)</option>
				<option value="asp">Acts of Scottish Parliament (asp)</option>
				<option value="ssi">Scottish Statutory Instruments (ssi)</option>
				<option value="wsi">Welsh Statutory Instruments (wsi)</option>
				<option value="nia">Northern Ireland Acts (nia)</option>
				<option value="nisr">NI Statutory Rules (nisr)</option>
			</select>
		</div>

		<!-- Laws Table -->
		{#if $lawsQuery?.isLoading}
			<div class="text-center py-8 text-gray-500">Loading laws...</div>
		{:else if laws.length === 0}
			<div class="text-center py-8 text-gray-500">
				{searchDebounced || typeFilter ? 'No laws match your search.' : 'No LAT data found.'}
			</div>
		{:else}
			<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
				<div class="px-4 py-2 bg-gray-50 border-b border-gray-200 text-xs text-gray-500">
					{laws.length} laws
				</div>
				<div class="overflow-x-auto max-h-96 overflow-y-auto">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50 sticky top-0">
							<tr>
								<th
									class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Law Name
								</th>
								<th
									class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Title
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Year
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Type
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									LAT
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Ann.
								</th>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each laws as law (law.law_name)}
								<tr
									class="hover:bg-blue-50 cursor-pointer transition-colors"
									on:click={() => selectLaw(law)}
								>
									<td class="px-4 py-2 text-sm font-mono text-gray-700 whitespace-nowrap">
										{law.law_name}
									</td>
									<td class="px-4 py-2 text-sm text-gray-900 max-w-md truncate">
										{law.title_en}
									</td>
									<td class="px-4 py-2 text-sm text-gray-600 text-right">{law.year}</td>
									<td class="px-4 py-2 text-sm text-right">
										<span class="px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600">
											{law.type_code}
										</span>
									</td>
									<td class="px-4 py-2 text-sm text-gray-600 text-right font-mono">
										{law.lat_count}
									</td>
									<td class="px-4 py-2 text-sm text-right font-mono">
										{#if law.annotation_count > 0}
											<span class="text-red-600">{law.annotation_count}</span>
										{:else}
											<span class="text-gray-400">0</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			</div>
		{/if}
	{:else}
		<!-- ── Selected Law Detail ───────────────────────────────────── -->

		<div class="bg-white rounded-lg border border-gray-200 p-4">
			<div class="flex items-center justify-between">
				<div>
					<h2 class="text-lg font-semibold text-gray-900">{selectedLaw.title_en}</h2>
					<p class="text-sm text-gray-500 font-mono">{selectedLaw.law_name}</p>
				</div>
				<div class="flex items-center gap-3">
					<span class="text-sm text-gray-500">
						{selectedLaw.lat_count} rows &middot; {selectedLaw.annotation_count} annotations
					</span>
					<button
						on:click={handleReparse}
						disabled={$reparseMutation?.isPending}
						class="px-3 py-1.5 text-sm font-medium rounded-md transition-colors
							{$reparseMutation?.isPending
							? 'bg-gray-100 text-gray-400 cursor-not-allowed'
							: 'bg-blue-600 text-white hover:bg-blue-700'}"
					>
						{#if $reparseMutation?.isPending}
							<span class="inline-flex items-center gap-1">
								<svg
									class="animate-spin h-3.5 w-3.5"
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
									/>
									<path
										class="opacity-75"
										fill="currentColor"
										d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z"
									/>
								</svg>
								Re-parsing...
							</span>
						{:else}
							Re-parse LAT
						{/if}
					</button>
				</div>
			</div>

			<!-- Reparse feedback -->
			{#if reparseMessage}
				<div class="mt-2 px-3 py-2 text-sm bg-green-50 text-green-700 rounded-md">
					{reparseMessage}
				</div>
			{/if}
			{#if reparseError}
				<div class="mt-2 px-3 py-2 text-sm bg-red-50 text-red-700 rounded-md">
					{reparseError}
				</div>
			{/if}
		</div>

		<!-- Tabs -->
		<div class="flex gap-1 border-b border-gray-200">
			<button
				on:click={() => (activeTab = 'structure')}
				class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
					{activeTab === 'structure'
					? 'border-blue-500 text-blue-600'
					: 'border-transparent text-gray-500 hover:text-gray-700'}"
			>
				Structure ({totalLatCount})
			</button>
			<button
				on:click={() => (activeTab = 'annotations')}
				class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
					{activeTab === 'annotations'
					? 'border-blue-500 text-blue-600'
					: 'border-transparent text-gray-500 hover:text-gray-700'}"
			>
				Annotations ({selectedLaw.annotation_count})
			</button>
		</div>

		<!-- Tab Content -->
		{#if activeTab === 'structure'}
			<!-- Structure Tab -->
			{#if $rowsQuery?.isLoading}
				<div class="text-center py-8 text-gray-500">Loading structure...</div>
			{:else if latRows.length === 0}
				<div class="text-center py-8 text-gray-500">No LAT rows found for this law.</div>
			{:else}
				<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th
										class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24"
									>
										Type
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase w-24"
									>
										Citation
									</th>
									<th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
										Text
									</th>
									<th
										class="px-3 py-2 text-right text-xs font-medium text-gray-500 uppercase w-16"
									>
										Ann.
									</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-100">
								{#each latRows as row (row.section_id)}
									{@const isExpanded = expandedRows.has(row.section_id)}
									{@const annCount = totalAnnotationCount(row)}
									<tr
										class="hover:bg-gray-50 cursor-pointer transition-colors"
										on:click={() => toggleRow(row.section_id)}
									>
										<td class="px-3 py-1.5" style="padding-left: {12 + row.depth * 16}px">
											<span
												class="inline-block px-1.5 py-0.5 rounded text-xs font-medium {sectionTypeClass(
													row.section_type
												)}"
											>
												{row.section_type}
											</span>
										</td>
										<td class="px-3 py-1.5 text-sm font-mono text-gray-600 whitespace-nowrap">
											{formatCitation(row)}
										</td>
										<td class="px-3 py-1.5 text-sm text-gray-800">
											{#if isExpanded}
												<div class="whitespace-pre-wrap">{row.text}</div>
												{#if row.extent_code}
													<span
														class="inline-block mt-1 px-1.5 py-0.5 rounded text-xs bg-yellow-50 text-yellow-700"
													>
														Extent: {row.extent_code}
													</span>
												{/if}
											{:else}
												{truncateText(row.text)}
											{/if}
										</td>
										<td class="px-3 py-1.5 text-sm text-right">
											{#if annCount > 0}
												<span
													class="inline-block px-1.5 py-0.5 rounded text-xs bg-red-100 text-red-700"
												>
													{annCount}
												</span>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>

					<!-- Pagination -->
					{#if hasMoreLat}
						<div class="px-4 py-3 border-t border-gray-200 bg-gray-50 text-center">
							<button
								on:click={loadMore}
								class="px-4 py-1.5 text-sm font-medium text-blue-600 hover:text-blue-800"
							>
								Load more rows ({latRows.length} of {totalLatCount} shown)
							</button>
						</div>
					{:else if totalLatCount > 0}
						<div class="px-4 py-2 border-t border-gray-200 bg-gray-50 text-center text-xs text-gray-500">
							Showing all {totalLatCount} rows
						</div>
					{/if}
				</div>
			{/if}
		{:else}
			<!-- Annotations Tab -->
			{#if $annotationsQuery?.isLoading}
				<div class="text-center py-8 text-gray-500">Loading annotations...</div>
			{:else if annotations.length === 0}
				<div class="text-center py-8 text-gray-500">No annotations for this law.</div>
			{:else}
				<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th
										class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase w-20"
									>
										Code
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase w-28"
									>
										Type
									</th>
									<th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
										Text
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase w-32"
									>
										Source
									</th>
									<th class="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase">
										Affected Sections
									</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-100">
								{#each annotations as ann (ann.id)}
									<tr class="hover:bg-gray-50">
										<td class="px-3 py-2 text-sm font-mono text-gray-700">{ann.code}</td>
										<td class="px-3 py-2">
											<span
												class="inline-block px-1.5 py-0.5 rounded text-xs font-medium {codeTypeClass(
													ann.code_type
												)}"
											>
												{ann.code_type}
											</span>
										</td>
										<td class="px-3 py-2 text-sm text-gray-800 max-w-lg">
											{ann.text}
										</td>
										<td class="px-3 py-2 text-xs text-gray-500">{ann.source}</td>
										<td class="px-3 py-2">
											{#if ann.affected_sections && ann.affected_sections.length > 0}
												<div class="flex flex-wrap gap-1">
													{#each ann.affected_sections.slice(0, 5) as sec}
														<span
															class="inline-block px-1.5 py-0.5 rounded text-xs bg-blue-50 text-blue-600 font-mono"
														>
															{sec.split(':')[1] || sec}
														</span>
													{/each}
													{#if ann.affected_sections.length > 5}
														<span class="text-xs text-gray-400">
															+{ann.affected_sections.length - 5} more
														</span>
													{/if}
												</div>
											{:else}
												<span class="text-xs text-gray-400">—</span>
											{/if}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}
		{/if}
	{/if}
</div>
