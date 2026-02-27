<script lang="ts">
	import { onMount } from 'svelte';
	import { TableKit } from '@shotleybuilder/svelte-table-kit';
	import type { ColumnDef } from '@tanstack/svelte-table';
	import { useQueryClient } from '@tanstack/svelte-query';
	import { getLatQueue, reparseLat, type QueueItem } from '$lib/api/lat';

	const queryClient = useQueryClient();

	// ── State ────────────────────────────────────────────────────────

	let data: QueueItem[] = [];
	let isLoading = true;
	let error: string | null = null;

	// Counts from API (always reflect full queue, not filtered)
	let totalCount = 0;
	let missingCount = 0;
	let staleCount = 0;

	// Reparse tracking
	let reparsingLaw: string | null = null;
	let reparseMessage = '';
	let reparseError = '';

	// ── Data fetching ───────────────────────────────────────────────

	async function fetchQueue() {
		try {
			isLoading = true;
			error = null;
			const result = await getLatQueue(5000, 0);
			data = result.items;
			totalCount = result.total;
			missingCount = result.missing_count;
			staleCount = result.stale_count;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load queue';
		} finally {
			isLoading = false;
		}
	}

	onMount(() => {
		fetchQueue();
	});

	// ── Re-parse ────────────────────────────────────────────────────

	async function handleReparse(item: QueueItem) {
		reparsingLaw = item.law_name;
		reparseMessage = '';
		reparseError = '';

		try {
			const result = await reparseLat(item.law_name);
			reparsingLaw = null;
			reparseMessage = `Re-parsed ${item.law_name}: ${result.lat.inserted} LAT rows, ${result.annotations.inserted} annotations (${result.duration_ms}ms)`;
			// Refresh queue data and invalidate related queries
			queryClient.invalidateQueries({ queryKey: ['lat'] });
			await fetchQueue();
		} catch (e) {
			reparsingLaw = null;
			reparseError = `Failed to re-parse ${item.law_name}: ${e instanceof Error ? e.message : 'Unknown error'}`;
		}
	}

	// ── Helpers ──────────────────────────────────────────────────────

	function asRecord(row: unknown): QueueItem {
		return row as QueueItem;
	}

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '--';
		return new Date(dateStr).toLocaleDateString('en-GB', {
			day: '2-digit',
			month: 'short',
			year: 'numeric'
		});
	}

	function formatNumber(n: number): string {
		return n.toLocaleString();
	}

	// ── Column definitions ──────────────────────────────────────────

	const reasonOptions = [
		{ value: 'missing', label: 'Missing' },
		{ value: 'stale', label: 'Stale' }
	];

	const columns: ColumnDef<QueueItem>[] = [
		{
			id: 'actions',
			header: '',
			cell: (info) => info.cell.row.original.law_name,
			size: 80,
			enableSorting: false,
			enableResizing: false,
			meta: { group: 'Actions' }
		},
		{
			id: 'law_name',
			accessorKey: 'law_name',
			header: 'Law Name',
			cell: (info) => info.getValue(),
			size: 160,
			meta: { group: 'Identification', dataType: 'text' }
		},
		{
			id: 'title_en',
			accessorKey: 'title_en',
			header: 'Title',
			cell: (info) => info.getValue() || '',
			size: 350,
			meta: { group: 'Identification', dataType: 'text' }
		},
		{
			id: 'family',
			accessorKey: 'family',
			header: 'Family',
			cell: (info) => info.getValue() || '',
			size: 200,
			enableGrouping: true,
			meta: { group: 'Identification', dataType: 'text' }
		},
		{
			id: 'queue_reason',
			accessorKey: 'queue_reason',
			header: 'Reason',
			cell: (info) => info.getValue(),
			size: 90,
			enableGrouping: true,
			meta: { group: 'Queue', dataType: 'select', selectOptions: reasonOptions }
		},
		{
			id: 'lat_count',
			accessorKey: 'lat_count',
			header: 'LAT Rows',
			cell: (info) => info.getValue(),
			size: 80,
			meta: { group: 'Queue', dataType: 'number' }
		},
		{
			id: 'lrt_updated_at',
			accessorKey: 'lrt_updated_at',
			header: 'LRT Updated',
			cell: (info) => formatDate(info.getValue() as string | null),
			size: 110,
			meta: { group: 'Dates', dataType: 'date' }
		},
		{
			id: 'latest_lat_updated_at',
			accessorKey: 'latest_lat_updated_at',
			header: 'LAT Updated',
			cell: (info) => formatDate(info.getValue() as string | null),
			size: 110,
			meta: { group: 'Dates', dataType: 'date' }
		}
	];


