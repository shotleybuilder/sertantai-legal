<script lang="ts">
	import { goto } from '$app/navigation';
	import { useLatSessionsQuery, useDeleteLatSessionMutation } from '$lib/query/lat';
	import LatParseDialog from '$lib/components/LatParseDialog.svelte';

	const sessionsQuery = useLatSessionsQuery();
	const deleteMutation = useDeleteLatSessionMutation();

	let showDialog = false;
	let deletingId: string | null = null;

	function statusColor(status: string): string {
		switch (status) {
			case 'completed':
				return 'bg-green-100 text-green-800';
			case 'failed':
				return 'bg-red-100 text-red-800';
			case 'pending':
				return 'bg-gray-100 text-gray-800';
			default:
				return 'bg-yellow-100 text-yellow-800';
		}
	}

	function formatDate(dateStr: string | null): string {
		if (!dateStr) return '-';
		try {
			return new Date(dateStr).toLocaleDateString('en-GB', {
				day: 'numeric',
				month: 'short',
				year: 'numeric',
				hour: '2-digit',
				minute: '2-digit'
			});
		} catch {
			return dateStr;
		}
	}

	async function handleDelete(sessionId: string) {
		if (!confirm(`Delete session "${sessionId}"?`)) return;
		deletingId = sessionId;
		try {
			await $deleteMutation.mutateAsync(sessionId);
		} catch (e) {
			console.error('Delete failed:', e);
		} finally {
			deletingId = null;
		}
	}

	function handleCreated(event: CustomEvent<{ session_id: string }>) {
		showDialog = false;
		goto(`/admin/lat/sessions/${event.detail.session_id}`);
	}
</script>

<div class="p-6 max-w-7xl mx-auto">
	<!-- Header -->
	<div class="flex items-center justify-between mb-6">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">LAT Parse Sessions</h1>
			<p class="text-sm text-gray-500 mt-1">
				Session-based LAT + annotation parsing for law families
			</p>
		</div>
		<div class="flex items-center space-x-3">
			<a
				href="/admin/lat/queue"
				class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
			>
				Queue
			</a>
			<button
				on:click={() => (showDialog = true)}
				class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700"
			>
				New LAT Session
			</button>
		</div>
	</div>

	<!-- Sessions Table -->
	{#if $sessionsQuery.isPending}
		<div class="text-center py-12 text-gray-500">Loading sessions...</div>
	{:else if $sessionsQuery.isError}
		<div class="rounded-md bg-red-50 p-4">
			<p class="text-sm text-red-700">{$sessionsQuery.error?.message || 'Failed to load sessions'}</p>
		</div>
	{:else if ($sessionsQuery.data?.sessions?.length ?? 0) === 0}
		<div class="text-center py-12">
			<p class="text-gray-500 mb-4">No LAT parse sessions yet.</p>
			<button
				on:click={() => (showDialog = true)}
				class="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700"
			>
				Create First Session
			</button>
		</div>
	{:else}
		<div class="overflow-x-auto bg-white rounded-lg shadow">
			<table class="min-w-full divide-y divide-gray-200">
				<thead class="bg-gray-50">
					<tr>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Session ID</th>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status</th>
						<th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Records</th>
						<th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">LAT Rows</th>
						<th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Annotations</th>
						<th class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase">Created</th>
						<th class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
					</tr>
				</thead>
				<tbody class="divide-y divide-gray-200">
					{#each $sessionsQuery.data?.sessions ?? [] as session}
						<tr class="hover:bg-gray-50">
							<td class="px-4 py-3">
								<a
									href="/admin/lat/sessions/{session.session_id}"
									class="text-sm font-medium text-blue-600 hover:text-blue-800 font-mono"
								>
									{session.session_id}
								</a>
							</td>
							<td class="px-4 py-3">
								<span class="px-2 py-0.5 text-xs font-medium rounded-full {statusColor(session.status)}">
									{session.status}
								</span>
							</td>
							<td class="px-4 py-3 text-right text-sm text-gray-700">
								{session.persisted_count}/{session.group1_count}
							</td>
							<td class="px-4 py-3 text-right text-sm text-gray-700">
								{session.lat_total_inserted}
							</td>
							<td class="px-4 py-3 text-right text-sm text-gray-700">
								{session.lat_total_annotations}
							</td>
							<td class="px-4 py-3 text-sm text-gray-500">
								{formatDate(session.inserted_at)}
							</td>
							<td class="px-4 py-3 text-right">
								<div class="flex justify-end space-x-2">
									<a
										href="/admin/lat/sessions/{session.session_id}"
										class="px-3 py-1 text-xs font-medium text-blue-700 bg-blue-50 rounded hover:bg-blue-100"
									>
										View
									</a>
									<button
										on:click={() => handleDelete(session.session_id)}
										disabled={deletingId === session.session_id}
										class="px-3 py-1 text-xs font-medium text-red-700 bg-red-50 rounded hover:bg-red-100 disabled:opacity-50"
									>
										{deletingId === session.session_id ? '...' : 'Delete'}
									</button>
								</div>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>

<LatParseDialog bind:open={showDialog} on:close={() => (showDialog = false)} on:created={handleCreated} />
