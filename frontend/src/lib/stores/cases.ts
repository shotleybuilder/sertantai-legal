/**
 * Svelte store for cases data
 * Updated by ElectricSQL sync
 */

import { writable } from 'svelte/store'
import type { Case } from '$lib/db/schema'

// Create a writable store for cases
export const casesStore = writable<Case[]>([])

// Helper functions to update the store
export function addCase(case_: Case) {
  casesStore.update((cases) => {
    // Check if case already exists
    const existing = cases.findIndex((c) => c.id === case_.id)
    if (existing >= 0) {
      // Update existing
      cases[existing] = case_
      return [...cases]
    } else {
      // Add new
      return [...cases, case_]
    }
  })
}

export function updateCase(id: string, updates: Partial<Case>) {
  casesStore.update((cases) => {
    const index = cases.findIndex((c) => c.id === id)
    if (index >= 0) {
      cases[index] = { ...cases[index], ...updates }
      return [...cases]
    }
    return cases
  })
}

export function removeCase(id: string) {
  casesStore.update((cases) => cases.filter((c) => c.id !== id))
}

export function clearCases() {
  casesStore.set([])
}
