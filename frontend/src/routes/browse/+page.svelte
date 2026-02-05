<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { TableKit } from '@shotleybuilder/svelte-table-kit';
	import type { ColumnDef } from '@tanstack/svelte-table';
	import {
		ViewSelector,
		SaveViewModal,
		activeViewId,
		activeViewModified,
		viewActions,
		savedViews
	} from 'svelte-table-views-tanstack';
	import type { TableConfig, SavedView, SavedViewInput } from 'svelte-table-views-tanstack';

	import {
		getUkLrtCollection,
		updateUkLrtWhere,
		buildWhereFromFilters,
		syncStatus
	} from '$lib/db/index.client';
	import type {
		TableState,
		FilterCondition,
		TableConfig as TableKitConfig
	} from '@shotleybuilder/svelte-table-kit';

	// Types
	interface UkLrtRecord {
		[key: string]: unknown;
		id: string;
		name: string;
		title_en: string;
		year: number;
		number: string;
		type_code: string;
		type_class: string;
		family: string | null;
		family_ii: string | null;
		live: string | null;
		live_description: string | null;
		geo_extent: string | null;
		geo_region: string | null;
		geo_detail: string | null;
		md_restrict_extent: string | null;
		si_code: string | null;
		function: string[] | null;
		md_date: string | null;
		md_made_date: string | null;
		md_enactment_date: string | null;
		md_coming_into_force_date: string | null;
		latest_amend_date: string | null;
		latest_rescind_date: string | null;
		leg_gov_uk_url: string | null;
	}

	function asRecord(row: unknown): UkLrtRecord {
		return row as UkLrtRecord;
	}

	// State
	let data: UkLrtRecord[] = [];
	let isLoading = true;
	let error: string | null = null;
	let totalCount = 0;

	// Electric sync state
	let collectionSubscription: { unsubscribe: () => void } | null = null;

	// Saved views state
	let showSaveModal = false;
	let capturedConfig: TableConfig | null = null;

	// View configuration state
	let viewColumns: string[] = [];
	let viewColumnOrder: string[] = [];
	let configVersion = 0;
	let viewFilters: FilterCondition[] = [];
	let viewSort: { columnId: string; direction: 'asc' | 'desc' } | null = null;
	let viewGrouping: string[] = [];

	// Format date helper
	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '-';
		const date = new Date(dateStr);
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
	}

	// Month name helper for md_date_month display
	const monthNames = [
		'Jan',
		'Feb',
		'Mar',
		'Apr',
		'May',
		'Jun',
		'Jul',
		'Aug',
		'Sep',
		'Oct',
		'Nov',
		'Dec'
	];

	// Family display helper
	function getFamilyDisplay(family: string | null): { prefix: string; name: string } {
		if (!family) return { prefix: '', name: '-' };
		if (
			family.startsWith('HS:') ||
			family.includes('OH&S') ||
			family.includes('FIRE') ||
			family.includes('FOOD') ||
			family.includes('HEALTH') ||
			family.includes('PUBLIC') ||
			family.includes('TRANSPORT:')
		)
			return { prefix: 'HS', name: family };
		if (
			family.startsWith('E:') ||
			family.includes('ENVIRONMENT') ||
			family.includes('CLIMATE') ||
			family.includes('WASTE') ||
			family.includes('WATER') ||
			family.includes('WILDLIFE') ||
			family.includes('MARINE') ||
			family.includes('POLLUTION') ||
			family.includes('AGRICULTURE') ||
			family.includes('ENERGY')
		)
			return { prefix: 'E', name: family };
		if (family.startsWith('HR:') || family.includes('HR:')) return { prefix: 'HR', name: family };
		return { prefix: '', name: family };
	}

	// Select options for filtering
	const typeCodeOptions = [
		{ value: 'ukpga', label: 'UK Public General Act' },
		{ value: 'uksi', label: 'UK Statutory Instrument' },
		{ value: 'ukla', label: 'UK Local Act' },
		{ value: 'asp', label: 'Act of Scottish Parliament' },
		{ value: 'ssi', label: 'Scottish Statutory Instrument' },
		{ value: 'anaw', label: 'Act of National Assembly for Wales' },
		{ value: 'wsi', label: 'Wales Statutory Instrument' },
		{ value: 'nia', label: 'Northern Ireland Act' },
		{ value: 'nisr', label: 'Northern Ireland Statutory Rule' },
		{ value: 'ukci', label: 'UK Church Instrument' },
		{ value: 'eur', label: 'EU Regulation' },
		{ value: 'eudr', label: 'EU Directive' },
		{ value: 'eudn', label: 'EU Decision' }
	];

	const liveStatusOptions = [
		{ value: 'Live', label: 'Live' },
		{ value: 'Revoked', label: 'Revoked' },
		{ value: 'Repealed', label: 'Repealed' },
		{ value: 'Expired', label: 'Expired' }
	];

	const geoExtentOptions = [
		{ value: 'E+W+S+NI', label: 'E+W+S+NI (UK-wide)' },
		{ value: 'E+W+S', label: 'E+W+S (GB)' },
		{ value: 'E+W', label: 'E+W (England & Wales)' },
		{ value: 'E', label: 'E (England)' },
		{ value: 'W', label: 'W (Wales)' },
		{ value: 'S', label: 'S (Scotland)' },
		{ value: 'NI', label: 'NI (Northern Ireland)' }
	];

	// Column definitions (read-only subset)
	const columns: ColumnDef<UkLrtRecord>[] = [
		// Core identification
		{
			id: 'name',
			accessorKey: 'name',
			header: 'Name',
			cell: (info) => info.getValue(),
			size: 140,
			meta: { group: 'Credentials', dataType: 'text' }
		},
		{
			id: 'title_en',
			accessorKey: 'title_en',
			header: 'Title',
			cell: (info) => info.getValue(),
			size: 300,
			meta: { group: 'Credentials', dataType: 'text' }
		},
		{
			id: 'year',
			accessorKey: 'year',
			header: 'Year',
			cell: (info) => info.getValue(),
			size: 70,
			meta: { group: 'Credentials', dataType: 'number' }
		},
		{
			id: 'type_code',
			accessorKey: 'type_code',
			header: 'Type Code',
			cell: (info) => String(info.getValue() || '').toUpperCase(),
			size: 80,
			enableGrouping: true,
			meta: { group: 'Credentials', dataType: 'select', selectOptions: typeCodeOptions }
		},
		{
			id: 'number',
			accessorKey: 'number',
			header: 'Number',
			cell: (info) => info.getValue(),
			size: 80,
			meta: { group: 'Credentials', dataType: 'text' }
		},
		{
			id: 'type_class',
			accessorKey: 'type_class',
			header: 'Type Class',
			cell: (info) => info.getValue(),
			size: 120,
			enableGrouping: true,
			meta: { group: 'Credentials', dataType: 'text' }
		},
		// Derived date columns for grouping
		{
			id: 'md_date_year',
			accessorFn: (row: UkLrtRecord) => {
				if (!row.md_date) return null;
				return new Date(row.md_date).getFullYear();
			},
			header: 'Year (Date)',
			cell: (info) => info.getValue() ?? '-',
			size: 90,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Metadata', dataType: 'number' }
		},
		{
			id: 'md_date_month',
			accessorFn: (row: UkLrtRecord) => {
				if (!row.md_date) return null;
				const d = new Date(row.md_date);
				return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
			},
			header: 'Month (Date)',
			cell: (info) => {
				const val = info.getValue() as string | null;
				if (!val) return '-';
				const parts = val.split('-');
				return `${monthNames[parseInt(parts[1]) - 1]} ${parts[0]}`;
			},
			size: 100,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Metadata', dataType: 'text' }
		},
		// Description
		{
			id: 'family',
			accessorKey: 'family',
			header: 'Family',
			cell: (info) => info.getValue(),
			size: 200,
			enableGrouping: true,
			meta: { group: 'Description', dataType: 'text' }
		},
		{
			id: 'family_ii',
			accessorKey: 'family_ii',
			header: 'Family II',
			cell: (info) => info.getValue(),
			size: 200,
			enableGrouping: true,
			meta: { group: 'Description', dataType: 'text' }
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
			meta: { group: 'Description', dataType: 'text' }
		},
		{
			id: 'si_code',
			accessorKey: 'si_code',
			header: 'SI Code',
			cell: (info) => info.getValue(),
			size: 180,
			meta: { group: 'Description', dataType: 'text' }
		},
		// Status
		{
			id: 'live',
			accessorKey: 'live',
			header: 'Status',
			cell: (info) => info.getValue(),
			size: 100,
			enableGrouping: true,
			meta: { group: 'Status', dataType: 'select', selectOptions: liveStatusOptions }
		},
		// Geographic
		{
			id: 'geo_extent',
			accessorKey: 'geo_extent',
			header: 'Extent',
			cell: (info) => info.getValue(),
			size: 120,
			enableGrouping: true,
			meta: { group: 'Geographic', dataType: 'select', selectOptions: geoExtentOptions }
		},
		{
			id: 'geo_region',
			accessorKey: 'geo_region',
			header: 'Region',
			cell: (info) => info.getValue(),
			size: 120,
			enableGrouping: true,
			meta: { group: 'Geographic', dataType: 'text' }
		},
		// Dates
		{
			id: 'md_date',
			accessorKey: 'md_date',
			header: 'Primary Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata', dataType: 'date' }
		},
		{
			id: 'md_made_date',
			accessorKey: 'md_made_date',
			header: 'Made',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata', dataType: 'date' }
		},
		{
			id: 'md_coming_into_force_date',
			accessorKey: 'md_coming_into_force_date',
			header: 'In Force',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata', dataType: 'date' }
		},
		// Amendments
		{
			id: 'latest_amend_date',
			accessorKey: 'latest_amend_date',
			header: 'Last Amended',
			cell: (info) => formatDate(info.getValue() as string),
			size: 110,
			meta: { group: 'Amendments', dataType: 'date' }
		},
		{
			id: 'latest_rescind_date',
			accessorKey: 'latest_rescind_date',
			header: 'Last Rescinded',
			cell: (info) => formatDate(info.getValue() as string),
			size: 110,
			meta: { group: 'Amendments', dataType: 'date' }
		},
		// Links
		{
			id: 'leg_gov_uk_url',
			accessorKey: 'leg_gov_uk_url',
			header: 'Link',
			cell: (info) => (info.getValue() ? 'View' : '-'),
			size: 70,
			enableSorting: false,
			meta: { group: 'Links', dataType: 'text' }
		}
	];

	// Default views for browse page
	const currentYear = new Date().getFullYear();
	const threeYearsAgo = `${currentYear - 3}-01-01`;

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
			name: 'Recent Laws',
			description:
				'Laws passed in the last 3 years, grouped by year and month (most recent first).',
			columns: [
				'name',
				'title_en',
				'md_date',
				'md_date_year',
				'md_date_month',
				'type_code',
				'live',
				'family'
			],
			filters: [{ columnId: 'md_date', operator: 'is_after', value: threeYearsAgo }],
			sort: { columnId: 'md_date', direction: 'desc' },
			grouping: ['md_date_year', 'md_date_month'],
			isDefault: true
		},
		{
			name: 'By Family',
			description: 'Browse laws organized by legal family classification.',
			columns: ['name', 'title_en', 'family', 'family_ii', 'year', 'type_code', 'live'],
			sort: { columnId: 'family', direction: 'asc' },
			grouping: ['family']
		},
		{
			name: 'By Status',
			description: 'Laws grouped by current status (Live, Revoked, Repealed, Expired).',
			columns: ['name', 'title_en', 'live', 'year', 'type_code', 'md_date', 'family'],
			sort: { columnId: 'md_date', direction: 'desc' },
			grouping: ['live']
		},
		{
			name: 'By Type',
			description: 'Laws grouped by legislation type (Acts, Statutory Instruments, etc.).',
			columns: ['name', 'title_en', 'type_code', 'type_class', 'year', 'live', 'md_date'],
			sort: { columnId: 'md_date', direction: 'desc' },
			grouping: ['type_code']
		},
		{
			name: 'Geographic Scope',
			description: 'Laws by geographic extent (UK-wide, England & Wales, Scotland, etc.).',
			columns: ['name', 'title_en', 'geo_extent', 'geo_region', 'year', 'type_code', 'live'],
			sort: { columnId: 'md_date', direction: 'desc' },
			grouping: ['geo_extent']
		}
	];

	// Seed default views
	async function seedDefaultViews() {
		localStorage.removeItem('svelte-table-views');

		await viewActions.waitForReady();

		const existingViews = new Map<string, string>();
		const currentViews = $savedViews;
		for (const view of currentViews) {
			existingViews.set(view.name, view.id);
		}

		// Update existing default views that need grouping config added
		for (const viewDef of defaultViews) {
			const existingId = existingViews.get(viewDef.name);
			if (existingId && viewDef.grouping?.length) {
				const existing = currentViews.find((v) => v.id === existingId);
				if (existing && (!existing.config.grouping || existing.config.grouping.length === 0)) {
					try {
						await viewActions.update(existingId, {
							config: {
								...existing.config,
								grouping: viewDef.grouping
							}
						});
					} catch (err) {
						console.error('[Browse] Failed to update view grouping:', viewDef.name, err);
					}
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
						pageSize: 25,
						grouping: view.grouping || []
					}
				};

				try {
					const savedView = await viewActions.save(viewInput);
					if (view.isDefault && savedView?.id) {
						defaultViewId = savedView.id;
					}
					await new Promise((resolve) => setTimeout(resolve, 100));
				} catch (err) {
					console.error('[Browse] Failed to seed view:', view.name, err);
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

	// Capture current table config for saving
	function captureCurrentConfig(): TableConfig {
		return {
			filters: [],
			sort: null,
			columns: columns.map((c) => String(c.id)),
			columnOrder: columns.map((c) => String(c.id)),
			columnWidths: {},
			pageSize: 25,
			grouping: []
		};
	}

	// Apply saved view configuration
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
				value: typeof f.value === 'string' ? f.value : String(f.value)
			}));
		} else {
			viewFilters = [];
		}

		viewSort = config.sort || null;
		viewGrouping = config.grouping || [];
		configVersion++;
	}

	// Handle view selection
	function handleViewSelected(event: CustomEvent<{ view: SavedView }>) {
		const view = event.detail.view;
		setTimeout(() => {
			applyViewConfig(view.config);
		}, 100);
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
			console.error('[Browse] Failed to update view:', err);
		}
	}

	function handleViewSaved(event: CustomEvent<{ id: string; name: string }>) {
		console.log('[Browse] View saved:', event.detail.name);
	}

	// Default date filter (3 years) for Electric sync
	const defaultDateFilter: FilterCondition = {
		id: 'default-date-filter',
		field: 'md_date',
		operator: 'is_after',
		value: threeYearsAgo
	};

	// Track last filter state
	let lastWhereClause = `"md_date" > '${threeYearsAgo}'`;

	function handleTableStateChange(state: TableState) {
		const filters = state.columnFilters.map((f) => ({
			field: f.field,
			operator: f.operator,
			value: f.value
		}));

		const newWhereClause = buildWhereFromFilters(filters);

		if (newWhereClause !== lastWhereClause) {
			lastWhereClause = newWhereClause;
			updateUkLrtWhere(newWhereClause);
		}
	}

	// Electric sync initialization
	async function initElectricSync() {
		try {
			error = null;
			isLoading = true;

			const collection = await getUkLrtCollection();

			let refreshDebounceTimer: ReturnType<typeof setTimeout> | null = null;
			const refreshData = () => {
				if (refreshDebounceTimer) {
					clearTimeout(refreshDebounceTimer);
				}
				refreshDebounceTimer = setTimeout(() => {
					const newData = collection.toArray as UkLrtRecord[];
					data = newData;
					totalCount = newData.length;
					if (newData.length > 0) {
						isLoading = false;
					}
				}, 200);
			};

			const unsubscribeSyncStatus = syncStatus.subscribe((status) => {
				if (status.connected) {
					refreshData();
					if (!status.syncing) {
						isLoading = false;
					}
				}
				if (status.error) {
					error = status.error;
					isLoading = false;
				}
			});

			collectionSubscription = {
				unsubscribe: () => {
					unsubscribeSyncStatus();
					if (refreshDebounceTimer) {
						clearTimeout(refreshDebounceTimer);
					}
				}
			};

			const initialData = collection.toArray as UkLrtRecord[];
			if (initialData.length > 0) {
				data = initialData;
				totalCount = initialData.length;
				isLoading = false;
			}
		} catch (e) {
			console.error('[Browse] Failed to initialize:', e);
			error = e instanceof Error ? e.message : 'Failed to initialize';
			isLoading = false;
		}
	}

	// Build TableKit configuration (reactive)
	$: hasViewConfig =
		viewColumns.length > 0 ||
		viewColumnOrder.length > 0 ||
		viewFilters.length > 0 ||
		viewSort !== null ||
		viewGrouping.length > 0;

	$: activeFilters = viewFilters.length > 0 ? viewFilters : [defaultDateFilter];

	$: activeSorting = viewSort
		? [{ columnId: viewSort.columnId, direction: viewSort.direction }]
		: [{ columnId: 'md_date', direction: 'desc' as const }];

	$: tableKitConfig = {
		id: hasViewConfig ? `browse_view_v${configVersion}` : 'browse_default',
		version: '1.0',
		defaultFilters: activeFilters,
		defaultSorting: activeSorting,
		defaultColumnOrder: hasViewConfig && viewColumnOrder.length > 0 ? viewColumnOrder : undefined,
		defaultVisibleColumns: hasViewConfig && viewColumns.length > 0 ? viewColumns : undefined,
		defaultGrouping: viewGrouping.length > 0 ? viewGrouping : undefined,
		defaultExpanded: viewGrouping.length > 0 ? true : undefined
	};

	onMount(() => {
		if (browser) {
			seedDefaultViews();
			initElectricSync();
		}
	});

	onDestroy(() => {
		if (collectionSubscription) {
			collectionSubscription.unsubscribe();
		}
	});
