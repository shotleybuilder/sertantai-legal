/**
 * TanStack Query functions for Cases
 *
 * Queries that read from TanStack DB and provide reactive data to components
 * Mutations that write to API and update local state optimistically
 */

import { createQuery, createMutation } from '@tanstack/svelte-query';
import { casesStore, addCase } from '$lib/stores/cases';
import { queryClient } from '$lib/query/client';
import { get } from 'svelte/store';
import type { Case } from '$lib/db/schema';

/**
 * Query key factory for cases
 */
export const casesKeys = {
	all: ['cases'] as const,
	lists: () => [...casesKeys.all, 'list'] as const,
	list: (filters?: any) => [...casesKeys.lists(), filters] as const,
	details: () => [...casesKeys.all, 'detail'] as const,
	detail: (id: string) => [...casesKeys.details(), id] as const
};

/**
 * Fetch all cases from the store
 *
 * This reads from the Svelte store which is kept in sync by ElectricSQL
 */
async function fetchAllCases(): Promise<Case[]> {
	// Get current value from store
	const cases = get(casesStore);
	return cases;
}

/**
 * Query hook for all cases
 *
 * Usage in Svelte components:
 * ```svelte
 * <script>
 *   import { useCasesQuery } from '$lib/query/cases'
 *   const casesQuery = useCasesQuery()
 * </script>
 *
 * {#if $casesQuery.isLoading}
 *   Loading...
 * {:else if $casesQuery.isError}
 *   Error: {$casesQuery.error}
 * {:else}
 *   {#each $casesQuery.data as case_}
 *     ...
 *   {/each}
 * {/if}
 * ```
 */
export function useCasesQuery() {
	return createQuery({
		queryKey: casesKeys.list(),
		queryFn: fetchAllCases,
		// Since ElectricSQL handles real-time updates to the store,
		// we don't need aggressive refetching
		refetchOnMount: false,
		refetchOnReconnect: false,
		refetchOnWindowFocus: false
	});
}

/**
 * Fetch a single case by ID
 */
async function fetchCaseById(id: string): Promise<Case | undefined> {
	const cases = get(casesStore);
	return cases.find((c) => c.id === id);
}

/**
 * Query hook for a single case
 */
export function useCaseQuery(id: string) {
	return createQuery({
		queryKey: casesKeys.detail(id),
		queryFn: () => fetchCaseById(id),
		enabled: !!id // Only run if ID is provided
	});
}

// ============================================================================
// MUTATIONS - Template for Create/Update/Delete with Optimistic Updates
// ============================================================================

/**
 * Mutation types for Case operations
 */
export interface CreateCaseInput {
	// Define your case creation fields here
	title: string;
	description?: string;
	status?: string;
	// ... other fields
}

interface CreateCaseResponse {
	success: boolean;
	data: Case;
}

/**
 * Create case mutation function
 *
 * Sends POST request to your API endpoint
 * Replace the URL with your actual backend API
 */
