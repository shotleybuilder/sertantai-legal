<script lang="ts">
	import {
		useCascadeIndexQuery,
		useCascadeSessionsQuery,
		useCascadeReparseMutation,
		useCascadeUpdateEnactingMutation,
		useCascadeAddLawsMutation,
		useDeleteCascadeEntryMutation,
		useClearProcessedCascadeMutation
	} from '$lib/query/scraper';
	import type { CascadeEntry, CascadeOperationResultItem } from '$lib/api/scraper';

	// Session filter state - defaults to 'all' to show all sessions
	let selectedSessionId: string | undefined = undefined;

	// Reactive query based on selected session
	$: cascadeQuery = useCascadeIndexQuery(selectedSessionId);
	const sessionsQuery = useCascadeSessionsQuery();

	// Mutations
	const reparseMutation = useCascadeReparseMutation();
	const updateEnactingMutation = useCascadeUpdateEnactingMutation();
	const addLawsMutation = useCascadeAddLawsMutation();
	const deleteEntryMutation = useDeleteCascadeEntryMutation();
	const clearProcessedMutation = useClearProcessedCascadeMutation();

	// Selection state for batch operations
	let selectedReparseInDb: Set<string> = new Set();
	let selectedReparseMissing: Set<string> = new Set();
	let selectedEnactingInDb: Set<string> = new Set();
	let selectedEnactingMissing: Set<string> = new Set();

	// Operation results state
	let operationResults: CascadeOperationResultItem[] | null = null;
	let operationMessage: string | null = null;

	// Helper to format session display
	function formatSession(session: {
		session_id: string;
		year: number | null;
		month: number | null;
		day_from: number | null;
		day_to: number | null;
	}): string {
		if (!session.year || !session.month) return session.session_id;
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
		const month = monthNames[session.month - 1];
		return `${month} ${session.day_from}-${session.day_to}, ${session.year}`;
	}

	// Toggle selection helpers
	function toggleSelection(set: Set<string>, id: string): Set<string> {
		const newSet = new Set(set);
		if (newSet.has(id)) {
			newSet.delete(id);
		} else {
			newSet.add(id);
		}
		return newSet;
	}

	function selectAll(entries: CascadeEntry[]): Set<string> {
		return new Set(entries.map((e) => e.id));
	}

	function clearSelection(): Set<string> {
		return new Set();
	}

	// Action handlers
	async function handleReparseInDb() {
		if (selectedReparseInDb.size === 0) return;
		operationResults = null;
		operationMessage = null;

		const result = await $reparseMutation.mutateAsync(Array.from(selectedReparseInDb));
		operationResults = result.results;
		operationMessage = `Re-parsed ${result.success} of ${result.total} laws`;
		selectedReparseInDb = new Set();
	}

	async function handleAddMissingLaws() {
		if (selectedReparseMissing.size === 0) return;
		operationResults = null;
		operationMessage = null;

		const result = await $addLawsMutation.mutateAsync(Array.from(selectedReparseMissing));
		operationResults = result.results;
		operationMessage = `Added ${result.success} of ${result.total} laws to database`;
		selectedReparseMissing = new Set();
	}

	async function handleUpdateEnacting() {
		if (selectedEnactingInDb.size === 0) return;
		operationResults = null;
		operationMessage = null;

		const result = await $updateEnactingMutation.mutateAsync(Array.from(selectedEnactingInDb));
		operationResults = result.results;
		operationMessage = `Updated enacting links for ${result.success} of ${result.total} laws`;
		selectedEnactingInDb = new Set();
	}

	async function handleAddEnactingMissing() {
		if (selectedEnactingMissing.size === 0) return;
		operationResults = null;
		operationMessage = null;

		const result = await $addLawsMutation.mutateAsync(Array.from(selectedEnactingMissing));
		operationResults = result.results;
		operationMessage = `Added ${result.success} of ${result.total} parent laws to database`;
		selectedEnactingMissing = new Set();
	}

	async function handleDeleteEntry(id: string) {
		if (confirm('Remove this cascade entry?')) {
			await $deleteEntryMutation.mutateAsync(id);
		}
	}

	async function handleClearProcessed() {
		if (confirm('Clear all processed cascade entries?')) {
			const result = await $clearProcessedMutation.mutateAsync(selectedSessionId);
			operationMessage = `Cleared ${result.deleted_count} processed entries`;
		}
	}

	function dismissResults() {
		operationResults = null;
		operationMessage = null;
	}

	function getStatusColor(status: string): string {
		switch (status) {
			case 'success':
				return 'text-green-700 bg-green-50';
			case 'error':
				return 'text-red-700 bg-red-50';
			case 'unchanged':
			case 'exists':
				return 'text-yellow-700 bg-yellow-50';
			case 'skipped':
				return 'text-gray-700 bg-gray-50';
			default:
				return 'text-gray-700 bg-gray-50';
		}
	}
