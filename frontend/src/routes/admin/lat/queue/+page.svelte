<script lang="ts">
	/* eslint-disable no-undef */
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { GridLite } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type { ColumnConfig, GridState, FilterCondition, SortConfig, GroupConfig } from '@shotleybuilder/svelte-gridlite-kit';
	import { initViewStore, SaveViewModal, runViewMigrations } from '@shotleybuilder/svelte-gridlite-views';
	import type { ViewConfig, SavedView, ViewStoreBundle } from '@shotleybuilder/svelte-gridlite-views';

	import { goto } from '$app/navigation';
	import { useQueryClient } from '@tanstack/svelte-query';
	import { reparseLat, createLatSessionFromView, type QueueItem } from '$lib/api/lat';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';
	import ParseReviewModal from '$lib/components/ParseReviewModal.svelte';
	import LatParseDialog from '$lib/components/LatParseDialog.svelte';

	const queryClient = useQueryClient();

	// ── PGLite + GridLite state ─────────────────────────────────────

	let db: PGLiteWithExtensions | null = null;
	let ready = false;
	let gridRef: GridLite;
	let error: string | null = null;

	// View store
	let viewStore: ViewStoreBundle | null = null;

	// Saved views state
	let showSaveModal = false;
	let capturedConfig: ViewConfig | null = null;

	// Track current query for GridLite
	let currentQuery: string = '';
	let currentFamily: string | null = null;
	let currentViewName: string | null = null;

	// ── SQL query builders ──────────────────────────────────────────

	const SIX_MONTHS_INTERVAL = "6 months";

	const QUEUE_BASE_WHERE = `
		is_making = true
		AND (making_classification IS NULL OR making_classification != 'not_making')
		AND (live IS NULL OR live != '❌ Revoked / Repealed / Abolished')
		AND title_en IS NOT NULL
		AND family IS NOT NULL
		AND family != '_todo'
		AND family != '🖤 X: No Family'`;

	const QUEUE_LAT_WHERE = `
		AND (
			lat_count = 0
			OR (
				updated_at IS NOT NULL
				AND latest_lat_updated_at IS NOT NULL
				AND updated_at > latest_lat_updated_at + INTERVAL '${SIX_MONTHS_INTERVAL}'
			)
		)`;

	const QUEUE_COLUMNS = 'id, name, title_en, year, type_code, family, family_ii, is_making, making_classification, live, live_from_changes, function, updated_at, lat_count, latest_lat_updated_at';

	function getQueryForFamily(family: string): string {
		return `SELECT ${QUEUE_COLUMNS} FROM uk_lrt WHERE ${QUEUE_BASE_WHERE} ${QUEUE_LAT_WHERE} AND family = '${family.replace(/'/g, "''")}' ORDER BY name`;
	}

	function getQueryAll(): string {
		return `SELECT ${QUEUE_COLUMNS} FROM uk_lrt WHERE ${QUEUE_BASE_WHERE} ${QUEUE_LAT_WHERE} ORDER BY name`;
	}

	function getQueryForView(viewName: string): string {
		const family = viewFamilyMapping[viewName];
		if (family) return getQueryForFamily(family);
		if (viewName === 'Missing LAT') {
			return `SELECT ${QUEUE_COLUMNS} FROM uk_lrt WHERE ${QUEUE_BASE_WHERE} AND lat_count = 0 ORDER BY name`;
		}
		if (viewName === 'Stale LAT') {
			return `SELECT ${QUEUE_COLUMNS} FROM uk_lrt WHERE ${QUEUE_BASE_WHERE} AND lat_count > 0 AND updated_at IS NOT NULL AND latest_lat_updated_at IS NOT NULL AND updated_at > latest_lat_updated_at + INTERVAL '${SIX_MONTHS_INTERVAL}' ORDER BY name`;
		}
		if (viewName === 'Live') {
			return `SELECT ${QUEUE_COLUMNS} FROM uk_lrt WHERE family = '💙 OH&S: Occupational / Personal Safety' AND title_en IS NOT NULL ORDER BY name`;
		}
		return getQueryAll();
	}

	// ── State ────────────────────────────────────────────────────────

	let reparsingLaw: string | null = null;
	let reparseMessage = '';
	let reparseError = '';

	// LRT refresh modal state
	let lrtModalOpen = false;
	let lrtModalRecord: Record<string, unknown> | null = null;
	let lrtModalRecordId: string | undefined = undefined;

	// LAT Parse Dialog state
	let showLatDialog = false;

	function handleLatSessionCreated(event: CustomEvent<{ session_id: string }>) {
		showLatDialog = false;
		goto(`/admin/lat/sessions/${event.detail.session_id}`);
	}

	// Reparse View dialog state
	let showReparseViewDialog = false;
	let reparseViewLoading = false;
	let reparseViewError: string | null = null;
	let reparseViewCount = 0;

	async function handleReparseViewConfirm() {
		reparseViewLoading = true;
		reparseViewError = null;
		try {
			const result = await db?.query<{ name: string }>(currentQuery);
			const names = result?.rows.map((r) => r.name) ?? [];
			const label = currentViewName || 'view';
			const sessionResult = await createLatSessionFromView(names, label);
			showReparseViewDialog = false;
			goto(`/admin/lat/sessions/${sessionResult.session_id}`);
		} catch (err) {
			reparseViewError = err instanceof Error ? err.message : String(err);
		} finally {
			reparseViewLoading = false;
		}
	}

	// Inline editing state
	let editingCell: { id: string; field: string } | null = null;
	let editValue: string = '';

	async function updateRecord(id: string, field: string, value: string | boolean | null) {
		try {
			const response = await authFetch(`${API_URL}/api/uk-lrt/${id}`, {
				method: 'PATCH',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ [field]: value })
			});

			if (!response.ok) {
				const err = await response.json();
				throw new Error(err.error || 'Failed to update');
			}
			// Live query auto-updates when Electric syncs the change back to PGLite
		} catch (e) {
			alert(`Update failed: ${e instanceof Error ? e.message : 'Unknown error'}`);
		}
	}

	function startEdit(id: string, field: string, currentValue: string | null) {
		editingCell = { id, field };
		editValue = currentValue ?? '';
	}

	async function saveEdit() {
		if (!editingCell) return;
		const { id, field } = editingCell;
		await updateRecord(id, field, editValue || null);
		editingCell = null;
		editValue = '';
	}

	function cancelEdit() {
		editingCell = null;
		editValue = '';
	}

	function handleEditKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			saveEdit();
		} else if (e.key === 'Escape') {
			cancelEdit();
		}
	}

	// ── Helpers ──────────────────────────────────────────────────────

	/** Template-safe cast helpers (Svelte 4 markup doesn't support TS `as`) */
	function str(v: unknown): string { return String(v ?? ''); }
	function bool(v: unknown): boolean { return Boolean(v); }

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '--';
		return new Date(dateStr).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
	}

	function formatNumber(n: number): string {
		return n.toLocaleString();
	}

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

	// ── Reparse ─────────────────────────────────────────────────────

	async function handleReparse(row: Record<string, unknown>) {
		const lawName = row.name as string;
		reparsingLaw = lawName;
		reparseMessage = '';
		reparseError = '';

		try {
			const result = await reparseLat(lawName);
			reparsingLaw = null;
			reparseMessage = `Re-parsed ${lawName}: ${result.lat.inserted} LAT rows, ${result.annotations.inserted} annotations (${result.duration_ms}ms)`;
			queryClient.invalidateQueries({ queryKey: ['lat'] });
		} catch (e) {
			reparsingLaw = null;
			reparseError = `Failed to re-parse ${lawName}: ${e instanceof Error ? e.message : 'Unknown error'}`;
		}
	}

	// LRT Refresh (Parse & Review modal)
	function openLrtRefresh(row: Record<string, unknown>) {
		lrtModalRecord = row;
		lrtModalRecordId = row.id as string;
		lrtModalOpen = true;
	}

	function closeLrtRefresh() {
		lrtModalOpen = false;
		lrtModalRecord = null;
		lrtModalRecordId = undefined;
	}

	// ── Column definitions ──────────────────────────────────────────

	const familyOptions = {
		health_safety: [
			'💙 FIRE', '💙 FIRE: Dangerous and Explosive Substances', '💙 FOOD',
			'💙 HEALTH: Coronavirus', '💙 HEALTH: Drug & Medicine Safety', '💙 HEALTH: Patient Safety',
			'💙 HEALTH: Public', '💙 OH&S: Gas & Electrical Safety', '💙 OH&S: Mines & Quarries',
			'💙 OH&S: Occupational / Personal Safety', '💙 OH&S: Offshore Safety', '💙 PUBLIC',
			'💙 PUBLIC: Building Safety', '💙 PUBLIC: Consumer / Product Safety',
			'💙 TRANSPORT: Air Safety', '💙 TRANSPORT: Rail Safety', '💙 TRANSPORT: Road Safety',
			'💙 TRANSPORT: Maritime Safety'
		],
		environment: [
			'💚 AGRICULTURE', '💚 AGRICULTURE: Pesticides', '💚 AIR QUALITY',
			'💚 ANIMALS & ANIMAL HEALTH', '💚 ANTARCTICA', '💚 BUILDINGS', '💚 CLIMATE CHANGE',
			'💚 ENERGY', '💚 ENVIRONMENTAL PROTECTION', '💚 FINANCE', '💚 FISHERIES & FISHING',
			'💚 GMOs', '💚 HISTORIC ENVIRONMENT', '💚 MARINE & RIVERINE', '💚 NOISE',
			'💚 NUCLEAR & RADIOLOGICAL', '💚 OIL & GAS - OFFSHORE - PETROLEUM',
			'💚 PLANNING & INFRASTRUCTURE', '💚 PLANT HEALTH', '💚 POLLUTION',
			'💚 TOWN & COUNTRY PLANNING', '💚 TRANSPORT', '💚 TRANSPORT: Aviation',
			'💚 TRANSPORT: Harbours & Shipping', '💚 TRANSPORT: Railways & Rail Transport',
			'💚 TRANSPORT: Roads & Vehicles', '💚 TREES: Forestry & Timber', '💚 WASTE',
			'💚 WATER & WASTEWATER', '💚 WILDLIFE & COUNTRYSIDE'
		],
		hr: ['💜 HR: Employment', '💜 HR: Insurance / Compensation / Wages / Benefits', '💜 HR: Working Time']
	};

	const makingClassificationOptions = [
		{ value: 'making', label: 'Making' },
		{ value: 'not_making', label: 'Not Making' },
		{ value: 'uncertain', label: 'Uncertain' }
	];

	const liveStatusOptions = [
		{ value: '✔ In force', label: '✔ In force' },
		{ value: '⭕ Part Revocation / Repeal', label: '⭕ Part Revocation / Repeal' },
		{ value: '❌ Revoked / Repealed / Abolished', label: '❌ Revoked / Repealed / Abolished' },
		{ value: '⚠ Planned', label: '⚠ Planned' }
	];

	const columns: ColumnConfig[] = [
		{ name: 'name', label: 'Law Name', width: 160, dataType: 'text' },
		{ name: 'title_en', label: 'Title', width: 350, dataType: 'text' },
		{ name: 'family', label: 'Family', width: 200, dataType: 'text' },
		{ name: 'family_ii', label: 'Family II', width: 200, dataType: 'text' },
		{ name: 'is_making', label: 'Is Making', width: 90, dataType: 'text' },
		{ name: 'making_classification', label: 'Making Classification', width: 160, dataType: 'text', selectOptions: makingClassificationOptions },
		{ name: 'year', label: 'Year', width: 80, dataType: 'number' },
		{ name: 'live', label: 'Status', width: 100, dataType: 'text', selectOptions: liveStatusOptions },
		{ name: 'live_from_changes', label: 'From Changes', width: 130, dataType: 'text' },
		{ name: 'function', label: 'Function', width: 150, dataType: 'text' },
		{ name: 'lat_count', label: 'LAT Rows', width: 80, dataType: 'number' },
		{ name: 'updated_at', label: 'LRT Updated', width: 110, dataType: 'date', format: (v) => formatDate(v as string | null) },
		{ name: 'latest_lat_updated_at', label: 'LAT Updated', width: 110, dataType: 'date', format: (v) => formatDate(v as string | null) }
	];

	// ── Family-based view definitions ───────────────────────────────

	interface FamilyViewDef {
		name: string;
		family: string;
		group: 'safety' | 'environment' | 'hr';
	}

	const familyViewDefs: FamilyViewDef[] = [
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
		{ name: 'Employment', family: '💜 HR: Employment', group: 'hr' },
		{ name: 'Insurance / Compensation', family: '💜 HR: Insurance / Compensation / Wages / Benefits', group: 'hr' },
		{ name: 'Working Time', family: '💜 HR: Working Time', group: 'hr' },
	];

	// Mappings
	const viewFamilyMapping: Record<string, string> = {};
	for (const def of familyViewDefs) viewFamilyMapping[def.name] = def.family;

	const viewGroupMapping: Record<string, string> = {};
	for (const def of familyViewDefs) viewGroupMapping[def.name] = def.group;
	viewGroupMapping['All Queue'] = 'queue';
	viewGroupMapping['Missing LAT'] = 'queue';
	viewGroupMapping['Stale LAT'] = 'queue';
	viewGroupMapping['Live'] = 'analytics';

	// Column visibility sets
	const allCols = columns.map((c) => c.name);
	const familyCols = ['name', 'title_en', 'is_making', 'making_classification', 'year', 'live', 'function', 'lat_count', 'updated_at', 'latest_lat_updated_at'];
	const liveCols = ['name', 'title_en', 'year', 'live', 'live_from_changes', 'lat_count'];

	// Helper to build column visibility map
	function colVis(visibleCols: string[]): Record<string, boolean> {
		const vis: Record<string, boolean> = {};
		for (const col of columns) vis[col.name] = visibleCols.includes(col.name);
		return vis;
	}

	function makeViewConfig(opts: {
		visibleCols: string[];
		filters?: FilterCondition[];
		sorting?: SortConfig[];
		grouping?: GroupConfig[];
	}): ViewConfig {
		return {
			filters: opts.filters ?? [],
			filterLogic: 'and',
			sorting: opts.sorting ?? [{ column: 'updated_at', direction: 'asc' }],
			grouping: opts.grouping ?? [{ column: 'family' }, { column: 'year' }],
			columnVisibility: colVis(opts.visibleCols),
			columnOrder: opts.visibleCols,
			columnWidths: {},
			pageSize: 50
		};
	}

	interface ViewGroupDef { id: string; name: string; order: number }
	const viewGroups: ViewGroupDef[] = [
		{ id: 'queue', name: 'Queue', order: 0 },
		{ id: 'safety', name: '💙 S', order: 1 },
		{ id: 'environment', name: '💚 E', order: 2 },
		{ id: 'hr', name: '💜 HR', order: 3 },
		{ id: 'analytics', name: 'Analytics', order: 4 }
	];

	interface ViewDef {
		name: string;
		description: string;
		config: ViewConfig;
		isDefault?: boolean;
	}

	const defaultViews: ViewDef[] = [
		{
			name: 'All Queue',
			description: 'All making laws needing LAT parsing — missing and stale.',
			config: makeViewConfig({ visibleCols: allCols }),
			isDefault: true
		},
		{
			name: 'Missing LAT',
			description: 'LRT records with making function that have no LAT data at all.',
			config: makeViewConfig({ visibleCols: allCols })
		},
		{
			name: 'Stale LAT',
			description: 'LRT records where LAT data exists but is more than 6 months out of date.',
			config: makeViewConfig({ visibleCols: allCols })
		},
		...familyViewDefs.map((def): ViewDef => ({
			name: def.name,
			description: `${def.family} — LAT parse candidates`,
			config: makeViewConfig({ visibleCols: familyCols, sorting: [{ column: 'name', direction: 'asc' }], grouping: [{ column: 'year' }] })
		})),
		{
			name: 'Live',
			description: 'Live status reconciliation — OH&S Occupational / Personal Safety',
			config: makeViewConfig({ visibleCols: liveCols, sorting: [{ column: 'name', direction: 'asc' }], grouping: [] })
		}
	];

	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));

	// ── Sidebar state ───────────────────────────────────────────────

	let sidebarOpen = false;

	interface SidebarViewItem { id: string; name: string; groupId: string; order: number; isDefault?: boolean }
	let sidebarViews: SidebarViewItem[] = [];

	function rebuildSidebarViews(views: SavedView[]) {
		sidebarViews = views
			.filter((v) => defaultViews.some((dv) => dv.name === v.name))
			.map((v): SidebarViewItem => ({
				id: v.id,
				name: v.name,
				groupId: viewGroupMapping[v.name] || 'queue',
				order: viewOrderMap.get(v.name) ?? 1000,
				isDefault: defaultViews.find((dv) => dv.name === v.name)?.isDefault
			}))
			.sort((a, b) => a.order - b.order);
	}

	// ── View lifecycle ──────────────────────────────────────────────

	async function seedDefaultViews() {
		if (!viewStore) return;
		const { actions, savedViews: svStore } = viewStore;
		await actions.waitForReady();

		let currentViews: SavedView[] = [];
		const unsub = svStore.subscribe((v) => { currentViews = v; });

		// Deduplicate
		const existingViews = new Map<string, string>();
		for (const view of currentViews) {
			if (existingViews.has(view.name)) {
				try { await actions.delete(view.id); } catch { /* dedup */ }
			} else {
				existingViews.set(view.name, view.id);
			}
		}

		// Seed missing
		const missingViews = defaultViews.filter((v) => !existingViews.has(v.name));
		let defaultViewId: string | null = null;

		const defaultViewDef = defaultViews.find((v) => v.isDefault);
		if (defaultViewDef && existingViews.has(defaultViewDef.name)) {
			defaultViewId = existingViews.get(defaultViewDef.name) || null;
		}

		for (const view of missingViews) {
			try {
				const saved = await actions.save({ name: view.name, description: view.description, config: view.config });
				if (view.isDefault && saved?.id) defaultViewId = saved.id;
				existingViews.set(view.name, saved?.id || '');
			} catch (err) {
				console.error('[LAT Queue] Failed to seed view:', view.name, err);
			}
		}

		// Auto-select default view
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => { activeId = v; })();
		if (defaultViewId && !activeId) {
			const loadedView = await actions.load(defaultViewId);
			if (loadedView) {
				switchToView('All Queue');
				setTimeout(() => applyViewToGrid(loadedView), 50);
			}
		} else if (activeId) {
			let activeView: SavedView | null = null;
			svStore.subscribe((views) => { activeView = views.find((v) => v.id === activeId) ?? null; })();
			if (activeView) {
				switchToView((activeView as SavedView).name);
			}
		}

		rebuildSidebarViews(currentViews);
		unsub();
		svStore.subscribe((views) => rebuildSidebarViews(views));
	}

	function applyViewToGrid(view: SavedView) {
		if (!gridRef) return;
		const cfg = view.config;
		gridRef.setFilters(cfg.filters as FilterCondition[], cfg.filterLogic);
		gridRef.setSorting(cfg.sorting as SortConfig[]);
		gridRef.setGrouping(cfg.grouping as GroupConfig[]);
	}

	function switchToView(viewName: string) {
		currentViewName = viewName;
		currentQuery = getQueryForView(viewName);
		currentFamily = viewFamilyMapping[viewName] ?? null;
	}

	async function handleViewSelect(viewItem: SidebarViewItem) {
		if (!viewStore) return;
		const view = await viewStore.actions.load(viewItem.id);
		if (view) {
			switchToView(viewItem.name);
			setTimeout(() => applyViewToGrid(view), 50);
		}
		sidebarOpen = false;
	}

	// ── Grid state management ───────────────────────────────────────

	let latestGridState: GridState | null = null;

	function handleStateChange(state: GridState) {
		latestGridState = state;
	}

	function captureCurrentConfig(state: GridState): ViewConfig {
		return {
			filters: state.filters,
			filterLogic: state.filterLogic,
			sorting: state.sorting,
			grouping: state.grouping,
			columnVisibility: state.columnVisibility,
			columnOrder: state.columnOrder,
			columnWidths: state.columnSizing,
			pageSize: state.pagination.pageSize
		};
	}

	function handleSaveView() {
		if (!latestGridState) return;
		capturedConfig = captureCurrentConfig(latestGridState);
		showSaveModal = true;
	}

	async function handleUpdateView() {
		if (!viewStore || !latestGridState) return;
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => { activeId = v; })();
		if (!activeId) return;
		try {
			const config = captureCurrentConfig(latestGridState);
			await viewStore.actions.update(activeId, { config });
		} catch (err) {
			console.error('[LAT Queue] Failed to update view:', err);
		}
	}

	function handleViewSaved(event: CustomEvent<{ id: string; name: string }>) {
		console.log('[LAT Queue] View saved:', event.detail.name);
	}

	// ── Reactive state ──────────────────────────────────────────────

	$: if ($syncStatus.error) { error = $syncStatus.error; }
	$: isLoading = !$syncStatus.connected && !ready;

	let hasActiveView = false;
	$: if (viewStore) {
		viewStore.activeViewId.subscribe((v) => { hasActiveView = !!v; })();
	}

	// Reparse view record count
	$: if (showReparseViewDialog && db && currentQuery) {
		db.query<{ count: string }>(`SELECT COUNT(*) as count FROM (${currentQuery}) sub`).then((r) => {
			reparseViewCount = parseInt(r.rows[0]?.count ?? '0', 10);
		}).catch(() => { reparseViewCount = 0; });
	}

	// Stats from current query
	let statTotal = 0;
	let statMissing = 0;
	let statStale = 0;

	async function refreshStats() {
		if (!db || !currentQuery) return;
		try {
			const total = await db.query<{ count: string }>(`SELECT COUNT(*) as count FROM (${currentQuery}) sub`);
			statTotal = parseInt(total.rows[0]?.count ?? '0', 10);
			// For detailed stats, only relevant when showing the queue
			if (currentQuery.includes('lat_count')) {
				const missing = await db.query<{ count: string }>(`SELECT COUNT(*) as count FROM (${currentQuery}) sub WHERE lat_count = 0`);
				statMissing = parseInt(missing.rows[0]?.count ?? '0', 10);
				statStale = statTotal - statMissing;
			} else {
				statMissing = 0;
				statStale = 0;
			}
		} catch { /* ignore */ }
	}

	$: if (ready && db && currentQuery) {
		refreshStats();
	}

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await runViewMigrations(db as any);
			viewStore = initViewStore(db as any, 'lat-queue');
			ready = true;
			// Default query until views load
			currentQuery = getQueryAll();
			setTimeout(() => seedDefaultViews(), 100);
		}
	});

	onDestroy(() => {
		viewStore?.destroy();
	});
