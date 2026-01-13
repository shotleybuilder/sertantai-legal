/**
 * Scraper API Client
 *
 * Functions for interacting with the scraper backend endpoints.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

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
	name: string;
	si_code?: string;
	SICode?: string[];
	matched_terms?: string[];
	selected?: boolean;
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

export interface SelectionResult {
	message: string;
	session_id: string;
	group: string;
	updated: number;
	selected: boolean;
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
 * DB status response - counts of session records that exist in uk_lrt
 */
export interface DbStatusResult {
	session_id: string;
	total_records: number;
	existing_in_db: number;
	new_records: number;
	existing_names: string[];
}

/**
 * Get the count of session records that already exist in uk_lrt
 */
export async function getSessionDbStatus(sessionId: string): Promise<DbStatusResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/db-status`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch DB status');
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
	group: 1 | 2 | 3,
	selectedOnly: boolean = false
): Promise<{ message: string; session_id: string; results: ParseResult }> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/parse/${group}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ selected_only: selectedOnly })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to parse group');
	}

	return response.json();
}

/**
 * Update selection state for records in a group
 */
export async function updateSelection(
	sessionId: string,
	group: 1 | 2 | 3,
	names: string[],
	selected: boolean
): Promise<SelectionResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/group/${group}/select`, {
		method: 'PATCH',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ names, selected })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to update selection');
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

// ============================================================================
// Parse Review API
// ============================================================================

export interface StageResult {
	status: 'ok' | 'error' | 'skipped';
	data: Record<string, unknown> | null;
	error: string | null;
}

export interface ParseOneResult {
	session_id: string;
	name: string;
	record: Record<string, unknown>;
	stages: {
		extent: StageResult;
		enacted_by: StageResult;
		amendments: StageResult;
		repeal_revoke: StageResult;
	};
	errors: string[];
	has_errors: boolean;
	duplicate: {
		exists: boolean;
		id?: string;
		title_en?: string;
		family?: string;
		updated_at?: string;
		record?: Record<string, unknown>;
	} | null;
}

export interface ConfirmResult {
	message: string;
	name: string;
	record_id: string;
	action: 'inserted' | 'updated';
}

export interface ExistsResult {
	exists: boolean;
	id?: string;
	name?: string;
	title_en?: string;
	family?: string;
	updated_at?: string;
}

/**
 * Parse a single record and return staged results for review
 */
export async function parseOne(sessionId: string, name: string): Promise<ParseOneResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/parse-one`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ name })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to parse record');
	}

	return response.json();
}

/**
 * Confirm and persist a reviewed record
 * @param record - The pre-parsed record data from parseOne (required to avoid redundant re-parsing)
 */
export async function confirmRecord(
	sessionId: string,
	name: string,
	record: Record<string, unknown>,
	family?: string,
	overrides?: Record<string, unknown>
): Promise<ConfirmResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/confirm`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ name, record, family, overrides })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to confirm record');
	}

	return response.json();
}

/**
 * Check if a record exists in uk_lrt by name
 */
export async function checkExists(name: string): Promise<ExistsResult> {
	const response = await fetch(`${API_URL}/api/uk-lrt/exists/${encodeURIComponent(name)}`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to check existence');
	}

	return response.json();
}

// ============================================================================
// Family Options API
// ============================================================================

export interface FamilyOptionsResult {
	families: string[];
	grouped: {
		health_safety: string[];
		environment: string[];
	};
}

/**
 * Get available family options for dropdowns
 */
export async function getFamilyOptions(): Promise<FamilyOptionsResult> {
	const response = await fetch(`${API_URL}/api/family-options`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch family options');
	}

	return response.json();
}

// ============================================================================
// Cascade Update API
// ============================================================================

export interface AffectedLaw {
	id?: string;
	name: string;
	title_en?: string;
	year?: number;
	type_code?: string;
}

export interface EnactingParentLaw {
	id?: string;
	name: string;
	title_en?: string;
	year?: number;
	type_code?: string;
	current_enacting_count?: number;
	is_enacting?: boolean;
}

export interface AffectedLawsResult {
	session_id: string;
	source_laws: string[];
	source_count: number;
	// Laws needing re-parse (amending/rescinding)
	in_db: AffectedLaw[];
	in_db_count: number;
	not_in_db: AffectedLaw[];
	not_in_db_count: number;
	total_affected: number;
	// Parent laws needing direct enacting update
	enacting_parents_in_db: EnactingParentLaw[];
	enacting_parents_in_db_count: number;
	enacting_parents_not_in_db: AffectedLaw[];
	enacting_parents_not_in_db_count: number;
	total_enacting_parents: number;
}

export interface BatchReparseResultItem {
	name: string;
	status: 'success' | 'error';
	message: string;
}

export interface BatchReparseResult {
	session_id: string;
	total: number;
	success: number;
	errors: number;
	results: BatchReparseResultItem[];
}

/**
 * Get affected laws for a session (for cascade update modal)
 */
export async function getAffectedLaws(sessionId: string): Promise<AffectedLawsResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/affected-laws`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch affected laws');
	}

	return response.json();
}

/**
 * Trigger batch re-parse for affected laws in the database
 */
export async function batchReparse(
	sessionId: string,
	names?: string[]
): Promise<BatchReparseResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/batch-reparse`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ names })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to batch re-parse');
	}

	return response.json();
}

/**
 * Clear affected laws after cascade update is complete
 */
export async function clearAffectedLaws(sessionId: string): Promise<{ message: string }> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/affected-laws`, {
		method: 'DELETE'
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to clear affected laws');
	}

	return response.json();
}

// ============================================================================
// Enacting Links Update API
// ============================================================================

export interface UpdateEnactingResultItem {
	name: string;
	status: 'success' | 'error' | 'unchanged' | 'skipped';
	message: string;
	added?: string[];
	added_count?: number;
	new_total?: number;
	current_count?: number;
}

export interface UpdateEnactingLinksResult {
	session_id: string;
	total: number;
	success: number;
	unchanged: number;
	errors: number;
	results: UpdateEnactingResultItem[];
}

/**
 * Update enacting arrays on parent laws directly.
 * Unlike amending/rescinding (which requires re-parsing), enacting relationships
 * are derived from enacted_by. This endpoint directly appends source laws to
 * parent laws' enacting arrays.
 */
export async function updateEnactingLinks(
	sessionId: string,
	names?: string[]
): Promise<UpdateEnactingLinksResult> {
	const response = await fetch(`${API_URL}/api/sessions/${sessionId}/update-enacting-links`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ names })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to update enacting links');
	}

	return response.json();
}
