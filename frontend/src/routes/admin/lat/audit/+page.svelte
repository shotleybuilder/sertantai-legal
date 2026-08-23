<script lang="ts">
	import { useAuditSummaryQuery, useAuditLawQuery, auditKeys } from '$lib/query/audit';
	import { useReparseMutation } from '$lib/query/lat';
	import { useQueryClient } from '@tanstack/svelte-query';
	import type { AuditLawResult, AuditWarning } from '$lib/api/audit';
	import { reparseLat } from '$lib/api/lat';

	let familyFilter = $state('');
	let statusFilter: 'all' | 'clean' | 'warning' | 'error' = $state('all');
	let selectedLaw: string | null = $state(null);
	let sortColumn: keyof AuditLawResult = $state('blob_count');
	let sortDirection: 'asc' | 'desc' = $state('desc');

	// Reparse state
	const queryClient = useQueryClient();
	let reparseMutation = useReparseMutation();
	let reparseMessage = $state('');
	let reparseError = $state('');

	// Bulk reparse state
	let bulkReparsing = $state(false);
	let bulkProgress = $state(0);
	let bulkTotal = $state(0);
	let bulkCurrentLaw = $state('');
	let bulkResults: { law: string; status: 'ok' | 'error'; message: string }[] = $state([]);

	let summaryQuery = useAuditSummaryQuery();
	let data = $derived(summaryQuery?.data);
	let corpus = $derived(data?.corpus);
	let counts = $derived(data?.counts);

	// Derive unique families from loaded data for picker
	let allFamilies = $derived(
		[...new Set((data?.laws ?? []).map((l) => l.family).filter(Boolean))].sort() as string[]
	);

	let filteredLaws = $derived(
		(data?.laws ?? [])
			.filter((l) => {
				if (statusFilter !== 'all' && l.status !== statusFilter) return false;
				if (familyFilter && l.family !== familyFilter) return false;
				return true;
			})
			.sort((a, b) => {
				const av = a[sortColumn] ?? 0;
				const bv = b[sortColumn] ?? 0;
				if (av < bv) return sortDirection === 'asc' ? -1 : 1;
				if (av > bv) return sortDirection === 'asc' ? 1 : -1;
				return 0;
			})
	);

	let lawDetailQuery = $derived(useAuditLawQuery(selectedLaw));
	let lawDetail = $derived(lawDetailQuery?.data ?? null);

	// Single-law reparse
	function handleReparse(lawName: string) {
		reparseMessage = '';
		reparseError = '';
		reparseMutation.mutate(lawName, {
			onSuccess: (result) => {
				reparseMessage = `Re-parsed ${lawName}: ${result.lat.inserted} rows, ${result.annotations.inserted} annotations (${result.duration_ms}ms)`;
				// Refresh audit data
				queryClient.invalidateQueries({ queryKey: auditKeys.all });
			},
			onError: (err) => {
				reparseError = `Failed to reparse ${lawName}: ${err.message}`;
			}
		});
	}

	// Bulk reparse all laws in current filtered view
	async function handleBulkReparse() {
		const errorLaws = filteredLaws;
		if (errorLaws.length === 0) return;

		bulkReparsing = true;
		bulkProgress = 0;
		bulkTotal = errorLaws.length;
		bulkResults = [];

		for (const law of errorLaws) {
			bulkCurrentLaw = law.law_name;
			try {
				const result = await reparseLat(law.law_name);
				bulkResults = [
					...bulkResults,
					{
						law: law.law_name,
						status: 'ok',
						message: `${result.lat.inserted} rows (${result.duration_ms}ms)`
					}
				];
			} catch (err) {
				bulkResults = [
					...bulkResults,
					{
						law: law.law_name,
						status: 'error',
						message: err instanceof Error ? err.message : 'Unknown error'
					}
				];
			}
			bulkProgress++;
		}

		bulkCurrentLaw = '';
		bulkReparsing = false;
		// Refresh audit data
		queryClient.invalidateQueries({ queryKey: auditKeys.all });
	}

	function toggleSort(col: keyof AuditLawResult) {
		if (sortColumn === col) {
			sortDirection = sortDirection === 'asc' ? 'desc' : 'asc';
		} else {
			sortColumn = col;
			sortDirection = 'desc';
		}
	}

	function formatBytes(bytes: number): string {
		if (bytes < 1024) return `${bytes} B`;
		if (bytes < 1048576) return `${(bytes / 1024).toFixed(1)} KB`;
		return `${(bytes / 1048576).toFixed(1)} MB`;
	}

	function statusBadge(status: string): string {
		switch (status) {
			case 'clean':
				return 'bg-green-100 text-green-700';
			case 'warning':
				return 'bg-yellow-100 text-yellow-700';
			case 'error':
				return 'bg-red-100 text-red-700';
			default:
				return 'bg-gray-100 text-gray-600';
		}
	}

	function severityBadge(severity: string): string {
		return severity === 'error' ? 'bg-red-100 text-red-700' : 'bg-yellow-100 text-yellow-700';
	}

	function sortIcon(col: keyof AuditLawResult): string {
		if (sortColumn !== col) return '';
		return sortDirection === 'asc' ? ' ^' : ' v';
	}
