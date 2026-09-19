## v3.73.2.34-github-clean1

- GitHub `main` / Release向けに配布ツリーを整理。
- `docs/` から旧版の静的監査JSON/CSV、関数索引、runtime split manifest等の機械生成物36ファイルを除外。
- `docs/` は現行の6文書だけに整理。
- `V33_CHANGE_NOTES.md` を `docs/CHANGE_HISTORY_ARCHIVE.md` に全文移し、現在版は `V34_CHANGE_NOTES.md` のみ単独保持。
- Graph / Figure / Statistics / Project / update-check の実行ロジックは変更なし。

## v3.73.2.33-doc-history-consolidation1

- Consolidate 90 historical/version-specific Markdown files into `docs/CHANGE_HISTORY_ARCHIVE.md` while preserving their full text and former source paths.
- Keep only current maintainer documents separate and rewrite the root README as a concise Japanese user guide.
- No application runtime behavior changed.

## v3.73.2.32-github-update-check1

- Add non-fatal GitHub Release update check to `run.bat` via `check_update.ps1`.
- Read current version from `app_config.R`; compare against `kaziklubey/ggplot-shiny-gui` latest Release.
- Newer release can be opened with `U`; Enter continues current app.
- Network/API/PowerShell failures never block Shiny startup.
- `GGPLOT_GUI_SKIP_UPDATE_CHECK=1` disables the check.

## v3.73.2.31-graph-settings-canonical-only1

Graph Settings Manager Graph writes are now canonical-only for dormant Graphs. They no longer launch hidden UI / graphServer materialization after a direct or batch parameter edit; the persistent Graph Editor replays the updated canonical GraphState only when that Graph is actually visited. This removes the `MATERIALIZE -> RenderState != canonical -> RESTORE-RETRY` loop seen after v30 multi-Graph edits. Figure-only/direct Figure updates and v30 Inset preservation remain unchanged. See [過去の詳細履歴](docs/CHANGE_HISTORY_ARCHIVE.md).

# v3.73.2.29-graph-settings-figure-edit1

- External Settings Manager now shows G (GraphState) and F (Figure-owned state) values separately.
- Added typed inline editing for titles, axis ranges, booleans, dimensions, legend/theme choices, font, point/line/bar/error sizes.
- Added explicit `Graphへ適用`, `Figureだけへ適用`, and `Graph + Figure` actions.
- Added `FigureをGraphから更新`, which rebuilds selected Figure main-panel snapshots through the existing direct GraphState snapshot service and does not use persisted SVG cache hits.
- Figure-only parameter writes modify Figure-owned GraphState/snapshot without changing canonical GraphState.
- Graph/Figure ownership remains separate; no automatic Graph→Figure sync was introduced.

# v3.73.2.28-graph-settings-batch1

External Graph Settings Manager now highlights cross-Graph differences, shows Shared Library binding status, supports multi-Graph target selection, and can copy one whitelisted display setting from a chosen source Graph to selected Graphs without changing Figure snapshots. See [過去の詳細履歴](docs/CHANGE_HISTORY_ARCHIVE.md).

# v3.73.2.27-graph-settings-popout-jump1

External Graph Settings Manager jumps now reliably return to the main Graph workspace and reveal the requested setting. See [過去の詳細履歴](docs/CHANGE_HISTORY_ARCHIVE.md).

# v3.73.2.26-graph-settings-popout1

Graph Settings Manager can now open as a separate browser companion window while keeping a single Shiny session, one GraphState registry, and one persistent Graph Editor. The popout is read-only: it receives the current comparison table from the main session and sends only navigation requests back to the opener.

# v3.73.2.25-graph-settings-manager1

Figureの共通設定に、全Graphの主要パラメータを横並び比較して該当Graph/入力欄へ直接移動できるGraph Settings Managerを追加しました。詳細は [過去の詳細履歴](docs/CHANGE_HISTORY_ARCHIVE.md)。

# v3.73.2.24-figure-legend-title-align-shared-style1

- Figure整列基準に `Axis＋凡例` を追加。通常の付随凡例をaxis bboxとの外接領域に含め、Auto/Fixed/Row個別基準で利用可能。Free legendはoverlayのため除外。
- `Graph title整列` を追加。同じRowのGraph titleをgtableのtitle bboxで検出し、Auto/Fixed Canvasの両方でタイトル上端を揃えられる。タイトル無しGraphは対象外。
- `共通Label / Style` を `共通Graph Label / Style` と明確化し、Library作成→Graph binding→Figure反映の3段階ガイドを追加。Panel label A/B/C の共通書式機能ではないこともUI上に明記。

# v3.73.2.23-figure-initial-panel-bootstrap1

- Fixed the initial Figure Panel 1 source (`r1_c1`) not materializing on first Figure open.
- Figure activation now queues a DIRECT-STATE snapshot only for occupied internal-Graph panels with no existing Figure-owned main snapshot.
- Existing live/persisted Figure snapshots are retained unchanged; automatic bootstrap never refreshes them from later Graph edits.
- Existing Figure-owned editable state is used when present; otherwise a READY Graph fast path or canonical GraphState direct build is used.
- Failed automatic first-view attempts are not retried on every tab visit; explicit Refresh/Bulk Import remains the retry boundary.

