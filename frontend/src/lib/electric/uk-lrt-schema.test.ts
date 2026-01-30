/**
 * Tests for UK LRT schema transformation
 */

import { describe, it, expect } from 'vitest';
import { transformUkLrtRecord, type UkLrtRecord } from './uk-lrt-schema';

describe('transformUkLrtRecord', () => {
	it('transforms basic string fields', () => {
		const raw = {
			id: 'uuid-123',
			name: 'UK_uksi_2024_100',
			title_en: 'Test Regulation 2024'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.id).toBe('uuid-123');
		expect(result.name).toBe('UK_uksi_2024_100');
		expect(result.title_en).toBe('Test Regulation 2024');
	});

	it('transforms numeric fields correctly', () => {
		const raw = {
			id: 'uuid-123',
			year: '2024',
			md_total_paras: '150',
			md_body_paras: '100',
			is_making: '1'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.year).toBe(2024);
		expect(result.md_total_paras).toBe(150);
		expect(result.md_body_paras).toBe(100);
		expect(result.is_making).toBe(1);
	});

	it('handles null values for optional fields', () => {
		const raw = {
			id: 'uuid-123',
			name: 'test',
			family: null,
			family_ii: null,
			si_code: null,
			tags: null,
			function: null
		};

		const result = transformUkLrtRecord(raw);

		expect(result.family).toBeNull();
		expect(result.family_ii).toBeNull();
		expect(result.si_code).toBeNull();
		expect(result.tags).toBeNull();
		expect(result.function).toBeNull();
	});

	it('parses JSON object fields', () => {
		const raw = {
			id: 'uuid-123',
			duty_holder: '{"employer": true, "employee": false}',
			power_holder: { regulator: true },
			purpose: null
		};

		const result = transformUkLrtRecord(raw);

		expect(result.duty_holder).toEqual({ employer: true, employee: false });
		expect(result.power_holder).toEqual({ regulator: true });
		expect(result.purpose).toBeNull();
	});

	it('parses JSON array fields', () => {
		const raw = {
			id: 'uuid-123',
			tags: '["health", "safety", "workplace"]',
			function: ['Making', 'Amending'],
			role: null
		};

		const result = transformUkLrtRecord(raw);

		expect(result.tags).toEqual(['health', 'safety', 'workplace']);
		expect(result.function).toEqual(['Making', 'Amending']);
		expect(result.role).toBeNull();
	});

	it('handles date fields', () => {
		const raw = {
			id: 'uuid-123',
			md_date: '2024-03-15',
			md_made_date: '2024-03-10',
			md_coming_into_force_date: null,
			created_at: '2024-01-01T12:00:00Z',
			updated_at: '2024-06-15T08:30:00Z'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.md_date).toBe('2024-03-15');
		expect(result.md_made_date).toBe('2024-03-10');
		expect(result.md_coming_into_force_date).toBeNull();
		expect(result.created_at).toBe('2024-01-01T12:00:00Z');
		expect(result.updated_at).toBe('2024-06-15T08:30:00Z');
	});

	it('handles URL fields', () => {
		const raw = {
			id: 'uuid-123',
			leg_gov_uk_url: 'https://www.legislation.gov.uk/uksi/2024/100'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.leg_gov_uk_url).toBe('https://www.legislation.gov.uk/uksi/2024/100');
	});

	it('handles missing fields with defaults', () => {
		const raw = {
			id: 'uuid-123'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.id).toBe('uuid-123');
		expect(result.name).toBe('');
		expect(result.title_en).toBe('');
		expect(result.year).toBe(0);
	});

	it('handles numeric string that cannot be parsed', () => {
		const raw = {
			id: 'uuid-123',
			year: 'not-a-number',
			md_total_paras: ''
		};

		const result = transformUkLrtRecord(raw);

		// Should fall back to 0 or null depending on implementation
		expect(typeof result.year).toBe('number');
		expect(result.md_total_paras === null || result.md_total_paras === 0).toBe(true);
	});

	it('preserves all holder fields', () => {
		const raw = {
			id: 'uuid-123',
			duty_holder: { employer: true },
			power_holder: { minister: true },
			rights_holder: { worker: true },
			responsibility_holder: { director: true },
			// Consolidated JSONB fields
			duties: {
				entries: [
					{ holder: 'employer', duty_type: 'Duty', clause: 'Clause 1', article: 'Article 5' }
				],
				holders: ['employer'],
				articles: ['Article 5']
			},
			rights: {
				entries: [{ holder: 'worker', duty_type: 'Right', clause: null, article: 'Section 2' }],
				holders: ['worker'],
				articles: ['Section 2']
			},
			responsibilities: null,
			powers: {
				entries: [{ holder: 'minister', duty_type: 'Power', clause: null, article: null }],
				holders: ['minister'],
				articles: []
			}
		};

		const result = transformUkLrtRecord(raw);

		expect(result.duty_holder).toEqual({ employer: true });
		expect(result.power_holder).toEqual({ minister: true });
		expect(result.rights_holder).toEqual({ worker: true });
		expect(result.responsibility_holder).toEqual({ director: true });
		// Consolidated JSONB fields
		expect(result.duties).toEqual({
			entries: [
				{ holder: 'employer', duty_type: 'Duty', clause: 'Clause 1', article: 'Article 5' }
			],
			holders: ['employer'],
			articles: ['Article 5']
		});
		expect(result.rights?.holders).toEqual(['worker']);
		expect(result.responsibilities).toBeNull();
		expect(result.powers?.holders).toEqual(['minister']);
	});

	it('handles live status field', () => {
		const raw = {
			id: 'uuid-123',
			live: 'Live',
			live_description: 'Currently in force'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.live).toBe('Live');
		expect(result.live_description).toBe('Currently in force');
	});

	it('handles geo extent fields', () => {
		const raw = {
			id: 'uuid-123',
			geo_extent: 'E+W+S+NI',
			geo_region: 'United Kingdom',
			geo_detail: 'Applies to England, Wales, Scotland and Northern Ireland'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.geo_extent).toBe('E+W+S+NI');
		expect(result.geo_region).toBe('United Kingdom');
		expect(result.geo_detail).toBe('Applies to England, Wales, Scotland and Northern Ireland');
	});

	it('transforms a complete realistic record', () => {
		const raw = {
			id: 'f47ac10b-58cc-4372-a567-0e02b2c3d479',
			name: 'UK_uksi_2024_100',
			title_en: 'The Health and Safety (Amendment) Regulations 2024',
			year: 2024,
			number: '100',
			type_code: 'uksi',
			type_class: 'secondary',
			family: 'OH&S: Occupational / Personal Safety',
			family_ii: null,
			live: 'Live',
			live_description: 'In force',
			geo_extent: 'E+W+S',
			geo_region: 'Great Britain',
			tags: ['health', 'safety'],
			function: ['Amending'],
			md_made_date: '2024-02-15',
			md_coming_into_force_date: '2024-04-06',
			md_total_paras: 25,
			leg_gov_uk_url: 'https://www.legislation.gov.uk/uksi/2024/100',
			created_at: '2024-01-10T10:00:00Z',
			updated_at: '2024-03-01T15:30:00Z'
		};

		const result = transformUkLrtRecord(raw);

		expect(result.id).toBe('f47ac10b-58cc-4372-a567-0e02b2c3d479');
		expect(result.name).toBe('UK_uksi_2024_100');
		expect(result.title_en).toBe('The Health and Safety (Amendment) Regulations 2024');
		expect(result.year).toBe(2024);
		expect(result.type_code).toBe('uksi');
		expect(result.family).toBe('OH&S: Occupational / Personal Safety');
		expect(result.live).toBe('Live');
		expect(result.geo_extent).toBe('E+W+S');
		expect(result.tags).toEqual(['health', 'safety']);
		expect(result.function).toEqual(['Amending']);
		expect(result.md_total_paras).toBe(25);
		expect(result.leg_gov_uk_url).toBe('https://www.legislation.gov.uk/uksi/2024/100');
	});
});

