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
	data_source: 'db' | 'json';
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
	updated_at_map: Record<string, string | null>;
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
	// Status counts for cascade button display
	pending_count: number;
	processed_count: number;
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

// ============================================================================
// Standalone Cascade Management API
// ============================================================================

export interface CascadeSession {
	session_id: string;
	year: number | null;
	month: number | null;
	day_from: number | null;
	day_to: number | null;
	status: string | null;
	persisted_count: number;
	pending_count?: number;
	reparse_count?: number;
	enacting_count?: number;
}

export interface SourceLawDetail {
	name: string;
	title_en: string | null;
}

export interface CascadeEntry {
	id: string;
	affected_law: string;
	session_id: string;
	source_laws: string[];
	source_laws_details?: SourceLawDetail[];
	title_en?: string;
	year?: number;
	type_code?: string;
	family?: string;
	current_enacting_count?: number;
	is_enacting?: boolean;
}

export interface CascadeIndexResult {
	sessions: CascadeSession[];
	reparse_in_db: CascadeEntry[];
	reparse_missing: CascadeEntry[];
	enacting_in_db: CascadeEntry[];
	enacting_missing: CascadeEntry[];
	summary: {
		total_pending: number;
		reparse_in_db_count: number;
		reparse_missing_count: number;
		enacting_in_db_count: number;
		enacting_missing_count: number;
		session_count: number;
	};
	filter: {
		session_id: string | null;
	};
}

export interface CascadeSessionsResult {
	sessions: CascadeSession[];
}

export interface CascadeOperationResultItem {
	id: string;
	affected_law: string;
	status: 'success' | 'error' | 'unchanged' | 'exists' | 'skipped';
	message: string;
}

export interface CascadeOperationResult {
	total: number;
	success: number;
	errors: number;
	unchanged?: number;
	exists?: number;
	results: CascadeOperationResultItem[];
}

/**
 * Get cascade entries, optionally filtered by session
 */
export async function getCascadeIndex(sessionId?: string): Promise<CascadeIndexResult> {
	const url = sessionId
		? `${API_URL}/api/cascade?session_id=${encodeURIComponent(sessionId)}`
		: `${API_URL}/api/cascade`;

	const response = await fetch(url);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch cascade entries');
	}

	return response.json();
}

/**
 * Get list of sessions with pending cascade entries
 */
export async function getCascadeSessions(): Promise<CascadeSessionsResult> {
	const response = await fetch(`${API_URL}/api/cascade/sessions`);

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to fetch cascade sessions');
	}

	return response.json();
}

/**
 * Batch re-parse cascade entries by ID
 */
export async function cascadeReparse(ids: string[]): Promise<CascadeOperationResult> {
	const response = await fetch(`${API_URL}/api/cascade/reparse`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ ids })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to re-parse cascade entries');
	}

	return response.json();
}

/**
 * Update enacting links for cascade entries by ID
 */
export async function cascadeUpdateEnacting(ids: string[]): Promise<CascadeOperationResult> {
	const response = await fetch(`${API_URL}/api/cascade/update-enacting`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ ids })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to update enacting links');
	}

	return response.json();
}

/**
 * Add missing laws to the database by parsing them
 */
export async function cascadeAddLaws(ids: string[]): Promise<CascadeOperationResult> {
	const response = await fetch(`${API_URL}/api/cascade/add-laws`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify({ ids })
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to add laws');
	}

	return response.json();
}

/**
 * Delete a single cascade entry
 */
