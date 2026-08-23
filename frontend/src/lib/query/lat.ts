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
	getLatQueue,
	getLatSessions,
	getLatSession,
	getLatSessionRecords,
	createLatSession,
	deleteLatSession,
	updateLatSelection,
	confirmLatRecord,
	type LatStats,
	type LawSummary,
	type LatRowsResponse,
	type AnnotationsResponse,
	type ReparseResult,
	type QueueResponse,
	type LatSession,
	type LatSessionRecord,
	type LatSessionFilters
} from '$lib/api/lat';

// Query Keys
export const latKeys = {
	all: ['lat'] as const,
	stats: () => [...latKeys.all, 'stats'] as const,
	queue: (limit?: number, offset?: number, reason?: string) =>
		[...latKeys.all, 'queue', limit, offset, reason] as const,
	laws: (search?: string, typeCode?: string) => [...latKeys.all, 'laws', search, typeCode] as const,
	rows: (lawName: string, limit?: number, offset?: number) =>
		[...latKeys.all, 'rows', lawName, limit, offset] as const,
	annotations: (lawName: string) => [...latKeys.all, 'annotations', lawName] as const,
	sessions: () => [...latKeys.all, 'sessions'] as const,
	session: (id: string) => [...latKeys.all, 'session', id] as const,
	sessionRecords: (id: string) => [...latKeys.all, 'session', id, 'records'] as const
};

/**
 * Query: Get LAT aggregate statistics
 */
export function useLatStatsQuery() {
	return createQuery<LatStats>(() => ({
		queryKey: latKeys.stats(),
		queryFn: getLatStats
	}));
}

/**
 * Query: Get laws with LAT data
 */
export function useLatLawsQuery(search?: string, typeCode?: string) {
	return createQuery<{ laws: LawSummary[]; count: number }>(() => ({
		queryKey: latKeys.laws(search, typeCode),
		queryFn: () => getLatLaws(search, typeCode)
	}));
}

/**
 * Query: Get LAT rows for a specific law
 */
export function useLatRowsQuery(lawName: string, limit?: number, offset?: number) {
	return createQuery<LatRowsResponse>(() => ({
		queryKey: latKeys.rows(lawName, limit, offset),
		queryFn: () => getLatRows(lawName, limit, offset),
		enabled: !!lawName
	}));
}

/**
 * Query: Get annotations for a specific law
 */
export function useAnnotationsQuery(lawName: string) {
	return createQuery<AnnotationsResponse>(() => ({
		queryKey: latKeys.annotations(lawName),
		queryFn: () => getAnnotations(lawName),
		enabled: !!lawName
	}));
}

/**
 * Query: Get LAT parse queue (LRT records needing LAT parsing)
 */
export function useLatQueueQuery(limit?: number, offset?: number, reason?: 'missing' | 'stale') {
	return createQuery<QueueResponse>(() => ({
		queryKey: latKeys.queue(limit, offset, reason),
		queryFn: () => getLatQueue(limit, offset, reason)
	}));
}

/**
 * Mutation: Trigger LAT re-parse for a law
 */
export function useReparseMutation() {
	const queryClient = useQueryClient();

	return createMutation<ReparseResult, Error, string>(() => ({
		mutationFn: (lawName: string) => reparseLat(lawName),
		onSuccess: (_data, lawName) => {
			// Invalidate all queries that may have changed
			queryClient.invalidateQueries({ queryKey: latKeys.stats() });
			queryClient.invalidateQueries({ queryKey: ['lat', 'queue'] });
			queryClient.invalidateQueries({ queryKey: ['lat', 'laws'] });
			queryClient.invalidateQueries({ queryKey: ['lat', 'rows', lawName] });
			queryClient.invalidateQueries({ queryKey: latKeys.annotations(lawName) });
		}
	}));
}

// ── LAT Session Hooks ──────────────────────────────────────────────

/**
 * Query: List recent LAT parse sessions
 */
export function useLatSessionsQuery() {
	return createQuery<{ sessions: LatSession[] }>(() => ({
		queryKey: latKeys.sessions(),
		queryFn: getLatSessions
	}));
}

/**
 * Query: Get a single LAT session
 */
export function useLatSessionQuery(sessionId: string) {
	return createQuery<LatSession>(() => ({
		queryKey: latKeys.session(sessionId),
		queryFn: () => getLatSession(sessionId),
		enabled: !!sessionId
	}));
}

/**
 * Query: Get records for a LAT session
 */
export function useLatSessionRecordsQuery(sessionId: string) {
	return createQuery<{ records: LatSessionRecord[]; count: number }>(() => ({
		queryKey: latKeys.sessionRecords(sessionId),
		queryFn: () => getLatSessionRecords(sessionId),
		enabled: !!sessionId
	}));
}

/**
 * Mutation: Create a LAT parse session
 */
export function useCreateLatSessionMutation() {
	const queryClient = useQueryClient();

	return createMutation(() => ({
		mutationFn: (filters: LatSessionFilters) => createLatSession(filters),
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: latKeys.sessions() });
		}
	}));
}

/**
 * Mutation: Delete a LAT session
 */
export function useDeleteLatSessionMutation() {
	const queryClient = useQueryClient();

	return createMutation(() => ({
		mutationFn: (sessionId: string) => deleteLatSession(sessionId),
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: latKeys.sessions() });
		}
	}));
}

/**
 * Mutation: Update LAT session record selection
 */
export function useUpdateLatSelectionMutation() {
	const queryClient = useQueryClient();

	return createMutation(() => ({
		mutationFn: ({
			sessionId,
			names,
			selected
		}: {
			sessionId: string;
			names: string[];
			selected: boolean;
		}) => updateLatSelection(sessionId, names, selected),
		onSuccess: (_data, variables) => {
			queryClient.invalidateQueries({
				queryKey: latKeys.sessionRecords(variables.sessionId)
			});
		}
	}));
}

/**
 * Mutation: Confirm a parsed LAT record
 */
export function useConfirmLatRecordMutation() {
	const queryClient = useQueryClient();

	return createMutation(() => ({
		mutationFn: ({ sessionId, lawName }: { sessionId: string; lawName: string }) =>
			confirmLatRecord(sessionId, lawName),
		onSuccess: (_data, variables) => {
			queryClient.invalidateQueries({
				queryKey: latKeys.sessionRecords(variables.sessionId)
			});
			queryClient.invalidateQueries({ queryKey: latKeys.session(variables.sessionId) });
			queryClient.invalidateQueries({ queryKey: latKeys.sessions() });
		}
	}));
}
