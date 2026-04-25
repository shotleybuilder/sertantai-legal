<script lang="ts">
	import {
		useGraphStatsQuery,
		useFamilyMismatchesQuery,
		useFamilyInferenceQuery
	} from '$lib/query/graph';
	import type { FamilyMismatch } from '$lib/api/graph';

	let selectedLaw: string | null = null;
	let familyFilter = '';
	let confidenceFilter: string = 'all';

	$: statsQuery = useGraphStatsQuery();
	$: mismatchesQuery = useFamilyMismatchesQuery();
	$: inferenceQuery = useFamilyInferenceQuery(selectedLaw);

	$: stats = $statsQuery?.data;
	$: mismatches = $mismatchesQuery?.data?.mismatches ?? [];
	$: inference = $inferenceQuery?.data ?? null;

	$: filteredMismatches = mismatches.filter((m) => {
		if (familyFilter && m.assigned_family !== familyFilter) return false;
		if (confidenceFilter !== 'all' && m.confidence !== confidenceFilter) return false;
		return true;
	});

	$: allFamilies = [
		...new Set(mismatches.map((m) => m.assigned_family).filter(Boolean))
	].sort() as string[];

	function confidenceBadge(c: string): string {
		switch (c) {
			case 'parent_inferred':
				return 'bg-red-100 text-red-700';
			case 'target_consensus':
				return 'bg-orange-100 text-orange-700';
			default:
				return 'bg-gray-100 text-gray-600';
		}
	}
</script>

