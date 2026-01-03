/**
 * ElectricSQL Integration
 *
 * Exports for Electric sync functionality.
 */

// Schema and types
export { type UkLrtRecord, transformUkLrtRecord } from './uk-lrt-schema';

// Sync functions
export {
	syncUkLrt,
	stopUkLrtSync,
	updateUkLrtWhere,
	getUkLrtSyncStatus,
	checkElectricHealth,
	buildWhereFromFilters,
	syncStatus,
	type SyncStatus
} from './sync-uk-lrt';

// Client config
export { ELECTRIC_URL, getCurrentYear, getDefaultUkLrtWhere } from './client';