</script>

<div>
	<div class="flex justify-between items-center mb-6">
		<h1 class="text-2xl font-bold text-gray-900">Cascade Updates</h1>
		<div class="flex items-center gap-4">
			<!-- Session filter -->
			<div class="flex items-center gap-2">
				<label for="session-filter" class="text-sm text-gray-600">Session:</label>
				<select
					id="session-filter"
					bind:value={selectedSessionId}
					class="block w-64 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 text-sm"
				>
					<option value={undefined}>All Sessions</option>
					{#if $sessionsQuery.data}
						{#each $sessionsQuery.data.sessions as session}
							<option value={session.session_id}>
								{formatSession(session)} ({session.pending_count} pending)
							</option>
						{/each}
					{/if}
				</select>
			</div>
			<a href="/admin/scrape/sessions" class="text-sm text-blue-600 hover:text-blue-800">
				Back to Sessions
			</a>
		</div>
	</div>

	<!-- Operation Results Banner -->
	{#if operationMessage || operationResults}
		<div class="mb-6 rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
			<div class="flex justify-between items-start">
				<div>
					{#if operationMessage}
						<p class="font-medium text-gray-900">{operationMessage}</p>
					{/if}
				</div>
				<button on:click={dismissResults} class="text-gray-400 hover:text-gray-600">
					<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
						<path
							stroke-linecap="round"
							stroke-linejoin="round"
							stroke-width="2"
							d="M6 18L18 6M6 6l12 12"
						/>
					</svg>
				</button>
			</div>
			{#if operationResults && operationResults.length > 0}
				<div class="mt-3 max-h-48 overflow-y-auto">
					<table class="min-w-full text-sm">
						<tbody class="divide-y divide-gray-100">
							{#each operationResults as result}
								<tr>
									<td class="py-1 pr-4 font-mono text-xs">{result.affected_law}</td>
									<td class="py-1 pr-4">
										<span
											class="inline-flex px-2 py-0.5 rounded text-xs font-medium {getStatusColor(
												result.status
											)}"
										>
											{result.status}
										</span>
									</td>
									<td class="py-1 text-gray-600">{result.message}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</div>
	{/if}

	{#if $cascadeQuery.isLoading}
		<div class="flex justify-center py-12">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
		</div>
	{:else if $cascadeQuery.isError}
		<div class="rounded-md bg-red-50 p-4">
			<p class="text-sm text-red-700">
				{$cascadeQuery.error?.message || 'Failed to load cascade data'}
			</p>
		</div>
	{:else if $cascadeQuery.data}
		{@const data = $cascadeQuery.data}

		<!-- Summary Stats -->
		<div class="grid grid-cols-5 gap-4 mb-6">
			<div class="bg-white rounded-lg shadow p-4">
				<div class="text-2xl font-bold text-gray-900">{data.summary.total_pending}</div>
				<div class="text-sm text-gray-500">Total Pending</div>
			</div>
			<div class="bg-white rounded-lg shadow p-4">
				<div class="text-2xl font-bold text-blue-600">{data.summary.reparse_in_db_count}</div>
				<div class="text-sm text-gray-500">Re-parse (in DB)</div>
			</div>
			<div class="bg-white rounded-lg shadow p-4">
				<div class="text-2xl font-bold text-orange-600">{data.summary.reparse_missing_count}</div>
				<div class="text-sm text-gray-500">New Laws to Add</div>
			</div>
			<div class="bg-white rounded-lg shadow p-4">
				<div class="text-2xl font-bold text-green-600">{data.summary.enacting_in_db_count}</div>
				<div class="text-sm text-gray-500">Enacting (in DB)</div>
			</div>
			<div class="bg-white rounded-lg shadow p-4">
				<div class="text-2xl font-bold text-purple-600">{data.summary.enacting_missing_count}</div>
				<div class="text-sm text-gray-500">Enacting (missing)</div>
			</div>
		</div>

		{#if data.summary.total_pending === 0}
			<div class="text-center py-12 bg-white rounded-lg shadow">
				<svg
					class="mx-auto h-12 w-12 text-green-400"
					fill="none"
					viewBox="0 0 24 24"
					stroke="currentColor"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
					/>
				</svg>
				<h3 class="mt-2 text-sm font-medium text-gray-900">All caught up!</h3>
				<p class="mt-1 text-sm text-gray-500">No pending cascade updates.</p>
			</div>
		{:else}
			<!-- Re-parse In DB Section -->
			{#if data.reparse_in_db.length > 0}
				<div class="bg-white rounded-lg shadow mb-6">
					<div class="px-4 py-3 border-b border-gray-200 flex justify-between items-center">
						<div>
							<h2 class="text-lg font-medium text-gray-900">Laws to Re-parse</h2>
							<p class="text-sm text-gray-500">
								These laws exist in the database and need re-parsing to update
								amendments/revocations
							</p>
						</div>
						<div class="flex items-center gap-2">
							<button
								on:click={() =>
									(selectedReparseInDb =
										selectedReparseInDb.size === data.reparse_in_db.length
											? clearSelection()
											: selectAll(data.reparse_in_db))}
								class="text-sm text-blue-600 hover:text-blue-800"
							>
								{selectedReparseInDb.size === data.reparse_in_db.length
									? 'Deselect All'
									: 'Select All'}
							</button>
							<button
								on:click={handleReparseInDb}
								disabled={selectedReparseInDb.size === 0 || $reparseMutation.isPending}
								class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
							>
								{#if $reparseMutation.isPending}
									<span class="animate-spin mr-1">...</span>
								{/if}
								Re-parse Selected ({selectedReparseInDb.size})
							</button>
						</div>
					</div>
					<div class="max-h-64 overflow-y-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50 sticky top-0">
								<tr>
									<th class="w-8 px-4 py-2"></th>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Law</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Title</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Year</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Source Laws</th
									>
									<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Actions</th
									>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each data.reparse_in_db as entry}
									<tr class="hover:bg-gray-50">
										<td class="px-4 py-2">
											<input
												type="checkbox"
												checked={selectedReparseInDb.has(entry.id)}
												on:change={() =>
													(selectedReparseInDb = toggleSelection(selectedReparseInDb, entry.id))}
												class="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
											/>
										</td>
										<td class="px-4 py-2 font-mono text-xs">{entry.affected_law}</td>
										<td
											class="px-4 py-2 text-sm text-gray-600 max-w-xs truncate"
											title={entry.title_en}>{entry.title_en || '-'}</td
										>
										<td class="px-4 py-2 text-sm">{entry.year || '-'}</td>
										<td class="px-4 py-2 text-xs text-gray-500">{entry.source_laws.join(', ')}</td>
										<td class="px-4 py-2 text-right">
											<button
												on:click={() => handleDeleteEntry(entry.id)}
												class="text-red-600 hover:text-red-800 text-sm"
											>
												Remove
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}

			<!-- New Laws to Add Section -->
			{#if data.reparse_missing.length > 0}
				<div class="bg-white rounded-lg shadow mb-6 border-l-4 border-orange-400">
					<div class="px-4 py-3 border-b border-gray-200 flex justify-between items-center">
						<div>
							<h2 class="text-lg font-medium text-gray-900">New Laws to Add</h2>
							<p class="text-sm text-gray-500">
								These laws were discovered via cascade but don't exist in the database yet
							</p>
						</div>
						<div class="flex items-center gap-2">
							<button
								on:click={() =>
									(selectedReparseMissing =
										selectedReparseMissing.size === data.reparse_missing.length
											? clearSelection()
											: selectAll(data.reparse_missing))}
								class="text-sm text-orange-600 hover:text-orange-800"
							>
								{selectedReparseMissing.size === data.reparse_missing.length
									? 'Deselect All'
									: 'Select All'}
							</button>
							<button
								on:click={handleAddMissingLaws}
								disabled={selectedReparseMissing.size === 0 || $addLawsMutation.isPending}
								class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-orange-600 hover:bg-orange-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
							>
								{#if $addLawsMutation.isPending}
									<span class="animate-spin mr-1">...</span>
								{/if}
								Add to Database ({selectedReparseMissing.size})
							</button>
						</div>
					</div>
					<div class="max-h-64 overflow-y-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50 sticky top-0">
								<tr>
									<th class="w-8 px-4 py-2"></th>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Law</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Source Laws</th
									>
									<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Actions</th
									>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each data.reparse_missing as entry}
									<tr class="hover:bg-gray-50">
										<td class="px-4 py-2">
											<input
												type="checkbox"
												checked={selectedReparseMissing.has(entry.id)}
												on:change={() =>
													(selectedReparseMissing = toggleSelection(
														selectedReparseMissing,
														entry.id
													))}
												class="rounded border-gray-300 text-orange-600 focus:ring-orange-500"
											/>
										</td>
										<td class="px-4 py-2 font-mono text-xs">{entry.affected_law}</td>
										<td class="px-4 py-2 text-xs text-gray-500">{entry.source_laws.join(', ')}</td>
										<td class="px-4 py-2 text-right">
											<button
												on:click={() => handleDeleteEntry(entry.id)}
												class="text-red-600 hover:text-red-800 text-sm"
											>
												Remove
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}

			<!-- Enacting In DB Section -->
			{#if data.enacting_in_db.length > 0}
				<div class="bg-white rounded-lg shadow mb-6">
					<div class="px-4 py-3 border-b border-gray-200 flex justify-between items-center">
						<div>
							<h2 class="text-lg font-medium text-gray-900">Parent Laws - Update Enacting</h2>
							<p class="text-sm text-gray-500">
								These parent laws need their enacting arrays updated with new child laws
							</p>
						</div>
						<div class="flex items-center gap-2">
							<button
								on:click={() =>
									(selectedEnactingInDb =
										selectedEnactingInDb.size === data.enacting_in_db.length
											? clearSelection()
											: selectAll(data.enacting_in_db))}
								class="text-sm text-green-600 hover:text-green-800"
							>
								{selectedEnactingInDb.size === data.enacting_in_db.length
									? 'Deselect All'
									: 'Select All'}
							</button>
							<button
								on:click={handleUpdateEnacting}
								disabled={selectedEnactingInDb.size === 0 || $updateEnactingMutation.isPending}
								class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-green-600 hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
							>
								{#if $updateEnactingMutation.isPending}
									<span class="animate-spin mr-1">...</span>
								{/if}
								Update Enacting ({selectedEnactingInDb.size})
							</button>
						</div>
					</div>
					<div class="max-h-64 overflow-y-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50 sticky top-0">
								<tr>
									<th class="w-8 px-4 py-2"></th>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Parent Law</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Title</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Current Count</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>New Children</th
									>
									<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Actions</th
									>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each data.enacting_in_db as entry}
									<tr class="hover:bg-gray-50">
										<td class="px-4 py-2">
											<input
												type="checkbox"
												checked={selectedEnactingInDb.has(entry.id)}
												on:change={() =>
													(selectedEnactingInDb = toggleSelection(selectedEnactingInDb, entry.id))}
												class="rounded border-gray-300 text-green-600 focus:ring-green-500"
											/>
										</td>
										<td class="px-4 py-2 font-mono text-xs">{entry.affected_law}</td>
										<td
											class="px-4 py-2 text-sm text-gray-600 max-w-xs truncate"
											title={entry.title_en}>{entry.title_en || '-'}</td
										>
										<td class="px-4 py-2 text-sm">{entry.current_enacting_count || 0}</td>
										<td class="px-4 py-2 text-xs text-gray-500">{entry.source_laws.join(', ')}</td>
										<td class="px-4 py-2 text-right">
											<button
												on:click={() => handleDeleteEntry(entry.id)}
												class="text-red-600 hover:text-red-800 text-sm"
											>
												Remove
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}

			<!-- Enacting Missing Section -->
			{#if data.enacting_missing.length > 0}
				<div class="bg-white rounded-lg shadow mb-6 border-l-4 border-purple-400">
					<div class="px-4 py-3 border-b border-gray-200 flex justify-between items-center">
						<div>
							<h2 class="text-lg font-medium text-gray-900">Parent Laws - Not in Database</h2>
							<p class="text-sm text-gray-500">
								These parent laws need to be added to the database first
							</p>
						</div>
						<div class="flex items-center gap-2">
							<button
								on:click={() =>
									(selectedEnactingMissing =
										selectedEnactingMissing.size === data.enacting_missing.length
											? clearSelection()
											: selectAll(data.enacting_missing))}
								class="text-sm text-purple-600 hover:text-purple-800"
							>
								{selectedEnactingMissing.size === data.enacting_missing.length
									? 'Deselect All'
									: 'Select All'}
							</button>
							<button
								on:click={handleAddEnactingMissing}
								disabled={selectedEnactingMissing.size === 0 || $addLawsMutation.isPending}
								class="inline-flex items-center px-3 py-1.5 border border-transparent text-sm font-medium rounded-md text-white bg-purple-600 hover:bg-purple-700 disabled:bg-gray-300 disabled:cursor-not-allowed"
							>
								{#if $addLawsMutation.isPending}
									<span class="animate-spin mr-1">...</span>
								{/if}
								Add to Database ({selectedEnactingMissing.size})
							</button>
						</div>
					</div>
					<div class="max-h-64 overflow-y-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50 sticky top-0">
								<tr>
									<th class="w-8 px-4 py-2"></th>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>Parent Law</th
									>
									<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase"
										>New Children</th
									>
									<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase"
										>Actions</th
									>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each data.enacting_missing as entry}
									<tr class="hover:bg-gray-50">
										<td class="px-4 py-2">
											<input
												type="checkbox"
												checked={selectedEnactingMissing.has(entry.id)}
												on:change={() =>
													(selectedEnactingMissing = toggleSelection(
														selectedEnactingMissing,
														entry.id
													))}
												class="rounded border-gray-300 text-purple-600 focus:ring-purple-500"
											/>
										</td>
										<td class="px-4 py-2 font-mono text-xs">{entry.affected_law}</td>
										<td class="px-4 py-2 text-xs text-gray-500">{entry.source_laws.join(', ')}</td>
										<td class="px-4 py-2 text-right">
											<button
												on:click={() => handleDeleteEntry(entry.id)}
												class="text-red-600 hover:text-red-800 text-sm"
											>
												Remove
											</button>
										</td>
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				</div>
			{/if}

			<!-- Footer Actions -->
			<div class="flex justify-end">
				<button
					on:click={handleClearProcessed}
					disabled={$clearProcessedMutation.isPending}
					class="text-sm text-gray-600 hover:text-gray-800"
				>
					Clear Processed Entries
				</button>
			</div>
		{/if}
	{/if}
</div>
