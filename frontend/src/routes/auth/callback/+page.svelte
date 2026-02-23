<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { adminAuth } from '$lib/stores/auth';

	let status: 'loading' | 'success' | 'error' = 'loading';
	let errorMessage = '';

	onMount(async () => {
		const error = $page.url.searchParams.get('error');
		if (error) {
			status = 'error';
			errorMessage = 'Authentication failed. Redirecting...';
			setTimeout(() => goto('/admin'), 3000);
			return;
		}

		try {
			const user = await adminAuth.check();
			if (user) {
				status = 'success';
				setTimeout(() => goto('/admin'), 1000);
			} else {
				status = 'error';
				errorMessage = 'Session not established. Please try again.';
				setTimeout(() => goto('/admin'), 3000);
			}
		} catch {
			status = 'error';
			errorMessage = 'Authentication verification failed.';
			setTimeout(() => goto('/admin'), 3000);
		}
	});
</script>

<div class="flex min-h-screen items-center justify-center bg-gray-50">
	<div class="text-center">
		{#if status === 'loading'}
			<div class="text-gray-600">
				<div class="mb-4 text-lg">Completing sign in...</div>
				<div class="animate-pulse text-sm text-gray-400">Verifying session</div>
			</div>
		{:else if status === 'success'}
			<div class="text-green-600">
				<div class="mb-2 text-lg font-medium">Signed in successfully</div>
				<div class="text-sm text-gray-500">Redirecting to admin...</div>
			</div>
		{:else}
			<div class="text-red-600">
				<div class="mb-2 text-lg font-medium">Authentication Error</div>
				<div class="text-sm text-gray-500">{errorMessage}</div>
			</div>
		{/if}
	</div>
</div>
