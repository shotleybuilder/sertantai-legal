<script lang="ts">
	import { create } from 'jsondiffpatch';
	import { getFieldLabel } from './parse-review/field-config';

	export let existing: Record<string, unknown>;
	export let incoming: Record<string, unknown>;
	export let expanded: boolean = false;

	// Track which section groups are expanded (all expanded by default)
	let expandedGroups: Record<string, boolean> = {};
	// Track which long field values are expanded
	let expandedFields: Record<string, boolean> = {};

	// Threshold for collapsing long arrays/strings
	const ARRAY_COLLAPSE_THRESHOLD = 5;
	const STRING_COLLAPSE_LENGTH = 300;

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

	// Field groupings matching LRT-SCHEMA.md structure (v1.1)
	// Order follows parse stages: STAGE 1-7
	const fieldGroups: Record<string, string[]> = {
		// STAGE 1 💠 metadata - Credentials
		Credentials: [
			'id',
			'name',
			'type_code',
			'year',
			'number',
			'old_style_number',
			'title_en',
			'acronym',
			'leg_gov_uk_url',
			'type_desc',
			'type_class',
			'secondary_class',
			'domain',
			'number_int'
		],
		// STAGE 1 💠 metadata - Description
		Description: ['family', 'family_ii', 'si_code', 'tags', 'md_description', 'md_subjects'],
		// STAGE 1 💠 metadata - Dates
		Dates: [
			'md_date',
			'md_made_date',
			'md_enactment_date',
			'md_coming_into_force_date',
			'md_dct_valid_date',
			'md_modified',
			'md_restrict_start_date',
			'md_restrict_extent'
		],
		// STAGE 1 💠 metadata - Document Statistics
		'Document Statistics': [
			'md_total_paras',
			'md_body_paras',
			'md_schedule_paras',
			'md_attachment_paras',
			'md_images'
		],
		// STAGE 2 📍 geographic extent
		'Geographic Extent': ['geo_extent', 'geo_region', 'geo_detail'],
		// STAGE 3 🚀 enacted_by
		'Enacted By': ['enacted_by', 'enacted_by_meta', 'is_enacting', 'enacting', 'linked_enacted_by'],
		// STAGE 4 🔄 amending - Function flags
		Function: ['function', 'is_making', 'is_commencing'],
		// STAGE 4 🔄 amending - Self-Affects
		'Self-Affects': ['stats_self_affects_count', 'stats_self_affects_count_per_law_detailed'],
		// STAGE 4 🔄 amending - Amending (this law affects others)
		Amending: [
			'is_amending',
			'amending_stats_affects_count',
			'amending_stats_affected_laws_count',
			'affects_stats_per_law',
			'amending',
			'linked_amending',
			'amending_change_log'
		],
		// STAGE 4 🔄 amending - Rescinding (this law rescinds others)
		Rescinding: [
			'is_rescinding',
			'rescinding_stats_rescinding_laws_count',
			'rescinding_stats_per_law',
			'rescinding',
			'linked_rescinding'
		],
		// STAGE 5 🔄 amended_by - Amended By (this law is affected by others)
		'Amended By': [
			'amended_by_stats_affected_by_count',
			'amended_by_stats_affected_by_laws_count',
			'affected_by_stats_per_law',
			'amended_by',
			'linked_amended_by',
			'latest_amend_date',
			'latest_change_date',
			'amended_by_change_log'
		],
		// STAGE 5 🔄 amended_by - Rescinded By (this law is rescinded by others)
		'Rescinded By': [
			'rescinded_by_stats_rescinded_by_laws_count',
			'rescinded_by_stats_per_law',
			'rescinded_by',
			'linked_rescinded_by',
			'latest_rescind_date'
		],
		// STAGE 6 🚫 repeal_revoke - Status
		Status: [
			'live',
			'live_description',
			'live_source',
			'live_conflict',
			'live_from_changes',
			'live_from_metadata',
			'live_conflict_detail'
		],
		// STAGE 7 🦋 taxa - Purpose
		Purpose: ['purpose'],
		// STAGE 7 🦋 taxa - Roles
		Roles: ['role', 'role_details', 'role_gvt', 'role_gvt_details'],
		// STAGE 7 🦋 taxa - Duty Type
		'Duty Type': ['duty_type', 'duty_type_article', 'article_duty_type'],
		// STAGE 7 🦋 taxa - Holders (DRRP)
		Duties: ['duty_holder', 'duties'],
		Rights: ['rights_holder', 'rights'],
		Responsibilities: ['responsibility_holder', 'responsibilities'],
		Powers: ['power_holder', 'powers'],
		// STAGE 7 🦋 taxa - POPIMAR
		POPIMAR: [
			'popimar',
			'popimar_details',
			'popimar_article',
			'popimar_article_clause',
			'article_popimar',
			'article_popimar_clause'
		],
		// Change Logs
		'Change Logs': ['record_change_log'],
		// Timestamps
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

	// Group order matching LRT-SCHEMA.md structure (v1.1)
	const groupOrder = [
		// STAGE 1 💠 metadata
		'Credentials',
		'Description',
		'Dates',
		'Document Statistics',
		// STAGE 2 📍 geographic extent
		'Geographic Extent',
		// STAGE 3 🚀 enacted_by
		'Enacted By',
		// STAGE 4 🔄 amending
		'Function',
		'Self-Affects',
		'Amending',
		'Rescinding',
		// STAGE 5 🔄 amended_by
		'Amended By',
		'Rescinded By',
		// STAGE 6 🚫 repeal_revoke
		'Status',
		// STAGE 7 🦋 taxa
		'Purpose',
		'Roles',
		'Duty Type',
		'Duties',
		'Rights',
		'Responsibilities',
		'Powers',
		'POPIMAR',
		// Other
		'Change Logs',
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

	// Check if a value is long enough to warrant collapsing
	function isLongValue(value: unknown): boolean {
		if (Array.isArray(value) && value.length > ARRAY_COLLAPSE_THRESHOLD) return true;
		const formatted = formatValue(value);
		return formatted.length > STRING_COLLAPSE_LENGTH;
	}

	// Get truncated preview of a value
	function getPreview(value: unknown): string {
		if (Array.isArray(value)) {
			const preview = value.slice(0, 3).map(v => typeof v === 'string' ? v : JSON.stringify(v)).join(', ');
			return `[${preview}${value.length > 3 ? `, ... +${value.length - 3} more` : ''}]`;
		}
		const formatted = formatValue(value);
		if (formatted.length > 100) {
			return formatted.slice(0, 100) + '...';
		}
		return formatted;
	}

	// Toggle group expansion
	function toggleGroup(groupName: string) {
		// Default is expanded (true), so toggle from current state
		const currentState = expandedGroups[groupName] !== false;
		expandedGroups = { ...expandedGroups, [groupName]: !currentState };
	}

	// Toggle field expansion
	function toggleField(fieldKey: string) {
		expandedFields = { ...expandedFields, [fieldKey]: !expandedFields[fieldKey] };
	}

	// Get array length for display
	function getArrayInfo(value: unknown): string | null {
		if (Array.isArray(value)) {
			return `${value.length} item${value.length === 1 ? '' : 's'}`;
		}
		return null;
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
						<!-- Collapsible Group Header -->
						<button
							type="button"
							on:click={() => toggleGroup(group.name)}
							class="w-full px-4 py-2 bg-gray-50 flex items-center justify-between text-left hover:bg-gray-100 transition-colors"
						>
							<div class="flex items-center gap-2">
								<span class="text-xs font-semibold text-gray-600 uppercase tracking-wide">
									{group.name}
								</span>
								<span class="text-xs text-gray-400">
									({group.changes.length} field{group.changes.length === 1 ? '' : 's'})
								</span>
							</div>
							<svg
								class="w-4 h-4 text-gray-500 transform transition-transform {expandedGroups[group.name] !== false ? 'rotate-180' : ''}"
								fill="none"
								stroke="currentColor"
								viewBox="0 0 24 24"
							>
								<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
							</svg>
						</button>
						<!-- Group Content -->
						{#if expandedGroups[group.name] !== false}
						<div class="divide-y divide-gray-100">
							{#each group.changes as change}
								{@const fieldKey = `${group.name}-${change.field}`}
								{@const oldIsLong = isLongValue(change.oldValue)}
								{@const newIsLong = isLongValue(change.newValue)}
								{@const isFieldExpanded = expandedFields[fieldKey]}
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
											<!-- Field header with optional expand toggle -->
											<div class="flex items-center justify-between mb-1">
												<div class="text-sm font-medium text-indigo-600">
													{getFieldLabel(change.field)} <span class="font-mono text-xs text-gray-400">({change.field})</span>
													{#if getArrayInfo(change.newValue || change.oldValue)}
														<span class="ml-1 text-xs text-gray-400">
															{getArrayInfo(change.newValue || change.oldValue)}
														</span>
													{/if}
												</div>
												{#if oldIsLong || newIsLong}
													<button
														type="button"
														on:click={() => toggleField(fieldKey)}
														class="text-xs text-blue-600 hover:text-blue-800 flex items-center gap-1"
													>
														{isFieldExpanded ? 'Collapse' : 'Expand'}
														<svg
															class="w-3 h-3 transform transition-transform {isFieldExpanded ? 'rotate-180' : ''}"
															fill="none"
															stroke="currentColor"
															viewBox="0 0 24 24"
														>
															<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
														</svg>
													</button>
												{/if}
											</div>
											<!-- Field values -->
											{#if change.type === 'deleted'}
												<div class="diff-value deleted">
													<pre>{(oldIsLong && !isFieldExpanded) ? getPreview(change.oldValue) : formatValue(change.oldValue)}</pre>
												</div>
											{:else if change.type === 'added'}
												<div class="diff-value added">
													<pre>{(newIsLong && !isFieldExpanded) ? getPreview(change.newValue) : formatValue(change.newValue)}</pre>
												</div>
											{:else}
												<div class="space-y-1">
													<div class="diff-value deleted">
														<pre>{(oldIsLong && !isFieldExpanded) ? getPreview(change.oldValue) : formatValue(change.oldValue)}</pre>
													</div>
													<div class="diff-value added">
														<pre>{(newIsLong && !isFieldExpanded) ? getPreview(change.newValue) : formatValue(change.newValue)}</pre>
													</div>
												</div>
											{/if}
										</div>
									</div>
								</div>
							{/each}
						</div>
						{/if}
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