# v3.73.2.22-direct-state-figure1

Figure snapshots now build directly from GraphState, with the existing READY Graph fast path. See [過去の詳細履歴](docs/CHANGE_HISTORY_ARCHIVE.md) for scope and static validation.

# v3.73.2.21-value-replay-live-figure1

## v3.73.2.21-value-replay-live-figure1

- Fixed live Graph rendering after state-replay refactor: ordinary `project_settings()` changes now own a separate Plot revision observer, so a committed style/mapping/plot change immediately invalidates and redraws the live plot.
- Simplified normal Graph activation to value replay only. The replay ACK is the only browser completion barrier; there is no browser-state semantic readback, VERIFY-MISS, canonical reconcile, retry replay, or activation abort for a merely invalid plot configuration.
- Restored Wide→Long to the ordinary reactive path. Data/Mapping choice observers stay active; saved selections are temporary seeds so transient choice updates cannot replace loaded values with defaults. The destructive incompatible-wide auto-disable waits until replay completes, then re-evaluates normally.
- Reduced `ui_snapshot` to view-only state (`graph_main_tab`, `sticky_plot`, panel fold state). Data-dependent choices/visibility/enabled metadata are no longer duplicated in GraphState.
- Replaced Figure main/legend source materialization with one persistent Figure value-replay renderer.
- Replaced dormant Inset Graph materialization with the same Figure renderer while preserving separate Inset ownership; generating an Inset no longer overwrites a Figure-edited Main snapshot.
- Added serialized Figure source jobs with target revisions, Project reset cleanup, and reference-GC cancellation. Figure runtime contains no `request_graph_materialization()`/`graph_materialization_signal()` path.

# v3.73.2.20-style-state-migration1

## v3.73.2.20-style-state-migration1

- Fix legacy/current Graph activation aborts caused by deterministic dynamic Style defaults being materialized only in the live Editor. GraphState schema 4 now canonicalizes per-level color/shape/linetype defaults and nested `raw_group_colors` before replay.
- Normalize legacy colourInput-backed `mean_color_mode` to canonical `#RRGGBB` during schema migration so named/short colour representations do not force an unnecessary reconcile replay.
- Tighten RenderState semantics for Scatter: `raw_group_colors` is not a Scatter render dependency, and `mean_color_mode` is inactive while a Color Mapping is present. These dormant values no longer count as render mismatches.
- Add `graph_style_state_migration.R` as a focused pure migration layer; the replay/UI/default runtimes are not enlarged with style-compatibility logic.

- Normal Graph selection no longer applies the `client-editor-hydrating` mask or shows `Graph設定を同期中…`; the persistent Editor controls remain visible and only the stale live plot is masked until the target image is published.
- Old `.ggplotpack` GraphStates without `ui_snapshot` are migrated directly in R from canonical `data_text`, reshape, mapping and plot state. Prepared-data choice vectors are reconstructed without attaching/restoring the Editor.
- Project load therefore follows the same value-only replay path as ordinary Graph switching after startup.
- Normal Graph ownership changes no longer fall back to `load_state()` / structural restore. Replay verification misses are handed to one value-only canonical reconcile retry; persistent failure aborts safely instead of rebuilding the Editor DOM.


## Graph state replay

- Added `server_graph_state_replay_runtime.R` and made state replay the default path for ordinary Graph selection/revisit.
- Added `GraphState$ui_snapshot` for logical Editor state (selections, choices, visibility/enabled metadata and panel-open state); bumped GraphState schema to 3.
- Normal switching now commits the outgoing Graph, replays the target into the same persistent Editor, crosses one browser completion barrier, performs canonical/RenderState acceptance, and releases one live Plot render.
- The persistent Graph Editor is not structurally restored after bootstrap; legacy/incomplete GraphStates are normalized into replayable snapshots before attachment.
- Removed the v3.73.2.13 identity-only fast-switch runtime; equivalent and non-equivalent Graphs now use one ownership model.
- Removed unused dynamic Mapping/reshape `renderUI` paths that could recompute behind the fixed persistent Editor shell.

## Live Graph / snapshot ownership

- Removed Graph SVG preview caches from the ordinary Graph workspace and from new Project saves. The persistent live Plot is the Graph display surface.
- New `.ggplotpack` saves keep GraphState plus Figure-owned snapshots; no `preview/graph_*.svg` files are written. Legacy Graph preview assets remain read-only compatibility input only.
- Statistics Plot preview generates a temporary caller-owned SVG when requested. Figure Inset snapshot generation reads the source Graph directly and stores only the Figure-owned result.
- Duplicate copies canonical GraphState, not a Graph SVG asset.
- Figure snapshot ownership remains independent from later Graph changes.

## Browser completion / failure safety

- Added one live-render completion ACK after canonical acceptance; the listener is armed before the render gate opens so a pre-render invalidation cannot consume the transaction.
- Browser completion accepts both Shiny output event target IDs and event names and resolves plot-output errors without leaving Graph selection locked.
- Graph activation failure clears the stale Editor shell instead of claiming to fall back to a cached Preview.
- No timers, polling, per-Graph Editor DOM/modules, warm DOM switching, or source-order override were introduced.

## Validation

