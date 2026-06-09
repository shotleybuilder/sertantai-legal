<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	let db: PGLiteWithExtensions | null = null;
	let ready = false;

	// Stats
	let totalMaking = 0;
	let registerCount = 0;
	let excludedCount = 0;
	let unreviewedCount = 0;

	interface FamilyStat {
		family: string;
		total: number;
		in_register: number;
		duty_count: number;
	}
	let familyStats: FamilyStat[] = [];

	interface TopLaw {
		name: string;
		title: string;
		family: string;
		duties: number;
	}
	let topLaws: TopLaw[] = [];

	let euCount = 0;
	let ukCount = 0;
	let euDuties = 0;
	let ukDuties = 0;

	let fitnessCount = 0;
	let noFitnessCount = 0;

	// Server-side compliance metrics (from webhook data)
	interface ComplianceMetrics {
		compliant: number;
		non_compliant: number;
		partially_compliant: number;
		not_assessed: number;
		actions_open: number;
		actions_completed: number;
		last_assessment_at: string | null;
		last_synced_at: string | null;
	}
	let complianceMetrics: ComplianceMetrics | null = null;

	// Change summary (from change detection)
	interface ChangeSummary {
		total_pending: number;
		overdue: number;
		by_materiality: { major: number; moderate: number; minor: number; informational: number };
	}
	let changeSummary: ChangeSummary | null = null;

	async function loadStats() {
		if (!db) return;

		// Overview counts
		const making = await db.query<{ count: string }>(
			`SELECT COUNT(*)::text as count FROM laws WHERE is_making = true AND (live IS NULL OR live NOT LIKE '%Revoked%')`
		);
		totalMaking = parseInt(making.rows[0]?.count ?? '0', 10);

		const reg = await db.query<{ count: string }>(
			`SELECT COUNT(*)::text as count FROM org_applicabilities WHERE status = 'yes'`
		);
		registerCount = parseInt(reg.rows[0]?.count ?? '0', 10);

		const exc = await db.query<{ count: string }>(
			`SELECT COUNT(*)::text as count FROM org_applicabilities WHERE status = 'excluded'`
		);
		excludedCount = parseInt(exc.rows[0]?.count ?? '0', 10);

		unreviewedCount = totalMaking - registerCount - excludedCount;
		if (unreviewedCount < 0) unreviewedCount = 0;

		// Family distribution
		const families = await db.query<{
			family: string;
			total: string;
			in_register: string;
			duty_count: string;
		}>(
			`SELECT l.family,
			        COUNT(*)::text as total,
			        SUM(CASE WHEN oa.status = 'yes' THEN 1 ELSE 0 END)::text as in_register,
			        '0' as duty_count
			 FROM laws l
			 LEFT JOIN org_applicabilities oa ON oa.law_name = l.name
			 WHERE l.is_making = true
			   AND (l.live IS NULL OR l.live NOT LIKE '%Revoked%')
			   AND l.family IS NOT NULL
			 GROUP BY l.family
			 ORDER BY COUNT(*) DESC`
		);
		familyStats = families.rows.map((r) => ({
			family: r.family,
			total: parseInt(r.total),
			in_register: parseInt(r.in_register),
			duty_count: parseInt(r.duty_count)
		}));

		// EU vs UK split (register only)
		const jurisdiction = await db.query<{
			jurisdiction: string;
			count: string;
		}>(
			`SELECT CASE WHEN l.type_code IN ('eur', 'eudr', 'eudn') THEN 'EU' ELSE 'UK' END as jurisdiction,
			        COUNT(*)::text as count
			 FROM laws l
			 INNER JOIN org_applicabilities oa ON oa.law_name = l.name
			 WHERE oa.status = 'yes'
			 GROUP BY jurisdiction`
		);
		for (const row of jurisdiction.rows) {
			if (row.jurisdiction === 'EU') euCount = parseInt(row.count);
			else ukCount = parseInt(row.count);
		}

		// Fitness coverage (register only)
		const fitness = await db.query<{ has: string; count: string }>(
			`SELECT CASE WHEN l.has_fitness = 'true' THEN 'yes' ELSE 'no' END as has,
			        COUNT(*)::text as count
			 FROM laws l
			 INNER JOIN org_applicabilities oa ON oa.law_name = l.name
			 WHERE oa.status = 'yes'
			 GROUP BY has`
		);
		for (const row of fitness.rows) {
			if (row.has === 'yes') fitnessCount = parseInt(row.count);
			else noFitnessCount = parseInt(row.count);
		}

		ready = true;
	}

	function pct(n: number, total: number): string {
		if (total === 0) return '0';
		return Math.round((n / total) * 100).toString();
	}

	async function loadServerMetrics() {
		try {
			const [metricsRes, changesRes] = await Promise.all([
				authFetch(`${API_URL}/api/screening/compliance-metrics`),
				authFetch(`${API_URL}/api/screening/changes/summary`)
			]);

			if (metricsRes.ok) complianceMetrics = await metricsRes.json();
			if (changesRes.ok) changeSummary = await changesRes.json();
		} catch {
			// Server metrics unavailable — dashboard still shows PGLite stats
		}
	}

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await Promise.all([loadStats(), loadServerMetrics()]);
		}
	});
