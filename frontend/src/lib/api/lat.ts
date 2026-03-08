/**
 * LAT Admin API Client
 *
 * Functions for interacting with the LAT admin backend endpoints.
 */

import { getAuthToken } from '$lib/stores/auth';

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
	[key: string]: unknown; // Index signature for TableKit compatibility
	law_id: string;
	law_name: string;
	title_en: string;
	year: number;
	type_code: string;
	family: string | null;
	live: string | null;
	function: string[] | null;
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

// ── LAT Session types ──────────────────────────────────────────────

export interface LatSession {
	id: string;
	session_id: string;
	session_type: string;
	status: string;
	group1_count: number;
	persisted_count: number;
	lat_total_inserted: number;
	lat_total_annotations: number;
	inserted_at: string;
	updated_at: string;
}

export interface LatSessionRecord {
	law_name: string;
	title_en: string;
	type_code: string;
	year: number | null;
	family: string;
	status: string;
	selected: boolean;
	lat_inserted: number | null;
	lat_deleted: number | null;
	annotations_inserted: number | null;
	parse_duration_ms: number | null;
	parse_error: string | null;
	parse_count: number;
}

export interface LatSessionFilters {
	family: string;
	type_code?: string;
	function?: string;
	queue_reason?: 'missing' | 'stale';
}

export interface LatParseResult {
	law_name: string;
	lat: { inserted: number; deleted: number };
	annotations: { inserted: number };
	duration_ms: number;
	has_errors: boolean;
}

async function fetchWithAuth(url: string, options: RequestInit = {}): Promise<Response> {
	const { authFetch } = await import('$lib/api/client');
	const response = await authFetch(url, options);

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

// ── LAT Session API ────────────────────────────────────────────────

export async function previewLatSession(filters: LatSessionFilters): Promise<{ count: number }> {
	const response = await fetchWithAuth(`${API_URL}/api/lat/sessions/preview`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(filters)
	});
	return response.json();
}

export async function createLatSession(
	filters: LatSessionFilters
): Promise<{ session_id: string; session_type: string; status: string; group1_count: number }> {
	const response = await fetchWithAuth(`${API_URL}/api/lat/sessions`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(filters)
	});
	return response.json();
}

export async function getLatSessions(): Promise<{ sessions: LatSession[] }> {
	const response = await fetchWithAuth(`${API_URL}/api/lat/sessions`);
	return response.json();
}

export async function getLatSession(sessionId: string): Promise<LatSession> {
	const response = await fetchWithAuth(
		`${API_URL}/api/lat/sessions/${encodeURIComponent(sessionId)}`
	);
	return response.json();
}

export async function getLatSessionRecords(
	sessionId: string
): Promise<{ records: LatSessionRecord[]; count: number }> {
	const response = await fetchWithAuth(
		`${API_URL}/api/lat/sessions/${encodeURIComponent(sessionId)}/records`
	);
	return response.json();
}

export async function updateLatSelection(
	sessionId: string,
	names: string[],
	selected: boolean
): Promise<{ updated: number }> {
	const response = await fetchWithAuth(
		`${API_URL}/api/lat/sessions/${encodeURIComponent(sessionId)}/records/select`,
		{
			method: 'PATCH',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ names, selected })
		}
	);
	return response.json();
}

export async function confirmLatRecord(
	sessionId: string,
	lawName: string
): Promise<{
	law_name: string;
	status: string;
	lat_inserted: number;
	annotations_inserted: number;
}> {
	const response = await fetchWithAuth(
		`${API_URL}/api/lat/sessions/${encodeURIComponent(sessionId)}/confirm`,
		{
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({ law_name: lawName })
		}
	);
	return response.json();
}

export async function deleteLatSession(sessionId: string): Promise<{ message: string }> {
	const response = await fetchWithAuth(
		`${API_URL}/api/lat/sessions/${encodeURIComponent(sessionId)}`,
		{ method: 'DELETE' }
	);
	return response.json();
}

// ── LAT Parse SSE Stream ───────────────────────────────────────────

export type LatParseStage =
	| 'fetch_body'
	| 'parse_lat'
	| 'persist_lat'
	| 'parse_annotations'
	| 'persist_annotations';

export interface LatParseProgressCallbacks {
	onStageStart?: (stage: LatParseStage, stageNum: number, total: number) => void;
	onStageComplete?: (
		stage: LatParseStage,
		status: 'ok' | 'error' | 'skipped',
		summary: string | null
	) => void;
	onComplete?: (result: LatParseResult) => void;
	onError?: (error: Error) => void;
}

/**
 * Stream LAT parse progress via SSE. Returns a cleanup function to abort the connection.
 */
export function latParseStream(
	sessionId: string,
	lawName: string,
	callbacks: LatParseProgressCallbacks
): () => void {
	let url = `${API_URL}/api/lat/sessions/${encodeURIComponent(sessionId)}/parse-stream?name=${encodeURIComponent(lawName)}`;

	// EventSource doesn't support custom headers — pass token as query param
	const token = getAuthToken();
	if (token) {
		url += `&token=${encodeURIComponent(token)}`;
	}

	const eventSource = new EventSource(url);

	eventSource.onmessage = (event) => {
		try {
			const data = JSON.parse(event.data);

			switch (data.event) {
				case 'connected':
					break;
				case 'stage_start':
					callbacks.onStageStart?.(data.stage, data.stage_num, data.total);
					break;
				case 'stage_complete':
					callbacks.onStageComplete?.(data.stage, data.status, data.summary);
					break;
				case 'parse_complete':
					callbacks.onComplete?.(data.result);
					eventSource.close();
					break;
				case 'parse_done':
					// Internal event from LatStagedParser — final result comes in parse_complete
					break;
			}
		} catch (err) {
			console.error('Failed to parse LAT SSE event:', err);
		}
	};

	eventSource.onerror = () => {
		if (eventSource.readyState === EventSource.CONNECTING) {
			return; // Let it reconnect
		}
		callbacks.onError?.(new Error('Connection to LAT parse stream failed.'));
		eventSource.close();
	};

	return () => {
		eventSource.close();
	};
}