export async function deleteCascadeEntry(id: string): Promise<{ message: string; id: string }> {
	const response = await fetch(`${API_URL}/api/cascade/${id}`, {
		method: 'DELETE'
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to delete cascade entry');
	}

	return response.json();
}

/**
 * Clear all processed cascade entries
 */
export async function clearProcessedCascade(
	sessionId?: string
): Promise<{ message: string; deleted_count: number }> {
	const url = sessionId
		? `${API_URL}/api/cascade/processed?session_id=${encodeURIComponent(sessionId)}`
		: `${API_URL}/api/cascade/processed`;

	const response = await fetch(url, {
		method: 'DELETE'
	});

	if (!response.ok) {
		const error = await response.json();
		throw new Error(error.error || 'Failed to clear processed entries');
	}

	return response.json();
}

// ============================================================================
// Error Message Mapping
// ============================================================================

/**
 * Maps technical parser error messages to user-friendly messages.
 * Used to display meaningful feedback when parsing fails.
 */
export function mapParseError(error: string): string {
	if (!error) return 'An unknown error occurred';

	const errorLower = error.toLowerCase();

	// Network/Service Failures
	if (errorLower.includes('econnrefused') || errorLower.includes('connection refused')) {
		return 'Unable to connect to legislation.gov.uk. The service may be temporarily unavailable.';
	}
	if (errorLower.includes('timeout') || errorLower.includes('timed out')) {
		return 'Request timed out. legislation.gov.uk may be slow or unresponsive.';
	}
	if (errorLower.includes('nxdomain') || errorLower.includes('dns')) {
		return 'Unable to resolve legislation.gov.uk. Check your network connection.';
	}
	if (
		errorLower.includes('ssl') ||
		errorLower.includes('tls') ||
		errorLower.includes('certificate')
	) {
		return 'Secure connection failed. Try again in a moment.';
	}

	// HTTP Error Responses
	if (errorLower.includes('404') || errorLower.includes('not found')) {
		return 'Law not found on legislation.gov.uk. It may have been removed, renumbered, or not yet published.';
	}
	if (errorLower.includes('429') || errorLower.includes('too many requests')) {
		return 'Rate limited by legislation.gov.uk. Please wait a moment and try again.';
	}
	if (errorLower.includes('500') || errorLower.includes('internal server error')) {
		return 'legislation.gov.uk is experiencing issues. Try again later.';
	}
	if (errorLower.includes('503') || errorLower.includes('service unavailable')) {
		return 'legislation.gov.uk is temporarily unavailable for maintenance.';
	}
	if (errorLower.includes('307') || errorLower.includes('redirect')) {
		return 'Law has moved. Try refreshing the page.';
	}

	// Data/Parsing Failures
	if (errorLower.includes('html instead of xml') || errorLower.includes('received html')) {
		return 'Unexpected response format. The law may not be available in machine-readable format.';
	}
	if (errorLower.includes('xml parse error') || errorLower.includes('parse error')) {
		return 'Unable to parse law data. The format may have changed.';
	}

	// Stage-Specific Messages
	if (errorLower.includes('no extent') || errorLower.includes('extent not found')) {
		return 'Geographic extent not specified for this law.';
	}
	if (errorLower.includes('empty') || errorLower.includes('too short')) {
		return 'Unable to classify. Law body is empty or too short.';
	}

	// Connection to parse stream failed (SSE-specific)
	if (errorLower.includes('connection to parse stream failed')) {
		return 'Lost connection during parsing. Retrying with fallback method...';
	}

	// Default: return original with minor cleanup
	// Remove Elixir-specific formatting like %Req.TransportError{...}
	const cleaned = error
		.replace(/%\w+\.\w+Error\{[^}]*\}/g, '')
		.replace(/Request failed:\s*/i, '')
		.replace(/HTTP \d+:\s*/i, '')
		.trim();

	return cleaned || error;
}

/**
 * Maps a stage-specific error to a user-friendly message with stage context.
 */
