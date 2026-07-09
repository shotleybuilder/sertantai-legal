<script lang="ts">
	import { page } from '$app/stores';
	import { goto } from '$app/navigation';
	import {
		useLatSessionQuery,
		useLatSessionRecordsQuery,
		useUpdateLatSelectionMutation,
		useDeleteLatSessionMutation
	} from '$lib/query/lat';
	import type { LatSessionRecord } from '$lib/api/lat';
	import LatParseReviewModal from '$lib/components/LatParseReviewModal.svelte';

	$: sessionId = $page.params.id ?? '';

	$: sessionQuery = useLatSessionQuery(sessionId);
	$: recordsQuery = useLatSessionRecordsQuery(sessionId);
	const selectionMutation = useUpdateLatSelectionMutation();
	const deleteMutation = useDeleteLatSessionMutation();

	// Modal state
	let showModal = false;
	let modalAutoConfirm = false;
	let modalRecords: LatSessionRecord[] = [];
	let modalInitialIndex = 0;

	// Selection helpers
	$: records = $recordsQuery.data?.records ?? [];
	$: selectedRecords = records.filter((r) => r.selected);
	$: pendingRecords = records.filter((r) => r.status === 'pending' || r.status === 'ready');
	$: parsedRecords = records.filter((r) => r.status === 'parsed' || r.status === 'confirmed');
	$: failedRecords = records.filter((r) => r.status === 'skipped');

	function statusColor(status: string): string {
		switch (status) {
			case 'confirmed':
				return 'bg-green-100 text-green-800';
			case 'parsed':
				return 'bg-blue-100 text-blue-800';
			case 'skipped':
				return 'bg-red-100 text-red-800';
			case 'pending':
			case 'ready':
				return 'bg-gray-100 text-gray-800';
			default:
				return 'bg-gray-100 text-gray-800';
		}
	}

	async function toggleSelect(record: LatSessionRecord) {
		await $selectionMutation.mutateAsync({
			sessionId,
			names: [record.law_name],
			selected: !record.selected
		});
	}

	async function selectAll() {
		const names = records.map((r) => r.law_name);
		await $selectionMutation.mutateAsync({ sessionId, names, selected: true });
	}

	async function deselectAll() {
		const names = records.map((r) => r.law_name);
		await $selectionMutation.mutateAsync({ sessionId, names, selected: false });
	}

	function openReviewSelected() {
		if (selectedRecords.length === 0) return;
		modalRecords = selectedRecords;
		modalInitialIndex = 0;
		modalAutoConfirm = false;
		showModal = true;
	}

	function openAutoParseAll() {
		if (selectedRecords.length === 0) return;
		modalRecords = selectedRecords;
		modalInitialIndex = 0;
		modalAutoConfirm = true;
		showModal = true;
	}

	function openSingleRecord(record: LatSessionRecord) {
		modalRecords = [record];
		modalInitialIndex = 0;
		modalAutoConfirm = false;
		showModal = true;
	}

	function handleModalComplete(
		_event: CustomEvent<{ confirmed: number; skipped: number; errors: number }>
	) {
		showModal = false;
		// Records query will auto-refresh via invalidation in the mutation
	}

	async function handleDelete() {
		if (!confirm(`Delete session "${sessionId}"?`)) return;
		await $deleteMutation.mutateAsync(sessionId);
		goto('/admin/lat/sessions');
	}
</script>