- Static release audit covers JavaScript syntax, R source/delimiter integrity, internal source targets, removed cache/fast-switch symbols, merge markers and archive contents.
- R/Rscript is unavailable in the packaging environment; Windows Shiny runtime acceptance remains required.

# v3.73.2.13-fast-equivalent-switch1

- Added a strict equivalent-state Graph switch fast path. When the current singleton Editor state, target canonical GraphState, rendered RenderState, and fresh Preview all match, Graph identity is retargeted without Editor restore, Preview ACK handshake, Shiny live-holder unbind/rebind, or `renderPlot`.
- The fast path preserves canonical revision leases and outgoing live state, adopts the equivalent target attachment without creating a pending render, and clones/reuses the already-current Preview record. Any failed safety condition falls through to the existing transaction unchanged.
- Added `GRAPH-SINGLE-FAST-PATH` / `GRAPH-SINGLE-FAST-MISS` diagnostics so Windows logs show whether a switch was skipped or why it used the ordinary path.
- Built-in sample line GraphState now keeps `mapping.id` empty, matching the actual UI default and removing the immediate ID -> empty canonical commit after startup.
- No timers/polling, per-Graph Editor modules, Statistics changes, or Figure reorder changes.

# v3.73.2.12-sample-template1


## Canonical built-in sample GraphState

- New Graph no longer depends on browser-selected Mapping values to define its initial state.
- The sample dataset is defined once by `graph_sample_data_text()` and used by both UI and GraphState.
- `graph_sample_graph_state()` derives deterministic sample Mapping from the data (`Group` / `Post`, `ID`).
- g001 and every New Graph receive a deep copy of the same sample template; Duplicate still copies its source GraphState.
- The persistent Editor is a consumer/editor of canonical GraphState, not the creator of New Graph Mapping defaults.

- Fixed the new-Graph default capture boundary: the write-once default is no longer captured at `moduleServer` return before Mapping defaults settle.
- `startup-post-bind` is now the authoritative initial default capture.
- Removed the redundant first-Graph READY promotion path; normal canonical arbitration remains the only acceptance flow.
- Added X/Y diagnostics to default capture/finalize and Preview mismatch logging.

# v3.73.2.10-accept-boundary1

- Restored `graphServer$ready()` to the staged-restore contract. READY no longer requires a second full live `project_settings()` snapshot after binding/finalization.
- Added one explicit outer-acceptance handoff: `accept_canonical()` / `graph_accept_attached_canonical()`. The accepted Registry GraphState refreshes both `attached_state_seed` and the pending render target before `render_gate` opens.
- Fixes the startup g001 case where canonical Mapping X/Y was finalized from the live UI but the first render still consumed the older pristine attachment.
- Fixes new Graphs stalling after internal restore READY because the second full-state live snapshot never became readable.
- No timers/polling added. Statistics and Figure reorder runtimes are unchanged.

# v3.73.2.9-live-ready-default1

- Strengthened Graph module READY: READY now requires a genuinely readable live `project_settings()` snapshot, not only completed restore flags.
- The first startup Graph promotes that browser-backed pristine state into canonical g001 and the reusable new-Graph default template.
- RenderState now collapses dormant Wide→Long fields while reshape is OFF.
- Preview mismatch diagnostics now report exact RenderState paths.
- No new timers/polling or per-Graph Editor/cache paths.

# v3.73.2.8-source-cleanup1

- Removed the unreachable alpha-era Figure -> Graph UI-input commit transaction from `graph_module.R`; current Figure Apply remains the server-level canonical Registry transaction.
- Removed dead graphServer API wrappers with zero current callers (`apply_figure_patch`, Figure commit status/finalizers, `raw_data`, `plot_source_data`, `drawn`, and transitional `load_state_direct`).
- Fixed the live Plot publication crash by recording `plot_last_built_render_state()` directly instead of calling the deleted `graph_completed_render_state_snapshot()`.
- Fixed the stale Figure helper call `figure_source_at_key()` -> `figure_layout_source_at_key()`.
- Corrected Editor-first / attached-canonical comments and current architecture documentation.
- Extended static release audit with unresolved project-internal call detection so deleted-function callers cannot silently pass packaging checks again.

---

# v3.73.2.7-simple-render-contract1

- Removed the second post-READY browser bootstrap gate. Once the outer persistent-Editor transaction accepts canonical RenderState and opens the render gate, the already-attached canonical target is released exactly once.
- Split the pure render contract out of `app_state_diff.R` into `graph_render_state.R`.
- RenderState now collapses inactive external-error Mapping controls. Hidden populated selectInputs no longer block READY when `external_error_mode` cannot affect the current Plot.
- Removed `graph_render_bootstrap_runtime.R` and the whole-state `graph_normalize_new_graph_state()` path. New Graphs use the finalized singleton-Editor default GraphState directly.
- Renamed the remaining shared UI default helper file to `graph_data_defaults.R`; it contains only pure Data/Mapping default selection helpers.
- No timers/polling, per-Graph Editor DOM/module, Statistics behavior, Figure ownership, or Preview ACK protocol were added or changed.

# v3.73.2.6-new-graph-bootstrap1