</script>

<svelte:head>
	<title>LAT Queue — SertantAI Legal</title>
</svelte:head>

<div class="flex h-full relative">
	<!-- Mobile sidebar overlay -->
	{#if sidebarOpen}
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="fixed inset-0 bg-black/30 z-30 lg:hidden" on:click={() => (sidebarOpen = false)} />
	{/if}

	<!-- View Sidebar -->
	<div class="shrink-0 {sidebarOpen ? 'fixed inset-y-0 left-0 z-40 lg:static lg:z-auto' : 'hidden lg:block'}">
		<div class="w-[220px] h-full bg-white border-r border-gray-200 overflow-y-auto py-2">
			{#each viewGroups as group}
				{@const groupViews = sidebarViews.filter((v) => v.groupId === group.id)}
				{#if groupViews.length > 0}
					<div class="px-3 py-1.5 text-xs font-semibold text-gray-500 uppercase tracking-wider">{group.name}</div>
					{#each groupViews as view}
						<button
							class="w-full text-left px-3 py-1.5 text-sm text-gray-700 hover:bg-gray-100 truncate"
							on:click={() => handleViewSelect(view)}
						>
							{view.name}
						</button>
					{/each}
				{/if}
			{/each}
		</div>
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
					class="px-4 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
				>
					Parse Family
				</button>
				<button
					on:click={() => (showReparseViewDialog = true)}
					disabled={!currentQuery}
					class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
				>
					Reparse View ({statTotal})
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
		{#if !isLoading && ready}
			<div class="grid grid-cols-1 md:grid-cols-4 gap-4">
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">View Total</div>
					<div class="text-2xl font-bold text-gray-900">{formatNumber(statTotal)}</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Missing LAT</div>
					<div class="text-2xl font-bold text-red-600">{formatNumber(statMissing)}</div>
				</div>
				<div class="bg-white rounded-lg border border-gray-200 p-4">
					<div class="text-sm text-gray-500">Stale LAT</div>
					<div class="text-2xl font-bold text-amber-600">{formatNumber(statStale)}</div>
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
				<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700" on:click={() => window.location.reload()}>Retry</button>
			</div>
		{:else if ready && db && currentQuery}
			{#key currentQuery}
			<GridLite
				bind:this={gridRef}
				{db}
				query={currentQuery}
				onStateChange={handleStateChange}
				config={{
					id: 'lat-queue',
					columns,
					defaultSorting: [{ column: 'updated_at', direction: 'asc' }],
					defaultVisibleColumns: allCols,
					pagination: { pageSize: 50 }
				}}
				features={{
					columnVisibility: true,
					columnResizing: true,
					columnReordering: true,
					filtering: true,
					sorting: true,
					pagination: false,
					grouping: true,
					globalSearch: true
				}}
			>
				<!-- Save View Buttons -->
				<svelte:fragment slot="toolbar-start">
					{#if hasActiveView}
						<div class="inline-flex rounded-md shadow-sm">
							<button
								type="button"
								on:click={handleUpdateView}
								class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-l-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
								</svg>
								Save View
							</button>
							<button
								type="button"
								on:click={handleSaveView}
								class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-indigo-600 border-l border-indigo-500 rounded-r-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
							>
								<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
								</svg>
							</button>
						</div>
					{:else}
						<button
							type="button"
							on:click={handleSaveView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
							</svg>
							Save View
						</button>
					{/if}
				</svelte:fragment>

				<!-- Custom cell rendering -->
				<svelte:fragment slot="cell" let:value let:row let:column>
					{#if column === 'name'}
						{@const rowName = str(row.name)}
						<div class="flex items-center gap-1">
							<button
								on:click={() => openLrtRefresh(row)}
								class="px-1.5 py-0.5 text-xs font-medium rounded bg-indigo-600 text-white hover:bg-indigo-700 shrink-0"
								title="Refresh LRT metadata from legislation.gov.uk"
							>
								LRT
							</button>
							<button
								on:click={() => handleReparse(row)}
								disabled={reparsingLaw === rowName}
								class="px-1.5 py-0.5 text-xs font-medium rounded shrink-0 {reparsingLaw === rowName ? 'bg-gray-100 text-gray-400 cursor-not-allowed' : 'bg-blue-600 text-white hover:bg-blue-700'}"
								title="Re-parse LAT articles and annotations"
							>
								{reparsingLaw === rowName ? '...' : 'LAT'}
							</button>
							<span class="font-mono text-gray-700 truncate">{value}</span>
						</div>
					{:else if column === 'title_en'}
						<span class="text-gray-900 whitespace-normal leading-snug">{value || ''}</span>
					{:else if column === 'family'}
						{@const rowId = str(row.id)}
						{#if editingCell?.id === rowId && editingCell?.field === 'family'}
							<select
								class="w-full text-sm border border-blue-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
								bind:value={editValue}
								on:blur={saveEdit}
								on:keydown={handleEditKeydown}
							>
								<option value="">-- None --</option>
								<optgroup label="Health & Safety">
									{#each familyOptions.health_safety as opt}<option value={opt}>{opt}</option>{/each}
								</optgroup>
								<optgroup label="Environment">
									{#each familyOptions.environment as opt}<option value={opt}>{opt}</option>{/each}
								</optgroup>
								<optgroup label="HR">
									{#each familyOptions.hr as opt}<option value={opt}>{opt}</option>{/each}
								</optgroup>
							</select>
						{:else}
							<button
								class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate"
								on:dblclick={() => startEdit(str(row.id), 'family', str(value) || null)}
								title="Double-click to edit"
							>
								<span class="text-gray-700 whitespace-normal leading-snug">{value || '-'}</span>
							</button>
						{/if}
					{:else if column === 'family_ii'}
						{@const rowId2 = str(row.id)}
						{#if editingCell?.id === rowId2 && editingCell?.field === 'family_ii'}
							<select
								class="w-full text-sm border border-blue-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
								bind:value={editValue}
								on:blur={saveEdit}
								on:keydown={handleEditKeydown}
							>
								<option value="">-- None --</option>
								<optgroup label="Health & Safety">
									{#each familyOptions.health_safety as opt}<option value={opt}>{opt}</option>{/each}
								</optgroup>
								<optgroup label="Environment">
									{#each familyOptions.environment as opt}<option value={opt}>{opt}</option>{/each}
								</optgroup>
								<optgroup label="HR">
									{#each familyOptions.hr as opt}<option value={opt}>{opt}</option>{/each}
								</optgroup>
							</select>
						{:else}
							<button
								class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate"
								on:dblclick={() => startEdit(str(row.id), 'family_ii', str(value) || null)}
								title="Double-click to edit"
							>
								{value || '-'}
							</button>
						{/if}
					{:else if column === 'is_making'}
						<button
							class="w-full text-center hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
							on:click={() => updateRecord(str(row.id), 'is_making', !bool(row.is_making))}
							title="Click to toggle"
						>
							{#if row.is_making}
								<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700">Yes</span>
							{:else}
								<span class="text-gray-400">-</span>
							{/if}
						</button>
					{:else if column === 'making_classification'}
						{@const rowId3 = str(row.id)}
						{#if editingCell?.id === rowId3 && editingCell?.field === 'making_classification'}
							<select
								class="w-full text-sm border border-blue-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
								bind:value={editValue}
								on:blur={saveEdit}
								on:keydown={handleEditKeydown}
							>
								<option value="">-- None --</option>
								{#each makingClassificationOptions as opt}
									<option value={opt.value}>{opt.label}</option>
								{/each}
							</select>
						{:else}
							<button
								class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
								on:dblclick={() => startEdit(str(row.id), 'making_classification', str(value) || null)}
								title="Double-click to edit"
							>
								{#if value === 'making'}
									<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700">Making</span>
								{:else if value === 'not_making'}
									<span class="px-1.5 py-0.5 text-xs rounded bg-red-100 text-red-700">Not Making</span>
								{:else if value === 'uncertain'}
									<span class="px-1.5 py-0.5 text-xs rounded bg-amber-100 text-amber-700">Uncertain</span>
								{:else}
									<span class="text-gray-400">-</span>
								{/if}
							</button>
						{/if}
					{:else if column === 'live'}
						{@const status = str(value)}
						<span class="inline-flex px-2 py-0.5 text-xs font-medium rounded {status === '✔ In force' ? 'bg-green-100 text-green-800' : status === '⭕ Part Revocation / Repeal' ? 'bg-amber-100 text-amber-800' : 'bg-gray-100 text-gray-800'}">
							{status || '-'}
						</span>
					{:else if column === 'function'}
						{@const fns = parseFunctionKeys(row.function)}
						{#if fns?.includes('Making')}
							<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700">Making</span>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
					{:else}
						{value ?? '-'}
					{/if}
				</svelte:fragment>
			</GridLite>
			{/key}
		{/if}
	</div>
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig && viewStore}
	<SaveViewModal bind:open={showSaveModal} {viewStore} config={capturedConfig} on:save={handleViewSaved} />
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
			name: str(lrtModalRecord.name),
			Title_EN: str(lrtModalRecord.title_en),
			type_code: String(lrtModalRecord.type_code ?? ''),
			Year: Number(lrtModalRecord.year ?? 0),
			Number: ''
		}]}
		recordId={lrtModalRecordId}
		open={lrtModalOpen}
		on:close={closeLrtRefresh}
	/>
{/if}

<!-- Reparse View Confirmation Dialog -->
{#if showReparseViewDialog}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" on:click|self={() => (showReparseViewDialog = false)}>
		<div class="bg-white rounded-lg shadow-xl w-full max-w-md mx-4">
			<div class="px-6 py-4 border-b border-gray-200">
				<h3 class="text-lg font-semibold text-gray-900">Reparse View</h3>
			</div>
			<div class="px-6 py-4 space-y-3">
				<div class="text-sm text-gray-600">
					<p><span class="font-medium">View:</span> {currentViewName || 'All Queue'}</p>
					{#if currentFamily}
						<p><span class="font-medium">Family:</span> {currentFamily}</p>
					{/if}
					<p class="mt-2">
						<span class="text-2xl font-bold text-gray-900">{reparseViewCount}</span>
						<span class="text-gray-500 ml-1">records will be added to a new parse session</span>
					</p>
				</div>
				{#if reparseViewError}
					<div class="px-3 py-2 text-sm bg-red-50 text-red-700 rounded border border-red-200">
						{reparseViewError}
					</div>
				{/if}
			</div>
			<div class="px-6 py-4 border-t border-gray-200 flex justify-end space-x-3">
				<button
					on:click={() => (showReparseViewDialog = false)}
					class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
					disabled={reparseViewLoading}
				>
					Cancel
				</button>
				<button
					on:click={handleReparseViewConfirm}
					disabled={reparseViewLoading || reparseViewCount === 0}
					class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
				>
					{#if reparseViewLoading}
						Creating...
					{:else}
						Create Reparse Session
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}
