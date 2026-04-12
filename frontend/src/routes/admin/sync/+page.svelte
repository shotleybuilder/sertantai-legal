<script lang="ts">
	import { onMount } from 'svelte';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	interface TableStatus {
		name: string;
		dev: { count: number; max_updated_at: string | null };
		nas: { count: number | null; snapshot_date: string | null };
		watermark: string | null;
		pending_rows: number;
	}

	interface SyncStatus {
		tables: TableStatus[];
		nas_snapshot: { date: string | null; available: boolean };
		last_export: { at: string | null; delta_file: string | null };
	}

	let data: SyncStatus | null = null;
	let loading = true;
	let error = '';

	onMount(() => {
		fetchStatus();
	});

	async function fetchStatus() {
		loading = true;
		error = '';
		try {
			const res = await authFetch(`${API_URL}/api/sync/status`);
			if (!res.ok) throw new Error(`HTTP ${res.status}`);
			data = await res.json();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load sync status';
		} finally {
			loading = false;
		}
	}

	function formatNumber(n: number | null | undefined): string {
		if (n == null) return '—';
		return n.toLocaleString();
	}

	function formatDate(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		return d.toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
	}

	function timeAgo(iso: string | null | undefined): string {
		if (!iso) return '—';
		const d = new Date(iso);
		const now = new Date();
		const diffMs = now.getTime() - d.getTime();
		const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
		const diffHours = Math.floor(diffMs / (1000 * 60 * 60));

		if (diffDays > 0) return `${diffDays}d ago`;
		if (diffHours > 0) return `${diffHours}h ago`;
		return 'just now';
	}

	function nasAgeClass(iso: string | null | undefined): string {
		if (!iso) return 'text-gray-400';
		const d = new Date(iso);
		const diffDays = (new Date().getTime() - d.getTime()) / (1000 * 60 * 60 * 24);
		if (diffDays > 14) return 'text-red-600';
		if (diffDays > 7) return 'text-amber-600';
		return 'text-green-600';
	}

	function tableStatus(t: TableStatus): { label: string; class: string } {
		if (!t.nas.snapshot_date) return { label: 'No NAS', class: 'bg-gray-100 text-gray-600' };
		if (t.pending_rows > 0) return { label: 'Stale', class: 'bg-amber-100 text-amber-700' };
		if (
			t.dev.max_updated_at &&
			t.nas.snapshot_date &&
			new Date(t.dev.max_updated_at) > new Date(t.nas.snapshot_date)
		)
			return { label: 'Stale', class: 'bg-amber-100 text-amber-700' };
		return { label: 'Current', class: 'bg-green-100 text-green-700' };
	}

	function diffClass(dev: number, nas: number | null | undefined): string {
		if (nas == null) return 'text-gray-400';
		const diff = dev - nas;
		if (diff === 0) return 'text-green-600';
		if (diff > 0) return 'text-amber-600';
		return 'text-red-600';
	}

	$: tablesWithPending = data?.tables.filter((t) => t.pending_rows > 0).length ?? 0;
</script>

<svelte:head>
	<title>Data Sync — SertantAI Legal</title>
</svelte:head>

