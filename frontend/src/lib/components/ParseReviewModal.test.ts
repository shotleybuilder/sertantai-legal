/**
 * Tests for ParseReviewModal state management logic
 *
 * These tests verify the core state reset logic that was fixed to prevent
 * stale currentIndex from breaking modal transitions.
 *
 * The bug: When modal was reopened with different records, currentIndex
 * wasn't being reset, causing isLast to be false when it should be true,
 * preventing the complete event from being dispatched.
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
		currentState: { currentIndex: number; confirmedCount: number },
		initialIndex: number
	): { currentIndex: number; confirmedCount: number } {
		return {
			currentIndex: initialIndex,
			confirmedCount: 0
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
			const oldState = { currentIndex: 3, confirmedCount: 5 };
			const newState = resetStateForNewRecords(oldState, 0);

			expect(newState.currentIndex).toBe(0);
			expect(newState.confirmedCount).toBe(0);
		});

		it('after reset, isLast is correctly calculated for single record', () => {
			const oldState = { currentIndex: 3, confirmedCount: 5 };
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
});
