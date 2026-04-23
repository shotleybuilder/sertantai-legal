/**
 * LAT Audit API Client
 */

import { authFetch } from '$lib/api/client';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

export interface AuditLawResult {
	law_name: string;
	title: string | null;
	family: string | null;
	year: number | null;
	total_rows: number;
	structural_rows: number;
	section_rows: number;
	total_text_bytes: number;
	structural_text_bytes: number;
	structural_text_pct: number;
	max_row_bytes: number;
	empty_section_count: number;
	blob_count: number;
	status: 'clean' | 'warning' | 'error';
}

export interface AuditCorpusSummary {
	total_rows: number;
	total_laws: number;
	structural_rows: number;
	section_rows: number;
	total_text_bytes: number;
	structural_text_bytes: number;
	structural_text_pct: number;
	empty_section_count: number;
	blob_count: number;
}

export interface AuditResponse {
	corpus: AuditCorpusSummary;
	laws: AuditLawResult[];
	counts: {
		total: number;
		clean: number;
		warning: number;
		error: number;
	};
}

export interface AuditWarning {
	check: string;
	severity: 'warning' | 'error';
	message: string;
	detail: Record<string, unknown>;
}

export interface AuditLawDetail {
	law_name: string;
	status: string;
	summary: {
		total_rows: number;
		structural_rows: number;
		section_rows: number;
		type_counts: Record<string, number>;
		structural_text_bytes: number;
		section_text_bytes: number;
		total_text_bytes: number;
		structural_text_pct: number;
		max_row_text_bytes: number;
		max_row_section_id: string | null;
	};
	warnings: AuditWarning[];
}

async function fetchJson<T>(url: string): Promise<T> {
	const response = await authFetch(url);
	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}
	return response.json();
}

export async function getAuditSummary(family?: string): Promise<AuditResponse> {
	const params = new URLSearchParams();
	if (family) params.set('family', family);
	const qs = params.toString();
	return fetchJson(`${API_URL}/api/lat/audit${qs ? `?${qs}` : ''}`);
}

export async function getAuditLaw(lawName: string): Promise<AuditLawDetail> {
	return fetchJson(`${API_URL}/api/lat/audit/${encodeURIComponent(lawName)}`);
}
