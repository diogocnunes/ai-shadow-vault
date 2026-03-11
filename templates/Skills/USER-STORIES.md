---
name: user-stories
description: Analyze a codebase and break down a goal into atomic user stories with acceptance criteria, dependency ordering, and implementation notes. Use when planning a feature, estimating work, or creating an execution roadmap. Writes plans to .ai/plans/<goal-slug>.user-stories.md and must not implement code.
argument-hint: <goal-description>
disable-model-invocation: false
user-invocable: true
allowed-tools: Read, Grep, Glob, Write, Bash
code: fork
agent: Explore
---

# User Stories

Plan mode only. Do not implement anything.

## Goal Handling

- If `$ARGUMENTS` is empty, ask the user which goal should be broken down into user stories.
- If `$ARGUMENTS` is present, use it directly as the planning goal.

## Mission

1. Analyze the codebase to understand architecture, conventions, technologies, and similar features.
2. Break the goal into small, atomic, implementable user stories.
3. Order stories by dependency.
4. Estimate complexity using T-shirt sizes.
5. Write the resulting plan to `.ai/plans/<generated-slug>.user-stories.md`.

## Context Requirements

Before decomposing the goal:

- Read `.ai/context/agent-context.md` when it exists.
- Use `.ai/skills/ACTIVE_SKILLS.md` when it exists for specialized guidance.
- Inspect relevant code paths to confirm architecture and naming patterns.

## Story Rules

Each story must be:

- Atomic
- Small enough for one coding session
- Valuable
- Testable

Avoid:

- Stories that still need to be broken down further
- Vague acceptance criteria
- Hidden dependencies
- Implementation work in this planning step

## Complexity Guide

- `XS`: less than 1 hour, trivial change, usually one file
- `S`: 1-2 hours, familiar pattern, 1-3 files
- `M`: 2-4 hours, moderate uncertainty, 3-5 files
- `L`: 4-8 hours, significant complexity, 5-10 files
- `XL`: too large, break it down further

## Filename Rules

Generate a kebab-case slug from the goal:

- remove filler articles such as `a`, `an`, `the`, `um`, `uma`, `o`, `os`, `a`, `as`
- keep the main nouns, verbs, and key technologies
- lowercase everything
- replace separators with hyphens
- keep 3-5 meaningful words when possible
- write to `.ai/plans/<slug>.user-stories.md`

Examples:

- `implement JWT authentication in the backend` -> `.ai/plans/jwt-authentication-backend.user-stories.md`
- `create Stripe payment API` -> `.ai/plans/stripe-payment-api.user-stories.md`
- `add image upload support` -> `.ai/plans/image-upload-support.user-stories.md`

## Output Format

Write the file with this structure:

```markdown
# Development Plan: [Goal Summary]

**Generated**: [ISO Date]  
**Goal**: $ARGUMENTS

## Context Summary

[Brief summary of the current codebase state, relevant technologies, and constraints]

## User Stories

```json
[
  {
    "id": "US-001",
    "title": "Story title in user voice",
    "description": "As a [user type], I want [goal] so that [benefit].",
    "acceptanceCriteria": [
      "Specific, verifiable criterion 1",
      "Specific, verifiable criterion 2"
    ],
    "priority": 1,
    "complexity": "S",
    "dependencies": [],
    "filesToTouch": ["path/to/file1", "path/to/file2"],
    "notes": "Technical notes, risks, or implementation hints"
  }
]
```

## Implementation Notes

- [Key architectural insight]
- [Risks or blockers]
- [Suggested testing approach]
- [Performance or migration considerations]

## Definition of Done

- [ ] All acceptance criteria met
- [ ] Tests written and passing
- [ ] Code reviewed
- [ ] Documentation updated when needed
```

## Process

1. Generate the output slug.
2. Explore the repository with read/search tools.
3. Identify similar existing features and conventions.
4. Decompose the goal into 3-10 stories.
5. Order stories by dependency.
6. Write the plan file to `.ai/plans/<slug>.user-stories.md`.
7. Report the full path of the created file.

Target fewer stories when possible. Clarity is more important than quantity.
