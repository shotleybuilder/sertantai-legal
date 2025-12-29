<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
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

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// Types
	interface UkLrtRecord {
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
		tags: string[] | null;
		function: string[] | null;
		// Role/Actor
		role: string[] | null;
		role_gvt: Record<string, unknown> | null;
		article_role: string | null;
		role_article: string | null;
		// Duty Type
		duty_type: string | null;
		duty_type_article: string | null;
		article_duty_type: string | null;
		// Duty Holder
		duty_holder: Record<string, unknown> | null;
		duty_holder_article: string | null;
		duty_holder_article_clause: string | null;
		article_duty_holder: string | null;
		article_duty_holder_clause: string | null;
		// Power Holder
		power_holder: Record<string, unknown> | null;
		power_holder_article: string | null;
		power_holder_article_clause: string | null;
		article_power_holder: string | null;
		article_power_holder_clause: string | null;
		// Rights Holder
		rights_holder: Record<string, unknown> | null;
		rights_holder_article: string | null;
		rights_holder_article_clause: string | null;
		article_rights_holder: string | null;
		article_rights_holder_clause: string | null;
		// Responsibility Holder
		responsibility_holder: Record<string, unknown> | null;
		responsibility_holder_article: string | null;
		responsibility_holder_article_clause: string | null;
		article_responsibility_holder: string | null;
		article_responsibility_holder_clause: string | null;
		// POPIMAR
		popimar: Record<string, unknown> | null;
		popimar_article: string | null;
		popimar_article_clause: string | null;
		article_popimar: string | null;
		article_popimar_clause: string | null;
		// Purpose
		purpose: Record<string, unknown> | null;
		is_making: number | null;
		enacted_by: string | null;
		amending: Record<string, unknown> | null;
		amended_by: Record<string, unknown> | null;
		md_date: string | null;
		md_made_date: string | null;
		md_enactment_date: string | null;
		md_coming_into_force_date: string | null;
		md_dct_valid_date: string | null;
		md_restrict_start_date: string | null;
		md_total_paras: number | null;
		md_body_paras: number | null;
		md_schedule_paras: number | null;
		md_attachment_paras: number | null;
		md_images: number | null;
		latest_amend_date: string | null;
		leg_gov_uk_url: string | null;
	}

	interface ApiResponse {
		records: UkLrtRecord[];
		count: number;
		limit: number;
		offset: number;
		has_more: boolean;
	}

	// Family options grouped by category
	const familyOptions = {
		health_safety: [
			'FIRE',
			'FIRE: Dangerous and Explosive Substances',
			'FOOD',
			'HEALTH: Coronavirus',
			'HEALTH: Drug & Medicine Safety',
			'HEALTH: Patient Safety',
			'HEALTH: Public',
			'OH&S: Gas & Electrical Safety',
			'OH&S: Mines & Quarries',
			'OH&S: Occupational / Personal Safety',
			'OH&S: Offshore Safety',
			'PUBLIC',
			'PUBLIC: Building Safety',
			'PUBLIC: Consumer / Product Safety',
			'TRANSPORT: Air Safety',
			'TRANSPORT: Rail Safety',
			'TRANSPORT: Road Safety',
			'TRANSPORT: Maritime Safety'
		],
		environment: [
			'AGRICULTURE',
			'AGRICULTURE: Pesticides',
			'AIR QUALITY',
			'ANIMALS & ANIMAL HEALTH',
			'ANTARCTICA',
			'BUILDINGS',
			'CLIMATE CHANGE',
			'ENERGY',
			'ENVIRONMENTAL PROTECTION',
			'FINANCE',
			'FISHERIES & FISHING',
			'GMOs',
			'HISTORIC ENVIRONMENT',
			'MARINE & RIVERINE',
			'NOISE',
			'NUCLEAR & RADIOLOGICAL',
			'OIL & GAS - OFFSHORE - PETROLEUM',
			'PLANNING & INFRASTRUCTURE',
			'PLANT HEALTH',
			'POLLUTION',
			'TOWN & COUNTRY PLANNING',
			'TRANSPORT',
			'TRANSPORT: Aviation',
			'TRANSPORT: Harbours & Shipping',
			'TRANSPORT: Railways & Rail Transport',
			'TRANSPORT: Roads & Vehicles',
			'TREES: Forestry & Timber',
			'WASTE',
			'WATER & WASTEWATER',
			'WILDLIFE & COUNTRYSIDE'
		],
		hr: ['HR: Employment', 'HR: Insurance / Compensation / Wages / Benefits', 'HR: Working Time']
	};

	// Function options
	const functionOptions = ['Making', 'Amending', 'Revoking', 'Commencing', 'Enacting'];

	// State
	let data: UkLrtRecord[] = [];
	let isLoading = true;
	let error: string | null = null;
	let totalCount = 0;
	let hasMore = false;

	// Editing state
	let editingCell: { id: string; field: string } | null = null;
	let editValue: string | string[] = '';

	// Rescrape state
	let rescrapingIds = new Set<string>();

	// Saved views state
	let showSaveModal = false;
	let capturedConfig: TableConfig | null = null;

	// View configuration state (for applying saved views)
	let viewColumns: string[] = [];
	let viewColumnOrder: string[] = [];
	let configVersion = 0;

	// Default views configuration
	const defaultViews: Array<{ name: string; description: string; columns: string[] }> = [
		{
			name: 'Credentials',
			description: 'Core identification fields: Title, Year, Number, Type Code, Type Class',
			columns: ['actions', 'name', 'title_en', 'year', 'number', 'type_code', 'type_class']
		},
		{
			name: 'Description',
			description: 'Classification fields: Family, Family II, Function, SI Code',
			columns: ['actions', 'name', 'title_en', 'family', 'family_ii', 'function', 'si_code']
		},
		{
			name: 'Status & Dates',
			description: 'Status and date fields',
			columns: ['actions', 'name', 'title_en', 'live', 'md_made_date', 'md_coming_into_force_date', 'geo_extent']
		},
		{
			name: 'Geo. Extent',
			description: 'Geographic scope fields: Extent, Region, Detail, Restrict Extent',
			columns: ['actions', 'name', 'title_en', 'geo_extent', 'geo_region', 'geo_detail', 'md_restrict_extent']
		},
		{
			name: 'Metadata',
			description: 'Dates and document stats: Made, Enacted, In Force, Paragraphs, Images',
			columns: ['actions', 'name', 'title_en', 'md_date', 'md_made_date', 'md_enactment_date', 'md_coming_into_force_date', 'md_dct_valid_date', 'md_restrict_start_date', 'md_total_paras', 'md_body_paras', 'md_schedule_paras', 'md_attachment_paras', 'md_images']
		},
		{
			name: 'Role',
			description: 'Role classifications and article mappings',
			columns: ['actions', 'name', 'title_en', 'role', 'role_gvt', 'article_role', 'role_article']
		},
		{
			name: 'Duty Type',
			description: 'Duty type classifications and article mappings',
			columns: ['actions', 'name', 'title_en', 'duty_type', 'duty_type_article', 'article_duty_type']
		},
		{
			name: 'Duty Holder',
			description: 'Entities with legal duties and article references',
			columns: ['actions', 'name', 'title_en', 'duty_holder', 'duty_holder_article', 'duty_holder_article_clause', 'article_duty_holder', 'article_duty_holder_clause']
		},
		{
			name: 'Power Holder',
			description: 'Entities with legal powers and article references',
			columns: ['actions', 'name', 'title_en', 'power_holder', 'power_holder_article', 'power_holder_article_clause', 'article_power_holder', 'article_power_holder_clause']
		},
		{
			name: 'Rights Holder',
			description: 'Entities with legal rights and article references',
			columns: ['actions', 'name', 'title_en', 'rights_holder', 'rights_holder_article', 'rights_holder_article_clause', 'article_rights_holder', 'article_rights_holder_clause']
		},
		{
			name: 'Responsibility Holder',
			description: 'Entities with legal responsibilities and article references',
			columns: ['actions', 'name', 'title_en', 'responsibility_holder', 'responsibility_holder_article', 'responsibility_holder_article_clause', 'article_responsibility_holder', 'article_responsibility_holder_clause']
		},
		{
			name: 'POPIMAR',
			description: 'POPIMAR framework and article references',
			columns: ['actions', 'name', 'title_en', 'popimar', 'popimar_article', 'popimar_article_clause', 'article_popimar', 'article_popimar_clause']
		},
		{
			name: 'Purpose',
			description: 'Legal purposes and objectives',
			columns: ['actions', 'name', 'title_en', 'purpose']
		}
	];

	// Seed default views if they don't exist (by name)
	async function seedDefaultViews() {
		// Clean up old incorrect localStorage key from previous implementation
		localStorage.removeItem('svelte-table-views');

		// Wait for library to initialize
		await new Promise(resolve => setTimeout(resolve, 200));

		// Get existing view names from localStorage
		const existingNames = new Set<string>();
		const storageData = localStorage.getItem('svelte-table-views-saved-views');
		if (storageData) {
			try {
				const parsed = JSON.parse(storageData);
				Object.values(parsed).forEach((item: unknown) => {
					const stored = item as { data: { name: string } };
					if (stored.data?.name) {
						existingNames.add(stored.data.name);
					}
				});
			} catch (err) {
				console.error('[LRT Admin] Failed to parse existing views:', err);
			}
		}

		console.log('[LRT Admin] Existing views:', Array.from(existingNames));

		// Seed only missing default views
		const missingViews = defaultViews.filter(v => !existingNames.has(v.name));
		if (missingViews.length === 0) {
			console.log('[LRT Admin] All default views already exist');
			return;
		}

		console.log('[LRT Admin] Seeding missing default views:', missingViews.map(v => v.name));

		for (const view of missingViews) {
			const viewInput: SavedViewInput = {
				name: view.name,
				description: view.description,
				config: {
					filters: [],
					sort: null,
					columns: view.columns,
					columnOrder: view.columns,
					columnWidths: {},
					pageSize: 25,
					grouping: []
				}
			};

			try {
				await viewActions.save(viewInput);
				console.log('[LRT Admin] Seeded view:', view.name);
				await new Promise(resolve => setTimeout(resolve, 100));
			} catch (err) {
				console.error('[LRT Admin] Failed to seed view:', view.name, err);
			}
		}

		console.log('[LRT Admin] Default views seeding complete');
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
		console.log('[LRT Admin] Applying view config:', config);

		// Get available column IDs
		const availableColumnIds = new Set(columns.map(c => String(c.id)));

		// Validate columns - filter out missing columns
		const validColumns = config.columns.filter(colId => availableColumnIds.has(colId));
		const validColumnOrder = config.columnOrder.filter(colId => availableColumnIds.has(colId));

		// Set view config (triggers reactive update)
		viewColumns = validColumns.length > 0 ? validColumns : [];
		viewColumnOrder = validColumnOrder.length > 0 ? validColumnOrder : [];
		configVersion++;
	}

	// Handle view selection
	function handleViewSelected(event: CustomEvent<{ view: SavedView }>) {
		const view = event.detail.view;
		console.log('[LRT Admin] View selected:', view.name);

		// Apply view config to table
		setTimeout(() => {
			applyViewConfig(view.config);
		}, 100);
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

	// Fetch data
	async function fetchData(limit = 100, offset = 0) {
		try {
			isLoading = true;
			const response = await fetch(`${API_URL}/api/uk-lrt?limit=${limit}&offset=${offset}`);
			if (!response.ok) throw new Error('Failed to fetch data');
			const json: ApiResponse = await response.json();
			data = json.records;
			totalCount = json.count;
			hasMore = json.has_more;
			error = null;
		} catch (e) {
			error = e instanceof Error ? e.message : 'Unknown error';
		} finally {
			isLoading = false;
		}
	}

	// Update record
	async function updateRecord(id: string, field: string, value: string | string[] | null) {
		try {
			const response = await fetch(`${API_URL}/api/uk-lrt/${id}`, {
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

	// Rescrape single record
	async function rescrapeRecord(id: string, name: string) {
		if (rescrapingIds.has(id)) return;

		try {
			rescrapingIds.add(id);
			rescrapingIds = rescrapingIds; // trigger reactivity

			// Call the parse-one endpoint (we need the session context, so we'll use a direct approach)
			const response = await fetch(`${API_URL}/api/uk-lrt/${id}/rescrape`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' }
			});

			if (!response.ok) {
				const err = await response.json();
				throw new Error(err.error || 'Rescrape failed');
			}

			const result = await response.json();

			// Refresh this record's data
			const recordResponse = await fetch(`${API_URL}/api/uk-lrt/${id}`);
			if (recordResponse.ok) {
				const updated = await recordResponse.json();
				data = data.map((r) => (r.id === id ? updated : r));
			}

			alert(`Rescrape complete for ${name}`);
		} catch (e) {
			alert(`Rescrape failed: ${e instanceof Error ? e.message : 'Unknown error'}`);
		} finally {
			rescrapingIds.delete(id);
			rescrapingIds = rescrapingIds;
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
		if (family.startsWith('HS:') || family.includes('OH&S') || family.includes('FIRE') || family.includes('FOOD') || family.includes('HEALTH') || family.includes('PUBLIC') || family.includes('TRANSPORT:'))
			return { prefix: 'HS', name: family };
		if (family.startsWith('E:') || family.includes('ENVIRONMENT') || family.includes('CLIMATE') || family.includes('WASTE') || family.includes('WATER') || family.includes('WILDLIFE') || family.includes('MARINE') || family.includes('POLLUTION') || family.includes('AGRICULTURE') || family.includes('ENERGY'))
			return { prefix: 'E', name: family };
		if (family.startsWith('HR:') || family.includes('HR:'))
			return { prefix: 'HR', name: family };
		return { prefix: '', name: family };
	}

	// Column definitions
	const columns: ColumnDef<UkLrtRecord>[] = [
		// Actions column (rescrape)
		{
			id: 'actions',
			header: '',
			cell: (info) => info.cell.row.original.id,
			size: 60,
			enableSorting: false,
			enableResizing: false,
			meta: { group: 'Actions' }
		},
		// Core identification
		{
			id: 'name',
			accessorKey: 'name',
			header: 'Name',
			cell: (info) => info.getValue(),
			size: 140,
			meta: { group: 'Credentials' }
		},
		{
			id: 'title_en',
			accessorKey: 'title_en',
			header: 'Title',
			cell: (info) => info.getValue(),
			size: 300,
			meta: { group: 'Credentials' }
		},
		{
			id: 'year',
			accessorKey: 'year',
			header: 'Year',
			cell: (info) => info.getValue(),
			size: 70,
			meta: { group: 'Credentials' }
		},
		{
			id: 'type_code',
			accessorKey: 'type_code',
			header: 'Type Code',
			cell: (info) => String(info.getValue() || '').toUpperCase(),
			size: 80,
			enableGrouping: true,
			meta: { group: 'Credentials' }
		},
		{
			id: 'number',
			accessorKey: 'number',
			header: 'Number',
			cell: (info) => info.getValue(),
			size: 80,
			meta: { group: 'Credentials' }
		},
		{
			id: 'type_class',
			accessorKey: 'type_class',
			header: 'Type Class',
			cell: (info) => info.getValue(),
			size: 120,
			enableGrouping: true,
			meta: { group: 'Credentials' }
		},
		// Editable fields
		{
			id: 'family',
			accessorKey: 'family',
			header: 'Family',
			cell: (info) => info.getValue(),
			size: 200,
			enableGrouping: true,
			meta: { group: 'Description', editable: true }
		},
		{
			id: 'family_ii',
			accessorKey: 'family_ii',
			header: 'Family II',
			cell: (info) => info.getValue(),
			size: 200,
			enableGrouping: true,
			meta: { group: 'Description', editable: true }
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
			meta: { group: 'Description', editable: true }
		},
		// Status
		{
			id: 'live',
			accessorKey: 'live',
			header: 'Status',
			cell: (info) => info.getValue(),
			size: 100,
			enableGrouping: true,
			meta: { group: 'Status' }
		},
		{
			id: 'si_code',
			accessorKey: 'si_code',
			header: 'SI Code',
			cell: (info) => info.getValue(),
			size: 180,
			meta: { group: 'Description' }
		},
		// Geographic
		{
			id: 'geo_extent',
			accessorKey: 'geo_extent',
			header: 'Extent',
			cell: (info) => info.getValue(),
			size: 120,
			enableGrouping: true,
			meta: { group: 'Geographic' }
		},
		{
			id: 'geo_region',
			accessorKey: 'geo_region',
			header: 'Region',
			cell: (info) => info.getValue(),
			size: 120,
			enableGrouping: true,
			meta: { group: 'Geographic' }
		},
		{
			id: 'geo_detail',
			accessorKey: 'geo_detail',
			header: 'Geo Detail',
			cell: (info) => info.getValue(),
			size: 150,
			meta: { group: 'Geographic' }
		},
		{
			id: 'md_restrict_extent',
			accessorKey: 'md_restrict_extent',
			header: 'Restrict Extent',
			cell: (info) => info.getValue(),
			size: 150,
			meta: { group: 'Geographic' }
		},
		// Metadata / Dates
		{
			id: 'md_date',
			accessorKey: 'md_date',
			header: 'Primary Date',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_made_date',
			accessorKey: 'md_made_date',
			header: 'Made',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_enactment_date',
			accessorKey: 'md_enactment_date',
			header: 'Enacted',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_coming_into_force_date',
			accessorKey: 'md_coming_into_force_date',
			header: 'In Force',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_dct_valid_date',
			accessorKey: 'md_dct_valid_date',
			header: 'DCT Valid',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_restrict_start_date',
			accessorKey: 'md_restrict_start_date',
			header: 'Restrict Start',
			cell: (info) => formatDate(info.getValue() as string),
			size: 100,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_total_paras',
			accessorKey: 'md_total_paras',
			header: 'Total Paras',
			cell: (info) => info.getValue() ?? '-',
			size: 80,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_body_paras',
			accessorKey: 'md_body_paras',
			header: 'Body Paras',
			cell: (info) => info.getValue() ?? '-',
			size: 80,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_schedule_paras',
			accessorKey: 'md_schedule_paras',
			header: 'Schedule Paras',
			cell: (info) => info.getValue() ?? '-',
			size: 90,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_attachment_paras',
			accessorKey: 'md_attachment_paras',
			header: 'Attach Paras',
			cell: (info) => info.getValue() ?? '-',
			size: 80,
			meta: { group: 'Metadata' }
		},
		{
			id: 'md_images',
			accessorKey: 'md_images',
			header: 'Images',
			cell: (info) => info.getValue() ?? '-',
			size: 70,
			meta: { group: 'Metadata' }
		},
		// Role/Actor
		{
			id: 'role',
			accessorKey: 'role',
			header: 'Roles',
			cell: (info) => {
				const val = info.getValue() as string[] | null;
				if (!val || val.length === 0) return '-';
				return val.join(', ');
			},
			size: 150,
			meta: { group: 'Role' }
		},
		{
			id: 'role_gvt',
			accessorKey: 'role_gvt',
			header: 'Govt Roles',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 150,
			meta: { group: 'Role' }
		},
		{
			id: 'article_role',
			accessorKey: 'article_role',
			header: 'Article → Role',
			cell: (info) => info.getValue() ?? '-',
			size: 120,
			meta: { group: 'Role' }
		},
		{
			id: 'role_article',
			accessorKey: 'role_article',
			header: 'Role → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 120,
			meta: { group: 'Role' }
		},
		// Duty Type
		{
			id: 'duty_type',
			accessorKey: 'duty_type',
			header: 'Duty Type',
			cell: (info) => info.getValue() ?? '-',
			size: 120,
			meta: { group: 'Duty Type' }
		},
		{
			id: 'duty_type_article',
			accessorKey: 'duty_type_article',
			header: 'Duty Type → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 140,
			meta: { group: 'Duty Type' }
		},
		{
			id: 'article_duty_type',
			accessorKey: 'article_duty_type',
			header: 'Article → Duty Type',
			cell: (info) => info.getValue() ?? '-',
			size: 140,
			meta: { group: 'Duty Type' }
		},
		// Duty Holder
		{
			id: 'duty_holder',
			accessorKey: 'duty_holder',
			header: 'Duty Holder',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 180,
			meta: { group: 'Duty Holder' }
		},
		{
			id: 'duty_holder_article',
			accessorKey: 'duty_holder_article',
			header: 'Duty Holder → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Duty Holder' }
		},
		{
			id: 'duty_holder_article_clause',
			accessorKey: 'duty_holder_article_clause',
			header: 'Duty Holder Article Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Duty Holder' }
		},
		{
			id: 'article_duty_holder',
			accessorKey: 'article_duty_holder',
			header: 'Article → Duty Holder',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Duty Holder' }
		},
		{
			id: 'article_duty_holder_clause',
			accessorKey: 'article_duty_holder_clause',
			header: 'Article Duty Holder Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Duty Holder' }
		},
		// Power Holder
		{
			id: 'power_holder',
			accessorKey: 'power_holder',
			header: 'Power Holder',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 180,
			meta: { group: 'Power Holder' }
		},
		{
			id: 'power_holder_article',
			accessorKey: 'power_holder_article',
			header: 'Power Holder → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Power Holder' }
		},
		{
			id: 'power_holder_article_clause',
			accessorKey: 'power_holder_article_clause',
			header: 'Power Holder Article Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Power Holder' }
		},
		{
			id: 'article_power_holder',
			accessorKey: 'article_power_holder',
			header: 'Article → Power Holder',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Power Holder' }
		},
		{
			id: 'article_power_holder_clause',
			accessorKey: 'article_power_holder_clause',
			header: 'Article Power Holder Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Power Holder' }
		},
		// Rights Holder
		{
			id: 'rights_holder',
			accessorKey: 'rights_holder',
			header: 'Rights Holder',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 180,
			meta: { group: 'Rights Holder' }
		},
		{
			id: 'rights_holder_article',
			accessorKey: 'rights_holder_article',
			header: 'Rights Holder → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Rights Holder' }
		},
		{
			id: 'rights_holder_article_clause',
			accessorKey: 'rights_holder_article_clause',
			header: 'Rights Holder Article Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Rights Holder' }
		},
		{
			id: 'article_rights_holder',
			accessorKey: 'article_rights_holder',
			header: 'Article → Rights Holder',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Rights Holder' }
		},
		{
			id: 'article_rights_holder_clause',
			accessorKey: 'article_rights_holder_clause',
			header: 'Article Rights Holder Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Rights Holder' }
		},
		// Responsibility Holder
		{
			id: 'responsibility_holder',
			accessorKey: 'responsibility_holder',
			header: 'Responsibility Holder',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 180,
			meta: { group: 'Responsibility Holder' }
		},
		{
			id: 'responsibility_holder_article',
			accessorKey: 'responsibility_holder_article',
			header: 'Resp. Holder → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Responsibility Holder' }
		},
		{
			id: 'responsibility_holder_article_clause',
			accessorKey: 'responsibility_holder_article_clause',
			header: 'Resp. Holder Article Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Responsibility Holder' }
		},
		{
			id: 'article_responsibility_holder',
			accessorKey: 'article_responsibility_holder',
			header: 'Article → Resp. Holder',
			cell: (info) => info.getValue() ?? '-',
			size: 150,
			meta: { group: 'Responsibility Holder' }
		},
		{
			id: 'article_responsibility_holder_clause',
			accessorKey: 'article_responsibility_holder_clause',
			header: 'Article Resp. Holder Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 180,
			meta: { group: 'Responsibility Holder' }
		},
		// POPIMAR
		{
			id: 'popimar',
			accessorKey: 'popimar',
			header: 'POPIMAR',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 150,
			meta: { group: 'POPIMAR' }
		},
		{
			id: 'popimar_article',
			accessorKey: 'popimar_article',
			header: 'POPIMAR → Article',
			cell: (info) => info.getValue() ?? '-',
			size: 140,
			meta: { group: 'POPIMAR' }
		},
		{
			id: 'popimar_article_clause',
			accessorKey: 'popimar_article_clause',
			header: 'POPIMAR Article Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 160,
			meta: { group: 'POPIMAR' }
		},
		{
			id: 'article_popimar',
			accessorKey: 'article_popimar',
			header: 'Article → POPIMAR',
			cell: (info) => info.getValue() ?? '-',
			size: 140,
			meta: { group: 'POPIMAR' }
		},
		{
			id: 'article_popimar_clause',
			accessorKey: 'article_popimar_clause',
			header: 'Article POPIMAR Clause',
			cell: (info) => info.getValue() ?? '-',
			size: 160,
			meta: { group: 'POPIMAR' }
		},
		// Purpose
		{
			id: 'purpose',
			accessorKey: 'purpose',
			header: 'Purpose',
			cell: (info) => {
				const val = info.getValue() as Record<string, unknown> | null;
				if (!val || Object.keys(val).length === 0) return '-';
				return Object.keys(val).join(', ');
			},
			size: 150,
			meta: { group: 'Purpose' }
		},
		// Links
		{
			id: 'leg_gov_uk_url',
			accessorKey: 'leg_gov_uk_url',
			header: 'Link',
			cell: (info) => (info.getValue() ? 'View' : '-'),
			size: 70,
			enableSorting: false,
			meta: { group: 'Links' }
		}
	];

	// Build TableKit configuration from view (reactive)
	$: hasViewConfig = viewColumns.length > 0 || viewColumnOrder.length > 0;

	$: tableKitConfig = hasViewConfig ? {
		id: `view_config_v${configVersion}`,
		version: '1.0',
		defaultColumnOrder: viewColumnOrder.length > 0 ? viewColumnOrder : undefined,
		defaultVisibleColumns: viewColumns.length > 0 ? viewColumns : undefined
	} : undefined;

	onMount(() => {
		if (browser) {
			seedDefaultViews();
			fetchData();
		}
	});
