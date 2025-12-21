<script lang="ts">
	import '../app.css';
	import { QueryClientProvider } from '@tanstack/svelte-query';
	import { queryClient } from '$lib/query/client';
</script>

<QueryClientProvider client={queryClient}>
	<slot />
</QueryClientProvider>
