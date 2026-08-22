<script lang="ts">
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	interface Finding {
		definition_id: string;
		law_name: string;
		term: string;
		category: string;
		citation: string | null;
		target_law: string | null;
		nearest_term: string | null;
		detail: string | null;
	}

	interface TopParent {
		law_name: string;
		count: number;
	}

	interface Summary {
		total: number;
		citation_resolved: number;
		genuinely_unresolved: number;
		actionable: number;
		ceiling: number;
		by_category: Record<string, number>;
		top_parents: TopParent[];
	}

	const CEILING_CATEGORIES = new Set([
		'parent_revoked',
		'parent_not_in_lrt',
		'internal_ref',
		'international_convention'
	]);

	const CATEGORY_LABELS: Record<string, string> = {
		term_not_found: 'Term Not Found',
		no_citation: 'No Citation',
		parent_unparsed: 'Parent Unparsed',
		term_normalisation: 'Term Normalisation',
		citation_ambiguous: 'Citation Ambiguous',
		parent_not_in_lrt: 'Parent Not in LRT',
		parent_revoked: 'Parent Revoked',
		internal_ref: 'Internal Reference',
		international_convention: 'International Convention'
	};

	let summary: Summary | null = null;
	let findings: Finding[] = [];
	let loading = false;
	let error = '';
	let familyFilter = '';
	let selectedCategory = '';

	// Sort categories: actionable first (by count desc), then ceiling (by count desc)
	$: sortedCategories = summary
		? Object.entries(summary.by_category)
				.sort((a, b) => {
					const aIsCeiling = CEILING_CATEGORIES.has(a[0]);
					const bIsCeiling = CEILING_CATEGORIES.has(b[0]);
					if (aIsCeiling !== bIsCeiling) return aIsCeiling ? 1 : -1;
					return b[1] - a[1];
				})
				.map(([cat, count]) => ({ cat, count, isCeiling: CEILING_CATEGORIES.has(cat) }))
		: [];

	$: filteredFindings = selectedCategory
		? findings.filter((f) => f.category === selectedCategory)
		: findings;

	$: maxCategoryCount = sortedCategories.length > 0 ? sortedCategories[0].count : 1;

	async function runDiagnostic() {
		loading = true;
		error = '';
		summary = null;
		findings = [];
		selectedCategory = '';
		try {
			const params = familyFilter ? `?family=${encodeURIComponent(familyFilter)}` : '';
			const res = await authFetch(`${API_URL}/api/definitions/admin/diagnostic${params}`);
			if (!res.ok) throw new Error(`Diagnostic API returned ${res.status}`);
			const data = await res.json();
			summary = data.summary;
			findings = data.findings;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Diagnostic failed';
		} finally {
			loading = false;
		}
	}

	function categoryBarWidth(count: number): string {
		return `${Math.max(2, (count / maxCategoryCount) * 100)}%`;
	}

	function browseUrl(lawName: string): string {
		return `/admin/definitions/browse?law=${encodeURIComponent(lawName)}`;
	}
</script>

