<script lang="ts">
	import { create } from 'jsondiffpatch';
	import { getFieldLabel } from './parse-review/field-config';

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

	// Field groupings matching the schema alignment doc
	const fieldGroups: Record<string, string[]> = {
		Credentials: [
			'name',
			'title_en',
			'year',
			'number',
			'number_int',
			'type_code',
			'type_desc',
			'type_class',
			'secondary_class',
			'acronym',
			'old_style_number'
		],
		Description: ['family', 'family_ii', 'si_code', 'tags', 'md_description', 'md_subjects'],
		Status: ['live', 'live_description'],
		'Geographic Extent': ['geo_extent', 'geo_region', 'geo_detail', 'md_restrict_extent'],
		Metadata: [
			'md_date',
			'md_made_date',
			'md_enactment_date',
			'md_coming_into_force_date',
			'md_dct_valid_date',
			'md_restrict_start_date',
			'md_total_paras',
			'md_body_paras',
			'md_schedule_paras',
			'md_attachment_paras',
			'md_images',
			'dct_valid',
			'latest_amend_date',
			'latest_change_date',
			'latest_rescind_date'
		],
		Function: [
			'function',
			'is_making',
			'is_commencing',
			'is_amending',
			'is_rescinding',
			'is_enacting',
			'enacting',
			'enacted_by',
			'amending',
			'amended_by',
			'rescinding',
			'rescinded_by',
			'amending_count',
			'amended_by_count',
			'rescinding_count',
			'rescinded_by_count',
			'amending_stats_affects_count',
			'amending_stats_affected_laws_count',
			'amending_stats_affects_count_per_law',
			'amending_stats_affects_count_per_law_detailed',
			'affects_stats_per_law',
			'amended_by_stats_affected_by_count',
			'amended_by_stats_affected_by_laws_count',
			'amended_by_stats_affected_by_count_per_law',
			'amended_by_stats_affected_by_count_per_law_detailed',
			'affected_by_stats_per_law',
			'rescinding_stats_rescinding_laws_count',
			'rescinding_stats_rescinding_count_per_law',
			'rescinding_stats_rescinding_count_per_law_detailed',
			'rescinding_stats_per_law',
			'rescinded_by_stats_rescinded_by_laws_count',
			'rescinded_by_stats_rescinded_by_count_per_law',
			'rescinded_by_stats_rescinded_by_count_per_law_detailed',
			'rescinded_by_stats_per_law',
			'stats_self_affects_count',
			'stats_self_affects_count_per_law_detailed',
			'linked_amending',
			'linked_amended_by',
			'linked_rescinding',
			'linked_rescinded_by',
			'linked_enacted_by',
			'amending_change_log',
			'amended_by_change_log'
		],
		Roles: [
			'role',
			'article_role',
			'role_article',
			'role_gvt',
			'role_gvt_article',
			'article_role_gvt',
			'duty_type',
			'duty_type_article',
			'article_duty_type',
			'duty_holder',
			'rights_holder',
			'responsibility_holder',
			'power_holder',
			// Consolidated JSONB holder fields (Phase 3)
			'duties',
			'rights',
			'responsibilities',
			'powers',
			'popimar',
			// Consolidated JSONB POPIMAR field (Phase 3 Issue #15)
			'popimar_details',
			// Consolidated JSONB Role fields (Phase 3 Issue #16)
			'role_details',
			'role_gvt_details',
			'popimar_article',
			'popimar_article_clause',
			'article_popimar',
			'article_popimar_clause',
			'purpose',
			'items'
		],
		'External References': ['leg_gov_uk_url'],
		Timestamps: ['created_at', 'updated_at', 'inserted_at']
	};

	// Compute diff between existing and incoming records
	$: delta = jsondiffpatch.diff(existing, incoming);
	$: hasChanges = delta !== undefined && Object.keys(delta).length > 0;

	// Categorize changes
	type ChangeType = 'deleted' | 'modified' | 'added';
	type Change = {
		field: string;
		type: ChangeType;
		oldValue: unknown;
		newValue: unknown;
	};

	function getChangeType(deltaValue: unknown): ChangeType {
		if (Array.isArray(deltaValue)) {
			if (deltaValue.length === 1) return 'added';
			if (deltaValue.length === 3 && deltaValue[2] === 0) return 'deleted';
			if (deltaValue.length === 2) return 'modified';
		}
		// Object changes (nested)
		return 'modified';
	}

	function getOldValue(field: string, deltaValue: unknown): unknown {
		if (Array.isArray(deltaValue)) {
			if (deltaValue.length === 1) return undefined; // added
			if (deltaValue.length === 3 && deltaValue[2] === 0) return deltaValue[0]; // deleted
			if (deltaValue.length === 2) return deltaValue[0]; // modified
		}
		return existing[field];
	}

	function getNewValue(field: string, deltaValue: unknown): unknown {
		if (Array.isArray(deltaValue)) {
			if (deltaValue.length === 1) return deltaValue[0]; // added
			if (deltaValue.length === 3 && deltaValue[2] === 0) return undefined; // deleted
			if (deltaValue.length === 2) return deltaValue[1]; // modified
		}
		return incoming[field];
	}

	// Check if a value is empty (null, undefined, empty string, empty array, empty object)
	function isEmpty(value: unknown): boolean {
		if (value === null || value === undefined) return true;
		if (value === '') return true;
		if (Array.isArray(value) && value.length === 0) return true;
		if (typeof value === 'object' && Object.keys(value as object).length === 0) return true;
		return false;
	}

	$: changes = delta
		? Object.entries(delta)
				.filter(([k]) => !k.startsWith('_'))
				.map(([field, deltaValue]) => ({
					field,
					type: getChangeType(deltaValue),
					oldValue: getOldValue(field, deltaValue),
					newValue: getNewValue(field, deltaValue)
				}))
				// Filter out changes where both values are empty, or added/deleted with empty value
				.filter((change) => {
					if (change.type === 'added' && isEmpty(change.newValue)) return false;
					if (change.type === 'deleted' && isEmpty(change.oldValue)) return false;
					if (change.type === 'modified' && isEmpty(change.oldValue) && isEmpty(change.newValue))
						return false;
					return true;
				})
		: [];

	// Group changes by category
	function getFieldGroup(field: string): string {
		for (const [group, fields] of Object.entries(fieldGroups)) {
			if (fields.includes(field)) return group;
		}
		return 'Other';
	}

	// Sort order for change types
	const typeOrder: Record<ChangeType, number> = { deleted: 0, modified: 1, added: 2 };

	// Group order
	const groupOrder = [
		'Credentials',
		'Description',
		'Status',
		'Geographic Extent',
		'Metadata',
		'Function',
		'Roles',
		'External References',
		'Timestamps',
		'Other'
	];

	$: groupedChanges = changes.reduce(
		(acc, change) => {
			const group = getFieldGroup(change.field);
			if (!acc[group]) acc[group] = [];
			acc[group].push(change);
			return acc;
		},
		{} as Record<string, Change[]>
	);

	// Sort changes within each group by type
	$: sortedGroups = groupOrder
		.filter((g) => groupedChanges[g]?.length > 0)
		.map((group) => ({
			name: group,
			changes: groupedChanges[group].sort((a, b) => typeOrder[a.type] - typeOrder[b.type])
		}));

	// Summary counts
	$: deletedCount = changes.filter((c) => c.type === 'deleted').length;
	$: modifiedCount = changes.filter((c) => c.type === 'modified').length;
	$: addedCount = changes.filter((c) => c.type === 'added').length;

	function formatValue(value: unknown): string {
		if (value === undefined || value === null) return 'null';
		if (typeof value === 'object') return JSON.stringify(value, null, 2);
		return String(value);
	}
