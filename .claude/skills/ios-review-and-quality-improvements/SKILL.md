---
name: ios-review-and-quality-improvements
description: Staff-level iOS code review and quality improvements for Swift, SwiftUI, Core Data, and Swift Concurrency changes. Use when asked to review code changes in a branch, analyze framework-specific updates, and propose a plan to finalize changes, reduce tech debt, and improve code quality.
---
# iOS Code Review and Quality Improvements

## Workflow

- Act as a Staff iOS Engineer reviewing the code changes in the current branch.
- Ask the user to confirm the branch name before starting the review.
- Use `.claude/skills/core-data-expert/SKILL.md` to analyze Core Data changes.
- Use `.claude/skills/swiftui-expert-skill/SKILL.md` to analyze SwiftUI changes.
- Use `.claude/skills/swift-concurrency/SKILL.md` to analyze concurrency changes.
- Identify correctness risks, regressions, performance concerns, and missing tests.
- Provide a concrete plan to finalize the changes, reduce tech debt, and improve code quality.

## Output Expectations

- Summarize key findings and risks, prioritized by severity.
- Call out test gaps and propose focused test additions.
- Provide a step-by-step plan with owners or next actions where possible.
