<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite } from '$lib/pglite/client';
	import { getChangeTrackingStats, getSessionAnalytics } from '$lib/api/analytics';
	import type { ChangeTrackingStats, SessionAnalytics } from '$lib/api/analytics';

	// ── PGLite Stats (Sections 1-3) ────────────────────────────────

	interface FamilyCount {
		family: string;
		count: number;
	}
	interface LabelCount {
		label: string;
		count: number;
	}
	interface PopulationRow {
		field: string;
		populated: number;
		total: number;
	}

	let totalRecords = 0;
	let nullFamily = 0;
	let nullTitleEn = 0;
	let familyCounts: FamilyCount[] = [];
	let makingCounts: LabelCount[] = [];
	let liveCounts: LabelCount[] = [];

	let populationStats: PopulationRow[] = [];

	let withLat = 0;
	let withoutLat = 0;
	let latBuckets: LabelCount[] = [];
	let makingNoLat = 0;

	let pgliteLoading = true;
	let pgliteError = '';

	// ── API Stats (Sections 4-5) ───────────────────────────────────

	let changeStats: ChangeTrackingStats | null = null;
	let sessionStats: SessionAnalytics | null = null;
	let apiLoading = true;
	let apiError = '';

	// ── Collapsible sections ────────────────────────────────────────

	let openSections: Record<string, boolean> = {
		completeness: true,
		population: true,
		lat: true,
		changes: true,
		sessions: true
	};

	function toggleSection(key: string) {
		openSections[key] = !openSections[key];
	}

	// ── Lifecycle ───────────────────────────────────────────────────

	onMount(async () => {
		if (!browser) return;
		await startSync();
		loadPgliteStats();
		loadApiStats();
	});

	// Re-run PGLite queries after initial sync completes
	$: if (!$syncStatus.syncing && $syncStatus.recordCount > 0 && pgliteLoading) {
		loadPgliteStats();
	}

	async function loadPgliteStats() {
		try {
			const pg = await getPglite();

			// Section 1: Data Completeness
			const [completenessRes, familyRes, makingRes, liveRes] = await Promise.all([
				pg.query<{ total: number; null_family: number; null_title_en: number }>(`
					SELECT COUNT(*)::int AS total,
					       COUNT(*) FILTER (WHERE family IS NULL)::int AS null_family,
					       COUNT(*) FILTER (WHERE title_en IS NULL)::int AS null_title_en
					FROM uk_lrt
				`),
				pg.query<{ family: string; count: number }>(`
					SELECT COALESCE(family, '(null)') AS family, COUNT(*)::int AS count
					FROM uk_lrt GROUP BY family ORDER BY count DESC LIMIT 30
				`),
				pg.query<{ label: string; count: number }>(`
					SELECT COALESCE(making_classification, '(unclassified)') AS label, COUNT(*)::int AS count
					FROM uk_lrt GROUP BY making_classification ORDER BY count DESC
				`),
				pg.query<{ label: string; count: number }>(`
					SELECT COALESCE(live, '(null)') AS label, COUNT(*)::int AS count
					FROM uk_lrt GROUP BY live ORDER BY count DESC
				`)
			]);

			const c = completenessRes.rows[0];
			totalRecords = c?.total ?? 0;
			nullFamily = c?.null_family ?? 0;
			nullTitleEn = c?.null_title_en ?? 0;
			familyCounts = familyRes.rows;
			makingCounts = makingRes.rows;
			liveCounts = liveRes.rows;

			// Section 2: P2P Taxa/Fitness Population
			const popRes = await pg.query<{
				total: number;
				duty_holder_pop: number;
				rights_holder_pop: number;
				power_holder_pop: number;
				responsibility_holder_pop: number;
				duty_type_pop: number;
				role_pop: number;
				fitness_person_pop: number;
				fitness_process_pop: number;
				fitness_place_pop: number;
				fitness_plant_pop: number;
				fitness_property_pop: number;
				fitness_sector_pop: number;
				fitness_pop: number;
			}>(`
				SELECT
					COUNT(*)::int AS total,
					COUNT(*) FILTER (WHERE duty_holder IS NOT NULL AND duty_holder::text NOT IN ('{}', 'null'))::int AS duty_holder_pop,
					COUNT(*) FILTER (WHERE rights_holder IS NOT NULL AND rights_holder::text NOT IN ('{}', 'null'))::int AS rights_holder_pop,
					COUNT(*) FILTER (WHERE power_holder IS NOT NULL AND power_holder::text NOT IN ('{}', 'null'))::int AS power_holder_pop,
					COUNT(*) FILTER (WHERE responsibility_holder IS NOT NULL AND responsibility_holder::text NOT IN ('{}', 'null'))::int AS responsibility_holder_pop,
					COUNT(*) FILTER (WHERE duty_type IS NOT NULL AND duty_type::text NOT IN ('{}', 'null'))::int AS duty_type_pop,
					COUNT(*) FILTER (WHERE role IS NOT NULL AND array_length(role, 1) > 0)::int AS role_pop,
					COUNT(*) FILTER (WHERE fitness_person IS NOT NULL AND array_length(fitness_person, 1) > 0)::int AS fitness_person_pop,
					COUNT(*) FILTER (WHERE fitness_process IS NOT NULL AND array_length(fitness_process, 1) > 0)::int AS fitness_process_pop,
					COUNT(*) FILTER (WHERE fitness_place IS NOT NULL AND array_length(fitness_place, 1) > 0)::int AS fitness_place_pop,
					COUNT(*) FILTER (WHERE fitness_plant IS NOT NULL AND array_length(fitness_plant, 1) > 0)::int AS fitness_plant_pop,
					COUNT(*) FILTER (WHERE fitness_property IS NOT NULL AND array_length(fitness_property, 1) > 0)::int AS fitness_property_pop,
					COUNT(*) FILTER (WHERE fitness_sector IS NOT NULL AND array_length(fitness_sector, 1) > 0)::int AS fitness_sector_pop,
					COUNT(*) FILTER (WHERE fitness IS NOT NULL AND array_length(fitness, 1) > 0)::int AS fitness_pop
				FROM uk_lrt
			`);

			const p = popRes.rows[0];
			if (p) {
				const t = p.total;
				const fields: Array<[string, number]> = [
					['duty_holder', p.duty_holder_pop],
					['rights_holder', p.rights_holder_pop],
					['power_holder', p.power_holder_pop],
					['responsibility_holder', p.responsibility_holder_pop],
					['duty_type', p.duty_type_pop],
					['role', p.role_pop],
					['fitness_person', p.fitness_person_pop],
					['fitness_process', p.fitness_process_pop],
					['fitness_place', p.fitness_place_pop],
					['fitness_plant', p.fitness_plant_pop],
					['fitness_property', p.fitness_property_pop],
					['fitness_sector', p.fitness_sector_pop],
					['fitness', p.fitness_pop]
				];
				populationStats = fields.map(([field, populated]) => ({
					field,
					populated,
					total: t
				}));
			}

			// Section 3: LAT Coverage
			const latRes = await pg.query<{
				with_lat: number;
				without_lat: number;
				bucket_0: number;
				bucket_1_10: number;
				bucket_11_50: number;
				bucket_50_plus: number;
				making_no_lat: number;
			}>(`
				SELECT
					COUNT(*) FILTER (WHERE lat_count > 0)::int AS with_lat,
					COUNT(*) FILTER (WHERE lat_count = 0)::int AS without_lat,
					COUNT(*) FILTER (WHERE lat_count = 0)::int AS bucket_0,
					COUNT(*) FILTER (WHERE lat_count BETWEEN 1 AND 10)::int AS bucket_1_10,
					COUNT(*) FILTER (WHERE lat_count BETWEEN 11 AND 50)::int AS bucket_11_50,
					COUNT(*) FILTER (WHERE lat_count > 50)::int AS bucket_50_plus,
					COUNT(*) FILTER (WHERE is_making = true AND lat_count = 0)::int AS making_no_lat
				FROM uk_lrt
			`);

			const l = latRes.rows[0];
			if (l) {
				withLat = l.with_lat;
				withoutLat = l.without_lat;
				makingNoLat = l.making_no_lat;
				latBuckets = [
					{ label: '0', count: l.bucket_0 },
					{ label: '1-10', count: l.bucket_1_10 },
					{ label: '11-50', count: l.bucket_11_50 },
					{ label: '50+', count: l.bucket_50_plus }
				];
			}

			pgliteLoading = false;
		} catch (e) {
			pgliteError = e instanceof Error ? e.message : 'Failed to load PGLite stats';
			pgliteLoading = false;
		}
	}

	async function loadApiStats() {
		try {
			const [changes, sessions] = await Promise.all([
				getChangeTrackingStats(),
				getSessionAnalytics()
			]);
			changeStats = changes;
			sessionStats = sessions;
		} catch (e) {
			apiError = e instanceof Error ? e.message : 'Failed to load API stats';
		} finally {
			apiLoading = false;
		}
	}

	// ── Helpers ─────────────────────────────────────────────────────

	function fmt(n: number): string {
		return n.toLocaleString();
	}

	function pct(n: number, total: number): string {
		if (total === 0) return '0';
		return ((n / total) * 100).toFixed(1);
	}

	function pctNum(n: number, total: number): number {
		if (total === 0) return 0;
		return (n / total) * 100;
	}

	function statusClass(status: string): string {
		switch (status) {
			case 'completed':
				return 'bg-green-100 text-green-700';
			case 'failed':
				return 'bg-red-100 text-red-700';
			case 'reviewing':
				return 'bg-blue-100 text-blue-700';
			default:
				return 'bg-amber-100 text-amber-700';
		}
	}

	function sessionTypeClass(type: string): string {
		switch (type) {
			case 'reparse':
				return 'bg-purple-100 text-purple-700';
			case 'lat_parse':
				return 'bg-teal-100 text-teal-700';
			default:
				return 'bg-gray-100 text-gray-700';
		}
	}

	function formatDate(iso: string): string {
		const d = new Date(iso);
		return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
	}

	function fieldLabel(field: string): string {
		return field.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
	}
