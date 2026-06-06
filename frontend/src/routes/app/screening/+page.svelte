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

	// Seed preview
	let seedPreview: { name: string; title: string; family: string; score: number }[] | null = null;
	let seedUncategorized: { name: string; title: string; family: string }[] | null = null;
	let seedLoading = false;
	let seedStrong = 0;
	let seedSingle = 0;
	let showUncategorized = false;

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
		       oa.reviewed_at,
		       oa.reviewed_by,
		       oa.source as app_source
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
		},
		{
			name: 'reviewed_by',
			dataType: 'text',
			postgresType: 'text',
			nullable: true,
			hasDefault: false
		},
		{
			name: 'app_source',
			dataType: 'text',
			postgresType: 'text',
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

	// ── Seed preview ────────────────────────────────────────────────

	async function runSeedPreview() {
		if (!db || $syncStatus.syncing) return;
		seedLoading = true;
		seedPreview = null;

		try {
			// Load profile from backend
			const profileRes = await authFetch(`${API_URL}/api/screening/profile`);
			if (!profileRes.ok) {
				alert('No profile configured. Go to Profile to set up your organisation.');
				seedLoading = false;
				return;
			}
			const profile = await profileRes.json();

			// Check profile has at least one tag
			const allTags = [
				...(profile.regions || []),
				...(profile.activities || []),
				...(profile.locations || []),
				...(profile.materials || []),
				...(profile.processes || []),
				...(profile.sector || [])
			];
			if (allTags.length === 0) {
				alert('Profile is empty. Go to Profile and select some tags first.');
				seedLoading = false;
				return;
			}

			// Build scored matching query in PGLite
			// Stage 1: geo filter via geo_region overlap
			// Stage 2: fitness intersection with match_score
			const regions = profile.regions || [];
			const activities = profile.activities || [];
			const locations = profile.locations || [];
			const materials = profile.materials || [];
			const processes = profile.processes || [];
			const sector = profile.sector || [];

			const result = await db.query<{
				name: string;
				title_en: string;
				family: string;
				match_score: string;
			}>(
				`SELECT l.name, l.title_en, COALESCE(l.family, '') as family,
				        (CASE WHEN l.fitness_person IS NOT NULL AND l.fitness_person && $1 THEN 1 ELSE 0 END +
				         CASE WHEN l.fitness_place IS NOT NULL AND l.fitness_place && $2 THEN 1 ELSE 0 END +
				         CASE WHEN l.fitness_plant IS NOT NULL AND l.fitness_plant && $3 THEN 1 ELSE 0 END +
				         CASE WHEN l.fitness_process IS NOT NULL AND l.fitness_process && $4 THEN 1 ELSE 0 END +
				         CASE WHEN l.fitness_sector IS NOT NULL AND l.fitness_sector && $5 THEN 1 ELSE 0 END)::text as match_score
				 FROM laws l
				 LEFT JOIN org_applicabilities oa ON oa.law_name = l.name
				 WHERE l.is_making = true
				   AND (l.live IS NULL OR l.live NOT LIKE '%Revoked%')
				   AND (oa.status IS NULL OR oa.status NOT IN ('yes'))
				   AND ($6::text[] = '{}' OR l.geo_region IS NOT NULL AND l.geo_region && $6)
				   AND (CASE WHEN l.fitness_person IS NOT NULL AND l.fitness_person && $1 THEN 1 ELSE 0 END +
				        CASE WHEN l.fitness_place IS NOT NULL AND l.fitness_place && $2 THEN 1 ELSE 0 END +
				        CASE WHEN l.fitness_plant IS NOT NULL AND l.fitness_plant && $3 THEN 1 ELSE 0 END +
				        CASE WHEN l.fitness_process IS NOT NULL AND l.fitness_process && $4 THEN 1 ELSE 0 END +
				        CASE WHEN l.fitness_sector IS NOT NULL AND l.fitness_sector && $5 THEN 1 ELSE 0 END) > 0
				 ORDER BY match_score DESC, l.family, l.name`,
				[activities, locations, materials, processes, sector, regions]
			);

			seedPreview = result.rows.map((r) => ({
				name: r.name,
				title: r.title_en || '',
				family: r.family,
				score: parseInt(r.match_score)
			}));

			seedStrong = seedPreview.filter((r) => r.score >= 2).length;
			seedSingle = seedPreview.filter((r) => r.score === 1).length;

			// Stage 3: Uncategorized — laws with NO fitness data but matching geo + has a family
			const uncatResult = await db.query<{
				name: string;
				title_en: string;
				family: string;
			}>(
				`SELECT l.name, l.title_en, COALESCE(l.family, '') as family
				 FROM laws l
				 LEFT JOIN org_applicabilities oa ON oa.law_name = l.name
				 WHERE l.is_making = true
				   AND (l.live IS NULL OR l.live NOT LIKE '%Revoked%')
				   AND (oa.status IS NULL OR oa.status NOT IN ('yes'))
				   AND l.family IS NOT NULL AND l.family != ''
				   AND ($1::text[] = '{}' OR l.geo_region IS NOT NULL AND l.geo_region && $1)
				   AND (l.fitness_person IS NULL OR l.fitness_person = '{}')
				   AND (l.fitness_place IS NULL OR l.fitness_place = '{}')
				   AND (l.fitness_plant IS NULL OR l.fitness_plant = '{}')
				   AND (l.fitness_process IS NULL OR l.fitness_process = '{}')
				   AND (l.fitness_sector IS NULL OR l.fitness_sector = '{}')
				 ORDER BY l.family, l.name`,
				[regions]
			);

			seedUncategorized = uncatResult.rows.map((r) => ({
				name: r.name,
				title: r.title_en || '',
				family: r.family
			}));
		} catch (err) {
			console.error('Seed preview failed:', err);
			alert(`Seed preview failed: ${err instanceof Error ? err.message : 'Unknown error'}`);
		} finally {
			seedLoading = false;
		}
	}

	async function executeSeed() {
		if (!seedPreview || seedPreview.length === 0) return;
		const user = $adminAuth;
		if (!user?.org_id || !db) return;

		const lawNames = seedPreview.map((r) => r.name);

		// Build match_reason per law for explainability (G5)
		const response = await authFetch(`${API_URL}/api/screening/applicabilities/bulk`, {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				law_names: lawNames,
				status: 'yes',
				source: 'screener'
			})
		});

		if (!response.ok) {
			alert('Seed failed');
			return;
		}

		// Write-back to PGLite
		for (const law of seedPreview) {
			await db.query(
				`INSERT INTO org_applicabilities (id, organization_id, law_name, status, source, reviewed_at, reviewed_by, inserted_at, updated_at)
				 VALUES (gen_random_uuid(), $1, $2, 'yes', 'screener', NOW(), 'sertantai', NOW(), NOW())
				 ON CONFLICT (organization_id, law_name) DO UPDATE SET
				   status = 'yes', source = 'screener', reviewed_at = NOW(), reviewed_by = 'sertantai', updated_at = NOW()`,
				[user.org_id, law.name]
			);
		}

		seedPreview = null;
		await rebuildPanels();
	}

	function closeSeedPreview() {
		seedPreview = null;
		seedUncategorized = null;
		showUncategorized = false;
	}

	async function confirmLaw(lawName: string) {
		// Transfer ownership from SertantAI to user
		const user = $adminAuth;
		if (!user?.org_id || !db) return;

		await authFetch(`${API_URL}/api/screening/applicabilities/${encodeURIComponent(lawName)}`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ status: 'yes', notes: null })
		});

		await db.query(
			`UPDATE org_applicabilities SET source = 'manual', reviewed_by = $1, reviewed_at = NOW(), updated_at = NOW()
			 WHERE law_name = $2`,
			[user.email || user.id || null, lawName]
		);

		await rebuildPanels();
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

	function groupByFamily(
		laws: { name: string; title: string; family: string }[]
	): [string, { name: string; title: string; family: string }[]][] {
		const map = new Map<string, { name: string; title: string; family: string }[]>();
		for (const law of laws) {
			const fam = law.family || 'Unclassified';
			if (!map.has(fam)) map.set(fam, []);
			map.get(fam)!.push(law);
		}
		return [...map.entries()].sort((a, b) => b[1].length - a[1].length);
	}

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
	// URL state persistence deferred — blocked on gridlite-kit#34

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
		{ name: 'app_source', label: 'Source', width: 90, dataType: 'text' },
		{ name: 'app_notes', label: 'Notes', width: 160, dataType: 'text' },
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
			<button
				on:click={runSeedPreview}
				disabled={seedLoading || $syncStatus.syncing}
				class="px-4 py-1.5 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700 disabled:opacity-50"
			>
				{#if seedLoading}
					Matching...
				{:else}
					Seed My Register
				{/if}
			</button>
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
								'app_source',
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
							{:else if column === 'app_source'}
								{@const source = str(value)}
								{@const lawName = str(row.name)}
								{#if source === 'screener'}
									<div class="flex items-center gap-1">
										<span class="px-1.5 py-0.5 text-xs rounded-full bg-violet-100 text-violet-700"
											>SertantAI</span
										>
										<button
											on:click={() => confirmLaw(lawName)}
											class="p-0.5 text-violet-400 hover:text-emerald-600 hover:bg-emerald-50 rounded"
											title="Confirm — transfer to your ownership"
										>
											<svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"
												><path
													stroke-linecap="round"
													stroke-linejoin="round"
													stroke-width="2"
													d="M5 13l4 4L19 7"
												/></svg
											>
										</button>
									</div>
								{:else if source === 'enhesa_import'}
									<span class="px-1.5 py-0.5 text-xs rounded-full bg-gray-100 text-gray-600"
										>Import</span
									>
								{:else}
									<span class="px-1.5 py-0.5 text-xs rounded-full bg-emerald-100 text-emerald-700"
										>Confirmed</span
									>
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

<!-- Seed Preview Modal -->
{#if seedPreview}
	<!-- svelte-ignore a11y-click-events-have-key-events -->
	<!-- svelte-ignore a11y-no-static-element-interactions -->
	<div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
		<div class="bg-white rounded-xl shadow-xl max-w-2xl w-full max-h-[80vh] flex flex-col">
			<div class="px-6 py-4 border-b border-gray-200">
				<h2 class="text-lg font-semibold text-gray-900">Seed Preview</h2>
				<p class="text-sm text-gray-500 mt-1">
					SertantAI found <strong>{seedPreview.length}</strong> laws matching your profile.
					{#if seedUncategorized && seedUncategorized.length > 0}
						Plus <strong>{seedUncategorized.length}</strong> uncategorized laws requiring manual review.
					{/if}
				</p>
				<div class="flex gap-4 mt-2">
					<span class="text-xs">
						<span class="inline-block w-2 h-2 rounded-full bg-emerald-500 mr-1"></span>
						Strong match (2+): {seedStrong}
					</span>
					<span class="text-xs">
						<span class="inline-block w-2 h-2 rounded-full bg-blue-500 mr-1"></span>
						Single match: {seedSingle}
					</span>
					{#if seedUncategorized && seedUncategorized.length > 0}
						<span class="text-xs">
							<span class="inline-block w-2 h-2 rounded-full bg-amber-500 mr-1"></span>
							Uncategorized: {seedUncategorized.length}
						</span>
					{/if}
				</div>
			</div>

			<div class="flex-1 overflow-auto px-6 py-3">
				<table class="w-full text-sm">
					<thead class="sticky top-0 bg-white">
						<tr class="text-left text-xs text-gray-500 border-b">
							<th class="pb-2 pr-3">Law</th>
							<th class="pb-2 pr-3">Family</th>
							<th class="pb-2 text-center">Score</th>
						</tr>
					</thead>
					<tbody>
						{#each seedPreview as law}
							<tr class="border-b border-gray-100 hover:bg-gray-50">
								<td class="py-1.5 pr-3">
									<div class="text-gray-900 text-xs">{law.title || law.name}</div>
									<div class="text-gray-400 text-xs font-mono">{law.name}</div>
								</td>
								<td class="py-1.5 pr-3 text-xs text-gray-600">{law.family || '-'}</td>
								<td class="py-1.5 text-center">
									{#if law.score >= 2}
										<span class="px-1.5 py-0.5 text-xs rounded-full bg-emerald-100 text-emerald-700"
											>{law.score}</span
										>
									{:else}
										<span class="px-1.5 py-0.5 text-xs rounded-full bg-blue-100 text-blue-700"
											>{law.score}</span
										>
									{/if}
								</td>
							</tr>
						{/each}
					</tbody>
				</table>

				{#if seedUncategorized && seedUncategorized.length > 0}
					<div class="mt-4 border-t border-gray-200 pt-3">
						<button
							on:click={() => (showUncategorized = !showUncategorized)}
							class="flex items-center gap-2 text-xs font-medium text-amber-700 hover:text-amber-800"
						>
							<svg
								class="w-3 h-3 transition-transform {showUncategorized ? 'rotate-90' : ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
								><path
									stroke-linecap="round"
									stroke-linejoin="round"
									stroke-width="2"
									d="M9 5l7 7-7 7"
								/></svg
							>
							Uncategorized — Requires Manual Review ({seedUncategorized.length})
						</button>
						<p class="text-xs text-gray-500 mt-1 ml-5">
							These laws have no fitness data. They are NOT seeded automatically — review them
							manually in the Available panel.
						</p>

						{#if showUncategorized}
							{@const grouped = groupByFamily(seedUncategorized)}
							<div class="mt-2 ml-5 space-y-2 max-h-48 overflow-auto">
								{#each grouped as [family, laws]}
									<div>
										<div class="text-xs font-medium text-amber-600">
											{family} ({laws.length})
										</div>
										<div class="ml-2 space-y-0.5">
											{#each laws as law}
												<div class="text-xs text-gray-600 truncate" title={law.name}>
													{law.title || law.name}
												</div>
											{/each}
										</div>
									</div>
								{/each}
							</div>
						{/if}
					</div>
				{/if}
			</div>

			<div class="px-6 py-4 border-t border-gray-200 flex items-center justify-between">
				<p class="text-xs text-gray-500">
					Laws will be added with source "SertantAI". You can confirm or remove them later.
				</p>
				<div class="flex gap-3">
					<button
						on:click={closeSeedPreview}
						class="px-4 py-2 text-sm text-gray-600 border border-gray-300 rounded-md hover:bg-gray-50"
					>
						Cancel
					</button>
					<button
						on:click={executeSeed}
						class="px-4 py-2 text-sm font-medium text-white bg-emerald-600 rounded-md hover:bg-emerald-700"
					>
						Add {seedPreview.length} laws to register
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
