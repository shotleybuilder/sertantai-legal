<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { GridLite } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type { ColumnConfig, GridState, FilterCondition, SortConfig, GroupConfig } from '@shotleybuilder/svelte-gridlite-kit';
	import { initViewStore, SaveViewModal, runViewMigrations } from '@shotleybuilder/svelte-gridlite-views';
	import type { ViewConfig, SavedView, ViewStoreBundle } from '@shotleybuilder/svelte-gridlite-views';

	import { authFetch } from '$lib/api/client';
	import { goto } from '$app/navigation';

	// PGLite sync
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';

	// Record viewing & parsing
	import ParseReviewModal from '$lib/components/ParseReviewModal.svelte';
	import RecordCardModal from '$lib/components/RecordCardModal.svelte';
	import ReparseDialog from '$lib/components/ReparseDialog.svelte';
	import { createReparseFromView } from '$lib/api/scraper';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// Types
	interface UkLrtRecord {
		[key: string]: unknown;
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
		function: Record<string, boolean> | string[] | null;
		is_making: boolean | null;
		has_fitness: string;
		lat_count: number;
		live: string | null;
		live_source: string | null;
		live_conflict: boolean | null;
		live_from_changes: string | null;
		live_from_metadata: string | null;
		latest_amend_date: string | null;
		latest_rescind_date: string | null;
		created_at: string | null;
	}

	/** Template-safe row cast (Svelte 4 markup doesn't support TS `as`) */
	function asLrt(row: Record<string, unknown>): UkLrtRecord { return row as UkLrtRecord; }

	/** Electric sends JSONB `function` as a JS object {Making: true, ...} — extract keys */
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

	// PGLite + GridLite state
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

	// LRT columns queried from PGLite
	const LRT_COLUMNS = 'id, name, title_en, year, number, type_code, type_desc, family, family_ii, si_code, md_subjects, md_date, geo_extent, function, is_making, has_fitness, lat_count, live, live_source, live_conflict, live_from_changes, live_from_metadata, latest_amend_date, latest_rescind_date, created_at';

	// Column definitions for GridLite
	const columns: ColumnConfig[] = [
		{ name: 'name', label: 'Name', width: 140, dataType: 'text' },
		{ name: 'title_en', label: 'Title', width: 300, dataType: 'text' },
		{ name: 'year', label: 'Year', width: 70, dataType: 'number' },
		{ name: 'number', label: 'Number', width: 80, dataType: 'text' },
		{ name: 'type_code', label: 'Type Code', width: 80, dataType: 'text', selectOptions: typeCodeOptions },
		{ name: 'type_desc', label: 'Type', width: 180, dataType: 'text' },
		{ name: 'family', label: 'Family', width: 200, dataType: 'text' },
		{ name: 'family_ii', label: 'Family II', width: 200, dataType: 'text' },
		{ name: 'si_code', label: 'SI Code', width: 180, dataType: 'text' },
		{ name: 'function', label: 'Function', width: 150, dataType: 'text' },
		{ name: 'is_making', label: 'Making?', width: 80, dataType: 'text' },
		{ name: 'has_fitness', label: 'Fitness?', width: 80, dataType: 'select', selectOptions: [{ value: 'true', label: 'Yes' }, { value: 'false', label: 'No' }] },
		{ name: 'lat_count', label: 'LAT', width: 70, dataType: 'number' },
		{ name: 'live', label: 'Status', width: 100, dataType: 'text', selectOptions: liveStatusOptions },
		{ name: 'live_source', label: 'Source', width: 90, dataType: 'text' },
		{ name: 'live_from_changes', label: 'From Changes', width: 130, dataType: 'text' },
		{ name: 'live_from_metadata', label: 'From Metadata', width: 130, dataType: 'text' },
		{ name: 'live_conflict', label: 'Conflict', width: 80, dataType: 'text' },
		{ name: 'geo_extent', label: 'Extent', width: 120, dataType: 'text', selectOptions: geoExtentOptions },
		{ name: 'md_date', label: 'Primary Date', width: 100, dataType: 'date', format: (v) => formatDate(v as string | null) },
		{ name: 'md_subjects', label: 'Subjects', width: 200, dataType: 'text',
			format: (v) => {
				const val = v as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			}
		},
		{ name: 'latest_amend_date', label: 'Last Amended', width: 110, dataType: 'date', format: (v) => formatDate(v as string | null) },
		{ name: 'latest_rescind_date', label: 'Last Rescinded', width: 110, dataType: 'date', format: (v) => formatDate(v as string | null) },
		{ name: 'created_at', label: 'Created', width: 100, dataType: 'date', format: (v) => formatDate(v as string | null) }
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

	// View group definitions (sidebar)
	interface ViewGroupDef { id: string; name: string; order: number }
	const viewGroups: ViewGroupDef[] = [
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
	viewGroupMapping['LAT Cleanup'] = 'analytics';

	// Map view name → family value (for PGLite query)
	const viewFamilyMapping: Record<string, string> = {};
	for (const def of familyViewDefs) {
		viewFamilyMapping[def.name] = def.family;
	}

	// Custom query views
	const currentYear = new Date().getFullYear();
	const VIEW_COLUMNS = ['name', 'title_en', 'year', 'number', 'type_code', 'type_desc', 'live', 'function', 'is_making', 'geo_extent'];
	const RECENT_COLUMNS = ['name', 'title_en', 'year', 'type_code', 'family', 'live'];
	const LIVE_VIEW_COLUMNS = ['name', 'title_en', 'year', 'live', 'live_source', 'live_from_changes', 'live_from_metadata', 'live_conflict'];
	const LAT_CLEANUP_COLUMNS = ['name', 'title_en', 'year', 'type_code', 'live', 'function', 'is_making', 'lat_count', 'family'];

	// Map view name → custom query SQL
	const viewCustomQueryMapping: Record<string, string> = {
		'Recently Added': `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE created_at >= NOW() - INTERVAL '1 month' ORDER BY created_at DESC`,
		'Recently Amended': `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE latest_amend_date >= '${currentYear - 2}-01-01' ORDER BY latest_amend_date DESC`,
		'Recently Rescinded': `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE latest_rescind_date >= '${currentYear - 2}-01-01' ORDER BY latest_rescind_date DESC`,
		'Live': `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE family = '💙 OH&S: Occupational / Personal Safety' AND title_en IS NOT NULL ORDER BY name`,
		'LAT Cleanup': `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE lat_count > 0 AND (live = '❌ Revoked / Repealed / Abolished' OR (is_making = true AND NOT (function ? 'Making'))) ORDER BY lat_count DESC`
	};

	// Helper to build column visibility map from a list of visible column names
	function colVis(visibleCols: string[]): Record<string, boolean> {
		const vis: Record<string, boolean> = {};
		for (const col of columns) {
			vis[col.name] = visibleCols.includes(col.name);
		}
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
			sorting: opts.sorting ?? [{ column: 'name', direction: 'asc' }],
			grouping: opts.grouping ?? [{ column: 'type_desc' }],
			columnVisibility: colVis(opts.visibleCols),
			columnOrder: opts.visibleCols,
			columnWidths: {},
			pageSize: 25
		};
	}

	interface ViewDef {
		name: string;
		description: string;
		config: ViewConfig;
		isDefault?: boolean;
		family?: string;
		customQuery?: string;
	}

	const defaultViews: ViewDef[] = [
		// Family views
		...familyViewDefs.map((def, i): ViewDef => ({
			name: def.name,
			description: `${def.family} — grouped by type`,
			config: makeViewConfig({ visibleCols: VIEW_COLUMNS }),
			isDefault: i === 0,
			family: def.family
		})),
		// Recent views
		{
			name: 'Recently Added',
			description: 'Records added to the database in the last month.',
			config: makeViewConfig({
				visibleCols: [...RECENT_COLUMNS, 'created_at'],
				sorting: [{ column: 'created_at', direction: 'desc' }],
				grouping: [{ column: 'type_desc' }]
			}),
			customQuery: viewCustomQueryMapping['Recently Added']
		},
		{
			name: 'Recently Amended',
			description: 'Laws amended in the last 3 years, sorted by most recent amendment date.',
			config: makeViewConfig({
				visibleCols: [...RECENT_COLUMNS, 'latest_amend_date'],
				sorting: [{ column: 'latest_amend_date', direction: 'desc' }],
				grouping: [{ column: 'type_desc' }]
			}),
			customQuery: viewCustomQueryMapping['Recently Amended']
		},
		{
			name: 'Recently Rescinded',
			description: 'Laws rescinded (repealed/revoked) in the last 3 years.',
			config: makeViewConfig({
				visibleCols: [...RECENT_COLUMNS, 'latest_rescind_date'],
				sorting: [{ column: 'latest_rescind_date', direction: 'desc' }],
				grouping: [{ column: 'type_desc' }]
			}),
			customQuery: viewCustomQueryMapping['Recently Rescinded']
		},
		// Analytics
		{
			name: 'Live',
			description: 'Live status reconciliation — OH&S Occupational / Personal Safety',
			config: makeViewConfig({
				visibleCols: LIVE_VIEW_COLUMNS,
				sorting: [{ column: 'name', direction: 'asc' }],
				grouping: []
			}),
			customQuery: viewCustomQueryMapping['Live']
		},
		{
			name: 'LAT Cleanup',
			description: 'Laws qualifying for LAT deletion — revoked/repealed or not-making with LAT data',
			config: makeViewConfig({
				visibleCols: LAT_CLEANUP_COLUMNS,
				sorting: [{ column: 'lat_count', direction: 'desc' }],
				grouping: []
			}),
			customQuery: viewCustomQueryMapping['LAT Cleanup']
		}
	];

	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));

	// Resolve view name to the correct PGLite query SQL
	function getQueryForView(viewName: string): string {
		const custom = viewCustomQueryMapping[viewName];
		if (custom) return custom;
		const family = viewFamilyMapping[viewName];
		if (family) return `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE family = '${family.replace(/'/g, "''")}' ORDER BY type_desc, name`;
		return `SELECT ${LRT_COLUMNS} FROM uk_lrt ORDER BY name`;
	}

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
				groupId: viewGroupMapping[v.name] || 'recent',
				order: viewOrderMap.get(v.name) ?? 1000,
				isDefault: defaultViews.find((dv) => dv.name === v.name)?.isDefault
			}))
			.sort((a, b) => a.order - b.order);
	}

	// ── Editing state ───────────────────────────────────────────────

	let editingCell: { id: string; field: string } | null = null;
	let editValue: string | string[] = '';

	// Record Card modal state
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

	// LAT deletion dialog state
	let deleteConfirmRecord: UkLrtRecord | null = null;
	let deleteLoading = false;
	let deleteError: string | null = null;

	// Track grid data for reparse view count
	let latestGridState: GridState | null = null;

	$: activeViewName = (() => {
		if (!viewStore) return null;
		let name: string | null = null;
		const unsub = viewStore.activeView.subscribe((v) => { name = v?.name ?? null; });
		unsub();
		return name;
	})();

	async function handleReparseViewConfirm() {
		reparseViewLoading = true;
		reparseViewError = null;
		try {
			// Get visible data names from PGLite directly using the current query
			const result = await db?.query<{ name: string }>(currentQuery);
			const names = result?.rows.map((r) => r.name) ?? [];
			const label = activeViewName || 'view';
			const sessionResult = await createReparseFromView(names, label);
			showReparseViewDialog = false;
			goto(`/admin/scrape/sessions/${sessionResult.session_id}`);
		} catch (err) {
			reparseViewError = err instanceof Error ? err.message : String(err);
		} finally {
			reparseViewLoading = false;
		}
	}

	// Delete LAT data for a single law
	async function handleDeleteLat() {
		if (!deleteConfirmRecord) return;
		deleteLoading = true;
		deleteError = null;

		try {
			const response = await authFetch(
				`${API_URL}/api/lat/laws/${encodeURIComponent(deleteConfirmRecord.name)}/data`,
				{ method: 'DELETE' }
			);

			if (!response.ok) {
				const err = await response.json();
				throw new Error(err.error || 'Failed to delete LAT data');
			}

			const result = await response.json();
			console.log(`[LAT Cleanup] Deleted ${result.lat_deleted} LAT rows, ${result.annotations_deleted} annotations for ${result.law_name}`);

			// Close dialog — PGLite will auto-update lat_count via Electric sync
			deleteConfirmRecord = null;
			deleteError = null;
		} catch (e) {
			deleteError = e instanceof Error ? e.message : String(e);
		} finally {
			deleteLoading = false;
		}
	}

	// Update record via API
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
			// Live query auto-updates when Electric syncs the change back to PGLite
		} catch (e) {
			alert(`Update failed: ${e instanceof Error ? e.message : 'Unknown error'}`);
		}
	}

	// Start editing
	function startEdit(id: string, field: string, currentValue: string | string[] | Record<string, boolean> | null) {
		editingCell = { id, field };
		if (field === 'function') {
			editValue = parseFunctionKeys(currentValue) ?? [];
		} else {
			editValue = (currentValue as string) ?? '';
		}
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
		if (family.startsWith('HS:') || family.includes('OH&S') || family.includes('FIRE') || family.includes('FOOD') || family.includes('HEALTH') || family.includes('PUBLIC') || family.includes('TRANSPORT:'))
			return { prefix: 'HS', name: family };
		if (family.startsWith('E:') || family.includes('ENVIRONMENT') || family.includes('CLIMATE') || family.includes('WASTE') || family.includes('WATER') || family.includes('WILDLIFE') || family.includes('MARINE') || family.includes('POLLUTION') || family.includes('AGRICULTURE') || family.includes('ENERGY'))
			return { prefix: 'E', name: family };
		if (family.startsWith('HR:') || family.includes('HR:')) return { prefix: 'HR', name: family };
		return { prefix: '', name: family };
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
				if (view.isDefault && saved?.id) {
					defaultViewId = saved.id;
				}
				existingViews.set(view.name, saved?.id || '');
			} catch (err) {
				console.error('[LRT Admin] Failed to seed view:', view.name, err);
			}
		}

		// Auto-select default view
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => { activeId = v; })();
		if (defaultViewId && !activeId) {
			const loadedView = await actions.load(defaultViewId);
			if (loadedView) {
				applyViewToGrid(loadedView);
				const defaultDef = defaultViews.find((v) => v.isDefault);
				if (defaultDef) {
					switchToView(defaultDef.name);
				}
			}
		} else if (activeId) {
			// Returning user — resolve the active view and query it
			let activeView: SavedView | null = null;
			svStore.subscribe((views) => {
				activeView = views.find((v) => v.id === activeId) ?? null;
			})();
			if (activeView) {
				switchToView((activeView as SavedView).name);
			}
		}

		// Rebuild sidebar
		rebuildSidebarViews(currentViews);
		unsub();

		// Subscribe for future updates
		svStore.subscribe((views) => rebuildSidebarViews(views));
	}

	// Apply a saved view to the GridLite instance
	function applyViewToGrid(view: SavedView) {
		if (!gridRef) return;
		const cfg = view.config;
		gridRef.setFilters(cfg.filters as FilterCondition[], cfg.filterLogic);
		gridRef.setSorting(cfg.sorting as SortConfig[]);
		gridRef.setGrouping(cfg.grouping as GroupConfig[]);
	}

	// Switch to a view (loads the query + applies config)
	function switchToView(viewName: string) {
		const query = getQueryForView(viewName);
		currentQuery = query;
		currentFamily = viewFamilyMapping[viewName] ?? null;
	}

	// Handle sidebar view selection
	async function handleViewSelect(viewItem: SidebarViewItem) {
		if (!viewStore) return;
		const view = await viewStore.actions.load(viewItem.id);
		if (view) {
			switchToView(viewItem.name);
			// Wait for GridLite to update with new query, then apply view config
			setTimeout(() => applyViewToGrid(view), 50);
		}
		sidebarOpen = false;
	}

	// Capture current grid state for saving as a view
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

	function handleStateChange(state: GridState) {
		latestGridState = state;
	}

	function handleSaveView() {
		if (!latestGridState) return;
		capturedConfig = captureCurrentConfig(latestGridState);
		showSaveModal = true;
	}

	// Handle update existing view
	async function handleUpdateView() {
		if (!viewStore || !latestGridState) return;
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => { activeId = v; })();
		if (!activeId) return;

		try {
			const config = captureCurrentConfig(latestGridState);
			await viewStore.actions.update(activeId, { config });
		} catch (err) {
			console.error('[LRT Admin] Failed to update view:', err);
		}
	}

	function handleViewSaved(event: CustomEvent<{ id: string; name: string }>) {
		console.log('[LRT Admin] View saved:', event.detail.name);
	}

	// Monitor sync errors
	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}

	$: isLoading = !$syncStatus.connected && !ready;

	// Track total records for stats (get from PGLite count)
	let totalRecordCount = 0;

	async function refreshTotalCount() {
		if (!db) return;
		try {
			const result = await db.query<{ count: string }>('SELECT COUNT(*) as count FROM uk_lrt');
			totalRecordCount = parseInt(result.rows[0]?.count ?? '0', 10);
		} catch { /* ignore */ }
	}

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await runViewMigrations(db as any);
			viewStore = initViewStore(db as any, 'lrt-admin');
			ready = true;
			await refreshTotalCount();
			// Default query until views load
			currentQuery = `SELECT ${LRT_COLUMNS} FROM uk_lrt WHERE family = '${familyViewDefs[0].family.replace(/'/g, "''")}' ORDER BY type_desc, name`;
			currentFamily = familyViewDefs[0].family;
			// Wait for next tick so GridLite renders, then seed views
			setTimeout(() => seedDefaultViews(), 100);
		}
	});

	onDestroy(() => {
		viewStore?.destroy();
	});

	// Reactive check for active view id
	let hasActiveView = false;
	$: if (viewStore) {
		viewStore.activeViewId.subscribe((v) => { hasActiveView = !!v; })();
	}

	// Reparse view record count — use PGLite query to count
	let reparseViewCount = 0;
	$: if (showReparseViewDialog && db && currentQuery) {
		db.query<{ count: string }>(`SELECT COUNT(*) as count FROM (${currentQuery}) sub`).then((r) => {
			reparseViewCount = parseInt(r.rows[0]?.count ?? '0', 10);
		}).catch(() => { reparseViewCount = 0; });
	}
