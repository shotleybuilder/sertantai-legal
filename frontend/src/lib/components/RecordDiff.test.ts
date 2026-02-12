/**
 * Tests for RecordDiff component diff logic
 *
 * Tests the jsondiffpatch Differ behavior that powers the RecordDiff component.
 * We test the diff logic directly since Svelte component testing would require
 * additional setup (testing-library/svelte).
 */

import { describe, it, expect } from 'vitest';
import { create } from 'jsondiffpatch';
import { format as formatHtml } from 'jsondiffpatch/formatters/html';

// Create differ instance matching the component configuration
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

describe('RecordDiff diff logic', () => {
	describe('basic diff detection', () => {
		it('returns undefined when objects are identical', () => {
			const existing = { name: 'test', title: 'Test Title', year: 2024 };
			const incoming = { name: 'test', title: 'Test Title', year: 2024 };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeUndefined();
		});

		it('detects added fields', () => {
			const existing = { name: 'test' };
			const incoming = { name: 'test', newField: 'new value' };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).newField).toBeDefined();
			// Added fields have format [newValue]
			expect((delta as any).newField).toEqual(['new value']);
		});

		it('detects removed fields', () => {
			const existing = { name: 'test', oldField: 'old value' };
			const incoming = { name: 'test' };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).oldField).toBeDefined();
			// Removed fields have format [oldValue, 0, 0]
			expect((delta as any).oldField).toEqual(['old value', 0, 0]);
		});

		it('detects modified fields', () => {
			const existing = { name: 'test', title: 'Old Title' };
			const incoming = { name: 'test', title: 'New Title' };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).title).toBeDefined();
			// Modified fields have format [oldValue, newValue]
			expect((delta as any).title).toEqual(['Old Title', 'New Title']);
		});
	});

	describe('nested object diffs', () => {
		it('detects changes in nested objects', () => {
			const existing = {
				name: 'test',
				metadata: { author: 'Alice', version: 1 }
			};
			const incoming = {
				name: 'test',
				metadata: { author: 'Bob', version: 1 }
			};

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).metadata).toBeDefined();
			expect((delta as any).metadata.author).toEqual(['Alice', 'Bob']);
		});

		it('handles null to object transitions', () => {
			const existing = { name: 'test', duty_holder: null };
			const incoming = { name: 'test', duty_holder: { employer: true } };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).duty_holder).toBeDefined();
		});

		it('handles object to null transitions', () => {
			const existing = { name: 'test', duty_holder: { employer: true } };
			const incoming = { name: 'test', duty_holder: null };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).duty_holder).toBeDefined();
		});
	});

	describe('array diffs', () => {
		it('detects added array elements', () => {
			const existing = { name: 'test', tags: ['health'] };
			const incoming = { name: 'test', tags: ['health', 'safety'] };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).tags).toBeDefined();
		});

		it('detects removed array elements', () => {
			const existing = { name: 'test', tags: ['health', 'safety'] };
			const incoming = { name: 'test', tags: ['health'] };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).tags).toBeDefined();
		});

		it('detects empty to non-empty array', () => {
			const existing = { name: 'test', tags: [] };
			const incoming = { name: 'test', tags: ['health'] };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).tags).toBeDefined();
		});
	});

	describe('type changes', () => {
		it('detects string to number change', () => {
			const existing = { name: 'test', year: '2024' };
			const incoming = { name: 'test', year: 2024 };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).year).toEqual(['2024', 2024]);
		});

		it('detects null to string change', () => {
			const existing = { name: 'test', family: null };
			const incoming = { name: 'test', family: 'Environmental Protection' };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).family).toEqual([null, 'Environmental Protection']);
		});

		it('detects string to null change', () => {
			const existing = { name: 'test', family: 'Environmental Protection' };
			const incoming = { name: 'test', family: null };

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).family).toEqual(['Environmental Protection', null]);
		});
	});

	describe('changed fields extraction', () => {
		it('extracts list of changed field names', () => {
			const existing = {
				name: 'test',
				title: 'Old Title',
				year: 2023,
				family: 'Old Family'
			};
			const incoming = {
				name: 'test',
				title: 'New Title',
				year: 2024,
				family: 'Old Family'
			};

			const delta = jsondiffpatch.diff(existing, incoming);
			const changedFields = delta ? Object.keys(delta).filter((k) => !k.startsWith('_')) : [];

			expect(changedFields).toContain('title');
			expect(changedFields).toContain('year');
			expect(changedFields).not.toContain('name');
			expect(changedFields).not.toContain('family');
		});

		it('returns empty array when no changes', () => {
			const existing = { name: 'test', title: 'Title' };
			const incoming = { name: 'test', title: 'Title' };

			const delta = jsondiffpatch.diff(existing, incoming);
			const changedFields = delta ? Object.keys(delta).filter((k) => !k.startsWith('_')) : [];

			expect(changedFields).toEqual([]);
		});
	});

	describe('HTML formatter output', () => {
		it('generates HTML output for changes', () => {
			const existing = { title: 'Old Title' };
			const incoming = { title: 'New Title' };

			const delta = jsondiffpatch.diff(existing, incoming);
			const html = delta ? formatHtml(delta, existing) : '';

			expect(html).toBeTruthy();
			expect(typeof html).toBe('string');
			expect(html).toContain('Old Title');
			expect(html).toContain('New Title');
		});

		it('returns empty string when no changes', () => {
			const existing = { title: 'Same Title' };
			const incoming = { title: 'Same Title' };

			const delta = jsondiffpatch.diff(existing, incoming);
			const html = delta ? formatHtml(delta, existing) : '';

			expect(html).toBe('');
		});
	});

	describe('realistic UK LRT record diffs', () => {
		it('detects family change', () => {
			const existing = {
				name: 'uksi/2024/100',
				title_en: 'Test Regulations 2024',
				family: 'Environmental Protection',
				year: 2024
			};
			const incoming = {
				name: 'uksi/2024/100',
				title_en: 'Test Regulations 2024',
				family: 'OH&S: Occupational Safety',
				year: 2024
			};

			const delta = jsondiffpatch.diff(existing, incoming);
			const changedFields = delta ? Object.keys(delta).filter((k) => !k.startsWith('_')) : [];

			expect(changedFields).toEqual(['family']);
			expect((delta as any).family).toEqual(['Environmental Protection', 'OH&S: Occupational Safety']);
		});

		it('detects multiple field changes during re-parse', () => {
			const existing = {
				name: 'uksi/2024/100',
				title_en: 'Test Regulations 2024',
				live: null,
				geo_extent: null,
				md_total_paras: null
			};
			const incoming = {
				name: 'uksi/2024/100',
				title_en: 'Test Regulations 2024',
				live: 'In Force',
				geo_extent: 'E+W+S',
				md_total_paras: 25
			};

			const delta = jsondiffpatch.diff(existing, incoming);
			const changedFields = delta ? Object.keys(delta).filter((k) => !k.startsWith('_')) : [];

			expect(changedFields).toContain('live');
			expect(changedFields).toContain('geo_extent');
			expect(changedFields).toContain('md_total_paras');
			expect(changedFields.length).toBe(3);
		});

		it('handles holder object changes', () => {
			const existing = {
				name: 'uksi/2024/100',
				duty_holder: { employer: true }
			};
			const incoming = {
				name: 'uksi/2024/100',
				duty_holder: { employer: true, employee: true }
			};

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).duty_holder).toBeDefined();
			expect((delta as any).duty_holder.employee).toBeDefined();
		});

		it('handles amendment array changes', () => {
			const existing = {
				name: 'uksi/2024/100',
				amending: ['uksi/2020/50']
			};
			const incoming = {
				name: 'uksi/2024/100',
				amending: ['uksi/2020/50', 'uksi/2021/75']
			};

			const delta = jsondiffpatch.diff(existing, incoming);

			expect(delta).toBeDefined();
			expect((delta as any).amending).toBeDefined();
		});
	});
});
