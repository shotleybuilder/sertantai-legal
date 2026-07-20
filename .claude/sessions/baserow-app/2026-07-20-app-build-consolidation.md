# App Build Consolidation

**Started**: 2026-07-20 11:00
**Meta**: `baserow-app/2026-07-18-meta.md`

## Problem

10 ad-hoc scripts (1,400+ lines, 70+ raw API calls) building the Compliance Workbench app.
Each script hardcodes field IDs, element IDs, page IDs. Fixes create more scripts instead
of improving the build. Not repeatable for a new customer without editing IDs.

## Architecture Plan

### Layer 1: Page Recipes (YAML/Markdown)

Each page of the app is defined by a **recipe file** — a declarative spec that describes
what the page should contain, not how to build it.

```
backend/lib/sertantai_legal/app/recipes/
├── legal_register.yml      # Home page — LRT table + links
├── assessment_queue.yml    # Assessment list
├── assessment_form.yml     # Assessment edit form
├── hierarchy.yml           # Org structure CRUD
├── actions.yml             # Action tracker CRUD
├── duties_list.yml         # Duties filtered by law
├── duty_detail.yml         # Single duty detail
└── MANUAL_STEPS.md         # Human setup for API-unsupported features
```

Recipe format (YAML):
```yaml
page:
  name: Legal Register
  path: /
  query_params:
    - name: law
      type: text

data_sources:
  - name: Legal Register
    type: list_rows
    table: :lrt

elements:
  - type: heading
    value: "Legal Register"
    level: 1

  - type: table
    data_source: Legal Register
    items_per_page: 25
    filterable: true
    sortable: true
    searchable: true
    columns:
      - name: Title
        type: text
        field: Title            # resolved by field name, not ID
      - name: Year
        type: text
        field: Year
      - name: Family
        type: text
        field: Family
        accessor: .value        # single_select
      - name: Status
        type: text
        field: Status
        accessor: .value
      - name: Assessment
        type: text
        field: Assessment_Status
        accessor: .*.value.value  # lookup → single_select
      - name: Actions
        type: text
        field_formula: "concat('✅ ', get('...Actions_Done.*.value'), ...)"
      - name: Assess
        type: link
        navigate_to: assessment_form   # page key, not ID
        params:
          id: "Assessments.0.id"       # first assessment's row ID
      - name: Duties
        type: link
        navigate_to: duties_list
        query:
          law: Name                    # pass law name

  - type: form_container
    submit_label: "Update Node"
    children:                          # declarative nesting (built via UI)
      - type: choice
        label: Status
        options: [Open, In Progress, Completed]
        default_from: edit_ds.Status.value

workflow:
  on_submit:
    - type: update_row
      table: :assessments
      row_id: page_parameter.id
      fields:                          # mapped in UI
        Compliance_Status: form.status
    - type: notification
      title: "Saved"
    - type: open_page
      target: legal_register
```

### Layer 2: Recipe Builder (Elixir module)

```
SertantaiLegal.App.Builder
├── Builder            # Main orchestrator: reads recipes, resolves IDs, calls API
├── RecipeParser       # Parses YAML into structs
├── FieldResolver      # Resolves field names → IDs per table
├── PageBuilder        # Creates pages, data sources, elements
├── WorkflowBuilder    # Creates workflow actions
└── Publisher          # Domain + publish
```

Key abstraction: **field names, not IDs**. The builder resolves `field: Title` to
`field_9565190` at build time by querying the table's fields. Same for page references —
`navigate_to: assessment_form` resolved to `page_id: 1069372` by looking up the page
by its recipe key.

### Layer 3: Manual Steps Document

`MANUAL_STEPS.md` — generated alongside the build, listing exactly what needs UI config:

```markdown
## Legal Register page
- No manual steps (all API-configurable)

## Assessment Form page
1. Drag Compliance Status, Risk Level, Gap Description, Notes INTO the Form container
2. Configure "Update a row" on Form submit:
   - Row ID: Query parameter > edit
   - Map: Compliance_Status ← Form data > Compliance Status
   ...
```

### Resolution order

1. `mix templates.apply` — creates Baserow tables + fields + views
2. `mix app.build` — reads recipes, resolves field IDs, creates app + pages + elements
3. Manual steps — UI config from MANUAL_STEPS.md
4. `mix app.publish` — publish to domain

## Todo
- [x] Design recipe YAML schema (field refs by name, accessors, manual_config flags)
- [x] Build RecipeParser (load YAML, extract table_keys, collect manual_steps)
- [x] Build FieldResolver (table → field name → field ID, formula interpolation)
- [x] Build PageBuilder (pages, data sources, elements, table columns, form children, button events)
- [x] Build Builder orchestrator (auth, app/integration, recipes, resolver, two-pass page build, publish)
- [x] Build `mix app.build` task
- [x] Write 7 recipes: legal_register, assessment_queue, assessment_form, hierarchy, actions, duties_list, duty_detail
- [x] Manual steps extracted from recipe `manual_config` / `manual_nesting` annotations
- [ ] Test `mix app.build` on fresh workspace
- [ ] Delete ad-hoc scripts after confirmed working

## Patterns to abstract

### Column type → formula mapping
- text + scalar field: `get('current_record.field_ID')`
- text + single_select: `get('current_record.field_ID.value')`
- text + multi_select: `get('current_record.field_ID.*.value')`
- text + link_row: `get('current_record.field_ID.*.value')`
- text + lookup: `get('current_record.field_ID.*.value')`
- text + lookup→single_select: `get('current_record.field_ID.*.value.value')`
- tags + multi_select: values=`get('...*.value')`, colors=`get('...*.color')`
- link: navigate_to_page_id + page_parameters/query_parameters

### Same-page create+edit pattern
- query_param `edit` on page
- "Edit DS" (Get Row, row_id = query_parameter.edit)
- Form defaults from Edit DS
- "+ Add" button → Create Row (blank) → Open Page with `Previous action > Create a row > Id`
- Edit link in table → same page with `?edit=ROW_ID`
- Form always does Update Row

### Data source types
- list_rows: table_id + integration_id + optional view filter
- get_row: table_id + integration_id + row_id formula
- summarize: table_id + integration_id + field + function

## Notes
- Single quotes required in formulas for complex paths
- Tags use `values`/`colors` not `value`
- Link fields don't accept `value` property — text set in UI
- parent_element_id not supported on SaaS API — nesting via UI only
- Workflow action service PATCH returns 500 — config via UI only
