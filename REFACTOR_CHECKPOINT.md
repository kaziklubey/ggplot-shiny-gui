# Current refactor checkpoint — v3.73.2.39

この文書は**現行runtimeの維持条件だけ**を記載します。過去の移行設計や内部Phase番号は `docs/CHANGE_HISTORY_ARCHIVE.md`、Git history、過去Releaseを参照してください。

Current runtime identity: `v3.73.2.39`.

## Non-negotiable Graph invariants

1. Canonical Graph authority is `GraphState` Registry state.
2. Normal Graph editing uses exactly **one persistent Graph Editor / graphServer instance**.
3. Graph activation is canonical GraphState -> target Mapping transaction -> one browser completion barrier -> canonical acceptance -> final render.
4. Mapping transaction owns target raw data / reshape / transformed data / choices / selected values until replay completion.
5. Browser completion is transport synchronization only. The browser does not semantically re-authorize canonical GraphState.
6. Delayed save candidates from another generation or from replay must not overwrite canonical state.
7. Dormant Graphs remain state-only. No hidden Graph UI/module may be created for Figure, Export, Shared Style, Project restore, deletion, or background work.
8. Live edits may update RenderState/revision, but Graph identity remains state, not module identity.
9. New Graph creation uses a deterministic canonical default template and must not inherit accidental live state from the previous Graph.

## Removed Graph architecture

Do not reintroduce any of the following as a compatibility path:

- `server_graph_materialization_runtime.R`;
- `graph_restore_runtime.R`;
- hidden per-Graph `graphUI()` / `graphServer()` modules;
- materialization queue / mount ACK / browser-drain lifecycle;
- `prepare_restore`, `load_state`, `sync_state`, `prepare_remount`, `remount` Graph APIs;
- old Mapping restore-binding semantic validation;
- semantic browser compare/reconcile;
- Graph restore retries;
- DOM remount seeds or remount render epochs;
- special fast/equivalent Graph-switch runtime.

Old Projects must be normalized into canonical state and opened through the current replay path.

## Current source boundaries

- Persistent Editor local primitives: `graph_editor_primitives_runtime.R`
- Graph live-state capture/commit: `graph_state_runtime.R`
- Mapping replay plan: `graph_mapping_replay_helpers.R`
- Mapping replay transaction: `graph_mapping_transaction_runtime.R`
- GraphState -> persistent Editor replay: `server_graph_state_replay_runtime.R`
- Render acceptance/revision: `graph_state_boundary_runtime.R`
- Persistent Editor ownership/switching: `server_graph_editor_runtime.R`
- Project package IO: `server_project_io_runtime.R`
- Direct Graph export: `server_graph_export_runtime.R` + `server_export_prepare_runtime.R`
- Figure Main/Inset direct-state snapshot service: `server_figure_source_snapshot_runtime.R`
- Figure workspace/render/export: `server_figure_workspace_runtime.R`, `figure_renderer.R`, `figure_export.R`
- Legend policy: `graph_legend_policy.R`
- Graph Settings Manager: `server_graph_settings_manager_runtime.R`, `server_graph_settings_value_runtime.R`, `server_graph_settings_batch_runtime.R`
- Shared semantic style state/transactions: `shared_style_state.R`, `server_shared_style_runtime.R`
- Statistics Analysis recipes/barrier: `graph_statistics_runtime.R`

## Figure invariants

Figure owns point-in-time snapshots and Figure-owned editable GraphState copies independently from source GraphState.

```text
GraphState / Figure-owned GraphState
  -> DIRECT-STATE server render
  -> Figure-owned Main / Legend / Inset snapshot
```

- Graph edits do not automatically mutate existing Figure snapshots.
- Explicit Graph -> Figure refresh is the synchronization boundary.
- Inset source selection may create the initial frozen snapshot; later refresh is explicit.
- Restored Inset SVG is preferred as the frozen WYSIWYG asset when available.
- A visible Figure Editor is presentation sync only; it is not a hidden batch-generation backend.

## Legend invariants

- Group guide visibility and individual-point guide visibility are independent GraphState fields.
- Group / individual guide merge is an explicit setting; title text must not implicitly decide merge/split behavior.
- Group and individual legend titles have independent text + visibility state.
- Both title visibility settings default OFF for new Graphs.
- When guides are merged, the group title is the common title.
- When guides are split, each guide uses its own title and explicit guide ordering.

## Settings / Shared Style invariants

- Graph-only -> canonical GraphState only.
- Figure-only -> Figure-owned state + DIRECT-STATE Figure snapshot only.
- Graph + Figure -> both independent paths.
- Dormant Graph Shared Style updates are canonical-only and replay on next visit.
- Settings Manager popout is presentation-only and owns no server state/module.

## Export invariants

- Visible persistent Editor owner may be published before export.
- Dormant Graphs export from canonical GraphState without activation.
- Figure export uses Figure-owned snapshots/state.
- Figure Inset export must use the same frozen SVG semantics as Viewer when an SVG snapshot exists.

## Project invariants

- Load Registry/Figure assets first, then attach only the selected Graph through normal replay.
- Save Graph canonical state; do not create new Graph SVG preview authority.
- Persist Figure Main/body/legend/Inset assets as Figure-owned state.
- Preserve Statistics recipes; results are regenerated.
- Mapping and legend settings must survive Project save/reopen without requiring hidden Editor materialization.

## Statistics exception

Statistics owns its separate `stats-restore-browser-barrier`. It prevents restore echoes from becoming recipe edits. It is not Graph canonical reconciliation and must stay isolated from Graph activation.

## Synchronization rule

Do not add lifecycle synchronization via sleep, polling, timers, MutationObserver, or repeated semantic browser comparison. Prefer one named state transaction with an existing event/flush/ACK boundary.

## Current Windows acceptance

v3.73.2.39 has been exercised on Windows with:

- old Project load;
- persistent Editor Graph switching across different column sets;
- Color / ID preservation across repeated Graph round-trips;
- Project save -> restart -> reopen;
- group/individual legend visibility;
- guide merge/split;
- independent group/individual title visibility and title text.

Future regression fixes must preserve these properties without reviving removed lifecycle machinery.
