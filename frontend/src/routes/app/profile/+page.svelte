<script lang="ts">
	import { browser } from '$app/environment';
	import { onMount } from 'svelte';
	import { authFetch } from '$lib/api/client';

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	// Profile state
	let profile: Record<string, string[]> = {
		regions: [],
		activities: [],
		locations: [],
		materials: [],
		processes: [],
		sector: []
	};

	// Vocabulary (available tags per dimension)
	let vocabulary: Record<string, string[]> = {
		regions: [],
		activities: [],
		locations: [],
		materials: [],
		processes: [],
		sector: []
	};

	let loading = true;
	let saving = false;
	let lastSaved: Date | null = null;

	const DIMENSION_META: {
		key: string;
		label: string;
		description: string;
		icon: string;
	}[] = [
		{
			key: 'regions',
			label: 'Geographic Scope',
			description: 'Where does your organisation operate?',
			icon: '🌍'
		},
		{
			key: 'activities',
			label: 'Activities & Roles',
			description: 'What roles does your organisation play?',
			icon: '👤'
		},
		{
			key: 'locations',
			label: 'Site Types',
			description: 'What types of physical locations do you operate?',
			icon: '🏭'
		},
		{
			key: 'materials',
			label: 'Materials & Equipment',
			description: 'What substances or equipment do you work with?',
			icon: '⚗️'
		},
		{
			key: 'processes',
			label: 'Processes & Operations',
			description: 'What activities or operations do you perform?',
			icon: '⚙️'
		},
		{
			key: 'sector',
			label: 'Industry Sector',
			description: 'What industry sector are you in?',
			icon: '🏢'
		}
	];

	async function loadProfile() {
		try {
			const [profileRes, vocabRes] = await Promise.all([
				authFetch(`${API_URL}/api/screening/profile`),
				authFetch(`${API_URL}/api/screening/vocabulary`)
			]);

			if (profileRes.ok) {
				const data = await profileRes.json();
				profile = {
					regions: data.regions || [],
					activities: data.activities || [],
					locations: data.locations || [],
					materials: data.materials || [],
					processes: data.processes || [],
					sector: data.sector || []
				};
			}

			if (vocabRes.ok) {
				vocabulary = await vocabRes.json();
			}
		} catch (err) {
			console.error('Failed to load profile:', err);
		} finally {
			loading = false;
		}
	}

	async function saveProfile() {
		saving = true;
		try {
			const response = await authFetch(`${API_URL}/api/screening/profile`, {
				method: 'PUT',
				headers: { 'Content-Type': 'application/json' },
				body: JSON.stringify(profile)
			});
			if (response.ok) {
				lastSaved = new Date();
			}
		} catch (err) {
			console.error('Failed to save profile:', err);
		} finally {
			saving = false;
		}
	}

	function toggleTag(dimension: string, tag: string) {
		const current = profile[dimension] || [];
		if (current.includes(tag)) {
			profile[dimension] = current.filter((t) => t !== tag);
		} else {
			profile[dimension] = [...current, tag];
		}
		profile = profile; // trigger reactivity
		// Auto-save on every change
		saveProfile();
	}

	function isSelected(dimension: string, tag: string): boolean {
		return (profile[dimension] || []).includes(tag);
	}

	$: totalTags = Object.values(profile).reduce((sum, arr) => sum + arr.length, 0);
	$: dimensionsUsed = Object.values(profile).filter((arr) => arr.length > 0).length;

	onMount(async () => {
		if (browser) {
			await loadProfile();
		}
	});
</script>

<svelte:head>
	<title>Organisation Profile - SertantAI</title>
</svelte:head>

<div class="overflow-auto px-6 py-6 space-y-6 max-w-4xl mx-auto">
	<div class="flex items-center justify-between">
		<div>
			<h1 class="text-2xl font-bold text-gray-900">Organisation Profile</h1>
			<p class="mt-1 text-sm text-gray-500">
				Describe your organisation to help SertantAI identify applicable laws.
			</p>
		</div>
		<div class="text-right">
			{#if saving}
				<span class="text-sm text-gray-400">Saving...</span>
			{:else if lastSaved}
				<span class="text-sm text-green-600">Saved</span>
			{/if}
			<div class="text-xs text-gray-400 mt-1">
				{totalTags} tags across {dimensionsUsed} dimensions
			</div>
		</div>
	</div>

	{#if loading}
		<div class="flex justify-center py-12">
			<div
				class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-emerald-600"
			></div>
		</div>
	{:else}
		<div class="space-y-6">
			{#each DIMENSION_META as dim}
				{@const tags = vocabulary[dim.key] || []}
				{@const selected = profile[dim.key] || []}
				<div class="bg-white rounded-lg border border-gray-200 p-5">
					<div class="flex items-center gap-2 mb-1">
						<span class="text-lg">{dim.icon}</span>
						<h2 class="text-sm font-semibold text-gray-800">{dim.label}</h2>
						{#if selected.length > 0}
							<span
								class="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700"
							>
								{selected.length}
							</span>
						{/if}
					</div>
					<p class="text-xs text-gray-500 mb-3">{dim.description}</p>

					{#if tags.length === 0}
						<p class="text-xs text-gray-400 italic">No tags available for this dimension yet.</p>
					{:else}
						<div class="flex flex-wrap gap-1.5">
							{#each tags as tag (dim.key + ':' + tag + ':' + selected.includes(tag))}
								<button
									on:click={() => toggleTag(dim.key, tag)}
									class="px-2.5 py-1 text-xs rounded-full border transition-colors
										{selected.includes(tag)
										? 'bg-emerald-100 border-emerald-300 text-emerald-800 font-medium'
										: 'bg-gray-50 border-gray-200 text-gray-600 hover:bg-gray-100 hover:border-gray-300'}"
								>
									{tag}
								</button>
							{/each}
						</div>
					{/if}
				</div>
			{/each}
		</div>

		<!-- Summary -->
		{#if totalTags > 0}
			<div class="bg-emerald-50 rounded-lg border border-emerald-200 p-4">
				<h3 class="text-sm font-semibold text-emerald-800 mb-2">Profile Summary</h3>
				<div class="grid grid-cols-2 md:grid-cols-3 gap-3">
					{#each DIMENSION_META as dim}
						{@const selected = profile[dim.key] || []}
						{#if selected.length > 0}
							<div>
								<div class="text-xs text-emerald-600 font-medium">{dim.label}</div>
								<div class="text-xs text-emerald-800">{selected.join(', ')}</div>
							</div>
						{/if}
					{/each}
				</div>
				<p class="text-xs text-emerald-600 mt-3">
					Go to <a href="/app/screening" class="underline font-medium">Screening</a> and press "Seed My
					Register" to find matching laws.
				</p>
			</div>
		{/if}
	{/if}
</div>
