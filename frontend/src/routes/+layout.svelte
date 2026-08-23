<script lang="ts">
	import type { Snippet } from 'svelte';
	import '../app.css';
	import { QueryClientProvider } from '@tanstack/svelte-query';
	import { queryClient } from '$lib/query/client';
	import { browser } from '$app/environment';
	import { adminAuth } from '$lib/stores/auth';

	let { children }: { children: Snippet } = $props();

	// Restore auth from localStorage at module scope — runs during script
	// initialization BEFORE any child onMount callbacks fire.
	// Fixes Issue #42: Electric sync was starting before auth was initialized
	// because Svelte child onMount fires before parent onMount.
	if (browser) {
		adminAuth.check();
	}
</script>

<QueryClientProvider client={queryClient}>
	{@render children()}
</QueryClientProvider>
