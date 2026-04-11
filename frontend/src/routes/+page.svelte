<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	// SvelteKit passes params as a prop; accept to suppress "unknown prop" warning
	// eslint-disable-next-line svelte/valid-compile
	export let params: Record<string, string> = {};

	onMount(() => {
		goto('/browse', { replaceState: true });
	});
</script>
