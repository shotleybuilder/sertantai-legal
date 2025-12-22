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
	updateSelection,
	type ScrapeSession,
	type GroupResponse,
	type ParseResult,
	type SelectionResult
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
		mutationFn: ({
			sessionId,
			group,
			selectedOnly = false
		}: {
			sessionId: string;
			group: 1 | 2 | 3;
			selectedOnly?: boolean;
		}) => parseGroup(sessionId, group, selectedOnly),
		onSuccess: (data) => {
			queryClient.invalidateQueries({ queryKey: scraperKeys.session(data.session_id) });
		}
	});
}

/**
 * Mutation: Update selection
 */
export function useUpdateSelectionMutation() {
	const queryClient = useQueryClient();

	return createMutation({
		mutationFn: ({
			sessionId,
			group,
			names,
			selected
		}: {
			sessionId: string;
			group: 1 | 2 | 3;
			names: string[];
			selected: boolean;
		}) => updateSelection(sessionId, group, names, selected),
		onSuccess: (data) => {
			// Invalidate the group query to refresh selection state
			queryClient.invalidateQueries({
				queryKey: scraperKeys.group(data.session_id, parseInt(data.group) as 1 | 2 | 3)
			});
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
