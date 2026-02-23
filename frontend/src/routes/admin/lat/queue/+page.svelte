<script lang="ts">
	import { useLatQueueQuery, useReparseMutation } from '$lib/query/lat';
	import { useQueryClient } from '@tanstack/svelte-query';
	import type { QueueItem } from '$lib/api/lat';

	const queryClient = useQueryClient();

	// ── State ────────────────────────────────────────────────────────

	let reasonFilter: 'missing' | 'stale' | undefined = undefined;
	let limit = 50;
	let offset = 0;

	// Reparse tracking
	let reparsingLaw: string | null = null;
	let reparseMessage = '';
	let reparseError = '';

	// ── Queries ──────────────────────────────────────────────────────

	$: queueQuery = useLatQueueQuery(limit, offset, reasonFilter);
	$: reparseMutation = useReparseMutation();

	// ── Derived ──────────────────────────────────────────────────────

	$: data = $queueQuery?.data;
	$: items = data?.items ?? [];
	$: total = data?.total ?? 0;
	$: missingCount = data?.missing_count ?? 0;
	$: staleCount = data?.stale_count ?? 0;
	$: filteredTotal = data?.filtered_total ?? 0;
	$: hasMore = data?.has_more ?? false;
	$: currentPage = Math.floor(offset / limit) + 1;
	$: totalPages = Math.ceil(filteredTotal / limit);

	// ── Filter ───────────────────────────────────────────────────────

	function setFilter(reason: 'missing' | 'stale' | undefined) {
		reasonFilter = reason;
		offset = 0;
	}

	// ── Pagination ──────────────────────────────────────────────────

	function nextPage() {
		offset += limit;
	}

	function prevPage() {
		offset = Math.max(0, offset - limit);
	}

	// ── Re-parse ────────────────────────────────────────────────────

	function handleReparse(item: QueueItem) {
		reparsingLaw = item.law_name;
		reparseMessage = '';
		reparseError = '';

		$reparseMutation.mutate(item.law_name, {
			onSuccess: (result) => {
				reparsingLaw = null;
				reparseMessage = `Re-parsed ${item.law_name}: ${result.lat.inserted} LAT rows, ${result.annotations.inserted} annotations (${result.duration_ms}ms)`;
				queryClient.invalidateQueries({ queryKey: ['lat', 'queue'] });
			},
			onError: (error) => {
				reparsingLaw = null;
				reparseError = `Failed to re-parse ${item.law_name}: ${error.message}`;
			}
		});
	}

	// ── Formatting ──────────────────────────────────────────────────

	function formatDate(iso: string | null): string {
		if (!iso) return '--';
		return new Date(iso).toLocaleDateString('en-GB', {
			day: '2-digit',
			month: 'short',
			year: 'numeric'
		});
	}

	function formatNumber(n: number): string {
		return n.toLocaleString();
	}
</script>

<svelte:head>
	<title>LAT Queue — SertantAI Legal</title>
</svelte:head>

