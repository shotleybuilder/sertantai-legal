<script lang="ts">
	import { browser } from '$app/environment';
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import { onMount, onDestroy } from 'svelte';
	import { GridLite, buildQuery } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type {
		ColumnConfig,
		GridState,
		FilterCondition,
		SortConfig,
		GroupConfig
	} from '@shotleybuilder/svelte-gridlite-kit';
	import { createTanStackDBAdapter } from '@shotleybuilder/gridlite-adapter-tanstack-db';
	import { createPGLiteCollection } from '$lib/pglite/collection-bridge';
	import type { Collection } from '@tanstack/db';
	import type { ColumnMetadata } from '@shotleybuilder/svelte-gridlite-kit/types';
	import { adminAuth } from '$lib/stores/auth';
	import { authFetch } from '$lib/api/client';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// ── State ───────────────────────────────────────────────────────

	let db: PGLiteWithExtensions | null = null;
	let ready = false;
	let gridRef: GridLite;
	let adapter: ReturnType<typeof createTanStackDBAdapter> | null = null;
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	let collectionRef: Collection<any, any, any, any, any> | null = null;
	let error: string | null = null;

	// Selection for batch operations
	let selectedLawNames: Set<string> = new Set();

	// Stats (computed from local PGLite)
	let statTotal = 0;
	let statYes = 0;
	let statNo = 0;
	let statExcluded = 0;
	let statUnreviewed = 0;

	// ── Query ───────────────────────────────────────────────────────

	const SCREENING_QUERY = `
		SELECT l.id, l.name, l.title_en, l.family, l.family_ii, l.year,
		       l.type_code, l.live, l.is_making,
		       l.duty_holder, l.power_holder, l.rights_holder, l.responsibility_holder,
		       l.fitness_person, l.fitness_process, l.fitness_place,
		       l.fitness_plant, l.fitness_sector, l.has_fitness,
		       l.si_code, l.function, l.source_url,
		       COALESCE(oa.status, 'unreviewed') as app_status,
		       oa.id as app_id,
		       oa.notes as app_notes,
		       oa.reviewed_at,
		       oa.reviewed_by
		FROM laws l
		LEFT JOIN org_applicabilities oa ON oa.law_name = l.name
		WHERE l.is_making = true
		  AND (l.live IS NULL OR l.live NOT LIKE '%Revoked%')
	`;

	const SCREENING_COLUMN_METADATA: ColumnMetadata[] = [
		{ name: 'id', dataType: 'text', postgresType: 'uuid', nullable: false, hasDefault: true },
		{ name: 'name', dataType: 'text', postgresType: 'varchar', nullable: true, hasDefault: false },
		{
			name: 'title_en',
			dataType: 'text',
			postgresType: 'text',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'family',
			dataType: 'text',
			postgresType: 'varchar',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'family_ii',
			dataType: 'text',
			postgresType: 'varchar',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'year',
			dataType: 'number',
			postgresType: 'integer',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'type_code',
			dataType: 'text',
			postgresType: 'text',
			nullable: true,
			hasDefault: false
		},
		{ name: 'live', dataType: 'text', postgresType: 'varchar', nullable: true, hasDefault: false },
		{
			name: 'is_making',
			dataType: 'boolean',
			postgresType: 'bool',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'duty_holder',
			dataType: 'json',
			postgresType: 'jsonb',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'fitness_person',
			dataType: 'text',
			postgresType: 'text[]',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'fitness_place',
			dataType: 'text',
			postgresType: 'text[]',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'fitness_sector',
			dataType: 'text',
			postgresType: 'text[]',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'has_fitness',
			dataType: 'boolean',
			postgresType: 'bool',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'si_code',
			dataType: 'json',
			postgresType: 'jsonb',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'function',
			dataType: 'json',
			postgresType: 'jsonb',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'app_status',
			dataType: 'text',
			postgresType: 'text',
			nullable: false,
			hasDefault: true
		},
		{
			name: 'app_id',
			dataType: 'text',
			postgresType: 'uuid',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'app_notes',
			dataType: 'text',
			postgresType: 'text',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'reviewed_at',
			dataType: 'date',
			postgresType: 'timestamptz',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'source_url',
			dataType: 'text',
			postgresType: 'text',
			nullable: true,
			hasDefault: false
		}
	];

	// ── Editable fields ─────────────────────────────────────────────

	const EDITABLE_FIELDS = new Set(['app_status', 'app_notes']);

	const statusOptions = [
		{ value: 'yes', label: 'Yes' },
		{ value: 'no', label: 'No' },
		{ value: 'excluded', label: 'Excluded' },
		{ value: 'unreviewed', label: 'Unreviewed' }
	];

	// Inline editing state
	let editingCell: { id: string; field: string } | null = null;
	let editValue = '';

	function startEdit(id: string, field: string, currentValue: string | null) {
		editingCell = { id, field };
		editValue = currentValue ?? '';
	}

	async function saveEdit(value?: string) {
		if (!editingCell) return;
		const { id, field } = editingCell;
		const val = (value !== undefined ? value : editValue) || null;
		editingCell = null;
		editValue = '';
		await updateRecord(id, field, val);
	}

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

	// ── Mutation handler ────────────────────────────────────────────

	function updateRecord(id: string, field: string, value: string | null) {
		if (!collectionRef) return;
		const tx = collectionRef.update(id, (draft: Record<string, unknown>) => {
			draft[field] = value === '' ? null : value;
		});
		tx.isPersisted.promise.catch((e: unknown) => {
			alert(`Update failed: ${e instanceof Error ? e.message : 'Unknown error'}`);
		});
	}

	async function buildCollection() {
		if (!db) return;
		ready = false;

		const collection = createPGLiteCollection({
			db,
			query: SCREENING_QUERY,
			id: `screening-${Date.now()}`,
			onUpdate: async ({ transaction }) => {
				const user = $adminAuth;
				for (const m of transaction.mutations) {
					const changes = m.changes as Record<string, unknown>;
					const appChanges: Record<string, unknown> = {};
					for (const [field, value] of Object.entries(changes)) {
						if (EDITABLE_FIELDS.has(field)) {
							// Strip app_ prefix for backend field names
							const backendField = field.replace(/^app_/, '');
							appChanges[backendField] = value;
						}
					}
					if (Object.keys(appChanges).length === 0) continue;

					// Get the law_name from the row data
					const lawName = (m as unknown as { value?: Record<string, unknown> }).value
						?.name as string;
					if (!lawName) continue;

					// Upsert to backend
					const response = await authFetch(
						`${API_URL}/api/screening/applicabilities/${encodeURIComponent(lawName)}`,
						{
							method: 'PUT',
							headers: { 'Content-Type': 'application/json' },
							body: JSON.stringify(appChanges)
						}
					);
					if (!response.ok) {
						const err = await response.json().catch(() => ({ error: 'Unknown error' }));
						throw new Error(err.error || 'Failed to update');
					}

					// Write-back to local PGLite org_applicabilities
					const orgId = user?.org_id;
					if (orgId && db) {
						await db.query(
							`INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, notes, reviewed_at, reviewed_by, inserted_at, updated_at)
							 VALUES (gen_random_uuid(), $1, $2, $3, 'manual', $4, NOW(), $5, NOW(), NOW())
							 ON CONFLICT (organization_id, law_name) DO UPDATE SET
							   status = COALESCE($3, org_applicabilities.status),
							   notes = COALESCE($4, org_applicabilities.notes),
							   reviewed_at = NOW(),
							   reviewed_by = $5,
							   updated_at = NOW()`,
							[
								orgId,
								lawName,
								appChanges.status ?? null,
								appChanges.notes ?? null,
								user?.email || user?.id || null
							]
						);
					}
				}
			}
		});

		collectionRef = collection;
		adapter = createTanStackDBAdapter({ collection, columns: SCREENING_COLUMN_METADATA });
		await adapter.init();
		ready = true;
	}

	// ── Selection ───────────────────────────────────────────────────

	function toggleSelection(name: string) {
		if (selectedLawNames.has(name)) {
			selectedLawNames.delete(name);
		} else {
			selectedLawNames.add(name);
		}
		selectedLawNames = selectedLawNames;
	}

	async function selectAll() {
		if (!db) return;
		const result = await db.query<{ name: string }>(`SELECT name FROM (${SCREENING_QUERY}) sub`);
		selectedLawNames = new Set(result.rows.map((r) => r.name));
	}

	function deselectAll() {
		selectedLawNames = new Set();
	}

	async function bulkSetStatus(status: string) {
		if (selectedLawNames.size === 0) return;
		const names = Array.from(selectedLawNames);

		try {
			const response = await authFetch(`${API_URL}/api/screening/applicabilities/bulk`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ law_names: names, status })
			});
			if (!response.ok) throw new Error('Bulk update failed');

			// Write-back to PGLite
			const user = $adminAuth;
			if (db && user?.org_id) {
				for (const name of names) {
					await db.query(
						`INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, reviewed_at, reviewed_by, inserted_at, updated_at)
						 VALUES (gen_random_uuid(), $1, $2, $3, 'manual', NOW(), $4, NOW(), NOW())
						 ON CONFLICT (organization_id, law_name) DO UPDATE SET
						   status = $3, reviewed_at = NOW(), reviewed_by = $4, updated_at = NOW()`,
						[user.org_id, name, status, user.email || user.id || null]
					);
				}
			}

			// Rebuild collection to pick up changes
			await buildCollection();
			deselectAll();
		} catch (err) {
			alert(`Bulk update failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
		}
	}

	// ── Stats ────────────────────────────────────────────────────────

	async function refreshStats() {
		if (!db) return;
		try {
			const total = await db.query<{ count: string }>(
				`SELECT COUNT(*)::text as count FROM (${SCREENING_QUERY}) sub`
			);
			statTotal = parseInt(total.rows[0]?.count ?? '0', 10);

			const byStatus = await db.query<{ status: string; count: string }>(
				`SELECT app_status as status, COUNT(*)::text as count FROM (${SCREENING_QUERY}) sub GROUP BY app_status`
			);
			const counts = Object.fromEntries(byStatus.rows.map((r) => [r.status, parseInt(r.count)]));
			statYes = counts['yes'] ?? 0;
			statNo = counts['no'] ?? 0;
			statExcluded = counts['excluded'] ?? 0;
			statUnreviewed = counts['unreviewed'] ?? 0;
		} catch {
			/* ignore */
		}
	}

	// ── Helpers ──────────────────────────────────────────────────────

	function str(v: unknown): string {
		return String(v ?? '');
	}

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '';
		return new Date(dateStr).toLocaleDateString('en-GB', {
			day: '2-digit',
			month: 'short',
			year: 'numeric'
		});
	}

	function parseJsonValues(v: unknown): string[] {
		if (!v) return [];
		if (typeof v === 'string') {
			try {
				const parsed = JSON.parse(v);
				if (parsed?.values) return parsed.values;
				if (Array.isArray(parsed)) return parsed;
			} catch {
				/* not JSON */
			}
		}
		if (typeof v === 'object' && v !== null) {
			if ('values' in v && Array.isArray((v as Record<string, unknown>).values))
				return (v as Record<string, unknown[]>).values as string[];
		}
		return [];
	}

	function parseArray(v: unknown): string[] {
		if (!v) return [];
		if (Array.isArray(v)) return v;
		if (typeof v === 'string') {
			// PGLite arrays come as {a,b,c} format
			if (v.startsWith('{') && v.endsWith('}')) {
				return v
					.slice(1, -1)
					.split(',')
					.filter((s) => s.length > 0);
			}
			try {
				return JSON.parse(v);
			} catch {
				return [];
			}
		}
		return [];
	}

	// ── URL State ───────────────────────────────────────────────────

	let latestGridState: GridState | null = null;

	function handleStateChange(state: GridState) {
		latestGridState = state;
		refreshStats();
	}

	// ── Columns ─────────────────────────────────────────────────────

	const columns: ColumnConfig[] = [
		{ name: 'name', label: 'Law', width: 160, dataType: 'text' },
		{ name: 'title_en', label: 'Title', width: 300, dataType: 'text' },
		{ name: 'family', label: 'Family', width: 180, dataType: 'text' },
		{
			name: 'app_status',
			label: 'Applicable',
			width: 120,
			dataType: 'text',
			selectOptions: statusOptions
		},
		{ name: 'app_notes', label: 'Notes', width: 200, dataType: 'text' },
		{ name: 'duty_holder', label: 'Duty Holders', width: 180, dataType: 'json' },
		{ name: 'fitness_person', label: 'Fitness: Person', width: 130, dataType: 'text' },
		{ name: 'fitness_place', label: 'Fitness: Place', width: 130, dataType: 'text' },
		{ name: 'fitness_sector', label: 'Fitness: Sector', width: 130, dataType: 'text' },
		{ name: 'live', label: 'Status', width: 100, dataType: 'text' },
		{ name: 'type_code', label: 'Type', width: 70, dataType: 'text' },
		{ name: 'year', label: 'Year', width: 70, dataType: 'number' },
		{
			name: 'reviewed_at',
			label: 'Reviewed',
			width: 100,
			dataType: 'date',
			format: (v) => formatDate(v as string | null)
		}
	];

	// ── Lifecycle ───────────────────────────────────────────────────

	$: if ($syncStatus.error) {
		error = $syncStatus.error;
	}
	$: isLoading = !$syncStatus.connected && !ready;

	onMount(async () => {
		if (browser) {
			await startSync();
			db = await getPglite();
			await buildCollection();
			await refreshStats();
		}
	});
</script>

<svelte:head>
	<title>Applicability Screening - SertantAI</title>
</svelte:head>

<div class="flex flex-col h-full overflow-auto px-6 py-4 space-y-4">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">Applicability Screening</h1>
			<p class="mt-1 text-sm text-gray-500">
				Review laws and set applicability for your organisation.
			</p>
		</div>
		<div class="flex items-center space-x-3">
			<button
				on:click={selectAll}
				class="px-3 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
			>
				Select All
			</button>
			<button
				on:click={deselectAll}
				disabled={selectedLawNames.size === 0}
				class="px-3 py-2 text-sm font-medium text-gray-600 bg-white border border-gray-300 rounded-md hover:bg-gray-50 disabled:opacity-50"
			>
				Deselect
			</button>
			<button
				on:click={() => bulkSetStatus('yes')}
				disabled={selectedLawNames.size === 0}
				class="px-3 py-2 text-sm font-medium text-white bg-green-600 rounded-md hover:bg-green-700 disabled:opacity-50"
			>
				Set Yes ({selectedLawNames.size})
			</button>
			<button
				on:click={() => bulkSetStatus('no')}
				disabled={selectedLawNames.size === 0}
				class="px-3 py-2 text-sm font-medium text-white bg-red-500 rounded-md hover:bg-red-600 disabled:opacity-50"
			>
				Set No ({selectedLawNames.size})
			</button>
		</div>
	</div>

	<!-- Stats Bar -->
	{#if ready}
		<div class="grid grid-cols-5 gap-4">
			<div class="bg-white rounded-lg border border-gray-200 p-3">
				<div class="text-xs text-gray-500">Total Laws</div>
				<div class="text-xl font-bold text-gray-900">{statTotal}</div>
			</div>
			<div class="bg-white rounded-lg border border-green-200 p-3">
				<div class="text-xs text-gray-500">Yes</div>
				<div class="text-xl font-bold text-green-600">{statYes}</div>
			</div>
			<div class="bg-white rounded-lg border border-red-200 p-3">
				<div class="text-xs text-gray-500">No</div>
				<div class="text-xl font-bold text-red-500">{statNo}</div>
			</div>
			<div class="bg-white rounded-lg border border-gray-200 p-3">
				<div class="text-xs text-gray-500">Excluded</div>
				<div class="text-xl font-bold text-gray-500">{statExcluded}</div>
			</div>
			<div class="bg-white rounded-lg border border-amber-200 p-3">
				<div class="text-xs text-gray-500">Unreviewed</div>
				<div class="text-xl font-bold text-amber-600">{statUnreviewed}</div>
			</div>
		</div>
	{/if}

	<!-- Grid -->
	{#if isLoading}
		<div class="px-4 py-12 text-center bg-white rounded-lg border border-gray-200">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
			<p class="mt-4 text-gray-600">Loading screening data...</p>
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
				id: 'screening',
				columns,
				defaultSorting: [{ column: 'family', direction: 'asc' }],
				defaultVisibleColumns: [
					'name',
					'title_en',
					'family',
					'app_status',
					'app_notes',
					'duty_holder',
					'fitness_person',
					'fitness_place',
					'live',
					'year'
				],
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
			<svelte:fragment slot="cell" let:value let:row let:column>
				{#if column === 'name'}
					{@const rowName = str(row.name)}
					<div class="flex items-center gap-1.5">
						<input
							type="checkbox"
							checked={selectedLawNames.has(rowName)}
							on:change={() => toggleSelection(rowName)}
							class="h-4 w-4 rounded border-gray-300 text-emerald-600 focus:ring-emerald-500"
						/>
						<span class="font-mono text-xs text-gray-700 truncate">{value}</span>
					</div>
				{:else if column === 'title_en'}
					<span class="text-gray-900 whitespace-normal leading-snug text-sm">{value || ''}</span>
				{:else if column === 'app_status'}
					{@const rowId = str(row.id)}
					{#if editingCell?.id === rowId && editingCell?.field === 'app_status'}
						<select
							class="w-full text-sm border border-emerald-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-emerald-500"
							bind:value={editValue}
							on:change={handleSelectSave}
							on:blur={() => saveEdit()}
							on:keydown={handleEditKeydown}
						>
							{#each statusOptions as opt}
								<option value={opt.value}>{opt.label}</option>
							{/each}
						</select>
					{:else}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer"
							on:dblclick={() => startEdit(str(row.id), 'app_status', str(value))}
							title="Double-click to edit"
						>
							{#if value === 'yes'}
								<span class="px-2 py-0.5 text-xs rounded-full bg-green-100 text-green-700">Yes</span
								>
							{:else if value === 'no'}
								<span class="px-2 py-0.5 text-xs rounded-full bg-red-100 text-red-700">No</span>
							{:else if value === 'excluded'}
								<span class="px-2 py-0.5 text-xs rounded-full bg-gray-100 text-gray-600"
									>Excluded</span
								>
							{:else}
								<span class="px-2 py-0.5 text-xs rounded-full bg-amber-100 text-amber-700"
									>Unreviewed</span
								>
							{/if}
						</button>
					{/if}
				{:else if column === 'app_notes'}
					{@const rowId2 = str(row.id)}
					{#if editingCell?.id === rowId2 && editingCell?.field === 'app_notes'}
						<input
							type="text"
							class="w-full text-sm border border-emerald-400 rounded px-1 py-0.5 focus:outline-none focus:ring-2 focus:ring-emerald-500"
							bind:value={editValue}
							on:blur={() => saveEdit()}
							on:keydown={handleEditKeydown}
						/>
					{:else}
						<button
							class="w-full text-left hover:bg-gray-100 px-1 py-0.5 rounded cursor-pointer truncate text-sm text-gray-600"
							on:dblclick={() => startEdit(str(row.id), 'app_notes', str(value) || null)}
							title="Double-click to add notes"
						>
							{value || '-'}
						</button>
					{/if}
				{:else if column === 'duty_holder'}
					{@const holders = parseJsonValues(value)}
					{#if holders.length > 0}
						<div class="flex flex-wrap gap-1">
							{#each holders.slice(0, 3) as holder}
								<span class="px-1.5 py-0.5 text-xs rounded bg-blue-50 text-blue-700">{holder}</span>
							{/each}
							{#if holders.length > 3}
								<span class="text-xs text-gray-400">+{holders.length - 3}</span>
							{/if}
						</div>
					{:else}
						<span class="text-gray-300">-</span>
					{/if}
				{:else if column === 'fitness_person' || column === 'fitness_place' || column === 'fitness_sector'}
					{@const items = parseArray(value)}
					{#if items.length > 0}
						<div class="flex flex-wrap gap-1">
							{#each items as item}
								<span class="px-1.5 py-0.5 text-xs rounded bg-purple-50 text-purple-700"
									>{item}</span
								>
							{/each}
						</div>
					{:else}
						<span class="text-gray-300">-</span>
					{/if}
				{:else if column === 'live'}
					{@const status = str(value)}
					<span
						class="inline-flex px-1.5 py-0.5 text-xs font-medium rounded
						{status.includes('In force')
							? 'bg-green-100 text-green-800'
							: status.includes('Part')
								? 'bg-amber-100 text-amber-800'
								: 'bg-gray-100 text-gray-800'}"
					>
						{status || '-'}
					</span>
				{:else if column === 'family'}
					<span class="text-gray-700 whitespace-normal leading-snug text-sm">{value || '-'}</span>
				{:else}
					{value ?? '-'}
				{/if}
			</svelte:fragment>
		</GridLite>
	{/if}
</div>