</script>

<div class="container mx-auto px-4 py-6">
	<div class="mb-6">
		<h1 class="text-2xl font-bold text-gray-900 mb-1">UK Legal Register</h1>
		<p class="text-sm text-gray-600">
			Browse UK Legal, Regulatory & Transport records. Use views to switch between different
			perspectives.
		</p>
	</div>

	{#if isLoading}
		<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
			<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
			<p class="mt-4 text-gray-600">Loading UK LRT data...</p>
		</div>
	{:else if error}
		<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
			<h3 class="text-lg font-semibold text-red-800 mb-2">Error Loading Data</h3>
			<p class="text-red-600">{error}</p>
			<button
				class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
				on:click={() => initElectricSync()}
			>
				Retry
			</button>
		</div>
	{:else}
		<!-- Stats -->
		<div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Records</div>
				<div class="text-2xl font-bold text-gray-900">{data.length.toLocaleString()}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Sync Status</div>
				<div class="flex items-center gap-2">
					{#if $syncStatus.syncing}
						<div class="w-2 h-2 bg-yellow-500 rounded-full animate-pulse"></div>
						<span class="text-lg font-medium text-yellow-600">Syncing...</span>
					{:else if $syncStatus.offline}
						<div class="w-2 h-2 bg-red-500 rounded-full"></div>
						<span class="text-lg font-medium text-red-600">Offline</span>
					{:else if $syncStatus.connected}
						<div class="w-2 h-2 bg-green-500 rounded-full"></div>
						<span class="text-lg font-medium text-green-600">Connected</span>
					{:else}
						<div class="w-2 h-2 bg-gray-400 rounded-full"></div>
						<span class="text-lg font-medium text-gray-600">Disconnected</span>
					{/if}
				</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Filter</div>
				<div
					class="text-sm font-mono text-gray-700 truncate"
					title={$syncStatus.whereClause || 'Last 3 years'}
				>
					{$syncStatus.whereClause || 'Last 3 years (by primary date)'}
				</div>
			</div>
		</div>

		<!-- Table -->
		<TableKit
			{data}
			{columns}
			config={tableKitConfig}
			storageKey="uk_lrt_browse_table"
			persistState={!hasViewConfig}
			align="left"
			onStateChange={handleTableStateChange}
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
			<!-- Saved Views Toolbar -->
			<svelte:fragment slot="toolbar-left">
				<ViewSelector on:viewSelected={handleViewSelected} />

				{#if $activeViewId && $activeViewModified}
					<div class="inline-flex rounded-md shadow-sm">
						<button
							type="button"
							on:click={handleUpdateView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-l-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
								/>
							</svg>
							Update View
						</button>
						<button
							type="button"
							on:click={handleSaveView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-emerald-600 border-l border-emerald-500 rounded-r-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M12 4v16m8-8H4"
								/>
							</svg>
							Save New
						</button>
					</div>
				{:else}
					<button
						type="button"
						on:click={handleSaveView}
						class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4"
							/>
						</svg>
						Save View
					</button>
				{/if}
			</svelte:fragment>

			<svelte:fragment slot="cell" let:cell let:column>
				{@const row = asRecord(cell.row.original)}
				{#if column === 'family'}
					{@const display = getFamilyDisplay(row.family)}
					<span class="truncate">
						{#if display.prefix}
							<span
								class="inline-block px-1 text-xs font-medium rounded mr-1 {display.prefix === 'HS'
									? 'bg-blue-100 text-blue-700'
									: display.prefix === 'E'
										? 'bg-green-100 text-green-700'
										: 'bg-purple-100 text-purple-700'}"
							>
								{display.prefix}
							</span>
						{/if}
						{display.name}
					</span>
				{:else if column === 'title_en'}
					<div class="truncate max-w-xs" title={String(cell.getValue() || '')}>
						{cell.getValue() || '-'}
					</div>
				{:else if column === 'leg_gov_uk_url'}
					{#if cell.getValue()}
						<a
							href={String(cell.getValue())}
							target="_blank"
							rel="noopener noreferrer"
							class="text-blue-600 hover:text-blue-800 hover:underline"
						>
							View
						</a>
					{:else}
						<span class="text-gray-400">-</span>
					{/if}
				{:else if column === 'live'}
					{@const status = cell.getValue()}
					<span
						class="inline-flex px-2 py-0.5 text-xs font-medium rounded {status === 'Live'
							? 'bg-green-100 text-green-800'
							: status === 'Revoked'
								? 'bg-red-100 text-red-800'
								: 'bg-gray-100 text-gray-800'}"
					>
						{status || '-'}
					</span>
				{:else if column === 'function'}
					{#if row.function?.length}
						<span class="flex flex-wrap gap-1">
							{#each row.function as fn}
								<span
									class="px-1.5 py-0.5 text-xs rounded {fn === 'Making'
										? 'bg-green-100 text-green-700'
										: fn === 'Amending'
											? 'bg-yellow-100 text-yellow-700'
											: fn === 'Revoking'
												? 'bg-red-100 text-red-700'
												: 'bg-gray-100 text-gray-700'}"
								>
									{fn}
								</span>
							{/each}
						</span>
					{:else}
						<span class="text-gray-400">-</span>
					{/if}
				{:else}
					{cell.getValue() ?? '-'}
				{/if}
			</svelte:fragment>
		</TableKit>
	{/if}
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig}
	<SaveViewModal bind:open={showSaveModal} config={capturedConfig} on:save={handleViewSaved} />
{/if}
