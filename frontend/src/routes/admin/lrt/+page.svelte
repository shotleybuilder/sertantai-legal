<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { TableKit, applyFilters } from '@shotleybuilder/svelte-table-kit';
	import type { ColumnDef } from '@tanstack/svelte-table';
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
	import { authFetch } from '$lib/api/client';

	// PGLite sync
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { createDynamicLiveQuery } from '$lib/pglite/live-store';
	import type { FilterCondition } from '@shotleybuilder/svelte-table-kit';

	// Record viewing & parsing
	import ParseReviewModal from '$lib/components/ParseReviewModal.svelte';
	import RecordCardModal from '$lib/components/RecordCardModal.svelte';
	import ReparseDialog from '$lib/components/ReparseDialog.svelte';
	import { createReparseFromView } from '$lib/api/scraper';
	import { goto } from '$app/navigation';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// Types
	interface UkLrtRecord {
		[key: string]: unknown; // Index signature for TableKit compatibility
		id: string;
		name: string;
		title_en: string;
		year: number | null;
		number: string | null;
		type_code: string | null;
		type_desc: string | null;
		family: string | null;
		family_ii: string | null;
		si_code: string | null;
		md_subjects: Record<string, unknown> | null;
		md_date: string | null;
		geo_extent: string | null;
		function: string[] | null;
		is_making: boolean | null;
		live: string | null;
		latest_amend_date: string | null;
		latest_rescind_date: string | null;
		created_at: string | null;
	}

	// Helper to type cast row data from TableKit cell slot
	function asRecord(row: unknown): UkLrtRecord {
		return row as UkLrtRecord;
	}

	// Family options grouped by category
	const familyOptions = {
		health_safety: [
			'💙 FIRE',
			'💙 FIRE: Dangerous and Explosive Substances',
			'💙 FOOD',
			'💙 HEALTH: Coronavirus',
			'💙 HEALTH: Drug & Medicine Safety',
			'💙 HEALTH: Patient Safety',
			'💙 HEALTH: Public',
			'💙 OH&S: Gas & Electrical Safety',
			'💙 OH&S: Mines & Quarries',
			'💙 OH&S: Occupational / Personal Safety',
			'💙 OH&S: Offshore Safety',
			'💙 PUBLIC',
			'💙 PUBLIC: Building Safety',
			'💙 PUBLIC: Consumer / Product Safety',
			'💙 TRANSPORT: Air Safety',
			'💙 TRANSPORT: Rail Safety',
			'💙 TRANSPORT: Road Safety',
			'💙 TRANSPORT: Maritime Safety'
		],
		environment: [
			'💚 AGRICULTURE',
			'💚 AGRICULTURE: Pesticides',
			'💚 AIR QUALITY',
			'💚 ANIMALS & ANIMAL HEALTH',
			'💚 ANTARCTICA',
			'💚 BUILDINGS',
			'💚 CLIMATE CHANGE',
			'💚 ENERGY',
			'💚 ENVIRONMENTAL PROTECTION',
			'💚 FINANCE',
			'💚 FISHERIES & FISHING',
			'💚 GMOs',
			'💚 HISTORIC ENVIRONMENT',
			'💚 MARINE & RIVERINE',
			'💚 NOISE',
			'💚 NUCLEAR & RADIOLOGICAL',
			'💚 OIL & GAS - OFFSHORE - PETROLEUM',
			'💚 PLANNING & INFRASTRUCTURE',
			'💚 PLANT HEALTH',
			'💚 POLLUTION',
			'💚 TOWN & COUNTRY PLANNING',
			'💚 TRANSPORT',
			'💚 TRANSPORT: Aviation',
			'💚 TRANSPORT: Harbours & Shipping',
			'💚 TRANSPORT: Railways & Rail Transport',
			'💚 TRANSPORT: Roads & Vehicles',
			'💚 TREES: Forestry & Timber',
			'💚 WASTE',
			'💚 WATER & WASTEWATER',
			'💚 WILDLIFE & COUNTRYSIDE'
		],
		hr: ['💜 HR: Employment', '💜 HR: Insurance / Compensation / Wages / Benefits', '💜 HR: Working Time']
	};

	// Function options
	const functionOptions = ['Making', 'Amending', 'Revoking', 'Commencing', 'Enacting'];

	// State — PGLite live query: auto-updates when Electric syncs changes back from backend
	const LRT_COLUMNS = 'id, name, title_en, year, number, type_code, type_desc, family, family_ii, si_code, md_subjects, md_date, geo_extent, function, is_making, live, live_source, live_conflict, live_from_changes, live_from_metadata, latest_amend_date, latest_rescind_date, created_at';
	const { store: dataStore, update: updateQuery, destroy: destroyLiveQuery } = createDynamicLiveQuery<UkLrtRecord>('id');

	$: data = $dataStore;
	$: filteredData = applyFilters(data, viewFilters) as UkLrtRecord[];
	$: totalCount = data.length;
	$: isLoading = !$syncStatus.connected && data.length === 0;
	let error: string | null = null;

	// Watch syncStatus for errors
	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}

	// Track current family filter for query updates
	let currentFamily: string | null = null;

	// Run query for the selected family (or all records if null)
	function queryForFamily(family: string | null) {
		currentFamily = family;
		if (family) {
			updateQuery(`SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE family = $1 ORDER BY type_desc, name`, [family]);
		} else {
			updateQuery(`SELECT ${LRT_COLUMNS} FROM uk_lrt ORDER BY name`, []);
		}
	}

	// Run a custom SQL query (for non-family views like Recent)
	function queryCustom(sql: string, params: unknown[]) {
		currentFamily = null;
		updateQuery(sql, params);
	}

	// Live query auto-refreshes via PGLite triggers — no manual refresh needed

	// Editing state
	let editingCell: { id: string; field: string } | null = null;
	let editValue: string | string[] = '';

	// Record Card modal state (back of card — view all fields)
	let cardModalOpen = false;
	let cardModalRecord: UkLrtRecord | null = null;

	function openRecordCard(record: UkLrtRecord) {
		cardModalRecord = record;
		cardModalOpen = true;
	}

	function closeRecordCard() {
		cardModalOpen = false;
		cardModalRecord = null;
	}

	// ParseReviewModal state
	let viewModalOpen = false;
	let viewModalRecord: UkLrtRecord | null = null;

	// Open modal in streaming parse & review mode
	function openParseReviewModal(record: UkLrtRecord) {
		viewModalRecord = record;
		viewModalOpen = true;
	}

	function closeViewModal() {
		viewModalOpen = false;
		viewModalRecord = null;
	}

	// Reparse dialog state
	let showReparseDialog = false;

	function handleReparseCreated(event: CustomEvent<{ session_id: string }>) {
		showReparseDialog = false;
		goto(`/admin/scrape/sessions/${event.detail.session_id}`);
	}

	// Reparse View dialog state
	let showReparseViewDialog = false;
	let reparseViewLoading = false;
	let reparseViewError: string | null = null;

	$: activeViewName = $savedViews.find((v) => v.id === $activeViewId)?.name || null;

	async function handleReparseViewConfirm() {
		reparseViewLoading = true;
		reparseViewError = null;
		try {
			const names = filteredData.map((r) => r.name);
			const label = activeViewName || 'view';
			const result = await createReparseFromView(names, label);
			showReparseViewDialog = false;
			goto(`/admin/scrape/sessions/${result.session_id}`);
		} catch (err) {
			reparseViewError = err instanceof Error ? err.message : String(err);
		} finally {
			reparseViewLoading = false;
		}
	}

	// Saved views state
	let showSaveModal = false;
	let capturedConfig: TableConfig | null = null;
	let sidebarOpen = false;

	// View configuration state (for applying saved views)
	let viewColumns: string[] = [];
	let viewColumnOrder: string[] = [];
	let viewGrouping: string[] = [];
	let configVersion = 0;

	// ── Family-based views ─────────────────────────────────────────
	// Each family value becomes its own view. Views are grouped into S (Safety),
	// E (Environment), HR. Selecting a view queries PGLite for that family only
	// and groups results by type_desc.

	const VIEW_COLUMNS = ['actions', 'name', 'title_en', 'year', 'number', 'type_code', 'type_desc', 'live', 'function', 'is_making', 'geo_extent'];

	interface FamilyViewDef {
		name: string;
		family: string; // exact value in uk_lrt.family column
		group: 'safety' | 'environment' | 'hr';
	}

	const familyViewDefs: FamilyViewDef[] = [
		// Safety (💙 prefix in DB)
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
		// Environment (💚 prefix in DB)
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
		// HR (💜 prefix in DB)
		{ name: 'Employment', family: '💜 HR: Employment', group: 'hr' },
		{ name: 'Insurance / Compensation', family: '💜 HR: Insurance / Compensation / Wages / Benefits', group: 'hr' },
		{ name: 'Working Time', family: '💜 HR: Working Time', group: 'hr' },
	];

	// Build defaultViews from family definitions + recent views
	const currentYear = new Date().getFullYear();
	const RECENT_COLUMNS = ['actions', 'name', 'title_en', 'year', 'type_code', 'family', 'live'];

	type ViewDef = {
		name: string;
		description: string;
		columns: string[];
		filters?: Array<{ columnId: string; operator: string; value: unknown }>;
		sort?: { columnId: string; direction: 'asc' | 'desc' } | null;
		grouping?: string[];
		isDefault?: boolean;
		family?: string;
		customQuery?: { sql: string; params: unknown[] };
	};

	const recentViews: ViewDef[] = [
		{
			name: 'Recently Added',
			description: 'Records added to the database in the last month.',
			columns: [...RECENT_COLUMNS, 'created_at'],
			sort: { columnId: 'created_at', direction: 'desc' },
			grouping: ['type_desc'],
			customQuery: {
				sql: `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE created_at >= NOW() - INTERVAL '1 month' ORDER BY created_at DESC`,
				params: []
			}
		},
		{
			name: 'Recently Amended',
			description: 'Laws amended in the last 3 years, sorted by most recent amendment date.',
			columns: [...RECENT_COLUMNS, 'latest_amend_date'],
			sort: { columnId: 'latest_amend_date', direction: 'desc' },
			grouping: ['type_desc'],
			customQuery: {
				sql: `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE latest_amend_date >= $1 ORDER BY latest_amend_date DESC`,
				params: [`${currentYear - 2}-01-01`]
			}
		},
		{
			name: 'Recently Rescinded',
			description: 'Laws rescinded (repealed/revoked) in the last 3 years.',
			columns: [...RECENT_COLUMNS, 'latest_rescind_date'],
			sort: { columnId: 'latest_rescind_date', direction: 'desc' },
			grouping: ['type_desc'],
			customQuery: {
				sql: `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE latest_rescind_date >= $1 ORDER BY latest_rescind_date DESC`,
				params: [`${currentYear - 2}-01-01`]
			}
		}
	];

	const LIVE_VIEW_COLUMNS = ['actions', 'name', 'title_en', 'year', 'live', 'live_source', 'live_from_changes', 'live_from_metadata', 'live_conflict'];

	const analyticsViews: ViewDef[] = [
		{
			name: 'Live',
			description: 'Live status reconciliation — OH&S Occupational / Personal Safety',
			columns: LIVE_VIEW_COLUMNS,
			sort: { columnId: 'name', direction: 'asc' },
			grouping: [],
			customQuery: {
				sql: `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE family = $1 AND title_en IS NOT NULL ORDER BY name`,
				params: ['💙 OH&S: Occupational / Personal Safety']
			}
		}
	];

	const defaultViews: ViewDef[] = [
		...familyViewDefs.map((def, i): ViewDef => ({
			name: def.name,
			description: `${def.family} — grouped by type`,
			columns: VIEW_COLUMNS,
			sort: { columnId: 'name', direction: 'asc' as const },
			grouping: ['type_desc'],
			isDefault: i === 0,
			family: def.family
		})),
		...recentViews,
		...analyticsViews
	];

	// ── View groups & sidebar mapping ───────────────────────────────

	const viewGroups: ViewGroup[] = [
		{ id: 'recent', name: 'Recent', order: 0 },
		{ id: 'safety', name: '💙 S', order: 1 },
		{ id: 'environment', name: '💚 E', order: 2 },
		{ id: 'hr', name: '💜 HR', order: 3 },
		{ id: 'analytics', name: 'Analytics', order: 4 }
	];

	// Map view name → group id
	const viewGroupMapping: Record<string, string> = {};
	for (const def of familyViewDefs) {
		viewGroupMapping[def.name] = def.group;
	}
	viewGroupMapping['Recently Added'] = 'recent';
	viewGroupMapping['Recently Amended'] = 'recent';
	viewGroupMapping['Recently Rescinded'] = 'recent';
	viewGroupMapping['Live'] = 'analytics';

	// Map view name → family value (for PGLite query)
	const viewFamilyMapping: Record<string, string> = {};
	for (const def of familyViewDefs) {
		viewFamilyMapping[def.name] = def.family;
	}

	// Map view name → custom query (for non-family views)
	const viewCustomQueryMapping: Record<string, { sql: string; params: unknown[] }> = {};
	for (const view of [...recentViews, ...analyticsViews]) {
		if (view.customQuery) {
			viewCustomQueryMapping[view.name] = view.customQuery;
		}
	}

	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));
	const lrtViewNames = new Set(defaultViews.map((v) => v.name));

	$: sidebarViews = $savedViews
		.filter((view) => lrtViewNames.has(view.name))
		.map((view): SidebarView => ({
			id: view.id,
			name: view.name,
			description: view.description,
			groupId: viewGroupMapping[view.name] || 'analysis',
			isDefault: defaultViews.find((dv) => dv.name === view.name)?.isDefault,
			order: viewOrderMap.get(view.name) ?? 1000
		}))
		.sort((a, b) => (a.order ?? 1000) - (b.order ?? 1000));

	// Seed default views if they don't exist (by name) and auto-select default view
	async function seedDefaultViews() {
		await viewActions.waitForReady();

		const currentViews = $savedViews;

		// Deduplicate — keep first occurrence of each name
		const existingViews = new Map<string, string>();
		for (const view of currentViews) {
			if (existingViews.has(view.name)) {
				try { await viewActions.delete(view.id); } catch { /* dedup */ }
			} else {
				existingViews.set(view.name, view.id);
			}
		}

		// Seed missing views (existing views are never overwritten — user edits are preserved)
		const missingViews = defaultViews.filter((v) => !existingViews.has(v.name));
		let defaultViewId: string | null = null;

		const defaultViewDef = defaultViews.find((v) => v.isDefault);
		if (defaultViewDef && existingViews.has(defaultViewDef.name)) {
			defaultViewId = existingViews.get(defaultViewDef.name) || null;
		}

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
				existingViews.set(view.name, savedView?.id || '');
				await new Promise((resolve) => setTimeout(resolve, 100));
			} catch (err) {
				console.error('[LRT Admin] Failed to seed view:', view.name, err);
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
				queryForView(activeView.name);
			}
		}
	}

	// Sync TableKit's internal state back to our view variables
	// so captureCurrentConfig() captures the user's actual current config
	import type { TableState } from '@shotleybuilder/svelte-table-kit';

	function handleStateChange(state: TableState) {
		// Update visible columns from TableKit's visibility state
		const visibleCols = Object.entries(state.columnVisibility)
			.filter(([, visible]) => visible)
			.map(([id]) => id);
		if (visibleCols.length > 0) {
			viewColumns = visibleCols;
		}

		// Update column order
		if (state.columnOrder.length > 0) {
			viewColumnOrder = state.columnOrder;
		}

		// Update filters
		viewFilters = state.columnFilters;

		// Update sort
		if (state.sorting.length > 0) {
			viewSort = {
				columnId: state.sorting[0].columnId,
				direction: state.sorting[0].direction
			};
		}
	}

	// Capture current table config for saving
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
			pageSize: 25,
			grouping: viewGrouping
		};
	}

	// View filters and sort state (for applying saved views)
	// viewFilters uses TableKit's FilterCondition type (with 'field'), converted from library's type (with 'columnId')
	let viewFilters: FilterCondition[] = [];
	let viewSort: { columnId: string; direction: 'asc' | 'desc' } | null = null;

	// Apply saved view configuration
	function applyViewConfig(config: TableConfig) {
		console.log('[LRT Admin] Applying view config:', config);

		// Get available column IDs
		const availableColumnIds = new Set(columns.map((c) => String(c.id)));

		// Validate columns - filter out missing columns
		const validColumns = config.columns.filter((colId) => availableColumnIds.has(colId));
		const validColumnOrder = config.columnOrder.filter((colId) => availableColumnIds.has(colId));

		// Set view config (triggers reactive update)
		viewColumns = validColumns.length > 0 ? validColumns : [];
		viewColumnOrder = validColumnOrder.length > 0 ? validColumnOrder : [];

		// Apply filters from view config (convert columnId to field for TableKit)
		// Ensure value is a string for FilterCondition component
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

		// Apply sort from view config
		viewSort = config.sort || null;

		// Apply grouping from view config
		viewGrouping = config.grouping || [];

		configVersion++;
	}

	// Handle sidebar view selection — load view config AND query PGLite
	async function handleSidebarSelect(event: CustomEvent<{ view: SidebarView }>) {
		const sidebarView = event.detail.view;
		const loadedView = await viewActions.load(sidebarView.id);
		if (loadedView) {
			applyViewConfig(loadedView.config);
		}
		queryForView(sidebarView.name);
	}

	// Resolve view name to the correct PGLite query
	function queryForView(viewName: string) {
		const custom = viewCustomQueryMapping[viewName];
		if (custom) {
			queryCustom(custom.sql, custom.params);
		} else {
			const family = viewFamilyMapping[viewName] ?? null;
			queryForFamily(family);
		}
	}

	// Handle save view button click
	function handleSaveView() {
		capturedConfig = captureCurrentConfig();
		showSaveModal = true;
	}

	// Handle update existing view
	async function handleUpdateView() {
		const activeId = $activeViewId;
		if (!activeId) return;

		try {
			const config = captureCurrentConfig();
			await viewActions.update(activeId, { config });
		} catch (err) {
			console.error('[LRT Admin] Failed to update view:', err);
		}
	}

	// Handle view saved
	function handleViewSaved(event: CustomEvent<{ id: string; name: string }>) {
		console.log('[LRT Admin] View saved:', event.detail.name);
	}

	// Update record
	async function updateRecord(id: string, field: string, value: string | string[] | boolean | null) {
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

			// Update local data
			const updated = await response.json();
			data = data.map((r) => (r.id === id ? updated : r));
		} catch (e) {
			alert(`Update failed: ${e instanceof Error ? e.message : 'Unknown error'}`);
		}
	}

	// Start editing
	function startEdit(id: string, field: string, currentValue: string | string[] | null) {
		editingCell = { id, field };
		editValue = currentValue ?? (field === 'function' ? [] : '');
	}

	// Save edit
	async function saveEdit() {
		if (!editingCell) return;
		const { id, field } = editingCell;
		await updateRecord(id, field, editValue || null);
		editingCell = null;
		editValue = '';
	}

	// Cancel edit
	function cancelEdit() {
		editingCell = null;
		editValue = '';
	}

	// Handle keyboard in edit mode
	function handleEditKeydown(e: KeyboardEvent) {
		if (e.key === 'Enter' && !e.shiftKey) {
			e.preventDefault();
			saveEdit();
		} else if (e.key === 'Escape') {
			cancelEdit();
		}
	}

	// Toggle function value
	function toggleFunction(fn: string) {
		if (!Array.isArray(editValue)) editValue = [];
		if (editValue.includes(fn)) {
			editValue = editValue.filter((v) => v !== fn);
		} else {
			editValue = [...editValue, fn];
		}
	}

	// Format date helper
	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '-';
		const date = new Date(dateStr);
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
	}

	// Get family prefix and clean name
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

	// Column definitions
	const columns: ColumnDef<UkLrtRecord>[] = [
		{
			id: 'actions',
			header: '',
			cell: (info) => info.cell.row.original.id,
			size: 90,
			enableSorting: false,
			enableResizing: false,
			meta: { group: 'Actions' }
		},
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
			enableGrouping: true,
			meta: { group: 'Credentials', dataType: 'number' }
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
			id: 'type_code',
			accessorKey: 'type_code',
			header: 'Type Code',
			cell: (info) => String(info.getValue() || '').toUpperCase(),
			size: 80,
			enableGrouping: true,
			meta: { group: 'Credentials', dataType: 'select', selectOptions: typeCodeOptions }
		},
		{
			id: 'type_desc',
			accessorKey: 'type_desc',
			header: 'Type',
			cell: (info) => info.getValue() || '-',
			size: 180,
			enableGrouping: true,
			meta: { group: 'Credentials', dataType: 'text' }
		},
		{
			id: 'family',
			accessorKey: 'family',
			header: 'Family',
			cell: (info) => info.getValue(),
			size: 200,
			enableGrouping: true,
			meta: { group: 'Description', editable: true, dataType: 'text' }
		},
		{
			id: 'family_ii',
			accessorKey: 'family_ii',
			header: 'Family II',
			cell: (info) => info.getValue(),
			size: 200,
			enableGrouping: true,
			meta: { group: 'Description', editable: true, dataType: 'text' }
		},
		{
			id: 'si_code',
			accessorKey: 'si_code',
			header: 'SI Code',
			cell: (info) => info.getValue(),
			size: 180,
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
			meta: { group: 'Description', editable: true, dataType: 'text' }
		},
		{
			id: 'is_making',
			accessorKey: 'is_making',
			header: 'Making?',
			cell: (info) => info.getValue() ? 'Yes' : '-',
			size: 80,
			enableGrouping: true,
			meta: { group: 'Description', editable: true, dataType: 'text' }
		},
		{
			id: 'live',
			accessorKey: 'live',
			header: 'Status',
			cell: (info) => info.getValue(),
			size: 100,
			enableGrouping: true,
			meta: { group: 'Status', dataType: 'select', selectOptions: liveStatusOptions }
		},
		{
			id: 'live_source',
			accessorKey: 'live_source',
			header: 'Source',
			cell: (info) => info.getValue() || '-',
			size: 90,
			meta: { group: 'Reconciliation', dataType: 'text' }
		},
		{
			id: 'live_from_changes',
			accessorKey: 'live_from_changes',
			header: 'From Changes',
			cell: (info) => info.getValue() || '-',
			size: 130,
			meta: { group: 'Reconciliation', dataType: 'text' }
		},
		{
			id: 'live_from_metadata',
			accessorKey: 'live_from_metadata',
			header: 'From Metadata',
			cell: (info) => info.getValue() || '-',
			size: 130,
			meta: { group: 'Reconciliation', dataType: 'text' }
		},
		{
			id: 'live_conflict',
			accessorKey: 'live_conflict',
			header: 'Conflict',
			cell: (info) => info.getValue() ? 'Yes' : '-',
			size: 80,
			meta: { group: 'Reconciliation', dataType: 'text' }
		},
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
			id: 'md_date',
			accessorKey: 'md_date',
			header: 'Primary Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Dates', dataType: 'date' }
		},
		{
			id: 'md_subjects',
			accessorKey: 'md_subjects',
			header: 'Subjects',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 200,
			meta: { group: 'Description', dataType: 'text' }
		},
		{
			id: 'latest_amend_date',
			accessorKey: 'latest_amend_date',
			header: 'Last Amended',
			cell: (info) => formatDate(info.getValue() as string),
			size: 110,
			meta: { group: 'Dates', dataType: 'date' }
		},
		{
			id: 'latest_rescind_date',
			accessorKey: 'latest_rescind_date',
			header: 'Last Rescinded',
			cell: (info) => formatDate(info.getValue() as string),
			size: 110,
			meta: { group: 'Dates', dataType: 'date' }
		},
		{
			id: 'created_at',
			accessorKey: 'created_at',
			header: 'Created',
			cell: (info) => {
				const val = info.getValue() as string | null;
				if (!val) return '-';
				return new Date(val).toLocaleDateString('en-GB', {
					day: '2-digit',
					month: 'short',
					year: 'numeric'
				});
			},
			size: 100,
			meta: { group: 'Dates', dataType: 'date' }
		}
	];

	// Build TableKit configuration from view (reactive)
	$: hasViewConfig =
		viewColumns.length > 0 ||
		viewColumnOrder.length > 0 ||
		viewFilters.length > 0 ||
		viewSort !== null ||
		viewGrouping.length > 0;

	// Filters come from saved views or user interaction — no hidden year scope.
	// Progressive sync provides all data, TableKit's applyFilters handles everything client-side.
	$: activeFilters = viewFilters;

	// Determine sort config (TableKit uses columnId and expects an array)
	// When grouping is active, prepend grouped columns as desc sort (year descending)
	$: activeSorting = viewSort
		? [
				...viewGrouping.map((col) => ({ columnId: col, direction: 'desc' as const })),
				{ columnId: viewSort.columnId, direction: viewSort.direction }
			]
		: viewGrouping.length > 0
			? viewGrouping.map((col) => ({ columnId: col, direction: 'desc' as const }))
			: undefined;

	$: tableKitConfig = {
		id: hasViewConfig ? `view_config_v${configVersion}` : 'default_config',
		version: '1.0',
		defaultFilters: activeFilters,
		defaultSorting: activeSorting,
		defaultColumnOrder: hasViewConfig && viewColumnOrder.length > 0 ? viewColumnOrder : undefined,
		defaultVisibleColumns: hasViewConfig && viewColumns.length > 0 ? viewColumns : undefined,
		defaultGrouping: viewGrouping.length > 0 ? viewGrouping : undefined,
		defaultExpanded: viewGrouping.length > 0 ? true : undefined
	};

	onMount(async () => {
		if (browser) {
			await startSync();
			seedDefaultViews();
		}
	});
