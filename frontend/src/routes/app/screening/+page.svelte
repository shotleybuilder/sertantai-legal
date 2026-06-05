<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { GridLite } from '@shotleybuilder/svelte-gridlite-kit';
	import '@shotleybuilder/svelte-gridlite-kit/styles';
	import type { ColumnConfig, GridState } from '@shotleybuilder/svelte-gridlite-kit';
	import { createTanStackDBAdapter } from '@shotleybuilder/gridlite-adapter-tanstack-db';
	import { createPGLiteCollection } from '$lib/pglite/collection-bridge';
	import type { ColumnMetadata } from '@shotleybuilder/svelte-gridlite-kit/types';
	import { adminAuth } from '$lib/stores/auth';
	import { authFetch } from '$lib/api/client';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite, type PGLiteWithExtensions } from '$lib/pglite/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// ── State ───────────────────────────────────────────────────────

	let db: PGLiteWithExtensions | null = null;
	let ready = false;
	let error: string | null = null;

	// Left panel (available + excluded)
	let leftAdapter: ReturnType<typeof createTanStackDBAdapter> | null = null;
	let leftGridRef: GridLite;
	let leftSelectedNames: Set<string> = new Set();

	// Right panel (my register)
	let rightAdapter: ReturnType<typeof createTanStackDBAdapter> | null = null;
	let rightGridRef: GridLite;
	let rightSelectedNames: Set<string> = new Set();

	// Stats
	let statAvailable = 0;
	let statRegister = 0;
	let statExcluded = 0;

	// Notes editing
	let editingNotes: { name: string; value: string } | null = null;

	// ── Queries ─────────────────────────────────────────────────────

	const SHARED_COLUMNS = `
		l.id, l.name, l.title_en, l.family, l.family_ii, l.year,
		l.type_code, l.live, l.is_making,
		l.duty_holder, l.power_holder, l.rights_holder, l.responsibility_holder,
		l.fitness_person, l.fitness_process, l.fitness_place,
		l.fitness_plant, l.fitness_sector, l.has_fitness,
		l.si_code, l.function, l.source_url
	`;

	const LEFT_QUERY = `
		SELECT ${SHARED_COLUMNS},
		       COALESCE(oa.status, 'unreviewed') as app_status,
		       oa.notes as app_notes
		FROM laws l
		LEFT JOIN org_applicabilities oa ON oa.law_name = l.name
		WHERE l.is_making = true
		  AND (l.live IS NULL OR l.live NOT LIKE '%Revoked%')
		  AND (oa.status IS NULL OR oa.status IN ('unreviewed', 'no', 'excluded'))
	`;

	const RIGHT_QUERY = `
		SELECT ${SHARED_COLUMNS},
		       oa.status as app_status,
		       oa.notes as app_notes,
		       oa.reviewed_at
		FROM laws l
		INNER JOIN org_applicabilities oa ON oa.law_name = l.name
		WHERE oa.status = 'yes'
	`;

	// ── Column Metadata ─────────────────────────────────────────────

	const COLUMN_METADATA: ColumnMetadata[] = [
		{ name: 'id', dataType: 'text', postgresType: 'uuid', nullable: false, hasDefault: true },
		{
			name: 'name',
			dataType: 'text',
			postgresType: 'varchar',
			nullable: true,
			hasDefault: false
		},
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
		{
			name: 'live',
			dataType: 'text',
			postgresType: 'varchar',
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
			name: 'app_status',
			dataType: 'text',
			postgresType: 'text',
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
		}
	];

	// ── Persist helpers ─────────────────────────────────────────────

	async function setStatus(lawName: string, status: string) {
		const user = $adminAuth;
		if (!user?.org_id || !db) return;

		// 1. Backend upsert
		const response = await authFetch(
			`${API_URL}/api/screening/applicabilities/${encodeURIComponent(lawName)}`,
			{
				method: 'PUT',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ status })
			}
		);
		if (!response.ok) {
			const err = await response.json().catch(() => ({ error: 'Unknown error' }));
			alert(`Failed: ${err.error || 'Unknown error'}`);
			return;
		}

		// 2. PGLite write-back
		await db.query(
			`INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, reviewed_at, reviewed_by, inserted_at, updated_at)
			 VALUES (gen_random_uuid(), $1, $2, $3, 'manual', NOW(), $4, NOW(), NOW())
			 ON CONFLICT (organization_id, law_name) DO UPDATE SET
			   status = $3, reviewed_at = NOW(), reviewed_by = $4, updated_at = NOW()`,
			[user.org_id, lawName, status, user.email || user.id || null]
		);

		// 3. Rebuild both panels to reflect the move
		await rebuildPanels();
	}

	async function bulkSetStatus(lawNames: string[], status: string) {
		if (lawNames.length === 0) return;
		const user = $adminAuth;
		if (!user?.org_id || !db) return;

		const response = await authFetch(`${API_URL}/api/screening/applicabilities/bulk`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ law_names: lawNames, status })
		});
		if (!response.ok) {
			alert('Bulk update failed');
			return;
		}

		for (const name of lawNames) {
			await db.query(
				`INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, reviewed_at, reviewed_by, inserted_at, updated_at)
				 VALUES (gen_random_uuid(), $1, $2, $3, 'manual', NOW(), $4, NOW(), NOW())
				 ON CONFLICT (organization_id, law_name) DO UPDATE SET
				   status = $3, reviewed_at = NOW(), reviewed_by = $4, updated_at = NOW()`,
				[user.org_id, name, status, user.email || user.id || null]
			);
		}

		leftSelectedNames = new Set();
		rightSelectedNames = new Set();
		await rebuildPanels();
	}

	async function saveNotes(lawName: string, notes: string) {
		const user = $adminAuth;
		if (!user?.org_id || !db) return;

		await authFetch(`${API_URL}/api/screening/applicabilities/${encodeURIComponent(lawName)}`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ notes })
		});

		await db.query(
			`UPDATE org_applicabilities SET notes = $1, updated_at = NOW()
			 WHERE law_name = $2`,
			[notes, lawName]
		);

		editingNotes = null;
	}

	// ── Panel builders ──────────────────────────────────────────────

	async function rebuildPanels() {
		if (!db) return;
		ready = false;

		// Left panel: available + excluded
		const leftCollection = createPGLiteCollection({
			db,
			query: LEFT_QUERY,
			id: `screening-left-${Date.now()}`
		});
		leftAdapter = createTanStackDBAdapter({ collection: leftCollection, columns: COLUMN_METADATA });
		await leftAdapter.init();

		// Right panel: my register
		const rightCollection = createPGLiteCollection({
			db,
			query: RIGHT_QUERY,
			id: `screening-right-${Date.now()}`
		});
		rightAdapter = createTanStackDBAdapter({
			collection: rightCollection,
			columns: COLUMN_METADATA
		});
		await rightAdapter.init();

		await refreshStats();
		ready = true;
	}

	async function refreshStats() {
		if (!db) return;
		try {
			const left = await db.query<{ count: string }>(
				`SELECT COUNT(*)::text as count FROM (${LEFT_QUERY}) sub WHERE app_status != 'excluded'`
			);
			statAvailable = parseInt(left.rows[0]?.count ?? '0', 10);

			const right = await db.query<{ count: string }>(
				`SELECT COUNT(*)::text as count FROM (${RIGHT_QUERY}) sub`
			);
			statRegister = parseInt(right.rows[0]?.count ?? '0', 10);

			const excluded = await db.query<{ count: string }>(
				`SELECT COUNT(*)::text as count FROM (${LEFT_QUERY}) sub WHERE app_status = 'excluded'`
			);
			statExcluded = parseInt(excluded.rows[0]?.count ?? '0', 10);
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
			month: 'short'
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

	// ── Selection ───────────────────────────────────────────────────

	function toggleLeftSelection(name: string) {
		if (leftSelectedNames.has(name)) leftSelectedNames.delete(name);
		else leftSelectedNames.add(name);
		leftSelectedNames = leftSelectedNames;
	}

	function toggleRightSelection(name: string) {
		if (rightSelectedNames.has(name)) rightSelectedNames.delete(name);
		else rightSelectedNames.add(name);
		rightSelectedNames = rightSelectedNames;
	}

	// ── Grid state ──────────────────────────────────────────────────

	function handleLeftStateChange(_state: GridState) {
		refreshStats();
	}

	function handleRightStateChange(_state: GridState) {
		refreshStats();
	}

	// ── Column definitions ──────────────────────────────────────────

	const leftColumns: ColumnConfig[] = [
		{ name: 'name', label: 'Law', width: 140, dataType: 'text' },
		{ name: 'title_en', label: 'Title', width: 250, dataType: 'text' },
		{ name: 'family', label: 'Family', width: 150, dataType: 'text' },
		{ name: 'duty_holder', label: 'Duty Holders', width: 150, dataType: 'json' },
		{ name: 'fitness_person', label: 'Person', width: 100, dataType: 'text' },
		{ name: 'fitness_place', label: 'Place', width: 100, dataType: 'text' },
		{ name: 'live', label: 'Status', width: 80, dataType: 'text' },
		{ name: 'app_status', label: '', width: 50, dataType: 'text' }
	];

	const rightColumns: ColumnConfig[] = [
		{ name: 'name', label: 'Law', width: 140, dataType: 'text' },
		{ name: 'title_en', label: 'Title', width: 250, dataType: 'text' },
		{ name: 'family', label: 'Family', width: 150, dataType: 'text' },
		{ name: 'app_notes', label: 'Notes', width: 180, dataType: 'text' },
		{ name: 'duty_holder', label: 'Duty Holders', width: 150, dataType: 'json' },
		{ name: 'reviewed_at', label: 'Added', width: 80, dataType: 'date' }
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
			await rebuildPanels();
		}
	});