describe('UkLrtRecord type', () => {
	it('should have required id field', () => {
		const record: UkLrtRecord = {
			id: 'test-id',
			name: '',
			title_en: '',
			year: 0,
			number: '',
			type_code: '',
			type_class: '',
			family: null,
			family_ii: null,
			live: null,
			live_description: null,
			geo_extent: null,
			geo_region: null,
			geo_detail: null,
			md_restrict_extent: null,
			si_code: null,
			tags: null,
			function: null,
			role: null,
			role_gvt: null,
			article_role: null,
			role_article: null,
			duty_type: null,
			duty_type_article: null,
			article_duty_type: null,
			duty_holder: null,
			power_holder: null,
			rights_holder: null,
			responsibility_holder: null,
			// Consolidated JSONB holder fields
			duties: null,
			rights: null,
			responsibilities: null,
			powers: null,
			popimar: null,
			popimar_article: null,
			popimar_article_clause: null,
			article_popimar: null,
			article_popimar_clause: null,
			purpose: null,
			is_making: null,
			enacted_by: null,
			amending: null,
			amended_by: null,
			md_date: null,
			md_made_date: null,
			md_enactment_date: null,
			md_coming_into_force_date: null,
			md_dct_valid_date: null,
			md_restrict_start_date: null,
			md_total_paras: null,
			md_body_paras: null,
			md_schedule_paras: null,
			md_attachment_paras: null,
			md_images: null,
			latest_amend_date: null,
			leg_gov_uk_url: null,
			created_at: null,
			updated_at: null
		};

		expect(record.id).toBe('test-id');
	});
});
