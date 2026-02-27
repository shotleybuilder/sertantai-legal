/**
 * TanStack Query hooks for Zenoh Admin API
 */

import { createQuery } from '@tanstack/svelte-query';
import {
	getSubscriptions,
	getQueryables,
	type SubscriptionsResponse,
	type QueryablesResponse
} from '$lib/api/zenoh';

export const zenohKeys = {
	all: ['zenoh'] as const,
	subscriptions: () => [...zenohKeys.all, 'subscriptions'] as const,
	queryables: () => [...zenohKeys.all, 'queryables'] as const
};

export function useSubscriptionsQuery() {
	return createQuery<SubscriptionsResponse>({
		queryKey: zenohKeys.subscriptions(),
		queryFn: getSubscriptions,
		refetchInterval: 10_000
	});
}

export function useQueryablesQuery() {
	return createQuery<QueryablesResponse>({
		queryKey: zenohKeys.queryables(),
		queryFn: getQueryables,
		refetchInterval: 10_000
	});
}