</script>

<svelte:head>
	<title>Applicability Screening - SertantAI</title>
</svelte:head>

<div class="flex flex-col h-full">
	<!-- Stats bar -->
	{#if ready}
		<div class="flex items-center gap-6 px-6 py-3 bg-white border-b border-gray-200">
			<div class="flex items-center gap-2">
				<span class="text-sm text-gray-500">Available</span>
				<span class="text-lg font-semibold text-gray-700">{statAvailable}</span>
			</div>
			<div class="flex items-center gap-2">
				<span class="text-sm text-gray-500">My Register</span>
				<span class="text-lg font-semibold text-emerald-600">{statRegister}</span>
			</div>
			<div class="flex items-center gap-2">
				<span class="text-sm text-gray-500">Excluded</span>
				<span class="text-lg font-semibold text-gray-400">{statExcluded}</span>
			</div>
			<div class="flex-1"></div>
			<div
				class="h-2 w-48 bg-gray-200 rounded-full overflow-hidden"
				title="{statRegister} of {statAvailable + statRegister} screened"
			>
				<div
					class="h-full bg-emerald-500 rounded-full transition-all duration-300"
					style="width: {statAvailable + statRegister > 0
						? (statRegister / (statAvailable + statRegister)) * 100
						: 0}%"
				></div>
			</div>
		</div>
	{/if}

	{#if isLoading}
		<div class="flex-1 flex items-center justify-center">
			<div class="text-center">
				<div
					class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
				></div>
				<p class="mt-4 text-gray-600">Loading screening data...</p>
			</div>
		</div>
	{:else if error}
		<div class="m-6 px-4 py-8 bg-red-50 border border-red-200 rounded-lg">
			<p class="text-red-600">{error}</p>
			<button
				class="mt-4 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
				on:click={() => window.location.reload()}>Retry</button
			>
		</div>
	{:else if ready && leftAdapter && rightAdapter}
		<!-- Two-panel split -->
		<div class="flex-1 flex overflow-hidden">
			<!-- LEFT PANEL: Available + Excluded -->
			<div class="flex-1 flex flex-col border-r border-gray-200 overflow-hidden">
				<div
					class="flex items-center justify-between px-4 py-2 bg-gray-50 border-b border-gray-200"
				>
					<h2 class="text-sm font-semibold text-gray-700">
						Available ({statAvailable})
						{#if statExcluded > 0}
							<span class="text-gray-400 font-normal">+ {statExcluded} excluded</span>
						{/if}
					</h2>
					{#if leftSelectedNames.size > 0}
						<button
							on:click={() => bulkSetStatus(Array.from(leftSelectedNames), 'yes')}
							class="px-3 py-1 text-xs font-medium text-white bg-emerald-600 rounded hover:bg-emerald-700"
						>
							+ Add {leftSelectedNames.size} to register
						</button>
					{/if}
				</div>
				<div class="flex-1 overflow-auto">
					<GridLite
						bind:this={leftGridRef}
						adapter={leftAdapter}
						onStateChange={handleLeftStateChange}
						config={{
							id: 'screening-available',
							columns: leftColumns,
							defaultSorting: [{ column: 'family', direction: 'asc' }],
							defaultVisibleColumns: [
								'name',
								'title_en',
								'family',
								'duty_holder',
								'fitness_person',
								'live',
								'app_status'
							],
							pagination: { pageSize: 50 }
						}}
						features={{
							columnVisibility: true,
							columnResizing: true,
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
										checked={leftSelectedNames.has(rowName)}
										on:change={() => toggleLeftSelection(rowName)}
										class="h-3.5 w-3.5 rounded border-gray-300 text-emerald-600"
									/>
									<span class="font-mono text-xs text-gray-600 truncate">{value}</span>
								</div>
							{:else if column === 'title_en'}
								<span class="text-sm text-gray-900 whitespace-normal leading-snug"
									>{value || ''}</span
								>
							{:else if column === 'app_status'}
								{@const lawName = str(row.name)}
								{@const status = str(value)}
								<div class="flex gap-1">
									{#if status === 'excluded'}
										<button
											on:click={() => setStatus(lawName, 'unreviewed')}
											class="p-1 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded"
											title="Restore to available"
										>
											<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"
												><path
													stroke-linecap="round"
													stroke-linejoin="round"
													stroke-width="2"
													d="M3 10h10a5 5 0 015 5v2M3 10l4-4M3 10l4 4"
												/></svg
											>
										</button>
									{:else}
										<button
											on:click={() => setStatus(lawName, 'yes')}
											class="p-1 text-gray-400 hover:text-emerald-600 hover:bg-emerald-50 rounded"
											title="Add to register"
										>
											<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"
												><path
													stroke-linecap="round"
													stroke-linejoin="round"
													stroke-width="2"
													d="M12 4v16m8-8H4"
												/></svg
											>
										</button>
										<button
											on:click={() => setStatus(lawName, 'excluded')}
											class="p-1 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded"
											title="Exclude"
										>
											<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"
												><path
													stroke-linecap="round"
													stroke-linejoin="round"
													stroke-width="2"
													d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636"
												/></svg
											>
										</button>
									{/if}
								</div>
							{:else if column === 'duty_holder'}
								{@const holders = parseJsonValues(value)}
								{#if holders.length > 0}
									<div class="flex flex-wrap gap-0.5">
										{#each holders.slice(0, 2) as holder}
											<span class="px-1 py-0.5 text-xs rounded bg-blue-50 text-blue-700"
												>{holder}</span
											>
										{/each}
										{#if holders.length > 2}
											<span class="text-xs text-gray-400">+{holders.length - 2}</span>
										{/if}
									</div>
								{:else}
									<span class="text-gray-300">-</span>
								{/if}
							{:else if column === 'fitness_person' || column === 'fitness_place'}
								{@const items = parseArray(value)}
								{#if items.length > 0}
									<div class="flex flex-wrap gap-0.5">
										{#each items as item}
											<span class="px-1 py-0.5 text-xs rounded bg-purple-50 text-purple-700"
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
									class="text-xs {status.includes('In force')
										? 'text-green-700'
										: 'text-amber-700'}">{status ? '✔' : '-'}</span
								>
							{:else if column === 'family'}
								<span class="text-xs text-gray-600 whitespace-normal">{value || '-'}</span>
							{:else}
								<span class="text-xs">{value ?? '-'}</span>
							{/if}
						</svelte:fragment>
					</GridLite>
				</div>
			</div>

			<!-- RIGHT PANEL: My Register -->
			<div class="flex-1 flex flex-col overflow-hidden">
				<div
					class="flex items-center justify-between px-4 py-2 bg-emerald-50 border-b border-emerald-200"
				>
					<h2 class="text-sm font-semibold text-emerald-800">
						My Register ({statRegister})
					</h2>
					{#if rightSelectedNames.size > 0}
						<button
							on:click={() => bulkSetStatus(Array.from(rightSelectedNames), 'unreviewed')}
							class="px-3 py-1 text-xs font-medium text-red-700 bg-red-100 rounded hover:bg-red-200"
						>
							× Remove {rightSelectedNames.size}
						</button>
					{/if}
				</div>
				<div class="flex-1 overflow-auto">
					<GridLite
						bind:this={rightGridRef}
						adapter={rightAdapter}
						onStateChange={handleRightStateChange}
						config={{
							id: 'screening-register',
							columns: rightColumns,
							defaultSorting: [{ column: 'family', direction: 'asc' }],
							defaultVisibleColumns: [
								'name',
								'title_en',
								'family',
								'app_notes',
								'duty_holder',
								'reviewed_at'
							],
							pagination: { pageSize: 50 }
						}}
						features={{
							columnVisibility: true,
							columnResizing: true,
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
										checked={rightSelectedNames.has(rowName)}
										on:change={() => toggleRightSelection(rowName)}
										class="h-3.5 w-3.5 rounded border-gray-300 text-emerald-600"
									/>
									<span class="font-mono text-xs text-gray-600 truncate">{value}</span>
								</div>
							{:else if column === 'title_en'}
								<span class="text-sm text-gray-900 whitespace-normal leading-snug"
									>{value || ''}</span
								>
							{:else if column === 'app_notes'}
								{@const lawName = str(row.name)}
								{#if editingNotes?.name === lawName}
									<input
										type="text"
										class="w-full text-xs border border-emerald-400 rounded px-1 py-0.5 focus:outline-none focus:ring-1 focus:ring-emerald-500"
										bind:value={editingNotes.value}
										on:blur={() => {
											if (editingNotes) saveNotes(editingNotes.name, editingNotes.value);
										}}
										on:keydown={(e) => {
											if (e.key === 'Enter') {
												if (editingNotes) saveNotes(editingNotes.name, editingNotes.value);
											} else if (e.key === 'Escape') {
												editingNotes = null;
											}
										}}
									/>
								{:else}
									<button
										class="w-full text-left text-xs text-gray-500 hover:bg-gray-100 px-1 py-0.5 rounded truncate"
										on:dblclick={() => {
											editingNotes = { name: lawName, value: str(value) };
										}}
										title="Double-click to edit"
									>
										{value || 'Add notes...'}
									</button>
								{/if}
							{:else if column === 'duty_holder'}
								{@const holders = parseJsonValues(value)}
								{#if holders.length > 0}
									<div class="flex flex-wrap gap-0.5">
										{#each holders.slice(0, 2) as holder}
											<span class="px-1 py-0.5 text-xs rounded bg-blue-50 text-blue-700"
												>{holder}</span
											>
										{/each}
										{#if holders.length > 2}
											<span class="text-xs text-gray-400">+{holders.length - 2}</span>
										{/if}
									</div>
								{:else}
									<span class="text-gray-300">-</span>
								{/if}
							{:else if column === 'reviewed_at'}
								<span class="text-xs text-gray-500">{formatDate(str(value))}</span>
							{:else if column === 'family'}
								<span class="text-xs text-gray-600 whitespace-normal">{value || '-'}</span>
							{:else}
								<span class="text-xs">{value ?? '-'}</span>
							{/if}
						</svelte:fragment>
					</GridLite>
				</div>
			</div>
		</div>
	{/if}
</div>
