<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/state';
	import { goto } from '$app/navigation';
	import { startSync, syncStatus } from '$lib/pglite/sync';
	import { getPglite } from '$lib/pglite/client';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// ── Types ──────────────────────────────────────────────────────

	interface LawRow {
		name: string;
		title_en: string;
		year: number;
		family: string;
		def_count: number;
		cross_ref_count: number;
		linked_count: number;
	}

	interface DefinitionRow {
		id: string;
		term: string;
		definition: string;
		section_id: string | null;
		scope: string | null;
		references_other_law: boolean;
		citation: boolean;
		referenced_law_citation: string | null;
		is_linked: boolean;
	}

	interface RootDefinition {
		term: string;
		definition: string;
		law_name: string;
		law_title: string;
		section_id: string | null;
	}

	// ── State ──────────────────────────────────────────────────────

	let families: string[] = $state([]);
	let laws: LawRow[] = $state([]);
	let definitions: DefinitionRow[] = $state([]);
	let loading = $state(true);
	let defsLoading = $state(false);

	// URL-driven state
	let selectedFamily: string = $state('');
	let selectedLaw: string = $state('');
	let lawSearch: string = $state('');

	// Detail panel state
	let selectedDef: DefinitionRow | null = $state(null);
	let rootDefs: RootDefinition[] = $state([]);
	let rootLoading = $state(false);

	// Reparse state
	let reparsing = $state(false);
	let reparseMsg = $state('');

	async function triggerReparse() {
		if (!selectedLaw) return;
		reparsing = true;
		reparseMsg = '';
		try {
			const res = await authFetch(`${API_URL}/api/definitions/admin/parse`, {
				method: 'POST',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify({ law_name: selectedLaw })
			});
			if (!res.ok) throw new Error(`Parse API returned ${res.status}`);
			reparseMsg = 'Parse started — definitions will update after sync.';
		} catch (e) {
			reparseMsg = e instanceof Error ? e.message : 'Parse failed';
		} finally {
			reparsing = false;
		}
	}

	// Read initial state from URL
	$effect(() => {
		if (browser) {
			const urlFamily = page.url.searchParams.get('family');
			const urlLaw = page.url.searchParams.get('law');
			if (urlFamily && !selectedFamily) selectedFamily = urlFamily;
			if (urlLaw && !selectedLaw) selectedLaw = urlLaw;
		}
	});

	// ── Filtered laws ──────────────────────────────────────────────

	let filteredLaws = $derived(
		laws.filter((l) => {
			if (selectedFamily && l.family !== selectedFamily) return false;
			if (lawSearch) {
				const q = lawSearch.toLowerCase();
				return l.title_en?.toLowerCase().includes(q) || l.name.toLowerCase().includes(q);
			}
			return true;
		})
	);

	// ── Data loading ───────────────────────────────────────────────

	onMount(async () => {
		if (!browser) return;
		await startSync();
		loadData();
	});

	// Re-run when sync delivers data (laws or definitions may arrive at different times)
	$effect(() => {
		if (!$syncStatus.syncing && $syncStatus.recordCount > 0) {
			loadData();
		}
	});

	async function loadData() {
		try {
			const pg = await getPglite();

			// Get families that have definitions
			const famRes = await pg.query<{ family: string }>(
				`SELECT DISTINCT l.family
				 FROM definitions d
				 JOIN laws l ON l.name = d.law_name
				 WHERE l.family IS NOT NULL
				 ORDER BY l.family`
			);
			families = famRes.rows.map((r) => r.family);

			// Get laws with definition counts
			const lawRes = await pg.query<LawRow>(
				`SELECT
					l.name,
					l.title_en,
					l.year,
					l.family,
					COUNT(*)::int AS def_count,
					COUNT(*) FILTER (WHERE d.references_other_law = true AND d.citation = false)::int AS cross_ref_count,
					(SELECT COUNT(DISTINCT dl.child_definition_id)::int
					 FROM definition_links dl
					 JOIN definitions dd ON dd.id = dl.child_definition_id
					 WHERE dd.law_name = l.name
					   AND dd.references_other_law = true
					   AND dd.citation = false
					) AS linked_count
				 FROM definitions d
				 JOIN laws l ON l.name = d.law_name
				 WHERE l.family IS NOT NULL
				 GROUP BY l.name, l.title_en, l.year, l.family
				 ORDER BY l.family, l.title_en`
			);
			laws = lawRes.rows;

			// If a law is already selected (from URL), load its definitions
			if (selectedLaw) {
				await loadDefinitions(selectedLaw);
			}
		} catch (e) {
			console.error('[Definitions Browse] Load error:', e);
		} finally {
			loading = false;
		}
	}

	async function loadDefinitions(lawName: string) {
		defsLoading = true;
		try {
			const pg = await getPglite();
			const res = await pg.query<DefinitionRow>(
				`SELECT
					d.id,
					d.term,
					d.definition,
					d.section_id,
					d.scope,
					d.references_other_law,
					d.citation,
					d.referenced_law_citation,
					EXISTS(SELECT 1 FROM definition_links dl WHERE dl.child_definition_id = d.id) AS is_linked
				 FROM definitions d
				 WHERE d.law_name = $1
				 ORDER BY d.term`,
				[lawName]
			);
			definitions = res.rows;
		} catch (e) {
			console.error('[Definitions Browse] Definitions load error:', e);
		} finally {
			defsLoading = false;
		}
	}

	async function selectDefinition(def: DefinitionRow) {
		if (selectedDef?.id === def.id) {
			selectedDef = null;
			rootDefs = [];
			return;
		}
		selectedDef = def;
		rootDefs = [];

		if (def.is_linked) {
			rootLoading = true;
			try {
				const pg = await getPglite();
				const res = await pg.query<RootDefinition>(
					`SELECT
						d.term,
						d.definition,
						d.law_name,
						COALESCE(l.title_en, d.law_name) AS law_title,
						d.section_id
					 FROM definition_links dl
					 JOIN definitions d ON d.id = dl.root_definition_id
					 LEFT JOIN laws l ON l.name = d.law_name
					 WHERE dl.child_definition_id = $1`,
					[def.id]
				);
				rootDefs = res.rows;
			} catch (e) {
				console.error('[Definitions Browse] Root lookup error:', e);
			} finally {
				rootLoading = false;
			}
		}
	}

	function lawSourceUrl(lawName: string): string {
		const path = lawName.replace(/^UK_/, '').replace(/_/g, '/');
		return `https://www.legislation.gov.uk/${path}`;
	}

	function selectLaw(lawName: string) {
		selectedLaw = lawName;
		selectedDef = null;
		rootDefs = [];
		updateUrl();
		loadDefinitions(lawName);
	}

	function selectFamily(family: string) {
		selectedFamily = family;
		selectedLaw = '';
		definitions = [];
		updateUrl();
	}

	function updateUrl() {
		const params = new URLSearchParams();
		if (selectedFamily) params.set('family', selectedFamily);
		if (selectedLaw) params.set('law', selectedLaw);
		const qs = params.toString();
		goto(`/admin/definitions/browse${qs ? '?' + qs : ''}`, { replaceState: true });
	}

	// ── Helpers ────────────────────────────────────────────────────

	function defType(d: DefinitionRow): string {
		if (d.citation) return 'citation';
		if (d.references_other_law) return 'cross-ref';
		return 'substantive';
	}

	function defTypeClass(d: DefinitionRow): string {
		if (d.citation) return 'bg-purple-50 text-purple-700';
		if (d.references_other_law) return 'bg-blue-50 text-blue-700';
		return 'bg-gray-50 text-gray-600';
	}

	function linkStatus(d: DefinitionRow): string {
		if (!d.references_other_law || d.citation) return '';
		if (d.is_linked) return 'linked';
		if (d.referenced_law_citation) return 'citation only';
		return 'unlinked';
	}

	function linkStatusClass(d: DefinitionRow): string {
		if (!d.references_other_law || d.citation) return '';
		if (d.is_linked) return 'text-green-700';
		if (d.referenced_law_citation) return 'text-amber-600';
		return 'text-red-600';
	}

	function truncate(text: string | null, len: number): string {
		if (!text) return '';
		return text.length > len ? text.slice(0, len) + '...' : text;
	}

	function selectedLawTitle(): string {
		const law = laws.find((l) => l.name === selectedLaw);
		return law?.title_en || selectedLaw;
	}
