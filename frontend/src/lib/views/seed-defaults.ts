/**
 * Seed and update default views in the view store.
 *
 * - Seeds any default views that don't yet exist
 * - Updates existing default views whose config has drifted from code-defined defaults
 *
 * Used by admin pages to ensure default views stay in sync with code changes.
 */
import type {
	ViewConfig,
	SavedView,
	GroupActions,
	ViewGroup
} from '@shotleybuilder/svelte-gridlite-views';

export interface ViewDef {
	name: string;
	description: string;
	config: ViewConfig;
	customQuery?: string;
	isDefault?: boolean;
}

export interface ViewActions {
	save(input: { name: string; description: string; config: ViewConfig }): Promise<SavedView>;
	update(id: string, updates: { config: ViewConfig }): Promise<void>;
	delete(id: string): Promise<void>;
}

/**
 * Deterministic JSON.stringify with sorted keys (handles JSONB key-order differences from PGLite).
 */
function stableStringify(obj: unknown): string {
	return JSON.stringify(obj, (_, v) =>
		v && typeof v === 'object' && !Array.isArray(v)
			? Object.keys(v)
					.sort()
					.reduce((acc: Record<string, unknown>, k) => {
						acc[k] = (v as Record<string, unknown>)[k];
						return acc;
					}, {})
			: v
	);
}

/**
 * Compare two ViewConfig objects for equality.
 * Normalizes undefined vs missing keys, pageSize defaults, and JSONB key order.
 */
function configsEqual(a: ViewConfig, b: ViewConfig): boolean {
	if (stableStringify(a.filters) !== stableStringify(b.filters)) return false;
	if ((a.filterLogic ?? 'and') !== (b.filterLogic ?? 'and')) return false;
	if (stableStringify(a.sorting) !== stableStringify(b.sorting)) return false;
	if (stableStringify(a.grouping) !== stableStringify(b.grouping)) return false;
	if (stableStringify(a.columnVisibility) !== stableStringify(b.columnVisibility)) return false;
	if (JSON.stringify(a.columnOrder) !== JSON.stringify(b.columnOrder)) return false; // arrays — order matters
	if (stableStringify(a.columnWidths) !== stableStringify(b.columnWidths)) return false;
	if ((a.pageSize ?? null) !== (b.pageSize ?? null)) return false;
	return true;
}

export { configsEqual as _configsEqual };

export interface SeedResult {
	seeded: string[];
	updated: string[];
	defaultViewId: string | null;
}

/**
 * Reconcile persisted views with code-defined defaults.
 *
 * 1. Deduplicates existing views (deletes duplicates by name)
 * 2. Updates existing default views whose config has changed
 * 3. Seeds any missing default views
 *
 * Returns the list of seeded/updated view names and the default view ID.
 */
export async function seedDefaultViews(
	defaults: ViewDef[],
	currentViews: SavedView[],
	actions: ViewActions
): Promise<SeedResult> {
	const result: SeedResult = { seeded: [], updated: [], defaultViewId: null };

	// Deduplicate
	const existingViews = new Map<string, string>();
	for (const view of currentViews) {
		if (existingViews.has(view.name)) {
			try {
				await actions.delete(view.id);
			} catch {
				/* dedup */
			}
		} else {
			existingViews.set(view.name, view.id);
		}
	}

	// Update existing default views whose config has changed
	for (const def of defaults) {
		const existingId = existingViews.get(def.name);
		if (!existingId) continue;
		const existing = currentViews.find((v) => v.id === existingId);
		if (!existing) continue;
		if (!configsEqual(def.config, existing.config)) {
			await actions.update(existingId, { config: def.config });
			result.updated.push(def.name);
		}
	}

	// Find default view ID
	const defaultViewDef = defaults.find((v) => v.isDefault);
	if (defaultViewDef && existingViews.has(defaultViewDef.name)) {
		result.defaultViewId = existingViews.get(defaultViewDef.name) || null;
	}

	// Seed missing
	const missingViews = defaults.filter((v) => !existingViews.has(v.name));
	for (const view of missingViews) {
		const saved = await actions.save({
			name: view.name,
			description: view.description,
			config: view.config
		});
		if (view.isDefault && saved?.id) {
			result.defaultViewId = saved.id;
		}
		result.seeded.push(view.name);
	}

	return result;
}

export interface GroupDef {
	name: string;
	icon?: string;
}

/**
 * Seed default groups into the view store.
 * Idempotent — skips groups that already exist by name.
 * Returns a map of groupName → groupId for use in assignViewsToGroups.
 */
export async function seedDefaultGroups(
	defaults: GroupDef[],
	currentGroups: ViewGroup[],
	groupActions: GroupActions
): Promise<Map<string, string>> {
	const nameToId = new Map<string, string>();

	// Index existing groups
	for (const group of currentGroups) {
		nameToId.set(group.name, group.id);
	}

	// Seed missing
	for (const def of defaults) {
		if (!nameToId.has(def.name)) {
			const group = await groupActions.createGroup({ name: def.name, icon: def.icon });
			nameToId.set(def.name, group.id);
		}
	}

	return nameToId;
}

/**
 * Assign views to groups based on a view-name → group-name mapping.
 * Idempotent — only moves views that aren't already in the correct group.
 */
export async function assignViewsToGroups(
	viewToGroupName: Record<string, string>,
	groupNameToId: Map<string, string>,
	savedViews: SavedView[],
	groupActions: GroupActions
): Promise<void> {
	for (const view of savedViews) {
		const expectedGroupName = viewToGroupName[view.name];
		if (!expectedGroupName) continue;
		const expectedGroupId = groupNameToId.get(expectedGroupName);
		if (!expectedGroupId) continue;
		if (view.groupId !== expectedGroupId) {
			await groupActions.moveViewToGroup(view.id, expectedGroupId);
		}
	}
}
