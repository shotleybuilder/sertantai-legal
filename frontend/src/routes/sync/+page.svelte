<script lang="ts">
	import { onMount } from 'svelte';
	import {
		fetchEntitlement,
		fetchProfiles,
		fetchConfigurations,
		fetchJobs,
		createProfile,
		deleteProfile,
		createConfiguration,
		testConnection,
		triggerSync,
		previewProfile,
		type OrgEntitlement,
		type SyncProfile,
		type SyncConfiguration,
		type SyncJob
	} from '$lib/api/sync';

	let entitlement: OrgEntitlement | null = null;
	let profiles: SyncProfile[] = [];
	let configurations: SyncConfiguration[] = [];
	let jobs: SyncJob[] = [];
	let loading = true;
	let error = '';

	// Form state
	let showProfileForm = false;
	let showConfigForm = false;
	let profileForm = {
		name: '',
		families: [] as string[],
		geo_regions: null as string[] | null,
		function_filter: null as Record<string, unknown> | null,
		fitness_person: null as string[] | null,
		fitness_process: null as string[] | null,
		fitness_place: null as string[] | null,
		fitness_plant: null as string[] | null,
		fitness_sector: null as string[] | null,
		live_filter: null as string[] | null,
		include_lat: false,
		include_amendments: false
	};
	let configForm = {
		name: '',
		sync_profile_id: '',
		provider: 'baserow' as const,
		base_url: '',
		lrt_table_id: '',
		lat_table_id: '',
		database_token: '',
		sync_frequency: 'manual' as 'manual' | 'daily' | 'weekly',
		on_filter_change: 'delete' as 'delete' | 'retain',
		on_entitlement_change: 'delete' as 'delete' | 'retain'
	};

	let previewCount: { matched_law_count: number; matched_lat_count: number } | null = null;
	let testResult: { ok: boolean; info?: Record<string, unknown>; error?: string } | null = null;
	let actionMessage = '';

	onMount(async () => {
		await loadAll();
	});

	async function loadAll() {
		loading = true;
		error = '';
		try {
			[entitlement, profiles, configurations, jobs] = await Promise.all([
				fetchEntitlement().catch(() => null),
				fetchProfiles().catch(() => []),
				fetchConfigurations().catch(() => []),
				fetchJobs().catch(() => [])
			]);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to load';
		}
		loading = false;
	}

	async function handleCreateProfile() {
		try {
			await createProfile(profileForm);
			showProfileForm = false;
			resetProfileForm();
			await loadAll();
			actionMessage = 'Profile created';
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to create profile';
		}
	}

	async function handleDeleteProfile(id: string) {
		if (!confirm('Delete this profile?')) return;
		try {
			await deleteProfile(id);
			await loadAll();
			actionMessage = 'Profile deleted';
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to delete';
		}
	}

	async function handlePreview() {
		try {
			previewCount = await previewProfile(profileForm);
		} catch (e) {
			error = e instanceof Error ? e.message : 'Preview failed';
		}
	}

	async function handleCreateConfig() {
		try {
			await createConfiguration({
				name: configForm.name,
				sync_profile_id: configForm.sync_profile_id,
				provider: configForm.provider,
				credentials: { database_token: configForm.database_token },
				target_config: {
					base_url: configForm.base_url,
					lrt_table_id: parseInt(configForm.lrt_table_id) || null,
					lat_table_id: configForm.lat_table_id ? parseInt(configForm.lat_table_id) : null
				},
				sync_frequency: configForm.sync_frequency,
				on_filter_change: configForm.on_filter_change,
				on_entitlement_change: configForm.on_entitlement_change
			});
			showConfigForm = false;
			resetConfigForm();
			await loadAll();
			actionMessage = 'Configuration created';
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to create configuration';
		}
	}

	async function handleTestConnection(id: string) {
		testResult = null;
		try {
			testResult = await testConnection(id);
		} catch (e) {
			testResult = { ok: false, error: e instanceof Error ? e.message : 'Test failed' };
		}
	}

	async function handleTriggerSync(id: string) {
		try {
			await triggerSync(id);
			actionMessage = 'Sync queued';
			await loadAll();
		} catch (e) {
			error = e instanceof Error ? e.message : 'Failed to trigger sync';
		}
	}

	function resetProfileForm() {
		profileForm = {
			name: '', families: [], geo_regions: null, function_filter: null,
			fitness_person: null, fitness_process: null, fitness_place: null,
			fitness_plant: null, fitness_sector: null, live_filter: null,
			include_lat: false, include_amendments: false
		};
		previewCount = null;
	}

	function resetConfigForm() {
		configForm = {
			name: '', sync_profile_id: '', provider: 'baserow',
			base_url: '', lrt_table_id: '', lat_table_id: '', database_token: '',
			sync_frequency: 'manual', on_filter_change: 'delete', on_entitlement_change: 'delete'
		};
		testResult = null;
	}

	function toggleFamily(family: string) {
		if (profileForm.families.includes(family)) {
			profileForm.families = profileForm.families.filter((f) => f !== family);
		} else {
			profileForm.families = [...profileForm.families, family];
		}
	}

	function statusColor(status: string): string {
		switch (status) {
			case 'completed': return 'bg-green-100 text-green-700';
			case 'running': case 'syncing': case 'queued': return 'bg-blue-100 text-blue-700';
			case 'failed': return 'bg-red-100 text-red-700';
			case 'idle': return 'bg-gray-100 text-gray-600';
			default: return 'bg-gray-100 text-gray-600';
		}
	}

	function formatDate(d: string | null): string {
		if (!d) return '-';
		return new Date(d).toLocaleString();
	}