</script>

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
				disabled={!currentQuery}
			>
				<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
				</svg>
				Reparse View
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
			<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700" on:click={() => window.location.reload()}>Retry</button>
		</div>
	{:else if ready && db}
		<!-- Stats -->
		<div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Total Records</div>
				<div class="text-2xl font-bold text-gray-900">{totalRecordCount.toLocaleString()}</div>
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

		<!-- GridLite Table -->
		{#if currentQuery}
		{#key currentQuery}
		<GridLite
			bind:this={gridRef}
			{db}
			query={currentQuery}
			onStateChange={handleStateChange}
			config={{
				id: 'lrt-admin',
				columns,
				defaultSorting: [{ column: 'name', direction: 'asc' }],
				defaultVisibleColumns: VIEW_COLUMNS,
				pagination: { pageSize: 25 }
			}}
			features={{
				columnVisibility: true,
				columnResizing: true,
				columnReordering: true,
				filtering: true,
				sorting: true,
				pagination: true,
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
				{@const r = asLrt(row)}
				{#if column === 'family'}
					{#if editingCell?.id === r.id && editingCell?.field === 'family'}
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
						{@const display = getFamilyDisplay(r.family)}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate"
							on:dblclick={() => startEdit(r.id, 'family', r.family)}
							title="Double-click to edit"
						>
							{#if display.prefix}
								<span class="inline-block px-1 text-xs font-medium rounded mr-1 {display.prefix === 'HS' ? 'bg-blue-100 text-blue-700' : display.prefix === 'E' ? 'bg-green-100 text-green-700' : 'bg-purple-100 text-purple-700'}">
									{display.prefix}
								</span>
							{/if}
							{display.name}
						</button>
					{/if}
				{:else if column === 'family_ii'}
					{#if editingCell?.id === r.id && editingCell?.field === 'family_ii'}
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
							on:dblclick={() => startEdit(r.id, 'family_ii', r.family_ii)}
							title="Double-click to edit"
						>
							{r.family_ii || '-'}
						</button>
					{/if}
				{:else if column === 'function'}
					{#if editingCell?.id === r.id && editingCell?.field === 'function'}
						<div class="flex flex-wrap gap-1 p-1 border border-blue-400 rounded bg-white">
							{#each functionOptions as fn}
								<button
									type="button"
									class="px-2 py-0.5 text-xs rounded {Array.isArray(editValue) && editValue.includes(fn) ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-700 hover:bg-gray-200'}"
									on:click={() => toggleFunction(fn)}
								>
									{fn}
								</button>
							{/each}
							<button type="button" class="px-2 py-0.5 text-xs bg-green-600 text-white rounded hover:bg-green-700 ml-auto" on:click={saveEdit}>Save</button>
							<button type="button" class="px-2 py-0.5 text-xs bg-gray-400 text-white rounded hover:bg-gray-500" on:click={cancelEdit}>Cancel</button>
						</div>
					{:else}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
							on:dblclick={() => startEdit(r.id, 'function', r.function)}
							title="Double-click to edit"
						>
							{#if parseFunctionKeys(r.function)?.length}
								<span class="flex flex-wrap gap-1">
									{#each parseFunctionKeys(r.function) ?? [] as fn}
										<span class="px-1.5 py-0.5 text-xs rounded {fn === 'Making' ? 'bg-green-100 text-green-700' : fn === 'Amending' ? 'bg-yellow-100 text-yellow-700' : fn === 'Revoking' ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'}">
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
					<div class="whitespace-normal break-words">{value || '-'}</div>
				{:else if column === 'is_making'}
					<button
						class="w-full text-center hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
						on:click={() => updateRecord(r.id, 'is_making', !r.is_making)}
						title="Click to toggle"
					>
						{#if r.is_making}
							<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700">Yes</span>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
					</button>
				{:else if column === 'has_fitness'}
					{#if r.has_fitness === 'true'}
						<span class="px-1.5 py-0.5 text-xs rounded bg-purple-100 text-purple-700">Yes</span>
					{:else}
						<span class="text-gray-400">-</span>
					{/if}
				{:else if column === 'live'}
					<span class="inline-flex px-2 py-0.5 text-xs font-medium rounded {value === 'Live' ? 'bg-green-100 text-green-800' : value === 'Revoked' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'}">
						{value || '-'}
					</span>
				{:else if column === 'live_conflict'}
					{value ? 'Yes' : '-'}
				{:else if column === 'type_code'}
					<span class="uppercase">{value || '-'}</span>
				{:else if column === 'name'}
					<div class="flex items-center gap-1">
						<button
							class="p-0.5 text-gray-400 hover:text-gray-700 hover:bg-gray-100 rounded shrink-0"
							title="View record details"
							on:click={() => openRecordCard(r)}
						>
							<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4" />
							</svg>
						</button>
						<button
							class="p-0.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded shrink-0"
							title="Parse & Review"
							on:click={() => openParseReviewModal(r)}
						>
							<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
							</svg>
						</button>
						{#if activeViewName === 'LAT Cleanup' && (r.lat_count ?? 0) > 0}
							<button
								class="p-0.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded shrink-0"
								title="Delete LAT data for this law"
								on:click={() => { deleteConfirmRecord = r; }}
							>
								<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
									<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
								</svg>
							</button>
						{/if}
						<span class="font-mono text-gray-700 truncate">{value}</span>
					</div>
				{:else if column === 'lat_count'}
					{#if Number(value) > 0}
						<span class="px-1.5 py-0.5 text-xs rounded bg-amber-100 text-amber-700 font-medium">
							{Number(value).toLocaleString()}
						</span>
					{:else}
						<span class="text-gray-400">0</span>
					{/if}
				{:else}
					{value ?? '-'}
				{/if}
			</svelte:fragment>
		</GridLite>
		{/key}
		{/if}

		<!-- Instructions -->
		<div class="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg text-sm">
			<h4 class="font-medium text-blue-800 mb-2">Instructions</h4>
			<ul class="list-disc list-inside text-blue-700 space-y-1">
				<li><strong>Double-click</strong> Family, Family II, or Function cells to edit inline</li>
				<li><strong>Parse & Review button</strong> (refresh icon) re-parses with streaming progress and shows diff for review before saving</li>
				<li>Use column visibility controls to show/hide columns and reduce horizontal scroll</li>
				<li><strong>Saved Views</strong> - Save your current table configuration for quick access later</li>
			</ul>
		</div>
	{/if}
	</div>
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig && viewStore}
	<SaveViewModal bind:open={showSaveModal} {viewStore} config={capturedConfig} on:save={handleViewSaved} />
{/if}

<!-- Record Card Modal -->
<RecordCardModal
	bind:open={cardModalOpen}
	record={cardModalRecord}
	recordId={cardModalRecord?.id ?? null}
	on:close={closeRecordCard}
/>

<!-- Parse Review Modal -->
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
						<span class="text-2xl font-bold text-gray-900">{reparseViewCount}</span>
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
					disabled={reparseViewLoading || reparseViewCount === 0}
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

<!-- Delete LAT Confirmation Dialog -->
{#if deleteConfirmRecord}
	{@const r = deleteConfirmRecord}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50" on:click|self={() => { deleteConfirmRecord = null; deleteError = null; }}>
		<div class="bg-white rounded-lg shadow-xl w-full max-w-md mx-4">
			<div class="px-6 py-4 border-b border-gray-200">
				<h3 class="text-lg font-semibold text-gray-900">Delete LAT Data</h3>
			</div>
			<div class="px-6 py-4 space-y-3">
				<div class="text-sm text-gray-600">
					<p><span class="font-medium">Law:</span> <span class="font-mono">{r.name}</span></p>
					<p class="mt-1 text-xs text-gray-500 line-clamp-2">{r.title_en}</p>
					<p class="mt-2"><span class="font-medium">Status:</span> {r.live || '-'}</p>
					<p><span class="font-medium">Function:</span> {parseFunctionKeys(r.function)?.join(', ') || 'None'}</p>
					<p><span class="font-medium">Making:</span> {r.is_making ? 'Yes' : 'No'}</p>
					<p class="mt-3">
						<span class="text-2xl font-bold text-red-600">{r.lat_count?.toLocaleString()}</span>
						<span class="text-gray-500 ml-1">LAT rows will be permanently deleted</span>
					</p>
					<p class="mt-2 text-xs text-gray-500">
						Amendment annotations for this law will also be deleted.
						Taxa and fitness data will NOT be affected.
					</p>
				</div>
				{#if deleteError}
					<div class="px-3 py-2 text-sm bg-red-50 text-red-700 rounded border border-red-200">
						{deleteError}
					</div>
				{/if}
			</div>
			<div class="px-6 py-4 border-t border-gray-200 flex justify-end space-x-3">
				<button
					on:click={() => { deleteConfirmRecord = null; deleteError = null; }}
					class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
					disabled={deleteLoading}
				>
					Cancel
				</button>
				<button
					on:click={handleDeleteLat}
					disabled={deleteLoading}
					class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700 disabled:opacity-50"
				>
					{#if deleteLoading}
						Deleting...
					{:else}
						Delete LAT Data
					{/if}
				</button>
			</div>
		</div>
	</div>
{/if}
