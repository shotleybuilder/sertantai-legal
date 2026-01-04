<script lang="ts">
	import { create } from 'jsondiffpatch';
	import { format as formatHtml } from 'jsondiffpatch/formatters/html';

	export let existing: Record<string, unknown>;
	export let incoming: Record<string, unknown>;
	export let expanded: boolean = false;

	const jsondiffpatch = create({
		objectHash: function (obj) {
			const o = obj as Record<string, unknown>;
			return (o.name as string) || (o.id as string) || JSON.stringify(obj);
		},
		arrays: {
			detectMove: true,
			includeValueOnMove: false
		}
	});

	// Compute diff between existing and incoming records
	$: delta = jsondiffpatch.diff(existing, incoming);
	$: hasChanges = delta !== undefined && Object.keys(delta).length > 0;

	// Get changed field names for summary
	$: changedFields = delta ? Object.keys(delta).filter((k) => !k.startsWith('_')) : [];

	// Format the delta as HTML
	$: diffHtml = delta ? formatHtml(delta, existing) : '';
</script>

{#if hasChanges}
	<div class="border border-amber-200 rounded-lg overflow-hidden bg-amber-50">
		<button
			type="button"
			on:click={() => (expanded = !expanded)}
			class="w-full px-4 py-3 flex items-center justify-between text-left hover:bg-amber-100 transition-colors"
		>
			<div class="flex items-center space-x-2">
				<svg
					class="w-5 h-5 text-amber-600"
					fill="none"
					stroke="currentColor"
					viewBox="0 0 24 24"
				>
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
					/>
				</svg>
				<span class="font-medium text-amber-800">
					{changedFields.length} field{changedFields.length === 1 ? '' : 's'} changed
				</span>
				<span class="text-sm text-amber-600">
					({changedFields.slice(0, 3).join(', ')}{changedFields.length > 3 ? '...' : ''})
				</span>
			</div>
			<svg
				class="w-5 h-5 text-amber-600 transform transition-transform {expanded
					? 'rotate-180'
					: ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
			</svg>
		</button>

		{#if expanded}
			<div class="border-t border-amber-200 p-4 bg-white">
				<div class="jsondiffpatch-container">
					{@html diffHtml}
				</div>
			</div>
		{/if}
	</div>
{:else}
	<div class="border border-green-200 rounded-lg bg-green-50 px-4 py-3">
		<div class="flex items-center space-x-2">
			<svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path
					stroke-linecap="round"
					stroke-linejoin="round"
					stroke-width="2"
					d="M5 13l4 4L19 7"
				/>
			</svg>
			<span class="text-green-800">No changes detected - record is identical</span>
		</div>
	</div>
{/if}

<style>
	/* jsondiffpatch default styles adapted for our theme */
	:global(.jsondiffpatch-container) {
		font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
		font-size: 0.75rem;
		line-height: 1.5;
	}

	:global(.jsondiffpatch-delta) {
		background: transparent;
	}

	:global(.jsondiffpatch-added) {
		background-color: #d1fae5;
		padding: 2px 4px;
		border-radius: 2px;
	}

	:global(.jsondiffpatch-deleted) {
		background-color: #fee2e2;
		padding: 2px 4px;
		border-radius: 2px;
		text-decoration: line-through;
	}

	:global(.jsondiffpatch-modified) {
		background-color: #fef3c7;
		padding: 2px 4px;
		border-radius: 2px;
	}

	:global(.jsondiffpatch-property-name) {
		color: #6366f1;
		font-weight: 500;
	}

	:global(.jsondiffpatch-unchanged) {
		color: #6b7280;
	}

	:global(.jsondiffpatch-value) {
		display: inline;
	}

	:global(.jsondiffpatch-arrow) {
		color: #9ca3af;
		padding: 0 4px;
	}

	/* Hide unchanged by default to reduce noise */
	:global(.jsondiffpatch-unchanged) {
		display: none;
	}

	:global(.jsondiffpatch-child-node-type-object),
	:global(.jsondiffpatch-child-node-type-array) {
		margin-left: 1rem;
		border-left: 2px solid #e5e7eb;
		padding-left: 0.5rem;
	}

	:global(.jsondiffpatch-textdiff-added) {
		background-color: #bbf7d0;
	}

	:global(.jsondiffpatch-textdiff-deleted) {
		background-color: #fecaca;
		text-decoration: line-through;
	}
</style>
