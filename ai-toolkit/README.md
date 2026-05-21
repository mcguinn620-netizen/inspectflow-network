# AI Toolkit for Swift Agent Engineering

Portable multi-agent + skills system inspired by patterns indexed in Twostraws' Swift-Agent-Skills repository.

## Included
- `agents/`: role files for architecture, UI, backend, debugging, testing, App Store, Playgrounds, Xcode14.
- `skills/`: reusable SKILL.md packs (SwiftUI, concurrency, data layers, CI/CD, accessibility, performance).
- `rules/`: token-efficiency and operating constraints.
- `templates/project-bootstrap/`: drop-in starter for future repos.
- `scripts/`: sync, export, install automation.
- `codex.toml`: Codex aliases + workflows.
- `lovable-agent-config.json`: routing + pipelines.

## Quick Start
1. `./scripts/install-toolkit.sh /path/to/target/ai-toolkit`
2. In Codex, use aliases: `$swiftui-pro`, `$coredata`, `$ios-debugging`, `$xcode14`, `$bitrise-ios`, `$supabase-ios`.
3. In Lovable, upload `lovable-agent-config.json` with `agents/` and `skills/`.

## How Agents Work
- Route by intent (UI/backend/debug/testing/deployment).
- Escalate architecture/performance/release blockers per `AGENTS.md`.
- Keep responses compact: context, patch, checks.

## How Skills Work
Each SKILL.md includes purpose, invocation criteria, anti-patterns, examples, deprecated API cautions, performance, accessibility, and Xcode14 fallbacks.

## Multi-tool Compatibility
- Codex: `codex.toml` aliases + workflow blocks.
- Lovable.dev: routing/pipeline JSON.
- Cursor/Windsurf/Claude Code: consume markdown agents/skills directly.
- Swift Playgrounds/Xcode14: explicit fallback notes in every skill.

## Updating from GitHub
- `./scripts/sync-skills.sh` clones/pulls Twostraws index and refreshes local upstream snapshot.

## Packaging & Distribution
- `./scripts/export-toolkit.sh` creates reusable zip bundle.
- Upload resulting package to Lovable/Codex/Cursor/Claude Code projects.
