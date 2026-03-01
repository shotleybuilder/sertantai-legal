<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { adminAuth } from '$lib/stores/auth';

	let status: 'loading' | 'success' | 'error' = 'loading';
	let errorMessage = '';
	let dest = '/browse';

	onMount(() => {
		// Where to go after auth — defaults to /browse
		dest = $page.url.searchParams.get('dest') || '/browse';

		const error = $page.url.searchParams.get('error');
		if (error) {
			status = 'error';
			errorMessage = 'Authentication failed. Redirecting...';
			setTimeout(() => goto(dest), 3000);
			return;
		}

		const token = $page.url.searchParams.get('token');
		if (!token) {
			status = 'error';
			errorMessage = 'No token received. Redirecting...';
			setTimeout(() => goto(dest), 3000);
			return;
		}

		const user = adminAuth.setToken(token);
		if (user) {
			status = 'success';
			// Clean the token from the URL before redirecting
			setTimeout(() => goto(dest), 500);
		} else {
			status = 'error';
			errorMessage = 'Invalid or expired token.';
			setTimeout(() => goto(dest), 3000);
		}
	});
</script>

<div class="flex min-h-screen items-center justify-center bg-gray-50">
	<div class="text-center">
		{#if status === 'loading'}
			<div class="text-gray-600">
				<div class="mb-4 text-lg">Completing sign in...</div>
				<div class="animate-pulse text-sm text-gray-400">Verifying token</div>
			</div>
		{:else if status === 'success'}
			<div class="text-green-600">
				<div class="mb-2 text-lg font-medium">Signed in successfully</div>
				<div class="text-sm text-gray-500">Redirecting...</div>
			</div>
		{:else}
			<div class="text-red-600">
				<div class="mb-2 text-lg font-medium">Authentication Error</div>
				<div class="text-sm text-gray-500">{errorMessage}</div>
			</div>
		{/if}
	</div>
</div>
