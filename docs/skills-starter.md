# Agent Skills for Starter Template

## What are Agent Skills?

Agent Skills are comprehensive, task-focused guides that help AI assistants (like Claude Code) perform complex, multi-step tasks correctly. Each skill is a detailed playbook for a specific workflow, complete with:

- **Purpose & Context**: What the skill does and when to use it
- **Core Principles**: Fundamental concepts that must be understood
- **Common Pitfalls**: Anti-patterns and what NOT to do
- **Working Patterns**: Step-by-step examples with code
- **Troubleshooting**: Common errors and their solutions
- **Quick Reference**: Essential commands and patterns

Read more: [Anthropic: Equipping Agents for the Real World with Agent Skills](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)

## Skills Directory Structure

All skills are stored in `.claude/skills/` with the following structure:

```
.claude/skills/
├── creating-ash-resources/
│   └── SKILL.md
├── electricsql-sync-setup/
│   └── SKILL.md
├── multi-tenant-resources/
│   └── SKILL.md
└── frontend-tanstack-integration/
    └── SKILL.md
```

Each skill is a standalone directory containing a `SKILL.md` file.

## How to Use Skills

### For AI Assistants (Claude Code)

When working on a task, Claude Code can:

1. **Discover relevant skills** by browsing `.claude/skills/`
2. **Read the skill** to understand the complete workflow
3. **Apply the patterns** from the skill to the current task
4. **Avoid pitfalls** that are explicitly documented
5. **Reference troubleshooting** when encountering errors

### For Developers

You can also read these skills to:

- **Learn project patterns** and conventions
- **Understand complex workflows** with detailed examples
- **Troubleshoot issues** using documented solutions
- **Onboard new team members** with comprehensive guides

## Available Skills in This Template

### 1. Creating Ash Resources (`creating-ash-resources/`)

**When to use**: Adding new domain entities to your application

**Covers**:
- Defining Ash resources with proper attributes
- Setting up PostgreSQL data layer
- Implementing multi-tenancy (organization_id)
- Generating migrations
- Defining actions and code interfaces
- Testing resources

### 2. ElectricSQL Sync Setup (`electricsql-sync-setup/`)

**When to use**: Enabling real-time sync for a resource

**Covers**:
- Configuring PostgreSQL logical replication
- Adding ELECTRIC GRANT statements
- Setting up Shape API subscriptions
- Implementing organization-based filtering
- Handling sync errors
- Testing sync behavior

### 3. Multi-Tenant Resources (`multi-tenant-resources/`)

**When to use**: Ensuring proper data isolation in your application

**Covers**:
- Organization-scoped resource patterns
- Query filtering by organization_id
- Authentication and authorization
- ElectricSQL RLS (Row-Level Security)
- Testing organization isolation
- Common multi-tenancy pitfalls

### 4. Frontend TanStack Integration (`frontend-tanstack-integration/`)

**When to use**: Connecting frontend to synced backend data

**Covers**:
- Setting up TanStack DB collections
- Subscribing to ElectricSQL shapes
- Writing reactive queries
- Handling offline state
- Optimistic updates
- Error handling and retries

## Creating New Skills

As you develop your application, you'll discover patterns worth documenting. Here's how to create a new skill:

### 1. Identify a Repeatable Workflow

Good candidates for skills:
- Complex multi-step processes
- Tasks with common pitfalls
- Workflows involving multiple technologies
- Patterns that require deep understanding

### 2. Create the Skill Directory

```bash
mkdir -p .claude/skills/your-skill-name
```

### 3. Write the SKILL.md File

Use this template:

```markdown
# SKILL: Your Skill Name

**Purpose:** Brief description of what this skill teaches

**Context:** Technologies/frameworks involved

**When to Use:**
- Scenario 1
- Scenario 2
- Scenario 3

---

## Core Principles

### 1. First Core Concept

Explain the fundamental understanding needed.

**Key Understanding:**
- Important point 1
- Important point 2

---

## Common Pitfalls & Solutions

### ❌ Pitfall 1: Descriptive Name

**Why it fails:**
Explain what goes wrong

**✅ Correct Pattern:**
```
Show the right way
```

---

## Working Patterns

### Pattern 1: Task Name

```code
Complete working example
```

**Why this works:**
- Reason 1
- Reason 2

---

## Troubleshooting

### Error: "Error message"

**Check:**
- Thing to verify 1
- Thing to verify 2

**Fix:** Solution

---

## Quick Reference

### Essential Commands

```bash
command-1
command-2
```

---

## Related Skills

- **Other Skill**: `.claude/skills/other-skill/`

---

## Key Takeaways

1. ✅ Do this
2. ✅ Do that
3. ❌ Don't do this
```