<svelte:head>
	<title>Family Graph — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<div>
		<h1 class="text-2xl font-bold text-gray-900">Law Relationship Graph</h1>
		<p class="text-sm text-gray-500 mt-1">
			Graph-informed family classification review — detect likely misclassifications
		</p>
	</div>

	{#if $statsQuery.isLoading}
		<div class="text-center py-12 text-gray-500">Loading graph data...</div>
	{:else if stats}
		<!-- Stats Cards -->
		<div class="grid grid-cols-2 md:grid-cols-5 gap-4">
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">{stats.total_edges.toLocaleString()}</div>
				<div class="text-sm text-gray-500">Total edges</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">{stats.laws_with_edges.toLocaleString()}</div>
				<div class="text-sm text-gray-500">Laws with edges</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-gray-900">
					{stats.laws_with_classified_parents?.toLocaleString()}
				</div>
				<div class="text-sm text-gray-500">With classified parents</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-2xl font-bold text-red-600">
					{stats.potential_mismatches?.toLocaleString()}
				</div>
				<div class="text-sm text-gray-500">Potential mismatches</div>
			</div>
			<div class="bg-white rounded-lg border p-4">
				<div class="text-sm space-y-1">
					{#each Object.entries(stats.edge_types) as [type, count]}
						<div class="flex justify-between">
							<span class="text-gray-600">{type}</span>
							<span class="font-mono text-gray-900">{count.toLocaleString()}</span>
						</div>
					{/each}
				</div>
			</div>
		</div>
	{/if}

	{#if $mismatchesQuery.isLoading}
		<div class="text-center py-8 text-gray-500">Loading mismatches...</div>
	{:else if mismatches.length > 0}
		<!-- Filters -->
		<div class="flex items-center gap-3 flex-wrap">
			<select
				bind:value={familyFilter}
				class="px-3 py-1.5 border rounded-lg text-sm w-72 bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
			>
				<option value="">All families</option>
				{#each allFamilies as fam}
					<option value={fam}>{fam}</option>
				{/each}
			</select>
			<select
				bind:value={confidenceFilter}
				class="px-3 py-1.5 border rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
			>
				<option value="all">All confidence</option>
				<option value="parent_inferred">Parent inferred</option>
				<option value="target_consensus">Target consensus</option>
			</select>
			<span class="text-sm text-gray-500">{filteredMismatches.length} mismatches shown</span>
		</div>

		<!-- Detail Panel -->
		{#if selectedLaw && inference}
			<div class="bg-white rounded-lg border p-5 space-y-3 shadow-lg">
				<div class="flex items-center justify-between">
					<h2 class="text-lg font-semibold text-gray-900">{selectedLaw}</h2>
					<div class="flex items-center gap-3">
						<a
							href="/admin/lat?law={encodeURIComponent(selectedLaw)}"
							class="text-sm text-indigo-600 hover:text-indigo-800">View in LAT browser</a
						>
						<button
							class="text-sm text-gray-400 hover:text-gray-600"
							on:click={() => (selectedLaw = null)}>Close</button
						>
					</div>
				</div>
				<div class="grid grid-cols-2 gap-4 text-sm">
					<div>
						<div class="text-gray-500 mb-1">Assigned Family</div>
						<div class="font-medium">{inference.assigned_family || 'None'}</div>
					</div>
					<div>
						<div class="text-gray-500 mb-1">Suggested Family</div>
						<div class="font-medium text-red-700">{inference.suggested_family || 'None'}</div>
					</div>
				</div>
				{#if inference.parent_families.length > 0}
					<div class="text-sm">
						<div class="text-gray-500 mb-1">Parent Act families (enacted_by)</div>
						<div class="flex flex-wrap gap-2">
							{#each inference.parent_families as [fam, count]}
								<span class="px-2 py-0.5 rounded bg-blue-50 text-blue-700 text-xs">
									{fam} ({count})
								</span>
							{/each}
						</div>
					</div>
				{/if}
				{#if inference.target_families.length > 0}
					<div class="text-sm">
						<div class="text-gray-500 mb-1">Amendment target families</div>
						<div class="flex flex-wrap gap-2">
							{#each inference.target_families as [fam, count]}
								<span class="px-2 py-0.5 rounded bg-green-50 text-green-700 text-xs">
									{fam} ({count})
								</span>
							{/each}
						</div>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Mismatches Table -->
		<div class="bg-white rounded-lg border overflow-hidden">
			<table class="w-full text-sm">
				<thead class="bg-gray-50 border-b">
					<tr>
						<th class="text-left px-3 py-2 font-medium text-gray-600">Law</th>
						<th class="text-left px-3 py-2 font-medium text-gray-600">Assigned Family</th>
						<th class="text-left px-3 py-2 font-medium text-gray-600">Suggested</th>
						<th class="text-left px-3 py-2 font-medium text-gray-600">Confidence</th>
						<th class="text-left px-3 py-2 font-medium text-gray-600">Evidence</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-gray-100">
					{#each filteredMismatches as m (m.law_name)}
						<tr
							class="hover:bg-gray-50 cursor-pointer transition-colors"
							class:bg-blue-50={selectedLaw === m.law_name}
							on:click={() => (selectedLaw = selectedLaw === m.law_name ? null : m.law_name)}
						>
							<td class="px-3 py-2 font-mono text-xs text-gray-700">{m.law_name}</td>
							<td class="px-3 py-2 text-gray-600 max-w-48 truncate">{m.assigned_family || '-'}</td>
							<td class="px-3 py-2 text-red-700 font-medium max-w-48 truncate"
								>{m.suggested_family || '-'}</td
							>
							<td class="px-3 py-2">
								<span
									class="inline-block px-2 py-0.5 text-xs font-medium rounded {confidenceBadge(
										m.confidence
									)}"
								>
									{m.confidence}
								</span>
							</td>
							<td class="px-3 py-2 text-xs text-gray-500">
								{#if m.parent_families.length > 0}
									Parent: {m.parent_families.map(([f]) => f).join(', ')}
								{/if}
								{#if m.target_families.length > 0}
									{m.parent_families.length > 0 ? ' | ' : ''}Targets: {m.target_families
										.map(([f]) => f)
										.join(', ')}
								{/if}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{:else}
		<div class="text-center py-8 text-gray-500">No family mismatches found</div>
	{/if}
</div>
