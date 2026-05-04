/**
 * TanStack Query hooks for Graph / Family Inference API
 */

import { createQuery } from '@tanstack/svelte-query';
import {
	getGraphStats,
	getMismatchCounts,
	getEnactedByMismatches,
	getAmendsMismatches,
	getRescindsMismatches,
	getFamilyInference,
	type GraphStats,
	type MismatchCounts,
	type MismatchResponse,
	type EnactedByItem,
	type AmendsMismatch,
	type RescindsMismatch,
	type FamilyInference
} from '$lib/api/graph';

export const graphKeys = {
	all: ['graph'] as const,
	stats: () => [...graphKeys.all, 'stats'] as const,
	counts: () => [...graphKeys.all, 'counts'] as const,
	enactedBy: () => [...graphKeys.all, 'enacted_by'] as const,
	amends: () => [...graphKeys.all, 'amends'] as const,
	rescinds: () => [...graphKeys.all, 'rescinds'] as const,
	inference: (lawName: string) => [...graphKeys.all, 'inference', lawName] as const
};

export function useGraphStatsQuery() {
	return createQuery<GraphStats>({
		queryKey: graphKeys.stats(),
		queryFn: getGraphStats
	});
}

export function useMismatchCountsQuery() {
	return createQuery<MismatchCounts>({
		queryKey: graphKeys.counts(),
		queryFn: getMismatchCounts
	});
}

export function useEnactedByQuery() {
	return createQuery<MismatchResponse<EnactedByItem>>({
		queryKey: graphKeys.enactedBy(),
		queryFn: getEnactedByMismatches
	});
}

export function useAmendsQuery() {
	return createQuery<MismatchResponse<AmendsMismatch>>({
		queryKey: graphKeys.amends(),
		queryFn: getAmendsMismatches
	});
}

export function useRescindsQuery() {
	return createQuery<MismatchResponse<RescindsMismatch>>({
		queryKey: graphKeys.rescinds(),
		queryFn: getRescindsMismatches
	});
}

export function useFamilyInferenceQuery(lawName: string | null) {
	return createQuery<FamilyInference>({
		queryKey: graphKeys.inference(lawName ?? ''),
		queryFn: () => getFamilyInference(lawName!),
		enabled: !!lawName
	});
}
