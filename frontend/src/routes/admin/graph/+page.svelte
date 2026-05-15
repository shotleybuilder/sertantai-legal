<script lang="ts">
	import {
		useGraphStatsQuery,
		useMismatchCountsQuery,
		useEnactedByQuery,
		useAmendsQuery,
		useRescindsQuery,
		graphKeys
	} from '$lib/query/graph';
	import { updateLawFamily, rescrapeLrt, rebuildEdges, type EnactedByItem } from '$lib/api/graph';
	import { reparseLat } from '$lib/api/lat';
	import { useQueryClient } from '@tanstack/svelte-query';

	const queryClient = useQueryClient();

	// Family options — single source for all dropdowns
	const HS_FAMILIES = [
		'💙 FIRE',
		'💙 FIRE: Dangerous and Explosive Substances',
		'💙 FOOD',
		'💙 HEALTH: Coronavirus',
		'💙 HEALTH: Drug & Medicine Safety',
		'💙 HEALTH: Patient Safety',
		'💙 HEALTH: Public',
		'💙 OH&S: Gas & Electrical Safety',
		'💙 OH&S: Mines & Quarries',
		'💙 OH&S: Occupational / Personal Safety',
		'💙 OH&S: Offshore Safety',
		'💙 PUBLIC',
		'💙 PUBLIC: Building Safety',
		'💙 PUBLIC: Consumer / Product Safety',
		'💙 PUBLIC: Data',
		'💙 TRANSPORT: Air Safety',
		'💙 TRANSPORT: Rail Safety',
		'💙 TRANSPORT: Road Safety',
		'💙 TRANSPORT: Maritime Safety'
	];
	const ENV_FAMILIES = [
		'💚 AGRICULTURE',
		'💚 AGRICULTURE: Pesticides',
		'💚 AIR QUALITY',
		'💚 ANIMALS & ANIMAL HEALTH',
		'💚 ANTARCTICA',
		'💚 BUILDINGS',
		'💚 CLIMATE CHANGE',
		'💚 ENERGY',
		'💚 ENVIRONMENTAL PROTECTION',
		'💚 FINANCE',
		'💚 FISHERIES & FISHING',
		'💚 GMOs',
		'💚 HISTORIC ENVIRONMENT',
		'💚 MARINE & RIVERINE',
		'💚 NOISE',
		'💚 NUCLEAR & RADIOLOGICAL',
		'💚 OIL & GAS - OFFSHORE - PETROLEUM',
		'💚 PLANNING & INFRASTRUCTURE',
		'💚 PLANT HEALTH',
		'💚 POLLUTION',
		'💚 TOWN & COUNTRY PLANNING',
		'💚 TRANSPORT',
		'💚 TRANSPORT: Aviation',
		'💚 TRANSPORT: Harbours & Shipping',
		'💚 TRANSPORT: Railways & Rail Transport',
		'💚 TRANSPORT: Roads & Vehicles',
		'💚 TREES: Forestry & Timber',
		'💚 WASTE',
		'💚 WATER & WASTEWATER',
		'💚 WILDLIFE & COUNTRYSIDE'
	];
	const HR_FAMILIES = [
		'💜 HR: Employment',
		'💜 HR: Insurance / Compensation / Wages / Benefits',
		'💜 HR: Working Time'
	];

	let activeTab: 'enacted_by' | 'amends' | 'rescinds' = 'enacted_by';
	let familyFilter = '';
	let hideTitleConfirmed = true;
	let activeQaFilter: 'si_code_mismatch' | 'outlier' | 'si_enacts_si' | 'no_enacted_fams' | '' = '';

	// Detail panel state
	let selectedRow: EnactedByItem | null = null;
	let editFamily = '';
	let editFamilyII = '';
	let editParentFamily = '';
	let editParentFamilyII = '';
	let editMessage = '';
	let editError = '';
	let saving = false;
	let reparsing = false;
	let rescraping = false;
	let rebuilding = false;
	let rebuildMessage = '';

	async function handleRebuildEdges() {
		rebuilding = true;
		rebuildMessage = '';
		try {
			const result = await rebuildEdges();
			rebuildMessage = `Rebuilt: ${result.total_edges.toLocaleString()} edges (${result.duration_ms}ms)`;
			queryClient.invalidateQueries({ queryKey: graphKeys.all });
		} catch (e) {
			rebuildMessage = e instanceof Error ? e.message : 'Rebuild failed';
		} finally {
			rebuilding = false;
		}
	}

	let reparsingParent = false;

	async function handleReparseParent() {
		if (!selectedRow) return;
		reparsingParent = true;
		editMessage = '';
		editError = '';
		try {
			const result = await reparseLat(selectedRow.parent_law);
			editMessage = `Parent LAT re-parsed: ${result.lat.inserted} rows, ${result.annotations.inserted} annotations (${result.duration_ms}ms)`;
		} catch (e) {
			editError = e instanceof Error ? e.message : 'Parent LAT reparse failed';
		} finally {
			reparsingParent = false;
		}
	}

	let rescrapingParent = false;

	async function handleRescrapeParent() {
		if (!selectedRow) return;
		rescrapingParent = true;
		editMessage = '';
		editError = '';
		try {
			const result = await rescrapeLrt(selectedRow.parent_law);
			editMessage = `Parent LRT re-scraped (${result.status}) in ${result.duration_ms}ms`;
			queryClient.invalidateQueries({ queryKey: graphKeys.all });
		} catch (e) {
			editError = e instanceof Error ? e.message : 'Parent LRT rescrape failed';
		} finally {
			rescrapingParent = false;
		}
	}

	function selectEnactedRow(m: EnactedByItem) {
		if (selectedRow?.law_name === m.law_name && selectedRow?.parent_law === m.parent_law) {
			selectedRow = null;
			return;
		}
		selectedRow = m;
		editFamily = m.assigned_family || '';
		editFamilyII = m.family_ii || '';
		editParentFamily = m.parent_family || '';
		editParentFamilyII = m.parent_family_ii || '';
		editMessage = '';
		editError = '';
	}

	async function saveFamily(lawId: string, family: string, familyII: string, label: string) {
		saving = true;
		editMessage = '';
		editError = '';
		try {
			await updateLawFamily(lawId, { family: family || null, family_ii: familyII || null });
			editMessage = `${label} family updated`;
			queryClient.invalidateQueries({ queryKey: graphKeys.all });
		} catch (e) {
			editError = e instanceof Error ? e.message : 'Update failed';
		} finally {
			saving = false;
		}
	}

	async function handleReparse() {
		if (!selectedRow) return;
		reparsing = true;
		editMessage = '';
		editError = '';
		try {
			const result = await reparseLat(selectedRow.law_name);
			editMessage = `LAT re-parsed: ${result.lat.inserted} rows, ${result.annotations.inserted} annotations (${result.duration_ms}ms)`;
		} catch (e) {
			editError = e instanceof Error ? e.message : 'LAT reparse failed';
		} finally {
			reparsing = false;
		}
	}

	async function handleRescrape() {
		if (!selectedRow) return;
		rescraping = true;
		editMessage = '';
		editError = '';
		try {
			const result = await rescrapeLrt(selectedRow.law_name);
			editMessage = `LRT re-scraped (${result.status}) in ${result.duration_ms}ms`;
			queryClient.invalidateQueries({ queryKey: graphKeys.all });
		} catch (e) {
			editError = e instanceof Error ? e.message : 'LRT rescrape failed';
		} finally {
			rescraping = false;
		}
	}

	// Sort state
	let sortCol = '';
	let sortDir: 'asc' | 'desc' = 'asc';

	function toggleSort(col: string) {
		if (sortCol === col) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortCol = col;
			sortDir = 'asc';
		}
	}

	function sortIcon(col: string): string {
		if (sortCol !== col) return '';
		return sortDir === 'asc' ? ' ↑' : ' ↓';
	}

	function sortRows<T>(rows: T[]): T[] {
		if (!sortCol) return rows;
		return [...rows].sort((a, b) => {
			const av = (a as Record<string, unknown>)[sortCol] ?? '';
			const bv = (b as Record<string, unknown>)[sortCol] ?? '';
			const cmp = String(av).localeCompare(String(bv), undefined, { numeric: true });
			return sortDir === 'asc' ? cmp : -cmp;
		});
	}

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

	// Reactive sort key — changes when sort state changes, triggering re-sort
	$: _sortKey = `${sortCol}:${sortDir}`;

	// QA filter counts
	$: titleConfirmedCount = enactedByItems.filter((m) => m.title_confirmed).length;
	$: siMismatchCount = enactedByItems.filter((m) => m.si_code_mismatch).length;
	$: outlierCount = enactedByItems.filter((m) => m.outlier).length;
	$: siEnactsSiCount = enactedByItems.filter((m) => m.si_enacts_si).length;
	$: noEnactedFamsCount = enactedByItems.filter(
		(m) => !m.parent_enacted_families || Object.keys(m.parent_enacted_families).length === 0
	).length;

	// Filter + sort
	$: filteredEnacted = (() => {
		void _sortKey;
		return sortRows(
			enactedByItems.filter((m) => {
				if (familyFilter && m.assigned_family !== familyFilter) return false;
				if (hideTitleConfirmed && m.title_confirmed) return false;
				// "show only" QA filters
				if (activeQaFilter === 'si_code_mismatch' && !m.si_code_mismatch) return false;
				if (activeQaFilter === 'outlier' && !m.outlier) return false;
				if (activeQaFilter === 'si_enacts_si' && !m.si_enacts_si) return false;
				if (
					activeQaFilter === 'no_enacted_fams' &&
					m.parent_enacted_families &&
					Object.keys(m.parent_enacted_families).length > 0
				)
					return false;
				return true;
			})
		);
	})();

	$: filteredAmends = (() => {
		void _sortKey;
		return sortRows(
			familyFilter ? amendsItems.filter((m) => m.assigned_family === familyFilter) : amendsItems
		);
	})();

	$: filteredRescinds = (() => {
		void _sortKey;
		return sortRows(
			familyFilter ? rescindsItems.filter((m) => m.assigned_family === familyFilter) : rescindsItems
		);
	})();

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

		<!-- Rebuild bar -->
		<div class="flex items-center gap-3">
			<button
				class="px-3 py-1.5 text-xs font-medium rounded transition-colors
					{stats.stale_count > 0
					? 'bg-amber-600 text-white hover:bg-amber-700'
					: 'bg-gray-100 text-gray-600 hover:bg-gray-200'}
					disabled:opacity-50"
				disabled={rebuilding}
				on:click={handleRebuildEdges}
			>
				{rebuilding ? 'Rebuilding...' : 'Rebuild edges'}
			</button>
			{#if stats.stale_count > 0}
				<span class="text-xs text-amber-600">
					{stats.stale_count} laws modified since last rebuild
				</span>
			{/if}
			{#if rebuildMessage}
				<span class="text-xs text-green-700">{rebuildMessage}</span>
			{/if}
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
				{#if activeTab === 'enacted_by'}{filteredEnacted.length} of {enactedByItems.length} shown
				{:else if activeTab === 'amends'}{filteredAmends.length}
				{:else}{filteredRescinds.length}
				{/if}{#if activeTab !== 'enacted_by'}
					mismatches shown{/if}
			</span>
		</div>

		<!-- Tab Content -->
		{#if activeTab === 'enacted_by'}
			<!-- Enacted By Tab -->
			{#if $enactedByQuery?.isLoading}
				<div class="text-center py-8 text-gray-500">Loading...</div>
			{:else}
				<!-- QA Filter Rules -->
				<div class="flex gap-2 flex-wrap">
					<button
						class="px-3 py-1.5 rounded-full text-xs font-medium transition-colors
							{hideTitleConfirmed ? 'bg-green-600 text-white' : 'bg-green-100 text-green-700 hover:bg-green-200'}"
						on:click={() => (hideTitleConfirmed = !hideTitleConfirmed)}
					>
						{hideTitleConfirmed ? 'Hiding' : 'Show'} title-confirmed ({titleConfirmedCount})
					</button>
					<button
						class="px-3 py-1.5 rounded-full text-xs font-medium transition-colors
							{activeQaFilter === 'si_code_mismatch'
							? 'bg-amber-600 text-white'
							: 'bg-amber-100 text-amber-700 hover:bg-amber-200'}"
						on:click={() =>
							(activeQaFilter = activeQaFilter === 'si_code_mismatch' ? '' : 'si_code_mismatch')}
					>
						SI mismatch ({siMismatchCount})
					</button>
					<button
						class="px-3 py-1.5 rounded-full text-xs font-medium transition-colors
							{activeQaFilter === 'outlier'
							? 'bg-red-600 text-white'
							: 'bg-red-100 text-red-700 hover:bg-red-200'}"
						on:click={() => (activeQaFilter = activeQaFilter === 'outlier' ? '' : 'outlier')}
					>
						Outlier &lt;5% ({outlierCount})
					</button>
					<button
						class="px-3 py-1.5 rounded-full text-xs font-medium transition-colors
							{activeQaFilter === 'si_enacts_si'
							? 'bg-purple-600 text-white'
							: 'bg-purple-100 text-purple-700 hover:bg-purple-200'}"
						on:click={() =>
							(activeQaFilter = activeQaFilter === 'si_enacts_si' ? '' : 'si_enacts_si')}
					>
						SI enacts SI ({siEnactsSiCount})
					</button>
					<button
						class="px-3 py-1.5 rounded-full text-xs font-medium transition-colors
							{activeQaFilter === 'no_enacted_fams'
							? 'bg-blue-600 text-white'
							: 'bg-blue-100 text-blue-700 hover:bg-blue-200'}"
						on:click={() =>
							(activeQaFilter = activeQaFilter === 'no_enacted_fams' ? '' : 'no_enacted_fams')}
					>
						No enacted fams ({noEnactedFamsCount})
					</button>
				</div>

				<div class="flex gap-4">
					<!-- Table (left) -->
					<div
						class="bg-white rounded-lg border overflow-auto {selectedRow
							? 'flex-1 min-w-0'
							: 'w-full'}"
						style="max-height: calc(100vh - 300px)"
					>
						<table class="w-full text-sm">
							<thead class="bg-gray-50 border-b sticky top-0 z-10">
								<tr>
									<th
										class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
										on:click={() => toggleSort('title')}>Law{sortIcon('title')}</th
									>
									<th
										class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
										on:click={() => toggleSort('si_code')}>SI Code{sortIcon('si_code')}</th
									>
									<th
										class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
										on:click={() => toggleSort('assigned_family')}
										>Assigned Family{sortIcon('assigned_family')}</th
									>
									<th
										class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
										on:click={() => toggleSort('parent_title')}
										>Parent Act{sortIcon('parent_title')}</th
									>
									<th class="text-left px-3 py-2 font-medium text-gray-600">Enacted SI Codes</th>
									<th class="text-left px-3 py-2 font-medium text-gray-600">Enacted Families</th>
									<th
										class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
										on:click={() => toggleSort('parent_family')}
										>Parent Family{sortIcon('parent_family')}</th
									>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-100">
								{#each filteredEnacted as m (m.law_name + m.parent_law)}
									<tr
										class="hover:bg-gray-50 cursor-pointer transition-colors"
										class:bg-blue-50={selectedRow?.law_name === m.law_name &&
											selectedRow?.parent_law === m.parent_law}
										on:click={() => selectEnactedRow(m)}
									>
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
										<td class="px-3 py-2 text-xs text-gray-500 max-w-40">
											{#if m.parent_enacted_si_codes && Object.keys(m.parent_enacted_si_codes).length > 0}
												{#each Object.entries(m.parent_enacted_si_codes)
													.sort((a, b) => b[1] - a[1])
													.slice(0, 3) as [code, count]}
													<span
														class="inline-block mr-1 mb-0.5 px-1 py-0.5 bg-gray-100 rounded text-xs"
														>{code} ({count})</span
													>
												{/each}
												{#if Object.keys(m.parent_enacted_si_codes).length > 3}
													<span class="text-gray-400"
														>+{Object.keys(m.parent_enacted_si_codes).length - 3}</span
													>
												{/if}
											{:else}
												<span class="text-gray-300">-</span>
											{/if}
										</td>
										<td class="px-3 py-2 text-xs text-gray-500 max-w-40">
											{#if m.parent_enacted_families && Object.keys(m.parent_enacted_families).length > 0}
												{#each Object.entries(m.parent_enacted_families)
													.sort((a, b) => b[1] - a[1])
													.slice(0, 3) as [fam, count]}
													<span
														class="inline-block mr-1 mb-0.5 px-1 py-0.5 bg-indigo-50 text-indigo-700 rounded text-xs"
														>{fam} ({count})</span
													>
												{/each}
												{#if Object.keys(m.parent_enacted_families).length > 3}
													<span class="text-gray-400"
														>+{Object.keys(m.parent_enacted_families).length - 3}</span
													>
												{/if}
											{:else}
												<span class="text-gray-300">-</span>
											{/if}
										</td>
										<td class="px-3 py-2 text-xs text-red-700 font-medium max-w-40 truncate"
											>{m.parent_family}</td
										>
									</tr>
								{/each}
								{#if filteredEnacted.length === 0}
									<tr
										><td colspan="7" class="px-3 py-8 text-center text-gray-400"
											>No items match filters</td
										></tr
									>
								{/if}
							</tbody>
						</table>
					</div>

					<!-- Side Panel (right) -->
					{#if selectedRow}
						<div
							class="w-96 flex-shrink-0 bg-white rounded-lg border p-4 space-y-4 sticky top-4 self-start overflow-y-auto"
							style="max-height: calc(100vh - 200px)"
						>
							<div class="flex items-center justify-between">
								<h3 class="text-sm font-semibold text-gray-900 truncate pr-2">
									{selectedRow.title || selectedRow.law_name}
								</h3>
								<button
									class="text-gray-400 hover:text-gray-600 text-lg flex-shrink-0"
									on:click={() => (selectedRow = null)}>x</button
								>
							</div>
							<div class="font-mono text-xs text-gray-400">{selectedRow.law_name}</div>
							<div class="flex gap-2 flex-wrap">
								<button
									class="px-2 py-1 text-xs font-medium text-white bg-orange-600 rounded hover:bg-orange-700 disabled:opacity-50"
									disabled={rescraping}
									on:click={handleRescrape}
									>{rescraping ? 'Re-scraping...' : 'Re-scrape LRT'}</button
								>
								<button
									class="px-2 py-1 text-xs font-medium text-white bg-indigo-600 rounded hover:bg-indigo-700 disabled:opacity-50"
									disabled={reparsing}
									on:click={handleReparse}>{reparsing ? 'Re-parsing...' : 'Re-parse LAT'}</button
								>
								<a
									href="/admin/lat?law={encodeURIComponent(selectedRow.law_name)}"
									class="px-2 py-1 text-xs text-indigo-600 hover:text-indigo-800 border border-indigo-200 rounded"
									>LAT browser</a
								>
							</div>
							<div class="border rounded p-3 space-y-2">
								<h4 class="text-xs font-medium text-gray-700">Enacted Law</h4>
								<div>
									<label class="text-xs text-gray-500">Family</label>
									<select
										bind:value={editFamily}
										class="w-full px-2 py-1 border rounded text-xs bg-white"
									>
										<option value="">-- None --</option>
										<optgroup label="H&S"
											>{#each HS_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
										<optgroup label="Env"
											>{#each ENV_FAMILIES as opt}<option value={opt}>{opt}</option
												>{/each}</optgroup
										>
										<optgroup label="HR"
											>{#each HR_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
									</select>
								</div>
								<div>
									<label class="text-xs text-gray-500">Family II</label>
									<select
										bind:value={editFamilyII}
										class="w-full px-2 py-1 border rounded text-xs bg-white"
									>
										<option value="">-- None --</option>
										<optgroup label="H&S"
											>{#each HS_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
										<optgroup label="Env"
											>{#each ENV_FAMILIES as opt}<option value={opt}>{opt}</option
												>{/each}</optgroup
										>
										<optgroup label="HR"
											>{#each HR_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
									</select>
								</div>
								<button
									class="px-2 py-1 text-xs font-medium text-white bg-green-600 rounded hover:bg-green-700 disabled:opacity-50 w-full"
									disabled={saving}
									on:click={() =>
										saveFamily(selectedRow?.law_id ?? '', editFamily, editFamilyII, 'Enacted law')}
									>{saving ? 'Saving...' : 'Save Enacted Law'}</button
								>
							</div>
							<!-- QA Signals -->
							<div class="border rounded p-3 space-y-1.5">
								<h4 class="text-xs font-medium text-gray-700">QA Signals</h4>
								<div class="flex flex-wrap gap-1.5">
									{#if selectedRow.title_confirmed}
										<span class="px-1.5 py-0.5 rounded text-xs bg-green-100 text-green-700"
											>title confirmed</span
										>
									{/if}
									{#if selectedRow.si_code_mismatch}
										<span class="px-1.5 py-0.5 rounded text-xs bg-amber-100 text-amber-700"
											>SI mismatch: {selectedRow.si_code_family}</span
										>
									{:else if selectedRow.si_code_family}
										<span class="px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600"
											>SI code: {selectedRow.si_code_family}</span
										>
									{/if}
									{#if selectedRow.outlier}
										<span class="px-1.5 py-0.5 rounded text-xs bg-red-100 text-red-700"
											>outlier {selectedRow.outlier_pct}%</span
										>
									{:else if selectedRow.outlier_pct > 0}
										<span class="px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600"
											>{selectedRow.outlier_pct}% of parent</span
										>
									{/if}
									{#if selectedRow.si_enacts_si}
										<span class="px-1.5 py-0.5 rounded text-xs bg-purple-100 text-purple-700"
											>SI enacts SI</span
										>
									{/if}
									<span class="px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-500"
										>parent: {selectedRow.parent_type}</span
									>
								</div>
							</div>

							<div class="border rounded p-3 space-y-2">
								<h4 class="text-xs font-medium text-gray-700 truncate">
									Parent: {selectedRow.parent_title || selectedRow.parent_law}
								</h4>
								<div class="font-mono text-xs text-gray-400 mb-1">{selectedRow.parent_law}</div>
								<div class="flex gap-2 flex-wrap mb-2">
									<button
										class="px-2 py-1 text-xs font-medium text-white bg-orange-600 rounded hover:bg-orange-700 disabled:opacity-50"
										disabled={rescrapingParent}
										on:click={handleRescrapeParent}
										>{rescrapingParent ? 'Re-scraping...' : 'Re-scrape LRT'}</button
									>
									<button
										class="px-2 py-1 text-xs font-medium text-white bg-indigo-600 rounded hover:bg-indigo-700 disabled:opacity-50"
										disabled={reparsingParent}
										on:click={handleReparseParent}
										>{reparsingParent ? 'Re-parsing...' : 'Re-parse LAT'}</button
									>
									<a
										href="/admin/lat?law={encodeURIComponent(selectedRow.parent_law)}"
										class="px-2 py-1 text-xs text-indigo-600 hover:text-indigo-800 border border-indigo-200 rounded"
										>LAT browser</a
									>
								</div>
								<div>
									<label class="text-xs text-gray-500">Family</label>
									<select
										bind:value={editParentFamily}
										class="w-full px-2 py-1 border rounded text-xs bg-white"
									>
										<option value="">-- None --</option>
										<optgroup label="H&S"
											>{#each HS_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
										<optgroup label="Env"
											>{#each ENV_FAMILIES as opt}<option value={opt}>{opt}</option
												>{/each}</optgroup
										>
										<optgroup label="HR"
											>{#each HR_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
									</select>
								</div>
								<div>
									<label class="text-xs text-gray-500">Family II</label>
									<select
										bind:value={editParentFamilyII}
										class="w-full px-2 py-1 border rounded text-xs bg-white"
									>
										<option value="">-- None --</option>
										<optgroup label="H&S"
											>{#each HS_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
										<optgroup label="Env"
											>{#each ENV_FAMILIES as opt}<option value={opt}>{opt}</option
												>{/each}</optgroup
										>
										<optgroup label="HR"
											>{#each HR_FAMILIES as opt}<option value={opt}>{opt}</option>{/each}</optgroup
										>
									</select>
								</div>
								<button
									class="px-2 py-1 text-xs font-medium text-white bg-green-600 rounded hover:bg-green-700 disabled:opacity-50 w-full"
									disabled={saving}
									on:click={() =>
										saveFamily(
											selectedRow?.parent_id ?? '',
											editParentFamily,
											editParentFamilyII,
											'Parent Act'
										)}>{saving ? 'Saving...' : 'Save Parent Act'}</button
								>
							</div>
							{#if editMessage}<div class="text-xs text-green-700 bg-green-50 rounded p-2">
									{editMessage}
								</div>{/if}
							{#if editError}<div class="text-xs text-red-700 bg-red-50 rounded p-2">
									{editError}
								</div>{/if}
							{#if selectedRow.md_description}
								<div class="border-t pt-3 mt-2">
									<h4 class="text-xs font-medium text-gray-500 mb-1">Description</h4>
									<p class="text-xs text-gray-600 leading-relaxed bg-gray-50 rounded p-2">
										{selectedRow.md_description}
									</p>
								</div>
							{/if}
						</div>
					{/if}
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
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('law_name')}>Law{sortIcon('law_name')}</th
								>
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('assigned_family')}
									>Assigned Family{sortIcon('assigned_family')}</th
								>
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('suggested_family')}
									>Top Target Family{sortIcon('suggested_family')}</th
								>
								<th
									class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('consensus_pct')}
									>Consensus{sortIcon('consensus_pct')}</th
								>
								<th
									class="text-right px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('total_amends')}>Total{sortIcon('total_amends')}</th
								>
								<th class="text-left px-3 py-2 font-medium text-gray-600">Target Families</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-100">
							{#each filteredAmends as m (m.law_name)}
								<tr class="hover:bg-gray-50">
									<td class="px-3 py-2">
										<div class="font-medium text-gray-900 text-xs">{m.title || m.law_name}</div>
										<div class="font-mono text-xs text-gray-400">{m.law_name}</div>
									</td>
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
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('title')}>Law{sortIcon('title')}</th
								>
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('assigned_family')}
									>Assigned Family{sortIcon('assigned_family')}</th
								>
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('rescinded_title')}
									>Rescinded Law{sortIcon('rescinded_title')}</th
								>
								<th
									class="text-left px-3 py-2 font-medium text-gray-600 cursor-pointer hover:text-gray-900"
									on:click={() => toggleSort('rescinded_family')}
									>Rescinded Family{sortIcon('rescinded_family')}</th
								>
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
