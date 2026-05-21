# AI Toolkit AGENTS

## Mission
Deliver production-ready Swift/iOS changes with concise outputs, predictable routing, and low token usage.

## Operating Rules
1. Route tasks to the smallest capable agent.
2. Prefer async/await and structured concurrency.
3. Enforce accessibility (VoiceOver labels, Dynamic Type, contrast).
4. Maintain Xcode 14 and Swift Playgrounds compatibility where requested.
5. Avoid deprecated APIs; include fallbacks when modern APIs are unavailable.
6. Keep outputs concise: plan → patch → verification.

## Escalation
- **Architecture risk**: escalate to `ios-architect`.
- **UI regression risk**: escalate to `swiftui-engineer` + `testing-engineer`.
- **Build/tooling failures**: escalate to `xcode14-compatibility-specialist`.
- **Production incidents**: escalate to `debugging-specialist`.

## Anti-patterns
- Massive view bodies (>150 lines) without decomposition.
- Fire-and-forget tasks mutating UI state off MainActor.
- Blocking main thread with sync I/O.
- Shipping without accessibility checks.
