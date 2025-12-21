/**
 * TanStack Query hooks for Scraper API
 */

import { createQuery, createMutation, useQueryClient } from '@tanstack/svelte-query';
import {
	getSessions,
	getSession,
	getGroupRecords,
	createScrapeSession,
	persistGroup,
	parseGroup,
	deleteSession,
	type ScrapeSession,
	type GroupResponse,
	type ParseResult
} from '$lib/api/scraper';

// Query Keys
export const scraperKeys = {
	all: ['scraper'] as const,
	sessions: () => [...scraperKeys.all, 'sessions'] as const,
	session: (id: string) => [...scraperKeys.all, 'session', id] as const,
	group: (sessionId: string, group: 1 | 2 | 3) =>
		[...scraperKeys.all, 'group', sessionId, group] as const
};

/**
 * Query: Get all sessions
 */
export function useSessionsQuery() {
	return createQuery({
		queryKey: scraperKeys.sessions(),
		queryFn: getSessions
	});
}

/**
 * Query: Get single session
 */
export function useSessionQuery(sessionId: string) {
	return createQuery({
		queryKey: scraperKeys.session(sessionId),
		queryFn: () => getSession(sessionId),
		enabled: !!sessionId
	});
}

/**
 * Query: Get group records
 */
export function useGroupQuery(sessionId: string, group: 1 | 2 | 3) {
	return createQuery({
		queryKey: scraperKeys.group(sessionId, group),
		queryFn: () => getGroupRecords(sessionId, group),
		enabled: !!sessionId
	});
}

/**
 * Mutation: Create scrape session
 */
export function useCreateScrapeMutation() {
	const queryClient = useQueryClient();

	return createMutation({
		mutationFn: createScrapeSession,
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: scraperKeys.sessions() });
		}
	});
}

/**
 * Mutation: Persist group
 */
export function usePersistGroupMutation() {
	const queryClient = useQueryClient();

	return createMutation({
		mutationFn: ({ sessionId, group }: { sessionId: string; group: 1 | 2 | 3 }) =>
			persistGroup(sessionId, group),
		onSuccess: (data) => {
			queryClient.invalidateQueries({ queryKey: scraperKeys.session(data.session.session_id) });
			queryClient.invalidateQueries({ queryKey: scraperKeys.sessions() });
		}
	});
}

/**
 * Mutation: Parse group
 */
export function useParseGroupMutation() {
	const queryClient = useQueryClient();

	return createMutation({
		mutationFn: ({ sessionId, group }: { sessionId: string; group: 1 | 2 | 3 }) =>
			parseGroup(sessionId, group),
		onSuccess: (data) => {
			queryClient.invalidateQueries({ queryKey: scraperKeys.session(data.session_id) });
		}
	});
}

/**
 * Mutation: Delete session
 */
export function useDeleteSessionMutation() {
	const queryClient = useQueryClient();

	return createMutation({
		mutationFn: deleteSession,
		onSuccess: () => {
			queryClient.invalidateQueries({ queryKey: scraperKeys.sessions() });
		}
	});
}
