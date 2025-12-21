<script lang="ts">
	import { format } from 'date-fns';
	import { useSessionsQuery, useDeleteSessionMutation } from '$lib/query/scraper';
	import type { ScrapeSession } from '$lib/api/scraper';

	const query = useSessionsQuery();
	const deleteMutation = useDeleteSessionMutation();

	function getStatusColor(status: ScrapeSession['status']): string {
		switch (status) {
			case 'completed':
				return 'bg-green-100 text-green-800';
			case 'failed':
				return 'bg-red-100 text-red-800';
			case 'scraping':
			case 'categorized':
			case 'reviewing':
				return 'bg-yellow-100 text-yellow-800';
			default:
				return 'bg-gray-100 text-gray-800';
		}
	}

	function formatDateRange(session: ScrapeSession): string {
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

	async function handleDelete(sessionId: string) {
		if (confirm('Are you sure you want to delete this session?')) {
			await $deleteMutation.mutateAsync(sessionId);
		}
	}
</script>

<div>
	<div class="flex justify-between items-center mb-6">
		<h1 class="text-2xl font-bold text-gray-900">Scrape Sessions</h1>
		<a
			href="/admin/scrape"
			class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700"
		>
			New Scrape
		</a>
	</div>

	{#if $query.isLoading}
		<div class="flex justify-center py-12">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
		</div>
	{:else if $query.isError}
		<div class="rounded-md bg-red-50 p-4">
			<p class="text-sm text-red-700">{$query.error?.message || 'Failed to load sessions'}</p>
		</div>
	{:else if $query.data && $query.data.length === 0}
		<div class="text-center py-12 bg-white rounded-lg shadow">
			<svg
				class="mx-auto h-12 w-12 text-gray-400"
				fill="none"
				viewBox="0 0 24 24"
				stroke="currentColor"
			>
				<path
					stroke-linecap="round"
					stroke-linejoin="round"
					stroke-width="2"
					d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
				/>
			</svg>
			<h3 class="mt-2 text-sm font-medium text-gray-900">No sessions</h3>
			<p class="mt-1 text-sm text-gray-500">Get started by creating a new scrape session.</p>
			<div class="mt-6">
				<a
					href="/admin/scrape"
					class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700"
				>
					New Scrape
				</a>
			</div>
		</div>
	{:else if $query.data}
		<div class="bg-white shadow overflow-hidden rounded-lg">
			<table class="min-w-full divide-y divide-gray-200">
				<thead class="bg-gray-50">
					<tr>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
						>
							Session
						</th>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
						>
							Date Range
						</th>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
						>
							Status
						</th>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
						>
							Records
						</th>
						<th
							class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
						>
							Created
						</th>
						<th
							class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
						>
							Actions
						</th>
					</tr>
				</thead>
				<tbody class="bg-white divide-y divide-gray-200">
					{#each $query.data as session}
						<tr class="hover:bg-gray-50">
							<td class="px-6 py-4 whitespace-nowrap">
								<a
									href="/admin/scrape/sessions/{session.session_id}"
									class="text-blue-600 hover:text-blue-800 font-medium"
								>
									{session.session_id}
								</a>
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								{formatDateRange(session)}
							</td>
							<td class="px-6 py-4 whitespace-nowrap">
								<span
									class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {getStatusColor(
										session.status
									)}"
								>
									{session.status}
								</span>
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								<div class="flex space-x-3">
									<span title="Total fetched">{session.total_fetched}</span>
									{#if session.group1_count > 0}
										<span class="text-green-600" title="Group 1 (SI match)"
											>G1: {session.group1_count}</span
										>
									{/if}
									{#if session.group2_count > 0}
										<span class="text-blue-600" title="Group 2 (Term match)"
											>G2: {session.group2_count}</span
										>
									{/if}
									{#if session.group3_count > 0}
										<span class="text-gray-600" title="Group 3 (Excluded)"
											>G3: {session.group3_count}</span
										>
									{/if}
								</div>
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
								{format(new Date(session.inserted_at), 'MMM d, HH:mm')}
							</td>
							<td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
								<a
									href="/admin/scrape/sessions/{session.session_id}"
									class="text-blue-600 hover:text-blue-800 mr-4"
								>
									View
								</a>
								<button
									on:click={() => handleDelete(session.session_id)}
									class="text-red-600 hover:text-red-800"
									disabled={$deleteMutation.isPending}
								>
									Delete
								</button>
							</td>
						</tr>
					{/each}
				</tbody>
			</table>
		</div>
	{/if}
</div>
