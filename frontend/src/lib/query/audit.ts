/**
 * TanStack Query hooks for LAT Audit API
 */

import { createQuery } from '@tanstack/svelte-query';
import {
	getAuditSummary,
	getAuditLaw,
	type AuditResponse,
	type AuditLawDetail
} from '$lib/api/audit';

export const auditKeys = {
	all: ['audit'] as const,
	summary: (family?: string) => [...auditKeys.all, 'summary', family] as const,
	law: (lawName: string) => [...auditKeys.all, 'law', lawName] as const
};

export function useAuditSummaryQuery(family?: string) {
	return createQuery<AuditResponse>({
		queryKey: auditKeys.summary(family),
		queryFn: () => getAuditSummary(family)
	});
}

export function useAuditLawQuery(lawName: string | null) {
	return createQuery<AuditLawDetail>({
		queryKey: auditKeys.law(lawName ?? ''),
		queryFn: () => getAuditLaw(lawName!),
		enabled: !!lawName
	});
}
