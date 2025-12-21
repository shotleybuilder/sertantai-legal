/**
 * TanStack Query Client Configuration
 *
 * Sets up the QueryClient with TanStack DB persistence
 */

import { QueryClient } from '@tanstack/svelte-query'
import { browser } from '$app/environment'

/**
 * Create the QueryClient
 *
 * This is the central client for TanStack Query.
 * It manages query caching, invalidation, and background updates.
 */
export function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        // Enable queries only in browser (not SSR)
        enabled: browser,

        // Stale time - how long before data is considered stale
        staleTime: 1000 * 60 * 5, // 5 minutes

        // Cache time - how long to keep unused data in cache
        gcTime: 1000 * 60 * 30, // 30 minutes (was cacheTime in v4)

        // Retry failed requests
        retry: 1,

        // Refetch on window focus
        refetchOnWindowFocus: false,

        // Refetch on reconnect
        refetchOnReconnect: true,
      },
    },
  })
}

/**
 * Global query client instance
 */
export const queryClient = browser ? createQueryClient() : null
