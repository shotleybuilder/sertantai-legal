<script lang="ts">
	import { onMount } from 'svelte';

	let message = '';
	let status = '';
	let error = '';
	let loading = true;

	const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

	async function fetchHello() {
		loading = true;
		error = '';

		try {
			const response = await fetch(`${API_URL}/api/hello`);
			if (!response.ok) {
				throw new Error(`HTTP error! status: ${response.status}`);
			}
			const data = await response.json();
			message = data.message;
			status = 'success';
		} catch (e) {
			error = e instanceof Error ? e.message : 'Unknown error';
			status = 'error';
		} finally {
			loading = false;
		}
	}

	onMount(() => {
		fetchHello();
	});
</script>

<main class="min-h-screen flex items-center justify-center p-8">
	<div class="max-w-2xl w-full space-y-6">
		<!-- Header -->
		<div class="text-center">
			<h1 class="text-4xl font-bold text-gray-900 mb-2">Starter App</h1>
			<p class="text-gray-600">Full-Stack Real-Time Application Template</p>
		</div>

		<!-- Backend API Test Card -->
		<div class="bg-white rounded-lg shadow-lg p-8">
			<h2 class="text-2xl font-semibold text-gray-800 mb-6">Backend API Test</h2>

			<div class="min-h-[80px] flex items-center justify-center">
				{#if loading}
					<div class="flex items-center space-x-2">
						<div class="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
						<p class="text-gray-600 italic">Loading...</p>
					</div>
				{:else if status === 'success'}
					<div class="text-center">
						<svg
							class="w-12 h-12 text-green-500 mx-auto mb-2"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
							/>
						</svg>
						<p class="text-green-600 font-semibold text-lg">{message}</p>
					</div>
				{:else if error}
					<div class="text-center">
						<svg
							class="w-12 h-12 text-red-500 mx-auto mb-2"
							fill="none"
							stroke="currentColor"
							viewBox="0 0 24 24"
						>
							<path
								stroke-linecap="round"
								stroke-linejoin="round"
								stroke-width="2"
								d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z"
							/>
						</svg>
						<p class="text-red-600 font-semibold">Error: {error}</p>
					</div>
				{/if}
			</div>

			<div class="mt-6 text-center">
				<button
					on:click={fetchHello}
					disabled={loading}
					class="px-6 py-3 bg-blue-600 text-white font-medium rounded-lg
                       hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2
                       disabled:bg-gray-300 disabled:cursor-not-allowed
                       transition-colors duration-200"
				>
					{loading ? 'Loading...' : 'Refresh'}
				</button>
			</div>
		</div>

		<!-- API Info Card -->
		<div class="bg-gray-100 rounded-lg p-4">
			<p class="text-sm text-gray-700">
				API URL: <code class="bg-gray-200 px-2 py-1 rounded text-gray-900 font-mono text-xs"
					>{API_URL}</code
				>
			</p>
		</div>

		<!-- Tech Stack Badge -->
		<div class="text-center text-sm text-gray-500">
			<p>
				SvelteKit + TypeScript + TailwindCSS + Phoenix + Ash Framework + ElectricSQL + TanStack DB
			</p>
		</div>
	</div>
</main>
