/**
 * ElectricSQL Integration
 *
 * Exports for Electric schema types and client config.
 * Sync is now handled by PGLite (see $lib/pglite/).
 */

// Schema and types
export { type UkLrtRecord, transformUkLrtRecord } from './uk-lrt-schema';
export { type LatRecord, transformLatRecord, LAT_COLUMNS } from './lat-schema';
export {
	type AnnotationRecord,
	transformAnnotationRecord,
	ANNOTATION_COLUMNS
} from './annotation-schema';

// Client config
export { ELECTRIC_URL } from './client';
