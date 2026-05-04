<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { GridLite, buildQuery } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type {
		ColumnConfig,
		GridState,
		FilterCondition,
		FilterNode,
		SortConfig,
		GroupConfig
	} from '@shotleybuilder/svelte-gridlite-kit';
	import { createTanStackDBAdapter } from '@shotleybuilder/gridlite-adapter-tanstack-db';
	import { createPGLiteCollection } from '$lib/pglite/collection-bridge';
	import type { Collection } from '@tanstack/db';
	import { UK_LRT_COLUMN_METADATA } from '$lib/pglite/uk-lrt-columns';
	import {
		initViewStore,
		SaveViewModal,
		ViewSidebar,
		runViewMigrations
	} from '@shotleybuilder/svelte-gridlite-views';
	import type {
		ViewConfig,
		SavedView,
		ViewStoreBundle,
		ViewGroup
	} from '@shotleybuilder/svelte-gridlite-views';

	import { goto } from '$app/navigation';
	import { useQueryClient } from '@tanstack/svelte-query';
	import { reparseLat, createLatSessionFromView } from '$lib/api/lat';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';
	import ParseReviewModal from '$lib/components/ParseReviewModal.svelte';
	import LatParseDialog from '$lib/components/LatParseDialog.svelte';
	import {
		seedDefaultViews as seedDefaults,
		seedDefaultGroups,
		assignViewsToGroups
	} from '$lib/views/seed-defaults';
	import type { GroupDef } from '$lib/views/seed-defaults';

	const queryClient = useQueryClient();

	// ── PGLite + GridLite state ─────────────────────────────────────

	let db: PGLiteWithExtensions | null = null;
	let ready = false;
	let gridRef: GridLite;
	let adapter: ReturnType<typeof createTanStackDBAdapter> | null = null;
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let collectionRef: Collection<any, any, any, any, any> | null = null;
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

	// ── Query + Filter constants ────────────────────────────────────

	const QUEUE_COLUMNS_LIST = [
		'id',
		'name',
		'title_en',
		'year',
		'type_code',
		'family',
		'family_ii',
		'is_making',
		'making_classification',
		'live',
		'live_from_changes',
		'function',
		'updated_at',
		'lat_count',
		'latest_lat_updated_at'
	];
	const QUEUE_COLUMNS = QUEUE_COLUMNS_LIST.join(', ');
	// Pre-compute lat_stale: true when LRT was updated > 6 months after LAT was last parsed
	const BASE_QUERY = `SELECT ${QUEUE_COLUMNS}, (updated_at IS NOT NULL AND latest_lat_updated_at IS NOT NULL AND updated_at > latest_lat_updated_at + INTERVAL '6 months') AS lat_stale FROM uk_lrt`;
	const queueColumnMetadata = [
		...UK_LRT_COLUMN_METADATA.filter((c) => QUEUE_COLUMNS_LIST.includes(c.name)),
		{
			name: 'lat_stale',
			dataType: 'boolean' as const,
			postgresType: 'bool',
			nullable: true,
			hasDefault: false
		}
	];

	// Core filters (always apply): candidates for LAT parsing, not revoked
	// making_classification != 'not_making' (includes 'making', 'uncertain', and NULL/unclassified)
	const QUEUE_CORE_FILTERS: FilterNode[] = [
		{
			id: 'q-class-ok',
			logic: 'or' as const,
			children: [
				{ id: 'q-class-null', field: 'making_classification', operator: 'is_empty', value: '' },
				{
					id: 'q-class-ne',
					field: 'making_classification',
					operator: 'not_equals',
					value: 'not_making'
				}
			]
		},
		// live IS NULL OR != '❌ Revoked / Repealed / Abolished' → OR group
		{
			id: 'q-live-ok',
			logic: 'or' as const,
			children: [
				{ id: 'q-live-null', field: 'live', operator: 'is_empty', value: '' },
				{
					id: 'q-live-ne',
					field: 'live',
					operator: 'not_equals',
					value: '❌ Revoked / Repealed / Abolished'
				}
			]
		}
	];

	// Guard filters — only needed for broad views without a specific family
	const QUEUE_BROAD_GUARDS: FilterNode[] = [
		{ id: 'q-has-title', field: 'title_en', operator: 'is_not_empty', value: '' },
		{ id: 'q-has-family', field: 'family', operator: 'is_not_empty', value: '' },
		{ id: 'q-not-todo', field: 'family', operator: 'not_equals', value: '_todo' }
	];

	// Full base filters for broad views (no specific family)
	const QUEUE_BASE_FILTERS: FilterNode[] = [...QUEUE_CORE_FILTERS, ...QUEUE_BROAD_GUARDS];

	// LAT queue filter: missing OR stale (lat_stale pre-computed in SQL)
	const QUEUE_LAT_FILTER: FilterNode = {
		id: 'q-lat-need',
		logic: 'or' as const,
		children: [
			{ id: 'q-lat-zero', field: 'lat_count', operator: 'equals', value: 0 },
			{ id: 'q-lat-stale', field: 'lat_stale', operator: 'equals', value: true }
		]
	};

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

	// Build the effective SQL query including GridLite filters (for reparse operations)
	function getEffectiveQuery(): { sql: string; params: unknown[] } {
		if (!latestGridState) return { sql: currentQuery, params: [] };
		return buildQuery({
			source: currentQuery,
			filters: latestGridState.filters as FilterCondition[],
			filterLogic: latestGridState.filterLogic as 'and' | 'or',
			sorting: latestGridState.sorting as SortConfig[],
			allowedColumns: columns.map((c) => c.name)
		});
	}

	async function handleReparseViewConfirm() {
		reparseViewLoading = true;
		reparseViewError = null;
		try {
			const { sql, params } = getEffectiveQuery();
			const result = await db?.query<{ name: string }>(sql, params);
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

	/**
	 * Update a record via TanStack DB optimistic mutation.
	 * The collection.update() call applies the change instantly (optimistic),
	 * then the onUpdate handler persists to backend + PGLite asynchronously.
	 */
	function updateRecord(id: string, field: string, value: string | boolean | null) {
		if (!collectionRef) return;
		const tx = collectionRef.update(id, (draft: Record<string, unknown>) => {
			draft[field] = value === '' ? null : value;
		});
		// Surface persistence errors to the user
		tx.isPersisted.promise.catch((e: unknown) => {
			alert(`Update failed: ${e instanceof Error ? e.message : 'Unknown error'}`);
		});
	}

	function startEdit(id: string, field: string, currentValue: string | null) {
		editingCell = { id, field };
		editValue = currentValue ?? '';
	}

	async function saveEdit(value?: string) {
		if (!editingCell) return;
		const { id, field } = editingCell;
		const val = (value !== undefined ? value : editValue) || null;
		// Clear state before await to prevent double-saves and give instant feedback
		editingCell = null;
		editValue = '';
		await updateRecord(id, field, val);
	}

	/** Save on select change — reads value from DOM event to avoid bind:value race. */
	function handleSelectSave(e: Event) {
		const target = e.currentTarget as HTMLSelectElement;
		saveEdit(target.value);
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
	function str(v: unknown): string {
		return String(v ?? '');
	}
	function bool(v: unknown): boolean {
		return Boolean(v);
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

	// Electric sends JSONB `function` as a JS object {Making: true, ...}
	function parseFunctionKeys(fn: unknown): string[] | null {
		if (!fn) return null;
		if (Array.isArray(fn)) return fn as string[];
		if (typeof fn === 'object') {
			return Object.keys(fn as Record<string, boolean>).filter(
				(k) => (fn as Record<string, boolean>)[k]
			);
		}
		if (typeof fn === 'string') {
			try {
				const parsed = JSON.parse(fn);
				if (typeof parsed === 'object' && !Array.isArray(parsed)) {
					return Object.keys(parsed).filter((k) => parsed[k]);
				}
			} catch {
				/* not JSON */
			}
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
			'💙 PUBLIC: Data',
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
		hr: [
			'💜 HR: Employment',
			'💜 HR: Insurance / Compensation / Wages / Benefits',
			'💜 HR: Working Time'
		]
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
		{
			name: 'making_classification',
			label: 'Making Classification',
			width: 160,
			dataType: 'text',
			selectOptions: makingClassificationOptions
		},
		{ name: 'year', label: 'Year', width: 80, dataType: 'number' },
		{
			name: 'live',
			label: 'Status',
			width: 100,
			dataType: 'text',
			selectOptions: liveStatusOptions
		},
		{ name: 'live_from_changes', label: 'From Changes', width: 130, dataType: 'text' },
		{ name: 'function', label: 'Function', width: 150, dataType: 'json' },
		{ name: 'lat_count', label: 'LAT Rows', width: 80, dataType: 'number' },
		{
			name: 'updated_at',
			label: 'LRT Updated',
			width: 110,
			dataType: 'date',
			format: (v) => formatDate(v as string | null)
		},
		{
			name: 'latest_lat_updated_at',
			label: 'LAT Updated',
			width: 110,
			dataType: 'date',
			format: (v) => formatDate(v as string | null)
		}
	];

	// ── Family-based view definitions ───────────────────────────────

	interface FamilyViewDef {
		name: string;
		family: string;
		group: 'safety' | 'environment' | 'hr';
	}

	const familyViewDefs: FamilyViewDef[] = [
		{ name: 'Fire', family: '💙 FIRE', group: 'safety' },
		{
			name: 'Fire: Dangerous & Explosive',
			family: '💙 FIRE: Dangerous and Explosive Substances',
			group: 'safety'
		},
		{ name: 'Food', family: '💙 FOOD', group: 'safety' },
		{ name: 'Health: Coronavirus', family: '💙 HEALTH: Coronavirus', group: 'safety' },
		{
			name: 'Health: Drug & Medicine',
			family: '💙 HEALTH: Drug & Medicine Safety',
			group: 'safety'
		},
		{ name: 'Health: Patient Safety', family: '💙 HEALTH: Patient Safety', group: 'safety' },
		{ name: 'Health: Public', family: '💙 HEALTH: Public', group: 'safety' },
		{ name: 'OHS: Gas & Electrical', family: '💙 OH&S: Gas & Electrical Safety', group: 'safety' },
		{ name: 'OHS: Mines & Quarries', family: '💙 OH&S: Mines & Quarries', group: 'safety' },
		{
			name: 'OHS: Occupational',
			family: '💙 OH&S: Occupational / Personal Safety',
			group: 'safety'
		},
		{ name: 'OHS: Offshore', family: '💙 OH&S: Offshore Safety', group: 'safety' },
		{ name: 'Public', family: '💙 PUBLIC', group: 'safety' },
		{ name: 'Public: Building Safety', family: '💙 PUBLIC: Building Safety', group: 'safety' },
		{
			name: 'Public: Consumer / Product',
			family: '💙 PUBLIC: Consumer / Product Safety',
			group: 'safety'
		},
		{ name: 'Public: Data', family: '💙 PUBLIC: Data', group: 'safety' },
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
		{
			name: 'Environmental Protection',
			family: '💚 ENVIRONMENTAL PROTECTION',
			group: 'environment'
		},
		{ name: 'Finance', family: '💚 FINANCE', group: 'environment' },
		{ name: 'Fisheries & Fishing', family: '💚 FISHERIES & FISHING', group: 'environment' },
		{ name: 'GMOs', family: '💚 GMOs', group: 'environment' },
		{ name: 'Historic Environment', family: '💚 HISTORIC ENVIRONMENT', group: 'environment' },
		{ name: 'Marine & Riverine', family: '💚 MARINE & RIVERINE', group: 'environment' },
		{ name: 'Noise', family: '💚 NOISE', group: 'environment' },
		{ name: 'Nuclear & Radiological', family: '💚 NUCLEAR & RADIOLOGICAL', group: 'environment' },
		{
			name: 'Oil & Gas / Offshore',
			family: '💚 OIL & GAS - OFFSHORE - PETROLEUM',
			group: 'environment'
		},
		{
			name: 'Planning & Infrastructure',
			family: '💚 PLANNING & INFRASTRUCTURE',
			group: 'environment'
		},
		{ name: 'Plant Health', family: '💚 PLANT HEALTH', group: 'environment' },
		{ name: 'Pollution', family: '💚 POLLUTION', group: 'environment' },
		{ name: 'Town & Country Planning', family: '💚 TOWN & COUNTRY PLANNING', group: 'environment' },
		{ name: 'Transport', family: '💚 TRANSPORT', group: 'environment' },
		{ name: 'Transport: Aviation', family: '💚 TRANSPORT: Aviation', group: 'environment' },
		{
			name: 'Transport: Harbours & Shipping',
			family: '💚 TRANSPORT: Harbours & Shipping',
			group: 'environment'
		},
		{
			name: 'Transport: Railways',
			family: '💚 TRANSPORT: Railways & Rail Transport',
			group: 'environment'
		},
		{
			name: 'Transport: Roads & Vehicles',
			family: '💚 TRANSPORT: Roads & Vehicles',
			group: 'environment'
		},
		{
			name: 'Trees: Forestry & Timber',
			family: '💚 TREES: Forestry & Timber',
			group: 'environment'
		},
		{ name: 'Waste', family: '💚 WASTE', group: 'environment' },
		{ name: 'Water & Wastewater', family: '💚 WATER & WASTEWATER', group: 'environment' },
		{ name: 'Wildlife & Countryside', family: '💚 WILDLIFE & COUNTRYSIDE', group: 'environment' },
		{ name: 'Employment', family: '💜 HR: Employment', group: 'hr' },
		{
			name: 'Insurance / Compensation',
			family: '💜 HR: Insurance / Compensation / Wages / Benefits',
			group: 'hr'
		},
		{ name: 'Working Time', family: '💜 HR: Working Time', group: 'hr' }
	];

	// Mappings
	const viewFamilyMapping: Record<string, string> = {};
	for (const def of familyViewDefs) viewFamilyMapping[def.name] = def.family;

	// Default group definitions for ViewSidebar seeding
	const defaultGroupDefs: GroupDef[] = [
		{ name: 'Queue', icon: '📋' },
		{ name: '💙 S', icon: '💙' },
		{ name: '💚 E', icon: '💚' },
		{ name: '💜 HR', icon: '💜' },
		{ name: 'Analytics', icon: '📊' }
	];

	// Map view name → group name (for seeding assignments)
	const viewToGroupName: Record<string, string> = {};
	for (const def of familyViewDefs) {
		viewToGroupName[def.name] =
			def.group === 'safety' ? '💙 S' : def.group === 'environment' ? '💚 E' : '💜 HR';
	}
	viewToGroupName['All Queue'] = 'Queue';
	viewToGroupName['Missing LAT'] = 'Queue';
	viewToGroupName['Stale LAT'] = 'Queue';
	viewToGroupName['Live'] = 'Analytics';

	// Column visibility sets
	const allCols = columns.map((c) => c.name);
	const familyCols = [
		'name',
		'title_en',
		'is_making',
		'making_classification',
		'year',
		'live',
		'function',
		'lat_count',
		'updated_at',
		'latest_lat_updated_at'
	];
	const liveCols = ['name', 'title_en', 'year', 'live', 'live_from_changes', 'lat_count'];

	// Helper to build column visibility map
	function colVis(visibleCols: string[]): Record<string, boolean> {
		const vis: Record<string, boolean> = {};
		for (const col of columns) vis[col.name] = visibleCols.includes(col.name);
		return vis;
	}

	function makeViewConfig(opts: {
		visibleCols: string[];
		filters?: FilterNode[];
		sorting?: SortConfig[];
		grouping?: GroupConfig[];
	}): ViewConfig {
		return {
			// Cast: ViewConfig.filters is typed as FilterCondition[] but we store FilterNode[]
			// (including FilterGroup). The views lib serializes to JSON so this is safe at runtime.
			filters: (opts.filters ?? []) as FilterCondition[],
			filterLogic: 'and',
			sorting: opts.sorting ?? [{ column: 'updated_at', direction: 'asc' }],
			grouping: opts.grouping ?? [{ column: 'family' }, { column: 'year' }],
			columnVisibility: colVis(opts.visibleCols),
			columnOrder: opts.visibleCols,
			columnWidths: {},
			pageSize: 50
		};
	}

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
			config: makeViewConfig({
				visibleCols: allCols,
				filters: [...QUEUE_BASE_FILTERS, QUEUE_LAT_FILTER]
			}),
			isDefault: true
		},
		{
			name: 'Missing LAT',
			description: 'LRT records with making function that have no LAT data at all.',
			config: makeViewConfig({
				visibleCols: allCols,
				filters: [
					...QUEUE_BASE_FILTERS,
					{ id: 'q-lat-missing', field: 'lat_count', operator: 'equals', value: 0 }
				]
			})
		},
		{
			name: 'Stale LAT',
			description: 'LRT records where LAT data exists but is more than 6 months out of date.',
			config: makeViewConfig({
				visibleCols: allCols,
				filters: [
					...QUEUE_BASE_FILTERS,
					{ id: 'q-lat-gt0', field: 'lat_count', operator: 'greater_than', value: 0 },
					{ id: 'q-lat-stale2', field: 'lat_stale', operator: 'equals', value: true }
				]
			})
		},
		...familyViewDefs.map(
			(def, i): ViewDef => ({
				name: def.name,
				description: `${def.family} — LAT parse candidates`,
				config: makeViewConfig({
					visibleCols: familyCols,
					filters: [
						...QUEUE_CORE_FILTERS,
						QUEUE_LAT_FILTER,
						{ id: `q-fam-${i}`, field: 'family', operator: 'equals', value: def.family }
					],
					sorting: [{ column: 'name', direction: 'asc' }],
					grouping: [{ column: 'year' }]
				})
			})
		),
		{
			name: 'Live',
			description: 'Live status reconciliation — OH&S Occupational / Personal Safety',
			config: makeViewConfig({
				visibleCols: liveCols,
				filters: [
					{
						id: 'q-live-fam',
						field: 'family',
						operator: 'equals',
						value: '💙 OH&S: Occupational / Personal Safety'
					},
					{ id: 'q-live-title', field: 'title_en', operator: 'is_not_empty', value: '' }
				],
				sorting: [{ column: 'name', direction: 'asc' }],
				grouping: []
			})
		}
	];

	// ── Sidebar state ───────────────────────────────────────────────

	let sidebarVisible = false;

	// ── View lifecycle ──────────────────────────────────────────────

	async function seedDefaultViews() {
		if (!viewStore) return;
		const { actions, savedViews: svStore, groupActions, savedGroups: grpStore } = viewStore;
		await actions.waitForReady();

		// One-time wipe of stale views (pre-filter-conversion format)
		const versionKey = 'lat-queue-view-version';
		if (localStorage.getItem(versionKey) !== '11') {
			let existingViews: SavedView[] = [];
			svStore.subscribe((v) => {
				existingViews = v;
			})();
			if (existingViews.length > 0) {
				// Wipe via raw SQL to avoid live-query cascade from individual deletes
				await db!.exec(
					`DELETE FROM _gridlite_views WHERE grid_id = 'lat-queue'; DELETE FROM _gridlite_view_groups WHERE grid_id = 'lat-queue'`
				);
				// Wait for live query to propagate the deletion before re-reading
				await new Promise((r) => setTimeout(r, 200));
			}
			localStorage.setItem(versionKey, '11');
		}

		let currentViews: SavedView[] = [];
		const unsub = svStore.subscribe((v) => {
			currentViews = v;
		});

		// Same pattern as working LRT page: dedup, update stale configs, seed missing
		const { defaultViewId } = await seedDefaults(defaultViews, currentViews, actions);

		// Seed groups and assign views to groups
		let currentGroups: ViewGroup[] = [];
		const unsubGrp = grpStore.subscribe((g) => {
			currentGroups = g;
		});
		const groupNameToId = await seedDefaultGroups(defaultGroupDefs, currentGroups, groupActions);
		svStore.subscribe((v) => {
			currentViews = v;
		})();
		await assignViewsToGroups(viewToGroupName, groupNameToId, currentViews, groupActions);
		unsubGrp();

		// Auto-select default view
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => {
			activeId = v;
		})();
		if (defaultViewId && !activeId) {
			const loadedView = await actions.load(defaultViewId);
			if (loadedView) {
				switchToView('All Queue');
				applyViewToGrid(loadedView);
			}
		} else if (activeId) {
			let activeView: SavedView | null = null;
			svStore.subscribe((views) => {
				activeView = views.find((v) => v.id === activeId) ?? null;
			})();
			if (activeView) {
				switchToView((activeView as SavedView).name);
				applyViewToGrid(activeView as SavedView);
			}
		}

		unsub();
	}

	function applyViewToGrid(view: SavedView) {
		if (!gridRef) return;
		const cfg = view.config;
		gridRef.applyConfig({
			filters: cfg.filters as FilterNode[],
			filterLogic: cfg.filterLogic,
			sorting: cfg.sorting as SortConfig[],
			grouping: cfg.grouping as GroupConfig[]
		});
	}

	// Track visible columns for GridLite config on {#key} remount
	let activeVisibleColumns: string[] = allCols;

	function switchToView(viewName: string, savedConfig?: ViewConfig) {
		currentViewName = viewName;
		currentQuery = BASE_QUERY;
		currentFamily = viewFamilyMapping[viewName] ?? null;
		if (savedConfig?.columnVisibility) {
			activeVisibleColumns = Object.entries(savedConfig.columnVisibility)
				.filter(([, visible]) => visible)
				.map(([name]) => name);
		} else {
			const viewDef = defaultViews.find((v) => v.name === viewName);
			activeVisibleColumns = viewDef?.config.columnOrder ?? allCols;
		}
	}

	function handleViewSelected(e: CustomEvent<{ view: SavedView }>) {
		const view = e.detail.view;
		switchToView(view.name, view.config);
		applyViewToGrid(view);
		sidebarVisible = false;
	}

	// ── Grid state management ───────────────────────────────────────

	let latestGridState: GridState | null = null;

	function handleStateChange(state: GridState) {
		latestGridState = state;
	}

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

	function handleSaveView() {
		if (!latestGridState) return;
		capturedConfig = captureCurrentConfig(latestGridState);
		showSaveModal = true;
	}

	async function handleUpdateView() {
		if (!viewStore || !latestGridState) return;
		let activeId: string | null = null;
		viewStore.activeViewId.subscribe((v) => {
			activeId = v;
		})();
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

	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}
	$: isLoading = !$syncStatus.connected && !ready;

	// Adapter is created once in onMount via createPGLiteCollection + createTanStackDBAdapter.
	// Filtering is handled by GridLite's filter descriptors, not by changing the SQL query.

	let hasActiveView = false;
	let activeViewUnsub: (() => void) | null = null;
	$: if (viewStore) {
		activeViewUnsub?.();
		activeViewUnsub = viewStore.activeViewId.subscribe((v) => {
			hasActiveView = !!v;
		});
	}

	// Reparse view record count — use effective filtered query
	$: if (showReparseViewDialog && db && currentQuery) {
		const eff = getEffectiveQuery();
		db.query<{ count: string }>(`SELECT COUNT(*) as count FROM (${eff.sql}) sub`, eff.params)
			.then((r) => {
				reparseViewCount = parseInt(r.rows[0]?.count ?? '0', 10);
			})
			.catch(() => {
				reparseViewCount = 0;
			});
	}

	// Stats from current filtered query
	let statTotal = 0;
	let statMissing = 0;
	let statStale = 0;

	async function refreshStats() {
		if (!db || !latestGridState) return;
		try {
			const { sql, params } = getEffectiveQuery();
			const total = await db.query<{ count: string }>(
				`SELECT COUNT(*) as count FROM (${sql}) sub`,
				params
			);
			statTotal = parseInt(total.rows[0]?.count ?? '0', 10);
			// For detailed stats, check if the filtered data includes lat_count-based filters
			const hasLatFilters = latestGridState.filters.some(
				(f: any) => f.field === 'lat_count' || f.id?.startsWith('q-lat')
			);
			if (hasLatFilters) {
				const missing = await db.query<{ count: string }>(
					`SELECT COUNT(*) as count FROM (${sql}) sub WHERE lat_count = 0`,
					params
				);
				statMissing = parseInt(missing.rows[0]?.count ?? '0', 10);
				statStale = statTotal - statMissing;
			} else {
				statMissing = 0;
				statStale = 0;
			}
		} catch {
			/* ignore */
		}
	}

	$: if (ready && db && latestGridState) {
		refreshStats();
	}

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await runViewMigrations(db as any);
			viewStore = initViewStore(db as any, 'lat-queue');
			/** Editable fields — whitelist prevents SQL injection via column name in PGLite write. */
			const EDITABLE_FIELDS = new Set([
				'family',
				'family_ii',
				'making_classification',
				'is_making'
			]);

			const collection = createPGLiteCollection({
				db,
				query: BASE_QUERY,
				id: 'lat-queue-uk-lrt',
				onUpdate: async ({ transaction }) => {
					for (const m of transaction.mutations) {
						// Filter to whitelisted fields only (SQL injection safety for PGLite write)
						const safeChanges: Record<string, unknown> = {};
						for (const [field, value] of Object.entries(m.changes as Record<string, unknown>)) {
							if (EDITABLE_FIELDS.has(field)) {
								safeChanges[field] = value;
							}
						}
						if (Object.keys(safeChanges).length === 0) continue;

						// 1. Persist to backend (PostgreSQL)
						const response = await authFetch(`${API_URL}/api/uk-lrt/${m.key}`, {
							method: 'PATCH',
							headers: { 'Content-Type': 'application/json' },
							body: JSON.stringify(safeChanges)
						});
						if (!response.ok) {
							const err = await response.json();
							throw new Error(err.error || 'Failed to update');
						}

						// 2. Write to PGLite so live.changes() confirms the optimistic state.
						//    Electric will eventually sync the same value (no conflict).
						const fields = Object.keys(safeChanges);
						const values = Object.values(safeChanges);
						const setClauses = fields.map((f, i) => `"${f}" = $${i + 1}`).join(', ');
						await db!.query(`UPDATE uk_lrt SET ${setClauses} WHERE id = $${fields.length + 1}`, [
							...values,
							m.key
						]);
					}
				}
			});
			collectionRef = collection;
			adapter = createTanStackDBAdapter({ collection, columns: queueColumnMetadata });
			await adapter.init();
			// Keep for reparse feature (PGLite SQL query)
			currentQuery = BASE_QUERY;
			ready = true;
			// Wait for GridLite to render, then seed views
			await new Promise((r) => setTimeout(r, 100));
			await seedDefaultViews();
		}
	});

	onDestroy(() => {
		activeViewUnsub?.();
		viewStore?.destroy();
	});
