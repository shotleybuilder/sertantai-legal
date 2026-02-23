<script lang="ts">
	import { onMount } from 'svelte';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	interface DashboardData {
		lrt: { families: number; years: number; yearRange: string };
		lat: { rows: number; laws: number; annotations: number; laws_with_annotations: number };
		sessions: { total: number; recent: RecentSession[] };
	}

	interface RecentSession {
		session_id: string;
		status: string;
		year: number;
		month: number;
		day_from: number;
		day_to: number;
		total_fetched: number;
		persisted_count: number;
		inserted_at: string;
	}

	let data: DashboardData | null = null;
	let loading = true;
	let error = '';

	onMount(async () => {
		try {
			const [filtersRes, latRes, sessionsRes] = await Promise.all([
				fetch(`${API_URL}/api/uk-lrt/filters`, { credentials: 'include' }),
				fetch(`${API_URL}/api/lat/stats`, { credentials: 'include' }),
				fetch(`${API_URL}/api/sessions`, { credentials: 'include' })
			]);

			// LRT filters: families + years
			const filtersData = filtersRes.ok
				? await filtersRes.json()
				: { families: [], years: [] };
			const years: number[] = filtersData.years ?? [];
			const yearRange =
				years.length > 0 ? `${years[years.length - 1]}–${years[0]}` : '—';

			// LAT stats
			const latData = latRes.ok ? await latRes.json() : null;

			// Sessions
			const sessionsData = sessionsRes.ok ? await sessionsRes.json() : { sessions: [] };
			const sessions: RecentSession[] = sessionsData.sessions ?? [];

			data = {
				lrt: {
					families: filtersData.families?.length ?? 0,
					years: years.length,
					yearRange
				},
				lat: {
					rows: latData?.total_lat_rows ?? 0,
					laws: latData?.laws_with_lat ?? 0,
					annotations: latData?.total_annotations ?? 0,
					laws_with_annotations: latData?.laws_with_annotations ?? 0
				},
				sessions: {
					total: sessions.length,
					recent: sessions.slice(0, 5)
				}
			};
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load dashboard';
		} finally {
			loading = false;
		}
	});

	function formatNumber(n: number): string {
		return n.toLocaleString();
	}

	function formatDate(iso: string): string {
		const d = new Date(iso);
		return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
	}

	function statusClass(status: string): string {
		switch (status) {
			case 'completed':
				return 'bg-green-100 text-green-700';
			case 'failed':
				return 'bg-red-100 text-red-700';
			default:
				return 'bg-amber-100 text-amber-700';
		}
	}
</script>

<svelte:head>
	<title>Admin Dashboard — SertantAI Legal</title>
</svelte:head>

