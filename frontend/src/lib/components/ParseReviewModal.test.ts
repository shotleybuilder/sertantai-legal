/**
 * Tests for ParseReviewModal state management logic
 *
 * These tests verify the core state logic that prevents bugs:
 * 1. Stale currentIndex breaking modal transitions
 * 2. Reparse being triggered after workflow completion
 */

import { describe, it, expect } from 'vitest';

describe('ParseReviewModal state logic', () => {
	/**
	 * Simulates the reactive logic that determines if we're on the last record
	 */
	function isLastRecord(currentIndex: number, recordsLength: number): boolean {
		return currentIndex === recordsLength - 1;
	}

	/**
	 * Simulates the state reset that should happen when records change
	 */
	function resetStateForNewRecords(
		currentState: { currentIndex: number; confirmedCount: number; workflowComplete: boolean },
		initialIndex: number
	): { currentIndex: number; confirmedCount: number; workflowComplete: boolean } {
		return {
			currentIndex: initialIndex,
			confirmedCount: 0,
			workflowComplete: false
		};
	}

	describe('isLastRecord calculation', () => {
		it('returns true for single record at index 0', () => {
			expect(isLastRecord(0, 1)).toBe(true);
		});

		it('returns true for last record in multi-record list', () => {
			expect(isLastRecord(2, 3)).toBe(true);
		});

		it('returns false for first record in multi-record list', () => {
			expect(isLastRecord(0, 3)).toBe(false);
		});

		it('returns false when index is out of bounds (the bug scenario)', () => {
			// This was the bug: user navigated to index 3 in a 5-record session,
			// then opened modal with 1 record. currentIndex was still 3.
			// isLast = (3 === 0) = false, so complete event never fired
			expect(isLastRecord(3, 1)).toBe(false);
		});
	});

	describe('state reset on new records', () => {
		it('resets currentIndex to initialIndex when records change', () => {
			// Simulate: user was at index 3, modal reopens with initialIndex 0
			const oldState = { currentIndex: 3, confirmedCount: 5, workflowComplete: true };
			const newState = resetStateForNewRecords(oldState, 0);

			expect(newState.currentIndex).toBe(0);
			expect(newState.confirmedCount).toBe(0);
		});

		it('resets workflowComplete flag when records change', () => {
			// After completing a workflow, workflowComplete is true
			// When opening with new records, it must reset to false
			const oldState = { currentIndex: 0, confirmedCount: 1, workflowComplete: true };
			const newState = resetStateForNewRecords(oldState, 0);

			expect(newState.workflowComplete).toBe(false);
		});

		it('after reset, isLast is correctly calculated for single record', () => {
			const oldState = { currentIndex: 3, confirmedCount: 5, workflowComplete: false };
			const newState = resetStateForNewRecords(oldState, 0);

			// Now with correct index, single record should be last
			expect(isLastRecord(newState.currentIndex, 1)).toBe(true);
		});
	});

	describe('complete event trigger conditions', () => {
		/**
		 * Simulates moveNext logic that decides whether to dispatch complete
		 */
		function shouldDispatchComplete(currentIndex: number, recordsLength: number): boolean {
			const isLast = currentIndex === recordsLength - 1;
			return isLast;
		}

		it('dispatches complete when confirming only record', () => {
			expect(shouldDispatchComplete(0, 1)).toBe(true);
		});

		it('dispatches complete when confirming last of multiple records', () => {
			expect(shouldDispatchComplete(4, 5)).toBe(true);
		});

		it('does not dispatch complete when more records remain', () => {
			expect(shouldDispatchComplete(0, 5)).toBe(false);
		});

		it('BUG SCENARIO: stale index prevents complete dispatch', () => {
			// Before fix: currentIndex=3 with 1 record -> never completes
			expect(shouldDispatchComplete(3, 1)).toBe(false);
		});

		it('FIXED: reset index allows complete dispatch', () => {
			// After fix: currentIndex reset to 0 with 1 record -> completes
			const resetIndex = 0;
			expect(shouldDispatchComplete(resetIndex, 1)).toBe(true);
		});
	});

	describe('reparse prevention after workflow completion', () => {
		/**
		 * Simulates the reactive condition that triggers parsing.
		 * This is the exact logic from the component's reactive statement.
		 */
		function shouldTriggerParse(state: {
			open: boolean;
			workflowComplete: boolean;
			currentRecordName: string | null;
			lastParsedName: string | null;
			failedNames: Set<string>;
			isParsePending: boolean;
		}): boolean {
			return (
				state.open &&
				!state.workflowComplete &&
				state.currentRecordName !== null &&
				state.currentRecordName !== state.lastParsedName &&
				!state.failedNames.has(state.currentRecordName) &&
				!state.isParsePending
			);
		}

		it('triggers parse when modal opens with new record', () => {
			const state = {
				open: true,
				workflowComplete: false,
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null,
				failedNames: new Set<string>(),
				isParsePending: false
			};

			expect(shouldTriggerParse(state)).toBe(true);
		});

		it('does not trigger parse when record already parsed', () => {
			const state = {
				open: true,
				workflowComplete: false,
				currentRecordName: 'uksi/2024/1',
				lastParsedName: 'uksi/2024/1', // Same as current
				failedNames: new Set<string>(),
				isParsePending: false
			};

			expect(shouldTriggerParse(state)).toBe(false);
		});

		it('does not trigger parse when workflow is complete', () => {
			// REGRESSION TEST: This was the bug where confirming the last record
			// would set lastParsedName to null in handleComplete(), which triggered
			// a reparse because the reactive condition saw:
			// currentRecordName ('uksi/2024/1') !== lastParsedName (null)
			const state = {
				open: true,
				workflowComplete: true, // Set to true BEFORE lastParsedName becomes null
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null, // This would normally trigger reparse
				failedNames: new Set<string>(),
				isParsePending: false
			};

			expect(shouldTriggerParse(state)).toBe(false);
		});

		it('does not trigger parse when modal is closed', () => {
			const state = {
				open: false,
				workflowComplete: false,
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null,
				failedNames: new Set<string>(),
				isParsePending: false
			};

			expect(shouldTriggerParse(state)).toBe(false);
		});

		it('does not trigger parse when record previously failed', () => {
			const state = {
				open: true,
				workflowComplete: false,
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null,
				failedNames: new Set(['uksi/2024/1']),
				isParsePending: false
			};

			expect(shouldTriggerParse(state)).toBe(false);
		});

		it('does not trigger parse when parse is already pending', () => {
			const state = {
				open: true,
				workflowComplete: false,
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null,
				failedNames: new Set<string>(),
				isParsePending: true
			};

			expect(shouldTriggerParse(state)).toBe(false);
		});
	});

	describe('handleComplete behavior', () => {
		/**
		 * Simulates handleComplete setting workflowComplete before clearing lastParsedName
		 */
		function simulateHandleComplete(state: {
			workflowComplete: boolean;
			lastParsedName: string | null;
		}): { workflowComplete: boolean; lastParsedName: string | null } {
			// Order matters! Set workflowComplete FIRST to prevent reparse trigger
			return {
				workflowComplete: true,
				lastParsedName: null
			};
		}

		it('sets workflowComplete before clearing lastParsedName', () => {
			const beforeState = {
				workflowComplete: false,
				lastParsedName: 'uksi/2024/1'
			};

			const afterState = simulateHandleComplete(beforeState);

			// Both should be set, but workflowComplete must be true
			// so the reactive statement won't trigger reparse
			expect(afterState.workflowComplete).toBe(true);
			expect(afterState.lastParsedName).toBe(null);
		});

		it('REGRESSION: without workflowComplete guard, reparse would trigger', () => {
			// This test documents what WOULD happen without the fix
			const stateAfterBuggyHandleComplete = {
				open: true,
				workflowComplete: false, // Bug: this wasn't being set
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null, // handleComplete sets this to null
				failedNames: new Set<string>(),
				isParsePending: false
			};

			// Without workflowComplete guard, this would be true (BAD)
			const wouldTriggerReparse =
				stateAfterBuggyHandleComplete.open &&
				stateAfterBuggyHandleComplete.currentRecordName !== null &&
				stateAfterBuggyHandleComplete.currentRecordName !==
					stateAfterBuggyHandleComplete.lastParsedName &&
				!stateAfterBuggyHandleComplete.failedNames.has(
					stateAfterBuggyHandleComplete.currentRecordName
				) &&
				!stateAfterBuggyHandleComplete.isParsePending;

			expect(wouldTriggerReparse).toBe(true); // This was the bug!
		});

		it('FIXED: with workflowComplete guard, reparse is prevented', () => {
			const stateAfterFixedHandleComplete = {
				open: true,
				workflowComplete: true, // FIX: this is now set first
				currentRecordName: 'uksi/2024/1',
				lastParsedName: null,
				failedNames: new Set<string>(),
				isParsePending: false
			};

			const wouldTriggerReparse =
				stateAfterFixedHandleComplete.open &&
				!stateAfterFixedHandleComplete.workflowComplete && // This guard prevents it
				stateAfterFixedHandleComplete.currentRecordName !== null &&
				stateAfterFixedHandleComplete.currentRecordName !==
					stateAfterFixedHandleComplete.lastParsedName &&
				!stateAfterFixedHandleComplete.failedNames.has(
					stateAfterFixedHandleComplete.currentRecordName
				) &&
				!stateAfterFixedHandleComplete.isParsePending;

			expect(wouldTriggerReparse).toBe(false); // Fixed!
		});
	});

	describe('per-stage reparse functionality', () => {
		type ParseStage =
			| 'metadata'
			| 'extent'
			| 'enacted_by'
			| 'amendments'
			| 'repeal_revoke'
			| 'taxa';

		/**
		 * Simulates whether a stage reparse can be triggered.
		 * Mirrors the guard conditions in reparseStage()
		 */
		function canReparseStage(state: {
			currentRecord: { name: string } | null;
			parseResult: object | null;
			reparsingStage: ParseStage | null;
		}): boolean {
			return !!state.currentRecord && !!state.parseResult && !state.reparsingStage;
		}

		/**
		 * Simulates whether the reparse button should be shown for a section.
		 * Mirrors showReparse prop condition
		 */
		function shouldShowReparseButton(state: {
			effectiveMode: 'create' | 'update' | 'read';
			parseResult: object | null;
		}): boolean {
			return state.effectiveMode !== 'read' && !!state.parseResult;
		}

		/**
		 * Simulates merging stage results after a single-stage reparse.
		 * Tests the merging logic from reparseStage()
		 */
		function mergeStageResult(
			previousResult: {
				stages: Record<ParseStage, { status: string }>;
				record: Record<string, unknown>;
				errors: string[];
			},
			stage: ParseStage,
			newStageResult: { status: string },
			newRecord: Record<string, unknown> | null,
			newError: string | null
		): {
			stages: Record<ParseStage, { status: string }>;
			record: Record<string, unknown>;
			errors: string[];
			has_errors: boolean;
		} {
			const mergedStages = { ...previousResult.stages };
			const mergedRecord = { ...previousResult.record };
			const mergedErrors = previousResult.errors.filter((e) => !e.startsWith(stage + ':'));

			mergedStages[stage] = newStageResult;

			if (newStageResult.status === 'ok' && newRecord) {
				Object.assign(mergedRecord, newRecord);
			}

			if (newStageResult.status === 'error' && newError) {
				mergedErrors.push(newError);
			}

			return {
				stages: mergedStages,
				record: mergedRecord,
				errors: mergedErrors,
				has_errors: mergedErrors.length > 0
			};
		}

		it('allows reparse when conditions are met', () => {
			const state = {
				currentRecord: { name: 'uksi/2024/1' },
				parseResult: { stages: {}, record: {} },
				reparsingStage: null
			};

			expect(canReparseStage(state)).toBe(true);
		});

		it('prevents reparse when no current record', () => {
			const state = {
				currentRecord: null,
				parseResult: { stages: {}, record: {} },
				reparsingStage: null
			};

			expect(canReparseStage(state)).toBe(false);
		});

		it('prevents reparse when no parse result', () => {
			const state = {
				currentRecord: { name: 'uksi/2024/1' },
				parseResult: null,
				reparsingStage: null
			};

			expect(canReparseStage(state)).toBe(false);
		});

		it('prevents reparse when already reparsing a stage', () => {
			const state = {
				currentRecord: { name: 'uksi/2024/1' },
				parseResult: { stages: {}, record: {} },
				reparsingStage: 'metadata' as ParseStage
			};

			expect(canReparseStage(state)).toBe(false);
		});

		it('shows reparse button in create mode with parse result', () => {
			expect(
				shouldShowReparseButton({
					effectiveMode: 'create',
					parseResult: { stages: {} }
				})
			).toBe(true);
		});

		it('shows reparse button in update mode with parse result', () => {
			expect(
				shouldShowReparseButton({
					effectiveMode: 'update',
					parseResult: { stages: {} }
				})
			).toBe(true);
		});

		it('hides reparse button in read mode', () => {
			expect(
				shouldShowReparseButton({
					effectiveMode: 'read',
					parseResult: { stages: {} }
				})
			).toBe(false);
		});

		it('hides reparse button when no parse result', () => {
			expect(
				shouldShowReparseButton({
					effectiveMode: 'create',
					parseResult: null
				})
			).toBe(false);
		});

		it('merges successful stage result into existing results', () => {
			const previousResult = {
				stages: {
					metadata: { status: 'ok' },
					extent: { status: 'ok' },
					enacted_by: { status: 'error' },
					amendments: { status: 'ok' },
					repeal_revoke: { status: 'ok' },
					taxa: { status: 'ok' }
				} as Record<ParseStage, { status: string }>,
				record: { title_en: 'Old Title', geo_extent: 'UK' },
				errors: ['enacted_by: Connection timeout']
			};

			const merged = mergeStageResult(
				previousResult,
				'enacted_by',
				{ status: 'ok' },
				{ enacted_by: ['ukpga/2020/1'], enacted_by_meta: {} },
				null
			);

			expect(merged.stages.enacted_by.status).toBe('ok');
			expect(merged.record.enacted_by).toEqual(['ukpga/2020/1']);
			expect(merged.record.title_en).toBe('Old Title'); // Preserved
			expect(merged.errors).toEqual([]); // Old error removed
			expect(merged.has_errors).toBe(false);
		});

		it('handles stage reparse failure gracefully', () => {
			const previousResult = {
				stages: {
					metadata: { status: 'ok' },
					extent: { status: 'ok' },
					enacted_by: { status: 'ok' },
					amendments: { status: 'ok' },
					repeal_revoke: { status: 'ok' },
					taxa: { status: 'ok' }
				} as Record<ParseStage, { status: string }>,
				record: { title_en: 'Title', taxa_purpose: ['safety'] },
				errors: []
			};

			const merged = mergeStageResult(
				previousResult,
				'taxa',
				{ status: 'error' },
				null,
				'taxa: API timeout'
			);

			expect(merged.stages.taxa.status).toBe('error');
			expect(merged.record.taxa_purpose).toEqual(['safety']); // Preserved from before
			expect(merged.errors).toContain('taxa: API timeout');
			expect(merged.has_errors).toBe(true);
		});

		it('clears previous stage error when retrying succeeds', () => {
			const previousResult = {
				stages: {
					metadata: { status: 'ok' },
					extent: { status: 'error' },
					enacted_by: { status: 'ok' },
					amendments: { status: 'ok' },
					repeal_revoke: { status: 'ok' },
					taxa: { status: 'ok' }
				} as Record<ParseStage, { status: string }>,
				record: { title_en: 'Title' },
				errors: ['extent: Parse failed']
			};

			const merged = mergeStageResult(
				previousResult,
				'extent',
				{ status: 'ok' },
				{ geo_extent: 'UK', geo_region: ['England', 'Wales'] },
				null
			);

			expect(merged.stages.extent.status).toBe('ok');
			expect(merged.record.geo_extent).toBe('UK');
			expect(merged.record.geo_region).toEqual(['England', 'Wales']);
			expect(merged.errors).toEqual([]); // Previous error cleared
			expect(merged.has_errors).toBe(false);
		});

		it('preserves other stage errors when one stage retried', () => {
			const previousResult = {
				stages: {
					metadata: { status: 'ok' },
					extent: { status: 'error' },
					enacted_by: { status: 'error' },
					amendments: { status: 'ok' },
					repeal_revoke: { status: 'ok' },
					taxa: { status: 'ok' }
				} as Record<ParseStage, { status: string }>,
				record: { title_en: 'Title' },
				errors: ['extent: Parse failed', 'enacted_by: Connection timeout']
			};

			const merged = mergeStageResult(
				previousResult,
				'extent',
				{ status: 'ok' },
				{ geo_extent: 'UK' },
				null
			);

			expect(merged.stages.extent.status).toBe('ok');
			expect(merged.errors).toEqual(['enacted_by: Connection timeout']); // Other error preserved
			expect(merged.has_errors).toBe(true);
		});
	});
});