- Fixed genuinely new Graphs remaining permanently blank at `READY waiting for live browser GraphState`; copies of such Graphs no longer inherit that non-rendering state.
- Added `graph_new_graph_defaults.R` with pure default-selection functions shared by Graph UI normalization and new-Graph canonical GraphState creation.
- A new Graph is normalized before Registry commit, including deterministic reshape columns and Mapping defaults, so canonical state is not born one browser normalization step behind its own Editor UI.
- Added `graph_render_bootstrap_runtime.R`: when full `project_settings()` is temporarily blocked by unrelated Shiny control-flow, the first render may release only after core Data/Reshape/Mapping/Plot browser controls match the already-accepted canonical target.
- Existing loaded/duplicated GraphState is never passed through new-Graph normalization.
- Reduced duplicate default-selection logic in `graph_data_runtime.R`; observers remain wiring over shared pure defaults.
- No per-Graph Editor DOM/module/live-plot cache, timer, polling, Statistics changes, Figure snapshot changes, or Figure reorder changes.

# v3.73.2.5-render-state-boundary-refactor1

- Refactored Graph state ownership into `graph_state_boundary_runtime.R`: READY arbitration may use the one attached canonical fallback, while Plot revision accepts live browser state only.
- New Graph/Graph switch transactions now seed their semantic Plot target from the canonical GraphState without treating that canonical snapshot as a drawable browser state.
- Moved semantic Plot-revision arbitration out of `graph_state_runtime.R` into a dedicated installer function; persistence/runtime wiring stays separate.
- Added `graph_render_error_runtime.R`: Shiny `validate()` / `req()` control-flow conditions are no longer converted into blank `Plot error` graphics. Genuine R errors still get a visible diagnostic Plot and class-aware log.
- Completed renders are tagged with the released semantic RenderState rather than re-reading dynamic browser inputs after drawing.
- The attached safety snapshot is refreshed only after a successful canonical commit, not by ordinary live reads.
- No per-Graph Editor DOM/module/state cache, polling, timer, or Statistics/Figure reorder changes.

# v3.73.2.4-graph-state-snapshot-fallback1

- Fixed newly-created Graph activation repeatedly aborting with `GRAPH-SINGLE-STATE-DIFF paths={<missing-state>}` after an otherwise completed cold hydrate.
- The one persistent Graph Editor now retains exactly one attached canonical GraphState safety snapshot; this is not a per-Graph Editor/cache.
- `module_api$state()` and Plot semantic-revision arbitration fall back to that attached state only when browser-backed `project_settings()` is temporarily unavailable during dynamic UI replacement.
- Successful live state commits refresh the safety snapshot, so later Graph switches do not fall back to stale startup state.
- Canonical reconcile remains bounded; no retry-count increase, timer, polling, warm DOM, or per-Graph module was added.
- Figure legend single-paint/materializer behavior from v3.73.2.3 is unchanged.

# v3.73.2.2-figure-legend-materializer1

## Fixed

- Figure legend override changes now materialize the Figure-owned Graph snapshot when only a persisted SVG is available, so side/none/free changes can rebuild real SVG content instead of only changing geometry.
- Rapid legend changes coalesce by Graph ID while the one hidden materializer is loading; completion renders the latest requested override.
- Materializer stability uses render-state equality rather than full GraphState equality and has a bounded single reload, avoiding repeated hydrate/reload loops.
- `FIGURE-LAYER` diagnostics are invalidated by legend mode/source and Figure plot/snapshot revisions.

## Preserved contracts

- Figure remains snapshot-owned; current Graph edits do not auto-refresh Figure content.
- One reusable materializer is shared by all Figure Graphs; no per-Graph editor modules, timers, or polling were added.
- Figure reorder, ownership guards, Statistics runtime, and persistent main Graph editor were not changed.

# v3.73.2-figure-control-surface1

- Removed the user-facing Advanced Figure accordion and returned Canvas/Auto-fit/Preview controls to their workflow owners.
- Reorganized Step 2 into compact Canvas and Layout cards, with Row/Panel and reorder subsections to reduce visual density.
- Added selected-Panel free-placement reset without resetting Graph order, Crop, style or content.
- Hardened detached/free legend extraction for compound guide boxes and added a fail-safe that preserves an attached legend if detachment cannot be materialized.
- Clarified Fixed Canvas Panel-gap semantics; Fixed gap changes slot allocation inside the fixed outer Canvas.

# v3.73.1.7-figure-ui-overflow-guard1

- Fixes Figure workflow controls that existed in the DOM but were visually cut off by the legacy `.figure-config-section { overflow: hidden; }` card chrome. Open Figure configuration sections now allow floating menus to escape their card; clipping/scrolling remains owned only by dedicated panes such as the Figure drawer body and plot viewport.
- Raises the currently focused Figure configuration section above later sibling sections and gives selectize/Bootstrap menus an explicit floating z-order, preventing the following `共通Label / Style` block from painting over an open menu.
- Changes the Step 2 `移動/交換先` chooser to a native select (`selectize=FALSE`). This control is a bounded slot list and does not need a search widget; native rendering avoids the avoidable floating-menu dependency entirely.
- No Figure reorder ownership/state logic, geometry, free-legend fix, Statistics calculation/restore, Graph Editor, materialization, timer/polling, or project schema changes.