<svelte:head>
	<title>Diagnostic Explorer — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<h1 class="text-2xl font-bold text-gray-900">Diagnostic Explorer</h1>
		<div class="flex items-center gap-2">
			<input
				type="text"
				bind:value={familyFilter}
				placeholder="Family filter (optional)"
				class="w-56 rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
			/>
			<button
				on:click={runDiagnostic}
				disabled={loading}
				class="rounded-md bg-blue-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
			>
				{loading ? 'Running...' : 'Run Diagnostic'}
			</button>
		</div>
	</div>

	{#if error}
		<div class="rounded-md bg-red-50 px-4 py-3 text-red-700">{error}</div>
	{/if}

	{#if loading}
		<div class="py-12 text-center text-gray-500">
			Running diagnostic — this may take a few seconds...
		</div>
	{:else if summary}
		<!-- Summary cards -->
		<div class="grid grid-cols-2 gap-4 md:grid-cols-5">
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Total Unlinked</div>
				<div class="text-2xl font-bold text-gray-900">{summary.total.toLocaleString()}</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Actionable</div>
				<div class="text-2xl font-bold text-red-700">{summary.actionable.toLocaleString()}</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Ceiling</div>
				<div class="text-2xl font-bold text-gray-400">{summary.ceiling.toLocaleString()}</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Citation Resolved</div>
				<div class="text-2xl font-bold text-amber-600">
					{summary.citation_resolved.toLocaleString()}
				</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Genuinely Unresolved</div>
				<div class="text-2xl font-bold text-red-600">
					{summary.genuinely_unresolved.toLocaleString()}
				</div>
			</div>
		</div>

		<div class="flex gap-6">
			<!-- Category breakdown -->
			<div class="w-80 flex-shrink-0 space-y-1">
				<h2 class="text-sm font-semibold text-gray-700">Categories</h2>
				{#each sortedCategories as { cat, count, isCeiling }}
					<button
						class="flex w-full items-center gap-2 rounded px-2 py-1 text-left text-sm hover:bg-gray-100
							{selectedCategory === cat ? 'bg-blue-50 ring-1 ring-blue-300' : ''}
							{isCeiling ? 'text-gray-400' : 'text-gray-700'}"
						on:click={() => (selectedCategory = selectedCategory === cat ? '' : cat)}
					>
						<div class="w-28 flex-shrink-0 truncate text-xs">
							{CATEGORY_LABELS[cat] || cat}
						</div>
						<div class="flex-1">
							<div
								class="h-3 rounded {isCeiling ? 'bg-gray-200' : 'bg-blue-400'}"
								style="width: {categoryBarWidth(count)}"
							/>
						</div>
						<div class="w-8 text-right text-xs font-medium">{count}</div>
					</button>
				{/each}
			</div>

			<!-- Findings table + top parents -->
			<div class="min-w-0 flex-1 space-y-4">
				<!-- Findings -->
				<div class="overflow-hidden rounded-lg border border-gray-200 bg-white">
					<div class="border-b border-gray-200 bg-gray-50 px-4 py-2">
						<span class="text-sm font-medium text-gray-700">
							{selectedCategory
								? CATEGORY_LABELS[selectedCategory] || selectedCategory
								: 'All Findings'}
						</span>
						<span class="ml-2 text-xs text-gray-400">
							{filteredFindings.length} findings
						</span>
					</div>
					<div class="max-h-96 overflow-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="sticky top-0 bg-gray-50">
								<tr>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Law
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Term
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Category
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Citation
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Detail
									</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-200">
								{#each filteredFindings.slice(0, 200) as f (f.definition_id)}
									<tr class="hover:bg-gray-50">
										<td class="whitespace-nowrap px-3 py-1.5 text-xs">
											<a href={browseUrl(f.law_name)} class="text-blue-600 hover:text-blue-800">
												{f.law_name}
											</a>
										</td>
										<td class="whitespace-nowrap px-3 py-1.5 text-sm font-medium text-gray-900">
											{f.term}
										</td>
										<td class="whitespace-nowrap px-3 py-1.5">
											<span
												class="rounded px-1.5 py-0.5 text-xs {CEILING_CATEGORIES.has(f.category)
													? 'bg-gray-100 text-gray-500'
													: 'bg-red-50 text-red-700'}"
											>
												{f.category}
											</span>
										</td>
										<td
											class="max-w-xs truncate px-3 py-1.5 text-xs text-gray-500"
											title={f.citation || ''}
										>
											{f.citation || ''}
										</td>
										<td
											class="max-w-xs truncate px-3 py-1.5 text-xs text-gray-400"
											title={f.detail || ''}
										>
											{f.detail || ''}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
						{#if filteredFindings.length > 200}
							<div class="px-4 py-2 text-xs text-gray-400">
								Showing first 200 of {filteredFindings.length} findings
							</div>
						{/if}
					</div>
				</div>

				<!-- Top parents -->
				{#if summary.top_parents.length > 0}
					<div class="overflow-hidden rounded-lg border border-gray-200 bg-white">
						<div class="border-b border-gray-200 bg-gray-50 px-4 py-2">
							<span class="text-sm font-medium text-gray-700">Top Unresolved Parent Laws</span>
						</div>
						<div class="max-h-48 overflow-auto">
							<table class="min-w-full divide-y divide-gray-200">
								<tbody class="divide-y divide-gray-200">
									{#each summary.top_parents.slice(0, 20) as parent}
										<tr class="hover:bg-gray-50">
											<td class="px-3 py-1.5 text-xs">
												<a
													href={browseUrl(parent.law_name)}
													class="text-blue-600 hover:text-blue-800"
												>
													{parent.law_name}
												</a>
											</td>
											<td class="px-3 py-1.5 text-right text-xs font-medium text-gray-600">
												{parent.count} refs
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						</div>
					</div>
				{/if}
			</div>
		</div>
	{:else}
		<div class="py-12 text-center text-gray-400">
			Click "Run Diagnostic" to analyse unlinked cross-reference definitions.
			<br />
			<span class="text-xs">Optionally enter a family name to scope the analysis.</span>
		</div>
	{/if}
</div>
