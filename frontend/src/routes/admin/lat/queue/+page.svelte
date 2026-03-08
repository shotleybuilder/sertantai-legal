<script lang="ts">
	/* eslint-disable no-undef */
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { TableKit } from '@shotleybuilder/svelte-table-kit';
	import type { ColumnDef } from '@tanstack/svelte-table';
	import type { FilterCondition } from '@shotleybuilder/svelte-table-kit';
	import { goto } from '$app/navigation';
	import { useQueryClient } from '@tanstack/svelte-query';
	import { reparseLat, type QueueItem } from '$lib/api/lat';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { createDynamicQueryStore } from '$lib/pglite/live-store';
	import ParseReviewModal from '$lib/components/ParseReviewModal.svelte';
	import LatParseDialog from '$lib/components/LatParseDialog.svelte';
	import {
		SaveViewModal,
		activeViewId,
		activeViewModified,
		viewActions,
		savedViews
	} from 'svelte-table-views-tanstack';
	import type { TableConfig, SavedViewInput } from 'svelte-table-views-tanstack';
	import { ViewSidebar } from 'svelte-table-views-sidebar';
	import type { SidebarView, ViewGroup } from 'svelte-table-views-sidebar';

	const queryClient = useQueryClient();

	// ── State ────────────────────────────────────────────────────────

	const SIX_MONTHS_MS = 6 * 30 * 24 * 60 * 60 * 1000;
	const SIX_MONTHS_INTERVAL = "6 months";

	// PGLite dynamic query: scoped to selected family view
	const { store: rawStore, update: updateQuery, refresh: refreshData } = createDynamicQueryStore<Record<string, unknown>>();

	// Build QueueItem[] from raw PGLite rows
	$: queueData = $rawStore.map((r): QueueItem => {
		const latCount = (r.lat_count as number) ?? 0;
		return {
			law_id: r.id as string,
			law_name: r.name as string,
			title_en: r.title_en as string,
			year: (r.year as number | null) ?? 0,
			type_code: (r.type_code as string | null) ?? '',
			family: r.family as string | null,
			live: r.live as string | null,
			function: parseFunctionKeys(r.function),
			lrt_updated_at: r.updated_at as string | null,
			lat_count: latCount,
			latest_lat_updated_at: r.latest_lat_updated_at as string | null,
			queue_reason: latCount === 0 ? 'missing' : 'stale'
		};
	});

	let error: string | null = null;

	// Reparse tracking
	let reparsingLaw: string | null = null;
	let reparseMessage = '';
	let reparseError = '';

	// LRT refresh modal state
	let lrtModalOpen = false;
	let lrtModalRecord: QueueItem | null = null;
	let lrtModalRecordId: string | undefined = undefined;

	// LAT Parse Dialog state
	let showLatDialog = false;

	function handleLatSessionCreated(event: CustomEvent<{ session_id: string }>) {
		showLatDialog = false;
		goto(`/admin/lat/sessions/${event.detail.session_id}`);
	}

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

	// Track current family for stats
	let currentFamily: string | null = null;
	let currentViewName: string | null = null;

	// ── SQL query builders ──────────────────────────────────────────

	// Base WHERE for LAT queue candidates: making, not revoked, not classified as not_making
	const QUEUE_BASE_WHERE = `
		is_making = true
		AND (making_classification IS NULL OR making_classification != 'not_making')
		AND (live IS NULL OR live != '❌ Revoked / Repealed / Abolished')
		AND title_en IS NOT NULL
		AND family IS NOT NULL
		AND family != '_todo'
		AND family != '🖤 X: No Family'`;

	// LAT queue condition: missing (lat_count=0) OR stale (LRT updated > 6 months after LAT)
	const QUEUE_LAT_WHERE = `
		AND (
			lat_count = 0
			OR (
				updated_at IS NOT NULL
				AND latest_lat_updated_at IS NOT NULL
				AND updated_at > latest_lat_updated_at + INTERVAL '${SIX_MONTHS_INTERVAL}'
			)
		)`;

	const QUEUE_COLUMNS = 'id, name, title_en, year, type_code, family, live, function, updated_at, lat_count, latest_lat_updated_at';

	function queryForFamily(family: string) {
		currentFamily = family;
		updateQuery(
			`SELECT ${QUEUE_COLUMNS} FROM uk_lrt
			 WHERE ${QUEUE_BASE_WHERE} ${QUEUE_LAT_WHERE}
			   AND family = $1
			 ORDER BY name`,
			[family]
		);
	}

	function queryAllQueue() {
		currentFamily = null;
		updateQuery(
			`SELECT ${QUEUE_COLUMNS} FROM uk_lrt
			 WHERE ${QUEUE_BASE_WHERE} ${QUEUE_LAT_WHERE}
			 ORDER BY name`,
			[]
		);
	}

	function queryForView(viewName: string) {
		currentViewName = viewName;
		const family = viewFamilyMapping[viewName];
		if (family) {
			queryForFamily(family);
		} else if (viewName === 'Missing LAT') {
			currentFamily = null;
			updateQuery(
				`SELECT ${QUEUE_COLUMNS} FROM uk_lrt
				 WHERE ${QUEUE_BASE_WHERE}
				   AND lat_count = 0
				 ORDER BY name`,
				[]
			);
		} else if (viewName === 'Stale LAT') {
			currentFamily = null;
			updateQuery(
				`SELECT ${QUEUE_COLUMNS} FROM uk_lrt
				 WHERE ${QUEUE_BASE_WHERE}
				   AND lat_count > 0
				   AND updated_at IS NOT NULL
				   AND latest_lat_updated_at IS NOT NULL
				   AND updated_at > latest_lat_updated_at + INTERVAL '${SIX_MONTHS_INTERVAL}'
				 ORDER BY name`,
				[]
			);
		} else {
			queryAllQueue();
		}
	}

	// Refresh data when sync status changes
	let lastRefreshRecordCount = 0;
	$: if ($syncStatus.recordCount > 0 && $syncStatus.recordCount !== lastRefreshRecordCount) {
		lastRefreshRecordCount = $syncStatus.recordCount;
		refreshData();
	}

	// ── Reactive stats ──────────────────────────────────────────────

	$: totalCount = queueData.length;
	$: missingCount = queueData.filter((r) => r.queue_reason === 'missing').length;
	$: staleCount = queueData.filter((r) => r.queue_reason === 'stale').length;
	$: isLoading = !$syncStatus.connected && queueData.length === 0;

	// Watch syncStatus for errors
	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}

	// ── Helpers ──────────────────────────────────────────────────────

	// Electric sends JSONB `function` as a JS object {Making: true, ...}
	function parseFunctionKeys(fn: unknown): string[] | null {
		if (!fn) return null;
		if (Array.isArray(fn)) return fn as string[];
		if (typeof fn === 'object') {
			return Object.keys(fn as Record<string, boolean>).filter((k) => (fn as Record<string, boolean>)[k]);
		}
		if (typeof fn === 'string') {
			try {
				const parsed = JSON.parse(fn);
				if (typeof parsed === 'object' && !Array.isArray(parsed)) {
					return Object.keys(parsed).filter((k) => parsed[k]);
				}
			} catch { /* not JSON */ }
		}
		return null;
	}

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

	// ── PGLite sync initialization ──────────────────────────────────

	onMount(async () => {
		if (browser) {
			await startSync();
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
			queryClient.invalidateQueries({ queryKey: ['lat'] });
		} catch (e) {
			reparsingLaw = null;
			reparseError = `Failed to re-parse ${item.law_name}: ${e instanceof Error ? e.message : 'Unknown error'}`;
		}
	}

	// ── LRT Refresh (Parse & Review modal) ──────────────────────────

	function openLrtRefresh(item: QueueItem) {
		lrtModalRecord = item;
		lrtModalRecordId = item.law_id;
		lrtModalOpen = true;
	}

	function closeLrtRefresh() {
		lrtModalOpen = false;
		lrtModalRecord = null;
		lrtModalRecordId = undefined;
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
			size: 60,
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
			id: 'year',
			accessorKey: 'year',
			header: 'Year',
			cell: (info) => info.getValue() ?? '',
			size: 80,
			enableGrouping: true,
			meta: { group: 'Identification', dataType: 'number' }
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

	// ── Family-based view definitions ───────────────────────────────

	interface FamilyViewDef {
		name: string;
		family: string;
		group: 'safety' | 'environment' | 'hr';
	}

	const familyViewDefs: FamilyViewDef[] = [
		// Safety
		{ name: 'Fire', family: '💙 FIRE', group: 'safety' },
		{ name: 'Fire: Dangerous & Explosive', family: '💙 FIRE: Dangerous and Explosive Substances', group: 'safety' },
		{ name: 'Food', family: '💙 FOOD', group: 'safety' },
		{ name: 'Health: Coronavirus', family: '💙 HEALTH: Coronavirus', group: 'safety' },
		{ name: 'Health: Drug & Medicine', family: '💙 HEALTH: Drug & Medicine Safety', group: 'safety' },
		{ name: 'Health: Patient Safety', family: '💙 HEALTH: Patient Safety', group: 'safety' },
		{ name: 'Health: Public', family: '💙 HEALTH: Public', group: 'safety' },
		{ name: 'OHS: Gas & Electrical', family: '💙 OH&S: Gas & Electrical Safety', group: 'safety' },
		{ name: 'OHS: Mines & Quarries', family: '💙 OH&S: Mines & Quarries', group: 'safety' },
		{ name: 'OHS: Occupational', family: '💙 OH&S: Occupational / Personal Safety', group: 'safety' },
		{ name: 'OHS: Offshore', family: '💙 OH&S: Offshore Safety', group: 'safety' },
		{ name: 'Public', family: '💙 PUBLIC', group: 'safety' },
		{ name: 'Public: Building Safety', family: '💙 PUBLIC: Building Safety', group: 'safety' },
		{ name: 'Public: Consumer / Product', family: '💙 PUBLIC: Consumer / Product Safety', group: 'safety' },
		{ name: 'Transport: Air Safety', family: '💙 TRANSPORT: Air Safety', group: 'safety' },
		{ name: 'Transport: Rail Safety', family: '💙 TRANSPORT: Rail Safety', group: 'safety' },
		{ name: 'Transport: Road Safety', family: '💙 TRANSPORT: Road Safety', group: 'safety' },
		{ name: 'Transport: Maritime', family: '💙 TRANSPORT: Maritime Safety', group: 'safety' },
		// Environment
		{ name: 'Agriculture', family: '💚 AGRICULTURE', group: 'environment' },
		{ name: 'Agriculture: Pesticides', family: '💚 AGRICULTURE: Pesticides', group: 'environment' },
		{ name: 'Air Quality', family: '💚 AIR QUALITY', group: 'environment' },
		{ name: 'Animals & Animal Health', family: '💚 ANIMALS & ANIMAL HEALTH', group: 'environment' },
		{ name: 'Antarctica', family: '💚 ANTARCTICA', group: 'environment' },
		{ name: 'Buildings', family: '💚 BUILDINGS', group: 'environment' },
		{ name: 'Climate Change', family: '💚 CLIMATE CHANGE', group: 'environment' },
		{ name: 'Energy', family: '💚 ENERGY', group: 'environment' },
		{ name: 'Environmental Protection', family: '💚 ENVIRONMENTAL PROTECTION', group: 'environment' },
		{ name: 'Finance', family: '💚 FINANCE', group: 'environment' },
		{ name: 'Fisheries & Fishing', family: '💚 FISHERIES & FISHING', group: 'environment' },
		{ name: 'GMOs', family: '💚 GMOs', group: 'environment' },
		{ name: 'Historic Environment', family: '💚 HISTORIC ENVIRONMENT', group: 'environment' },
		{ name: 'Marine & Riverine', family: '💚 MARINE & RIVERINE', group: 'environment' },
		{ name: 'Noise', family: '💚 NOISE', group: 'environment' },
		{ name: 'Nuclear & Radiological', family: '💚 NUCLEAR & RADIOLOGICAL', group: 'environment' },
		{ name: 'Oil & Gas / Offshore', family: '💚 OIL & GAS - OFFSHORE - PETROLEUM', group: 'environment' },
		{ name: 'Planning & Infrastructure', family: '💚 PLANNING & INFRASTRUCTURE', group: 'environment' },
		{ name: 'Plant Health', family: '💚 PLANT HEALTH', group: 'environment' },
		{ name: 'Pollution', family: '💚 POLLUTION', group: 'environment' },
		{ name: 'Town & Country Planning', family: '💚 TOWN & COUNTRY PLANNING', group: 'environment' },
		{ name: 'Transport', family: '💚 TRANSPORT', group: 'environment' },
		{ name: 'Transport: Aviation', family: '💚 TRANSPORT: Aviation', group: 'environment' },
		{ name: 'Transport: Harbours & Shipping', family: '💚 TRANSPORT: Harbours & Shipping', group: 'environment' },
		{ name: 'Transport: Railways', family: '💚 TRANSPORT: Railways & Rail Transport', group: 'environment' },
		{ name: 'Transport: Roads & Vehicles', family: '💚 TRANSPORT: Roads & Vehicles', group: 'environment' },
		{ name: 'Trees: Forestry & Timber', family: '💚 TREES: Forestry & Timber', group: 'environment' },
		{ name: 'Waste', family: '💚 WASTE', group: 'environment' },
		{ name: 'Water & Wastewater', family: '💚 WATER & WASTEWATER', group: 'environment' },
		{ name: 'Wildlife & Countryside', family: '💚 WILDLIFE & COUNTRYSIDE', group: 'environment' },
		// HR
		{ name: 'Employment', family: '💜 HR: Employment', group: 'hr' },
		{ name: 'Insurance / Compensation', family: '💜 HR: Insurance / Compensation / Wages / Benefits', group: 'hr' },
		{ name: 'Working Time', family: '💜 HR: Working Time', group: 'hr' },
	];

	// Mappings for quick lookup
	const viewFamilyMapping: Record<string, string> = {};
	for (const def of familyViewDefs) {
		viewFamilyMapping[def.name] = def.family;
	}

	const viewGroupMapping: Record<string, string> = {};
	for (const def of familyViewDefs) {
		viewGroupMapping[def.name] = def.group;
	}
	viewGroupMapping['All Queue'] = 'queue';
	viewGroupMapping['Missing LAT'] = 'queue';
	viewGroupMapping['Stale LAT'] = 'queue';

	const allColumns = ['actions', 'law_name', 'title_en', 'family', 'year', 'live', 'function', 'queue_reason', 'lat_count', 'lrt_updated_at', 'latest_lat_updated_at'];
	const familyColumns = ['actions', 'law_name', 'title_en', 'year', 'live', 'function', 'queue_reason', 'lat_count', 'lrt_updated_at', 'latest_lat_updated_at'];

	type ViewDef = {
		name: string;
		description: string;
		columns: string[];
		filters?: Array<{ columnId: string; operator: string; value: unknown }>;
		sort?: { columnId: string; direction: 'asc' | 'desc' } | null;
		grouping?: string[];
		isDefault?: boolean;
	};

	const defaultViews: ViewDef[] = [
		// Queue-wide views
		{
			name: 'All Queue',
			description: 'All making laws needing LAT parsing — missing and stale.',
			columns: allColumns,
			sort: { columnId: 'lrt_updated_at', direction: 'asc' },
			grouping: ['family', 'year'],
			isDefault: true
		},
		{
			name: 'Missing LAT',
			description: 'LRT records with making function that have no LAT data at all.',
			columns: allColumns,
			sort: { columnId: 'lrt_updated_at', direction: 'asc' },
			grouping: ['family', 'year']
		},
		{
			name: 'Stale LAT',
			description: 'LRT records where LAT data exists but is more than 6 months out of date.',
			columns: allColumns,
			sort: { columnId: 'lrt_updated_at', direction: 'asc' },
			grouping: ['family', 'year']
		},
		// Family-specific views
		...familyViewDefs.map((def): ViewDef => ({
			name: def.name,
			description: `${def.family} — LAT parse candidates`,
			columns: familyColumns,
			sort: { columnId: 'name', direction: 'asc' },
			grouping: ['year']
		}))
	];

	const viewGroups: ViewGroup[] = [
		{ id: 'queue', name: 'Queue', order: 0 },
		{ id: 'safety', name: '💙 S', order: 1 },
		{ id: 'environment', name: '💚 E', order: 2 },
		{ id: 'hr', name: '💜 HR', order: 3 }
	];

	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));
	const queueViewNames = new Set(defaultViews.map((v) => v.name));

	$: sidebarViews = $savedViews
		.filter((view) => queueViewNames.has(view.name))
		.map((view): SidebarView => ({
			id: view.id,
			name: view.name,
			description: view.description,
			groupId: viewGroupMapping[view.name] || 'queue',
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
				try { await viewActions.delete(view.id); } catch { /* ignore duplicate cleanup */ }
			} else {
				existingViews.set(view.name, view.id);
			}
		}

		// Seed missing views (existing views are never overwritten)
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

		// Auto-select default view and query it
		if (defaultViewId && !$activeViewId) {
			const loadedView = await viewActions.load(defaultViewId);
			if (loadedView) {
				applyViewConfig(loadedView.config);
				const defaultDef = defaultViews.find((v) => v.isDefault);
				if (defaultDef) {
					queryForView(defaultDef.name);
				}
			}
		} else if ($activeViewId) {
			// Returning user — resolve the active view and query it
			const activeView = $savedViews.find((v) => v.id === $activeViewId);
			if (activeView) {
				applyViewConfig(activeView as unknown as TableConfig);
				queryForView(activeView.name);
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
		queryForView(sidebarView.name);
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
						{#if currentFamily}
							{currentFamily} — records needing LAT parsing
						{:else if currentViewName}
							{currentViewName}
						{:else}
							LRT records with making function that need LAT parsing or re-parsing.
						{/if}
					</p>
				</div>
			</div>
			<div class="flex items-center space-x-3">
				<a
					href="/admin/lat/sessions"
					class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
				>
					Sessions
				</a>
				<button
					on:click={() => (showLatDialog = true)}
					class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700"
				>
					Parse Family
				</button>
			</div>
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
			<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">View Total</div>
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
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Sync Status</div>
					<div class="flex items-center gap-2">
						{#if $syncStatus.syncing}
							<div class="w-2 h-2 bg-yellow-500 rounded-full animate-pulse"></div>
							<span class="text-sm font-medium text-yellow-600">Syncing...</span>
						{:else if $syncStatus.connected}
							<div class="w-2 h-2 bg-green-500 rounded-full"></div>
							<span class="text-sm font-medium text-green-600">Synced</span>
						{:else}
							<div class="w-2 h-2 bg-gray-400 rounded-full"></div>
							<span class="text-sm font-medium text-gray-600">Disconnected</span>
						{/if}
					</div>
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
					on:click={() => window.location.reload()}
				>
					Retry
				</button>
			</div>
		{:else if queueData.length === 0}
			<div class="text-center py-12 text-gray-500">
				{#if currentFamily}
					No records needing LAT parsing in this family.
				{:else}
					No records in queue. All making laws have up-to-date LAT data.
				{/if}
			</div>
		{:else}
			<TableKit
				data={queueData}
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
					pagination: false,
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
						<div class="flex flex-col gap-0.5">
							<button
								on:click={() => openLrtRefresh(row)}
								class="px-2 py-0.5 text-xs font-medium rounded transition-colors bg-indigo-600 text-white hover:bg-indigo-700"
								title="Refresh LRT metadata (status, dates, extent) from legislation.gov.uk"
							>
								LRT
							</button>
							<button
								on:click={() => handleReparse(row)}
								disabled={reparsingLaw === row.law_name}
								class="px-2 py-0.5 text-xs font-medium rounded transition-colors
									{reparsingLaw === row.law_name
									? 'bg-gray-100 text-gray-400 cursor-not-allowed'
									: 'bg-blue-600 text-white hover:bg-blue-700'}"
								title="Re-parse LAT articles and annotations"
							>
								{#if reparsingLaw === row.law_name}
									Parsing...
								{:else}
									LAT
								{/if}
							</button>
						</div>
					{:else if column === 'law_name'}
						<span class="font-mono text-gray-700">{row.law_name}</span>
					{:else if column === 'title_en'}
						<span class="text-gray-900 whitespace-normal leading-snug">{row.title_en || ''}</span>
					{:else if column === 'family'}
						<span class="text-gray-700 whitespace-normal leading-snug">{row.family || ''}</span>
					{:else if column === 'year'}
						<span class="text-gray-700">{row.year ?? ''}</span>
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
						{#if row.function?.includes('Making')}
							<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700">Making</span>
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

<!-- LAT Parse Family Dialog -->
<LatParseDialog
	bind:open={showLatDialog}
	on:close={() => (showLatDialog = false)}
	on:created={handleLatSessionCreated}
/>

<!-- LRT Refresh Modal (Parse & Review) -->
{#if lrtModalRecord}
	<ParseReviewModal
		records={[{
			name: lrtModalRecord.law_name,
			Title_EN: lrtModalRecord.title_en,
			type_code: lrtModalRecord.type_code,
			Year: lrtModalRecord.year,
			Number: ''
		}]}
		recordId={lrtModalRecordId}
		open={lrtModalOpen}
		on:close={closeLrtRefresh}
	/>
{/if}