<div class="p-6 max-w-7xl mx-auto">
	<!-- Header -->
	<div class="flex items-center justify-between mb-6">
		<div>
			<div class="flex items-center space-x-3">
				<a href="/admin/lat/sessions" class="text-sm text-gray-500 hover:text-gray-700">Sessions</a>
				<span class="text-gray-300">/</span>
				<h1 class="text-xl font-bold text-gray-900 font-mono">{sessionId}</h1>
			</div>
			{#if $sessionQuery.data}
				<div class="flex items-center space-x-3 mt-1">
					<span
						class="px-2 py-0.5 text-xs font-medium rounded-full {statusColor(
							$sessionQuery.data.status
						)}"
					>
						{$sessionQuery.data.status}
					</span>
				</div>
			{/if}
		</div>
		<div class="flex items-center space-x-3">
			<button
				on:click={handleDelete}
				class="px-3 py-1.5 text-sm text-red-700 border border-red-300 rounded-md hover:bg-red-50"
			>
				Delete
			</button>
		</div>
	</div>

	<!-- Stats Grid -->
	{#if $sessionQuery.data}
		{@const s = $sessionQuery.data}
		<div class="grid grid-cols-2 md:grid-cols-6 gap-4 mb-6">
			<div class="bg-white rounded-lg shadow px-4 py-3">
				<p class="text-xs text-gray-500 uppercase">Records</p>
				<p class="text-2xl font-bold text-gray-900">{s.group1_count}</p>
			</div>
			<div class="bg-white rounded-lg shadow px-4 py-3">
				<p class="text-xs text-gray-500 uppercase">Parsed</p>
				<p class="text-2xl font-bold text-green-600">{parsedRecords.length}</p>
			</div>
			<div class="bg-white rounded-lg shadow px-4 py-3">
				<p class="text-xs text-gray-500 uppercase">Pending</p>
				<p class="text-2xl font-bold text-gray-600">{pendingRecords.length}</p>
			</div>
			<div class="bg-white rounded-lg shadow px-4 py-3">
				<p class="text-xs text-gray-500 uppercase">Failed</p>
				<p class="text-2xl font-bold text-red-600">{failedRecords.length}</p>
			</div>
			<div class="bg-white rounded-lg shadow px-4 py-3">
				<p class="text-xs text-gray-500 uppercase">LAT Rows</p>
				<p class="text-2xl font-bold text-blue-600">{s.lat_total_inserted}</p>
			</div>
			<div class="bg-white rounded-lg shadow px-4 py-3">
				<p class="text-xs text-gray-500 uppercase">Annotations</p>
				<p class="text-2xl font-bold text-purple-600">{s.lat_total_annotations}</p>
			</div>
		</div>
	{/if}

	<!-- Actions Bar -->
	<div class="flex items-center justify-between mb-4 bg-white rounded-lg shadow px-4 py-3">
		<div class="flex items-center space-x-3">
			<button
				on:click={selectAll}
				class="px-3 py-1.5 text-xs font-medium text-gray-600 border border-gray-300 rounded hover:bg-gray-50"
			>
				Select All
			</button>
			<button
				on:click={deselectAll}
				class="px-3 py-1.5 text-xs font-medium text-gray-600 border border-gray-300 rounded hover:bg-gray-50"
			>
				Deselect All
			</button>
			{#if selectedRecords.length > 0}
				<span class="text-sm text-gray-500">{selectedRecords.length} selected</span>
			{/if}
		</div>
		<div class="flex items-center space-x-3">
			<button
				on:click={openReviewSelected}
				disabled={selectedRecords.length === 0}
				class="px-4 py-2 text-sm font-medium text-blue-700 bg-blue-50 border border-blue-200 rounded-md hover:bg-blue-100 disabled:opacity-50 disabled:cursor-not-allowed"
			>
				Review Selected ({selectedRecords.length})
			</button>
			<button
				on:click={openAutoParseAll}
				disabled={selectedRecords.length === 0}
				class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
			>
				Auto Parse Selected ({selectedRecords.length})
			</button>
		</div>
	</div>

	<!-- Records Table -->
	{#if $recordsQuery.isPending}
		<div class="text-center py-12 text-gray-500">Loading records...</div>
	{:else if $recordsQuery.isError}
		<div class="rounded-md bg-red-50 p-4">
			<p class="text-sm text-red-700">{$recordsQuery.error?.message || 'Failed to load records'}</p>
		</div>
	{:else if records.length === 0}
		<div class="text-center py-12 text-gray-500">No records in this session.</div>
	{:else}
		<div class="overflow-x-auto bg-white rounded-lg shadow">
			<table class="min-w-full divide-y divide-gray-200">
				<thead class="bg-gray-50">
					<tr>
						<th class="px-3 py-3 w-10"></th>
						<th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase">Law Name</th
						>
						<th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase">Title</th>
						<th class="px-3 py-3 text-left text-xs font-medium text-gray-500 uppercase">Family</th>
						<th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase">Live</th>
						<th class="px-3 py-3 text-center text-xs font-medium text-gray-500 uppercase">Status</th
						>
						<th class="px-3 py-3 text-right text-xs font-medium text-gray-500 uppercase">LAT</th>
						<th class="px-3 py-3 text-right text-xs font-medium text-gray-500 uppercase">Ann.</th>
						<th class="px-3 py-3 text-right text-xs font-medium text-gray-500 uppercase">Time</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-gray-200">
					{#each records as record}
						<tr class="hover:bg-gray-50 cursor-pointer" on:click={() => openSingleRecord(record)}>
							<!-- svelte-ignore a11y-click-events-have-key-events -->
							<td class="px-3 py-2" on:click|stopPropagation>
								<input
									type="checkbox"
									checked={record.selected}
									on:change={() => toggleSelect(record)}
									class="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
								/>
							</td>
							<td class="px-3 py-2 text-sm font-mono text-gray-700 max-w-[200px] truncate">
								{record.law_name}
							</td>
							<td class="px-3 py-2 text-sm text-gray-900 max-w-[250px] truncate">
								{record.title_en || '-'}
							</td>
							<td class="px-3 py-2 text-sm text-gray-600 max-w-[120px] truncate">
								{record.family || '-'}
							</td>
							<td class="px-3 py-2 text-center text-sm">
								{#if record.live?.startsWith('✔')}
									<span class="text-green-600" title="In force">✔</span>
								{:else if record.live?.startsWith('❌')}
									<span class="text-red-600" title="Revoked / Repealed">❌</span>
								{:else if record.live?.startsWith('⭕')}
									<span class="text-orange-500" title="Part Revocation">⭕</span>
								{:else}
									<span class="text-gray-400">-</span>
								{/if}
							</td>
							<td class="px-3 py-2 text-center">
								<span
									class="px-2 py-0.5 text-xs font-medium rounded-full {statusColor(record.status)}"
								>
									{record.status}
								</span>
							</td>
							<td class="px-3 py-2 text-sm text-right text-gray-700">
								{record.lat_inserted ?? '-'}
							</td>
							<td class="px-3 py-2 text-sm text-right text-gray-700">
								{record.annotations_inserted ?? '-'}
							</td>
							<td class="px-3 py-2 text-sm text-right text-gray-500">
								{record.parse_duration_ms
									? `${(record.parse_duration_ms / 1000).toFixed(1)}s`
									: '-'}
							</td>
						</tr>
						{#if record.parse_error}
							<tr class="bg-red-50">
								<td></td>
								<td colspan="9" class="px-3 py-1 text-xs text-red-600">
									{record.parse_error}
								</td>
							</tr>
						{/if}
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<LatParseReviewModal
	{sessionId}
	records={modalRecords}
	initialIndex={modalInitialIndex}
	bind:open={showModal}
	autoConfirm={modalAutoConfirm}
	on:close={() => (showModal = false)}
	on:complete={handleModalComplete}
/>
