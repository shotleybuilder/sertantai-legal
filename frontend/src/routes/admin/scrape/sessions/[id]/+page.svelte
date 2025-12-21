<script lang="ts">
	import { page } from '$app/stores';
	import { format } from 'date-fns';
	import {
		useSessionQuery,
		useGroupQuery,
		usePersistGroupMutation,
		useParseGroupMutation
	} from '$lib/query/scraper';
	import type { ScrapeSession } from '$lib/api/scraper';

	$: sessionId = $page.params.id ?? '';
	$: sessionQuery = useSessionQuery(sessionId);

	let activeGroup: 1 | 2 | 3 = 1;
	$: groupQuery = useGroupQuery(sessionId, activeGroup);

	type GroupNumber = 1 | 2 | 3;
	const groups: GroupNumber[] = [1, 2, 3];

	const persistMutation = usePersistGroupMutation();
	const parseMutation = useParseGroupMutation();

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

	function getGroupLabel(group: 1 | 2 | 3): string {
		switch (group) {
			case 1:
				return 'SI Code Match';
			case 2:
				return 'Term Match';
			case 3:
				return 'Excluded';
		}
	}

	function getGroupCount(session: ScrapeSession, group: 1 | 2 | 3): number {
		switch (group) {
			case 1:
				return session.group1_count;
			case 2:
				return session.group2_count;
			case 3:
				return session.group3_count;
		}
	}

	async function handlePersist() {
		if (confirm(`Persist Group ${activeGroup} to database?`)) {
			await $persistMutation.mutateAsync({ sessionId, group: activeGroup });
		}
	}

	async function handleParse() {
		if (confirm(`Parse Group ${activeGroup}? This will fetch metadata from legislation.gov.uk.`)) {
			await $parseMutation.mutateAsync({ sessionId, group: activeGroup });
		}
	}
</script>

