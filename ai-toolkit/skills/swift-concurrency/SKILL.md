# SKILL: Swift Concurrency

## Purpose
Production guidance for Swift Concurrency in scalable iOS apps.

## When to Invoke
- New feature touches Swift Concurrency.
- Refactor or bugfix changes behavior/performance/accessibility.
- Need Xcode 14-safe implementation path.

## Common Mistakes
- Overly large files and mixed concerns.
- Missing availability checks.
- Unstructured async work and poor cancellation.

## Anti-patterns
- Deprecated APIs without migration path.
- UI updates off MainActor.
- Unbounded observers/timers causing leaks.

## Correct Example
```swift
@MainActor
func load() async {
    do { state = .loading; state = .loaded(try await service.fetch()) }
    catch { state = .error(error.localizedDescription) }
}
```

## Deprecated APIs to Avoid
- Legacy completion-handler pyramids when async/await exists.
- Force-unwrapped outlets/state assumptions.
- Implicitly unbounded background queues.

## Performance Guidance
- Keep hot paths allocation-light.
- Move heavy work off main thread.
- Add lightweight telemetry around bottlenecks.

## Accessibility Guidance
- Add meaningful labels/hints.
- Support Dynamic Type + VoiceOver navigation.
- Verify color contrast and touch target size.

## Xcode 14 Fallback Patterns
- Use `if #available(iOS 17, *)` for modern APIs.
- Offer iOS 15/16 equivalent modifiers/types.
- Pin SPM dependencies to Xcode 14-compatible versions.
