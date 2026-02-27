<script lang="ts">
	import { format } from 'date-fns';
	import { useSubscriptionsQuery, useQueryablesQuery } from '$lib/query/zenoh';
	import type { ActivityEntry } from '$lib/api/zenoh';

	let activeTab: 'subscriptions' | 'queryables' = 'subscriptions';

	const subsQuery = useSubscriptionsQuery();
	const queryablesQuery = useQueryablesQuery();

	function stateColor(state: string): string {
		switch (state) {
			case 'ready':
				return 'bg-green-100 text-green-800';
			case 'connecting':
				return 'bg-yellow-100 text-yellow-800';
			case 'disabled':
				return 'bg-gray-100 text-gray-500';
			case 'stopped':
				return 'bg-red-100 text-red-800';
			default:
				return 'bg-gray-100 text-gray-600';
		}
	}

	function eventColor(event: string): string {
		switch (event) {
			case 'updated':
			case 'connected':
			case 'published':
			case 'query':
				return 'text-green-700';
			case 'error':
				return 'text-red-700';
			default:
				return 'text-gray-600';
		}
	}

	function formatTs(ts: string): string {
		try {
			return format(new Date(ts), 'HH:mm:ss');
		} catch {
			return ts;
		}
	}

	function statValue(stats: Record<string, unknown>, key: string): number {
		const v = stats[key];
		return typeof v === 'number' ? v : 0;
	}

	function startedAt(stats: Record<string, unknown> | undefined): string | null {
		if (!stats) return null;
		const v = stats['started_at'];
		return typeof v === 'string' ? v : null;
	}

	$: statsSince =
		startedAt($subsQuery.data?.stats) ||
		startedAt($queryablesQuery.data?.data_server?.stats);
</script>