<div>
	<!-- Back Link -->
	<div class="mb-4">
		<a href="/admin/scrape/sessions" class="text-blue-600 hover:text-blue-800 text-sm">
			&larr; Back to Sessions
		</a>
	</div>

	{#if $sessionQuery.isLoading}
		<div class="flex justify-center py-12">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
		</div>
	{:else if $sessionQuery.isError}
		<div class="rounded-md bg-red-50 p-4">
			<p class="text-sm text-red-700">{$sessionQuery.error?.message || 'Session not found'}</p>
		</div>
	{:else if $sessionQuery.data}
		{@const session = $sessionQuery.data}

		<!-- Header -->
		<div class="bg-white shadow rounded-lg p-6 mb-6">
			<div class="flex justify-between items-start">
				<div>
					<h1 class="text-2xl font-bold text-gray-900">{session.session_id}</h1>
					<p class="text-gray-500 mt-1">{formatDateRange(session)}</p>
				</div>
				<span
					class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium {getStatusColor(
						session.status
					)}"
				>
					{session.status}
				</span>
			</div>

			<!-- Stats Grid -->
			<div class="mt-6 grid grid-cols-2 md:grid-cols-5 gap-4">
				<div class="bg-gray-50 rounded-lg p-4">
					<p class="text-sm text-gray-500">Total Fetched</p>
					<p class="text-2xl font-semibold text-gray-900">{session.total_fetched}</p>
				</div>
				<div class="bg-green-50 rounded-lg p-4">
					<p class="text-sm text-green-600">Group 1 (SI)</p>
					<p class="text-2xl font-semibold text-green-700">{session.group1_count}</p>
				</div>
				<div class="bg-blue-50 rounded-lg p-4">
					<p class="text-sm text-blue-600">Group 2 (Term)</p>
					<p class="text-2xl font-semibold text-blue-700">{session.group2_count}</p>
				</div>
				<div class="bg-gray-50 rounded-lg p-4">
					<p class="text-sm text-gray-500">Group 3 (Exc)</p>
					<p class="text-2xl font-semibold text-gray-700">{session.group3_count}</p>
				</div>
				<div class="bg-purple-50 rounded-lg p-4">
					<p class="text-sm text-purple-600">Persisted</p>
					<p class="text-2xl font-semibold text-purple-700">{session.persisted_count}</p>
				</div>
			</div>

			{#if session.error_message}
				<div class="mt-4 rounded-md bg-red-50 p-4">
					<p class="text-sm text-red-700">{session.error_message}</p>
				</div>
			{/if}
		</div>

		<!-- Tabs -->
		<div class="bg-white shadow rounded-lg">
			<div class="border-b border-gray-200">
				<nav class="flex -mb-px">
					{#each groups as group}
						{@const count = getGroupCount(session, group)}
						<button
							on:click={() => (activeGroup = group)}
							class="flex-1 py-4 px-6 text-center border-b-2 font-medium text-sm
                     {activeGroup === group
								? 'border-blue-500 text-blue-600'
								: 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'}"
						>
							{getGroupLabel(group)}
							<span
								class="ml-2 py-0.5 px-2 rounded-full text-xs
                       {activeGroup === group
									? 'bg-blue-100 text-blue-600'
									: 'bg-gray-100 text-gray-600'}"
							>
								{count}
							</span>
						</button>
					{/each}
				</nav>
			</div>

			<!-- Action Buttons -->
			<div class="p-4 border-b border-gray-200 flex justify-end space-x-3">
				<button
					on:click={handleParse}
					disabled={$parseMutation.isPending}
					class="inline-flex items-center px-4 py-2 border border-gray-300 text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:bg-gray-100 disabled:cursor-not-allowed"
				>
					{#if $parseMutation.isPending}
						<svg class="animate-spin -ml-1 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24">
							<circle
								class="opacity-25"
								cx="12"
								cy="12"
								r="10"
								stroke="currentColor"
								stroke-width="4"
							></circle>
							<path
								class="opacity-75"
								fill="currentColor"
								d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
							></path>
						</svg>
						Parsing...
					{:else}
						Parse Group {activeGroup}
					{/if}
				</button>
				<button
					on:click={handlePersist}
					disabled={$persistMutation.isPending}
					class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
				>
					{#if $persistMutation.isPending}
						<svg class="animate-spin -ml-1 mr-2 h-4 w-4" fill="none" viewBox="0 0 24 24">
							<circle
								class="opacity-25"
								cx="12"
								cy="12"
								r="10"
								stroke="currentColor"
								stroke-width="4"
							></circle>
							<path
								class="opacity-75"
								fill="currentColor"
								d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
							></path>
						</svg>
						Persisting...
					{:else}
						Persist Group {activeGroup}
					{/if}
				</button>
			</div>

			<!-- Mutation Results -->
			{#if $persistMutation.isSuccess}
				<div class="mx-4 mt-4 rounded-md bg-green-50 p-4">
					<p class="text-sm text-green-700">Group persisted successfully!</p>
				</div>
			{/if}
			{#if $persistMutation.isError}
				<div class="mx-4 mt-4 rounded-md bg-red-50 p-4">
					<p class="text-sm text-red-700">{$persistMutation.error?.message}</p>
				</div>
			{/if}
			{#if $parseMutation.isSuccess}
				<div class="mx-4 mt-4 rounded-md bg-green-50 p-4">
					<p class="text-sm text-green-700">
						Parse complete! Parsed: {$parseMutation.data?.results.parsed}, Errors: {$parseMutation
							.data?.results.errors}
					</p>
				</div>
			{/if}
			{#if $parseMutation.isError}
				<div class="mx-4 mt-4 rounded-md bg-red-50 p-4">
					<p class="text-sm text-red-700">{$parseMutation.error?.message}</p>
				</div>
			{/if}

			<!-- Records Table -->
			<div class="p-4">
				{#if $groupQuery.isLoading}
					<div class="flex justify-center py-8">
						<div class="animate-spin rounded-full h-6 w-6 border-b-2 border-blue-600"></div>
					</div>
				{:else if $groupQuery.isError}
					<div class="text-center py-8 text-gray-500">
						<p>No records found for this group</p>
					</div>
				{:else if $groupQuery.data && $groupQuery.data.records.length > 0}
					<div class="overflow-x-auto">
						<table class="min-w-full divide-y divide-gray-200">
							<thead class="bg-gray-50">
								<tr>
									{#if activeGroup === 3}
										<th
											class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>
											#
										</th>
									{/if}
									<th
										class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
									>
										Title
									</th>
									<th
										class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
									>
										Type
									</th>
									<th
										class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
									>
										Year
									</th>
									<th
										class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
									>
										Number
									</th>
									{#if activeGroup === 1}
										<th
											class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>
											SI Codes
										</th>
									{/if}
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each $groupQuery.data.records as record}
									<tr class="hover:bg-gray-50">
										{#if activeGroup === 3}
											<td class="px-4 py-3 text-sm text-gray-500">
												{record._index || '-'}
											</td>
										{/if}
										<td class="px-4 py-3">
											<a
												href="https://www.legislation.gov.uk/{record.type_code}/{record.Year}/{record.Number}"
												target="_blank"
												rel="noopener noreferrer"
												class="text-blue-600 hover:text-blue-800 text-sm"
											>
												{record.Title_EN}
											</a>
										</td>
										<td class="px-4 py-3 text-sm text-gray-500">
											{record.type_code}
										</td>
										<td class="px-4 py-3 text-sm text-gray-500">
											{record.Year}
										</td>
										<td class="px-4 py-3 text-sm text-gray-500">
											{record.Number}
										</td>
										{#if activeGroup === 1}
											<td class="px-4 py-3 text-sm text-gray-500">
												{#if record.SICode && record.SICode.length > 0}
													<span class="text-green-600">{record.SICode.join(', ')}</span>
												{:else if record.si_code}
													<span class="text-green-600">{record.si_code}</span>
												{:else}
													-
												{/if}
											</td>
										{/if}
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{:else}
					<div class="text-center py-8 text-gray-500">
						<p>No records in this group</p>
					</div>
				{/if}
			</div>
		</div>
	{/if}
</div>
