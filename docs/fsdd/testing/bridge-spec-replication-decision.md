# Bridge Spec Replication Decision

Architectural decision record for how Scribe tests its Crystal native library
bridge without linking the real object files into the spec binary.

---

## Context

Scribe's mobile apps (iOS and Android) embed a Crystal native library that
exposes C-callable functions (`scribe_init`, `scribe_start_recording`,
`scribe_stop_recording`, `scribe_start_playback`, `scribe_stop_playback`,
`scribe_is_recording`). The Crystal source lives at
`mobile/shared/scribe_bridge.cr` and is cross-compiled into a static library
(iOS) or shared object (Android) that links into the Swift / Kotlin host app.

The bridge contains a private `Bridge` module managing state (initialized,
recording, has_recorder, has_player) and the `fun` declarations that make
up the C API. Testing this code in isolation is non-trivial because the
compiled artifact is designed to be hosted by another binary, not run
standalone.

Two options were evaluated.

---

## Option A -- Link Object Files

Compile `scribe_bridge.cr` to an object file and link it into a Crystal spec
binary that calls the exported functions.

### How it would work

```bash
crystal-alpha build scribe_bridge.cr --cross-compile -Dmacos -o build/bridge
ld -r -unexported_symbol _main build/bridge.o -o build/bridge_nomain.o
crystal-alpha spec spec/bridge_spec.cr --link-flags="build/bridge_nomain.o ..."
```

### Pros

- Tests the real compiled code, not a replica.
- Catches implementation bugs (typos, wrong variable, missing rescue).
- Return codes come from the actual `fun` bodies.

### Cons

- **`_main` symbol conflict.** Crystal's `scribe_bridge.cr` defines
  `fun main` (required so the host app's @main entry point takes precedence).
  The spec runner also generates a `main`. Linking both produces a duplicate
  symbol error. The workaround is `ld -r -unexported_symbol _main` to make
  Crystal's main local, but this is fragile and non-obvious.

- **Multiple .o dependencies.** The bridge requires several C extension object
  files at link time:
  - `block_bridge.o` (Crystal block-to-C-callback bridge)
  - `objc_helpers.o` (ObjC runtime helpers)
  - `trace_helper.o` (stderr trace function)
  - `audio_write_helper.o` (WAV write support)
  - `system_audio_tap_stub.o` (stub for system audio)

  Each must be compiled separately and passed via `--link-flags`. Any change
  to the extension file set breaks the spec build.

- **Hardware dependencies.** The bridge requires `crystal_audio` which
  initializes audio frameworks (AVFoundation on iOS, AAudio on Android). Spec
  environments (CI runners, containers) typically lack audio hardware and
  frameworks, causing runtime crashes or link failures.

- **Fragile Makefile.** Maintaining a separate build target for "bridge object
  file suitable for spec linking" adds ongoing maintenance burden.

---

## Option B -- Replicate Interface (CHOSEN)

Create standalone `BridgeState` and `BridgeAPI` modules inside the spec file
that mirror the bridge's state machine contract. Test the contract, not the
implementation.

### How it works

The spec file (`mobile/shared/spec/scribe_bridge_spec.cr`) defines:

- `private module BridgeState` -- mirrors the `Bridge` module's class
  variables (`@@initialized`, `@@recording`, `@@has_recorder`, `@@has_player`)
  with the same getter/setter interface.

- `module BridgeAPI` -- mirrors each `fun` declaration's logic (guard
  clauses, state transitions, return codes) but replaces hardware calls
  (`CrystalAudio::Recorder.new`, `.start`, `.stop`) with state flag mutations.

### Pros

- **Simple.** One file, zero external dependencies. No Makefile, no .o files,
  no linker flags.
- **CI-safe.** Runs anywhere `crystal-alpha` is installed. No audio hardware,
  no platform frameworks, no simulator required.
- **Tests the contract.** State transitions, guard clauses, and return codes
  are the interface that iOS and Android host apps depend on. If the contract
  is correct, the host app integration works.
- **Fast.** 25 tests execute in under 100 ms.

### Cons

- **Drift risk.** The spec replica can diverge from the real bridge if someone
  changes `scribe_bridge.cr` without updating the spec.

---

## Decision

**Option B was chosen** for the following reasons:

1. The `fun main` conflict (Option A) required a non-obvious `ld -r
   -unexported_symbol _main` workaround that would surprise future
   contributors and break if Crystal's codegen changes.

2. CI environments do not have audio hardware. Option A would either crash at
   runtime or require extensive mocking of `CrystalAudio` internals, which
   defeats the purpose of testing "real code."

3. The contract (state transitions + return codes) is what matters to the host
   apps. Swift and Kotlin call `scribe_start_recording` and check the return
   code. They do not care whether `CrystalAudio::Recorder.new` was called
   internally -- that is an implementation detail.

4. 25 tests running in under 100 ms provides rapid feedback during
   development. Option A's link step alone would take longer.

---

## Drift Mitigation

The following conventions reduce the risk of spec-to-bridge divergence:

| Convention | Detail |
|-----------|--------|
| Module naming | Spec's `BridgeState` mirrors bridge's `Bridge` module structure |
| State variables | Spec uses the same names: `@@initialized`, `@@recording`, `@@has_recorder`, `@@has_player` |
| Return codes | Spec asserts the same values: 0 (success), -1 (error), 1 (true for `is_recording`) |
| Guard clauses | Spec replicates the same guards (e.g., `return -1 unless recording?`) |
| Comment headers | Spec comments reference the corresponding `fun` in `scribe_bridge.cr` by name |

Additionally:

- Any change to `scribe_bridge.cr`'s public C API (new function, changed
  return code, new state variable) should trigger an update to the spec.
  This is documented in
  [Partial Testability -- Epic 7](partial-testability-epic-7.md).

- If the bridge is ever refactored to extract the state machine into a
  separate file (e.g., `bridge_state.cr`), the spec can require that file
  directly, eliminating the replication entirely.

---

## Wisdom Captured

### The `_main` symbol conflict

Crystal's `scribe_bridge.cr` must define `fun main` as a no-op because the
host app (Swift's `@main`, Kotlin's `MainActivity`) provides the real entry
point. When cross-compiling, this `main` becomes the `_main` symbol in the
object file. Linking this object into a spec binary (which also has `_main`
from the spec runner) produces a duplicate symbol error.

**Workaround:** `ld -r -unexported_symbol _main bridge.o -o bridge_nomain.o`
makes the symbol local. This was discovered during Epic 7 implementation and
is also used in the iOS build pipeline (`build_crystal_lib.sh`).

### Naming the options

Labeling alternatives as "Option A" and "Option B" with a clear "(CHOSEN)"
marker makes it easy to reference the decision in future discussions.
Contributors can say "we chose Option B because of _main conflicts" without
re-reading the full analysis.

---

## Applicability

This pattern works for any Crystal native library compiled into a host app
binary:

- **crystal-audio** compiled into Scribe's iOS/Android apps
- **Asset Pipeline renderers** compiled for AppKit, UIKit, or Android targets
- Any future Crystal library exposing a C API to a non-Crystal host

The key question is always: "Is the contract (state transitions + return
codes) more valuable to test than the implementation (hardware interaction)?"
If yes, Option B applies.

---

## References

- `mobile/shared/scribe_bridge.cr` -- the real bridge source
- `mobile/shared/spec/scribe_bridge_spec.cr` -- the spec using Option B
- [Testing Architecture](TESTING_ARCHITECTURE.md) -- full 3-layer overview
- [Partial Testability -- Epic 7](partial-testability-epic-7.md) -- per-story analysis
