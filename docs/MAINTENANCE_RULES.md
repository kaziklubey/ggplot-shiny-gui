# Function-first maintenance rules

1. **New behavior starts as a named function.** Give it explicit inputs and an explicit return value whenever possible.
2. **Observers are wiring, not business logic.** An observer should collect an event, call a function, and commit/send the result.
3. **Canonical state stays canonical.** Registry / GraphState is authoritative; DOM, Shiny inputs, plot objects, and previews are views/derived artifacts.
4. **Extend contracts instead of scattering type checks.** Plot-type capabilities belong in `graph_plot_contract.R`.
5. **Replace, then remove.** After callers move to a new function, delete the old function/path unless a documented compatibility reason remains.
6. **No silent overrides.** Do not redefine an existing function later in the source order to change behavior. Create the new function, migrate callers, then remove the old one.
7. **Side effects are named.** Functions that commit Registry state, update Shiny inputs, send browser messages, or write files should make that responsibility obvious in their names/docs.
8. **Keep transaction code separate from pure transformation code.** Replay/snapshot/render lifecycle may remain reactive, but parsing, normalization, validation, mapping contracts and plot preparation should be ordinary functions.
9. **Legacy code has an exit condition.** Compatibility branches must say what they support and when they can be removed.
10. **Each structural refactor leaves an executable checkpoint.** Do not combine unrelated architecture changes in one step.

## Browser JavaScript

`www/app_client.js` remains one ordered client runtime in this checkpoint. It contains many cross-section handlers whose ordering and shared browser globals are currently intentional. Do not split it merely for line count. Split only after defining explicit client-side module interfaces and preserving script load order; `node --check` is necessary but not sufficient for that later change.

## Graph lifecycle rule

Graph compatibility work must normalize old state into the current canonical schema and then use the ordinary persistent-Editor value replay. Do not preserve or recreate a second structural restore/remount/reconcile runtime for legacy Projects. Figure/Export work on dormant Graphs must use direct state, not hidden UI materialization.