# v3.73.1.6-figure-layout-reorder-stability1

- Moves Figure Graph reorder controls out of the selected-Panel inspector and back into workflow Step 2 `配置・整列`, while preserving the established input ids for adjacent arrows, Shift insert, Swap and one-level Undo. Adds an explicit `Graph順にリセット` action.
- Hardens every Row/Grid reorder as a validated content transaction: Slot-owned state (Panel label, cell width/free frame/z-order/row-col identity) must remain unchanged, while Graph/Asset identity plus Figure Graph width/height must be preserved exactly as a multiset. Invalid transitions are rejected before commit.
- Selection now follows the moved Graph/Asset across Shift/Swap/arrow moves, including cross-Row moves. `selected_panel`, `selected_graph`, selected Row, Inspector generation and browser highlight are synchronized to the destination; Undo restores the prior selection.
- Keeps automatic Panel labels strictly slot-owned even when Shift passes through blank cells; newly occupied blank slots derive their auto label from the slot ordinal, preventing duplicate A/B/C-style labels after reorder.
- Adds a slot-owner guard to Figure cell/Inset/free-legend/label render paths so a delayed output closure from a previous owner cannot repaint a slot after reorder. A post-flush reorder verifier logs logical/requested layout and selection agreement without timers/polling.
- Adds a Figure-wide vertical placement helper in Step 2 (`上/中央/下` + top gutter, apply to all Panels). New Figure cells use a more compact 32 px label gutter; restored authored projects retain their saved gutter/alignment until explicitly changed.
- Fixes the bottom-edge clipping of Advanced Figure select menus by allowing the Advanced section to overflow and increasing final workspace bottom room.
- Expands Statistics `Analysis settings` to a taller scroll region and removes its horizontal overflow caused by nested Bootstrap row margins.
- No change to GraphState ownership, Figure snapshot ownership, materialization, Statistics calculation/restore semantics, or timer/polling cadence.

# v3.73.1.5-figure-free-legend-footprint1

- Fixes excess Figure whitespace for Graphs whose legend is in Figure `free` mode. A detached/free legend is now outside the Row common legend-slot cohort in both directions: it neither contributes a slot nor receives padding reserved for another Graph's attached legend.
- Uses persisted `body_meta` as the owner-Graph geometry for detached/free Figure previews when live gtable measurement is unavailable (project bootstrap/dormant/persisted-SVG paths). Source legend bboxes are mapped into the body coordinate system only for overlay placement.
- Preserves attached-legend alignment: Graphs with an attached legend and legend-less non-free Graphs in the same Row still share the existing common legend slot, so Plot/Axis alignment for ordinary legends is unchanged.
- Fixed Canvas remains fixed-size; this change removes the asymmetric free-legend reservation inside a cell, while any remaining cell whitespace is the intentional consequence of the fixed canvas/slot dimensions. Auto Canvas now sizes the free owner body without the old source-side legend strip and expands only if the actual free legend overlay lies outside the content bbox.
- No Figure snapshot ownership, Inset geometry, Statistics, Graph Editor, materialization, timer/polling, or JavaScript handler changes.

# v3.73.1.4-statistics-plot-above-analysis1

- Repositions the dedicated Statistics Plot from the main Plot/Result reading grid into the Statistics control column, directly above the Analysis selector and Analysis settings. The intended reading flow is now Plot -> Analysis setup on the left, with Result retaining the full main-panel width on the right.
- Keeps the same read-only `stats_plot_preview` SVG/cache path introduced in v3.73.1.3. No Statistics calculation, recipe restore/baseline, Global Preview ACK/visibility, GraphState, Figure, or materialization logic changes.
- Moves the existing Analysis selector into the same left control column without changing its input id, and slightly reduces the Analysis-settings internal scroll height so Plot + controls remain usable within the sticky Statistics sidebar.
- No new editor, JavaScript handler, timer, polling loop, or background materialization path.

# v3.73.1.3-statistics-plot-preview1

- Restores an in-Statistics Plot view for interpreting test results. The Plot is not a tiny identity thumbnail: it is a full reading aid placed beside Result so the statistical output can be read against the actual graph.
- The Statistics Plot is a dedicated read-only SVG surface backed by the existing Graph preview cache. It does not reveal, move, or reparent the live Global Plot Preview and therefore does not undo the v3.73.1.1 workspace Preview-tab guard.
- The Statistics reading area uses a Plot/Result two-column layout on wide screens, keeps the Plot sticky while reading results, and stacks vertically on narrower windows.
- Graph changes while Statistics is open update the Statistics Plot from the newly selected Graph preview record; no second Graph editor, background warm DOM, timer/polling path, or new JavaScript handler is introduced.

# v3.73.1.2-statistics-post-restore-baseline1

- Fixes the remaining one-shot `STATS-RECIPE-COMMIT` seen after a stable Analysis restore when a dynamic Statistics control displayed an inferred/default value that intentionally differed from an empty saved recipe field (observed for `anova_id`).
- Adds a transient post-restore Statistics baseline separate from the canonical recipe. After the existing bounded browser barrier reaches a stable snapshot, that exact UI snapshot is treated as restore presentation state rather than a user edit.
- The generic recipe save path ignores the unchanged post-restore baseline; the first input state that differs from that baseline resumes normal semantic compare/commit behavior. Project serialization uses the same guard so an untouched inferred UI default is not silently persisted.
- The baseline is cleared on Analysis load/delete and whenever GraphState restores/replaces Statistics recipes. No timer, polling loop, debounce, new browser handler, Preview, Figure, GraphState schema, or Statistics result calculation change was added.

