<script lang="ts">
	import { onMount } from 'svelte';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	interface ChangeSummary {
		total_pending: number;
		overdue: number;
		by_materiality: { major: number; moderate: number; minor: number; informational: number };
		by_event: {
			law_status_changed: number;
			new_law_available: number;
			match_score_changed: number;
		};
	}

	interface ChangeEvent {
		id: string;
		law_name: string;
		event: string;
		materiality: string;
		review_due_date: string | null;
		decision: string | null;
		decision_reason: string | null;
		metadata: Record<string, unknown>;
		inserted_at: string;
		title: string | null;
		overdue: boolean;
	}

	let summary: ChangeSummary | null = null;
	let changes: ChangeEvent[] = [];
	let loading = true;
	let filter: string | null = null;
	let decidingId: string | null = null;
	let decisionReason = '';

	const materialityColors: Record<string, { bg: string; text: string; label: string }> = {
		major: { bg: 'bg-red-100', text: 'text-red-800', label: 'Major' },
		moderate: { bg: 'bg-amber-100', text: 'text-amber-800', label: 'Moderate' },
		minor: { bg: 'bg-blue-100', text: 'text-blue-800', label: 'Minor' },
		informational: { bg: 'bg-gray-100', text: 'text-gray-600', label: 'Info' }
	};

	const eventLabels: Record<string, string> = {
		law_status_changed: 'Status Changed',
		new_law_available: 'New Match',
		match_score_changed: 'Score Changed'
	};

	const eventGroupOrder = ['law_status_changed', 'new_law_available', 'match_score_changed'];
	const eventGroupLabels: Record<string, string> = {
		law_status_changed: 'Repealed / Status Changes',
		new_law_available: 'New Law Matches',
		match_score_changed: 'Enrichment Updates'
	};

	let groupByEvent = true;

	function groupChanges(
		items: ChangeEvent[]
	): { label: string; event: string; items: ChangeEvent[] }[] {
		const groups: Record<string, ChangeEvent[]> = {};
		for (const item of items) {
			(groups[item.event] ??= []).push(item);
		}
		return eventGroupOrder
			.filter((e) => groups[e]?.length)
			.map((e) => ({ label: eventGroupLabels[e] || e, event: e, items: groups[e] }));
	}

	async function load() {
		loading = true;
		const [summaryRes, changesRes] = await Promise.all([
			authFetch(`${API_URL}/api/screening/changes/summary`),
			authFetch(`${API_URL}/api/screening/changes${filter ? `?materiality=${filter}` : ''}`)
		]);

		if (summaryRes.ok) summary = await summaryRes.json();
		if (changesRes.ok) {
			const data = await changesRes.json();
			changes = data.changes || [];
		}
		loading = false;
	}

	async function decide(eventId: string, decision: string) {
		const body: Record<string, string> = { decision };
		if (decisionReason) body.decision_reason = decisionReason;

		const res = await authFetch(`${API_URL}/api/screening/changes/${eventId}/decide`, {
			method: 'PUT',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify(body)
		});

		if (res.ok) {
			decidingId = null;
			decisionReason = '';
			await load();
		} else {
			const err = await res.json();
			alert(err.error || 'Failed to record decision');
		}
	}

	function setFilter(mat: string | null) {
		filter = filter === mat ? null : mat;
		load();
	}

	onMount(load);
</script>

