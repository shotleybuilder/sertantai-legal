<script lang="ts">
	import { onMount } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';
	import { adminAuth } from '$lib/stores/auth';

	onMount(() => {
		const token = $page.url.searchParams.get('token');
		const dest = $page.url.searchParams.get('dest') || '/';

		if (token) {
			adminAuth.setToken(token);
		}

		goto(dest, { replaceState: true });
	});
</script>

<p class="p-8 text-gray-500">Redirecting...</p>