<div class="space-y-8">
	<div class="flex items-center justify-between">
		<h1 class="text-2xl font-bold text-gray-900">Data Sync Pipeline</h1>
		<button
			on:click={fetchStatus}
			disabled={loading}
			class="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
		>
			{loading ? 'Loading...' : 'Refresh'}
		</button>
	</div>

	{#if loading && !data}
		<div class="py-12 text-center text-gray-500">Loading sync status...</div>
	{:else if error}
		<div class="rounded-md bg-red-50 px-4 py-3 text-red-700">{error}</div>
	{:else if data}
		<!-- Summary Cards -->
		<div class="grid grid-cols-2 gap-4 md:grid-cols-3">
			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">NAS Snapshot</div>
				{#if data.nas_snapshot.available}
					<div class="mt-1 text-2xl font-bold {nasAgeClass(data.nas_snapshot.date)}">
						{timeAgo(data.nas_snapshot.date)}
					</div>
					<div class="mt-0.5 text-xs text-gray-400">{formatDate(data.nas_snapshot.date)}</div>
				{:else}
					<div class="mt-1 text-lg font-medium text-gray-400">Unavailable</div>
					<div class="mt-0.5 text-xs text-gray-400">NAS not mounted</div>
				{/if}
			</div>

			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Last Delta Export</div>
				{#if data.last_export.at}
					<div class="mt-1 text-2xl font-bold text-gray-900">
						{timeAgo(data.last_export.at)}
					</div>
					<div class="mt-0.5 text-xs text-gray-400">{data.last_export.delta_file}</div>
				{:else}
					<div class="mt-1 text-lg font-medium text-gray-400">None</div>
					<div class="mt-0.5 text-xs text-gray-400">No exports yet</div>
				{/if}
			</div>

			<div class="rounded-lg border border-gray-200 bg-white p-4">
				<div class="text-sm text-gray-500">Pending Changes</div>
				<div
					class="mt-1 text-2xl font-bold {tablesWithPending > 0
						? 'text-amber-600'
						: 'text-green-600'}"
				>
					{tablesWithPending} / {data.tables.length}
				</div>
				<div class="mt-0.5 text-xs text-gray-400">tables with unexported rows</div>
			</div>
		</div>

		<!-- Per-Table Comparison -->
		<section>
			<h2 class="mb-3 text-lg font-semibold text-gray-800">Table Status</h2>
			<div class="overflow-hidden rounded-lg border border-gray-200 bg-white shadow">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-50">
						<tr>
							<th
								class="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
								>Table</th
							>
							<th
								class="px-4 py-2 text-right text-xs font-medium uppercase tracking-wider text-gray-500"
								>Dev Rows</th
							>
							<th
								class="px-4 py-2 text-right text-xs font-medium uppercase tracking-wider text-gray-500"
								>NAS Rows</th
							>
							<th
								class="px-4 py-2 text-right text-xs font-medium uppercase tracking-wider text-gray-500"
								>Diff</th
							>
							<th
								class="px-4 py-2 text-right text-xs font-medium uppercase tracking-wider text-gray-500"
								>Dev Latest</th
							>
							<th
								class="px-4 py-2 text-right text-xs font-medium uppercase tracking-wider text-gray-500"
								>Pending</th
							>
							<th
								class="px-4 py-2 text-center text-xs font-medium uppercase tracking-wider text-gray-500"
								>Status</th
							>
						</tr>
					</thead>
					<tbody class="divide-y divide-gray-200">
						{#each data.tables as t (t.name)}
							{@const status = tableStatus(t)}
							{@const diff = t.nas.count != null ? t.dev.count - t.nas.count : null}
							<tr class="hover:bg-gray-50">
								<td class="px-4 py-2 text-sm font-medium text-gray-900">{t.name}</td>
								<td class="px-4 py-2 text-right text-sm text-gray-700">
									{formatNumber(t.dev.count)}
								</td>
								<td class="px-4 py-2 text-right text-sm text-gray-700">
									{formatNumber(t.nas.count)}
								</td>
								<td
									class="px-4 py-2 text-right text-sm font-medium {diffClass(
										t.dev.count,
										t.nas.count
									)}"
								>
									{#if diff == null}
										—
									{:else if diff === 0}
										0
									{:else if diff > 0}
										+{formatNumber(diff)}
									{:else}
										{formatNumber(diff)}
									{/if}
								</td>
								<td class="px-4 py-2 text-right text-sm text-gray-500">
									{formatDate(t.dev.max_updated_at)}
								</td>
								<td
									class="px-4 py-2 text-right text-sm font-medium {t.pending_rows > 0
										? 'text-amber-600'
										: 'text-gray-500'}"
								>
									{formatNumber(t.pending_rows)}
								</td>
								<td class="px-4 py-2 text-center">
									<span class="inline-block rounded px-2 py-0.5 text-xs font-medium {status.class}">
										{status.label}
									</span>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
		</section>

		<!-- Promotion Checklist -->
		<section>
			<h2 class="mb-3 text-lg font-semibold text-gray-800">Promotion Checklist</h2>
			<div class="rounded-lg border border-gray-200 bg-white p-5">
				<p class="mb-4 text-sm text-gray-600">
					Follow these steps in order to promote dev data to production.
				</p>
				<ol class="space-y-3 text-sm text-gray-700">
					<li class="flex gap-3">
						<span
							class="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700"
							>1</span
						>
						<div>
							<div class="font-medium">NAS Snapshot</div>
							<code class="mt-0.5 block text-xs text-gray-500"
								>./scripts/nas/export-snapshot.sh --archive</code
							>
						</div>
					</li>
					<li class="flex gap-3">
						<span
							class="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700"
							>2</span
						>
						<div>
							<div class="font-medium">Delta Export</div>
							<code class="mt-0.5 block text-xs text-gray-500"
								>cd backend && mix data.export_delta</code
							>
						</div>
					</li>
					<li class="flex gap-3">
						<span
							class="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700"
							>3</span
						>
						<div>
							<div class="font-medium">Review Delta SQL</div>
							<span class="mt-0.5 block text-xs text-gray-500"
								>Inspect the generated .sql file — remove any rows not ready for prod</span
							>
						</div>
					</li>
					<li class="flex gap-3">
						<span
							class="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-full bg-blue-100 text-xs font-bold text-blue-700"
							>4</span
						>
						<div>
							<div class="font-medium">Apply to Production</div>
							<code class="mt-0.5 block text-xs text-gray-500"
								>cat scripts/sync/delta_*.sql | ssh sertantai-hz "docker exec -i shared_postgres
								psql -U postgres -d sertantai_legal_prod -v ON_ERROR_STOP=1"</code
							>
						</div>
					</li>
				</ol>
			</div>
		</section>
	{/if}
</div>
