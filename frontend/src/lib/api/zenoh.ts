/**
 * Zenoh Admin API Client
 *
 * Functions for monitoring Zenoh P2P mesh services.
 */

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:4003';

async function adminFetch(url: string, options: RequestInit = {}): Promise<Response> {
	return fetch(url, { ...options, credentials: 'include' });
}

// --- Types ---

export interface ActivityEntry {
	event: string;
	metadata: Record<string, unknown>;
	timestamp: string;
}

export interface ServiceStats {
	status: string;
	[key: string]: unknown;
}

export interface ServiceStatus {
	state: string;
	[key: string]: unknown;
}

export interface SubscriberStatus extends ServiceStatus {
	key_expr: string | null;
}

export interface DataServerStatus extends ServiceStatus {
	queryable_count: number;
	key_expressions: string[];
}

export interface NotifierStatus extends ServiceStatus {
	key: string | null;
}

export interface SubscriptionsResponse {
	status: SubscriberStatus;
	stats: ServiceStats;
	recent: ActivityEntry[];
}

export interface ServiceData<S = ServiceStatus> {
	status: S;
	stats: ServiceStats;
	recent: ActivityEntry[];
}

export interface QueryablesResponse {
	data_server: ServiceData<DataServerStatus>;
	change_notifier: ServiceData<NotifierStatus>;
}

// --- API Functions ---

export async function getSubscriptions(): Promise<SubscriptionsResponse> {
	const res = await adminFetch(`${API_URL}/api/zenoh/subscriptions`);
	if (!res.ok) {
		const body = await res.json().catch(() => ({}));
		throw new Error(body.error || `Failed to fetch subscriptions: ${res.statusText}`);
	}
	return res.json();
}

export async function getQueryables(): Promise<QueryablesResponse> {
	const res = await adminFetch(`${API_URL}/api/zenoh/queryables`);
	if (!res.ok) {
		const body = await res.json().catch(() => ({}));
		throw new Error(body.error || `Failed to fetch queryables: ${res.statusText}`);
	}
	return res.json();
}