<div class="space-y-8">
	<h1 class="text-2xl font-bold text-gray-900">Admin Dashboard</h1>

	{#if loading}
		<div class="text-center py-12 text-gray-500">Loading dashboard...</div>
	{:else if error}
		<div class="bg-red-50 text-red-700 px-4 py-3 rounded-md">{error}</div>
	{:else if data}
		<!-- LRT Section -->
		<section>
			<div class="flex items-center justify-between mb-3">
				<h2 class="text-lg font-semibold text-gray-800">Legal Register (LRT)</h2>
				<a href="/admin/lrt" class="text-sm text-blue-600 hover:text-blue-800">View all &rarr;</a>
			</div>
			<div class="grid grid-cols-2 md:grid-cols-3 gap-4">
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Families</div>
					<div class="text-2xl font-bold text-gray-900">{formatNumber(data.lrt.families)}</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Year Range</div>
					<div class="text-2xl font-bold text-gray-900">{data.lrt.yearRange}</div>
					<div class="text-xs text-gray-400 mt-0.5">{data.lrt.years} distinct years</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">ElectricSQL Sync</div>
					<div class="text-sm font-medium text-green-600 mt-1">Enabled</div>
				</div>
			</div>
		</section>

		<!-- LAT Section -->
		<section>
			<div class="flex items-center justify-between mb-3">
				<h2 class="text-lg font-semibold text-gray-800">Legal Articles (LAT)</h2>
				<a href="/admin/lat" class="text-sm text-blue-600 hover:text-blue-800">View all &rarr;</a>
			</div>
			<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">LAT Rows</div>
					<div class="text-2xl font-bold text-gray-900">{formatNumber(data.lat.rows)}</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Laws Parsed</div>
					<div class="text-2xl font-bold text-gray-900">{formatNumber(data.lat.laws)}</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Annotations</div>
					<div class="text-2xl font-bold text-gray-900">{formatNumber(data.lat.annotations)}</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Laws with Annotations</div>
					<div class="text-2xl font-bold text-gray-900">
						{formatNumber(data.lat.laws_with_annotations)}
					</div>
				</div>
			</div>
		</section>

		<!-- Scraper Section -->
		<section>
			<div class="flex items-center justify-between mb-3">
				<h2 class="text-lg font-semibold text-gray-800">Scraper Sessions</h2>
				<div class="flex gap-3">
					<a href="/admin/scrape" class="text-sm text-blue-600 hover:text-blue-800"
						>New scrape &rarr;</a
					>
					<a href="/admin/scrape/sessions" class="text-sm text-blue-600 hover:text-blue-800"
						>All sessions &rarr;</a
					>
				</div>
			</div>

			{#if data.sessions.recent.length > 0}
				<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th
									class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Date Range
								</th>
								<th
									class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Status
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Fetched
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Persisted
								</th>
								<th
									class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
								>
									Created
								</th>
								<th class="px-4 py-2"></th>
							</tr>
						</thead>
						<tbody class="divide-y divide-gray-200">
							{#each data.sessions.recent as session (session.session_id)}
								<tr class="hover:bg-gray-50">
									<td class="px-4 py-2 text-sm text-gray-700">
										{session.year}-{String(session.month).padStart(2, '0')}-{String(
											session.day_from
										).padStart(2, '0')}
										to
										{String(session.day_to).padStart(2, '0')}
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
										{session.total_fetched}
									</td>
									<td class="px-4 py-2 text-sm text-gray-600 text-right">
										{session.persisted_count}
									</td>
									<td class="px-4 py-2 text-sm text-gray-500 text-right">
										{formatDate(session.inserted_at)}
									</td>
									<td class="px-4 py-2 text-right">
										<a
											href="/admin/scrape/sessions/{session.session_id}"
											class="text-sm text-blue-600 hover:text-blue-800"
										>
											View
										</a>
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div
					class="bg-white rounded-lg border border-gray-200 p-8 text-center text-sm text-gray-500"
				>
					No scrape sessions yet.
					<a href="/admin/scrape" class="text-blue-600 hover:text-blue-800">Start one &rarr;</a>
				</div>
			{/if}
		</section>

		<!-- Quick Links -->
		<section>
			<h2 class="text-lg font-semibold text-gray-800 mb-3">Quick Links</h2>
			<div class="grid grid-cols-2 md:grid-cols-4 gap-3">
				<a
					href="/admin/lrt"
					class="bg-white rounded-lg border border-gray-200 p-4 hover:border-blue-300 hover:bg-blue-50 transition-colors"
				>
					<div class="text-sm font-medium text-gray-900">LRT Data</div>
					<div class="text-xs text-gray-500 mt-1">Browse & edit UK legal register</div>
				</a>
				<a
					href="/admin/lat"
					class="bg-white rounded-lg border border-gray-200 p-4 hover:border-blue-300 hover:bg-blue-50 transition-colors"
				>
					<div class="text-sm font-medium text-gray-900">LAT Data</div>
					<div class="text-xs text-gray-500 mt-1">Legal articles & annotations</div>
				</a>
				<a
					href="/admin/scrape"
					class="bg-white rounded-lg border border-gray-200 p-4 hover:border-blue-300 hover:bg-blue-50 transition-colors"
				>
					<div class="text-sm font-medium text-gray-900">New Scrape</div>
					<div class="text-xs text-gray-500 mt-1">Scrape legislation.gov.uk</div>
				</a>
				<a
					href="/admin/scrape/cascade"
					class="bg-white rounded-lg border border-gray-200 p-4 hover:border-blue-300 hover:bg-blue-50 transition-colors"
				>
					<div class="text-sm font-medium text-gray-900">Cascade</div>
					<div class="text-xs text-gray-500 mt-1">Manage affected law updates</div>
				</a>
			</div>
		</section>
	{/if}
</div>