<div>
	<div class="mb-6">
		<h1 class="text-2xl font-bold text-gray-900">Zenoh P2P Mesh</h1>
		<p class="mt-1 text-sm text-gray-500">
			Monitor subscriptions, queryables, and publishers
			{#if statsSince}
				<span class="ml-2 text-gray-400">| Stats since {formatTs(statsSince)}</span>
			{/if}
		</p>
	</div>

	<!-- Tabs -->
	<div class="flex gap-1 border-b border-gray-200 mb-6">
		<button
			on:click={() => (activeTab = 'subscriptions')}
			class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
				{activeTab === 'subscriptions'
				? 'border-blue-500 text-blue-600'
				: 'border-transparent text-gray-500 hover:text-gray-700'}"
		>
			Subscriptions
		</button>
		<button
			on:click={() => (activeTab = 'queryables')}
			class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
				{activeTab === 'queryables'
				? 'border-blue-500 text-blue-600'
				: 'border-transparent text-gray-500 hover:text-gray-700'}"
		>
			Queryables & Publishers
		</button>
	</div>

	<!-- Subscriptions Tab -->
	{#if activeTab === 'subscriptions'}
		{#if $subsQuery.isLoading}
			<div class="flex justify-center py-12">
				<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
			</div>
		{:else if $subsQuery.isError}
			<div class="rounded-md bg-red-50 p-4">
				<p class="text-sm text-red-700">
					{$subsQuery.error?.message || 'Failed to load subscription data'}
				</p>
			</div>
		{:else if $subsQuery.data}
			{@const data = $subsQuery.data}
			<!-- Status -->
			<div class="bg-white shadow rounded-lg p-6 mb-6">
				<div class="flex items-center justify-between mb-4">
					<h2 class="text-lg font-semibold text-gray-900">TaxaSubscriber</h2>
					<span
						class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {stateColor(
							data.status.state
						)}"
					>
						{data.status.state}
					</span>
				</div>
				{#if data.status.key_expr}
					<p class="text-sm text-gray-500 mb-4">
						Key: <code class="bg-gray-100 px-1.5 py-0.5 rounded text-xs"
							>{data.status.key_expr}</code
						>
					</p>
				{/if}

				<!-- Counters -->
				<div class="grid grid-cols-3 gap-4">
					<div class="bg-blue-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-blue-700">
							{statValue(data.stats, 'received')}
						</div>
						<div class="text-xs text-blue-600 mt-1">Received</div>
					</div>
					<div class="bg-green-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-green-700">
							{statValue(data.stats, 'updated')}
						</div>
						<div class="text-xs text-green-600 mt-1">Updated</div>
					</div>
					<div class="bg-red-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-red-700">
							{statValue(data.stats, 'failed')}
						</div>
						<div class="text-xs text-red-600 mt-1">Failed</div>
					</div>
				</div>
			</div>

			<!-- Recent Activity -->
			{#if data.recent.length > 0}
				<div class="bg-white shadow overflow-hidden rounded-lg">
					<div class="px-6 py-4 border-b border-gray-200">
						<h3 class="text-sm font-medium text-gray-900">Recent Activity</h3>
					</div>
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Time</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Event</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Details</th
								>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each data.recent as entry}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-3 whitespace-nowrap text-xs text-gray-500">
										{formatTs(entry.timestamp)}
									</td>
									<td class="px-6 py-3 whitespace-nowrap">
										<span class="text-sm font-medium {eventColor(entry.event)}">
											{entry.event}
										</span>
									</td>
									<td class="px-6 py-3 text-sm text-gray-500">
										{#if entry.metadata.law_name}
											{entry.metadata.law_name}
										{/if}
										{#if entry.metadata.reason}
											<span class="text-red-600">{entry.metadata.reason}</span>
										{/if}
										{#if entry.metadata.key_expr}
											<code class="bg-gray-100 px-1 rounded text-xs"
												>{entry.metadata.key_expr}</code
											>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="text-center py-8 bg-white rounded-lg shadow">
					<p class="text-sm text-gray-500">No activity recorded yet</p>
				</div>
			{/if}
		{/if}

		<!-- Queryables & Publishers Tab -->
	{:else if activeTab === 'queryables'}
		{#if $queryablesQuery.isLoading}
			<div class="flex justify-center py-12">
				<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
			</div>
		{:else if $queryablesQuery.isError}
			<div class="rounded-md bg-red-50 p-4">
				<p class="text-sm text-red-700">
					{$queryablesQuery.error?.message || 'Failed to load queryable data'}
				</p>
			</div>
		{:else if $queryablesQuery.data}
			{@const data = $queryablesQuery.data}

			<!-- DataServer Section -->
			<div class="bg-white shadow rounded-lg p-6 mb-6">
				<div class="flex items-center justify-between mb-4">
					<h2 class="text-lg font-semibold text-gray-900">DataServer (Queryables)</h2>
					<span
						class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {stateColor(
							data.data_server.status.state
						)}"
					>
						{data.data_server.status.state}
					</span>
				</div>

				{#if data.data_server.status.queryable_count}
					<p class="text-sm text-gray-500 mb-2">
						{data.data_server.status.queryable_count} queryables declared
					</p>
				{/if}

				{#if data.data_server.status.key_expressions}
					<div class="mb-4 space-y-1">
						{#each data.data_server.status.key_expressions as expr}
							<div>
								<code class="bg-gray-100 px-1.5 py-0.5 rounded text-xs">{expr}</code>
							</div>
						{/each}
					</div>
				{/if}

				<!-- Counters -->
				<div class="grid grid-cols-2 gap-4">
					<div class="bg-blue-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-blue-700">
							{statValue(data.data_server.stats, 'queries')}
						</div>
						<div class="text-xs text-blue-600 mt-1">Queries Handled</div>
					</div>
					<div class="bg-red-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-red-700">
							{statValue(data.data_server.stats, 'errors')}
						</div>
						<div class="text-xs text-red-600 mt-1">Errors</div>
					</div>
				</div>
			</div>

			<!-- DataServer Recent Activity -->
			{#if data.data_server.recent.length > 0}
				<div class="bg-white shadow overflow-hidden rounded-lg mb-6">
					<div class="px-6 py-4 border-b border-gray-200">
						<h3 class="text-sm font-medium text-gray-900">DataServer Activity</h3>
					</div>
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Time</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Event</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Key Expression</th
								>
								<th
									class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase"
									>Duration</th
								>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each data.data_server.recent as entry}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-3 whitespace-nowrap text-xs text-gray-500">
										{formatTs(entry.timestamp)}
									</td>
									<td class="px-6 py-3 whitespace-nowrap">
										<span class="text-sm font-medium {eventColor(entry.event)}">
											{entry.event}
										</span>
									</td>
									<td class="px-6 py-3 text-sm text-gray-500">
										{#if entry.metadata.key_expr}
											<code class="bg-gray-100 px-1 rounded text-xs"
												>{entry.metadata.key_expr}</code
											>
										{/if}
										{#if entry.metadata.reason}
											<span class="text-red-600">{entry.metadata.reason}</span>
										{/if}
									</td>
									<td class="px-6 py-3 whitespace-nowrap text-right text-xs text-gray-500">
										{#if entry.metadata.duration_ms !== undefined}
											{entry.metadata.duration_ms}ms
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}

			<!-- ChangeNotifier Section -->
			<div class="bg-white shadow rounded-lg p-6 mb-6">
				<div class="flex items-center justify-between mb-4">
					<h2 class="text-lg font-semibold text-gray-900">ChangeNotifier (Publisher)</h2>
					<span
						class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {stateColor(
							data.change_notifier.status.state
						)}"
					>
						{data.change_notifier.status.state}
					</span>
				</div>

				{#if data.change_notifier.status.key}
					<p class="text-sm text-gray-500 mb-4">
						Key: <code class="bg-gray-100 px-1.5 py-0.5 rounded text-xs"
							>{data.change_notifier.status.key}</code
						>
					</p>
				{/if}

				<!-- Counters -->
				<div class="grid grid-cols-3 gap-4">
					<div class="bg-green-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-green-700">
							{statValue(data.change_notifier.stats, 'published')}
						</div>
						<div class="text-xs text-green-600 mt-1">Published</div>
					</div>
					<div class="bg-yellow-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-yellow-700">
							{statValue(data.change_notifier.stats, 'dropped')}
						</div>
						<div class="text-xs text-yellow-600 mt-1">Dropped</div>
					</div>
					<div class="bg-red-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-red-700">
							{statValue(data.change_notifier.stats, 'errors')}
						</div>
						<div class="text-xs text-red-600 mt-1">Errors</div>
					</div>
				</div>
			</div>

			<!-- ChangeNotifier Recent Activity -->
			{#if data.change_notifier.recent.length > 0}
				<div class="bg-white shadow overflow-hidden rounded-lg">
					<div class="px-6 py-4 border-b border-gray-200">
						<h3 class="text-sm font-medium text-gray-900">ChangeNotifier Activity</h3>
					</div>
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Time</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Event</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Table</th
								>
								<th
									class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Action</th
								>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each data.change_notifier.recent as entry}
								<tr class="hover:bg-gray-50">
									<td class="px-6 py-3 whitespace-nowrap text-xs text-gray-500">
										{formatTs(entry.timestamp)}
									</td>
									<td class="px-6 py-3 whitespace-nowrap">
										<span class="text-sm font-medium {eventColor(entry.event)}">
											{entry.event}
										</span>
									</td>
									<td class="px-6 py-3 text-sm text-gray-500">
										{entry.metadata.table || ''}
									</td>
									<td class="px-6 py-3 text-sm text-gray-500">
										{entry.metadata.action || ''}
										{#if entry.metadata.reason}
											<span class="text-red-600">{entry.metadata.reason}</span>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		{/if}
	{/if}
</div>