</script>

<svelte:head>
	<title>LAT Queue — SertantAI Legal</title>
</svelte:head>

<div class="flex h-full relative">
	<!-- Mobile sidebar overlay -->
	{#if sidebarVisible}
		<!-- svelte-ignore a11y-click-events-have-key-events -->
		<!-- svelte-ignore a11y-no-static-element-interactions -->
		<div
			class="fixed inset-0 bg-black/30 z-30 lg:hidden"
			on:click={() => (sidebarVisible = false)}
		/>
	{/if}

	<!-- View Sidebar -->
	{#if viewStore}
		<div
			class="shrink-0 {sidebarVisible
				? 'fixed inset-y-0 left-0 z-40 lg:static lg:z-auto'
				: 'hidden lg:block'}"
		>
			<ViewSidebar
				{viewStore}
				storageKey="lat-queue-sidebar"
				isDocked={true}
				on:viewSelected={handleViewSelected}
			/>
		</div>
	{/if}

	<!-- Main Content -->
	<div class="flex-1 overflow-auto px-6 py-4 space-y-6">
		<!-- Header -->
		<div class="flex items-center justify-between">
			<div class="flex items-center gap-3">
				<button
					class="lg:hidden p-1.5 rounded-md border border-gray-300 text-gray-600 hover:bg-gray-100"
					on:click={() => (sidebarVisible = !sidebarVisible)}
					title="Toggle views sidebar"
				>
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							stroke-width="2"
							d="M4 6h16M4 12h16M4 18h16"
						/>
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
				<div
					class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
				></div>
				<p class="mt-4 text-gray-600">Loading queue...</p>
			</div>
		{:else if error}
			<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
				<p class="text-red-600">{error}</p>
				<button
					class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
					on:click={() => window.location.reload()}>Retry</button
				>
			</div>
		{:else if ready && adapter}
			<GridLite
				bind:this={gridRef}
				{adapter}
				onStateChange={handleStateChange}
				config={{
					id: 'lat-queue',
					columns,
					defaultSorting: [{ column: 'updated_at', direction: 'asc' }],
					defaultVisibleColumns: activeVisibleColumns,
					pagination: { pageSize: 50 }
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
								class="px-1.5 py-0.5 text-xs font-medium rounded shrink-0 {reparsingLaw === rowName
									? 'bg-gray-100 text-gray-400 cursor-not-allowed'
									: 'bg-blue-600 text-white hover:bg-blue-700'}"
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
								on:change={handleSelectSave}
								on:blur={() => saveEdit()}
								on:keydown={handleEditKeydown}
							>
								<option value="">-- None --</option>
								<optgroup label="Health & Safety">
									{#each familyOptions.health_safety as opt}<option value={opt}>{opt}</option
										>{/each}
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
								on:change={handleSelectSave}
								on:blur={() => saveEdit()}
								on:keydown={handleEditKeydown}
							>
								<option value="">-- None --</option>
								<optgroup label="Health & Safety">
									{#each familyOptions.health_safety as opt}<option value={opt}>{opt}</option
										>{/each}
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
								on:change={handleSelectSave}
								on:blur={() => saveEdit()}
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
								on:dblclick={() =>
									startEdit(str(row.id), 'making_classification', str(value) || null)}
								title="Double-click to edit"
							>
								{#if value === 'making'}
									<span class="px-1.5 py-0.5 text-xs rounded bg-green-100 text-green-700"
										>Making</span
									>
								{:else if value === 'not_making'}
									<span class="px-1.5 py-0.5 text-xs rounded bg-red-100 text-red-700"
										>Not Making</span
									>
								{:else if value === 'uncertain'}
									<span class="px-1.5 py-0.5 text-xs rounded bg-amber-100 text-amber-700"
										>Uncertain</span
									>
								{:else}
									<span class="text-gray-400">-</span>
								{/if}
							</button>
						{/if}
					{:else if column === 'live'}
						{@const status = str(value)}
						<span
							class="inline-flex px-2 py-0.5 text-xs font-medium rounded {status === '✔ In force'
								? 'bg-green-100 text-green-800'
								: status === '⭕ Part Revocation / Repeal'
									? 'bg-amber-100 text-amber-800'
									: 'bg-gray-100 text-gray-800'}"
						>
							{status || '-'}
						</span>
					{:else if column === 'function'}
						{@const fns = parseFunctionKeys(row.function)}
						{#if fns && fns.length > 0}
							<div class="flex flex-wrap gap-1">
								{#each fns as fn}
									<span
										class="px-1.5 py-0.5 text-xs rounded {fn === 'Making'
											? 'bg-green-100 text-green-700'
											: 'bg-blue-100 text-blue-700'}">{fn}</span
									>
								{/each}
							</div>
						{:else}
							<span class="text-gray-400">-</span>
						{/if}
					{:else}
						{value ?? '-'}
					{/if}
				</svelte:fragment>
			</GridLite>
		{/if}
	</div>
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig && viewStore}
	<SaveViewModal
		bind:open={showSaveModal}
		{viewStore}
		config={capturedConfig}
		on:save={handleViewSaved}
	/>
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
		records={[
			{
				name: str(lrtModalRecord.name),
				Title_EN: str(lrtModalRecord.title_en),
				type_code: String(lrtModalRecord.type_code ?? ''),
				Year: Number(lrtModalRecord.year ?? 0),
				Number: ''
			}
		]}
		recordId={lrtModalRecordId}
		open={lrtModalOpen}
		on:close={closeLrtRefresh}
	/>
{/if}

<!-- Reparse View Confirmation Dialog -->
{#if showReparseViewDialog}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
		on:click|self={() => (showReparseViewDialog = false)}
	>
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
