/**
 * Seed and update default views in the view store.
 *
 * - Seeds any default views that don't yet exist
 * - Updates existing default views whose config has drifted from code-defined defaults
 *
 * Used by admin pages to ensure default views stay in sync with code changes.
 */
import type { ViewConfig, SavedView } from '@shotleybuilder/svelte-gridlite-views';

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
 * Compare two ViewConfig objects for equality.
 * Normalizes undefined vs missing keys and pageSize defaults.
 */
function configsEqual(a: ViewConfig, b: ViewConfig): boolean {
	// Compare each field individually to avoid serialization order issues
	if (JSON.stringify(a.filters) !== JSON.stringify(b.filters)) return false;
	if ((a.filterLogic ?? 'and') !== (b.filterLogic ?? 'and')) return false;
	if (JSON.stringify(a.sorting) !== JSON.stringify(b.sorting)) return false;
	if (JSON.stringify(a.grouping) !== JSON.stringify(b.grouping)) return false;
	if (JSON.stringify(a.columnVisibility) !== JSON.stringify(b.columnVisibility)) return false;
	if (JSON.stringify(a.columnOrder) !== JSON.stringify(b.columnOrder)) return false;
	if (JSON.stringify(a.columnWidths) !== JSON.stringify(b.columnWidths)) return false;
	// pageSize: treat undefined and null as equivalent
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
			try { await actions.delete(view.id); } catch { /* dedup */ }
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
		const saved = await actions.save({ name: view.name, description: view.description, config: view.config });
		if (view.isDefault && saved?.id) {
			result.defaultViewId = saved.id;
		}
		result.seeded.push(view.name);
	}

	return result;
}