</script>

<svelte:head>
	<title>Definitions Browser — SertantAI Legal</title>
</svelte:head>

<div class="flex h-[calc(100vh-10rem)] flex-col gap-4">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<h1 class="text-2xl font-bold text-gray-900">Definitions Browser</h1>
		<div class="flex items-center gap-2">
			<select
				value={selectedFamily}
				onchange={(e) => selectFamily(e.currentTarget.value)}
				class="rounded-md border border-gray-300 bg-white px-3 py-1.5 text-sm text-gray-700 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
			>
				<option value="">All Families</option>
				{#each families as fam}
					<option value={fam}>{fam}</option>
				{/each}
			</select>
		</div>
	</div>

	{#if loading}
		<div class="py-12 text-center text-gray-500">Loading definitions...</div>
	{:else}
		<!-- Split pane -->
		<div class="flex min-h-0 flex-1 gap-4">
			<!-- Left: Law list -->
			<div
				class="flex w-80 flex-shrink-0 flex-col overflow-hidden rounded-lg border border-gray-200 bg-white"
			>
				<div class="border-b border-gray-200 p-2">
					<input
						type="text"
						bind:value={lawSearch}
						placeholder="Search laws..."
						class="w-full rounded-md border border-gray-300 px-3 py-1.5 text-sm focus:border-blue-500 focus:outline-none focus:ring-1 focus:ring-blue-500"
					/>
				</div>
				<div class="flex-1 overflow-y-auto">
					{#each filteredLaws as law (law.name)}
						<button
							class="w-full border-b border-gray-100 px-3 py-2 text-left hover:bg-gray-50
								{selectedLaw === law.name ? 'bg-blue-50 border-l-2 border-l-blue-500' : ''}"
							onclick={() => selectLaw(law.name)}
						>
							<div class="text-sm font-medium text-gray-900 leading-tight">
								{truncate(law.title_en, 60)}
							</div>
							<div class="mt-0.5 flex items-center gap-2 text-xs text-gray-500">
								<span>{law.year}</span>
								<span>{law.def_count} defs</span>
								{#if law.cross_ref_count > 0}
									<span
										class="rounded px-1 {law.linked_count === law.cross_ref_count
											? 'bg-green-50 text-green-700'
											: 'bg-amber-50 text-amber-700'}"
									>
										{law.linked_count}/{law.cross_ref_count} linked
									</span>
								{/if}
							</div>
						</button>
					{/each}
					{#if filteredLaws.length === 0}
						<div class="px-3 py-8 text-center text-sm text-gray-400">No laws found</div>
					{/if}
				</div>
				<div class="border-t border-gray-200 px-3 py-1.5 text-xs text-gray-400">
					{filteredLaws.length} laws
				</div>
			</div>

			<!-- Right: Definitions table -->
			<div
				class="flex min-w-0 flex-1 flex-col overflow-hidden rounded-lg border border-gray-200 bg-white"
			>
				{#if !selectedLaw}
					<div class="flex flex-1 items-center justify-center text-sm text-gray-400">
						Select a law from the list to view its definitions
					</div>
				{:else if defsLoading}
					<div class="flex flex-1 items-center justify-center text-sm text-gray-400">
						Loading definitions...
					</div>
				{:else}
					<!-- Law header -->
					<div class="flex items-center justify-between border-b border-gray-200 px-4 py-2">
						<div>
							<div class="text-sm font-semibold text-gray-900">{selectedLawTitle()}</div>
							<div class="text-xs text-gray-500">
								{selectedLaw} — {definitions.length} definitions
							</div>
						</div>
						<button
							onclick={triggerReparse}
							disabled={reparsing}
							class="rounded-md border border-gray-300 bg-white px-2.5 py-1 text-xs font-medium text-gray-700 hover:bg-gray-50 disabled:opacity-50"
						>
							{reparsing ? 'Parsing...' : 'Reparse'}
						</button>
					</div>
					{#if reparseMsg}
						<div class="border-b border-gray-200 bg-blue-50 px-4 py-1.5 text-xs text-blue-700">
							{reparseMsg}
						</div>
					{/if}

					<!-- Definitions table -->
					<div class="flex-1 overflow-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="sticky top-0 bg-gray-50">
								<tr>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Term
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Definition
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Section
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Type
									</th>
									<th
										class="px-3 py-2 text-left text-xs font-medium uppercase tracking-wider text-gray-500"
									>
										Status
									</th>
								</tr>
							</thead>
							<tbody class="divide-y divide-gray-200">
								{#each definitions as def (def.id)}
									<tr
										class="cursor-pointer hover:bg-gray-50 {selectedDef?.id === def.id
											? 'bg-blue-50'
											: ''}"
										onclick={() => selectDefinition(def)}
									>
										<td class="whitespace-nowrap px-3 py-1.5 text-sm font-medium text-gray-900">
											{def.term}
										</td>
										<td
											class="max-w-md whitespace-pre-line px-3 py-1.5 text-sm text-gray-600"
											title={def.definition}
										>
											{truncate(def.definition, 80)}
										</td>
										<td class="whitespace-nowrap px-3 py-1.5 text-xs text-gray-500">
											{def.section_id || ''}
										</td>
										<td class="whitespace-nowrap px-3 py-1.5">
											<span
												class="inline-block rounded px-1.5 py-0.5 text-xs font-medium {defTypeClass(
													def
												)}"
											>
												{defType(def)}
											</span>
										</td>
										<td class="whitespace-nowrap px-3 py-1.5 text-xs {linkStatusClass(def)}">
											{linkStatus(def)}
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			</div>
		</div>

		<!-- Detail panel -->
		{#if selectedDef}
			<div class="flex-shrink-0 rounded-lg border border-blue-200 bg-white p-4">
				<div class="flex items-start justify-between">
					<h3 class="text-sm font-semibold text-gray-900">
						{selectedDef.term}
					</h3>
					<button
						class="text-xs text-gray-400 hover:text-gray-600"
						onclick={() => {
							selectedDef = null;
							rootDefs = [];
						}}
					>
						Close
					</button>
				</div>

				<!-- Full definition text -->
				<p class="mt-2 whitespace-pre-line text-sm text-gray-700">{selectedDef.definition}</p>

				<!-- Metadata -->
				<div class="mt-3 flex flex-wrap gap-3 text-xs text-gray-500">
					{#if selectedDef.section_id}
						<span>Section: {selectedDef.section_id}</span>
					{/if}
					{#if selectedDef.scope}
						<span>Scope: {selectedDef.scope}</span>
					{/if}
					<span
						>Type: <span class="font-medium {defTypeClass(selectedDef)}"
							>{defType(selectedDef)}</span
						></span
					>
					{#if selectedDef.references_other_law && !selectedDef.citation}
						<span
							>Status: <span class="font-medium {linkStatusClass(selectedDef)}"
								>{linkStatus(selectedDef)}</span
							></span
						>
					{/if}
					<a
						href={lawSourceUrl(selectedLaw)}
						target="_blank"
						rel="noopener noreferrer"
						class="text-blue-600 hover:text-blue-800"
					>
						legislation.gov.uk
					</a>
				</div>

				<!-- Citation info for cross-refs -->
				{#if selectedDef.references_other_law && !selectedDef.citation && selectedDef.referenced_law_citation}
					<div class="mt-3 rounded border border-gray-200 bg-gray-50 px-3 py-2">
						<div class="text-xs font-medium text-gray-500">Extracted Citation</div>
						<div class="text-sm text-gray-700">{selectedDef.referenced_law_citation}</div>
					</div>
				{/if}

				<!-- Root definitions (linked cross-refs) -->
				{#if rootLoading}
					<div class="mt-3 text-xs text-gray-400">Loading root definitions...</div>
				{:else if rootDefs.length > 0}
					<div class="mt-3 space-y-2">
						<div class="text-xs font-medium text-gray-500">
							Root Definition{rootDefs.length > 1 ? 's' : ''}
						</div>
						{#each rootDefs as root}
							<div class="rounded border border-green-200 bg-green-50 px-3 py-2">
								<div class="flex items-center gap-2">
									<span class="text-sm font-medium text-green-800">{root.term}</span>
									<span class="text-xs text-green-600">
										{root.law_title}
										{#if root.section_id}({root.section_id}){/if}
									</span>
								</div>
								<p class="mt-1 whitespace-pre-line text-sm text-green-700">{root.definition}</p>
								<a
									href={lawSourceUrl(root.law_name)}
									target="_blank"
									rel="noopener noreferrer"
									class="mt-1 inline-block text-xs text-blue-600 hover:text-blue-800"
								>
									View on legislation.gov.uk
								</a>
							</div>
						{/each}
					</div>
				{:else if selectedDef.is_linked}
					<div class="mt-3 text-xs text-amber-600">
						Linked but root definition not found in local sync
					</div>
				{/if}
			</div>
		{/if}
	{/if}
</div>
