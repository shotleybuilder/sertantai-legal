<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	interface ActivityEvent {
		id: string;
		law_name: string;
		event: string;
		actor: string;
		status_before: string | null;
		status_after: string;
		source: string;
		metadata: Record<string, unknown> | null;
		inserted_at: string;
	}

	let events: ActivityEvent[] = [];
	let total = 0;
	let loading = true;
	let offset = 0;
	const limit = 50;

	async function loadEvents() {
		loading = true;
		try {
			const res = await authFetch(
				`${API_URL}/api/screening/events?limit=${limit}&offset=${offset}`
			);
			if (res.ok) {
				const data = await res.json();
				events = data.events;
				total = data.total;
			}
		} catch (err) {
			console.error('Failed to load events:', err);
		} finally {
			loading = false;
		}
	}

	function nextPage() {
		if (offset + limit < total) {
			offset += limit;
			loadEvents();
		}
	}

	function prevPage() {
		if (offset > 0) {
			offset = Math.max(0, offset - limit);
			loadEvents();
		}
	}

	function getMatchFamily(metadata: Record<string, unknown> | null): string {
		if (!metadata || !metadata['match_reason']) return '';
		const reason = metadata['match_reason'];
		if (typeof reason === 'object' && reason !== null && 'family' in reason) {
			return String((reason as Record<string, unknown>)['family'] || '');
		}
		return '';
	}

	function getMatchScore(metadata: Record<string, unknown> | null): string {
		if (!metadata || !metadata['match_reason']) return '';
		const reason = metadata['match_reason'];
		if (typeof reason === 'object' && reason !== null && 'score' in reason) {
			return String((reason as Record<string, unknown>)['score'] || '');
		}
		return '';
	}

	function formatTime(dateStr: string): string {
		return new Date(dateStr).toLocaleString('en-GB', {
			day: '2-digit',
			month: 'short',
			hour: '2-digit',
			minute: '2-digit'
		});
	}

	function eventIcon(event: string): string {
		switch (event) {
			case 'added':
				return '+';
			case 'seeded':
				return '🌱';
			case 'removed':
				return '×';
			case 'excluded':
				return '⊘';
			case 'confirmed':
				return '✓';
			case 'restored':
				return '↺';
			default:
				return '•';
		}
	}

	function eventColor(event: string): string {
		switch (event) {
			case 'added':
			case 'confirmed':
				return 'text-emerald-600';
			case 'seeded':
				return 'text-violet-600';
			case 'removed':
				return 'text-red-500';
			case 'excluded':
				return 'text-gray-500';
			case 'restored':
				return 'text-blue-600';
			default:
				return 'text-gray-600';
		}
	}

	function eventBgColor(event: string): string {
		switch (event) {
			case 'added':
			case 'confirmed':
				return 'bg-emerald-50';
			case 'seeded':
				return 'bg-violet-50';
			case 'removed':
				return 'bg-red-50';
			case 'excluded':
				return 'bg-gray-50';
			case 'restored':
				return 'bg-blue-50';
			default:
				return 'bg-gray-50';
		}
	}

	function eventDescription(e: ActivityEvent): string {
		const actor = e.actor === 'sertantai' ? 'SertantAI' : e.actor;
		switch (e.event) {
			case 'added':
				return `${actor} added to register`;
			case 'seeded':
				return `${actor} seeded from profile`;
			case 'removed':
				return `${actor} removed from register`;
			case 'excluded':
				return `${actor} excluded`;
			case 'confirmed':
				return `${actor} confirmed (transferred ownership)`;
			case 'restored':
				return `${actor} restored to available`;
			default:
				return `${actor} — ${e.event}`;
		}
	}

	onMount(() => {
		if (browser) loadEvents();
	});
</script>

<svelte:head>
	<title>Activity Log - SertantAI</title>
</svelte:head>

<div class="h-full overflow-auto px-6 py-6 space-y-4 max-w-3xl mx-auto">
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">Activity Log</h1>
			<p class="mt-1 text-sm text-gray-500">
				{total} screening events
			</p>
		</div>
	</div>

	{#if loading}
		<div class="flex justify-center py-12">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
		</div>
	{:else if events.length === 0}
		<div class="text-center py-12 text-gray-500">
			<p>No screening activity yet.</p>
			<p class="text-sm mt-1">
				Go to <a href="/app/screening" class="text-emerald-600 underline">Screening</a> to start building
				your register.
			</p>
		</div>
	{:else}
		<div class="space-y-2">
			{#each events as event}
				<div
					class="flex items-start gap-3 px-4 py-3 rounded-lg border border-gray-100 {eventBgColor(
						event.event
					)}"
				>
					<span class="text-lg w-6 text-center flex-shrink-0 {eventColor(event.event)}">
						{eventIcon(event.event)}
					</span>
					<div class="flex-1 min-w-0">
						<div class="text-sm text-gray-900">
							<span class="font-mono text-xs text-gray-500">{event.law_name}</span>
						</div>
						<div class="text-sm {eventColor(event.event)}">
							{eventDescription(event)}
						</div>
						{#if event.metadata?.notes}
							<div class="text-xs text-gray-500 mt-0.5">
								Note: {event.metadata.notes}
							</div>
						{/if}
						{#if event.metadata && event.metadata['match_reason']}
							<div class="text-xs text-violet-500 mt-0.5">
								Score: {getMatchScore(event.metadata)}
								{#if getMatchFamily(event.metadata)}
									· {getMatchFamily(event.metadata)}
								{/if}
							</div>
						{/if}
					</div>
					<div class="text-xs text-gray-400 flex-shrink-0">
						{formatTime(event.inserted_at)}
					</div>
				</div>
			{/each}
		</div>

		<!-- Pagination -->
		{#if total > limit}
			<div class="flex items-center justify-between pt-2">
				<button
					on:click={prevPage}
					disabled={offset === 0}
					class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50"
				>
					Previous
				</button>
				<span class="text-sm text-gray-500">
					{offset + 1}–{Math.min(offset + limit, total)} of {total}
				</span>
				<button
					on:click={nextPage}
					disabled={offset + limit >= total}
					class="px-3 py-1.5 text-sm text-gray-600 border border-gray-300 rounded hover:bg-gray-50 disabled:opacity-50"
				>
					Next
				</button>
			</div>
		{/if}
	{/if}
</div>
