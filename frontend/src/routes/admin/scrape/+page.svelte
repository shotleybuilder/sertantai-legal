<script lang="ts">
	import { goto } from '$app/navigation';
	import { useCreateScrapeMutation } from '$lib/query/scraper';

	const currentYear = new Date().getFullYear();
	const currentMonth = new Date().getMonth() + 1;

	let year = currentYear;
	let month = currentMonth;
	let dayFrom = 1;
	let dayTo = new Date().getDate();
	let typeCode = '';

	const mutation = useCreateScrapeMutation();

	async function handleSubmit() {
		try {
			const session = await $mutation.mutateAsync({
				year,
				month,
				day_from: dayFrom,
				day_to: dayTo,
				type_code: typeCode || undefined
			});
			// Navigate to session detail
			goto(`/admin/scrape/sessions/${session.session_id}`);
		} catch (error) {
			// Error is handled by mutation state
		}
	}

	// Generate month options
	const months = [
		{ value: 1, label: 'January' },
		{ value: 2, label: 'February' },
		{ value: 3, label: 'March' },
		{ value: 4, label: 'April' },
		{ value: 5, label: 'May' },
		{ value: 6, label: 'June' },
		{ value: 7, label: 'July' },
		{ value: 8, label: 'August' },
		{ value: 9, label: 'September' },
		{ value: 10, label: 'October' },
		{ value: 11, label: 'November' },
		{ value: 12, label: 'December' }
	];

	// Generate year options (last 5 years)
	const years = Array.from({ length: 5 }, (_, i) => currentYear - i);

	// Type codes
	const typeCodes = [
		{ value: '', label: 'All Types' },
		{ value: 'uksi', label: 'UK Statutory Instruments' },
		{ value: 'ukpga', label: 'UK Public General Acts' },
		{ value: 'ukla', label: 'UK Local Acts' },
		{ value: 'asp', label: 'Acts of the Scottish Parliament' },
		{ value: 'ssi', label: 'Scottish Statutory Instruments' },
		{ value: 'wsi', label: 'Wales Statutory Instruments' },
		{ value: 'nia', label: 'Acts of the Northern Ireland Assembly' },
		{ value: 'nisr', label: 'Northern Ireland Statutory Rules' }
	];
</script>

<div class="max-w-2xl">
	<h1 class="text-2xl font-bold text-gray-900 mb-6">New Scrape Session</h1>

	<div class="bg-white shadow rounded-lg p-6">
		<form on:submit|preventDefault={handleSubmit} class="space-y-6">
			<!-- Date Range -->
			<div>
				<h2 class="text-lg font-medium text-gray-900 mb-4">Date Range</h2>
				<p class="text-sm text-gray-500 mb-4">
					Select the date range to scrape from legislation.gov.uk
				</p>

				<div class="grid grid-cols-2 gap-4">
					<!-- Year -->
					<div>
						<label for="year" class="block text-sm font-medium text-gray-700">Year</label>
						<select
							id="year"
							bind:value={year}
							class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						>
							{#each years as y}
								<option value={y}>{y}</option>
							{/each}
						</select>
					</div>

					<!-- Month -->
					<div>
						<label for="month" class="block text-sm font-medium text-gray-700">Month</label>
						<select
							id="month"
							bind:value={month}
							class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						>
							{#each months as m}
								<option value={m.value}>{m.label}</option>
							{/each}
						</select>
					</div>

					<!-- Day From -->
					<div>
						<label for="dayFrom" class="block text-sm font-medium text-gray-700">From Day</label>
						<input
							type="number"
							id="dayFrom"
							bind:value={dayFrom}
							min="1"
							max="31"
							class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						/>
					</div>

					<!-- Day To -->
					<div>
						<label for="dayTo" class="block text-sm font-medium text-gray-700">To Day</label>
						<input
							type="number"
							id="dayTo"
							bind:value={dayTo}
							min="1"
							max="31"
							class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
						/>
					</div>
				</div>
			</div>

			<!-- Type Code Filter -->
			<div>
				<label for="typeCode" class="block text-sm font-medium text-gray-700">
					Legislation Type (Optional)
				</label>
				<select
					id="typeCode"
					bind:value={typeCode}
					class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
				>
					{#each typeCodes as tc}
						<option value={tc.value}>{tc.label}</option>
					{/each}
				</select>
				<p class="mt-1 text-sm text-gray-500">Leave as "All Types" to scrape all legislation</p>
			</div>

			<!-- Error Message -->
			{#if $mutation.isError}
				<div class="rounded-md bg-red-50 p-4">
					<div class="flex">
						<div class="flex-shrink-0">
							<svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
								<path
									fill-rule="evenodd"
									d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z"
									clip-rule="evenodd"
								/>
							</svg>
						</div>
						<div class="ml-3">
							<p class="text-sm text-red-700">
								{$mutation.error?.message || 'Failed to start scrape'}
							</p>
						</div>
					</div>
				</div>
			{/if}

			<!-- Submit Button -->
			<div class="flex justify-end">
				<button
					type="submit"
					disabled={$mutation.isPending}
					class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-400 disabled:cursor-not-allowed"
				>
					{#if $mutation.isPending}
						<svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
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
						Scraping...
					{:else}
						Start Scrape
					{/if}
				</button>
			</div>
		</form>
	</div>

	<!-- Info Box -->
	<div class="mt-6 bg-blue-50 rounded-lg p-4">
		<h3 class="text-sm font-medium text-blue-800">How it works</h3>
		<ul class="mt-2 text-sm text-blue-700 list-disc list-inside space-y-1">
			<li>Scrapes legislation.gov.uk for newly published laws in the date range</li>
			<li>Automatically categorizes laws into 3 groups based on SI codes and terms</li>
			<li>Group 1: SI code match (highest priority)</li>
			<li>Group 2: Term match only (medium priority)</li>
			<li>Group 3: Excluded (review needed)</li>
		</ul>
	</div>
</div>
