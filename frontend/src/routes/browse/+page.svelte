<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount, onDestroy } from 'svelte';
	import { TableKit } from '@shotleybuilder/svelte-table-kit';
	import type { ColumnDef } from '@tanstack/svelte-table';
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
		md_date_year: number | null;
		md_date_month: number | null;
		md_made_date: string | null;
		md_enactment_date: string | null;
		md_coming_into_force_date: string | null;
		latest_amend_date: string | null;
		latest_amend_date_year: number | null;
		latest_amend_date_month: number | null;
		latest_rescind_date: string | null;
		latest_rescind_date_year: number | null;
		latest_rescind_date_month: number | null;
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
	let sidebarOpen = false;

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
		// Date grouping columns (from DB generated columns)
		{
			id: 'md_date_year',
			accessorKey: 'md_date_year',
			header: 'Year (Date)',
			cell: (info) => info.getValue() ?? '-',
			size: 90,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Metadata', dataType: 'number' }
		},
		{
			id: 'md_date_month',
			accessorKey: 'md_date_month',
			header: 'Month (Date)',
			cell: (info) => {
				const val = info.getValue() as number | null;
				if (val == null) return '-';
				return monthNames[val - 1] ?? '-';
			},
			size: 100,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Metadata', dataType: 'number' }
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
			id: 'latest_amend_date_year',
			accessorKey: 'latest_amend_date_year',
			header: 'Amended Year',
			cell: (info) => info.getValue() ?? '-',
			size: 90,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Amendments', dataType: 'number' }
		},
		{
			id: 'latest_amend_date_month',
			accessorKey: 'latest_amend_date_month',
			header: 'Amended Month',
			cell: (info) => {
				const val = info.getValue() as number | null;
				if (val == null) return '-';
				return monthNames[val - 1] ?? '-';
			},
			size: 100,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Amendments', dataType: 'number' }
		},
		{
			id: 'latest_rescind_date',
			accessorKey: 'latest_rescind_date',
			header: 'Last Rescinded',
			cell: (info) => formatDate(info.getValue() as string),
			size: 110,
			meta: { group: 'Amendments', dataType: 'date' }
		},
		{
			id: 'latest_rescind_date_year',
			accessorKey: 'latest_rescind_date_year',
			header: 'Rescinded Year',
			cell: (info) => info.getValue() ?? '-',
			size: 90,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Amendments', dataType: 'number' }
		},
		{
			id: 'latest_rescind_date_month',
			accessorKey: 'latest_rescind_date_month',
			header: 'Rescinded Month',
			cell: (info) => {
				const val = info.getValue() as number | null;
				if (val == null) return '-';
				return monthNames[val - 1] ?? '-';
			},
			size: 100,
			enableGrouping: true,
			enableSorting: true,
			meta: { group: 'Amendments', dataType: 'number' }
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

	// Date boundary helpers for view filters
	const now = new Date();
	const currentYear = now.getFullYear();
	const currentMonth = now.getMonth(); // 0-indexed
	const currentQuarterStart = Math.floor(currentMonth / 3) * 3;

	function isoDate(y: number, m: number, d: number): string {
		return `${y}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
	}

	const thisMonthStart = isoDate(currentYear, currentMonth, 1);
	const lastMonthStart =
		currentMonth === 0
			? isoDate(currentYear - 1, 11, 1)
			: isoDate(currentYear, currentMonth - 1, 1);

	const thisQuarterStart = isoDate(currentYear, currentQuarterStart, 1);
	const lastQuarterStart =
		currentQuarterStart === 0
			? isoDate(currentYear - 1, 9, 1)
			: isoDate(currentYear, currentQuarterStart - 3, 1);

	const thisYearStart = isoDate(currentYear, 0, 1);
	const lastYearStart = isoDate(currentYear - 1, 0, 1);
	const threeYearsAgoStart = isoDate(currentYear - 3, 0, 1);
	const todayStr = isoDate(currentYear, currentMonth, now.getDate());

	// Shared column/sort/grouping config for all New Laws views
	const newLawsColumns = [
		'name',
		'title_en',
		'md_date',
		'md_date_year',
		'md_date_month',
		'type_code',
		'live',
		'family'
	];
	const newLawsSort = { columnId: 'md_date', direction: 'desc' as const };
	const newLawsGrouping = ['md_date_year', 'md_date_month'];

	// Shared config for Amended Laws views
	const amendedLawsColumns = [
		'name',
		'title_en',
		'latest_amend_date',
		'latest_amend_date_year',
		'latest_amend_date_month',
		'type_code',
		'live',
		'family'
	];
	const amendedLawsSort = { columnId: 'latest_amend_date', direction: 'desc' as const };
	const amendedLawsGrouping = ['latest_amend_date_year', 'latest_amend_date_month'];
	// Only include laws still at least partly in force
	const amendedLawsLiveFilter: { columnId: string; operator: string; value: unknown } = {
		columnId: 'live',
		operator: 'in',
		value: ['✔ In force', '⭕ Part Revocation / Repeal']
	};

	// Shared config for Repealed Laws views
	const repealedLawsColumns = [
		'name',
		'title_en',
		'latest_rescind_date',
		'latest_rescind_date_year',
		'latest_rescind_date_month',
		'type_code',
		'live',
		'family'
	];
	const repealedLawsSort = { columnId: 'latest_rescind_date', direction: 'desc' as const };
	const repealedLawsGrouping = ['latest_rescind_date_year', 'latest_rescind_date_month'];
	// Only fully repealed/revoked laws
	const repealedLawsLiveFilter: { columnId: string; operator: string; value: unknown } = {
		columnId: 'live',
		operator: 'equals',
		value: '❌ Revoked / Repealed / Abolished'
	};

	// View group definitions for sidebar organization
	const viewGroups: ViewGroup[] = [
		{ id: 'new-laws', name: 'New Laws', order: 0 },
		{ id: 'amended-laws', name: 'Amended Laws', order: 1 },
		{ id: 'repealed-laws', name: 'Repealed Laws', order: 2 },
		{ id: 'classification', name: 'Classification', order: 3 },
		{ id: 'custom', name: 'Custom Views', order: 4 }
	];

	// Map view names to group IDs
	const viewGroupMapping: Record<string, string> = {
		'This Month': 'new-laws',
		'Last Month': 'new-laws',
		'This Quarter': 'new-laws',
		'Last Quarter': 'new-laws',
		'This Year': 'new-laws',
		'Last Year': 'new-laws',
		'Last 3 Years': 'new-laws',
		'Amended This Month': 'amended-laws',
		'Amended Last Month': 'amended-laws',
		'Amended This Quarter': 'amended-laws',
		'Amended Last Quarter': 'amended-laws',
		'Amended This Year': 'amended-laws',
		'Amended Last Year': 'amended-laws',
		'Amended Last 3 Years': 'amended-laws',
		'Repealed This Month': 'repealed-laws',
		'Repealed Last Month': 'repealed-laws',
		'Repealed This Quarter': 'repealed-laws',
		'Repealed Last Quarter': 'repealed-laws',
		'Repealed This Year': 'repealed-laws',
		'Repealed Last Year': 'repealed-laws',
		'Repealed Last 3 Years': 'repealed-laws',
		'By Family': 'classification',
		'By Status': 'classification',
		'By Type': 'classification',
		'Geographic Scope': 'classification'
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
		// New Laws group
		{
			name: 'This Month',
			description: 'Laws from this calendar month onwards (includes future dates).',
			columns: newLawsColumns,
			filters: [{ columnId: 'md_date', operator: 'is_after', value: thisMonthStart }],
			sort: newLawsSort,
			grouping: newLawsGrouping,
			isDefault: true
		},
		{
			name: 'Last Month',
			description: 'Laws from the previous calendar month.',
			columns: newLawsColumns,
			filters: [
				{ columnId: 'md_date', operator: 'is_after', value: lastMonthStart },
				{ columnId: 'md_date', operator: 'is_before', value: thisMonthStart }
			],
			sort: newLawsSort,
			grouping: newLawsGrouping
		},
		{
			name: 'This Quarter',
			description: 'Laws from this calendar quarter onwards (includes future dates).',
			columns: newLawsColumns,
			filters: [{ columnId: 'md_date', operator: 'is_after', value: thisQuarterStart }],
			sort: newLawsSort,
			grouping: newLawsGrouping
		},
		{
			name: 'Last Quarter',
			description: 'Laws from the previous calendar quarter.',
			columns: newLawsColumns,
			filters: [
				{ columnId: 'md_date', operator: 'is_after', value: lastQuarterStart },
				{ columnId: 'md_date', operator: 'is_before', value: thisQuarterStart }
			],
			sort: newLawsSort,
			grouping: newLawsGrouping
		},
		{
			name: 'This Year',
			description: 'Laws from this calendar year onwards (includes future dates).',
			columns: newLawsColumns,
			filters: [{ columnId: 'md_date', operator: 'is_after', value: thisYearStart }],
			sort: newLawsSort,
			grouping: newLawsGrouping
		},
		{
			name: 'Last Year',
			description: `Laws from ${currentYear - 1}.`,
			columns: newLawsColumns,
			filters: [
				{ columnId: 'md_date', operator: 'is_after', value: lastYearStart },
				{ columnId: 'md_date', operator: 'is_before', value: thisYearStart }
			],
			sort: newLawsSort,
			grouping: newLawsGrouping
		},
		{
			name: 'Last 3 Years',
			description: `Laws from ${currentYear - 3} to today.`,
			columns: newLawsColumns,
			filters: [
				{ columnId: 'md_date', operator: 'is_after', value: threeYearsAgoStart },
				{ columnId: 'md_date', operator: 'is_before', value: todayStr }
			],
			sort: newLawsSort,
			grouping: newLawsGrouping
		},
		// Amended Laws group
		{
			name: 'Amended This Month',
			description: 'Laws amended this calendar month onwards (in force or partly repealed).',
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: thisMonthStart },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		{
			name: 'Amended Last Month',
			description: 'Laws amended in the previous calendar month (in force or partly repealed).',
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: lastMonthStart },
				{ columnId: 'latest_amend_date', operator: 'is_before', value: thisMonthStart },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		{
			name: 'Amended This Quarter',
			description: 'Laws amended this calendar quarter onwards (in force or partly repealed).',
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: thisQuarterStart },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		{
			name: 'Amended Last Quarter',
			description: 'Laws amended in the previous calendar quarter (in force or partly repealed).',
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: lastQuarterStart },
				{ columnId: 'latest_amend_date', operator: 'is_before', value: thisQuarterStart },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		{
			name: 'Amended This Year',
			description: 'Laws amended this calendar year onwards (in force or partly repealed).',
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: thisYearStart },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		{
			name: 'Amended Last Year',
			description: `Laws amended in ${currentYear - 1} (in force or partly repealed).`,
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: lastYearStart },
				{ columnId: 'latest_amend_date', operator: 'is_before', value: thisYearStart },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		{
			name: 'Amended Last 3 Years',
			description: `Laws amended from ${currentYear - 3} to today (in force or partly repealed).`,
			columns: amendedLawsColumns,
			filters: [
				{ columnId: 'latest_amend_date', operator: 'is_after', value: threeYearsAgoStart },
				{ columnId: 'latest_amend_date', operator: 'is_before', value: todayStr },
				amendedLawsLiveFilter
			],
			sort: amendedLawsSort,
			grouping: amendedLawsGrouping
		},
		// Repealed Laws group
		{
			name: 'Repealed This Month',
			description: 'Laws repealed/revoked this calendar month onwards.',
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: thisMonthStart },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		{
			name: 'Repealed Last Month',
			description: 'Laws repealed/revoked in the previous calendar month.',
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: lastMonthStart },
				{ columnId: 'latest_rescind_date', operator: 'is_before', value: thisMonthStart },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		{
			name: 'Repealed This Quarter',
			description: 'Laws repealed/revoked this calendar quarter onwards.',
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: thisQuarterStart },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		{
			name: 'Repealed Last Quarter',
			description: 'Laws repealed/revoked in the previous calendar quarter.',
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: lastQuarterStart },
				{ columnId: 'latest_rescind_date', operator: 'is_before', value: thisQuarterStart },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		{
			name: 'Repealed This Year',
			description: 'Laws repealed/revoked this calendar year onwards.',
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: thisYearStart },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		{
			name: 'Repealed Last Year',
			description: `Laws repealed/revoked in ${currentYear - 1}.`,
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: lastYearStart },
				{ columnId: 'latest_rescind_date', operator: 'is_before', value: thisYearStart },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		{
			name: 'Repealed Last 3 Years',
			description: `Laws repealed/revoked from ${currentYear - 3} to today.`,
			columns: repealedLawsColumns,
			filters: [
				{ columnId: 'latest_rescind_date', operator: 'is_after', value: threeYearsAgoStart },
				{ columnId: 'latest_rescind_date', operator: 'is_before', value: todayStr },
				repealedLawsLiveFilter
			],
			sort: repealedLawsSort,
			grouping: repealedLawsGrouping
		},
		// Classification group
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

	// Build order lookup from defaultViews array position
	const viewOrderMap = new Map(defaultViews.map((v, i) => [v.name, i]));

	// Convert saved views to sidebar format, preserving definition order
	$: sidebarViews = $savedViews
		.map((view): SidebarView => ({
			id: view.id,
			name: view.name,
			description: view.description,
			groupId: viewGroupMapping[view.name] || 'custom',
			isDefault: defaultViews.find((dv) => dv.name === view.name)?.isDefault,
			order: viewOrderMap.get(view.name) ?? 1000
		}))
		.sort((a, b) => (a.order ?? 1000) - (b.order ?? 1000));

	// View names that have been removed and should be cleaned up from storage
	const staleViewNames = ['Recent Laws'];

	// Seed default views
	async function seedDefaultViews() {
		await viewActions.waitForReady();

		const currentViews = $savedViews;

		// Build map of existing views, keeping only the first instance of each name
		// and deleting duplicates (can happen from HMR or double-mount)
		const existingViews = new Map<string, string>();
		for (const view of currentViews) {
			if (existingViews.has(view.name)) {
				// Duplicate — delete it
				try {
					await viewActions.delete(view.id);
				} catch (err) {
					console.error('[Browse] Failed to delete duplicate view:', view.name, err);
				}
			} else {
				existingViews.set(view.name, view.id);
			}
		}

		// Clean up stale views from previous versions
		for (const staleName of staleViewNames) {
			const staleId = existingViews.get(staleName);
			if (staleId) {
				try {
					await viewActions.delete(staleId);
					existingViews.delete(staleName);
				} catch (err) {
					console.error('[Browse] Failed to delete stale view:', staleName, err);
				}
			}
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
					// Track the name so we don't re-create on reactive re-runs
					existingViews.set(view.name, savedView?.id || '');
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
			filters: viewFilters.map((f) => ({
				columnId: f.field,
				operator: f.operator,
				value: f.value
			})),
			sort: viewSort,
			columns: viewColumns.length > 0 ? viewColumns : columns.map((c) => String(c.id)),
			columnOrder:
				viewColumnOrder.length > 0 ? viewColumnOrder : columns.map((c) => String(c.id)),
			columnWidths: {},
			pageSize: 25,
			grouping: viewGrouping
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

	// Handle view selection from sidebar
	async function handleSidebarSelect(event: CustomEvent<{ view: SidebarView }>) {
		const sidebarView = event.detail.view;
		const loadedView = await viewActions.load(sidebarView.id);
		if (loadedView) {
			applyViewConfig(loadedView.config);
		}
	}

	// Handle view selection (legacy - for modal)
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

	// Default date filter matching the default "This Month" view
	const defaultDateFilter: FilterCondition = {
		id: 'default-date-filter',
		field: 'md_date',
		operator: 'is_after',
		value: thisMonthStart
	};

	// Track last filter state
	let lastWhereClause = `"md_date" > '${thisMonthStart}'`;

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

			const collection = await getUkLrtCollection(lastWhereClause);

			let refreshDebounceTimer: ReturnType<typeof setTimeout> | null = null;
			const refreshData = () => {
				if (refreshDebounceTimer) {
					clearTimeout(refreshDebounceTimer);
				}
				refreshDebounceTimer = setTimeout(async () => {
					// Always get the latest collection reference in case it was recreated
					const currentCollection = await getUkLrtCollection(lastWhereClause);
					const newData = currentCollection.toArray as unknown as UkLrtRecord[];
					data = newData;
					totalCount = newData.length;
					if (newData.length > 0) {
						isLoading = false;
					}
				}, 200);
			};

			// Subscribe to collection changes directly
			const changeSub = collection.subscribeChanges(() => {
				refreshData();
			});

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
					changeSub.unsubscribe();
					if (refreshDebounceTimer) {
						clearTimeout(refreshDebounceTimer);
					}
				}
			};

			const initialData = collection.toArray as unknown as UkLrtRecord[];
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
		? [
				// Include grouping columns in sort so groups are ordered correctly
				...viewGrouping.map((col) => ({ columnId: col, direction: 'desc' as const })),
				{ columnId: viewSort.columnId, direction: viewSort.direction }
			]
		: [
				...(viewGrouping.length > 0
					? viewGrouping.map((col) => ({ columnId: col, direction: 'desc' as const }))
					: []),
				{ columnId: 'md_date', direction: 'desc' as const }
			];

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
			storageKey="browse-views-sidebar"
			width={220}
			showSearch={true}
			showPinned={true}
			on:select={(e) => {
				handleSidebarSelect(e);
				sidebarOpen = false;
			}}
		/>
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
				<p class="text-sm text-gray-600">
					Browse UK Legal, Regulatory & Transport records.
				</p>
			</div>
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
					title={$syncStatus.whereClause || 'This month'}
				>
					{$syncStatus.whereClause || 'This month (by primary date)'}
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
				filtering: false,
				sorting: true,
				sortingMode: 'control',
				pagination: false,
				grouping: true,
				globalSearch: true,
				rowDetail: true
			}}
		>
			<!-- Save View Buttons -->
			<svelte:fragment slot="toolbar-left">
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
					{cell.getValue() || '-'}
				{:else if column === 'leg_gov_uk_url'}
					{#if cell.getValue()}
						<a
							href={String(cell.getValue())}
							target="_blank"
							rel="noopener noreferrer"
							class="flex items-center justify-center w-full h-full text-blue-600 hover:text-blue-800 hover:underline"
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

			<svelte:fragment slot="row-detail" let:row let:close let:goToPrev let:goToNext let:hasPrev let:hasNext>
				{#if row}
					{@const r = asRecord(row)}
					{@const familyDisplay = getFamilyDisplay(r.family)}
					<div class="max-w-4xl mx-auto">
						<!-- Header -->
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
									<span class="inline-flex px-2 py-0.5 text-xs font-medium rounded {r.live === 'Live' ? 'bg-green-100 text-green-800' : r.live === 'Revoked' ? 'bg-red-100 text-red-800' : 'bg-gray-100 text-gray-800'}">
										{r.live}
									</span>
								{/if}
								{#if r.function?.length}
									{#each r.function as fn}
										<span class="px-2 py-0.5 text-xs rounded {fn === 'Making' ? 'bg-green-100 text-green-700' : fn === 'Amending' ? 'bg-yellow-100 text-yellow-700' : fn === 'Revoking' ? 'bg-red-100 text-red-700' : 'bg-gray-100 text-gray-700'}">
											{fn}
										</span>
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
							<!-- Credentials -->
							<section class="bg-gray-50 rounded-lg p-4">
								<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Credentials</h3>
								<dl class="space-y-2">
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Year</dt><dd class="text-sm font-medium text-gray-900">{r.year}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Number</dt><dd class="text-sm font-medium text-gray-900">{r.number || '-'}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Type Code</dt><dd class="text-sm font-medium text-gray-900 uppercase">{r.type_code || '-'}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Type Class</dt><dd class="text-sm font-medium text-gray-900">{r.type_class || '-'}</dd></div>
								</dl>
							</section>

							<!-- Classification -->
							<section class="bg-gray-50 rounded-lg p-4">
								<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Classification</h3>
								<dl class="space-y-2">
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Family</dt><dd class="text-sm font-medium text-gray-900">{r.family || '-'}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Family II</dt><dd class="text-sm font-medium text-gray-900">{r.family_ii || '-'}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">SI Code</dt><dd class="text-sm font-medium text-gray-900">{r.si_code || '-'}</dd></div>
								</dl>
							</section>

							<!-- Geographic -->
							<section class="bg-gray-50 rounded-lg p-4">
								<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Geographic</h3>
								<dl class="space-y-2">
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Extent</dt><dd class="text-sm font-medium text-gray-900">{r.geo_extent || '-'}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Region</dt><dd class="text-sm font-medium text-gray-900">{r.geo_region || '-'}</dd></div>
								</dl>
							</section>

							<!-- Key Dates -->
							<section class="bg-gray-50 rounded-lg p-4">
								<h3 class="text-sm font-semibold text-gray-500 uppercase tracking-wider mb-3">Key Dates</h3>
								<dl class="space-y-2">
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Primary Date</dt><dd class="text-sm font-medium text-gray-900">{formatDate(r.md_date)}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Made</dt><dd class="text-sm font-medium text-gray-900">{formatDate(r.md_made_date)}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">In Force</dt><dd class="text-sm font-medium text-gray-900">{formatDate(r.md_coming_into_force_date)}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Last Amended</dt><dd class="text-sm font-medium text-gray-900">{formatDate(r.latest_amend_date)}</dd></div>
									<div class="flex justify-between"><dt class="text-sm text-gray-600">Last Rescinded</dt><dd class="text-sm font-medium text-gray-900">{formatDate(r.latest_rescind_date)}</dd></div>
								</dl>
							</section>
						</div>
					</div>
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