# v3.73.1.1-workspace-preview-tab-guard1

- Fixes the v3.73.1 regression where the singleton Plot Preview could reappear over Statistics/Data/Comment after switching back to a Graph that had previously been on Plot.
- Makes Graph section ownership explicitly workspace-global: Plot / Statistics / Data View / 製作者コメント now remain the single source of truth across Graph changes.
- Removes per-Graph Preview-tab history from target-switch visibility decisions. Cached and live Plot layers stay hidden on every non-Plot section, including during Graph auto-hydration and Preview target replacement.
- No GraphState, Statistics recipe, Figure, materialization, timer/polling, or Preview ACK protocol changes.

# v3.73.1-editor-workspace-decoupling1

- Restores **Editor-first** Graph workflow: ordinary Graph selection and Project open now auto-hydrate the one persistent Graph Editor; the top-level `編集` button is removed.
- Moves Plot / Statistics / Data View / 製作者コメント navigation to a stable workspace section bar outside the hydration mask, preserves that section across Graph switches, and removes unrelated Plot controls from Data View / comment.
- Adds a latest-target Graph selection queue so rapid switches cannot interrupt HYDRATING/SYNC and publish a partially restored GraphState.
- Project open still stages cached SVG first, then automatically attaches the selected Editor through the existing cached/live/auth ACK handshake.
- Adds **Projectを閉じる** with confirmation. Close is a hard session boundary and returns to pristine Graph 1, preventing Graph/Figure/Shared-Library/editor lease leakage.
- No timer/polling synchronization was added; failure-only cached-preview fallback remains available.

# v3.73.0-figure-workflow-shared-style1

- Promoted the post-v3.72.27 hotfix line to the v3.73 feature line. Figure is reorganized around the actual publication workflow: **Import → Layout / alignment → Shared Label / Style → Individual adjustment → Export**, with lower-frequency canvas/update/preview controls moved under Advanced. Existing Figure geometry input ids and runtime algorithms are retained rather than rewritten.
- Added a project-level **Shared Label / Style Library** with explicit semantic items (`level`, `axis_label`, `legend_title`). Internal semantic id and display text are separate; Graph bindings are explicit user choices only. There is no name-based automatic binding.
- Added per-Graph Shared Library binding metadata and opt-in attribute control for display label, Color/Fill, Shape and Line type. Library values are materialized into ordinary GraphState style/label fields; binding metadata itself is excluded from RenderState so only concrete appearance changes trigger rendering.
- Linked Graph edits can write level/legend/style changes back through the central Library. Graphs never message each other directly: the central server transaction updates canonical GraphState only for affected linked Graphs and schedules only those Graphs for read-only materialization. Background materializers and the Figure editor do not receive a writable Library callback.
- Added Figure Shared Style controls. Figure Library auto-sync is **OFF by default**; `今すぐFigureへ反映` performs an explicit semantic apply. Figure Data, Mapping and geometry remain snapshot-owned. The apply resolves only semantic binding metadata from the current source Graph, then rebuilds affected Figure snapshots sequentially through the existing single Figure Editor.
- Hardened the Figure Shared Style batch: the current live Figure state is captured before external semantic mutation, the reusable Figure editor is force-reloaded and bounded-settled before every snapshot, stale READY state is never snapshotted, and a settle failure aborts the batch rather than leaving a background queue active. No timer or polling loop was added.
- Added Shared Library JSON Import/Export. Portable files contain Library definitions only; per-Graph bindings remain Project-specific. Project save/load now persists the Library, Graph bindings and Figure sync opt-in while old Projects load with an empty Library and sync disabled.
- Shared binding metadata is Project-owned and intentionally excluded from generic Graph style export/copy-paste. Figure→Graph Apply preserves the source Graph's current binding instead of copying potentially stale Figure metadata back upstream.
- Linked Graph write-through is conflict-safe: when one semantic item is bound to multiple values in the same Graph, the Library is updated only when all observed edits imply one unambiguous new value. Binding-only metadata commits do not trigger Graph materialization or Figure snapshot rebuilds.
- Legacy v3.72 GraphState and saved Figure editable states are normalized once at Project-load boundaries to an explicit empty Shared Library binding, preventing false canonical/editor diffs when opening old Projects.

# v3.72.27.6-statistics-restore-context1

- Fixed the v3.72.27.5 Windows crash during Statistics restore settling: `stats_restore_input_snapshot()` was invoked from `session$onFlushed()` and called `stats_capture_recipe_from_inputs()`, which read `input$stats_name` and related reactive inputs outside a reactive consumer.
- The whole snapshot read is now wrapped in `isolate({ ... })`, so the bounded restore-settle handshake can safely sample browser-returned Statistics inputs from the post-flush callback without creating reactive dependencies.
- No restore timing, barrier protocol, recipe schema, active-type capture behavior, Result calculation, Plot/Figure ownership, timer/polling path, or client handler was changed.

