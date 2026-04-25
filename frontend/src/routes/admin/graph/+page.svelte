<script lang="ts">
	import {
		useGraphStatsQuery,
		useMismatchCountsQuery,
		useEnactedByQuery,
		useAmendsQuery,
		useRescindsQuery
	} from '$lib/query/graph';

	let activeTab: 'enacted_by' | 'amends' | 'rescinds' = 'enacted_by';
	let familyFilter = '';
	let hideTitleConfirmed = true;

	$: statsQuery = useGraphStatsQuery();
	$: countsQuery = useMismatchCountsQuery();
	$: enactedByQuery = useEnactedByQuery();
	$: amendsQuery = useAmendsQuery();
	$: rescindsQuery = useRescindsQuery();

	$: stats = $statsQuery?.data;
	$: counts = $countsQuery?.data;
	$: enactedByItems = $enactedByQuery?.data?.items ?? [];
	$: amendsItems = $amendsQuery?.data?.items ?? [];
	$: rescindsItems = $rescindsQuery?.data?.items ?? [];

	// Filter enacted_by by family + title-confirmed toggle
	$: titleConfirmedCount = enactedByItems.filter((m) => m.title_confirmed).length;
	$: filteredEnacted = enactedByItems.filter((m) => {
		if (familyFilter && m.assigned_family !== familyFilter) return false;
		if (hideTitleConfirmed && m.title_confirmed) return false;
		return true;
	});

	$: filteredAmends = familyFilter
		? amendsItems.filter((m) => m.assigned_family === familyFilter)
		: amendsItems;

	$: filteredRescinds = familyFilter
		? rescindsItems.filter((m) => m.assigned_family === familyFilter)
		: rescindsItems;

	$: allFamilies = [
		...new Set(
			[
				...enactedByItems.map((m) => m.assigned_family),
				...amendsItems.map((m) => m.assigned_family),
				...rescindsItems.map((m) => m.assigned_family)
			].filter(Boolean)
		)
	].sort() as string[];
</script>

