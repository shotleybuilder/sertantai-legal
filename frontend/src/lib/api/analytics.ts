/**
 * Analytics API Client
 *
 * Functions for fetching LRT analytics: change tracking and session metrics.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

// ── Change Tracking Types ────────────────────────────────────────────

export interface ChangeTrackingStats {
	records_with_changes: number;
	total_entries: number;
	by_source: Array<{ source: string; count: number }>;
	by_changed_by: Array<{ changed_by: string; count: number }>;
	top_changed_fields: Array<{ field: string; count: number }>;
	timeline: Array<{ date: string; count: number }>;
}

// ── Session Analytics Types ──────────────────────────────────────────

export interface SessionSummaryRow {
	session_type: string;
	status: string;
	count: number;
	total_group1: number;
	total_persisted: number;
	total_lat_inserted: number;
	total_lat_annotations: number;
}

export interface RecentSession {
	session_id: string;
	session_type: string;
	status: string;
	year: number;
	month: number;
	day_from: number;
	day_to: number;
	type_code: string | null;
	total_fetched: number | null;
	group1_count: number | null;
	persisted_count: number | null;
	lat_total_inserted: number | null;
	lat_total_annotations: number | null;
	inserted_at: string;
	updated_at: string;
}

export interface SessionAnalytics {
	summary: SessionSummaryRow[];
	recent: RecentSession[];
	totals: {
		total_sessions: number;
		total_records_processed: number;
		total_persisted: number;
	};
}

// ── Fetch Helper ─────────────────────────────────────────────────────

async function fetchWithAuth(url: string): Promise<Response> {
	const { authFetch } = await import('$lib/api/client');
	const response = await authFetch(url);

	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}

	return response;
}

// ── API Functions ────────────────────────────────────────────────────

export async function getChangeTrackingStats(): Promise<ChangeTrackingStats> {
	const response = await fetchWithAuth(`${API_URL}/api/analytics/changes`);
	return response.json();
}

export async function getSessionAnalytics(): Promise<SessionAnalytics> {
	const response = await fetchWithAuth(`${API_URL}/api/analytics/sessions`);
	return response.json();
}
