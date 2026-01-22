<script context="module" lang="ts">
	import type { FieldConfig, FieldType } from './field-config';

	/**
	 * Get field value from record, checking alternative keys
	 */
	export function getFieldValue(
		record: Record<string, unknown> | null | undefined,
		fieldConfig: FieldConfig
	): unknown {
		if (!record) return null;

		// Check primary key first
		if (record[fieldConfig.key] !== undefined && record[fieldConfig.key] !== null) {
			return record[fieldConfig.key];
		}

		// Check alternative keys
		if (fieldConfig.altKeys) {
			for (const altKey of fieldConfig.altKeys) {
				if (record[altKey] !== undefined && record[altKey] !== null) {
					return record[altKey];
				}
			}
		}

		return null;
	}

	/**
	 * Check if a value has meaningful data (not empty)
	 */
	export function hasData(val: unknown): boolean {
		if (val === null || val === undefined) return false;
		if (val === '' || val === '-' || val === '(none)') return false;
		if (Array.isArray(val) && val.length === 0) return false;
		if (typeof val === 'object' && Object.keys(val).length === 0) return false;
		if (typeof val === 'number' && val === 0) return false;
		return true;
	}
</script>

<script lang="ts">
	export let config: FieldConfig;
	export let value: unknown;
	export let showFieldKey: boolean = true;

	/**
	 * Format value based on field type
	 */
	function formatValue(val: unknown, type: FieldType): string {
		if (val === null || val === undefined) return '-';

		switch (type) {
			case 'date':
				if (typeof val !== 'string') return String(val);
				try {
					return new Date(val).toLocaleDateString();
				} catch {
					return String(val);
				}

			case 'boolean':
				return val ? 'Yes' : 'No';

			case 'number':
				return String(val);

			case 'array':
				if (!Array.isArray(val)) return String(val);
				if (val.length === 0) return '(none)';
				return val
					.map((v) => (typeof v === 'object' ? JSON.stringify(v) : String(v)))
					.join(', ');

			case 'json':
				if (typeof val !== 'object') return String(val);
				// Handle {values: [...]} format
				const obj = val as Record<string, unknown>;
				if ('values' in obj && Array.isArray(obj.values)) {
					if (obj.values.length === 0) return '(none)';
					return obj.values.join(', ');
				}
				// Handle {items: [...]} format
				if ('items' in obj && Array.isArray(obj.items)) {
					if (obj.items.length === 0) return '(none)';
					return obj.items
						.map((v) => (typeof v === 'object' ? JSON.stringify(v) : String(v)))
						.join(', ');
				}
				// Handle boolean map format {key: true, key2: true}
				const trueKeys = Object.entries(obj)
					.filter(([_, v]) => v === true)
					.map(([k, _]) => k);
				if (trueKeys.length > 0) {
					return trueKeys.join(', ');
				}
				return JSON.stringify(val);

			case 'url':
				return String(val);

			case 'multiline':
			case 'text':
			default:
				return String(val);
		}
	}

	$: formattedValue = formatValue(value, config.type);
	$: isEmpty = !hasData(value);
</script>

<div class="grid grid-cols-3 px-4 py-2">
	<span class="text-sm text-gray-500">
		{config.label}
		{#if showFieldKey}
			<span class="text-xs text-gray-400">({config.key})</span>
		{/if}
	</span>
	<span
		class="col-span-2 text-sm {isEmpty ? 'text-gray-400 italic' : 'text-gray-900'}"
		class:whitespace-pre-line={config.type === 'multiline'}
		class:max-h-32={config.type === 'multiline'}
		class:overflow-y-auto={config.type === 'multiline'}
	>
		{#if config.type === 'url' && !isEmpty}
			<a
				href={String(value)}
				target="_blank"
				rel="noopener noreferrer"
				class="text-blue-600 hover:text-blue-800"
			>
				{formattedValue}
			</a>
		{:else if config.type === 'boolean'}
			<span class={value ? 'text-green-600' : 'text-gray-400'}>
				{formattedValue}
			</span>
		{:else}
			{formattedValue}
		{/if}
	</span>
</div>
