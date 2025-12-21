/**
 * Scraper API Client
 *
 * Functions for interacting with the scraper backend endpoints.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4000';

export interface ScrapeSession {
	id: string;
	session_id: string;
	year: number;
	month: number;
	day_from: number;
	day_to: number;
	type_code: string | null;
	status: 'pending' | 'scraping' | 'categorized' | 'reviewing' | 'completed' | 'failed';
	error_message: string | null;
	total_fetched: number;
	title_excluded_count: number;
	group1_count: number;
	group2_count: number;
	group3_count: number;
	persisted_count: number;
	inserted_at: string;
	updated_at: string;
}

export interface ScrapeRecord {
	Title_EN: string;
	type_code: string;
	Year: number;
	Number: string;
	si_code?: string;
	SICode?: string[];
	matched_terms?: string[];
	_index?: string;
}

export interface GroupResponse {
	session_id: string;
	group: string;
	count: number;
	records: ScrapeRecord[];
}

export interface ParseResult {
	parsed: number;
	skipped: number;
	errors: number;
}

/**
 * Create and run a new scrape session
 */
export async function createScrapeSession(params: {
	year: number;
	month: number;
	day_from: number;
	day_to: number;
	type_code?: string;
}): Promise<ScrapeSession> {
	const response = await fetch(`${API_URL}/api/scrape`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(params)
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to create scrape session');
	}

	return response.json();
}

/**
 * Get list of recent sessions
 */
export async function getSessions(): Promise<ScrapeSession[]> {
	const response = await fetch(`${API_URL}/api/sessions`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch sessions');
	}

	const data = await response.json();
	return data.sessions;
}

/**
 * Get session detail by session_id
 */
export async function getSession(sessionId: string): Promise<ScrapeSession> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Session not found');
	}

	return response.json();
}

/**
 * Get records for a specific group
 */
export async function getGroupRecords(sessionId: string, group: 1 | 2 | 3): Promise<GroupResponse> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/group/${group}`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch group records');
	}

	return response.json();
}

/**
 * Persist a group to the uk_lrt table
 */
export async function persistGroup(
	sessionId: string,
	group: 1 | 2 | 3
): Promise<{ message: string; session: ScrapeSession }> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/persist/${group}`, {
		method: 'POST'
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to persist group');
	}

	return response.json();
}

/**
 * Parse a group to fetch XML metadata
 */
export async function parseGroup(
	sessionId: string,
	group: 1 | 2 | 3
): Promise<{ message: string; session_id: string; results: ParseResult }> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/parse/${group}`, {
		method: 'POST'
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to parse group');
	}

	return response.json();
}

/**
 * Delete a session
 */
export async function deleteSession(sessionId: string): Promise<{ message: string }> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}`, {
		method: 'DELETE'
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to delete session');
	}

	return response.json();
}
