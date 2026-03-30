<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { GridLite } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type { ColumnConfig, GridState, FilterCondition, SortConfig, GroupConfig } from '@shotleybuilder/svelte-gridlite-kit';
	import { createTanStackDBAdapter } from '@shotleybuilder/gridlite-adapter-tanstack-db';
	import { createPGLiteCollection } from '$lib/pglite/collection-bridge';
	import { UK_LRT_COLUMN_METADATA } from '$lib/pglite/uk-lrt-columns';
	import { initViewStore, SaveViewModal, runViewMigrations } from '@shotleybuilder/svelte-gridlite-views';
	import type { ViewConfig, SavedView, SavedViewInput, ViewStoreBundle } from '@shotleybuilder/svelte-gridlite-views';

	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';

	// Columns queried from PGLite for the browse page
	const BROWSE_COLUMNS = [
		'id', 'name', 'title_en', 'year', 'type_code', 'number', 'type_class',
		'md_date_year', 'md_date_month', 'family', 'family_ii', 'function',
		'si_code', 'live', 'geo_extent', 'geo_region', 'md_date',
		'md_made_date', 'md_coming_into_force_date', 'latest_amend_date',
		'latest_amend_date_year', 'latest_amend_date_month', 'latest_rescind_date',
		'latest_rescind_date_year', 'latest_rescind_date_month'
	];
	const BROWSE_SQL = `SELECT ${BROWSE_COLUMNS.join(', ')} FROM uk_lrt`;
	const browseColumnMetadata = UK_LRT_COLUMN_METADATA.filter(
		(c) => BROWSE_COLUMNS.includes(c.name)
	);

	// PGLite + GridLite state
	let db: PGLiteWithExtensions | null = null;
	let ready = false;
	let gridRef: GridLite;
	let adapter: ReturnType<typeof createTanStackDBAdapter> | null = null;
	let error: string | null = null;

	// View store (initialized after PGLite is ready)
	let viewStore: ViewStoreBundle | null = null;

	// Saved views state
	let showSaveModal = false;
	let capturedConfig: ViewConfig | null = null;

	// Type helpers for Svelte template (no `as` casts in templates)
	function asStr(v: unknown): string | null { return v as string | null; }
	function asStrArr(v: unknown): string[] | null { return v as string[] | null; }
	function asRec(v: unknown): Record<string, unknown> { return v as Record<string, unknown>; }

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

	// Format date helper
	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '-';
		const date = new Date(dateStr);
		return date.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
	}

	// Month name helper
	const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

	// Family display helper
	function getFamilyDisplay(family: string | null): { prefix: string; name: string } {
		if (!family) return { prefix: '', name: '-' };
		if (family.includes('OH&S') || family.includes('FIRE') || family.includes('FOOD') || family.includes('HEALTH') || family.includes('PUBLIC') || family.includes('TRANSPORT:'))
			return { prefix: 'HS', name: family };
		if (family.includes('ENVIRONMENT') || family.includes('CLIMATE') || family.includes('WASTE') || family.includes('WATER') || family.includes('WILDLIFE') || family.includes('MARINE') || family.includes('POLLUTION') || family.includes('AGRICULTURE') || family.includes('ENERGY'))
			return { prefix: 'E', name: family };
		if (family.includes('HR:')) return { prefix: 'HR', name: family };
		return { prefix: '', name: family };
	}

	// Column definitions for GridLite
	const columns: ColumnConfig[] = [
		{ name: 'name', label: 'Name', width: 140, dataType: 'text' },
		{ name: 'title_en', label: 'Title', width: 300, dataType: 'text' },
		{ name: 'year', label: 'Year', width: 70, dataType: 'number' },
		{ name: 'type_code', label: 'Type Code', width: 80, dataType: 'text' },
		{ name: 'number', label: 'Number', width: 80, dataType: 'text' },
		{ name: 'type_class', label: 'Type Class', width: 120, dataType: 'text' },
		{ name: 'md_date_year', label: 'Year (Date)', width: 90, dataType: 'number' },
		{ name: 'md_date_month', label: 'Month (Date)', width: 100, dataType: 'number',
			format: (v) => { const n = v as number | null; return n != null ? (monthNames[n - 1] ?? '-') : '-'; }
		},
		{ name: 'family', label: 'Family', width: 200, dataType: 'text' },
		{ name: 'family_ii', label: 'Family II', width: 200, dataType: 'text' },
		{ name: 'function', label: 'Function', width: 150, dataType: 'json' },
		{ name: 'si_code', label: 'SI Code', width: 180, dataType: 'text' },
		{ name: 'live', label: 'Status', width: 100, dataType: 'text' },
		{ name: 'geo_extent', label: 'Extent', width: 120, dataType: 'text' },
		{ name: 'geo_region', label: 'Region', width: 120, dataType: 'text' },
		{ name: 'md_date', label: 'Primary Date', width: 100, dataType: 'date',
			format: (v) => formatDate(v as string | null)
		},
		{ name: 'md_made_date', label: 'Made', width: 100, dataType: 'date',
			format: (v) => formatDate(v as string | null)
		},
		{ name: 'md_coming_into_force_date', label: 'In Force', width: 100, dataType: 'date',
			format: (v) => formatDate(v as string | null)
		},
		{ name: 'latest_amend_date', label: 'Last Amended', width: 110, dataType: 'date',
			format: (v) => formatDate(v as string | null)
		},
		{ name: 'latest_amend_date_year', label: 'Amended Year', width: 90, dataType: 'number' },
		{ name: 'latest_amend_date_month', label: 'Amended Month', width: 100, dataType: 'number',
			format: (v) => { const n = v as number | null; return n != null ? (monthNames[n - 1] ?? '-') : '-'; }
		},
		{ name: 'latest_rescind_date', label: 'Last Rescinded', width: 110, dataType: 'date',
			format: (v) => formatDate(v as string | null)
		},
		{ name: 'latest_rescind_date_year', label: 'Rescinded Year', width: 90, dataType: 'number' },
		{ name: 'latest_rescind_date_month', label: 'Rescinded Month', width: 100, dataType: 'number',
			format: (v) => { const n = v as number | null; return n != null ? (monthNames[n - 1] ?? '-') : '-'; }
		},
		{ name: 'leg_gov_uk_url', label: 'Link', width: 70, dataType: 'text' }
	];

	// Date boundary helpers for view filters
	const now = new Date();
	const currentYear = now.getFullYear();
	const currentMonth = now.getMonth();
	const currentQuarterStart = Math.floor(currentMonth / 3) * 3;

	function isoDate(y: number, m: number, d: number): string {
		return `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
	}

	const thisMonthStart = isoDate(currentYear, currentMonth, 1);
	const lastMonthStart = currentMonth === 0 ? isoDate(currentYear - 1, 11, 1) : isoDate(currentYear, currentMonth - 1, 1);
	const thisQuarterStart = isoDate(currentYear, currentQuarterStart, 1);
	const lastQuarterStart = currentQuarterStart === 0 ? isoDate(currentYear - 1, 9, 1) : isoDate(currentYear, currentQuarterStart - 3, 1);
	const thisYearStart = isoDate(currentYear, 0, 1);
	const lastYearStart = isoDate(currentYear - 1, 0, 1);
	const threeYearsAgoStart = isoDate(currentYear - 3, 0, 1);
	const todayStr = isoDate(currentYear, currentMonth, now.getDate());

	// Helper to build column visibility map from a list of visible column names
	function colVis(visibleCols: string[]): Record<string, boolean> {
		const vis: Record<string, boolean> = {};
		for (const col of columns) {
			vis[col.name] = visibleCols.includes(col.name);
		}
		return vis;
	}

	// Shared column/sort/grouping config for view categories
	const newLawsColumns = ['name', 'title_en', 'md_date', 'md_date_year', 'md_date_month', 'type_code', 'live', 'family'];
	const newLawsSorting: SortConfig[] = [{ column: 'md_date', direction: 'desc' }];
	const newLawsGrouping: GroupConfig[] = [{ column: 'md_date_year' }, { column: 'md_date_month' }];

	const amendedLawsColumns = ['name', 'title_en', 'latest_amend_date', 'latest_amend_date_year', 'latest_amend_date_month', 'type_code', 'live', 'family'];
	const amendedLawsSorting: SortConfig[] = [{ column: 'latest_amend_date', direction: 'desc' }];
	const amendedLawsGrouping: GroupConfig[] = [{ column: 'latest_amend_date_year' }, { column: 'latest_amend_date_month' }];
	const amendedLawsLiveFilter: FilterCondition = { id: 'live-filter', field: 'live', operator: 'equals', value: '✔ In force' };

	const repealedLawsColumns = ['name', 'title_en', 'latest_rescind_date', 'latest_rescind_date_year', 'latest_rescind_date_month', 'type_code', 'live', 'family'];
	const repealedLawsSorting: SortConfig[] = [{ column: 'latest_rescind_date', direction: 'desc' }];
	const repealedLawsGrouping: GroupConfig[] = [{ column: 'latest_rescind_date_year' }, { column: 'latest_rescind_date_month' }];
	const repealedLawsLiveFilter: FilterCondition = { id: 'live-filter', field: 'live', operator: 'equals', value: '❌ Revoked / Repealed / Abolished' };

	// View group definitions (for sidebar — will be used when gridlite-views sidebar is ready)
	interface ViewGroupDef { id: string; name: string; order: number }
	const viewGroups: ViewGroupDef[] = [
		{ id: 'new-laws', name: 'New Laws', order: 0 },
		{ id: 'amended-laws', name: 'Amended Laws', order: 1 },
		{ id: 'repealed-laws', name: 'Repealed Laws', order: 2 },
		{ id: 'classification', name: 'Classification', order: 3 }
	];

	const viewGroupMapping: Record<string, string> = {
		'This Month': 'new-laws', 'Last Month': 'new-laws', 'This Quarter': 'new-laws',
		'Last Quarter': 'new-laws', 'This Year': 'new-laws', 'Last Year': 'new-laws', 'Last 3 Years': 'new-laws',
		'Amended This Month': 'amended-laws', 'Amended Last Month': 'amended-laws', 'Amended This Quarter': 'amended-laws',
		'Amended Last Quarter': 'amended-laws', 'Amended This Year': 'amended-laws', 'Amended Last Year': 'amended-laws', 'Amended Last 3 Years': 'amended-laws',
		'Repealed This Month': 'repealed-laws', 'Repealed Last Month': 'repealed-laws', 'Repealed This Quarter': 'repealed-laws',
		'Repealed Last Quarter': 'repealed-laws', 'Repealed This Year': 'repealed-laws', 'Repealed Last Year': 'repealed-laws', 'Repealed Last 3 Years': 'repealed-laws',
		'By Family': 'classification', 'By Status': 'classification', 'By Type': 'classification', 'Geographic Scope': 'classification'
	};

	// Default view definitions (using the new ViewConfig shape)
	interface ViewDef {
		name: string;
		description: string;
		config: ViewConfig;
		isDefault?: boolean;
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
			sorting: opts.sorting ?? [],
			grouping: opts.grouping ?? [],
			columnVisibility: colVis(opts.visibleCols),
			columnOrder: opts.visibleCols,
			columnWidths: {},
			pageSize: 25
		};
	}

	const defaultViews: ViewDef[] = [
		// New Laws
		{ name: 'This Month', description: 'Laws from this calendar month onwards.',
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: thisMonthStart }], sorting: newLawsSorting, grouping: newLawsGrouping }),
			isDefault: true },
		{ name: 'Last Month', description: 'Laws from the previous calendar month.',
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: lastMonthStart }, { id: 'f2', field: 'md_date', operator: 'is_before', value: thisMonthStart }], sorting: newLawsSorting, grouping: newLawsGrouping }) },
		{ name: 'This Quarter', description: 'Laws from this calendar quarter onwards.',
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: thisQuarterStart }], sorting: newLawsSorting, grouping: newLawsGrouping }) },
		{ name: 'Last Quarter', description: 'Laws from the previous calendar quarter.',
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: lastQuarterStart }, { id: 'f2', field: 'md_date', operator: 'is_before', value: thisQuarterStart }], sorting: newLawsSorting, grouping: newLawsGrouping }) },
		{ name: 'This Year', description: 'Laws from this calendar year onwards.',
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: thisYearStart }], sorting: newLawsSorting, grouping: newLawsGrouping }) },
		{ name: 'Last Year', description: `Laws from ${currentYear - 1}.`,
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: lastYearStart }, { id: 'f2', field: 'md_date', operator: 'is_before', value: thisYearStart }], sorting: newLawsSorting, grouping: newLawsGrouping }) },
		{ name: 'Last 3 Years', description: `Laws from ${currentYear - 3} to today.`,
			config: makeViewConfig({ visibleCols: newLawsColumns, filters: [{ id: 'f1', field: 'md_date', operator: 'is_after', value: threeYearsAgoStart }, { id: 'f2', field: 'md_date', operator: 'is_before', value: todayStr }], sorting: newLawsSorting, grouping: newLawsGrouping }) },
		// Amended Laws
		{ name: 'Amended This Month', description: 'Laws amended this month (in force).',
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: thisMonthStart }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		{ name: 'Amended Last Month', description: 'Laws amended last month (in force).',
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: lastMonthStart }, { id: 'f2', field: 'latest_amend_date', operator: 'is_before', value: thisMonthStart }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		{ name: 'Amended This Quarter', description: 'Laws amended this quarter (in force).',
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: thisQuarterStart }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		{ name: 'Amended Last Quarter', description: 'Laws amended last quarter (in force).',
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: lastQuarterStart }, { id: 'f2', field: 'latest_amend_date', operator: 'is_before', value: thisQuarterStart }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		{ name: 'Amended This Year', description: 'Laws amended this year (in force).',
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: thisYearStart }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		{ name: 'Amended Last Year', description: `Laws amended in ${currentYear - 1} (in force).`,
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: lastYearStart }, { id: 'f2', field: 'latest_amend_date', operator: 'is_before', value: thisYearStart }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		{ name: 'Amended Last 3 Years', description: `Laws amended from ${currentYear - 3} to today (in force).`,
			config: makeViewConfig({ visibleCols: amendedLawsColumns, filters: [{ id: 'f1', field: 'latest_amend_date', operator: 'is_after', value: threeYearsAgoStart }, { id: 'f2', field: 'latest_amend_date', operator: 'is_before', value: todayStr }, amendedLawsLiveFilter], sorting: amendedLawsSorting, grouping: amendedLawsGrouping }) },
		// Repealed Laws
		{ name: 'Repealed This Month', description: 'Laws repealed/revoked this month.',
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: thisMonthStart }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		{ name: 'Repealed Last Month', description: 'Laws repealed/revoked last month.',
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: lastMonthStart }, { id: 'f2', field: 'latest_rescind_date', operator: 'is_before', value: thisMonthStart }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		{ name: 'Repealed This Quarter', description: 'Laws repealed/revoked this quarter.',
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: thisQuarterStart }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		{ name: 'Repealed Last Quarter', description: 'Laws repealed/revoked last quarter.',
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: lastQuarterStart }, { id: 'f2', field: 'latest_rescind_date', operator: 'is_before', value: thisQuarterStart }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		{ name: 'Repealed This Year', description: 'Laws repealed/revoked this year.',
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: thisYearStart }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		{ name: 'Repealed Last Year', description: `Laws repealed/revoked in ${currentYear - 1}.`,
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: lastYearStart }, { id: 'f2', field: 'latest_rescind_date', operator: 'is_before', value: thisYearStart }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		{ name: 'Repealed Last 3 Years', description: `Laws repealed/revoked from ${currentYear - 3} to today.`,
			config: makeViewConfig({ visibleCols: repealedLawsColumns, filters: [{ id: 'f1', field: 'latest_rescind_date', operator: 'is_after', value: threeYearsAgoStart }, { id: 'f2', field: 'latest_rescind_date', operator: 'is_before', value: todayStr }, repealedLawsLiveFilter], sorting: repealedLawsSorting, grouping: repealedLawsGrouping }) },
		// Classification
		{ name: 'By Family', description: 'Browse laws organized by legal family classification.',
			config: makeViewConfig({ visibleCols: ['name', 'title_en', 'family', 'family_ii', 'year', 'type_code', 'live'], sorting: [{ column: 'family', direction: 'asc' }], grouping: [{ column: 'family' }] }) },
		{ name: 'By Status', description: 'Laws grouped by current status.',
			config: makeViewConfig({ visibleCols: ['name', 'title_en', 'live', 'year', 'type_code', 'md_date', 'family'], sorting: [{ column: 'md_date', direction: 'desc' }], grouping: [{ column: 'live' }] }) },
		{ name: 'By Type', description: 'Laws grouped by legislation type.',
			config: makeViewConfig({ visibleCols: ['name', 'title_en', 'type_code', 'type_class', 'year', 'live', 'md_date'], sorting: [{ column: 'md_date', direction: 'desc' }], grouping: [{ column: 'type_code' }] }) },
		{ name: 'Geographic Scope', description: 'Laws by geographic extent.',
			config: makeViewConfig({ visibleCols: ['name', 'title_en', 'geo_extent', 'geo_region', 'year', 'type_code', 'live'], sorting: [{ column: 'md_date', direction: 'desc' }], grouping: [{ column: 'geo_extent' }] }) }
	];

	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));

	// Sidebar state — grouped views list built from viewStore
	let sidebarOpen = false;

	interface SidebarViewItem { id: string; name: string; groupId: string; order: number; isDefault?: boolean }
	let sidebarViews: SidebarViewItem[] = [];

	function rebuildSidebarViews(views: SavedView[]) {
		sidebarViews = views
			.map((v): SidebarViewItem => ({
				id: v.id,
				name: v.name,
				groupId: viewGroupMapping[v.name] || 'custom',
				order: viewOrderMap.get(v.name) ?? 1000,
				isDefault: defaultViews.find((dv) => dv.name === v.name)?.isDefault
			}))
			.sort((a, b) => a.order - b.order);
	}

	// Seed default views into PGLite-backed store
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
				console.error('[Browse] Failed to seed view:', view.name, err);
			}
		}

		// Auto-select default view
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => { activeId = v; })();
		if (defaultViewId && !activeId) {
			const loadedView = await actions.load(defaultViewId);
			if (loadedView) {
				applyViewToGrid(loadedView);
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
		gridRef.applyConfig({
			filters: cfg.filters as FilterCondition[],
			filterLogic: cfg.filterLogic,
			sorting: cfg.sorting as SortConfig[],
			grouping: cfg.grouping as GroupConfig[]
		});
	}

	// Handle sidebar view selection
	async function handleViewSelect(viewItem: SidebarViewItem) {
		if (!viewStore) return;
		const view = await viewStore.actions.load(viewItem.id);
		if (view) {
			applyViewToGrid(view);
		}
		sidebarOpen = false;
	}

	// Capture current grid state for saving as a view
	function captureCurrentConfig(state: GridState): ViewConfig {
		return {
			filters: state.filters as FilterCondition[],
			filterLogic: state.filterLogic,
			sorting: state.sorting,
			grouping: state.grouping,
			columnVisibility: state.columnVisibility,
			columnOrder: state.columnOrder,
			columnWidths: state.columnSizing,
			pageSize: state.pagination.pageSize
		};
	}

	let latestGridState: GridState | null = null;

	function handleStateChange(state: GridState) {
		latestGridState = state;
	}

	function handleSaveView() {
		if (!latestGridState) return;
		capturedConfig = captureCurrentConfig(latestGridState);
		showSaveModal = true;
	}

	function handleViewSaved(event: CustomEvent<{ id: string; name: string }>) {
		console.log('[Browse] View saved:', event.detail.name);
	}

	// Monitor sync errors
	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}

	$: isLoading = !$syncStatus.connected && !ready;

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await runViewMigrations(db as any);
			viewStore = initViewStore(db as any, 'browse');
			const collection = createPGLiteCollection({
				db, query: BROWSE_SQL, id: 'browse-uk-lrt'
			});
			adapter = createTanStackDBAdapter({ collection, columns: browseColumnMetadata });
			await adapter.init();
			ready = true;
			// Wait for next tick so GridLite renders, then seed views
			setTimeout(() => seedDefaultViews(), 100);
		}
	});

	onDestroy(() => {
		viewStore?.destroy();
	});
</script>

<div class="flex h-full relative">
	<!-- Mobile sidebar overlay -->
	{#if sidebarOpen}
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div class="fixed inset-0 bg-black/30 z-30 lg:hidden" on:click={() => (sidebarOpen = false)} />
	{/if}

	<!-- View Sidebar (simple list until gridlite-views sidebar component is released) -->
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
	<div class="flex-1 overflow-auto px-6 py-4">
		<div class="mb-4 flex items-center gap-3">
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
				<h1 class="text-xl font-bold text-gray-900">UK Legal Register</h1>
				<p class="text-sm text-gray-600">Browse UK Legal, Regulatory & Transport records.</p>
			</div>
		</div>

		{#if isLoading}
			<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
				<div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"></div>
				<p class="mt-4 text-gray-600">Loading UK LRT data...</p>
			</div>
		{:else if error}
			<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
				<h3 class="text-lg font-semibold text-red-800 mb-2">Error Loading Data</h3>
				<p class="text-red-600">{error}</p>
				<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700" on:click={() => window.location.reload()}>Retry</button>
			</div>
		{:else if ready && adapter}
			<!-- Stats -->
			<div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
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
					<div class="text-sm text-gray-600">Total Records</div>
					<div class="text-sm font-medium text-gray-700">{$syncStatus.recordCount.toLocaleString()} in local database</div>
				</div>
			</div>

			<!-- GridLite Table -->
			<GridLite
				bind:this={gridRef}
				{adapter}
				onStateChange={handleStateChange}
				config={{
					id: 'browse',
					columns,
					defaultFilters: [{ id: 'default-date', field: 'md_date', operator: 'is_after', value: thisMonthStart }],
					defaultSorting: [{ column: 'md_date_year', direction: 'desc' }, { column: 'md_date_month', direction: 'desc' }],
					defaultGrouping: [{ column: 'md_date_year' }, { column: 'md_date_month' }],
					defaultVisibleColumns: newLawsColumns,
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
					globalSearch: true,
					rowDetail: true
				}}
			>
				<!-- Save View Button -->
				<svelte:fragment slot="toolbar-start">
					<button
						type="button"
						on:click={handleSaveView}
						class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 focus:outline-none focus:ring-2 focus:ring-emerald-500"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
						</svg>
						Save View
					</button>
				</svelte:fragment>

				<!-- Custom cell rendering -->
				<svelte:fragment slot="cell" let:value let:row let:column>
					{#if column === 'family'}
						{@const display = getFamilyDisplay(asStr(value))}
						<span class="truncate">
							{#if display.prefix}
								<span class="inline-block px-1 text-xs font-medium rounded mr-1 {display.prefix === 'HS' ? 'bg-blue-100 text-blue-700' : display.prefix === 'E' ? 'bg-green-100 text-green-700' : 'bg-purple-100 text-purple-700'}">
									{display.prefix}
								</span>
							{/if}
							{display.name}
						</span>
					{:else if column === 'title_en'}
						{value || '-'}
					{:else if column === 'leg_gov_uk_url'}
						{#if value}
							<a href={String(value)} target="_blank" rel="noopener noreferrer" class="flex items-center justify-center w-full h-full text-blue-600 hover:text-blue-800 hover:underline">View</a>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
					{:else if column === 'live'}
						<span class="inline-flex px-2 py-0.5 text-xs font-medium rounded {value === 'Live' ? 'bg-green-100 text-green-800' : value === 'Revoked' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'}">
							{value || '-'}
						</span>
					{:else if column === 'function'}
						{@const fns = parseFunctionKeys(row.function)}
						{#if fns?.length}
							<span class="flex flex-wrap gap-1">
								{#each fns as fn}
									<span class="px-1.5 py-0.5 text-xs rounded {fn === 'Making' ? 'bg-green-100 text-green-700' : fn === 'Amending' ? 'bg-yellow-100 text-yellow-700' : fn === 'Revoking' ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'}">
										{fn}
									</span>
								{/each}
							</span>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
					{:else}
						{value ?? '-'}
					{/if}
				</svelte:fragment>

				<!-- Custom row detail -->
				<div slot="row-detail" let:row let:close>
					{#if row}
						{@const r = asRec(row)}
						{@const familyDisplay = getFamilyDisplay(asStr(r.family))}
						{@const fns = parseFunctionKeys(r.function)}
						<div class="max-w-4xl mx-auto">
							<div class="mb-6">
								<div class="flex items-start gap-3 mb-2">
									{#if familyDisplay.prefix}
										<span class="inline-block px-2 py-1 text-sm font-medium rounded {familyDisplay.prefix === 'HS' ? 'bg-blue-100 text-blue-700' : familyDisplay.prefix === 'E' ? 'bg-green-100 text-green-700' : 'bg-purple-100 text-purple-700'}">
											{familyDisplay.prefix}
										</span>
									{/if}
									<div>
										<h2 class="text-xl font-bold text-gray-900">{r.title_en || r.name}</h2>
										<p class="text-sm text-gray-500 font-mono mt-1">{r.name}</p>
									</div>
								</div>
								<div class="flex flex-wrap gap-2 mt-3">
									{#if r.live}
										<span class="inline-flex px-2 py-0.5 text-xs font-medium rounded {r.live === 'Live' ? 'bg-green-100 text-green-800' : r.live === 'Revoked' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'}">{r.live}</span>
									{/if}
									{#if fns?.length}
										{#each fns as fn}
											<span class="px-2 py-0.5 text-xs rounded {fn === 'Making' ? 'bg-green-100 text-green-700' : fn === 'Amending' ? 'bg-yellow-100 text-yellow-700' : fn === 'Revoking' ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'}">{fn}</span>
										{/each}
									{/if}
									{#if r.leg_gov_uk_url}
										<a href={String(r.leg_gov_uk_url)} target="_blank" rel="noopener noreferrer" class="inline-flex items-center gap-1 px-2 py-0.5 text-xs text-blue-600 hover:text-blue-800 bg-blue-50 rounded">
											legislation.gov.uk
											<svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
										</a>
									{/if}
								</div>
							</div>

							<div class="grid grid-cols-1 md:grid-cols-2 gap-6">
								<section class="bg-gray-50 rounded-lg p-4">
									<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Credentials</h3>
									<dl class="space-y-2">
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Year</dt><dd class="text-sm font-medium text-gray-900">{r.year}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Number</dt><dd class="text-sm font-medium text-gray-900">{r.number || '-'}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Type Code</dt><dd class="text-sm font-medium text-gray-900 uppercase">{r.type_code || '-'}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Type Class</dt><dd class="text-sm font-medium text-gray-900">{r.type_class || '-'}</dd></div>
									</dl>
								</section>
								<section class="bg-gray-50 rounded-lg p-4">
									<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Classification</h3>
									<dl class="space-y-2">
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Family</dt><dd class="text-sm font-medium text-gray-900">{r.family || '-'}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Family II</dt><dd class="text-sm font-medium text-gray-900">{r.family_ii || '-'}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">SI Code</dt><dd class="text-sm font-medium text-gray-900">{r.si_code || '-'}</dd></div>
									</dl>
								</section>
								<section class="bg-gray-50 rounded-lg p-4">
									<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Geographic</h3>
									<dl class="space-y-2">
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Extent</dt><dd class="text-sm font-medium text-gray-900">{r.geo_extent || '-'}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Region</dt><dd class="text-sm font-medium text-gray-900">{r.geo_region || '-'}</dd></div>
									</dl>
								</section>
								<section class="bg-gray-50 rounded-lg p-4">
									<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Key Dates</h3>
									<dl class="space-y-2">
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Primary Date</dt><dd class="text-sm font-medium text-gray-900">{formatDate(asStr(r.md_date))}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Made</dt><dd class="text-sm font-medium text-gray-900">{formatDate(asStr(r.md_made_date))}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">In Force</dt><dd class="text-sm font-medium text-gray-900">{formatDate(asStr(r.md_coming_into_force_date))}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Last Amended</dt><dd class="text-sm font-medium text-gray-900">{formatDate(asStr(r.latest_amend_date))}</dd></div>
										<div class="flex justify-between"><dt class="text-sm text-gray-600">Last Rescinded</dt><dd class="text-sm font-medium text-gray-900">{formatDate(asStr(r.latest_rescind_date))}</dd></div>
									</dl>
								</section>
							</div>
						</div>
					{/if}
				</div>
			</GridLite>
		{/if}
	</div>
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig && viewStore}
	<SaveViewModal bind:open={showSaveModal} {viewStore} config={capturedConfig} on:save={handleViewSaved} />
{/if}
