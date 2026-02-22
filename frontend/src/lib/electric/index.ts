/**
 * ElectricSQL Integration
 *
 * Exports for Electric sync functionality.
 */

// Schema and types
export { type UkLrtRecord, transformUkLrtRecord } from './uk-lrt-schema';
export { type LatRecord, transformLatRecord, LAT_COLUMNS } from './lat-schema';
export {
	type AnnotationRecord,
	transformAnnotationRecord,
	ANNOTATION_COLUMNS
} from './annotation-schema';

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