</script>

<svelte:head>
	<title>LAT Queue — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">LAT Parse Queue</h1>
			<p class="mt-1 text-sm text-gray-500">
				LRT records with making function that need LAT parsing or re-parsing.
			</p>
		</div>
		<a href="/admin/lat" class="text-sm text-gray-500 hover:text-gray-700">&larr; LAT Data</a>
	</div>

	<!-- Feedback messages -->
	{#if reparseMessage}
		<div class="px-4 py-3 text-sm bg-green-50 text-green-700 rounded-lg border border-green-200">
			{reparseMessage}
		</div>
	{/if}
	{#if reparseError}
		<div class="px-4 py-3 text-sm bg-red-50 text-red-700 rounded-lg border border-red-200">
			{reparseError}
		</div>
	{/if}

	<!-- Stats Bar -->
	{#if !isLoading}
		<div class="grid grid-cols-3 gap-4">
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Total Queue</div>
				<div class="text-2xl font-bold text-gray-900">{formatNumber(totalCount)}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Missing LAT</div>
				<div class="text-2xl font-bold text-red-600">{formatNumber(missingCount)}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-4">
				<div class="text-sm text-gray-500">Stale LAT</div>
				<div class="text-2xl font-bold text-amber-600">{formatNumber(staleCount)}</div>
			</div>
		</div>
	{/if}

	<!-- Table -->
	{#if isLoading}
		<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
			<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
			<p class="mt-4 text-gray-600">Loading queue...</p>
		</div>
	{:else if error}
		<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
			<p class="text-red-600">{error}</p>
			<button
				class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
				on:click={fetchQueue}
			>
				Retry
			</button>
		</div>
	{:else if data.length === 0}
		<div class="text-center py-12 text-gray-500">
			No records in queue. All making laws have up-to-date LAT data.
		</div>
	{:else}
		<TableKit
			{data}
			{columns}
			storageKey="lat_queue_table"
			persistState={true}
			align="left"
			features={{
				columnVisibility: true,
				columnResizing: true,
				columnReordering: true,
				filtering: true,
				sorting: true,
				sortingMode: 'control',
				pagination: true,
				grouping: true
			}}
		>
			<svelte:fragment slot="cell" let:cell let:column>
				{@const row = asRecord(cell.row.original)}
				{#if column === 'actions'}
					<button
						on:click={() => handleReparse(row)}
						disabled={reparsingLaw === row.law_name}
						class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors
							{reparsingLaw === row.law_name
							? 'bg-gray-100 text-gray-400 cursor-not-allowed'
							: 'bg-blue-600 text-white hover:bg-blue-700'}"
					>
						{#if reparsingLaw === row.law_name}
							Parsing...
						{:else}
							Re-parse
						{/if}
					</button>
				{:else if column === 'law_name'}
					<span class="font-mono text-gray-700">{row.law_name}</span>
				{:else if column === 'title_en'}
					<span class="text-gray-900">{row.title_en || ''}</span>
				{:else if column === 'family'}
					<span class="text-gray-700">{row.family || ''}</span>
				{:else if column === 'lat_count'}
					<span class="text-gray-700">{row.lat_count}</span>
				{:else if column === 'lrt_updated_at'}
					<span class="text-gray-700">{formatDate(String(row.lrt_updated_at ?? ''))}</span>
				{:else if column === 'latest_lat_updated_at'}
					<span class="text-gray-700">{formatDate(String(row.latest_lat_updated_at ?? ''))}</span>
				{:else if column === 'queue_reason'}
					{#if row.queue_reason === 'missing'}
						<span class="px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
							missing
						</span>
					{:else}
						<span class="px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
							stale
						</span>
					{/if}
			{/if}
			</svelte:fragment>
		</TableKit>
	{/if}
</div>
