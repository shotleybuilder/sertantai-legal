/**
 * LAT Admin API Client
 *
 * Functions for interacting with the LAT admin backend endpoints.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

export interface LatStats {
	total_lat_rows: number;
	laws_with_lat: number;
	total_annotations: number;
	laws_with_annotations: number;
	section_type_counts: Record<string, number>;
	code_type_counts: Record<string, number>;
}

export interface LawSummary {
	law_name: string;
	law_id: string;
	title_en: string;
	year: number;
	type_code: string;
	lat_count: number;
	annotation_count: number;
}

export interface LatRow {
	section_id: string;
	law_name: string;
	law_id: string;
	section_type: string;
	sort_key: string;
	position: number;
	depth: number;
	part: string | null;
	chapter: string | null;
	heading_group: string | null;
	provision: string | null;
	paragraph: string | null;
	sub_paragraph: string | null;
	schedule: string | null;
	text: string;
	language: string;
	extent_code: string | null;
	hierarchy_path: string | null;
	amendment_count: number | null;
	modification_count: number | null;
	commencement_count: number | null;
	extent_count: number | null;
	editorial_count: number | null;
	created_at: string | null;
	updated_at: string | null;
}

export interface AnnotationRow {
	id: string;
	law_name: string;
	law_id: string;
	code: string;
	code_type: string;
	source: string;
	text: string;
	affected_sections: string[] | null;
	created_at: string | null;
	updated_at: string | null;
}

export interface LatRowsResponse {
	law_name: string;
	rows: LatRow[];
	count: number;
	total_count: number;
	limit: number;
	offset: number;
	has_more: boolean;
}

export interface AnnotationsResponse {
	law_name: string;
	annotations: AnnotationRow[];
	count: number;
}

export interface QueueItem {
	law_id: string;
	law_name: string;
	title_en: string;
	year: number;
	type_code: string;
	lrt_updated_at: string | null;
	lat_count: number;
	latest_lat_updated_at: string | null;
	queue_reason: 'missing' | 'stale';
}

export interface QueueResponse {
	items: QueueItem[];
	count: number;
	total: number;
	missing_count: number;
	stale_count: number;
	filtered_total: number;
	limit: number;
	offset: number;
	has_more: boolean;
}

export interface ReparseResult {
	law_name: string;
	lat: { inserted: number };
	annotations: { inserted: number };
	duration_ms: number;
}

async function fetchWithAuth(url: string, options: RequestInit = {}): Promise<Response> {
	const response = await fetch(url, {
		...options,
		credentials: 'include'
	});

	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}

	return response;
}

export async function getLatStats(): Promise<LatStats> {
	const response = await fetchWithAuth(`${API_URL}/api/lat/stats`);
	return response.json();
}

export async function getLatLaws(
	search?: string,
	typeCode?: string
): Promise<{ laws: LawSummary[]; count: number }> {
	const params = new URLSearchParams();
	if (search) params.set('search', search);
	if (typeCode) params.set('type_code', typeCode);

	const qs = params.toString();
	const url = `${API_URL}/api/lat/laws${qs ? `?${qs}` : ''}`;
	const response = await fetchWithAuth(url);
	return response.json();
}

export async function getLatRows(
	lawName: string,
	limit?: number,
	offset?: number
): Promise<LatRowsResponse> {
	const params = new URLSearchParams();
	if (limit !== undefined) params.set('limit', String(limit));
	if (offset !== undefined) params.set('offset', String(offset));

	const qs = params.toString();
	const url = `${API_URL}/api/lat/laws/${encodeURIComponent(lawName)}${qs ? `?${qs}` : ''}`;
	const response = await fetchWithAuth(url);
	return response.json();
}

export async function getAnnotations(lawName: string): Promise<AnnotationsResponse> {
	const url = `${API_URL}/api/lat/laws/${encodeURIComponent(lawName)}/annotations`;
	const response = await fetchWithAuth(url);
	return response.json();
}

export async function reparseLat(lawName: string): Promise<ReparseResult> {
	const url = `${API_URL}/api/lat/laws/${encodeURIComponent(lawName)}/reparse`;
	const response = await fetchWithAuth(url, { method: 'POST' });
	return response.json();
}

export async function getLatQueue(
	limit?: number,
	offset?: number,
	reason?: 'missing' | 'stale'
): Promise<QueueResponse> {
	const params = new URLSearchParams();
	if (limit !== undefined) params.set('limit', String(limit));
	if (offset !== undefined) params.set('offset', String(offset));
	if (reason) params.set('reason', reason);

	const qs = params.toString();
	const url = `${API_URL}/api/lat/queue${qs ? `?${qs}` : ''}`;
	const response = await fetchWithAuth(url);
	return response.json();
}
