/**
 * Graph / Family Inference API Client
 */

import { authFetch } from '$lib/api/client';

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

export interface GraphStats {
	total_edges: number;
	edge_types: Record<string, number>;
	laws_with_edges: number;
	laws_with_classified_parents: number;
	potential_mismatches: number;
}

export interface EnactedByMismatch {
	law_name: string;
	law_id: string;
	title: string | null;
	si_code: string[];
	md_description: string | null;
	assigned_family: string | null;
	family_ii: string | null;
	parent_law: string;
	parent_id: string;
	parent_title: string | null;
	parent_enacted_si_codes: Record<string, number>;
	parent_family: string;
	parent_family_ii: string | null;
	title_confirmed: boolean;
}

export interface AmendsMismatch {
	law_name: string;
	assigned_family: string | null;
	suggested_family: string;
	consensus_pct: number;
	total_amends: number;
	target_families: { family: string; count: number }[];
}

export interface RescindsMismatch {
	law_name: string;
	title: string | null;
	assigned_family: string | null;
	rescinded_law: string;
	rescinded_title: string | null;
	rescinded_family: string;
}

export interface MismatchResponse<T> {
	items: T[];
	count: number;
}

export interface MismatchCounts {
	enacted_by: number;
	amends: number;
	rescinds: number;
}

export interface FamilyInference {
	assigned_family: string | null;
	suggested_family: string | null;
	confidence: string;
	parent_families: [string, number][];
	target_families: [string, number][];
	mismatch: boolean;
}

async function fetchJson<T>(url: string): Promise<T> {
	const response = await authFetch(url);
	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}
	return response.json();
}

export async function getGraphStats(): Promise<GraphStats> {
	return fetchJson(`${API_URL}/api/graph/stats`);
}

export async function getMismatchCounts(): Promise<MismatchCounts> {
	return fetchJson(`${API_URL}/api/graph/family-mismatches`);
}

export async function getEnactedByMismatches(): Promise<MismatchResponse<EnactedByMismatch>> {
	return fetchJson(`${API_URL}/api/graph/family-mismatches?type=enacted_by`);
}

export async function getAmendsMismatches(): Promise<MismatchResponse<AmendsMismatch>> {
	return fetchJson(`${API_URL}/api/graph/family-mismatches?type=amends`);
}

export async function getRescindsMismatches(): Promise<MismatchResponse<RescindsMismatch>> {
	return fetchJson(`${API_URL}/api/graph/family-mismatches?type=rescinds`);
}

export async function updateLawFamily(
	lawId: string,
	updates: { family?: string | null; family_ii?: string | null }
): Promise<void> {
	const response = await authFetch(`${API_URL}/api/uk-lrt/${lawId}`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(updates)
	});
	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}
}

export interface RescrapeResult {
	law_name: string;
	status: string;
	stages: Record<string, string>;
	duration_ms: number;
}

export async function rescrapeLrt(lawName: string): Promise<RescrapeResult> {
	const response = await authFetch(
		`${API_URL}/api/graph/rescrape-lrt/${encodeURIComponent(lawName)}`,
		{
			method: 'POST'
		}
	);
	if (!response.ok) {
		const body = await response.json().catch(() => ({ error: response.statusText }));
		throw new Error(body.error || `HTTP ${response.status}`);
	}
	return response.json();
}

export async function getFamilyInference(lawName: string): Promise<FamilyInference> {
	return fetchJson(`${API_URL}/api/graph/family-inference/${encodeURIComponent(lawName)}`);
}