export function mapStageError(stage: string, error: string): string {
	const friendlyError = mapParseError(error);

	// Add stage-specific context for certain errors
	switch (stage) {
		case 'metadata':
			if (error.toLowerCase().includes('404')) {
				return 'Metadata not available. This may be draft or historical legislation.';
			}
			break;
		case 'extent':
			if (error.toLowerCase().includes('404') || error.toLowerCase().includes('not found')) {
				return 'Extent data unavailable. Manual review may be needed.';
			}
			break;
		case 'enacted_by':
			// Acts are not enacted by other laws - this is informational, not an error
			if (error.toLowerCase().includes('acts are not enacted')) {
				return 'Primary legislation - not enacted by other laws.';
			}
			break;
		case 'amendments':
			if (error.toLowerCase().includes('timeout')) {
				return 'Amendment data incomplete. This law has extensive amendment history.';
			}
			break;
		case 'repeal_revoke':
			if (error.toLowerCase().includes('404')) {
				return 'Revocation status unknown. Assuming in force.';
			}
			break;
		case 'taxa':
			if (error.toLowerCase().includes('empty') || error.toLowerCase().includes('too short')) {
				return 'Unable to classify. Law body is empty or too short.';
			}
			break;
	}

	return friendlyError;
}

// ============================================================================
// Parse Streaming API (SSE)
// ============================================================================

export type ParseStage =
	| 'metadata'
	| 'extent'
	| 'enacted_by'
	| 'amendments'
	| 'repeal_revoke'
	| 'taxa';

export interface ParseStageStartEvent {
	event: 'stage_start';
	stage: ParseStage;
	stage_num: number;
	total: number;
}

export interface ParseStageCompleteEvent {
	event: 'stage_complete';
	stage: ParseStage;
	status: 'ok' | 'error' | 'skipped';
	summary: string | null;
}

export interface ParseCompleteEvent {
	event: 'parse_complete';
	has_errors: boolean;
	result: ParseOneResult;
}

export type ParseProgressEvent =
	| ParseStageStartEvent
	| ParseStageCompleteEvent
	| ParseCompleteEvent;

export interface ParseProgressCallbacks {
	onStageStart?: (stage: ParseStage, stageNum: number, total: number) => void;
	onStageComplete?: (
		stage: ParseStage,
		status: 'ok' | 'error' | 'skipped',
		summary: string | null
	) => void;
	onComplete?: (result: ParseOneResult) => void;
	onError?: (error: Error) => void;
}

/**
 * Parse a single record with streaming progress updates via SSE.
 * Optionally pass specific stages to retry only those stages.
 * Returns a cleanup function to abort the connection.
 */
export function parseOneStream(
	sessionId: string,
	name: string,
	callbacks: ParseProgressCallbacks,
	stages?: ParseStage[]
): () => void {
	let url = `${API_URL}/api/sessions/${sessionId}/parse-stream?name=${encodeURIComponent(name)}`;
	if (stages && stages.length > 0) {
		url += `&stages=${stages.join(',')}`;
	}
	const eventSource = new EventSource(url);

	eventSource.onmessage = (event) => {
		try {
			const data = JSON.parse(event.data) as
				| ParseProgressEvent
				| { event: 'connected'; name: string };

			switch (data.event) {
				case 'connected':
					// Initial connection confirmed, just ignore
					break;
				case 'stage_start':
					callbacks.onStageStart?.(
						(data as ParseStageStartEvent).stage,
						(data as ParseStageStartEvent).stage_num,
						(data as ParseStageStartEvent).total
					);
					break;
				case 'stage_complete':
					callbacks.onStageComplete?.(
						(data as ParseStageCompleteEvent).stage,
						(data as ParseStageCompleteEvent).status,
						(data as ParseStageCompleteEvent).summary
					);
					break;
				case 'parse_complete':
					callbacks.onComplete?.((data as ParseCompleteEvent).result);
					eventSource.close();
					break;
			}
		} catch (err) {
			console.error('Failed to parse SSE event:', err);
		}
	};

	eventSource.onerror = (event) => {
		console.error('SSE error:', event);
		callbacks.onError?.(new Error('Connection to parse stream failed'));
		eventSource.close();
	};

	// Return cleanup function
	return () => {
		eventSource.close();
	};
}
