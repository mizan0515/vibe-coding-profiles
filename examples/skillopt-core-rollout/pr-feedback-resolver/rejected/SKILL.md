---
name: pr-feedback-resolver
description: >
  Rejected PR feedback resolver candidate. Trigger: "PR feedback".
---

# PR Feedback Resolver Rejected Candidate

This rejected candidate allowed PR readiness after local validation while GitHub
comment and review-thread state remained unchecked.

## Why Rejected

- It did not block on unresolved review threads.
- It did not preserve linked issue comment follow-up gates.
- It pushed raw GitHub state inspection back to the manager when data was
  unavailable.

## Rollback

Use `examples/skillopt-core-rollout/pr-feedback-resolver/rollback/SKILL.md`.