</script>

<svelte:head>
	<title>Analytics — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<h1 class="text-2xl font-bold text-gray-900">LRT Analytics</h1>

	{#if $syncStatus.syncing}
		<div class="bg-blue-50 text-blue-700 px-4 py-3 rounded-md text-sm">
			Syncing local data... Sections 1-3 will load when sync completes.
		</div>
	{/if}

	<!-- ═══════ Section 1: Data Completeness ═══════ -->
	<section>
		<button
			on:click={() => toggleSection('completeness')}
			class="flex items-center gap-2 text-lg font-semibold text-gray-800 mb-3 hover:text-gray-600"
		>
			<svg
				class="w-4 h-4 transition-transform {openSections.completeness ? 'rotate-90' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
			</svg>
			Data Completeness
			<span class="text-sm font-normal text-gray-400">(PGLite)</span>
		</button>

		{#if openSections.completeness}
			{#if pgliteLoading}
				<div class="text-sm text-gray-500 py-4">Loading...</div>
			{:else if pgliteError}
				<div class="bg-red-50 text-red-700 px-4 py-3 rounded-md text-sm">{pgliteError}</div>
			{:else}
				<!-- KPI Cards -->
				<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Total Records</div>
						<div class="text-2xl font-bold text-gray-900">{fmt(totalRecords)}</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Missing Family</div>
						<div class="text-2xl font-bold text-gray-900">{fmt(nullFamily)}</div>
						<div class="text-xs text-gray-400 mt-0.5">{pct(nullFamily, totalRecords)}%</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Missing Title</div>
						<div class="text-2xl font-bold text-gray-900">{fmt(nullTitleEn)}</div>
						<div class="text-xs text-gray-400 mt-0.5">{pct(nullTitleEn, totalRecords)}%</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Families</div>
						<div class="text-2xl font-bold text-gray-900">{familyCounts.length}</div>
					</div>
				</div>

				<!-- Making Classification + Live Status side by side -->
				<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
					<!-- Making Classification -->
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<h3 class="text-sm font-medium text-gray-700 mb-2">Making Classification</h3>
						<div class="space-y-1.5">
							{#each makingCounts as { label, count }}
								<div class="flex items-center gap-2 text-sm">
									<div
										class="h-2 rounded-full bg-blue-400"
										style="width: {pctNum(count, totalRecords)}%"
									></div>
									<span class="text-gray-600 whitespace-nowrap">{label}</span>
									<span class="text-gray-400 ml-auto">{fmt(count)}</span>
								</div>
							{/each}
						</div>
					</div>

					<!-- Live Status -->
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<h3 class="text-sm font-medium text-gray-700 mb-2">Live Status</h3>
						<div class="space-y-1.5">
							{#each liveCounts as { label, count }}
								<div class="flex items-center gap-2 text-sm">
									<div
										class="h-2 rounded-full bg-green-400"
										style="width: {pctNum(count, totalRecords)}%"
									></div>
									<span class="text-gray-600 whitespace-nowrap truncate max-w-[200px]"
										>{label}</span
									>
									<span class="text-gray-400 ml-auto">{fmt(count)}</span>
								</div>
							{/each}
						</div>
					</div>
				</div>

				<!-- Family Distribution -->
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<h3 class="text-sm font-medium text-gray-700 mb-2">
						Family Distribution (top {familyCounts.length})
					</h3>
					<div class="grid grid-cols-1 md:grid-cols-2 gap-x-6 gap-y-1">
						{#each familyCounts as { family, count }}
							<div class="flex items-center gap-2 text-sm">
								<div
									class="h-2 rounded-full bg-indigo-400 flex-shrink-0"
									style="width: {pctNum(count, totalRecords) * 2}%"
								></div>
								<span class="text-gray-600 truncate max-w-[200px]">{family}</span>
								<span class="text-gray-400 ml-auto whitespace-nowrap">{fmt(count)}</span>
							</div>
						{/each}
					</div>
				</div>
			{/if}
		{/if}
	</section>

	<!-- ═══════ Section 2: P2P Taxa/Fitness Population ═══════ -->
	<section>
		<button
			on:click={() => toggleSection('population')}
			class="flex items-center gap-2 text-lg font-semibold text-gray-800 mb-3 hover:text-gray-600"
		>
			<svg
				class="w-4 h-4 transition-transform {openSections.population ? 'rotate-90' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
			</svg>
			P2P Taxa / Fitness Population
			<span class="text-sm font-normal text-gray-400">(PGLite)</span>
		</button>

		{#if openSections.population}
			{#if pgliteLoading}
				<div class="text-sm text-gray-500 py-4">Loading...</div>
			{:else if pgliteError}
				<div class="bg-red-50 text-red-700 px-4 py-3 rounded-md text-sm">{pgliteError}</div>
			{:else}
				<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th
									class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Field
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Populated
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									%
								</th>
								<th
									class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-1/3"
								>
									Coverage
								</th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-200">
							{#each populationStats as row}
								{@const percentage = pctNum(row.populated, row.total)}
								<tr class="hover:bg-gray-50">
									<td class="px-4 py-2 text-sm text-gray-700 font-mono">{row.field}</td>
									<td class="px-4 py-2 text-sm text-gray-600 text-right">
										{fmt(row.populated)}
										<span class="text-gray-400">/ {fmt(row.total)}</span>
									</td>
									<td class="px-4 py-2 text-sm text-right font-medium {percentage > 20
										? 'text-green-600'
										: percentage > 0
											? 'text-amber-600'
											: 'text-gray-400'}">
										{pct(row.populated, row.total)}%
									</td>
									<td class="px-4 py-2">
										<div class="w-full bg-gray-100 rounded-full h-2">
											<div
												class="h-2 rounded-full {percentage > 20
													? 'bg-green-400'
													: percentage > 0
														? 'bg-amber-400'
														: 'bg-gray-200'}"
												style="width: {Math.max(percentage, 0.5)}%"
											></div>
										</div>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		{/if}
	</section>

	<!-- ═══════ Section 3: LAT Coverage ═══════ -->
	<section>
		<button
			on:click={() => toggleSection('lat')}
			class="flex items-center gap-2 text-lg font-semibold text-gray-800 mb-3 hover:text-gray-600"
		>
			<svg
				class="w-4 h-4 transition-transform {openSections.lat ? 'rotate-90' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
			</svg>
			LAT Coverage
			<span class="text-sm font-normal text-gray-400">(PGLite)</span>
		</button>

		{#if openSections.lat}
			{#if pgliteLoading}
				<div class="text-sm text-gray-500 py-4">Loading...</div>
			{:else if pgliteError}
				<div class="bg-red-50 text-red-700 px-4 py-3 rounded-md text-sm">{pgliteError}</div>
			{:else}
				<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">With LAT</div>
						<div class="text-2xl font-bold text-green-600">{fmt(withLat)}</div>
						<div class="text-xs text-gray-400 mt-0.5">{pct(withLat, totalRecords)}%</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Without LAT</div>
						<div class="text-2xl font-bold text-gray-900">{fmt(withoutLat)}</div>
						<div class="text-xs text-gray-400 mt-0.5">{pct(withoutLat, totalRecords)}%</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Making + No LAT</div>
						<div class="text-2xl font-bold text-amber-600">{fmt(makingNoLat)}</div>
						<div class="text-xs text-gray-400 mt-0.5">Priority gap</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">LAT Count Distribution</div>
						<div class="space-y-1 mt-1">
							{#each latBuckets as { label, count }}
								<div class="flex justify-between text-sm">
									<span class="text-gray-500">{label}</span>
									<span class="text-gray-700 font-medium">{fmt(count)}</span>
								</div>
							{/each}
						</div>
					</div>
				</div>
			{/if}
		{/if}
	</section>

	<!-- ═══════ Section 4: Change Tracking ═══════ -->
	<section>
		<button
			on:click={() => toggleSection('changes')}
			class="flex items-center gap-2 text-lg font-semibold text-gray-800 mb-3 hover:text-gray-600"
		>
			<svg
				class="w-4 h-4 transition-transform {openSections.changes ? 'rotate-90' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
			</svg>
			Change Tracking
			<span class="text-sm font-normal text-gray-400">(API)</span>
		</button>

		{#if openSections.changes}
			{#if apiLoading}
				<div class="text-sm text-gray-500 py-4">Loading...</div>
			{:else if apiError}
				<div class="bg-red-50 text-red-700 px-4 py-3 rounded-md text-sm">{apiError}</div>
			{:else if changeStats}
				<!-- KPIs -->
				<div class="grid grid-cols-2 md:grid-cols-3 gap-4 mb-4">
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Records with Changes</div>
						<div class="text-2xl font-bold text-gray-900">
							{fmt(changeStats.records_with_changes)}
						</div>
						<div class="text-xs text-gray-400 mt-0.5">
							{pct(changeStats.records_with_changes, totalRecords)}% of total
						</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Total Log Entries</div>
						<div class="text-2xl font-bold text-gray-900">{fmt(changeStats.total_entries)}</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Sources</div>
						<div class="space-y-1 mt-1">
							{#each changeStats.by_source as { source, count }}
								<div class="flex justify-between text-sm">
									<span class="text-gray-500">{source}</span>
									<span class="text-gray-700 font-medium">{fmt(count)}</span>
								</div>
							{/each}
						</div>
					</div>
				</div>

				<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
					<!-- Top Changed Fields -->
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<h3 class="text-sm font-medium text-gray-700 mb-3">Top Changed Fields</h3>
						<div class="space-y-1.5">
							{#each changeStats.top_changed_fields as { field, count }, i}
								{@const maxCount = changeStats.top_changed_fields[0]?.count ?? 1}
								<div class="flex items-center gap-2 text-sm">
									<div
										class="h-2 rounded-full bg-orange-400 flex-shrink-0"
										style="width: {(count / maxCount) * 100}%"
									></div>
									<span class="text-gray-600 truncate max-w-[180px] font-mono text-xs"
										>{field}</span
									>
									<span class="text-gray-400 ml-auto">{fmt(count)}</span>
								</div>
							{/each}
						</div>
					</div>

					<!-- Changed By -->
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<h3 class="text-sm font-medium text-gray-700 mb-3">Changed By</h3>
						<div class="space-y-1.5">
							{#each changeStats.by_changed_by as { changed_by, count }}
								{@const maxCount = changeStats.by_changed_by[0]?.count ?? 1}
								<div class="flex items-center gap-2 text-sm">
									<div
										class="h-2 rounded-full bg-violet-400 flex-shrink-0"
										style="width: {(count / maxCount) * 100}%"
									></div>
									<span class="text-gray-600 font-mono text-xs">{changed_by}</span>
									<span class="text-gray-400 ml-auto">{fmt(count)}</span>
								</div>
							{/each}
						</div>
					</div>
				</div>

				<!-- Timeline -->
				{#if changeStats.timeline.length > 0}
					{@const maxTimelineCount = Math.max(...changeStats.timeline.map((t) => t.count))}
					<div class="bg-white rounded-lg border border-gray-200 p-4 mt-4">
						<h3 class="text-sm font-medium text-gray-700 mb-3">
							Change Timeline (last 90 days)
						</h3>
						<div class="flex items-end gap-px h-24">
							{#each changeStats.timeline.slice().reverse() as { date, count }}
								<div
									class="flex-1 bg-blue-400 rounded-t hover:bg-blue-500 relative group"
									style="height: {(count / maxTimelineCount) * 100}%"
									title="{date}: {count} changes"
								>
									<div
										class="hidden group-hover:block absolute bottom-full mb-1 left-1/2 -translate-x-1/2 bg-gray-800 text-white text-xs rounded px-2 py-1 whitespace-nowrap z-10"
									>
										{date}: {count}
									</div>
								</div>
							{/each}
						</div>
						<div class="flex justify-between text-xs text-gray-400 mt-1">
							<span>{changeStats.timeline[changeStats.timeline.length - 1]?.date}</span>
							<span>{changeStats.timeline[0]?.date}</span>
						</div>
					</div>
				{/if}
			{/if}
		{/if}
	</section>

	<!-- ═══════ Section 5: Session Analytics ═══════ -->
	<section>
		<button
			on:click={() => toggleSection('sessions')}
			class="flex items-center gap-2 text-lg font-semibold text-gray-800 mb-3 hover:text-gray-600"
		>
			<svg
				class="w-4 h-4 transition-transform {openSections.sessions ? 'rotate-90' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
			</svg>
			Session Analytics
			<span class="text-sm font-normal text-gray-400">(API)</span>
		</button>

		{#if openSections.sessions}
			{#if apiLoading}
				<div class="text-sm text-gray-500 py-4">Loading...</div>
			{:else if apiError}
				<div class="bg-red-50 text-red-700 px-4 py-3 rounded-md text-sm">{apiError}</div>
			{:else if sessionStats}
				<!-- Totals -->
				<div class="grid grid-cols-3 gap-4 mb-4">
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Total Sessions</div>
						<div class="text-2xl font-bold text-gray-900">
							{fmt(sessionStats.totals.total_sessions)}
						</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Records Processed</div>
						<div class="text-2xl font-bold text-gray-900">
							{fmt(sessionStats.totals.total_records_processed)}
						</div>
					</div>
					<div class="bg-white rounded-lg border border-gray-200 p-4">
						<div class="text-sm text-gray-500">Records Persisted</div>
						<div class="text-2xl font-bold text-gray-900">
							{fmt(sessionStats.totals.total_persisted)}
						</div>
					</div>
				</div>

				<!-- Summary by Type/Status -->
				{#if sessionStats.summary.length > 0}
					<div class="bg-white rounded-lg border border-gray-200 overflow-hidden mb-4">
						<h3 class="text-sm font-medium text-gray-700 px-4 py-3 bg-gray-50 border-b">
							Summary by Type / Status
						</h3>
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									<th
										class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Type</th
									>
									<th
										class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Status</th
									>
									<th
										class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Sessions</th
									>
									<th
										class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Group 1</th
									>
									<th
										class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Persisted</th
									>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-200">
								{#each sessionStats.summary as row}
									<tr class="hover:bg-gray-50">
										<td class="px-4 py-2">
											<span
												class="inline-block px-2 py-0.5 rounded text-xs font-medium {sessionTypeClass(
													row.session_type
												)}"
											>
												{row.session_type}
											</span>
										</td>
										<td class="px-4 py-2">
											<span
												class="inline-block px-2 py-0.5 rounded text-xs font-medium {statusClass(
													row.status
												)}"
											>
												{row.status}
											</span>
										</td>
										<td class="px-4 py-2 text-sm text-gray-600 text-right">
											{row.count}
										</td>
										<td class="px-4 py-2 text-sm text-gray-600 text-right">
											{fmt(row.total_group1)}
										</td>
										<td class="px-4 py-2 text-sm text-gray-600 text-right">
											{fmt(row.total_persisted)}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}

				<!-- Recent Sessions -->
				{#if sessionStats.recent.length > 0}
					<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
						<h3 class="text-sm font-medium text-gray-700 px-4 py-3 bg-gray-50 border-b">
							Recent Sessions (last 20)
						</h3>
						<div class="overflow-x-auto">
							<table class="min-w-full divide-y divide-gray-200">
								<thead class="bg-gray-50">
									<tr>
										<th
											class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
											>Session</th
										>
										<th
											class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
											>Type</th
										>
										<th
											class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
											>Status</th
										>
										<th
											class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
											>G1</th
										>
										<th
											class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
											>Persisted</th
										>
										<th
											class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
											>Created</th
										>
									</tr>
								</thead>
								<tbody class="divide-y divide-gray-200">
									{#each sessionStats.recent as session}
										<tr class="hover:bg-gray-50">
											<td class="px-4 py-2 text-sm text-gray-700 font-mono text-xs">
												{session.session_id}
											</td>
											<td class="px-4 py-2">
												<span
													class="inline-block px-2 py-0.5 rounded text-xs font-medium {sessionTypeClass(
														session.session_type
													)}"
												>
													{session.session_type}
												</span>
											</td>
											<td class="px-4 py-2">
												<span
													class="inline-block px-2 py-0.5 rounded text-xs font-medium {statusClass(
														session.status
													)}"
												>
													{session.status}
												</span>
											</td>
											<td class="px-4 py-2 text-sm text-gray-600 text-right">
												{session.group1_count ?? '—'}
											</td>
											<td class="px-4 py-2 text-sm text-gray-600 text-right">
												{session.persisted_count ?? '—'}
											</td>
											<td class="px-4 py-2 text-sm text-gray-500 text-right">
												{formatDate(session.inserted_at)}
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
	</section>
</div>