<div class="h-full overflow-y-auto">
	<div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
		<h1 class="text-2xl font-bold text-gray-900 mb-6">Change Review</h1>

		{#if loading && !summary}
			<p class="text-gray-500">Loading...</p>
		{:else if summary}
			<!-- Summary cards -->
			{@const matCards = [
				{ key: 'major', count: summary.by_materiality.major },
				{ key: 'moderate', count: summary.by_materiality.moderate },
				{ key: 'minor', count: summary.by_materiality.minor },
				{ key: 'informational', count: summary.by_materiality.informational }
			]}
			<div class="grid grid-cols-2 sm:grid-cols-4 gap-3 mb-6">
				{#each matCards as card}
					{@const mc = materialityColors[card.key]}
					<button
						on:click={() => setFilter(card.key)}
						class="rounded-lg p-4 text-left transition-all
							{filter === card.key ? 'ring-2 ring-emerald-500' : ''}
							{mc.bg}"
					>
						<div class="text-2xl font-bold {mc.text}">{card.count}</div>
						<div class="text-sm {mc.text}">{mc.label}</div>
					</button>
				{/each}
			</div>

			{#if summary.overdue > 0}
				<div class="mb-4 px-4 py-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-800">
					{summary.overdue} change{summary.overdue === 1 ? '' : 's'} overdue for review
				</div>
			{/if}

			<!-- Group toggle -->
			{#if changes.length > 0}
				<div class="flex items-center gap-2 mb-4">
					<button
						on:click={() => (groupByEvent = !groupByEvent)}
						class="text-sm text-gray-500 hover:text-gray-700"
					>
						{groupByEvent ? 'Flat view' : 'Group by type'}
					</button>
				</div>
			{/if}

			<!-- Changes list -->
			{#if changes.length === 0}
				<div class="text-center py-12 text-gray-500">
					{#if filter}
						No {filter} changes pending.
						<button on:click={() => setFilter(null)} class="text-emerald-600 underline ml-1"
							>Clear filter</button
						>
					{:else}
						No pending changes. Your register is up to date.
					{/if}
				</div>
			{:else if groupByEvent}
				{#each groupChanges(changes) as group}
					<div class="mb-6">
						<h2 class="text-sm font-semibold text-gray-700 uppercase tracking-wide mb-3">
							{group.label}
							<span class="text-gray-400 font-normal">({group.items.length})</span>
						</h2>
						<div class="space-y-3">
							{#each group.items as change (change.id)}
								{@const mc =
									materialityColors[change.materiality] || materialityColors.informational}
								<div
									class="bg-white rounded-lg border p-4
										{change.overdue ? 'border-red-300' : 'border-gray-200'}"
								>
									<div class="flex items-start justify-between gap-4">
										<div class="flex-1 min-w-0">
											<div class="flex items-center gap-2 mb-1">
												<span
													class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {mc.bg} {mc.text}"
												>
													{mc.label}
												</span>
												{#if change.overdue}
													<span class="text-xs font-medium text-red-600">Overdue</span>
												{/if}
											</div>
											<div class="font-medium text-gray-900 truncate">
												{change.title || change.law_name}
											</div>
											<div class="text-sm text-gray-500 mt-0.5">
												{change.law_name}
												{#if change.metadata?.change_type}
													&middot; {change.metadata.change_type}
												{/if}
												{#if change.review_due_date}
													&middot; Due {change.review_due_date}
												{/if}
											</div>
										</div>

										<div class="flex-shrink-0 flex items-center gap-2">
											{#if decidingId === change.id}
												<div class="flex items-center gap-2">
													{#if change.materiality === 'major' || change.materiality === 'moderate'}
														<input
															type="text"
															bind:value={decisionReason}
															placeholder="Reason (required)"
															class="text-sm border rounded px-2 py-1 w-48"
														/>
													{/if}
													{#if change.event === 'law_status_changed'}
														<button
															on:click={() => decide(change.id, 'archive')}
															class="px-2 py-1 text-xs bg-red-100 text-red-700 rounded hover:bg-red-200"
															>Archive</button
														>
														<button
															on:click={() => decide(change.id, 'keep')}
															class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded hover:bg-green-200"
															>Keep</button
														>
													{:else if change.event === 'new_law_available'}
														<button
															on:click={() => decide(change.id, 'add')}
															class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded hover:bg-green-200"
															>Add</button
														>
														<button
															on:click={() => decide(change.id, 'dismiss')}
															class="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
															>Dismiss</button
														>
													{:else}
														<button
															on:click={() => decide(change.id, 'keep')}
															class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded hover:bg-green-200"
															>Acknowledge</button
														>
													{/if}
													<button
														on:click={() => {
															decidingId = null;
															decisionReason = '';
														}}
														class="px-2 py-1 text-xs text-gray-500 hover:text-gray-700"
														>Cancel</button
													>
												</div>
											{:else}
												<button
													on:click={() => (decidingId = change.id)}
													class="px-3 py-1.5 text-xs font-medium bg-emerald-100 text-emerald-700 rounded-md hover:bg-emerald-200"
												>
													Review
												</button>
											{/if}
										</div>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/each}
			{:else}
				<div class="space-y-3">
					{#each changes as change (change.id)}
						{@const mc = materialityColors[change.materiality] || materialityColors.informational}
						<div
							class="bg-white rounded-lg border p-4
								{change.overdue ? 'border-red-300' : 'border-gray-200'}"
						>
							<div class="flex items-start justify-between gap-4">
								<div class="flex-1 min-w-0">
									<div class="flex items-center gap-2 mb-1">
										<span
											class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium {mc.bg} {mc.text}"
										>
											{mc.label}
										</span>
										<span class="text-xs text-gray-500">
											{eventLabels[change.event] || change.event}
										</span>
										{#if change.overdue}
											<span class="text-xs font-medium text-red-600">Overdue</span>
										{/if}
									</div>
									<div class="font-medium text-gray-900 truncate">
										{change.title || change.law_name}
									</div>
									<div class="text-sm text-gray-500 mt-0.5">
										{change.law_name}
										{#if change.metadata?.change_type}
											&middot; {change.metadata.change_type}
										{/if}
										{#if change.review_due_date}
											&middot; Due {change.review_due_date}
										{/if}
									</div>
								</div>

								<div class="flex-shrink-0 flex items-center gap-2">
									{#if decidingId === change.id}
										<div class="flex items-center gap-2">
											{#if change.materiality === 'major' || change.materiality === 'moderate'}
												<input
													type="text"
													bind:value={decisionReason}
													placeholder="Reason (required)"
													class="text-sm border rounded px-2 py-1 w-48"
												/>
											{/if}
											{#if change.event === 'law_status_changed'}
												<button
													on:click={() => decide(change.id, 'archive')}
													class="px-2 py-1 text-xs bg-red-100 text-red-700 rounded hover:bg-red-200"
													>Archive</button
												>
												<button
													on:click={() => decide(change.id, 'keep')}
													class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded hover:bg-green-200"
													>Keep</button
												>
											{:else if change.event === 'new_law_available'}
												<button
													on:click={() => decide(change.id, 'add')}
													class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded hover:bg-green-200"
													>Add</button
												>
												<button
													on:click={() => decide(change.id, 'dismiss')}
													class="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded hover:bg-gray-200"
													>Dismiss</button
												>
											{:else}
												<button
													on:click={() => decide(change.id, 'keep')}
													class="px-2 py-1 text-xs bg-green-100 text-green-700 rounded hover:bg-green-200"
													>Acknowledge</button
												>
											{/if}
											<button
												on:click={() => {
													decidingId = null;
													decisionReason = '';
												}}
												class="px-2 py-1 text-xs text-gray-500 hover:text-gray-700">Cancel</button
											>
										</div>
									{:else}
										<button
											on:click={() => (decidingId = change.id)}
											class="px-3 py-1.5 text-xs font-medium bg-emerald-100 text-emerald-700 rounded-md hover:bg-emerald-200"
										>
											Review
										</button>
									{/if}
								</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		{/if}
	</div>
</div>