async function createCaseMutation(input: CreateCaseInput): Promise<Case> {
	const response = await fetch('http://localhost:4002/api/cases', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json'
		},
		body: JSON.stringify(input)
	});

	if (!response.ok) {
		const data = await response.json().catch(() => ({}));
		throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`);
	}

	const result: CreateCaseResponse = await response.json();
	return result.data;
}

/**
 * Hook for creating cases with optimistic updates
 *
 * Features:
 * - Optimistic UI updates (instant feedback)
 * - Automatic rollback on error
 * - ElectricSQL sync integration
 * - Type-safe inputs/outputs
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useCreateCaseMutation } from '$lib/query/cases'
 *   const createMutation = useCreateCaseMutation()
 *
 *   function handleSubmit() {
 *     $createMutation.mutate({
 *       title: 'New Case',
 *       description: 'Case description',
 *       status: 'open'
 *     })
 *   }
 * </script>
 *
 * {#if $createMutation.isPending}
 *   Creating...
 * {:else if $createMutation.isError}
 *   Error: {$createMutation.error.message}
 * {:else if $createMutation.isSuccess}
 *   Success!
 * {/if}
 * ```
 */
export function useCreateCaseMutation() {
	return createMutation({
		mutationFn: createCaseMutation,

		// Optimistic update: immediately add to UI before server responds
		onMutate: async (newCase: CreateCaseInput) => {
			// Cancel any outgoing refetches to avoid overwriting optimistic update
			await queryClient?.cancelQueries({ queryKey: casesKeys.all });

			// Snapshot the previous value for rollback
			const previousCases = get(casesStore);

			// Optimistically create a temporary case with placeholder ID
			const optimisticCase: Case = {
				id: `temp-${Date.now()}`, // Temporary ID will be replaced by server ID
				...newCase,
				// Add any other required Case fields with default values
				inserted_at: new Date().toISOString(),
				updated_at: new Date().toISOString()
			} as Case;

			// Optimistically update the store (instant UI feedback!)
			addCase(optimisticCase);

			// Return context with rollback data
			return { previousCases, optimisticCase };
		},

		// On success: replace optimistic case with real one from server
		onSuccess: (serverCase, _variables, context) => {
			if (!context) return;

			// The server case will be synced automatically via ElectricSQL
			// But we can manually add it immediately for instant feedback
			addCase(serverCase);

			// Invalidate queries to refetch from TanStack DB
			// (which will have the real data from ElectricSQL)
			queryClient?.invalidateQueries({ queryKey: casesKeys.all });
		},

		// On error: rollback to previous state
		onError: (_error, _variables, context) => {
			if (!context) return;

			// Rollback optimistic update
			casesStore.set(context.previousCases);

			// Invalidate to refetch correct state
			queryClient?.invalidateQueries({ queryKey: casesKeys.all });
		}
	});
}

/**
 * Template for Update Mutation
 *
 * Copy and adapt this pattern for update operations
 */
export interface UpdateCaseInput {
	id: string;
	title?: string;
	description?: string;
	status?: string;
	// ... other updatable fields
}

async function updateCaseMutation(input: UpdateCaseInput): Promise<Case> {
	const { id, ...updates } = input;
	const response = await fetch(`http://localhost:4002/api/cases/${id}`, {
		method: 'PATCH',
		headers: {
			'Content-Type': 'application/json'
		},
		body: JSON.stringify(updates)
	});

	if (!response.ok) {
		const data = await response.json().catch(() => ({}));
		throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`);
	}

	const result = await response.json();
	return result.data;
}

export function useUpdateCaseMutation() {
	return createMutation({
		mutationFn: updateCaseMutation,

		onMutate: async (updatedCase: UpdateCaseInput) => {
			await queryClient?.cancelQueries({ queryKey: casesKeys.all });
			const previousCases = get(casesStore);

			// Optimistically update the case in the store
			const currentCases = get(casesStore);
			const optimisticCases = currentCases.map((c) =>
				c.id === updatedCase.id ? { ...c, ...updatedCase, updated_at: new Date().toISOString() } : c
			);
			casesStore.set(optimisticCases);

			return { previousCases };
		},

		onSuccess: () => {
			queryClient?.invalidateQueries({ queryKey: casesKeys.all });
		},

		onError: (_error, _variables, context) => {
			if (context?.previousCases) {
				casesStore.set(context.previousCases);
			}
			queryClient?.invalidateQueries({ queryKey: casesKeys.all });
		}
	});
}

/**
 * Template for Delete Mutation
 *
 * Copy and adapt this pattern for delete operations
 */
async function deleteCaseMutation(id: string): Promise<void> {
	const response = await fetch(`http://localhost:4002/api/cases/${id}`, {
		method: 'DELETE'
	});

	if (!response.ok) {
		const data = await response.json().catch(() => ({}));
		throw new Error(data.error || `HTTP ${response.status}: ${response.statusText}`);
	}
}

export function useDeleteCaseMutation() {
	return createMutation({
		mutationFn: deleteCaseMutation,

		onMutate: async (id: string) => {
			await queryClient?.cancelQueries({ queryKey: casesKeys.all });
			const previousCases = get(casesStore);

			// Optimistically remove the case from the store
			const currentCases = get(casesStore);
			casesStore.set(currentCases.filter((c) => c.id !== id));

			return { previousCases };
		},

		onSuccess: () => {
			queryClient?.invalidateQueries({ queryKey: casesKeys.all });
		},

		onError: (_error, _variables, context) => {
			if (context?.previousCases) {
				casesStore.set(context.previousCases);
			}
			queryClient?.invalidateQueries({ queryKey: casesKeys.all });
		}
	});
}