</script>

<div class="container mx-auto px-4 py-6">
	<div class="mb-6">
		<h1 class="text-2xl font-bold text-gray-900 mb-1">UK LRT Data</h1>
		<p class="text-sm text-gray-600">
			Manage UK Legal Register Table records. Inline edit Family, Family II, and Function fields.
		</p>
	</div>

	{#if isLoading}
		<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"
			></div>
			<p class="mt-4 text-gray-600">Loading UK LRT data...</p>
		</div>
	{:else if error}
		<div class="px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
			<h3 class="text-lg font-semibold text-red-800 mb-2">Error Loading Data</h3>
			<p class="text-red-600">{error}</p>
			<button
				class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
				on:click={() => fetchData()}
			>
				Retry
			</button>
		</div>
	{:else}
		<!-- Stats -->
		<div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Showing</div>
				<div class="text-2xl font-bold text-gray-900">{data.length.toLocaleString()}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 px-4 py-3">
				<div class="text-sm text-gray-600">Has More</div>
				<div class="text-2xl font-bold text-gray-900">{hasMore ? 'Yes' : 'No'}</div>
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
			align="left"
			features={{
				columnVisibility: true,
				columnResizing: true,
				columnReordering: true,
				filtering: true,
				sorting: true,
				sortingMode: 'control',
				pagination: true,
				grouping: false
			}}
		>
			<!-- Saved Views Toolbar -->
			<svelte:fragment slot="toolbar-left">
				<ViewSelector on:viewSelected={handleViewSelected} />

				{#if $activeViewId && $activeViewModified}
					<!-- Split Button: Update | Save New -->
					<div class="inline-flex rounded-md shadow-sm">
						<button
							type="button"
							on:click={handleUpdateView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-l-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
						>
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
							</svg>
							Update View
						</button>
						<button
							type="button"
							on:click={handleSaveView}
							class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 border-l border-indigo-500 rounded-r-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
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
						class="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3 3m0 0l-3-3m3 3V4" />
						</svg>
						Save View
					</button>
				{/if}
			</svelte:fragment>

			<svelte:fragment slot="cell" let:cell let:column>
				{#if column === 'actions'}
					<button
						class="p-1.5 text-gray-500 hover:text-blue-600 hover:bg-blue-50 rounded disabled:opacity-50 disabled:cursor-not-allowed"
						title="Rescrape this record"
						disabled={rescrapingIds.has(cell.row.original.id)}
						on:click={() => rescrapeRecord(cell.row.original.id, cell.row.original.name)}
					>
						{#if rescrapingIds.has(cell.row.original.id)}
							<svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
								<circle
									class="opacity-25"
									cx="12"
									cy="12"
									r="10"
									stroke="currentColor"
									stroke-width="4"
								></circle>
								<path
									class="opacity-75"
									fill="currentColor"
									d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
								></path>
							</svg>
						{:else}
							<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
								<path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
								/>
							</svg>
						{/if}
					</button>
				{:else if column === 'family'}
					{#if editingCell?.id === cell.row.original.id && editingCell?.field === 'family'}
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
						{@const display = getFamilyDisplay(cell.row.original.family)}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate"
							on:dblclick={() => startEdit(cell.row.original.id, 'family', cell.row.original.family)}
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
					{#if editingCell?.id === cell.row.original.id && editingCell?.field === 'family_ii'}
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
							on:dblclick={() => startEdit(cell.row.original.id, 'family_ii', cell.row.original.family_ii)}
							title="Double-click to edit"
						>
							{cell.row.original.family_ii || '-'}
						</button>
					{/if}
				{:else if column === 'function'}
					{#if editingCell?.id === cell.row.original.id && editingCell?.field === 'function'}
						<div class="flex flex-wrap gap-1 p-1 border border-blue-400 rounded bg-white">
							{#each functionOptions as fn}
								<button
									type="button"
									class="px-2 py-0.5 text-xs rounded {Array.isArray(editValue) && editValue.includes(fn)
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
							on:dblclick={() => startEdit(cell.row.original.id, 'function', cell.row.original.function)}
							title="Double-click to edit"
						>
							{#if cell.row.original.function?.length}
								<span class="flex flex-wrap gap-1">
									{#each cell.row.original.function as fn}
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
					<strong>Rescrape button</strong> (refresh icon) re-fetches and parses the record from legislation.gov.uk
				</li>
				<li>Use column visibility controls to show/hide columns and reduce horizontal scroll</li>
				<li>Table state (column order, visibility, sorting) is persisted locally</li>
				<li><strong>Saved Views</strong> - Save your current table configuration for quick access later</li>
			</ul>
		</div>
	{/if}
</div>

<!-- Save View Modal -->
{#if showSaveModal && capturedConfig}
	<SaveViewModal bind:open={showSaveModal} config={capturedConfig} on:save={handleViewSaved} />
{/if}