### 4. Keep Skills Focused

Each skill should focus on ONE workflow. If you find yourself covering too much, split into multiple skills.

### 5. Update and Refine

As you learn more or patterns change:
- Update existing skills
- Add new pitfalls discovered
- Include real-world examples from your codebase
- Cross-reference related skills

## Best Practices for Skills

### Do:

- ✅ **Be comprehensive**: Include everything needed to complete the task
- ✅ **Show anti-patterns**: Explicitly show what NOT to do
- ✅ **Include real examples**: Use actual code from your project
- ✅ **Document context**: Explain WHY, not just WHAT
- ✅ **Link related skills**: Help discover complementary knowledge
- ✅ **Keep current**: Update when patterns change

### Don't:

- ❌ **Be vague**: Generic advice isn't helpful
- ❌ **Assume knowledge**: Explain everything needed
- ❌ **Skip edge cases**: Document the tricky bits
- ❌ **Ignore errors**: Include troubleshooting
- ❌ **Mix multiple workflows**: Keep skills focused

## Integration with CLAUDE.md

Skills and CLAUDE.md serve different purposes:

**CLAUDE.md**:
- High-level architecture overview
- Quick command reference
- Project structure explanation
- Common configuration files
- "How to navigate the codebase"

**Skills (SKILL.md)**:
- Deep-dive into specific workflows
- Step-by-step task completion
- Common pitfalls and solutions
- Troubleshooting guides
- "How to do X correctly"

Use both together for comprehensive project knowledge.

## Example Workflow

Let's say an AI assistant needs to add a new domain resource with real-time sync:

1. **Read CLAUDE.md** to understand the overall architecture
2. **Read `.claude/skills/creating-ash-resources/SKILL.md`** for resource creation
3. **Read `.claude/skills/multi-tenant-resources/SKILL.md`** for organization scoping
4. **Read `.claude/skills/electricsql-sync-setup/SKILL.md`** for enabling sync
5. **Read `.claude/skills/frontend-tanstack-integration/SKILL.md`** for frontend integration

Each skill builds on the previous, providing complete guidance for the entire workflow.

## Skills vs Documentation

Traditional documentation explains individual features. Skills explain complete workflows.

**Traditional Docs**:
```
Ash.Resource - Defines a resource
Ash.Changeset - Handles changes
AshPostgres - PostgreSQL integration
```

**Skill**:
```
Here's how to create a multi-tenant resource from scratch:
1. Define the resource with these attributes
2. AVOID this common mistake with organization_id
3. Generate migration this way
4. Test it like this
5. If you see this error, do this
```

## Maintenance

### When to Update Skills

- **Pattern changes**: Core patterns evolve
- **New pitfalls discovered**: Team encounters new issues
- **Technology updates**: Framework versions change
- **Better approaches found**: Improved patterns emerge

### Review Cycle

Recommended: Review skills quarterly or when:
- Onboarding new team members (they find gaps)
- Major version upgrades
- Repeated questions/issues arise

## Contributing Skills

When you solve a complex problem:

1. Document the solution in a skill
2. Include the context of what went wrong
3. Show the working solution
4. Add troubleshooting for future occurrences
5. Link related skills

This builds institutional knowledge and helps the entire team.

## Template Skills

This starter template includes foundational skills for:
- **Ash Framework**: Resource creation, actions, testing
- **ElectricSQL**: Real-time sync setup and configuration
- **Multi-tenancy**: Organization-scoped data patterns
- **Frontend**: TanStack DB integration with ElectricSQL

You should add your own skills for:
- Domain-specific workflows
- Integration patterns
- Deployment procedures
- Testing strategies
- Performance optimization
- Security patterns

## Further Reading

- [Agent Skills Blog Post](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills) - Anthropic Engineering
- [CLAUDE.md](../CLAUDE.md) - High-level codebase overview
- [usage-rules.md](../usage-rules.md) - Enforced coding patterns
- [docs/BLUEPRINT.md](BLUEPRINT.md) - Technical architecture guide

---

**Remember**: Skills are living documents. Update them as you learn. Share them with your team. Build institutional knowledge that lasts beyond individual developers.
