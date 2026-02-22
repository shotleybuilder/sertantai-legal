/**
 * TanStack Query hooks for LAT Admin API
 */

import { createQuery, createMutation, useQueryClient } from '@tanstack/svelte-query';
import {
	getLatStats,
	getLatLaws,
	getLatRows,
	getAnnotations,
	reparseLat,
	type LatStats,
	type LawSummary,
	type LatRowsResponse,
	type AnnotationsResponse,
	type ReparseResult
} from '$lib/api/lat';

// Query Keys
export const latKeys = {
	all: ['lat'] as const,
	stats: () => [...latKeys.all, 'stats'] as const,
	laws: (search?: string, typeCode?: string) =>
		[...latKeys.all, 'laws', search, typeCode] as const,
	rows: (lawName: string, limit?: number, offset?: number) =>
		[...latKeys.all, 'rows', lawName, limit, offset] as const,
	annotations: (lawName: string) => [...latKeys.all, 'annotations', lawName] as const
};

/**
 * Query: Get LAT aggregate statistics
 */
export function useLatStatsQuery() {
	return createQuery<LatStats>({
		queryKey: latKeys.stats(),
		queryFn: getLatStats
	});
}

/**
 * Query: Get laws with LAT data
 */
export function useLatLawsQuery(search?: string, typeCode?: string) {
	return createQuery<{ laws: LawSummary[]; count: number }>({
		queryKey: latKeys.laws(search, typeCode),
		queryFn: () => getLatLaws(search, typeCode)
	});
}

/**
 * Query: Get LAT rows for a specific law
 */
export function useLatRowsQuery(lawName: string, limit?: number, offset?: number) {
	return createQuery<LatRowsResponse>({
		queryKey: latKeys.rows(lawName, limit, offset),
		queryFn: () => getLatRows(lawName, limit, offset),
		enabled: !!lawName
	});
}

/**
 * Query: Get annotations for a specific law
 */
export function useAnnotationsQuery(lawName: string) {
	return createQuery<AnnotationsResponse>({
		queryKey: latKeys.annotations(lawName),
		queryFn: () => getAnnotations(lawName),
		enabled: !!lawName
	});
}

/**
 * Mutation: Trigger LAT re-parse for a law
 */
export function useReparseMutation() {
	const queryClient = useQueryClient();

	return createMutation<ReparseResult, Error, string>({
		mutationFn: (lawName: string) => reparseLat(lawName),
		onSuccess: (_data, lawName) => {
			// Invalidate all queries that may have changed
			queryClient.invalidateQueries({ queryKey: latKeys.stats() });
			queryClient.invalidateQueries({ queryKey: ['lat', 'laws'] });
			queryClient.invalidateQueries({ queryKey: ['lat', 'rows', lawName] });
			queryClient.invalidateQueries({ queryKey: latKeys.annotations(lawName) });
		}
	});
}
