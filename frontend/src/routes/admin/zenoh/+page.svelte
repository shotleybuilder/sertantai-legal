<script lang="ts">
	import { format } from 'date-fns';
	import { useSubscriptionsQuery, useQueryablesQuery } from '$lib/query/zenoh';

	let activeTab:
		| 'taxa'
		| 'provisions'
		| 'controls'
		| 'evidence'
		| 'triage'
		| 'secondary_sources'
		| 'queryables' = 'triage';

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

	const tabs = [
		{ id: 'triage' as const, label: 'Triage' },
		{ id: 'taxa' as const, label: 'Taxa' },
		{ id: 'provisions' as const, label: 'Provisions' },
		{ id: 'controls' as const, label: 'Controls' },
		{ id: 'evidence' as const, label: 'Evidence' },
		{ id: 'secondary_sources' as const, label: 'Secondary Sources' },
		{ id: 'queryables' as const, label: 'Queryables & Publishers' }
	];

	$: statsSince =
		startedAt($subsQuery.data?.taxa_subscriber?.stats) ||
		startedAt($queryablesQuery.data?.data_server?.stats);

	// Map tab id to subscriber data
	$: subscriberMap = $subsQuery.data
		? {
				taxa: {
					label: 'TaxaSubscriber',
					sublabel: 'Law-level enrichment',
					data: $subsQuery.data.taxa_subscriber
				},
				triage: {
					label: 'TriageSubscriber',
					sublabel: 'Making/not-making classification',
					data: $subsQuery.data.triage_subscriber
				},
				provisions: {
					label: 'ProvisionSubscriber',
					sublabel: 'Per-provision DRRP & actors',
					data: $subsQuery.data.provision_subscriber
				},
				controls: {
					label: 'ControlsSubscriber',
					sublabel: 'AI-generated controls & predicates',
					data: $subsQuery.data.controls_subscriber
				},
				evidence: {
					label: 'EvidenceSubscriber',
					sublabel: 'Evidence patterns & artefact templates',
					data: $subsQuery.data.evidence_subscriber
				},
				secondary_sources: {
					label: 'SecondaryTaxaSubscriber',
					sublabel: 'ACoP / JSP / HSG provision enrichment',
					data: $subsQuery.data.secondary_taxa_subscriber
				}
			}
		: null;
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
		{#each tabs as tab}
			<button
				on:click={() => (activeTab = tab.id)}
				class="px-4 py-2 text-sm font-medium border-b-2 transition-colors
					{activeTab === tab.id
					? 'border-blue-500 text-blue-600'
					: 'border-transparent text-gray-500 hover:text-gray-700'}"
			>
				{tab.label}
				{#if tab.id !== 'queryables' && subscriberMap}
					{@const subData = subscriberMap[tab.id].data}
					<span
						class="ml-1.5 inline-flex items-center w-2 h-2 rounded-full {subData.status.state ===
						'ready'
							? 'bg-green-500'
							: subData.status.state === 'connecting'
								? 'bg-yellow-500'
								: 'bg-gray-400'}"
					></span>
				{/if}
			</button>
		{/each}
	</div>

	<!-- Subscriber Tabs (Taxa, Provisions, Controls) -->
	{#if activeTab === 'taxa' || activeTab === 'provisions' || activeTab === 'controls' || activeTab === 'evidence' || activeTab === 'triage' || activeTab === 'secondary_sources'}
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
		{:else if subscriberMap}
			{@const sub = subscriberMap[activeTab]}

			<!-- Status -->
			<div class="bg-white shadow rounded-lg p-6 mb-6">
				<div class="flex items-center justify-between mb-4">
					<div>
						<h2 class="text-lg font-semibold text-gray-900">{sub.label}</h2>
						<p class="text-xs text-gray-400">{sub.sublabel}</p>
					</div>
					<span
						class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {stateColor(
							sub.data.status.state
						)}"
					>
						{sub.data.status.state}
					</span>
				</div>
				{#if sub.data.status.key_expr}
					<p class="text-sm text-gray-500 mb-4">
						Key: <code class="bg-gray-100 px-1.5 py-0.5 rounded text-xs"
							>{sub.data.status.key_expr}</code
						>
					</p>
				{/if}

				<!-- Counters -->
				<div class="grid grid-cols-3 gap-4">
					<div class="bg-blue-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-blue-700">
							{statValue(sub.data.stats, 'received')}
						</div>
						<div class="text-xs text-blue-600 mt-1">Received</div>
					</div>
					<div class="bg-green-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-green-700">
							{statValue(sub.data.stats, 'updated')}
						</div>
						<div class="text-xs text-green-600 mt-1">Updated</div>
					</div>
					<div class="bg-red-50 rounded-lg p-4 text-center">
						<div class="text-2xl font-bold text-red-700">
							{statValue(sub.data.stats, 'failed')}
						</div>
						<div class="text-xs text-red-600 mt-1">Failed</div>
					</div>
				</div>
			</div>

			<!-- Recent Activity -->
			{#if sub.data.recent.length > 0}
				<div class="bg-white shadow overflow-hidden rounded-lg mb-6">
					<div class="px-6 py-4 border-b border-gray-200">
						<h3 class="text-sm font-medium text-gray-900">Recent Activity</h3>
					</div>
					<table class="min-w-full divide-y divide-gray-200">
						<thead class="bg-gray-50">
							<tr>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Event</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Details</th
								>
							</tr>
						</thead>
						<tbody class="bg-white divide-y divide-gray-200">
							{#each sub.data.recent as entry}
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
										{#if entry.metadata.source_id}
											{entry.metadata.source_id}
										{/if}
										{#if entry.metadata.provisions}
											<span class="text-gray-400 ml-1"
												>({entry.metadata.provisions} provisions)</span
											>
										{/if}
										{#if entry.metadata.controls}
											<span class="text-gray-400 ml-1">({entry.metadata.controls} controls)</span>
										{/if}
										{#if entry.metadata.patterns}
											<span class="text-gray-400 ml-1">({entry.metadata.patterns} patterns)</span>
										{/if}
										{#if entry.metadata.is_predicate}
											<span
												class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded text-xs bg-purple-100 text-purple-700"
												>predicate</span
											>
										{/if}
										{#if entry.metadata.reason}
											<span class="text-red-600">{entry.metadata.reason}</span>
										{/if}
										{#if entry.metadata.key_expr}
											<code class="bg-gray-100 px-1 rounded text-xs">{entry.metadata.key_expr}</code
											>
										{/if}
									</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{:else}
				<div class="text-center py-8 bg-white rounded-lg shadow mb-6">
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
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Event</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Key Expression</th
								>
								<th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase"
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
											<code class="bg-gray-100 px-1 rounded text-xs">{entry.metadata.key_expr}</code
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
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Time</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Event</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
									>Table</th
								>
								<th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase"
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
