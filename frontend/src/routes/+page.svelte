<script lang="ts">
	import { goto } from '$app/navigation';
	import { onMount } from 'svelte';

	// SvelteKit passes props; consume with $props() to avoid warnings
	// eslint-disable-next-line @typescript-eslint/no-unused-vars
	let { ...restProps } = $props();

	onMount(() => {
		goto('/admin', { replaceState: true });
	});
</script>