# v3.72.27.5-statistics-restore-settle1

- Finished the residual Statistics Analysis-switch cleanup seen in the v3.72.27.4 Windows log. The first browser barrier removed most restore echoes, but one dynamically rebuilt mapping input could still bind after the barrier and create one recipe commit.
- Statistics restore now uses the existing browser barrier as a bounded value-stability handshake: while `stats_restoring == TRUE`, the active Analysis input snapshot is compared after each ACK flush and the guard is released only after two consecutive browser round-trips produce the same canonical snapshot (maximum four attempts). No timer, sleep, debounce, polling loop, MutationObserver, or new JavaScript handler was added.
- Recipe capture is now type-scoped. ANOVA saves only ANOVA-specific mappings, t-test saves only t-test mappings, and correlation saves only correlation mappings. Hidden/dormant analysis-type controls can therefore no longer auto-select browser defaults and leak them into another analysis type. Common Analysis fields and Analysis-local transform fields remain shared.
- Existing result rendering, Raw Dataset + Analysis-local preparation, persistent Graph Editor, Preview handshake, Figure snapshots/materialization, and Project save/reload semantics are unchanged.
- Added `attempt=` / `settling` / `stable=` detail to `STATS-RESTORE-BARRIER` diagnostics for Windows verification.

# v3.72.27.4-statistics-switch-echo-guard1

- Fixed the residual burst of `STATS-SAVE` / `STATS-RECIPE-COMMIT` events immediately after switching Analysis. The saved recipe was restored correctly, but `stats_restoring` was released on the server before the final `update*Input()` batch had completed its browser → Shiny round trip, so restore echoes could be mistaken for user edits.
- Analysis restore now reuses the existing `graph-editor-reconcile-barrier` browser round-trip handler. After the two dynamic-control restore phases, Statistics requests a namespaced barrier ACK and keeps `stats_restoring == TRUE` until the ACK flush has fully completed.
- The generic Statistics save observer therefore ignores all restore echoes in that ACK flush. Releasing the guard is performed in `session$onFlushed()` and does not itself schedule a save because the save boundary reads `stats_restoring()` through `isolate()`.
- No new JavaScript handler, polling loop, timer, debounce, MutationObserver, warm DOM/LRU path, or background Editor path was added. Normal user edits and the existing 180 ms Result debounce are unchanged.
- v3.72.27.3 result rendering remains intact; `STATS-RESTORE-BARRIER requested/acked/released` diagnostics were added for Windows verification.

# v3.72.27.3-statistics-result-stability1

- Fixed the remaining Statistics reactive loop observed in v3.72.27.2. The Analysis transform reactive still depended on `stats_recipes()` during normal editing, so each recipe commit invalidated `stats_source_data()`, rebuilt dynamic Statistics mapping UI, re-emitted browser inputs and committed again.
- `stats_transform_recipe()` now reads the saved Analysis recipe reactively only during guarded recipe restore. During normal editing the browser inputs are authoritative and the saved recipe is an isolated fallback only. This breaks the `recipe commit -> source data -> dynamic UI -> input echo -> recipe commit` cycle without adding timers or suppressing real edits.
- This same loop was starving the 180 ms debounced `stats_result` calculation, leaving the Result panel blank. Once the dynamic UI stops self-invalidating, ANOVA / t-test / correlation output can settle and render normally.
- Added a `STATS-RESULT` diagnostic showing analysis type and rendered character count for Windows runtime verification.
- v3.72.27.2 semantic recipe equality guards remain in place. Raw Dataset + Analysis-local preparation, Plot/Data View ownership, persistent Graph Editor, Preview ACK/render-gate flow, Figure snapshot ownership and materialization behavior are unchanged.
- No polling, timer, warm DOM/LRU, or background Editor path was added.

# v3.72.27.2-statistics-recipe-stability1

- Fixed a Statistics recipe save loop observed after opening/switching Analysis in v3.72.27.1. `save_current_stats_recipe()` previously rewrote `stats_recipes()` even when the captured Analysis recipe was semantically unchanged; that invalidated dynamic Statistics UI, browser inputs re-fired, and the recipe collection was written again.
- The selected recipe is now normalized on both sides and committed only when the canonical recipe actually changes. Real user edits still update `stats_recipes()` and GraphState; identical UI echo events are ignored.
- The Analysis-name observer now also skips identical-name writes.
- Legacy Statistics migration, Raw Dataset + Analysis-local preparation, Plot/Data View ownership, persistent Graph Editor, Preview ACK/render-gate flow, Figure snapshot ownership, and materialization behavior are unchanged.
- No polling, timer, warm DOM/LRU, or background Editor path was added.

# v3.72.27.1-data-transform-boot-guard1