</script>

<svelte:head>
	<title>Compliance Stats - SertantAI</title>
</svelte:head>

<div class="overflow-auto px-6 py-6 space-y-6 max-w-5xl mx-auto">
	<h1 class="text-2xl font-bold text-gray-900">Compliance Dashboard</h1>

	{#if !ready}
		<div class="flex justify-center py-12">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
		</div>
	{:else}
		<!-- Overview Cards -->
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Total Making Laws</div>
				<div class="text-3xl font-bold text-gray-900">{totalMaking}</div>
			</div>
			<div class="bg-white rounded-lg border border-emerald-200 p-4">
				<div class="text-sm text-gray-500">In My Register</div>
				<div class="text-3xl font-bold text-emerald-600">{registerCount}</div>
				<div class="text-xs text-gray-400 mt-1">{pct(registerCount, totalMaking)}% of total</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Excluded</div>
				<div class="text-3xl font-bold text-gray-400">{excludedCount}</div>
			</div>
			<div class="bg-white rounded-lg border border-amber-200 p-4">
				<div class="text-sm text-gray-500">Unreviewed</div>
				<div class="text-3xl font-bold text-amber-600">{unreviewedCount}</div>
				<div class="text-xs text-gray-400 mt-1">{pct(unreviewedCount, totalMaking)}% remaining</div>
			</div>
		</div>

		<!-- Progress Bar -->
		<div class="bg-white rounded-lg border border-gray-200 p-4">
			<div class="flex items-center justify-between mb-2">
				<span class="text-sm font-medium text-gray-700">Screening Progress</span>
				<span class="text-sm text-gray-500"
					>{registerCount + excludedCount} of {totalMaking} reviewed</span
				>
			</div>
			<div class="w-full h-3 bg-gray-200 rounded-full overflow-hidden flex">
				<div
					class="h-full bg-emerald-500 transition-all duration-300"
					style="width: {pct(registerCount, totalMaking)}%"
				></div>
				<div
					class="h-full bg-gray-400 transition-all duration-300"
					style="width: {pct(excludedCount, totalMaking)}%"
				></div>
			</div>
			<div class="flex gap-4 mt-2 text-xs text-gray-500">
				<span class="flex items-center gap-1">
					<span class="w-2 h-2 rounded-full bg-emerald-500"></span> In Register
				</span>
				<span class="flex items-center gap-1">
					<span class="w-2 h-2 rounded-full bg-gray-400"></span> Excluded
				</span>
				<span class="flex items-center gap-1">
					<span class="w-2 h-2 rounded-full bg-gray-200"></span> Unreviewed
				</span>
			</div>
		</div>

		<!-- Two-column layout -->
		<div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
			<!-- Family Distribution -->
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<h2 class="text-sm font-semibold text-gray-700 mb-3">Family Distribution</h2>
				<div class="space-y-2 max-h-96 overflow-auto">
					{#each familyStats as fam}
						<div class="flex items-center gap-2">
							<div class="flex-1 min-w-0">
								<div class="text-xs text-gray-700 truncate" title={fam.family}>
									{fam.family}
								</div>
								<div class="w-full h-2 bg-gray-100 rounded-full overflow-hidden flex mt-0.5">
									<div
										class="h-full bg-emerald-500 rounded-full"
										style="width: {pct(fam.in_register, fam.total)}%"
									></div>
								</div>
							</div>
							<div class="text-xs text-gray-500 whitespace-nowrap">
								{fam.in_register}/{fam.total}
							</div>
						</div>
					{/each}
				</div>
			</div>

			<!-- Jurisdiction Split + Fitness -->
			<div class="space-y-6">
				<!-- EU vs UK -->
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<h2 class="text-sm font-semibold text-gray-700 mb-3">Jurisdiction (My Register)</h2>
					<div class="flex gap-8">
						<div class="text-center">
							<div class="text-2xl font-bold text-blue-600">{ukCount}</div>
							<div class="text-xs text-gray-500">UK Domestic</div>
						</div>
						<div class="text-center">
							<div class="text-2xl font-bold text-indigo-600">{euCount}</div>
							<div class="text-xs text-gray-500">EU Retained</div>
						</div>
					</div>
					{#if ukCount + euCount > 0}
						<div class="w-full h-3 bg-gray-100 rounded-full overflow-hidden flex mt-3">
							<div
								class="h-full bg-blue-500"
								style="width: {pct(ukCount, ukCount + euCount)}%"
							></div>
							<div
								class="h-full bg-indigo-500"
								style="width: {pct(euCount, ukCount + euCount)}%"
							></div>
						</div>
					{/if}
				</div>

				<!-- Fitness Coverage -->
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<h2 class="text-sm font-semibold text-gray-700 mb-3">Fitness Coverage (My Register)</h2>
					<div class="flex gap-8">
						<div class="text-center">
							<div class="text-2xl font-bold text-purple-600">{fitnessCount}</div>
							<div class="text-xs text-gray-500">With fitness data</div>
						</div>
						<div class="text-center">
							<div class="text-2xl font-bold text-gray-400">{noFitnessCount}</div>
							<div class="text-xs text-gray-500">Without</div>
						</div>
					</div>
					{#if fitnessCount + noFitnessCount > 0}
						<div class="w-full h-3 bg-gray-100 rounded-full overflow-hidden flex mt-3">
							<div
								class="h-full bg-purple-500"
								style="width: {pct(fitnessCount, fitnessCount + noFitnessCount)}%"
							></div>
						</div>
						<div class="text-xs text-gray-500 mt-1">
							{pct(fitnessCount, fitnessCount + noFitnessCount)}% of register laws have fitness
							signals for screening
						</div>
					{/if}
				</div>
			</div>
		</div>

		<!-- Compliance Assessment Posture (server-side metrics) -->
		{#if complianceMetrics}
			{@const total =
				complianceMetrics.compliant +
				complianceMetrics.non_compliant +
				complianceMetrics.partially_compliant}
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<h2 class="text-sm font-semibold text-gray-700 mb-3">Compliance Assessment Posture</h2>
				{#if total > 0}
					<div class="grid grid-cols-3 gap-4 mb-4">
						<div class="text-center">
							<div class="text-2xl font-bold text-green-600">
								{complianceMetrics.compliant}
							</div>
							<div class="text-xs text-gray-500">Compliant</div>
						</div>
						<div class="text-center">
							<div class="text-2xl font-bold text-amber-600">
								{complianceMetrics.partially_compliant}
							</div>
							<div class="text-xs text-gray-500">Partial</div>
						</div>
						<div class="text-center">
							<div class="text-2xl font-bold text-red-600">
								{complianceMetrics.non_compliant}
							</div>
							<div class="text-xs text-gray-500">Non-Compliant</div>
						</div>
					</div>
					<div class="w-full h-3 bg-gray-100 rounded-full overflow-hidden flex">
						<div
							class="h-full bg-green-500"
							style="width: {pct(complianceMetrics.compliant, total)}%"
						></div>
						<div
							class="h-full bg-amber-400"
							style="width: {pct(complianceMetrics.partially_compliant, total)}%"
						></div>
						<div
							class="h-full bg-red-500"
							style="width: {pct(complianceMetrics.non_compliant, total)}%"
						></div>
					</div>
					<div class="text-xs text-gray-500 mt-2">
						{pct(complianceMetrics.compliant, total)}% compliant across {total} assessed laws
					</div>
				{:else}
					<div class="text-sm text-gray-400">
						No assessment data yet. Assessment metrics appear once compliance status is tracked in
						your workspace.
					</div>
				{/if}
			</div>
		{/if}

		<!-- Action Status (server-side metrics) -->
		{#if complianceMetrics && (complianceMetrics.actions_open > 0 || complianceMetrics.actions_completed > 0)}
			{@const totalActions = complianceMetrics.actions_open + complianceMetrics.actions_completed}
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<h2 class="text-sm font-semibold text-gray-700 mb-3">Action Status</h2>
				<div class="flex gap-8">
					<div class="text-center">
						<div class="text-2xl font-bold text-amber-600">
							{complianceMetrics.actions_open}
						</div>
						<div class="text-xs text-gray-500">Open</div>
					</div>
					<div class="text-center">
						<div class="text-2xl font-bold text-green-600">
							{complianceMetrics.actions_completed}
						</div>
						<div class="text-xs text-gray-500">Completed</div>
					</div>
				</div>
				{#if totalActions > 0}
					<div class="w-full h-3 bg-gray-100 rounded-full overflow-hidden flex mt-3">
						<div
							class="h-full bg-green-500"
							style="width: {pct(complianceMetrics.actions_completed, totalActions)}%"
						></div>
						<div
							class="h-full bg-amber-400"
							style="width: {pct(complianceMetrics.actions_open, totalActions)}%"
						></div>
					</div>
				{/if}
			</div>
		{/if}

		<!-- Pending Changes (from change detection) -->
		{#if changeSummary && changeSummary.total_pending > 0}
			<div
				class="bg-white rounded-lg border p-4
					{changeSummary.overdue > 0 ? 'border-red-300' : 'border-amber-200'}"
			>
				<h2 class="text-sm font-semibold text-gray-700 mb-2">Pending Legal Changes</h2>
				<div class="flex gap-4 text-sm">
					{#if changeSummary.by_materiality.major > 0}
						<span class="text-red-600 font-medium">
							{changeSummary.by_materiality.major} major
						</span>
					{/if}
					{#if changeSummary.by_materiality.moderate > 0}
						<span class="text-amber-600 font-medium">
							{changeSummary.by_materiality.moderate} moderate
						</span>
					{/if}
					{#if changeSummary.by_materiality.minor > 0}
						<span class="text-blue-600">
							{changeSummary.by_materiality.minor} minor
						</span>
					{/if}
					{#if changeSummary.by_materiality.informational > 0}
						<span class="text-gray-500">
							{changeSummary.by_materiality.informational} info
						</span>
					{/if}
				</div>
				{#if changeSummary.overdue > 0}
					<div class="text-xs text-red-600 mt-1 font-medium">
						{changeSummary.overdue} overdue for review
					</div>
				{/if}
				<a href="/app/changes" class="text-xs text-emerald-600 hover:underline mt-2 inline-block">
					Review changes
				</a>
			</div>
		{/if}
	{/if}
</div>