</script>

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
			storageKey="lrt-admin-views-sidebar"
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
			<div class="flex-1">
				<h1 class="text-2xl font-bold text-gray-900">UK LRT Data</h1>
				<p class="mt-1 text-sm text-gray-500">
					Manage UK Legal Register Table records. Inline edit Family, Family II, and Function fields.
				</p>
			</div>
			<button
				class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
				on:click={() => (showReparseDialog = true)}
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Reparse Family
			</button>
			<button
				class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-amber-600 rounded-md hover:bg-amber-700 disabled:opacity-50 disabled:cursor-not-allowed"
				on:click={() => (showReparseViewDialog = true)}
				disabled={filteredData.length === 0}
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Reparse View ({filteredData.length})
			</button>
		</div>

	{#if isLoading}
		<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
			<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
			<p class="mt-4 text-gray-600">Loading UK LRT data...</p>
		</div>
	{:else if error}
		<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
			<h3 class="text-lg font-semibold text-red-800 mb-2">Error Loading Data</h3>
			<p class="text-red-600">{error}</p>
			<button
				class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
				on:click={() => window.location.reload()}
			>
				Retry
			</button>
		</div>
	{:else}
		<!-- Stats -->
		<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Synced Records</div>
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
						<button
							class="ml-2 text-xs px-2 py-0.5 bg-red-100 text-red-700 rounded hover:bg-red-200"
							on:click={() => window.location.reload()}
						>
							Retry
						</button>
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
				<div class="text-sm text-gray-600">Data Scope</div>
				<div class="text-sm font-medium text-gray-700">
					{#if $syncStatus.syncing}
						Syncing... ({$syncStatus.recordCount.toLocaleString()})
					{:else}
						All records synced
					{/if}
				</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Currently Editing</div>
				<div class="text-2xl font-bold text-gray-900">
					{editingCell ? `${editingCell.field}` : 'None'}
				</div>
			</div>
		</div>

		<!-- Table -->
		<TableKit
			{data}
			{columns}
			config={tableKitConfig}
			storageKey="uk_lrt_admin_table"
			persistState={!hasViewConfig}
			onStateChange={handleStateChange}
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
			<!-- Saved Views Toolbar -->
			<svelte:fragment slot="toolbar-left">
				{#if $activeViewId}
					<!-- Split Button: Save (update current) | Save As New -->
					<div class="inline-flex rounded-md shadow-sm">
						<button
							type="button"
							on:click={handleUpdateView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-l-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
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
						<button
							type="button"
							on:click={handleSaveView}
							class="inline-flex items-center gap-2 px-3 py-2 text-sm font-medium text-white bg-indigo-600 border-l border-indigo-500 rounded-r-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M12 4v16m8-8H4"
								/>
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
				{#if column === 'actions'}
					<div class="flex items-center gap-1">
						<!-- Expand arrow — open record card (back of card) -->
						<button
							class="p-1 text-gray-400 hover:text-gray-700 hover:bg-gray-100 rounded"
							title="View record details"
							on:click={() => openRecordCard(row)}
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
							</svg>
						</button>
						<!-- Parse & Review button -->
						<button
							class="p-1.5 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded"
							title="Parse & Review - re-parse and review changes before saving"
							on:click={() => openParseReviewModal(row)}
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
								/>
							</svg>
						</button>
					</div>
				{:else if column === 'family'}
					{#if editingCell?.id === row.id && editingCell?.field === 'family'}
						<select
							class="w-full text-sm border border-blue-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
							bind:value={editValue}
							on:blur={saveEdit}
							on:keydown={handleEditKeydown}
						>
							<option value="">-- None --</option>
							<optgroup label="Health & Safety">
								{#each familyOptions.health_safety as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</optgroup>
							<optgroup label="Environment">
								{#each familyOptions.environment as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</optgroup>
							<optgroup label="HR">
								{#each familyOptions.hr as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</optgroup>
						</select>
					{:else}
						{@const display = getFamilyDisplay(row.family)}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate"
							on:dblclick={() => startEdit(row.id, 'family', row.family)}
							title="Double-click to edit"
						>
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
						</button>
					{/if}
				{:else if column === 'family_ii'}
					{#if editingCell?.id === row.id && editingCell?.field === 'family_ii'}
						<select
							class="w-full text-sm border border-blue-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-blue-500"
							bind:value={editValue}
							on:blur={saveEdit}
							on:keydown={handleEditKeydown}
						>
							<option value="">-- None --</option>
							<optgroup label="Health & Safety">
								{#each familyOptions.health_safety as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</optgroup>
							<optgroup label="Environment">
								{#each familyOptions.environment as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</optgroup>
							<optgroup label="HR">
								{#each familyOptions.hr as opt}
									<option value={opt}>{opt}</option>
								{/each}
							</optgroup>
						</select>
					{:else}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate"
							on:dblclick={() => startEdit(row.id, 'family_ii', row.family_ii)}
							title="Double-click to edit"
						>
							{row.family_ii || '-'}
						</button>
					{/if}
				{:else if column === 'function'}
					{#if editingCell?.id === row.id && editingCell?.field === 'function'}
						<div class="flex flex-wrap gap-1 p-1 border border-blue-400 rounded bg-white">
							{#each functionOptions as fn}
								<button
									type="button"
									class="px-2 py-0.5 text-xs rounded {Array.isArray(editValue) &&
									editValue.includes(fn)
										? 'bg-blue-600 text-white'
										: 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
									on:click={() => toggleFunction(fn)}
								>
									{fn}
								</button>
							{/each}
							<button
								type="button"
								class="px-2 py-0.5 text-xs bg-green-600 text-white rounded hover:bg-green-700 ml-auto"
								on:click={saveEdit}
							>
								Save
							</button>
							<button
								type="button"
								class="px-2 py-0.5 text-xs bg-gray-400 text-white rounded hover:bg-gray-500"
								on:click={cancelEdit}
							>
								Cancel
							</button>
						</div>
					{:else}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
							on:dblclick={() => startEdit(row.id, 'function', row.function)}
							title="Double-click to edit"
						>
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
						</button>
					{/if}
				{:else if column === 'title_en'}
					<div class="whitespace-normal break-words">
						{cell.getValue() || '-'}
					</div>
				{:else if column === 'is_making'}
					<button
						class="w-full text-center hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
						on:click={() => updateRecord(row.id, 'is_making', !row.is_making)}
						title="Click to toggle"
					>
						{#if row.is_making}
							<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700">Yes</span>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
					</button>
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
				{:else}
					{cell.getValue() ?? '-'}
				{/if}
			</svelte:fragment>
		</TableKit>

		<!-- Instructions -->
		<div class="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg text-sm">
			<h4 class="font-medium text-blue-800 mb-2">Instructions</h4>
			<ul class="list-disc list-inside text-blue-700 space-y-1">
				<li><strong>Double-click</strong> Family, Family II, or Function cells to edit inline</li>
				<li>
					<strong>Parse & Review button</strong> (refresh icon) re-parses with streaming progress and shows diff for review before saving
				</li>
				<li>Use column visibility controls to show/hide columns and reduce horizontal scroll</li>
				<li>Table state (column order, visibility, sorting) is persisted locally</li>
				<li>
					<strong>Saved Views</strong> - Save your current table configuration for quick access later
				</li>
			</ul>
		</div>
	{/if}
	</div> <!-- /flex-1 overflow-auto (main content) -->
</div> <!-- /flex h-full relative (sidebar+content wrapper) -->

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig}
	<SaveViewModal bind:open={showSaveModal} config={capturedConfig} on:save={handleViewSaved} />
{/if}

<!-- Record Card Modal (back of card — view all fields) -->
<RecordCardModal
	bind:open={cardModalOpen}
	record={cardModalRecord}
	recordId={cardModalRecord?.id ?? null}
	on:close={closeRecordCard}
/>

<!-- Parse Review Modal (streaming parse & review for existing records) -->
{#if viewModalRecord}
	<ParseReviewModal
		records={[{
			name: viewModalRecord.name,
			Title_EN: viewModalRecord.title_en,
			type_code: String(viewModalRecord.type_code ?? ''),
			Year: Number(viewModalRecord.year ?? 0),
			Number: String(viewModalRecord.number ?? '')
		}]}
		recordId={viewModalRecord.id}
		open={viewModalOpen}
		on:close={closeViewModal}
	/>
{/if}

<!-- Reparse Family Dialog -->
<ReparseDialog
	open={showReparseDialog}
	on:close={() => (showReparseDialog = false)}
	on:created={handleReparseCreated}
/>

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
					<p><span class="font-medium">View:</span> {activeViewName || 'All'}</p>
					{#if currentFamily}
						<p><span class="font-medium">Family:</span> {currentFamily}</p>
					{/if}
					<p class="mt-2">
						<span class="text-2xl font-bold text-gray-900">{filteredData.length}</span>
						<span class="text-gray-500 ml-1">records will be added to a new reparse session</span>
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
					disabled={reparseViewLoading || filteredData.length === 0}
					class="px-4 py-2 text-sm font-medium text-white bg-amber-600 rounded-md hover:bg-amber-700 disabled:opacity-50"
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

<style>
	:global(.table-kit-table) {
		min-width: auto !important;
	}
</style>
