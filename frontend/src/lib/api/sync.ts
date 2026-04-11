/**
 * Sync Service API Client
 *
 * Functions for managing entitlements, sync profiles, configurations, and jobs.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

import { authFetch } from '$lib/api/client';

async function adminFetch(url: string, options: RequestInit = {}): Promise<Response> {
	return authFetch(url, options);
}

// ── Types ──────────────────────────────────────────────────────────

export interface OrgEntitlement {
	id: string;
	organization_id: string;
	families: string[];
	data_tier: 'lrt_only' | 'lrt_lat' | 'lrt_lat_amendments';
	field_tier: 'essential' | 'standard' | 'full';
	source: string;
	granted_at: string;
	expires_at: string | null;
}

export interface SyncProfile {
	id: string;
	name: string;
	description: string | null;
	families: string[];
	geo_regions: string[] | null;
	function_filter: Record<string, unknown> | null;
	fitness_person: string[] | null;
	fitness_process: string[] | null;
	fitness_place: string[] | null;
	fitness_plant: string[] | null;
	fitness_sector: string[] | null;
	live_filter: string[] | null;
	include_lat: boolean;
	include_amendments: boolean;
	matched_law_count: number | null;
	matched_lat_count: number | null;
	is_active: boolean;
	deactivation_reason: string | null;
	inserted_at: string;
	updated_at: string;
}

export interface SyncConfiguration {
	id: string;
	sync_profile_id: string;
	name: string;
	provider: 'baserow' | 'airtable' | 'notion' | 'zapier';
	target_config: Record<string, unknown>;
	field_mapping: Record<string, string> | null;
	sync_frequency: 'manual' | 'daily' | 'weekly';
	on_filter_change: 'delete' | 'retain';
	on_entitlement_change: 'delete' | 'retain';
	sync_status: 'idle' | 'queued' | 'syncing' | 'completed' | 'failed';
	last_synced_at: string | null;
	last_sync_summary: {
		rows_created: number;
		rows_updated: number;
		rows_deleted: number;
		rows_failed: number;
	} | null;
	is_active: boolean;
	inserted_at: string;
	updated_at: string;
}

export interface SyncJob {
	id: string;
	sync_configuration_id: string;
	status: 'queued' | 'running' | 'completed' | 'failed' | 'cancelled';
	started_at: string | null;
	completed_at: string | null;
	law_count: number | null;
	lat_count: number | null;
	rows_created: number;
	rows_updated: number;
	rows_deleted: number;
	rows_failed: number;
	error_message: string | null;
	inserted_at: string;
}

// ── Entitlements ───────────────────────────────────────────────────

export async function fetchEntitlement(): Promise<OrgEntitlement | null> {
	const res = await adminFetch(`${API_URL}/api/sync/entitlement`);
	if (res.status === 404) return null;
	if (!res.ok) throw new Error(`Failed to fetch entitlement: ${res.status}`);
	return res.json();
}

// ── Profiles ───────────────────────────────────────────────────────

export async function fetchProfiles(): Promise<SyncProfile[]> {
	const res = await adminFetch(`${API_URL}/api/sync/profiles`);
	if (!res.ok) throw new Error(`Failed to fetch profiles: ${res.status}`);
	const data = await res.json();
	return data.profiles;
}

export async function createProfile(profile: Partial<SyncProfile>): Promise<SyncProfile> {
	const res = await adminFetch(`${API_URL}/api/sync/profiles`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(profile)
	});
	if (!res.ok) throw new Error(`Failed to create profile: ${res.status}`);
	return res.json();
}

export async function updateProfile(
	id: string,
	updates: Partial<SyncProfile>
): Promise<SyncProfile> {
	const res = await adminFetch(`${API_URL}/api/sync/profiles/${id}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(updates)
	});
	if (!res.ok) throw new Error(`Failed to update profile: ${res.status}`);
	return res.json();
}

export async function deleteProfile(id: string): Promise<void> {
	const res = await adminFetch(`${API_URL}/api/sync/profiles/${id}`, {
		method: 'DELETE'
	});
	if (!res.ok) throw new Error(`Failed to delete profile: ${res.status}`);
}

export async function previewProfile(
	filters: Partial<SyncProfile>
): Promise<{ matched_law_count: number; matched_lat_count: number }> {
	const res = await adminFetch(`${API_URL}/api/sync/profiles/preview`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(filters)
	});
	if (!res.ok) throw new Error(`Failed to preview profile: ${res.status}`);
	return res.json();
}

// ── Configurations ─────────────────────────────────────────────────

export async function fetchConfigurations(): Promise<SyncConfiguration[]> {
	const res = await adminFetch(`${API_URL}/api/sync/configurations`);
	if (!res.ok) throw new Error(`Failed to fetch configurations: ${res.status}`);
	const data = await res.json();
	return data.configurations;
}

export async function createConfiguration(
	config: Record<string, unknown>
): Promise<SyncConfiguration> {
	const res = await adminFetch(`${API_URL}/api/sync/configurations`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(config)
	});
	if (!res.ok) throw new Error(`Failed to create configuration: ${res.status}`);
	return res.json();
}

export async function updateConfiguration(
	id: string,
	updates: Record<string, unknown>
): Promise<SyncConfiguration> {
	const res = await adminFetch(`${API_URL}/api/sync/configurations/${id}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(updates)
	});
	if (!res.ok) throw new Error(`Failed to update configuration: ${res.status}`);
	return res.json();
}

export async function deleteConfiguration(id: string): Promise<void> {
	const res = await adminFetch(`${API_URL}/api/sync/configurations/${id}`, {
		method: 'DELETE'
	});
	if (!res.ok) throw new Error(`Failed to delete configuration: ${res.status}`);
}

export async function testConnection(
	id: string
): Promise<{ ok: boolean; info?: Record<string, unknown>; error?: string }> {
	const res = await adminFetch(`${API_URL}/api/sync/configurations/${id}/test`, {
		method: 'POST'
	});
	return res.json();
}

export async function triggerSync(id: string): Promise<{ ok: boolean; message: string }> {
	const res = await adminFetch(`${API_URL}/api/sync/configurations/${id}/sync`, {
		method: 'POST'
	});
	if (!res.ok) throw new Error(`Failed to trigger sync: ${res.status}`);
	return res.json();
}

// ── Jobs ───────────────────────────────────────────────────────────

export async function fetchJobs(): Promise<SyncJob[]> {
	const res = await adminFetch(`${API_URL}/api/sync/jobs`);
	if (!res.ok) throw new Error(`Failed to fetch jobs: ${res.status}`);
	const data = await res.json();
	return data.jobs;
}