<svelte:head>
	<title>Family Graph — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<div>
		<h1 class="text-2xl font-bold text-gray-900">Law Relationship Graph</h1>
		<p class="text-sm text-gray-500 mt-1">
			Graph-informed family classification review by relationship type
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

		<!-- Tabs -->
		<div class="flex gap-1 border-b border-gray-200">
			<button
				on:click={() => (activeTab = 'enacted_by')}
				class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
					{activeTab === 'enacted_by'
					? 'border-blue-500 text-blue-600'
					: 'border-transparent text-gray-500 hover:text-gray-700'}"
			>
				Enacted By {counts ? `(${counts.enacted_by})` : ''}
			</button>
			<button
				on:click={() => (activeTab = 'amends')}
				class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
					{activeTab === 'amends'
					? 'border-blue-500 text-blue-600'
					: 'border-transparent text-gray-500 hover:text-gray-700'}"
			>
				Amends {counts ? `(${counts.amends})` : ''}
			</button>
			<button
				on:click={() => (activeTab = 'rescinds')}
				class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
					{activeTab === 'rescinds'
					? 'border-blue-500 text-blue-600'
					: 'border-transparent text-gray-500 hover:text-gray-700'}"
			>
				Rescinds {counts ? `(${counts.rescinds})` : ''}
			</button>
		</div>

		<!-- Family Filter -->
		<div class="flex items-center gap-3">
			<select
				bind:value={familyFilter}
				class="px-3 py-1.5 border rounded-lg text-sm w-72 bg-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
			>
				<option value="">All families</option>
				{#each allFamilies as fam}
					<option value={fam}>{fam}</option>
				{/each}
			</select>
			<span class="text-sm text-gray-500">
				{#if activeTab === 'enacted_by'}{filteredEnacted.length}
				{:else if activeTab === 'amends'}{filteredAmends.length}
				{:else}{filteredRescinds.length}
				{/if} mismatches shown
			</span>
		</div>

		<!-- Tab Content -->
		{#if activeTab === 'enacted_by'}
			<!-- Enacted By Tab -->
			{#if $enactedByQuery?.isLoading}
				<div class="text-center py-8 text-gray-500">Loading...</div>
			{:else}
				<!-- Filter Rules -->
				<div class="flex gap-2 flex-wrap">
					<button
						class="px-3 py-1.5 rounded-full text-xs font-medium transition-colors
							{hideTitleConfirmed ? 'bg-green-600 text-white' : 'bg-green-100 text-green-700 hover:bg-green-200'}"
						on:click={() => (hideTitleConfirmed = !hideTitleConfirmed)}
					>
						{hideTitleConfirmed ? 'Hiding' : 'Show'} title-confirmed ({titleConfirmedCount})
					</button>
				</div>

				<div class="bg-white rounded-lg border overflow-hidden">
					<table class="w-full text-sm">
						<thead class="bg-gray-50 border-b">
							<tr>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Law</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">SI Code</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Assigned Family</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Parent Act</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Parent Family</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-100">
							{#each filteredEnacted as m (m.law_name + m.parent_law)}
								<tr class="hover:bg-gray-50">
									<td class="px-3 py-2">
										<div class="font-medium text-gray-900 text-xs">{m.title || m.law_name}</div>
										<div class="font-mono text-xs text-gray-400">{m.law_name}</div>
									</td>
									<td class="px-3 py-2 text-xs text-gray-500 max-w-36 truncate">
										{#if m.si_code && m.si_code.length > 0}
											{m.si_code.join(', ')}
										{:else}
											<span class="text-gray-300">-</span>
										{/if}
									</td>
									<td class="px-3 py-2 text-xs text-gray-600 max-w-40 truncate"
										>{m.assigned_family || '-'}</td
									>
									<td class="px-3 py-2">
										<div class="text-xs font-medium text-gray-900">
											{m.parent_title || m.parent_law}
										</div>
										<div class="font-mono text-xs text-gray-400">{m.parent_law}</div>
									</td>
									<td class="px-3 py-2 text-xs text-red-700 font-medium max-w-40 truncate"
										>{m.parent_family}</td
									>
								</tr>
							{/each}
							{#if filteredEnacted.length === 0}
								<tr
									><td colspan="5" class="px-3 py-8 text-center text-gray-400">No mismatches</td
									></tr
								>
							{/if}
						</tbody>
					</table>
				</div>
			{/if}
		{:else if activeTab === 'amends'}
			<!-- Amends Tab -->
			{#if $amendsQuery?.isLoading}
				<div class="text-center py-8 text-gray-500">Loading...</div>
			{:else}
				<div class="bg-white rounded-lg border overflow-hidden">
					<table class="w-full text-sm">
						<thead class="bg-gray-50 border-b">
							<tr>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Law</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Assigned Family</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Top Target Family</th>
								<th class="text-right px-3 py-2 font-medium text-gray-600">Consensus</th>
								<th class="text-right px-3 py-2 font-medium text-gray-600">Total</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Target Families</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-100">
							{#each filteredAmends as m (m.law_name)}
								<tr class="hover:bg-gray-50">
									<td class="px-3 py-2 font-mono text-xs text-gray-700">{m.law_name}</td>
									<td class="px-3 py-2 text-xs text-gray-600 max-w-40 truncate"
										>{m.assigned_family || '-'}</td
									>
									<td class="px-3 py-2 text-xs text-red-700 font-medium max-w-40 truncate"
										>{m.suggested_family}</td
									>
									<td class="px-3 py-2 text-right tabular-nums">
										<span
											class="px-1.5 py-0.5 rounded text-xs {m.consensus_pct >= 80
												? 'bg-red-100 text-red-700 font-medium'
												: m.consensus_pct >= 60
													? 'bg-orange-100 text-orange-700'
													: 'bg-gray-100 text-gray-600'}"
										>
											{m.consensus_pct}%
										</span>
									</td>
									<td class="px-3 py-2 text-right text-xs text-gray-500 tabular-nums"
										>{m.total_amends}</td
									>
									<td class="px-3 py-2 text-xs text-gray-500">
										{#each m.target_families.slice(0, 3) as tf}
											<span class="inline-block mr-1">{tf.family} ({tf.count})</span>
										{/each}
									</td>
								</tr>
							{/each}
							{#if filteredAmends.length === 0}
								<tr
									><td colspan="6" class="px-3 py-8 text-center text-gray-400">No mismatches</td
									></tr
								>
							{/if}
						</tbody>
					</table>
				</div>
			{/if}
		{:else}
			<!-- Rescinds Tab -->
			{#if $rescindsQuery?.isLoading}
				<div class="text-center py-8 text-gray-500">Loading...</div>
			{:else}
				<div class="bg-white rounded-lg border overflow-hidden">
					<table class="w-full text-sm">
						<thead class="bg-gray-50 border-b">
							<tr>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Law</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Assigned Family</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Rescinded Law</th>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Rescinded Family</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-100">
							{#each filteredRescinds as m (m.law_name + m.rescinded_law)}
								<tr class="hover:bg-gray-50">
									<td class="px-3 py-2">
										<div class="font-medium text-gray-900 text-xs">{m.title || m.law_name}</div>
										<div class="font-mono text-xs text-gray-400">{m.law_name}</div>
									</td>
									<td class="px-3 py-2 text-xs text-gray-600 max-w-40 truncate"
										>{m.assigned_family || '-'}</td
									>
									<td class="px-3 py-2">
										<div class="text-xs font-medium text-gray-900">
											{m.rescinded_title || m.rescinded_law}
										</div>
										<div class="font-mono text-xs text-gray-400">{m.rescinded_law}</div>
									</td>
									<td class="px-3 py-2 text-xs text-red-700 font-medium max-w-40 truncate"
										>{m.rescinded_family}</td
									>
								</tr>
							{/each}
							{#if filteredRescinds.length === 0}
								<tr
									><td colspan="4" class="px-3 py-8 text-center text-gray-400">No mismatches</td
									></tr
								>
							{/if}
						</tbody>
					</table>
				</div>
			{/if}
		{/if}
	{/if}
</div>
