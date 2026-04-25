/**
 * TanStack Query hooks for Graph / Family Inference API
 */

import { createQuery } from '@tanstack/svelte-query';
import {
	getGraphStats,
	getFamilyMismatches,
	getFamilyInference,
	type GraphStats,
	type FamilyMismatchResponse,
	type FamilyInference
} from '$lib/api/graph';

export const graphKeys = {
	all: ['graph'] as const,
	stats: () => [...graphKeys.all, 'stats'] as const,
	mismatches: () => [...graphKeys.all, 'mismatches'] as const,
	inference: (lawName: string) => [...graphKeys.all, 'inference', lawName] as const
};

export function useGraphStatsQuery() {
	return createQuery<GraphStats>({
		queryKey: graphKeys.stats(),
		queryFn: getGraphStats
	});
}

export function useFamilyMismatchesQuery() {
	return createQuery<FamilyMismatchResponse>({
		queryKey: graphKeys.mismatches(),
		queryFn: () => getFamilyMismatches(500)
	});
}

export function useFamilyInferenceQuery(lawName: string | null) {
	return createQuery<FamilyInference>({
		queryKey: graphKeys.inference(lawName ?? ''),
		queryFn: () => getFamilyInference(lawName!),
		enabled: !!lawName
	});
}