</script>

{#if hasChanges}
	<div class="border border-amber-200 rounded-lg overflow-hidden bg-amber-50">
		<button
			type="button"
			on:click={() => (expanded = !expanded)}
			class="w-full px-4 py-3 flex items-center justify-between text-left hover:bg-amber-100 transition-colors"
		>
			<div class="flex items-center space-x-3">
				<svg class="w-5 h-5 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
					<path
						stroke-linecap="round"
						stroke-linejoin="round"
						stroke-width="2"
						d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"
					/>
				</svg>
				<span class="font-medium text-amber-800">
					{changes.length} field{changes.length === 1 ? '' : 's'} changed
				</span>
				<div class="flex items-center space-x-2 text-xs">
					{#if deletedCount > 0}
						<span class="px-2 py-0.5 bg-red-100 text-red-700 rounded">{deletedCount} removed</span>
					{/if}
					{#if modifiedCount > 0}
						<span class="px-2 py-0.5 bg-amber-100 text-amber-700 rounded"
							>{modifiedCount} updated</span
						>
					{/if}
					{#if addedCount > 0}
						<span class="px-2 py-0.5 bg-green-100 text-green-700 rounded">{addedCount} added</span>
					{/if}
				</div>
			</div>
			<svg
				class="w-5 h-5 text-amber-600 transform transition-transform {expanded ? 'rotate-180' : ''}"
				fill="none"
				stroke="currentColor"
				viewBox="0 0 24 24"
			>
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
			</svg>
		</button>

		{#if expanded}
			<div class="border-t border-amber-200 bg-white">
				{#each sortedGroups as group}
					<div class="border-b border-gray-100 last:border-b-0">
						<div
							class="px-4 py-2 bg-gray-50 text-xs font-semibold text-gray-600 uppercase tracking-wide"
						>
							{group.name}
						</div>
						<div class="divide-y divide-gray-100">
							{#each group.changes as change}
								<div class="px-4 py-3">
									<div class="flex items-start gap-3">
										<span
											class="shrink-0 w-16 text-xs font-medium px-2 py-0.5 rounded {change.type ===
											'deleted'
												? 'bg-red-100 text-red-700'
												: change.type === 'added'
													? 'bg-green-100 text-green-700'
													: 'bg-amber-100 text-amber-700'}"
										>
											{change.type === 'deleted'
												? 'Removed'
												: change.type === 'added'
													? 'Added'
													: 'Updated'}
										</span>
										<div class="flex-1 min-w-0">
											<div class="text-sm font-medium text-indigo-600 mb-1">
												{getFieldLabel(change.field)} <span class="font-mono text-xs text-gray-400">({change.field})</span>
											</div>
											{#if change.type === 'deleted'}
												<div class="diff-value deleted">
													<pre>{formatValue(change.oldValue)}</pre>
												</div>
											{:else if change.type === 'added'}
												<div class="diff-value added">
													<pre>{formatValue(change.newValue)}</pre>
												</div>
											{:else}
												<div class="space-y-1">
													<div class="diff-value deleted">
														<pre>{formatValue(change.oldValue)}</pre>
													</div>
													<div class="diff-value added">
														<pre>{formatValue(change.newValue)}</pre>
													</div>
												</div>
											{/if}
										</div>
									</div>
								</div>
							{/each}
						</div>
					</div>
				{/each}
			</div>
		{/if}
	</div>
{:else}
	<div class="border border-green-200 rounded-lg bg-green-50 px-4 py-3">
		<div class="flex items-center space-x-2">
			<svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
				<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
			</svg>
			<span class="text-green-800">No changes detected - record is identical</span>
		</div>
	</div>
{/if}

<style>
	.diff-value {
		font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
		font-size: 0.75rem;
		line-height: 1.4;
		padding: 0.5rem;
		border-radius: 0.25rem;
		overflow-x: auto;
	}

	.diff-value pre {
		margin: 0;
		white-space: pre-wrap;
		word-wrap: break-word;
		overflow-wrap: break-word;
		word-break: break-word;
	}

	.diff-value.deleted {
		background-color: #fee2e2;
		border-left: 3px solid #ef4444;
	}

	.diff-value.added {
		background-color: #d1fae5;
		border-left: 3px solid #10b981;
	}
</style>
