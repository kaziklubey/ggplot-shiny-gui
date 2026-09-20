# Current architecture and forward plan

## Current maintenance checkpoint — v3.73.2.39

This document describes the **current runtime only**. Historical designs, removed fallbacks, internal Phase names, and prior validation narratives belong in `CHANGE_HISTORY_ARCHIVE.md`, Git history, or older Releases. They are not active architecture.

Current runtime identity is `v3.73.2.39`. Graph ownership remains canonical GraphState + one persistent Editor. Mapping replay is a target-owned transaction that fixes raw/transformed data, Mapping choices, selected values, and transport completion before canonical acceptance. Legend visibility, merge/split, and independent group/individual titles are ordinary GraphState-owned style fields.

## 1. Canonical ownership

- `GraphState` Registry is the only editable/persisted source of truth for Graphs.
- The Graph workspace owns exactly **one persistent Graph Editor / graphServer module**. Graph identity is state, not module identity.
- Figure owns point-in-time Main / Legend / Inset snapshots plus Figure-owned editable GraphState copies. Figure state is independent from the source Graph after capture.
- DOM inputs, live ggplot objects, browser SVG, and cached geometry are derived views/artifacts, never canonical state.
- Statistics Analysis recipes are persisted inside GraphState but own their own preparation/test settings independently from Plot Mapping and Plot Wide→Long state.

## 2. Normal Graph activation

Normal Graph selection uses one path:

```text
Graph selection
  -> commit outgoing visible owner when needed
  -> read target canonical GraphState
  -> close render gate
  -> derive target Mapping choices from target GraphState data/reshape
  -> replay target choices + GraphState values into persistent Editor
  -> one browser completion barrier
  -> accept canonical target
  -> release final render
  -> READY
```

The browser completion barrier confirms that the value replay has crossed the client/server binding boundary. It is **not** a semantic browser-state comparison and does not create a second source of truth.

Rapid selection may queue the latest requested target behind an in-flight persistent-Editor transaction. No per-Graph Editor is created.

## 3. Explicitly removed Graph architecture

The following are not part of the runtime and must not be reintroduced as fallbacks:

- per-Graph hidden `graphUI()` / `graphServer()` materialization;
- `server_graph_materialization_runtime.R` and hidden materialization queues;
- staged Graph structural restore / `graph_restore_runtime.R`;
- `prepare_restore`, `load_state`, `sync_state`, `prepare_remount`, `remount` Graph APIs;
- Mapping restore-binding ACK handshakes;
- browser semantic canonical compare / reconcile loops;
- Graph restore retry loops;
- DOM remount seeds / remount render epochs;
- source-module revision leases used to authorize dormant hidden Graph modules;
- browser materialization-drain barriers;
- fast/equivalent special Graph-switch architecture.

Compatibility with old Projects is handled by normalizing persisted state and then using the current value-replay path, not by reviving the removed runtime.

## 4. Figure source boundary

Figure source generation is server-side direct-state rendering:

```text
canonical GraphState or Figure-owned GraphState
  -> request_figure_source_snapshot()
  -> server-side render
  -> Figure-owned SVG snapshot
```

Rules:

- New Figure assignment, explicit Graph→Figure refresh, bulk import, and Inset refresh use DIRECT-STATE snapshots.
- Selecting an internal Inset source creates the initial frozen Inset snapshot when needed.
- Later Graph edits do **not** automatically update an existing Figure Main or Inset snapshot.
- Explicit refresh is required to pull a newer Graph state into Figure.
- A visible Figure Editor may be synchronized for presentation, but it is not a hidden snapshot-generation backend.
- Restored Figure/Inset SVG is valid Figure-owned state and may be used without activating its source Graph.

The historical `figure_legend_materializer_*` names are legacy naming only. Their current path is Figure/direct-state work; they do not instantiate hidden Graph Editors.

## 5. Export boundary

Graph export uses canonical state directly:

```text
visible owner -> publish stable state if needed
selected canonical GraphState(s)
  -> graph_state_export_snapshot()
  -> file writer
```

Dormant Graphs are exported without mounting or replaying them. Figure export uses Figure-owned snapshots/state and must preserve the Viewer appearance, including frozen Inset SVG geometry/aspect/border semantics.

## 6. Graph Settings Manager / Shared Style

Graph Settings Manager has three explicit ownership scopes:

- **Graph only:** update canonical GraphState. Dormant Graphs remain state-only and replay on next visit.
- **Figure only:** update Figure-owned GraphState and regenerate the Figure snapshot DIRECT-STATE. Source GraphState remains unchanged.
- **Graph + Figure:** perform both independent operations.

Shared Style follows the same ownership rule: central semantic library changes canonical GraphStates directly, and Figure propagation changes Figure-owned state/snapshots directly. Hidden Graph/Figure Editor switching is not allowed for dormant targets.

The Settings Manager popout is presentation-only; it does not own a Shiny session, GraphState, or graphServer.

## 7. Project save/load

### Load

```text
read .ggplotpack
  -> restore canonical GraphState registry
  -> restore Figure / Inset snapshots and Figure state
  -> remap persisted IDs when required
  -> unlock project state
  -> attach only the selected Graph to the persistent Editor via normal replay
```

Dormant Graphs have no restore UI/module work.

### Save

- Graphs are serialized from canonical Registry state.
- Current visible Editor state is published before save when necessary.
- New Projects do not save Graph SVG previews as Graph authority.
- Figure Main / body / legend / Inset snapshots are persisted as Figure-owned assets.
- Statistics recipes are persisted; calculated result text is regenerated rather than treated as canonical saved output.

Legacy Graph preview assets may be read only for backward-compatible migration where explicitly supported. They must not become current Graph authority or be written back as new Graph previews.

## 8. Statistics boundary

Statistics is hosted in the persistent Graph module but has an independent Analysis recipe lifecycle.

Its restore barrier is `stats-restore-browser-barrier`. This barrier exists only to prevent browser input echoes from being mistaken for user edits while an Analysis recipe is replayed. It must not be reused as GraphState reconciliation.

Statistics restore uses a bounded event/ACK transaction and active-analysis semantic stability checks. Do not add timer/polling synchronization.

## 9. Render / performance rules

- Plot rebuilds are driven by semantic RenderState changes, not arbitrary GraphState/UI snapshot changes.
- `GraphState$ui_snapshot` is persistence/presentation state and does not by itself force Plot rebuilds.
- Avoid synchronization by `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer` for Graph/Figure ownership transactions.
- Prefer canonical state mutation + one explicit replay/snapshot boundary over hidden UI establishment.
- Keep pure transforms separate from reactive transaction wiring.

## 10. Maintenance direction

Before adding a new lifecycle path, decide which existing owner should perform it:

1. Graph canonical state work -> GraphState Registry / persistent Graph Editor.
2. Figure-owned rendering -> direct-state Figure snapshot service.
3. Export -> direct canonical/Figure state renderer.
4. Statistics Analysis restoration -> Statistics-specific barrier.

If a proposed feature requires a dormant Graph to mount a hidden Graph Editor, requires browser semantic readback to decide canonical truth, or adds a retry/reconcile loop, the design conflicts with the current architecture.
