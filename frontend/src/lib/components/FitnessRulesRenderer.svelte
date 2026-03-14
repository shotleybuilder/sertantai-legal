<!--
  FitnessRulesRenderer.svelte

  Renders fitness applicability rules with two view modes:
  - Group by Article: rules grouped by article reference (section/1, section/4, etc.)
  - Group by Person: rules grouped by person (employer, employee, etc.)

  Each rule has: article, polarity (AppliesTo/DisappliesTo), and 6 optional facets.
-->
<script lang="ts">
	interface FitnessRule {
		article: string | null;
		polarity: string | null;
		person: string | null;
		place: string | null;
		plant: string | null;
		process: string | null;
		property: string | null;
		sector: string | null;
	}

	/** The fitness rules array */
	export let rules: FitnessRule[] = [];

	type GroupMode = 'article' | 'person';
	let groupMode: GroupMode = 'article';

	/** Facet keys to display (excluding article, polarity, and the grouping key) */
	const FACET_KEYS: (keyof FitnessRule)[] = ['person', 'place', 'plant', 'process', 'property', 'sector'];

	/** Split comma-separated string into trimmed items */
	function splitFacet(val: string | null): string[] {
		if (!val) return [];
		return val.split(',').map(s => s.trim()).filter(Boolean);
	}

	/** Group rules by article */
	function groupByArticle(items: FitnessRule[]): Map<string, FitnessRule[]> {
		const groups = new Map<string, FitnessRule[]>();
		for (const rule of items) {
			const key = rule.article || '(no article)';
			if (!groups.has(key)) groups.set(key, []);
			groups.get(key)!.push(rule);
		}
		return groups;
	}

	/** Group rules by person (one rule can appear under multiple persons) */
	function groupByPerson(items: FitnessRule[]): Map<string, FitnessRule[]> {
		const groups = new Map<string, FitnessRule[]>();
		for (const rule of items) {
			const persons = splitFacet(rule.person);
			if (persons.length === 0) {
				const key = '(no person)';
				if (!groups.has(key)) groups.set(key, []);
				groups.get(key)!.push(rule);
			} else {
				for (const p of persons) {
					if (!groups.has(p)) groups.set(p, []);
					groups.get(p)!.push(rule);
				}
			}
		}
		// Sort by key
		return new Map([...groups.entries()].sort((a, b) => a[0].localeCompare(b[0])));
	}

	$: grouped = groupMode === 'article' ? groupByArticle(rules) : groupByPerson(rules);

	/** Get facets to show for a rule, excluding the current group key */
	function getVisibleFacets(rule: FitnessRule): { label: string; value: string }[] {
		const excludeKey = groupMode === 'person' ? 'person' : null;
		const result: { label: string; value: string }[] = [];
		for (const key of FACET_KEYS) {
			if (key === excludeKey) continue;
			if (rule[key]) {
				result.push({ label: key, value: rule[key]! });
			}
		}
		return result;
	}
</script>

{#if rules.length === 0}
	<div class="px-4 py-3 text-sm text-gray-400 italic">No fitness rules</div>
{:else}
	<!-- View mode toggle -->
	<div class="px-4 py-2 flex items-center gap-2 border-b border-gray-100">
		<span class="text-xs text-gray-500">Group by:</span>
		<button
			class="px-2 py-0.5 text-xs rounded {groupMode === 'article' ? 'bg-indigo-100 text-indigo-700 font-medium' : 'text-gray-600 hover:bg-gray-100'}"
			on:click={() => groupMode = 'article'}
		>
			Article
		</button>
		<button
			class="px-2 py-0.5 text-xs rounded {groupMode === 'person' ? 'bg-indigo-100 text-indigo-700 font-medium' : 'text-gray-600 hover:bg-gray-100'}"
			on:click={() => groupMode = 'person'}
		>
			Person
		</button>
		<span class="ml-auto text-xs text-gray-400">{rules.length} rule{rules.length !== 1 ? 's' : ''}</span>
	</div>

	<!-- Grouped rules -->
	<div class="divide-y divide-gray-100">
		{#each [...grouped.entries()] as [groupKey, groupRules]}
			<div class="px-4 py-2">
				<!-- Group header -->
				<div class="flex items-center gap-2 mb-1">
					<span class="text-sm font-medium text-gray-800">{groupKey}</span>
					<span class="text-xs text-gray-400">({groupRules.length})</span>
				</div>

				<!-- Rules in this group -->
				<div class="ml-3 space-y-1.5">
					{#each groupRules as rule}
						<div class="flex items-start gap-2 text-xs">
							<!-- Polarity badge -->
							{#if rule.polarity === 'AppliesTo'}
								<span class="shrink-0 mt-0.5 px-1.5 py-0.5 rounded bg-green-100 text-green-700 font-medium">Applies</span>
							{:else if rule.polarity === 'DisappliesTo'}
								<span class="shrink-0 mt-0.5 px-1.5 py-0.5 rounded bg-red-100 text-red-700 font-medium">Disapplies</span>
							{:else}
								<span class="shrink-0 mt-0.5 px-1.5 py-0.5 rounded bg-gray-100 text-gray-600">{rule.polarity || '?'}</span>
							{/if}

							<!-- Article reference (shown when grouping by person) -->
							{#if groupMode === 'person' && rule.article}
								<span class="shrink-0 mt-0.5 text-gray-500 font-mono">{rule.article}</span>
							{/if}

							<!-- Facets -->
							<div class="flex flex-wrap gap-x-3 gap-y-0.5 text-gray-700">
								{#each getVisibleFacets(rule) as facet}
									<span>
										<span class="text-gray-400">{facet.label}:</span>
										{facet.value}
									</span>
								{/each}
							</div>
						</div>
					{/each}
				</div>
			</div>
		{/each}
	</div>
{/if}