<div class="space-y-6">
	<!-- Header -->
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">LAT Parse Queue</h1>
			<p class="mt-1 text-sm text-gray-500">
				LRT records with making function that need LAT parsing or re-parsing.
			</p>
		</div>
		<a href="/admin/lat" class="text-sm text-gray-500 hover:text-gray-700">&larr; LAT Data</a>
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
	{#if data}
		<div class="grid grid-cols-3 gap-4">
			<button
				on:click={() => setFilter(undefined)}
				class="bg-white rounded-lg border p-4 text-left transition-colors
					{reasonFilter === undefined
					? 'border-blue-500 ring-1 ring-blue-500'
					: 'border-gray-200 hover:border-gray-300'}"
			>
				<div class="text-sm text-gray-500">Total Queue</div>
				<div class="text-2xl font-bold text-gray-900">{formatNumber(total)}</div>
			</button>
			<button
				on:click={() => setFilter('missing')}
				class="bg-white rounded-lg border p-4 text-left transition-colors
					{reasonFilter === 'missing'
					? 'border-red-500 ring-1 ring-red-500'
					: 'border-gray-200 hover:border-gray-300'}"
			>
				<div class="text-sm text-gray-500">Missing LAT</div>
				<div class="text-2xl font-bold text-red-600">{formatNumber(missingCount)}</div>
			</button>
			<button
				on:click={() => setFilter('stale')}
				class="bg-white rounded-lg border p-4 text-left transition-colors
					{reasonFilter === 'stale'
					? 'border-amber-500 ring-1 ring-amber-500'
					: 'border-gray-200 hover:border-gray-300'}"
			>
				<div class="text-sm text-gray-500">Stale LAT</div>
				<div class="text-2xl font-bold text-amber-600">{formatNumber(staleCount)}</div>
			</button>
		</div>
	{/if}

	<!-- Table -->
	{#if $queueQuery?.isLoading}
		<div class="text-center py-12 text-gray-500">Loading queue...</div>
	{:else if items.length === 0}
		<div class="text-center py-12 text-gray-500">
			{#if reasonFilter}
				No {reasonFilter} records in queue.
			{:else}
				No records in queue. All making laws have up-to-date LAT data.
			{/if}
		</div>
	{:else}
		<div class="bg-white rounded-lg border border-gray-200 overflow-hidden">
			<div class="px-4 py-2 bg-gray-50 border-b border-gray-200 flex items-center justify-between">
				<span class="text-xs text-gray-500">
					Showing {offset + 1}–{Math.min(offset + items.length, filteredTotal)} of {formatNumber(filteredTotal)}
					{#if reasonFilter}({reasonFilter}){/if}
				</span>
				<span class="text-xs text-gray-400">Oldest first</span>
			</div>
			<div class="overflow-x-auto">
				<table class="min-w-full divide-y divide-gray-200">
					<thead class="bg-gray-50">
						<tr>
							<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Law Name
							</th>
							<th class="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
								Title
							</th>
							<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
								Year
							</th>
							<th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
								Type
							</th>
							<th class="px-4 py-2 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
								Reason
							</th>
							<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
								LAT Rows
							</th>
							<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
								LRT Updated
							</th>
							<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
								LAT Updated
							</th>
							<th class="px-4 py-2 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
								Actions
							</th>
						</tr>
					</thead>
					<tbody class="bg-white divide-y divide-gray-200">
						{#each items as item (item.law_id)}
							<tr class="hover:bg-gray-50 transition-colors">
								<td class="px-4 py-2 text-sm font-mono text-gray-700 whitespace-nowrap">
									{item.law_name}
								</td>
								<td class="px-4 py-2 text-sm text-gray-900 max-w-xs truncate" title={item.title_en}>
									{item.title_en}
								</td>
								<td class="px-4 py-2 text-sm text-gray-600 text-right">{item.year}</td>
								<td class="px-4 py-2 text-sm text-center">
									<span class="px-1.5 py-0.5 rounded text-xs bg-gray-100 text-gray-600">
										{item.type_code}
									</span>
								</td>
								<td class="px-4 py-2 text-center">
									{#if item.queue_reason === 'missing'}
										<span class="px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-700">
											missing
										</span>
									{:else}
										<span class="px-2 py-0.5 rounded-full text-xs font-medium bg-amber-100 text-amber-700">
											stale
										</span>
									{/if}
								</td>
								<td class="px-4 py-2 text-sm text-gray-600 text-right font-mono">
									{item.lat_count}
								</td>
								<td class="px-4 py-2 text-sm text-gray-600 text-right whitespace-nowrap">
									{formatDate(item.lrt_updated_at)}
								</td>
								<td class="px-4 py-2 text-sm text-gray-600 text-right whitespace-nowrap">
									{formatDate(item.latest_lat_updated_at)}
								</td>
								<td class="px-4 py-2 text-right">
									<button
										on:click={() => handleReparse(item)}
										disabled={reparsingLaw === item.law_name}
										class="px-2.5 py-1 text-xs font-medium rounded-md transition-colors
											{reparsingLaw === item.law_name
											? 'bg-gray-100 text-gray-400 cursor-not-allowed'
											: 'bg-blue-600 text-white hover:bg-blue-700'}"
									>
										{#if reparsingLaw === item.law_name}
											Parsing...
										{:else}
											Re-parse
										{/if}
									</button>
								</td>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>

			<!-- Pagination -->
			<div class="px-4 py-3 border-t border-gray-200 bg-gray-50 flex items-center justify-between">
				<button
					on:click={prevPage}
					disabled={offset === 0}
					class="px-3 py-1.5 text-sm font-medium rounded-md transition-colors
						{offset === 0
						? 'text-gray-400 cursor-not-allowed'
						: 'text-blue-600 hover:bg-blue-50'}"
				>
					&larr; Previous
				</button>
				<span class="text-xs text-gray-500">
					Page {currentPage} of {totalPages}
				</span>
				<button
					on:click={nextPage}
					disabled={!hasMore}
					class="px-3 py-1.5 text-sm font-medium rounded-md transition-colors
						{!hasMore
						? 'text-gray-400 cursor-not-allowed'
						: 'text-blue-600 hover:bg-blue-50'}"
				>
					Next &rarr;
				</button>
			</div>
		</div>
	{/if}
</div>