</script>

<svelte:head>
	<title>LAT Audit — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">LAT Parse Audit</h1>
			<p class="text-sm text-gray-500 mt-1">
				Diagnostic checks for structural blobs, empty sections, and parse anomalies
			</p>
		</div>
	</div>

	{#if summaryQuery.isLoading}
		<div class="text-center py-12 text-gray-500">Loading audit data...</div>
	{:else if summaryQuery.error}
		<div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
			Error: {summaryQuery.error.message}
		</div>
	{:else if corpus && counts}
		<!-- Corpus Summary Cards -->
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">{corpus.total_laws.toLocaleString()}</div>
				<div class="text-sm text-gray-500">Laws audited</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">
					{corpus.total_rows.toLocaleString()}
				</div>
				<div class="text-sm text-gray-500">Total LAT rows</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">{corpus.structural_text_pct}%</div>
				<div class="text-sm text-gray-500">Structural text</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">{formatBytes(corpus.total_text_bytes)}</div>
				<div class="text-sm text-gray-500">Total text</div>
			</div>
		</div>

		<!-- Status Summary -->
		<div class="flex gap-3 flex-wrap">
			<button
				class="px-3 py-1.5 rounded-full text-sm font-medium transition-colors
					{statusFilter === 'all' ? 'bg-gray-800 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}"
				onclick={() => (statusFilter = 'all')}
			>
				All {counts.total}
			</button>
			<button
				class="px-3 py-1.5 rounded-full text-sm font-medium transition-colors
					{statusFilter === 'clean'
					? 'bg-green-600 text-white'
					: 'bg-green-100 text-green-700 hover:bg-green-200'}"
				onclick={() => (statusFilter = 'clean')}
			>
				Clean {counts.clean}
			</button>
			<button
				class="px-3 py-1.5 rounded-full text-sm font-medium transition-colors
					{statusFilter === 'warning'
					? 'bg-yellow-500 text-white'
					: 'bg-yellow-100 text-yellow-700 hover:bg-yellow-200'}"
				onclick={() => (statusFilter = 'warning')}
			>
				Warnings {counts.warning}
			</button>
			<button
				class="px-3 py-1.5 rounded-full text-sm font-medium transition-colors
					{statusFilter === 'error' ? 'bg-red-600 text-white' : 'bg-red-100 text-red-700 hover:bg-red-200'}"
				onclick={() => (statusFilter = 'error')}
			>
				Errors {counts.error}
			</button>
			{#if corpus.blob_count > 0}
				<span class="px-3 py-1.5 rounded-full text-sm bg-red-50 text-red-600 border border-red-200">
					{corpus.blob_count} structural blobs &gt;1KB
				</span>
			{/if}
			{#if corpus.empty_section_count > 0}
				<span
					class="px-3 py-1.5 rounded-full text-sm bg-yellow-50 text-yellow-600 border border-yellow-200"
				>
					{corpus.empty_section_count} empty sections
				</span>
			{/if}
		</div>

		<!-- Family Filter + Bulk Actions -->
		<div class="flex items-center gap-3 flex-wrap">
			<select
				bind:value={familyFilter}
				class="px-3 py-1.5 border rounded-lg text-sm w-72 focus:outline-none focus:ring-2 focus:ring-indigo-500 bg-white"
			>
				<option value="">All families</option>
				{#each allFamilies as fam}
					<option value={fam}>{fam}</option>
				{/each}
			</select>
			<span class="text-sm text-gray-500">{filteredLaws.length} laws shown</span>
			{#if filteredLaws.length > 0}
				<button
					class="ml-auto px-3 py-1.5 text-sm font-medium text-white bg-indigo-600 rounded-lg hover:bg-indigo-700 disabled:opacity-50 transition-colors"
					disabled={bulkReparsing}
					onclick={handleBulkReparse}
				>
					{#if bulkReparsing}
						Re-parsing {bulkProgress}/{bulkTotal}...
					{:else}
						Re-parse shown ({filteredLaws.length})
					{/if}
				</button>
			{/if}
		</div>

		<!-- Law Detail Panel (above table so it's always visible) -->
		{#if selectedLaw}
			<div class="bg-white rounded-lg border p-5 space-y-4 shadow-lg">
				<div class="flex items-center justify-between">
					<h2 class="text-lg font-semibold text-gray-900">
						Diagnostics: {selectedLaw}
					</h2>
					<div class="flex items-center gap-3">
						<a
							href="/admin/lat?law={encodeURIComponent(selectedLaw)}"
							class="text-sm text-indigo-600 hover:text-indigo-800"
						>
							View in LAT browser
						</a>
						<button
							class="px-3 py-1 text-sm font-medium text-white bg-indigo-600 rounded hover:bg-indigo-700 disabled:opacity-50"
							disabled={reparseMutation.isPending}
							onclick={() => handleReparse(selectedLaw ?? '')}
						>
							{#if reparseMutation.isPending}
								Re-parsing...
							{:else}
								Re-parse LAT
							{/if}
						</button>
						<button
							class="text-sm text-gray-400 hover:text-gray-600"
							onclick={() => (selectedLaw = null)}
						>
							Close
						</button>
					</div>
				</div>

				{#if lawDetailQuery?.isLoading}
					<div class="text-sm text-gray-500">Running diagnostics...</div>
				{:else if lawDetailQuery?.error}
					<div class="text-sm text-red-600">
						Error: {lawDetailQuery.error.message}
					</div>
				{:else if lawDetail}
					<div class="grid grid-cols-3 md:grid-cols-6 gap-3 text-sm">
						<div class="bg-gray-50 rounded p-2">
							<div class="font-semibold">{lawDetail.summary.total_rows}</div>
							<div class="text-xs text-gray-500">Total</div>
						</div>
						<div class="bg-gray-50 rounded p-2">
							<div class="font-semibold">{lawDetail.summary.structural_rows}</div>
							<div class="text-xs text-gray-500">Structural</div>
						</div>
						<div class="bg-gray-50 rounded p-2">
							<div class="font-semibold">{lawDetail.summary.section_rows}</div>
							<div class="text-xs text-gray-500">Sections</div>
						</div>
						<div class="bg-gray-50 rounded p-2">
							<div class="font-semibold">{lawDetail.summary.structural_text_pct}%</div>
							<div class="text-xs text-gray-500">Struct text</div>
						</div>
						<div class="bg-gray-50 rounded p-2">
							<div class="font-semibold">
								{formatBytes(lawDetail.summary.max_row_text_bytes)}
							</div>
							<div class="text-xs text-gray-500">Largest row</div>
						</div>
						<div class="bg-gray-50 rounded p-2">
							<div class="font-semibold">{formatBytes(lawDetail.summary.total_text_bytes)}</div>
							<div class="text-xs text-gray-500">Total text</div>
						</div>
					</div>

					<div class="flex flex-wrap gap-2">
						{#each Object.entries(lawDetail.summary.type_counts) as [type, count]}
							<span class="px-2 py-0.5 text-xs rounded bg-indigo-50 text-indigo-700">
								{type}: {count}
							</span>
						{/each}
					</div>

					{#if lawDetail.warnings.length > 0}
						<div class="space-y-2">
							<h3 class="text-sm font-medium text-gray-700">
								{lawDetail.warnings.length} issue{lawDetail.warnings.length !== 1 ? 's' : ''}
							</h3>
							{#each lawDetail.warnings as warning}
								<div
									class="flex items-start gap-2 text-sm border rounded p-3 {warning.severity ===
									'error'
										? 'border-red-200 bg-red-50'
										: 'border-yellow-200 bg-yellow-50'}"
								>
									<span
										class="inline-block px-1.5 py-0.5 text-xs font-medium rounded {severityBadge(
											warning.severity
										)}"
									>
										{warning.check}
									</span>
									<span class="text-gray-700">{warning.message}</span>
								</div>
							{/each}
						</div>
					{:else}
						<div class="text-sm text-green-600">No issues found</div>
					{/if}
				{/if}
			</div>
		{/if}

		<!-- Per-Law Results Table -->
		<div class="bg-white rounded-lg border overflow-hidden">
			<div class="overflow-x-auto">
				<table class="w-full text-sm">
					<thead class="bg-gray-50 border-b">
						<tr>
							<th class="text-left px-3 py-2 font-medium text-gray-600">Status</th>
							<th
								class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
								onclick={() => toggleSort('law_name')}
							>
								Law{sortIcon('law_name')}
							</th>
							<th class="text-left px-3 py-2 font-medium text-gray-600">Family</th>
							<th
								class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
								onclick={() => toggleSort('total_rows')}
							>
								Rows{sortIcon('total_rows')}
							</th>
							<th
								class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
								onclick={() => toggleSort('structural_text_pct')}
							>
								Struct %{sortIcon('structural_text_pct')}
							</th>
							<th
								class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
								onclick={() => toggleSort('blob_count')}
							>
								Blobs{sortIcon('blob_count')}
							</th>
							<th
								class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
								onclick={() => toggleSort('empty_section_count')}
							>
								Empty{sortIcon('empty_section_count')}
							</th>
							<th
								class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
								onclick={() => toggleSort('max_row_bytes')}
							>
								Max Row{sortIcon('max_row_bytes')}
							</th>
						</tr>
					</thead>
					<tbody class="divide-y divide-gray-100">
						{#each filteredLaws as law (law.law_name)}
							<tr
								class="hover:bg-gray-50 cursor-pointer transition-colors"
								class:bg-blue-50={selectedLaw === law.law_name}
								onclick={() => (selectedLaw = selectedLaw === law.law_name ? null : law.law_name)}
							>
								<td class="px-3 py-2">
									<span
										class="inline-block px-2 py-0.5 text-xs font-medium rounded {statusBadge(
											law.status
										)}"
									>
										{law.status}
									</span>
								</td>
								<td class="px-3 py-2">
									<div class="font-medium text-gray-900">{law.title || law.law_name}</div>
									<div class="text-xs text-gray-400 font-mono">{law.law_name}</div>
								</td>
								<td class="px-3 py-2 text-gray-600 max-w-48 truncate">{law.family || '-'}</td>
								<td class="px-3 py-2 text-right text-gray-700 tabular-nums"
									>{law.total_rows.toLocaleString()}</td
								>
								<td class="px-3 py-2 text-right tabular-nums">
									<span
										class={law.structural_text_pct > 10
											? 'text-orange-600 font-medium'
											: 'text-gray-500'}
									>
										{law.structural_text_pct}%
									</span>
								</td>
								<td class="px-3 py-2 text-right tabular-nums">
									{#if law.blob_count > 0}
										<span class="text-red-600 font-medium">{law.blob_count}</span>
									{:else}
										<span class="text-gray-300">0</span>
									{/if}
								</td>
								<td class="px-3 py-2 text-right tabular-nums">
									{#if law.empty_section_count > 0}
										<span class="text-yellow-600">{law.empty_section_count}</span>
									{:else}
										<span class="text-gray-300">0</span>
									{/if}
								</td>
								<td class="px-3 py-2 text-right text-gray-500 tabular-nums"
									>{formatBytes(law.max_row_bytes)}</td
								>
							</tr>
						{/each}
						{#if filteredLaws.length === 0}
							<tr>
								<td colspan="8" class="px-3 py-8 text-center text-gray-400">
									No laws match the current filters
								</td>
							</tr>
						{/if}
					</tbody>
				</table>
			</div>
		</div>

		<!-- Bulk Reparse Progress -->
		{#if bulkReparsing || bulkResults.length > 0}
			<div class="bg-white rounded-lg border p-4 space-y-3">
				<div class="flex items-center justify-between">
					<h3 class="text-sm font-semibold text-gray-900">
						{#if bulkReparsing}
							Re-parsing {bulkProgress + 1} of {bulkTotal}: {bulkCurrentLaw}
						{:else}
							Bulk reparse complete: {bulkResults.filter((r) => r.status === 'ok')
								.length}/{bulkResults.length} succeeded
						{/if}
					</h3>
					{#if !bulkReparsing}
						<button
							class="text-xs text-gray-400 hover:text-gray-600"
							onclick={() => (bulkResults = [])}
						>
							Dismiss
						</button>
					{/if}
				</div>
				{#if bulkReparsing}
					<div class="w-full bg-gray-200 rounded-full h-2">
						<div
							class="bg-indigo-600 h-2 rounded-full transition-all"
							style="width: {((bulkProgress / bulkTotal) * 100).toFixed(0)}%"
						/>
					</div>
				{/if}
				{#if bulkResults.some((r) => r.status === 'error')}
					<div class="text-xs space-y-1 max-h-32 overflow-y-auto">
						{#each bulkResults.filter((r) => r.status === 'error') as r}
							<div class="text-red-600">{r.law}: {r.message}</div>
						{/each}
					</div>
				{/if}
			</div>
		{/if}

		<!-- Reparse feedback -->
		{#if reparseMessage}
			<div class="px-3 py-2 text-sm bg-green-50 text-green-700 rounded-lg border border-green-200">
				{reparseMessage}
			</div>
		{/if}
		{#if reparseError}
			<div class="px-3 py-2 text-sm bg-red-50 text-red-700 rounded-lg border border-red-200">
				{reparseError}
			</div>
		{/if}
	{/if}
</div>
