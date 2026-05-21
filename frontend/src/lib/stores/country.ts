/**
 * Country context store for multi-jurisdiction support.
 *
 * Drives all PGlite queries via `WHERE country = $1`.
 * Admin users can switch between countries; all data is local.
 */

import { writable, derived } from 'svelte/store';

export interface CountryInfo {
	code: string;
	name: string;
	partition: string; // Electric partition table name
}

export const COUNTRIES: CountryInfo[] = [
	{ code: 'uk', name: 'United Kingdom', partition: 'legal_register_uk' },
	{ code: 'au', name: 'Australia', partition: 'legal_register_au' }
];

/** Currently selected country code */
export const selectedCountry = writable<string>('uk');

/** Derived: full country info for the selected country */
export const currentCountry = derived(selectedCountry, ($code) => {
	return COUNTRIES.find((c) => c.code === $code) ?? COUNTRIES[0];
});
