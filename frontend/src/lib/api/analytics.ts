/**
 * Analytics API Client
 *
 * Functions for fetching LRT analytics: change tracking and session metrics.
 */

import { authFetch } from '$lib/api/client';

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
	const response = await authFetch(url);

	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}

	return response;
}

// ── Live Status Assurance Types ──────────────────────────────────

export interface LiveStatusAssurance {
	pipeline_coverage: {
		total: number;
		reconciled: number;
		changes_only: number;
		metadata_only: number;
		airtable_only: number;
		no_status: number;
	};
	source_agreement: {
		reconciled: number;
		agreeing: number;
		conflicting: number;
		conflict_breakdown: Array<{
			live_from_changes: string;
			live_from_metadata: string;
			live_source: string;
			count: number;
		}>;
	};
	misclassified: number;
	affect_distribution: Array<{ affect_type: string; count: number }>;
	target_distribution: Array<{ target_type: string; count: number }>;
	families: Array<{
		family: string | null;
		total: number;
		reconciled: number;
		in_force: number;
		revoked: number;
		partial: number;
		unknown: number;
	}>;
	applied_status: Array<{ status: string; count: number }>;
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

export async function getLiveStatusAssurance(): Promise<LiveStatusAssurance> {
	const response = await fetchWithAuth(`${API_URL}/api/analytics/live-status`);
	return response.json();
}

export async function getMisclassifiedNames(): Promise<{ names: string[]; count: number }> {
	const response = await fetchWithAuth(`${API_URL}/api/analytics/live-status/misclassified`);
	return response.json();
}
