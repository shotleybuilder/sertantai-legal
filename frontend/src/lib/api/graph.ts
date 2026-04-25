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

export interface FamilyMismatch {
	law_name: string;
	title: string | null;
	si_code: string[];
	assigned_family: string | null;
	suggested_family: string | null;
	confidence: string;
	parent_families: [string, number][];
	target_families: [string, number][];
}

export interface FamilyMismatchResponse {
	mismatches: FamilyMismatch[];
	count: number;
	total: number;
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

export async function getFamilyMismatches(limit?: number): Promise<FamilyMismatchResponse> {
	const params = new URLSearchParams();
	if (limit) params.set('limit', String(limit));
	const qs = params.toString();
	return fetchJson(`${API_URL}/api/graph/family-mismatches${qs ? `?${qs}` : ''}`);
}

export async function getFamilyInference(lawName: string): Promise<FamilyInference> {
	return fetchJson(`${API_URL}/api/graph/family-inference/${encodeURIComponent(lawName)}`);
}
