<script lang="ts">
	import { onMount } from 'svelte';
	import { authFetch } from '$lib/api/client';
	import { goto } from '$app/navigation';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	interface FamilyStats {
		family: string;
		total_defs: number;
		cross_refs: number;
		linked: number;
		citation_resolved: number;
		effective: number;
		effective_pct: number;
		unlinked: number;
		citation_defs: number;
		substantive_defs: number;
	}

	interface Totals {
		total_defs: number;
		cross_refs: number;
		linked: number;
		citation_defs: number;
	}

	let families: FamilyStats[] = [];
	let totals: Totals | null = null;
	let loading = true;
	let error = '';

	// Sort state
	let sortCol: keyof FamilyStats = 'family';
	let sortDir: 'asc' | 'desc' = 'asc';

	// Filter
	let familyFilter: 'all' | 'safety' | 'environment' = 'all';

	// Column definitions for the stats table
	const columns: { key: keyof FamilyStats; label: string; align: string }[] = [
		{ key: 'family', label: 'Family', align: 'left' },
		{ key: 'total_defs', label: 'Defs', align: 'right' },
		{ key: 'cross_refs', label: 'Cross-Refs', align: 'right' },
		{ key: 'linked', label: 'Linked', align: 'right' },
		{ key: 'citation_resolved', label: 'Cit. Resolved', align: 'right' },
		{ key: 'effective_pct', label: 'Effective %', align: 'right' },
		{ key: 'unlinked', label: 'Unlinked', align: 'right' }
	];

	$: filteredFamilies = families.filter((f) => {
		if (familyFilter === 'safety') return f.family.startsWith('\u{1F499}');
		if (familyFilter === 'environment') return f.family.startsWith('\u{1F49A}');
		return true;
	});

	$: sortedFamilies = [...filteredFamilies].sort((a, b) => {
		const av = a[sortCol];
		const bv = b[sortCol];
		if (typeof av === 'string' && typeof bv === 'string') {
			return sortDir === 'asc' ? av.localeCompare(bv) : bv.localeCompare(av);
		}
		if (typeof av === 'number' && typeof bv === 'number') {
			return sortDir === 'asc' ? av - bv : bv - av;
		}
		return 0;
	});

	// Computed totals for filtered view
	$: filteredTotals = {
		total_defs: filteredFamilies.reduce((s, f) => s + f.total_defs, 0),
		cross_refs: filteredFamilies.reduce((s, f) => s + f.cross_refs, 0),
		linked: filteredFamilies.reduce((s, f) => s + f.linked, 0),
		effective: filteredFamilies.reduce((s, f) => s + f.effective, 0)
	};

	$: overallEffectivePct =
		filteredTotals.cross_refs > 0
			? Math.round((1000 * filteredTotals.effective) / filteredTotals.cross_refs) / 10
			: 100;

	function toggleSort(col: keyof FamilyStats) {
		if (sortCol === col) {
			sortDir = sortDir === 'asc' ? 'desc' : 'asc';
		} else {
			sortCol = col;
			sortDir = col === 'family' ? 'asc' : 'desc';
		}
	}

	function pctClass(pct: number): string {
		if (pct >= 90) return 'text-green-700 bg-green-50';
		if (pct >= 80) return 'text-amber-700 bg-amber-50';
		return 'text-red-700 bg-red-50';
	}

	function sortArrow(col: keyof FamilyStats): string {
		if (sortCol !== col) return '';
		return sortDir === 'asc' ? ' \u25B2' : ' \u25BC';
	}

	onMount(async () => {
		try {
			const res = await authFetch(`${API_URL}/api/definitions/admin/stats`);
			if (!res.ok) throw new Error(`Stats API returned ${res.status}`);
			const data = await res.json();
			families = data.families;
			totals = data.totals;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load stats';
		} finally {
			loading = false;
		}
	});
</script>

<svelte:head>
	<title>Definitions Dashboard — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<div class="flex items-center justify-between">
		<h1 class="text-2xl font-bold text-gray-900">Definitions Dashboard</h1>
		<div class="flex items-center gap-2">
			<select
				bind:value={familyFilter}
				class="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
			>
				<option value="all">All Families</option>
				<option value="safety">Safety</option>
				<option value="environment">Environment</option>
			</select>
		</div>
	</div>

	{#if loading}
		<div class="py-12 text-center text-gray-500">Loading definition stats...</div>
	{:else if error}
		<div class="rounded-md bg-red-50 px-4 py-3 text-red-700">{error}</div>
	{:else}
		<!-- Summary Cards -->
		<div class="grid grid-cols-2 gap-4 md:grid-cols-5">
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Total Definitions</div>
				<div class="text-2xl font-bold text-gray-900">
					{filteredTotals.total_defs.toLocaleString()}
				</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Cross-References</div>
				<div class="text-2xl font-bold text-gray-900">
					{filteredTotals.cross_refs.toLocaleString()}
				</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Linked</div>
				<div class="text-2xl font-bold text-gray-900">
					{filteredTotals.linked.toLocaleString()}
				</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Effective Resolved</div>
				<div class="text-2xl font-bold text-gray-900">
					{filteredTotals.effective.toLocaleString()}
				</div>
			</div>
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Effective %</div>
				<div class="text-2xl font-bold {pctClass(overallEffectivePct)}">
					{overallEffectivePct}%
				</div>
			</div>
		</div>

		<!-- Family Stats Table -->
		<div class="overflow-hidden rounded-lg border border-gray-200 bg-white">
			<table class="min-w-full divide-y divide-gray-200">
				<thead class="bg-gray-50">
					<tr>
						{#each columns as col}
							<th
								class="cursor-pointer select-none px-4 py-2 text-xs font-medium uppercase tracking-wider text-gray-500 hover:text-gray-700
									{col.align === 'right' ? 'text-right' : 'text-left'}"
								on:click={() => toggleSort(col.key)}
							>
								{col.label}{sortArrow(col.key)}
							</th>
						{/each}
					</tr>
				</thead>
				<tbody class="divide-y divide-gray-200">
					{#each sortedFamilies as fam (fam.family)}
						<tr
							class="cursor-pointer hover:bg-gray-50"
							on:click={() =>
								goto(`/admin/definitions/browse?family=${encodeURIComponent(fam.family)}`)}
						>
							<td class="whitespace-nowrap px-4 py-2 text-sm font-medium text-gray-900">
								{fam.family}
							</td>
							<td class="whitespace-nowrap px-4 py-2 text-right text-sm text-gray-600">
								{fam.total_defs.toLocaleString()}
							</td>
							<td class="whitespace-nowrap px-4 py-2 text-right text-sm text-gray-600">
								{fam.cross_refs.toLocaleString()}
							</td>
							<td class="whitespace-nowrap px-4 py-2 text-right text-sm text-gray-600">
								{fam.linked.toLocaleString()}
							</td>
							<td class="whitespace-nowrap px-4 py-2 text-right text-sm text-gray-600">
								{fam.citation_resolved.toLocaleString()}
							</td>
							<td class="whitespace-nowrap px-4 py-2 text-right text-sm">
								<span
									class="inline-block rounded px-2 py-0.5 text-xs font-semibold {pctClass(
										fam.effective_pct
									)}"
								>
									{fam.effective_pct}%
								</span>
							</td>
							<td class="whitespace-nowrap px-4 py-2 text-right text-sm text-gray-600">
								{fam.unlinked.toLocaleString()}
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>

		<div class="text-xs text-gray-400">
			{sortedFamilies.length} families shown. Effective % = (linked + citation resolved) / cross-refs.
			Click a row to browse definitions for that family.
		</div>
	{/if}
</div>