</script>

<div class="space-y-8">
	<div class="flex items-center justify-between">
		<h1 class="text-2xl font-bold text-gray-900">Sync Service</h1>
		{#if actionMessage}
			<span class="rounded bg-green-100 px-3 py-1 text-sm text-green-700">{actionMessage}</span>
		{/if}
	</div>

	{#if loading}
		<div class="text-gray-500">Loading...</div>
	{:else}
		{#if error}
			<div class="rounded border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">{error}</div>
		{/if}

		<!-- Entitlement Section -->
		<section>
			<h2 class="mb-3 text-lg font-semibold text-gray-800">Entitlement</h2>
			{#if entitlement}
				<div class="rounded-lg border border-gray-200 bg-white p-4">
					<div class="grid grid-cols-3 gap-4 text-sm">
						<div>
							<span class="text-gray-500">Field Tier:</span>
							<span class="ml-1 font-medium">{entitlement.field_tier}</span>
						</div>
						<div>
							<span class="text-gray-500">Data Tier:</span>
							<span class="ml-1 font-medium">{entitlement.data_tier}</span>
						</div>
						<div>
							<span class="text-gray-500">Source:</span>
							<span class="ml-1 font-medium">{entitlement.source}</span>
						</div>
					</div>
					<div class="mt-3">
						<span class="text-sm text-gray-500">Families ({entitlement.families.length}):</span>
						<div class="mt-1 flex flex-wrap gap-1">
							{#each entitlement.families as family}
								<span class="rounded bg-gray-100 px-2 py-0.5 text-xs text-gray-700">{family}</span>
							{/each}
						</div>
					</div>
				</div>
			{:else}
				<div class="rounded-lg border border-amber-200 bg-amber-50 p-4 text-sm text-amber-700">
					No entitlement found. Entitlements are pushed from the Hub when your organisation subscribes.
				</div>
			{/if}
		</section>

		<!-- Profiles Section -->
		<section>
			<div class="mb-3 flex items-center justify-between">
				<h2 class="text-lg font-semibold text-gray-800">Sync Profiles</h2>
				<button
					on:click={() => { showProfileForm = !showProfileForm; if (!showProfileForm) resetProfileForm(); }}
					class="rounded bg-blue-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-700"
				>
					{showProfileForm ? 'Cancel' : 'New Profile'}
				</button>
			</div>

			{#if showProfileForm}
				<div class="mb-4 rounded-lg border border-blue-200 bg-white p-4">
					<div class="space-y-4">
						<div>
							<label for="profile-name" class="block text-sm font-medium text-gray-700">Name</label>
							<input id="profile-name" bind:value={profileForm.name} type="text" placeholder="e.g. Construction H&S"
								class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm" />
						</div>

						{#if entitlement}
							<div>
								<span class="block text-sm font-medium text-gray-700">Families</span>
								<div class="mt-1 max-h-48 overflow-y-auto rounded border border-gray-200 p-2">
									{#each entitlement.families as family}
										<label class="flex items-center gap-2 py-0.5 text-sm">
											<input type="checkbox" checked={profileForm.families.includes(family)}
												on:change={() => toggleFamily(family)} />
											{family}
										</label>
									{/each}
								</div>
							</div>
						{/if}

						<div class="grid grid-cols-2 gap-4">
							<label class="flex items-center gap-2 text-sm">
								<input type="checkbox" bind:checked={profileForm.include_lat} />
								Include LAT (article text)
							</label>
							<label class="flex items-center gap-2 text-sm">
								<input type="checkbox" bind:checked={profileForm.include_amendments} />
								Include amendments
							</label>
						</div>

						<div class="flex items-center gap-3">
							<button on:click={handlePreview}
								class="rounded border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-50"
								disabled={profileForm.families.length === 0}>
								Preview Count
							</button>
							{#if previewCount}
								<span class="text-sm text-gray-600">
									{previewCount.matched_law_count} laws, {previewCount.matched_lat_count} LAT rows
								</span>
							{/if}
						</div>

						<button on:click={handleCreateProfile}
							class="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
							disabled={!profileForm.name || profileForm.families.length === 0}>
							Create Profile
						</button>
					</div>
				</div>
			{/if}

			{#if profiles.length === 0}
				<p class="text-sm text-gray-500">No sync profiles yet.</p>
			{:else}
				<div class="space-y-2">
					{#each profiles as profile}
						<div class="flex items-center justify-between rounded-lg border border-gray-200 bg-white px-4 py-3">
							<div>
								<div class="flex items-center gap-2">
									<span class="font-medium text-gray-900">{profile.name}</span>
									{#if !profile.is_active}
										<span class="rounded bg-red-100 px-1.5 py-0.5 text-xs text-red-700">Inactive</span>
									{/if}
								</div>
								<div class="mt-1 text-xs text-gray-500">
									{profile.families.length} families
									{#if profile.matched_law_count != null}
										&middot; {profile.matched_law_count} laws
									{/if}
									{#if profile.include_lat}
										&middot; LAT
									{/if}
								</div>
							</div>
							<button on:click={() => handleDeleteProfile(profile.id)}
								class="text-sm text-red-500 hover:text-red-700">Delete</button>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Configurations Section -->
		<section>
			<div class="mb-3 flex items-center justify-between">
				<h2 class="text-lg font-semibold text-gray-800">Sync Configurations</h2>
				<button
					on:click={() => { showConfigForm = !showConfigForm; if (!showConfigForm) resetConfigForm(); }}
					class="rounded bg-blue-600 px-3 py-1.5 text-sm font-medium text-white hover:bg-blue-700"
					disabled={profiles.length === 0}
				>
					{showConfigForm ? 'Cancel' : 'New Configuration'}
				</button>
			</div>

			{#if showConfigForm}
				<div class="mb-4 rounded-lg border border-blue-200 bg-white p-4">
					<div class="space-y-4">
						<div class="grid grid-cols-2 gap-4">
							<div>
								<label for="config-name" class="block text-sm font-medium text-gray-700">Name</label>
								<input id="config-name" bind:value={configForm.name} type="text"
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm" />
							</div>
							<div>
								<label for="config-profile" class="block text-sm font-medium text-gray-700">Profile</label>
								<select id="config-profile" bind:value={configForm.sync_profile_id}
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm">
									<option value="">Select profile...</option>
									{#each profiles.filter(p => p.is_active) as p}
										<option value={p.id}>{p.name}</option>
									{/each}
								</select>
							</div>
						</div>

						<div class="grid grid-cols-2 gap-4">
							<div>
								<label for="config-url" class="block text-sm font-medium text-gray-700">Baserow URL</label>
								<input id="config-url" bind:value={configForm.base_url} type="text"
									placeholder="https://baserow.example.com"
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm" />
							</div>
							<div>
								<label for="config-token" class="block text-sm font-medium text-gray-700">Database Token</label>
								<input id="config-token" bind:value={configForm.database_token} type="password"
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm" />
							</div>
						</div>

						<div class="grid grid-cols-3 gap-4">
							<div>
								<label for="config-lrt" class="block text-sm font-medium text-gray-700">LRT Table ID</label>
								<input id="config-lrt" bind:value={configForm.lrt_table_id} type="text"
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm" />
							</div>
							<div>
								<label for="config-lat" class="block text-sm font-medium text-gray-700">LAT Table ID (optional)</label>
								<input id="config-lat" bind:value={configForm.lat_table_id} type="text"
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm" />
							</div>
							<div>
								<label for="config-freq" class="block text-sm font-medium text-gray-700">Frequency</label>
								<select id="config-freq" bind:value={configForm.sync_frequency}
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm">
									<option value="manual">Manual</option>
									<option value="daily">Daily</option>
									<option value="weekly">Weekly</option>
								</select>
							</div>
						</div>

						<div class="grid grid-cols-2 gap-4">
							<div>
								<label for="config-filter-change" class="block text-sm font-medium text-gray-700">On filter change</label>
								<select id="config-filter-change" bind:value={configForm.on_filter_change}
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm">
									<option value="delete">Delete rows from target</option>
									<option value="retain">Retain rows (stop updating)</option>
								</select>
							</div>
							<div>
								<label for="config-ent-change" class="block text-sm font-medium text-gray-700">On entitlement change</label>
								<select id="config-ent-change" bind:value={configForm.on_entitlement_change}
									class="mt-1 w-full rounded border border-gray-300 px-3 py-2 text-sm">
									<option value="delete">Delete rows from target</option>
									<option value="retain">Retain rows (stop updating)</option>
								</select>
							</div>
						</div>

						<button on:click={handleCreateConfig}
							class="rounded bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700"
							disabled={!configForm.name || !configForm.sync_profile_id || !configForm.base_url || !configForm.database_token || !configForm.lrt_table_id}>
							Create Configuration
						</button>
					</div>
				</div>
			{/if}

			{#if configurations.length === 0}
				<p class="text-sm text-gray-500">No sync configurations yet.</p>
			{:else}
				<div class="space-y-2">
					{#each configurations as config}
						<div class="rounded-lg border border-gray-200 bg-white px-4 py-3">
							<div class="flex items-center justify-between">
								<div>
									<div class="flex items-center gap-2">
										<span class="font-medium text-gray-900">{config.name}</span>
										<span class="rounded px-1.5 py-0.5 text-xs {statusColor(config.sync_status)}">
											{config.sync_status}
										</span>
										<span class="rounded bg-gray-100 px-1.5 py-0.5 text-xs text-gray-600">{config.provider}</span>
									</div>
									<div class="mt-1 text-xs text-gray-500">
										{config.sync_frequency}
										{#if config.last_synced_at}
											&middot; Last synced: {formatDate(config.last_synced_at)}
										{/if}
										{#if config.last_sync_summary}
											&middot; {config.last_sync_summary.rows_created} created
										{/if}
									</div>
								</div>
								<div class="flex items-center gap-2">
									<button on:click={() => handleTestConnection(config.id)}
										class="rounded border border-gray-300 px-2 py-1 text-xs hover:bg-gray-50">
										Test
									</button>
									<button on:click={() => handleTriggerSync(config.id)}
										class="rounded bg-green-600 px-2 py-1 text-xs font-medium text-white hover:bg-green-700"
										disabled={config.sync_status === 'syncing' || config.sync_status === 'queued'}>
										Sync Now
									</button>
								</div>
							</div>
							{#if testResult}
								<div class="mt-2 text-xs {testResult.ok ? 'text-green-600' : 'text-red-600'}">
									{testResult.ok ? 'Connection OK' : testResult.error}
								</div>
							{/if}
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Jobs Section -->
		<section>
			<h2 class="mb-3 text-lg font-semibold text-gray-800">Recent Jobs</h2>
			{#if jobs.length === 0}
				<p class="text-sm text-gray-500">No sync jobs yet.</p>
			{:else}
				<div class="overflow-hidden rounded-lg border border-gray-200 bg-white">
					<table class="w-full text-sm">
						<thead class="border-b border-gray-200 bg-gray-50">
							<tr>
								<th class="px-4 py-2 text-left font-medium text-gray-600">Status</th>
								<th class="px-4 py-2 text-left font-medium text-gray-600">Started</th>
								<th class="px-4 py-2 text-right font-medium text-gray-600">Laws</th>
								<th class="px-4 py-2 text-right font-medium text-gray-600">Created</th>
								<th class="px-4 py-2 text-right font-medium text-gray-600">Updated</th>
								<th class="px-4 py-2 text-right font-medium text-gray-600">Deleted</th>
								<th class="px-4 py-2 text-right font-medium text-gray-600">Failed</th>
								<th class="px-4 py-2 text-left font-medium text-gray-600">Error</th>
							</tr>
						</thead>
						<tbody>
							{#each jobs as job}
								<tr class="border-b border-gray-100">
									<td class="px-4 py-2">
										<span class="rounded px-1.5 py-0.5 text-xs {statusColor(job.status)}">{job.status}</span>
									</td>
									<td class="px-4 py-2 text-gray-600">{formatDate(job.started_at)}</td>
									<td class="px-4 py-2 text-right">{job.law_count ?? '-'}</td>
									<td class="px-4 py-2 text-right">{job.rows_created}</td>
									<td class="px-4 py-2 text-right">{job.rows_updated}</td>
									<td class="px-4 py-2 text-right">{job.rows_deleted}</td>
									<td class="px-4 py-2 text-right">{job.rows_failed}</td>
									<td class="px-4 py-2 text-red-600">{job.error_message || ''}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				</div>
			{/if}
		</section>
	{/if}
</div>
