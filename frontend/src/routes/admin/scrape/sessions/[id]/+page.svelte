<script lang="ts">
	import { page } from '$app/stores';
	import {
		useSessionQuery,
		useSessionDbStatusQuery,
		useGroupQuery,
		useParseGroupMutation,
		useUpdateSelectionMutation
	} from '$lib/query/scraper';
	import type { ScrapeSession, ScrapeRecord, AffectedLaw } from '$lib/api/scraper';
	import { getAffectedLaws } from '$lib/api/scraper';
	import ParseReviewModal from '$lib/components/ParseReviewModal.svelte';
	import CascadeUpdateModal from '$lib/components/CascadeUpdateModal.svelte';

	$: sessionId = $page.params.id ?? '';
	$: sessionQuery = useSessionQuery(sessionId);
	$: dbStatusQuery = useSessionDbStatusQuery(sessionId);

	let activeGroup: 1 | 2 | 3 = 1;
	$: groupQuery = useGroupQuery(sessionId, activeGroup);

	type GroupNumber = 1 | 2 | 3;
	const groups: GroupNumber[] = [1, 2, 3];

	const parseMutation = useParseGroupMutation();
	const selectionMutation = useUpdateSelectionMutation();

	// Compute selected count from current group data
	$: records = $groupQuery.data?.records ?? [];
	$: selectedCount = records.filter((r) => r.selected).length;
	$: allSelected = records.length > 0 && selectedCount === records.length;
	$: someSelected = selectedCount > 0 && selectedCount < records.length;

	// Set of names that exist in database (for "In DB" column indicator)
	$: existingNamesSet = new Set($dbStatusQuery.data?.existing_names ?? []);

	// Parse Review Modal State
	let showParseModal = false;
	let parseModalRecords: ScrapeRecord[] = [];
	let parseModalStartIndex = 0;
	let parseModalStages: import('$lib/api/scraper').ParseStage[] | undefined = undefined;
	let parseCompleteMessage = '';

	// Cascade Update Modal State
	let showCascadeModal = false;
	let affectedLawsCount = 0;
	let cascadePendingCount = 0;
	let cascadeProcessedCount = 0;

	// Fetch cascade status on mount and when session changes
	$: if (sessionId) {
		fetchCascadeStatus();
	}

	async function fetchCascadeStatus() {
		try {
			const affected = await getAffectedLaws(sessionId);
			cascadePendingCount = affected.pending_count;
			cascadeProcessedCount = affected.processed_count;
		} catch (e) {
			// No cascade data or error - that's fine
			cascadePendingCount = 0;
			cascadeProcessedCount = 0;
		}
	}

	function formatUpdatedAt(isoString: string | null | undefined): string {
		if (!isoString) return '-';
		const date = new Date(isoString);
		const month = (date.getMonth() + 1).toString().padStart(2, '0');
		const day = date.getDate().toString().padStart(2, '0');
		const hours = date.getHours().toString().padStart(2, '0');
		const mins = date.getMinutes().toString().padStart(2, '0');
		return `${month}/${day} ${hours}:${mins}`;
	}

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

	async function handleParse() {
		const parseSelectedOnly = selectedCount > 0;
		const count = parseSelectedOnly ? selectedCount : records.length;
		const msg = parseSelectedOnly
			? `Parse ${selectedCount} selected records? This will fetch metadata from legislation.gov.uk.`
			: `Parse all ${records.length} records in Group ${activeGroup}? This will fetch metadata from legislation.gov.uk.`;

		if (confirm(msg)) {
			await $parseMutation.mutateAsync({
				sessionId,
				group: activeGroup,
				selectedOnly: parseSelectedOnly
			});
		}
	}

	function handleInteractiveParse() {
		const targetRecords = selectedCount > 0 ? records.filter((r) => r.selected) : records;
		if (targetRecords.length === 0) {
			alert('No records to parse');
			return;
		}
		parseModalRecords = targetRecords;
		parseModalStartIndex = 0;
		parseModalStages = undefined;
		parseCompleteMessage = '';
		showParseModal = true;
	}

	function handleParseModalClose() {
		showParseModal = false;
	}

	async function handleParseComplete(
		event: CustomEvent<{ confirmed: number; skipped: number; errors: number }>
	) {
		showParseModal = false;
		const { confirmed, skipped, errors } = event.detail;
		parseCompleteMessage = `Parse complete: ${confirmed} confirmed, ${skipped} skipped, ${errors} errors`;
		// Refresh the session data to update counts
		$sessionQuery.refetch();
		// Also refresh db status to update the "In DB" indicator
		$dbStatusQuery.refetch();

		// Check if there are affected laws to show cascade modal
		if (confirmed > 0) {
			try {
				const affected = await getAffectedLaws(sessionId);
				if (affected.total_affected > 0 || affected.total_enacting_parents > 0) {
					affectedLawsCount = affected.total_affected;
					// Show cascade modal after a brief delay
					setTimeout(() => {
						showCascadeModal = true;
					}, 500);
				}
			} catch (e) {
				console.error('Failed to check affected laws:', e);
			}
		}
	}

	function handleCascadeModalClose() {
		showCascadeModal = false;
	}

	function handleCascadeComplete(event: CustomEvent<{ reparsed: number; errors: number }>) {
		showCascadeModal = false;
		const { reparsed, errors } = event.detail;
		if (reparsed > 0 || errors > 0) {
			parseCompleteMessage = `Cascade update: ${reparsed} re-parsed, ${errors} errors`;
		}
		$sessionQuery.refetch();
		// Refresh cascade status to update pending/processed counts
		fetchCascadeStatus();
	}

	function handleCascadeReviewLaws(event: CustomEvent<{ laws: AffectedLaw[]; stages?: import('$lib/api/scraper').ParseStage[] }>) {
		// Close cascade modal and open parse review modal with the selected laws
		showCascadeModal = false;
		const { laws, stages } = event.detail;
		// Convert AffectedLaw[] to ScrapeRecord[] format (ParseReviewModal uses name field)
		parseModalRecords = laws.map((law) => ({
			name: law.name,
			Title_EN: law.title_en || law.name,
			type_code: law.type_code || '',
			Year: law.year || 0,
			Number: ''
		}));
		parseModalStartIndex = 0;
		parseModalStages = stages;
		parseCompleteMessage = '';
		showParseModal = true;
	}

	async function handleShowCascadeModal() {
		showCascadeModal = true;
	}

	function handleRowClick(record: ScrapeRecord, index: number) {
		// Open modal for single record
		parseModalRecords = [record];
		parseModalStartIndex = 0;
		parseModalStages = undefined;
		parseCompleteMessage = '';
		showParseModal = true;
	}

	async function handleSelectAll() {
		const names = records.map((r) => r.name);
		await $selectionMutation.mutateAsync({
			sessionId,
			group: activeGroup,
			names,
			selected: true
		});
	}

	async function handleDeselectAll() {
		const names = records.map((r) => r.name);
		await $selectionMutation.mutateAsync({
			sessionId,
			group: activeGroup,
			names,
			selected: false
		});
	}

	async function handleToggleRecord(record: ScrapeRecord) {
		await $selectionMutation.mutateAsync({
			sessionId,
			group: activeGroup,
			names: [record.name],
			selected: !record.selected
		});
	}

	async function handleToggleAll() {
		if (allSelected) {
			await handleDeselectAll();
		} else {
			await handleSelectAll();
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
			<div class="mt-6 grid grid-cols-2 md:grid-cols-6 gap-4">
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
					<p class="text-sm text-purple-600">In DB</p>
					{#if $dbStatusQuery.isLoading}
						<p class="text-2xl font-semibold text-purple-700">...</p>
					{:else if $dbStatusQuery.data}
						<p class="text-2xl font-semibold text-purple-700">
							{$dbStatusQuery.data.existing_in_db}
							<span class="text-sm font-normal text-purple-500">
								/ {$dbStatusQuery.data.total_records}
							</span>
						</p>
					{:else}
						<p class="text-2xl font-semibold text-purple-700">-</p>
					{/if}
				</div>
				<div class="bg-amber-50 rounded-lg p-4">
					<p class="text-sm text-amber-600">This Session</p>
					<p class="text-2xl font-semibold text-amber-700">{session.persisted_count}</p>
				</div>
			</div>

			<!-- Session Actions - Cascade Update -->
			{#if cascadePendingCount > 0 || cascadeProcessedCount > 0}
				<div class="mt-4 flex items-center space-x-3">
					<button
						on:click={handleShowCascadeModal}
						class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white {cascadePendingCount >
						0
							? 'bg-indigo-600 hover:bg-indigo-700'
							: 'bg-gray-500 hover:bg-gray-600'} focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
					>
						<svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
							/>
						</svg>
						Cascade Update
						{#if cascadePendingCount > 0}
							<span class="ml-2 py-0.5 px-2 rounded-full text-xs bg-white text-indigo-700">
								{cascadePendingCount} pending
							</span>
						{/if}
					</button>
					<span class="text-sm text-gray-500">
						{#if cascadePendingCount > 0}
							{cascadePendingCount} laws need updating
						{:else}
							{cascadeProcessedCount} processed (all complete)
						{/if}
					</span>
				</div>
			{/if}

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
			<div class="p-4 border-b border-gray-200 flex justify-between items-center">
				<div class="flex items-center space-x-2">
					<!-- Data Source Badge -->
					{#if $groupQuery.data?.data_source}
						{@const isDb = $groupQuery.data.data_source === 'db'}
						<span
							class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {isDb
								? 'bg-green-100 text-green-800'
								: 'bg-yellow-100 text-yellow-800'}"
							title={isDb ? 'Data loaded from database' : 'Data loaded from JSON files (legacy)'}
						>
							{#if isDb}
								<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
									<path
										d="M3 12v3c0 1.657 3.134 3 7 3s7-1.343 7-3v-3c0 1.657-3.134 3-7 3s-7-1.343-7-3z"
									/>
									<path
										d="M3 7v3c0 1.657 3.134 3 7 3s7-1.343 7-3V7c0 1.657-3.134 3-7 3S3 8.657 3 7z"
									/>
									<path d="M17 5c0 1.657-3.134 3-7 3S3 6.657 3 5s3.134-3 7-3 7 1.343 7 3z" />
								</svg>
								DB
							{:else}
								<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
									<path
										fill-rule="evenodd"
										d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z"
										clip-rule="evenodd"
									/>
								</svg>
								JSON
							{/if}
						</span>
					{/if}
					<button
						on:click={handleSelectAll}
						disabled={$selectionMutation.isPending || records.length === 0}
						class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:bg-gray-100 disabled:cursor-not-allowed"
					>
						Select All
					</button>
					<button
						on:click={handleDeselectAll}
						disabled={$selectionMutation.isPending || selectedCount === 0}
						class="inline-flex items-center px-3 py-1.5 border border-gray-300 text-xs font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 disabled:bg-gray-100 disabled:cursor-not-allowed"
					>
						Deselect All
					</button>
					{#if selectedCount > 0}
						<span class="text-sm text-gray-500">
							{selectedCount} of {records.length} selected
						</span>
					{/if}
				</div>
				<div class="flex items-center space-x-2">
					<button
						on:click={handleInteractiveParse}
						disabled={records.length === 0}
						class="inline-flex items-center px-4 py-2 border border-blue-600 text-sm font-medium rounded-md text-blue-600 bg-white hover:bg-blue-50 disabled:border-gray-300 disabled:text-gray-400 disabled:cursor-not-allowed"
					>
						{#if selectedCount > 0}
							Review Selected ({selectedCount})
						{:else}
							Review All ({records.length})
						{/if}
					</button>
					<button
						on:click={handleParse}
						disabled={$parseMutation.isPending || records.length === 0}
						class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed"
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
						{:else if selectedCount > 0}
							Auto Parse ({selectedCount})
						{:else}
							Auto Parse All ({records.length})
						{/if}
					</button>
				</div>
			</div>

			<!-- Mutation Results -->
			{#if parseCompleteMessage}
				<div class="mx-4 mt-4 rounded-md bg-green-50 p-4 flex justify-between items-center">
					<p class="text-sm text-green-700">{parseCompleteMessage}</p>
					<button
						on:click={() => (parseCompleteMessage = '')}
						class="text-green-600 hover:text-green-800"
					>
						<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M6 18L18 6M6 6l12 12"
							/>
						</svg>
					</button>
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
									<th class="px-4 py-3 w-10">
										<input
											type="checkbox"
											checked={allSelected}
											indeterminate={someSelected}
											on:change={handleToggleAll}
											disabled={$selectionMutation.isPending}
											class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded cursor-pointer disabled:cursor-not-allowed"
										/>
									</th>
									<th
										class="px-2 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider w-12"
										title="Already exists in database"
									>
										In DB
									</th>
									<th
										class="px-2 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider w-24"
										title="Last updated in database"
									>
										Updated
									</th>
									{#if activeGroup === 3}
										<th
											class="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
										>
											#
										</th>
									{/if}
									<th
										class="px-2 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider max-w-xs"
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
											class="px-2 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider max-w-[150px]"
										>
											SI Codes
										</th>
									{/if}
									<th
										class="px-4 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider"
									>
										Actions
									</th>
								</tr>
							</thead>
							<tbody class="bg-white divide-y divide-gray-200">
								{#each $groupQuery.data.records as record}
									{@const inDb = existingNamesSet.has(record.name)}
									<tr
										class="hover:bg-gray-50 {record.selected ? 'bg-blue-50' : ''} {inDb
											? 'bg-purple-50/50'
											: ''}"
									>
										<td class="px-4 py-3">
											<input
												type="checkbox"
												checked={record.selected ?? false}
												on:change={() => handleToggleRecord(record)}
												disabled={$selectionMutation.isPending}
												class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded cursor-pointer disabled:cursor-not-allowed"
											/>
										</td>
										<td class="px-4 py-3 text-center">
											{#if inDb}
												<span
													class="inline-flex items-center justify-center w-6 h-6 rounded-full bg-purple-100 text-purple-700"
													title="Exists in database"
												>
													<svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
														<path
															fill-rule="evenodd"
															d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
															clip-rule="evenodd"
														/>
													</svg>
												</span>
											{:else}
												<span class="text-gray-300">-</span>
											{/if}
										</td>
										<td class="px-2 py-3 text-sm text-gray-500 whitespace-nowrap">
											{formatUpdatedAt($dbStatusQuery.data?.updated_at_map?.[record.name])}
										</td>
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
										<td class="px-4 py-3 text-right">
											<button
												on:click|stopPropagation={() => handleRowClick(record, 0)}
												class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded"
												title="Parse and review this record"
											>
												<svg
													class="w-4 h-4 mr-1"
													fill="none"
													stroke="currentColor"
													viewBox="0 0 24 24"
												>
													<path
														stroke-linecap="round"
														stroke-linejoin="round"
														stroke-width="2"
														d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
													/>
													<path
														stroke-linecap="round"
														stroke-linejoin="round"
														stroke-width="2"
														d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"
													/>
												</svg>
												Review
											</button>
										</td>
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

<!-- Parse Review Modal -->
<ParseReviewModal
	{sessionId}
	records={parseModalRecords}
	initialIndex={parseModalStartIndex}
	stages={parseModalStages}
	open={showParseModal}
	on:close={handleParseModalClose}
	on:complete={handleParseComplete}
/>

<!-- Cascade Update Modal -->
<CascadeUpdateModal
	{sessionId}
	open={showCascadeModal}
	on:close={handleCascadeModalClose}
	on:complete={handleCascadeComplete}
	on:reviewLaws={handleCascadeReviewLaws}
/>