- Fixed the v3.72.27 startup infinite recursion. The new transform-only `plot_data` reactive collided with the longstanding prepared-data `plot_data` reactive because both runtime files are sourced into the same `graphServer` environment. The resulting dependency was `dat() -> plot_data() -> dat()`, preventing pristine default-state capture.
- Renamed the transform-only boundary to `plot_source_data()`. `dat()` now delegates to that explicit boundary, while the existing prepared `plot_data()` remains unchanged.
- Data View now explicitly reads `plot_source_data()`, preserving the pre-v3.72.27 `dat()` semantics: original Graph data plus Plot-owned Wide→Long, before Mapping-specific preparation.
- Hardened transform recipe normalization for startup `NULL`, zero-length, blank and `NA` values.
- Added a release audit for duplicate local bindings across the runtime files sourced into one `graphServer` environment, so future source-split name collisions are detected statically.
- No polling/timer path, warm DOM/LRU path, Preview handshake change, Figure ownership change, or Statistics/Plot recoupling was introduced.

# v3.72.27-statistics-rawdata-recipe1

- Statistics now starts from the original Graph dataset rather than Plot-transformed `dat()`. Plot Mapping/Style and Plot Wide→Long are outside the Statistics data boundary.
- Each saved Analysis owns an independent Data preparation recipe. New analyses default to `as-is`; an Analysis can optionally apply its own Wide→Long (`columns`, `RowID`, `names_to`, `values_to`).
- Legacy analyses without an explicit transform are migrated once: if they historically depended on a saved Plot Wide→Long, that transform is copied into the Analysis recipe so old Projects retain their previous analysis input table without future coupling to Plot settings.
- Plot Wide→Long now uses the shared pure transform engine in `graph_data_transform.R`; Data View explicitly shows `plot_data()` (the data actually supplied to the Plot).
- Statistics runtime was separated from `graph_restore_runtime.R` into `graph_statistics_runtime.R`. Analysis input capture and restore are decomposed into named helpers; duplicated Project-save/Analysis-save capture logic was removed.
- Statistics no longer renders the Plot reference image or consults Plot Mapping for ANOVA variable suggestions.
- Figure → Graph Apply preserves `statistics_recipes`; Figure editing owns Plot GraphState fields only.
- Fixed singleton Preview overlap on Statistics / Data View / 製作者コメント. Persistent Editor tab events now resolve `graph_editor_single` to the actual editing Graph before applying Preview visibility; any non-Plot main tab hides the singleton Preview immediately.

# v3.72.26-reconcile-browser-barrier1

- Fixes a false Graph Editor activation abort after Figure → Graph Apply. `sync_state()` could send fixed-input updates (for example `plot.connect_id` and `style.appearance.error_width`) and reach READY before those browser values had completed the browser → Shiny-server round trip.
- Canonical reconcile retry now crosses one explicit generation-scoped browser barrier before the second RenderState comparison. The barrier uses `requestAnimationFrame` + Shiny ACK only; no timer, polling, MutationObserver, or sleep was added.
- The first reconcile retry no longer forces an immediate settle tick. `sync_state()` must complete its normal READY transition, then the browser barrier ACK schedules canonical arbitration.
- Barrier state is cleared on Graph switch, STALE invalidation, successful acceptance, and activation abort so stale ACKs cannot affect another Graph/generation.
- Figure Apply semantics remain unchanged: canonical GraphState is committed, old Graph preview is invalidated, and the new Graph preview is generated before Apply completion.

# v3.72.25-restore-ack-fallthrough1

- Fixed a restore deadlock introduced by the v3.72.24 event-driven binding path.
- `RESHAPE-PARENT` and `RESHAPE-BIND` no longer return immediately after a successful browser ACK. They validate the corresponding Shiny input values in the same reactive execution.
- When browser preseed and server input already match, restore advances immediately without waiting for an input change that will never occur.
- When a client update is still required, the same-pass input reads establish the reactive dependencies needed for the real Shiny input event to resume restore.
- No polling/timer fallback was reintroduced.

# v3.72.24-editor-hydrate-fastpath1

- New Graphs are initialized from one captured canonical default GraphState before Editor activation; transient UI values no longer manufacture the new Graph's canonical state.
- Fixed the new-Graph permanent `Graph設定を同期中…` mask: READY no longer waits for repeated whole-GraphState equality. After one Shiny flush, the Editor is accepted against canonical RenderState and the existing Preview ACK transaction continues.
- Added a fail-safe activation abort. If canonical RenderState still cannot reconcile after the existing one retry, the render gate is reopened, the hydration mask is cleared, and the selected Graph returns to cached-preview browse instead of leaving the UI locked.
- Replaced the 50 ms browser polling used by RESHAPE/MAPPING binding checks with generation-scoped `shiny:bound` / `shiny:unbound` / `shiny:inputchanged` events plus one coalesced `requestAnimationFrame` inspection.
- Removed the three 75 ms `invalidateLater()` restore loops. Restore progression is now driven by Shiny input/reactive changes and browser binding ACK events.
- Persistent Editor restore skips the RESHAPE parent binding ACK when the already-mounted parent controls already match the canonical state.
- `shape` / `linetype` transient `<NULL>` is treated as the semantic `__color__` default only after the Mapping browser generation has been ACKed, avoiding an unnecessary new-Graph resync.
- Persistent dynamic-style restore no longer adds an extra whole-server flush after canonical reassertion; generation-scoped dynamic input IDs and the outer loading guard remain the safety boundary.
- The v3.72.23 materialization encapsulation, v3.72.18 Figure Apply Graph-preview generation, and v3.72.16 full-screen hydration overlay are otherwise retained.
