<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { TableKit } from '@shotleybuilder/svelte-table-kit';
	import type { ColumnDef } from '@tanstack/svelte-table';
	import type { FilterCondition, TableConfig as TableKitConfig } from '@shotleybuilder/svelte-table-kit';
	import { useQueryClient } from '@tanstack/svelte-query';
	import { getLatQueue, reparseLat, type QueueItem } from '$lib/api/lat';
	import {
		SaveViewModal,
		activeViewId,
		activeViewModified,
		viewActions,
		savedViews
	} from 'svelte-table-views-tanstack';
	import type { TableConfig, SavedView, SavedViewInput } from 'svelte-table-views-tanstack';
	import { ViewSidebar } from 'svelte-table-views-sidebar';
	import type { SidebarView, ViewGroup } from 'svelte-table-views-sidebar';

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

	// Saved views state
	let showSaveModal = false;
	let capturedConfig: TableConfig | null = null;
	let sidebarOpen = false;

	// View configuration state
	let viewFilters: FilterCondition[] = [];
	let viewSort: { columnId: string; direction: 'asc' | 'desc' } | null = null;
	let viewColumns: string[] = [];
	let viewColumnOrder: string[] = [];
	let viewGrouping: string[] = [];
	let configVersion = 0;

	// ── Data fetching ───────────────────────────────────────────────

	let isRefreshing = false;

	async function fetchQueue(initial = false) {
		try {
			if (initial) isLoading = true;
			isRefreshing = true;
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
			isRefreshing = false;
		}
	}

	onMount(() => {
		fetchQueue(true);
		if (browser) {
			seedDefaultViews();
		}
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

	const liveStatusOptions = [
		{ value: '✔ In force', label: '✔ In force' },
		{ value: '⭕ Part Revocation / Repeal', label: '⭕ Part Revocation / Repeal' },
		{ value: '❌ Revoked / Repealed / Abolished', label: '❌ Revoked / Repealed / Abolished' },
		{ value: '⚠ Planned', label: '⚠ Planned' }
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
			id: 'live',
			accessorKey: 'live',
			header: 'Status',
			cell: (info) => info.getValue() || '',
			size: 100,
			enableGrouping: true,
			meta: { group: 'Identification', dataType: 'select', selectOptions: liveStatusOptions }
		},
		{
			id: 'function',
			accessorKey: 'function',
			header: 'Function',
			cell: (info) => {
				const val = info.getValue() as string[] | null;
				return val?.join(', ') || '-';
			},
			size: 150,
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

	// ── View definitions ────────────────────────────────────────────

	const allColumns = ['actions', 'law_name', 'title_en', 'family', 'live', 'function', 'queue_reason', 'lat_count', 'lrt_updated_at', 'latest_lat_updated_at'];

	const viewGroups: ViewGroup[] = [
		{ id: 'queue', name: 'Queue Views', order: 0 }
	];

	const viewGroupMapping: Record<string, string> = {
		'All Queue': 'queue',
		'Missing LAT': 'queue',
		'Stale LAT': 'queue'
	};

	const defaultViews: Array<{
		name: string;
		description: string;
		columns: string[];
		filters?: Array<{ columnId: string; operator: string; value: unknown }>;
		sort?: { columnId: string; direction: 'asc' | 'desc' } | null;
		grouping?: string[];
		isDefault?: boolean;
	}> = [
		{
			name: 'All Queue',
			description: 'Making laws in force needing LAT parsing — missing and stale.',
			columns: allColumns,
			filters: [
				{ columnId: 'function', operator: 'contains', value: 'Making' },
				{ columnId: 'live', operator: 'not_equals', value: '❌ Revoked / Repealed / Abolished' }
			],
			sort: { columnId: 'lrt_updated_at', direction: 'asc' },
			isDefault: true
		},
		{
			name: 'Missing LAT',
			description: 'LRT records with making function that have no LAT data at all.',
			columns: allColumns,
			filters: [{ columnId: 'queue_reason', operator: 'equals', value: 'missing' }],
			sort: { columnId: 'lrt_updated_at', direction: 'asc' }
		},
		{
			name: 'Stale LAT',
			description: 'LRT records where LAT data exists but is more than 6 months out of date.',
			columns: allColumns,
			filters: [{ columnId: 'queue_reason', operator: 'equals', value: 'stale' }],
			sort: { columnId: 'lrt_updated_at', direction: 'asc' }
		}
	];

	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));

	// Only show views that belong to this page (filter out browse page views from shared store)
	const queueViewNames = new Set(defaultViews.map((v) => v.name));

	$: sidebarViews = $savedViews
		.filter((view) => queueViewNames.has(view.name))
		.map((view): SidebarView => ({
			id: view.id,
			name: view.name,
			description: view.description,
			groupId: 'queue',
			isDefault: defaultViews.find((dv) => dv.name === view.name)?.isDefault,
			order: viewOrderMap.get(view.name) ?? 1000
		}))
		.sort((a, b) => (a.order ?? 1000) - (b.order ?? 1000));

	// ── View lifecycle ──────────────────────────────────────────────

	async function seedDefaultViews() {
		await viewActions.waitForReady();

		const currentViews = $savedViews;

		// Deduplicate
		const existingViews = new Map<string, string>();
		for (const view of currentViews) {
			if (existingViews.has(view.name)) {
				try { await viewActions.delete(view.id); } catch {}
			} else {
				existingViews.set(view.name, view.id);
			}
		}

		// Update existing default views if their config has drifted (e.g. new filters/columns added)
		for (const viewDef of defaultViews) {
			const existingId = existingViews.get(viewDef.name);
			if (!existingId) continue;
			const existing = currentViews.find((v) => v.id === existingId);
			if (!existing) continue;

			const expectedFilters = viewDef.filters || [];
			const currentFilters = existing.config.filters || [];
			const filtersMatch = JSON.stringify(currentFilters) === JSON.stringify(expectedFilters);
			const columnsMatch = JSON.stringify(existing.config.columns) === JSON.stringify(viewDef.columns);

			if (!filtersMatch || !columnsMatch) {
				try {
					await viewActions.update(existingId, {
						config: {
							...existing.config,
							filters: expectedFilters,
							columns: viewDef.columns,
							columnOrder: viewDef.columns
						}
					});
				} catch (err) {
					console.error('[LAT Queue] Failed to update view:', viewDef.name, err);
				}
			}
		}

		const missingViews = defaultViews.filter((v) => !existingViews.has(v.name));
		let defaultViewId: string | null = null;

		const defaultViewDef = defaultViews.find((v) => v.isDefault);
		if (defaultViewDef && existingViews.has(defaultViewDef.name)) {
			defaultViewId = existingViews.get(defaultViewDef.name) || null;
		}

		if (missingViews.length > 0) {
			for (const view of missingViews) {
				const viewInput: SavedViewInput = {
					name: view.name,
					description: view.description,
					config: {
						filters: view.filters || [],
						sort: view.sort || null,
						columns: view.columns,
						columnOrder: view.columns,
						columnWidths: {},
						pageSize: 50,
						grouping: view.grouping || []
					}
				};

				try {
					const savedView = await viewActions.save(viewInput);
					if (view.isDefault && savedView?.id) {
						defaultViewId = savedView.id;
					}
					existingViews.set(view.name, savedView?.id || '');
					await new Promise((resolve) => setTimeout(resolve, 100));
				} catch (err) {
					console.error('[LAT Queue] Failed to seed view:', view.name, err);
				}
			}
		}

		if (defaultViewId && !$activeViewId) {
			const loadedView = await viewActions.load(defaultViewId);
			if (loadedView) {
				applyViewConfig(loadedView.config);
			}
		}
	}

	function applyViewConfig(config: TableConfig) {
		const availableColumnIds = new Set(columns.map((c) => String(c.id)));
		const validColumns = config.columns.filter((colId) => availableColumnIds.has(colId));
		const validColumnOrder = config.columnOrder.filter((colId) => availableColumnIds.has(colId));

		viewColumns = validColumns.length > 0 ? validColumns : [];
		viewColumnOrder = validColumnOrder.length > 0 ? validColumnOrder : [];

		if (config.filters && Array.isArray(config.filters) && config.filters.length > 0) {
			viewFilters = config.filters.map((f, idx) => ({
				id: `view-filter-${idx}`,
				field: f.columnId,
				operator: f.operator as FilterCondition['operator'],
				value: Array.isArray(f.value)
					? f.value
					: typeof f.value === 'string'
						? f.value
						: String(f.value)
			}));
		} else {
			viewFilters = [];
		}

		viewSort = config.sort || null;
		viewGrouping = config.grouping || [];
		configVersion++;
	}

	function captureCurrentConfig(): TableConfig {
		return {
			filters: viewFilters.map((f) => ({
				columnId: f.field,
				operator: f.operator,
				value: f.value
			})),
			sort: viewSort,
			columns: viewColumns.length > 0 ? viewColumns : columns.map((c) => String(c.id)),
			columnOrder: viewColumnOrder.length > 0 ? viewColumnOrder : columns.map((c) => String(c.id)),
			columnWidths: {},
			pageSize: 50,
			grouping: viewGrouping
		};
	}

	async function handleSidebarSelect(event: CustomEvent<{ view: SidebarView }>) {
		const sidebarView = event.detail.view;
		const loadedView = await viewActions.load(sidebarView.id);
		if (loadedView) {
			applyViewConfig(loadedView.config);
		}
	}

	function handleSaveView() {
		capturedConfig = captureCurrentConfig();
		showSaveModal = true;
	}

	async function handleUpdateView() {
		const activeId = $activeViewId;
		if (!activeId) return;
		try {
			const config = captureCurrentConfig();
			await viewActions.update(activeId, { config });
		} catch (err) {
			console.error('[LAT Queue] Failed to update view:', err);
		}
	}

	function handleViewSaved(event: CustomEvent<{ id: string; name: string }>) {
		console.log('[LAT Queue] View saved:', event.detail.name);
	}

	// ── Reactive TableKit config ────────────────────────────────────

	$: hasViewConfig =
		viewColumns.length > 0 ||
		viewColumnOrder.length > 0 ||
		viewFilters.length > 0 ||
		viewSort !== null ||
		viewGrouping.length > 0;

	$: activeFilters = viewFilters.length > 0 ? viewFilters : [];

	$: activeSorting = viewSort
		? [
				...viewGrouping.map((col) => ({ columnId: col, direction: 'desc' as const })),
				{ columnId: viewSort.columnId, direction: viewSort.direction }
			]
		: viewGrouping.length > 0
			? viewGrouping.map((col) => ({ columnId: col, direction: 'desc' as const }))
			: [{ columnId: 'lrt_updated_at', direction: 'asc' as const }];

	$: tableKitConfig = {
		id: hasViewConfig ? `lat_queue_view_v${configVersion}` : 'lat_queue_default',
		version: '1.0',
		defaultFilters: activeFilters,
		defaultSorting: activeSorting,
		defaultColumnOrder: hasViewConfig && viewColumnOrder.length > 0 ? viewColumnOrder : undefined,
		defaultVisibleColumns: hasViewConfig && viewColumns.length > 0 ? viewColumns : undefined,
		defaultGrouping: viewGrouping.length > 0 ? viewGrouping : undefined,
		defaultExpanded: viewGrouping.length > 0 ? true : undefined
	};
</script>

<svelte:head>
	<title>LAT Queue — SertantAI Legal</title>
</svelte:head>

<div class="flex h-full relative">
	<!-- Mobile sidebar overlay -->
	{#if sidebarOpen}
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div
			class="fixed inset-0 bg-black/30 z-30 lg:hidden"
			on:click={() => (sidebarOpen = false)}
		/>
	{/if}

	<!-- View Sidebar -->
	<div
		class="shrink-0 {sidebarOpen
			? 'fixed inset-y-0 left-0 z-40 lg:static lg:z-auto'
			: 'hidden lg:block'}"
	>
		<ViewSidebar
			views={sidebarViews}
			groups={viewGroups}
			selectedViewId={$activeViewId ?? undefined}
			storageKey="lat-queue-views-sidebar"
			width={220}
			showSearch={false}
			showPinned={false}
			on:select={(e) => {
				handleSidebarSelect(e);
				sidebarOpen = false;
			}}
		/>
	</div>

	<!-- Main Content -->
	<div class="flex-1 overflow-auto px-6 py-4 space-y-6">
		<!-- Header -->
		<div class="flex items-center justify-between">
			<div class="flex items-center gap-3">
				<button
					class="lg:hidden p-1.5 rounded-md border border-gray-300 text-gray-600 hover:bg-gray-100"
					on:click={() => (sidebarOpen = !sidebarOpen)}
					title="Toggle views sidebar"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
					</svg>
				</button>
				<div>
					<h1 class="text-2xl font-bold text-gray-900">LAT Parse Queue</h1>
					<p class="mt-1 text-sm text-gray-500">
						LRT records with making function that need LAT parsing or re-parsing.
					</p>
				</div>
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
					on:click={() => fetchQueue(true)}
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
				config={tableKitConfig}
				storageKey="lat_queue_table"
				persistState={!hasViewConfig}
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
				<!-- Save View Buttons -->
				<svelte:fragment slot="toolbar-left">
					{#if $activeViewId && $activeViewModified}
						<div class="inline-flex rounded-md shadow-sm">
							<button
								type="button"
								on:click={handleUpdateView}
								class="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded-l-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
								</svg>
								Update View
							</button>
							<button
								type="button"
								on:click={handleSaveView}
								class="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 border-l border-blue-500 rounded-r-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
								</svg>
								Save New
							</button>
						</div>
					{:else}
						<button
							type="button"
							on:click={handleSaveView}
							class="inline-flex items-center gap-2 px-3 py-1.5 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
							</svg>
							Save View
						</button>
					{/if}
				</svelte:fragment>

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
					{:else if column === 'live'}
						{@const status = row.live}
						<span
							class="inline-flex px-2 py-0.5 text-xs font-medium rounded
								{status === '✔ In force' ? 'bg-green-100 text-green-800'
								: status === '⭕ Part Revocation / Repeal' ? 'bg-amber-100 text-amber-800'
								: 'bg-gray-100 text-gray-800'}"
						>
							{status || '-'}
						</span>
					{:else if column === 'function'}
						{#if row.function?.length}
							<span class="flex flex-wrap gap-1">
								{#each row.function as fn}
									<span
										class="px-1.5 py-0.5 text-xs rounded
											{fn === 'Making' ? 'bg-green-100 text-green-700'
											: fn === 'Amending' ? 'bg-yellow-100 text-yellow-700'
											: fn === 'Revoking' ? 'bg-red-100 text-red-700'
											: 'bg-gray-100 text-gray-700'}"
									>
										{fn}
									</span>
								{/each}
							</span>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
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
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig}
	<SaveViewModal bind:open={showSaveModal} config={capturedConfig} on:save={handleViewSaved} />
{/if}
