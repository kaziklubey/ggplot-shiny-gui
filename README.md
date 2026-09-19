## v3.73.2.32-github-update-check1

Startup can now check `https://github.com/kaziklubey/ggplot-shiny-gui` GitHub Releases before launching Shiny. The check is best-effort only: offline/API failures do not prevent startup. If a newer release exists, press `U` to open its Release page or Enter to continue the installed version. Set `GGPLOT_GUI_SKIP_UPDATE_CHECK=1` to skip the check.

### Previous baseline: v3.73.2.31-graph-settings-canonical-only1
Graph Settings Manager Graph writes are now canonical-only for dormant Graphs. They no longer launch hidden UI / graphServer materialization after a direct or batch parameter edit; the persistent Graph Editor replays the updated canonical GraphState only when that Graph is actually visited. This removes the `MATERIALIZE -> RenderState != canonical -> RESTORE-RETRY` loop seen after v30 multi-Graph edits. Figure-only/direct Figure updates and v30 Inset preservation remain unchanged. See [V31_CHANGE_NOTES.md](V31_CHANGE_NOTES.md).

# v3.73.2.29-graph-settings-figure-edit1

External Graph Settings Manager now mirrors **Graph (G)** and **Figure-owned (F)** values side by side. Editable scalar settings can be changed directly in the popout and explicitly applied to Graph only, Figure only, or both. A separate **FigureをGraphから更新** action rebuilds selected Figure main-panel snapshots directly from canonical GraphState, bypassing persisted SVG caches. Figure remains snapshot-owned; no automatic Graph→Figure following was added.

# v3.73.2.28-graph-settings-batch1

External Graph Settings Manager now highlights cross-Graph differences, shows Shared Library binding status, supports multi-Graph target selection, and can copy one whitelisted display setting from a chosen source Graph to selected Graphs without changing Figure snapshots. See [V28_CHANGE_NOTES.md](V28_CHANGE_NOTES.md).

# v3.73.2.27-graph-settings-popout-jump1

External Graph Settings Manager jumps now reliably return to the main Graph workspace and reveal the requested setting. See [V27_CHANGE_NOTES.md](V27_CHANGE_NOTES.md).

# v3.73.2.26-graph-settings-popout1

Graph Settings Manager can now open as a separate browser companion window while keeping a single Shiny session, one GraphState registry, and one persistent Graph Editor. The popout is read-only: it receives the current comparison table from the main session and sends only navigation requests back to the opener.

# v3.73.2.25-graph-settings-manager1

Figureの共通設定に、全Graphの主要パラメータを横並び比較して該当Graph/入力欄へ直接移動できるGraph Settings Managerを追加しました。詳細は [V25_CHANGE_NOTES.md](V25_CHANGE_NOTES.md)。

# v3.73.2.24-figure-legend-title-align-shared-style1

- Figure整列基準に `Axis＋凡例` を追加。通常の付随凡例をaxis bboxとの外接領域に含め、Auto/Fixed/Row個別基準で利用可能。Free legendはoverlayのため除外。
- `Graph title整列` を追加。同じRowのGraph titleをgtableのtitle bboxで検出し、Auto/Fixed Canvasの両方でタイトル上端を揃えられる。タイトル無しGraphは対象外。
- `共通Label / Style` を `共通Graph Label / Style` と明確化し、Library作成→Graph binding→Figure反映の3段階ガイドを追加。Panel label A/B/C の共通書式機能ではないこともUI上に明記。

# v3.73.2.23-figure-initial-panel-bootstrap1

## v3.73.2.23 Figure initial panel bootstrap

The Figure workspace now materializes only occupied main panels that already have a source Graph but do not yet own a Figure snapshot. This fixes the initial auto-filled Panel 1 remaining blank until another Row/Panel or bulk import triggered source loading. Existing in-session or persisted Figure snapshots are never refreshed by this bootstrap.


Figure snapshots now build directly from GraphState, with the existing READY Graph fast path. See [V22_CHANGE_NOTES.md](V22_CHANGE_NOTES.md) for scope and static validation.

# v3.73.2.21-value-replay-live-figure1

## v3.73.2.21 Value replay / live render / Figure source refactor

This build completes the value-only persistent-UI direction for ordinary Graph and Figure workflows.

- One Graph Editor UI/module is created at startup; Graph and Project loads overwrite its saved values and use the normal reactive UI chain.
- Normal Graph load no longer reads browser state back for semantic equality, retries replay, or performs canonical reconcile. Invalid plot settings are allowed to reach the existing Plot error surface.
- Live Graph edits now invalidate the Plot revision independently from attach transactions, fixing the regression where GraphState committed but the rendered plot did not change.
- Wide→Long and Mapping choice observers remain active during value replay. Saved Mapping/reshape selections are held only as short-lived seeds while choices change, then ordinary reactive behavior resumes.
- `ui_snapshot` now owns only manual UI presentation state (tab/sticky/panel folds); Mapping/plot/style values remain single-owned by GraphState, and conditional visibility/choices are derived by the persistent UI.
- Figure main snapshots, legend regeneration, and Inset refreshes reuse one persistent Figure renderer. Figure runtime no longer creates per-Graph hidden UI/modules or calls Graph materialization/restore for those paths.
- Figure source jobs are serialized, generation/revision tracked, reset on Project replacement, and cancelled when the final Figure reference is removed.

This build replaces the ordinary Graph-switch restore/Preview transaction with GraphState replay into the one persistent Editor. Each canonical GraphState now carries a logical `ui_snapshot` (selections, choices, visibility/enabled metadata and panel-open state). Ordinary revisits replay that state, cross one browser completion barrier, accept the canonical RenderState, and release exactly one live Plot render. After the persistent Editor is bootstrapped, Project load and Graph switching are value-only: missing legacy UI snapshots are reconstructed in R and replay failure aborts safely instead of structurally restoring the Editor.
## v3.73.2.20 Style-state migration fix

Older Projects can omit deterministic per-level Style values that the persistent Editor creates on demand. Schema 4 now materializes those defaults in canonical GraphState before replay, including nested `raw_group_colors`. Scatter RenderState also ignores `raw_group_colors` because Scatter does not render through the individual-data raw-colour layer. This prevents a canonical-reconcile abort/reselection loop when opening legacy Scatter Graphs.


The normal Graph workspace no longer owns or persists Graph SVG previews. The persistent `graph_editor_single-plot_container` is the live Graph surface. New `.ggplotpack` saves contain GraphState for Graphs and Figure-owned snapshot assets only; legacy Graph preview SVGs may still be read for backward-compatible Figure heuristics but are not installed as normal Graph authority and are not re-saved. Statistics Plot and Figure Inset requests create temporary/direct snapshots at the caller boundary instead of reading a Graph preview cache.

Figure remains snapshot-owned and independent from later Graph edits. Existing Figure body/legend snapshot separation and Figure edit state are preserved. The former identity-only `server_graph_fast_switch_runtime.R` has been removed because equivalent and non-equivalent Graphs now share the same replay architecture. No timer/polling or per-Graph Editor/DOM cache was added.

This package was statically audited in the build environment (JavaScript syntax, R delimiter/source-target checks, removed-symbol scans and archive/diff checks). R/Rscript is not available in that environment, so final Shiny runtime acceptance must be performed on the Windows target machine.

# v3.73.2.13-fast-equivalent-switch1

This build adds an identity-only fast path for the one persistent Graph Editor. If the selected Graph already has the same editor state and semantic RenderState as the plot currently held by the singleton Editor, switching Graph identity does not run the normal restore / cached-live Preview handshake / render transaction. The existing transaction remains the fallback for every non-equivalent or stale case.

The browser fast retarget keeps the existing singleton live output holder mounted and only updates Graph identity and viewport ownership. This specifically targets repeated switching among identical sample/New/Duplicate Graphs, where v3.73.2.12 spent about 0.8-1+ seconds on synchronization even though `make_plot()` was a cache hit.

The built-in sample line template also leaves ID Mapping unset, matching the actual line UI default.

# v3.73.2.12-sample-template1


This build makes the built-in sample GraphState authoritative for g001 and New Graph. The sample data and its initial Mapping are created deterministically before Editor activation, so a Graph does not need a manual X/Y change or a Graph round-trip to become canonical. Duplicate Graph behavior is unchanged.

This release fixes the startup/new-Graph default boundary. The reusable default GraphState is captured once after the first Shiny/browser flush, not at module creation, so data-dependent Mapping defaults are canonical before g001/new Graph attachment.


This release corrects the persistent Graph Editor acceptance boundary without adding another bootstrap layer. Module `READY` again means the staged restore transaction is complete: mapping/reshape/style binding ACKs and stage-3 finalization have finished. It no longer waits for a second full `project_settings()` snapshot, which could remain transiently unavailable after a valid Graph switch.

After the outer persistent-Editor transaction accepts the Registry canonical GraphState, it now calls the module's `accept_canonical()` once. That updates the module-local attached safety snapshot and pending RenderState target together before Preview authorization opens `render_gate`. The first render therefore cannot use an older pre-acceptance seed (notably the startup pristine X/Y Mapping), while ordinary user edits remain browser-backed through `project_settings()` and the existing Registry callback.

# v3.73.2.9-live-ready-default1

This maintenance release tightens the existing single-Editor state contract rather than adding another bootstrap layer. `READY` means the live browser GraphState is readable; startup then finalizes the one reusable default GraphState from that live pristine state. Hidden Wide→Long controls are ignored by RenderState while reshape is disabled.

# v3.73.2.8-source-cleanup1

This release is a source-reality cleanup, not another synchronization layer. It removes confirmed unreachable migration code, repairs two dangling internal calls, and aligns comments with the current Editor-first / single-canonical-render-boundary architecture. New Graph, duplicate Graph, and existing Graph continue through the same singleton Editor/render path.

---

# v3.73.2.7-simple-render-contract1

## Single render contract

Graph switching is back to one authority path: canonical GraphState is restored into the one persistent Editor, the outer Editor transaction performs READY/semantic acceptance once, Preview ACKs complete, then the accepted attached GraphState is released directly as the Plot target. The Graph module no longer performs a second browser-state bootstrap gate after READY.

`graph_render_state.R` now owns the render contract separately from generic state-diff helpers. Hidden external-error column selectors are collapsed when they cannot affect the current Plot (`Error bar = none`, or a non-direct-value Plot), so browser-populated hidden selectInputs cannot cause a false canonical mismatch. GraphState persistence keeps those selections; only RenderState comparison ignores inactive values.

The v3.73.2.6 whole-state new-Graph canonicalizer and `graph_render_bootstrap_runtime.R` were removed. New Graphs again receive a deep copy of the finalized persistent-Editor default GraphState; they do not have a separate state-authority path. Shared Data/Mapping UI default helpers remain pure in `graph_data_defaults.R`.

# v3.73.2.5-render-state-boundary-refactor1

## Graph live/canonical boundary refactor

The one persistent Graph Editor now has an explicit state boundary: attached canonical GraphState may be used for READY arbitration, but Plot revision and drawing require a live browser-backed GraphState. Graph-switch/restore transactions seed the expected semantic RenderState from canonical state and keep rendering pending until the browser projection catches up.

Expected Shiny `validate()` / `req()` control-flow is no longer converted into a blank `Plot error` graphic. Genuine R errors still produce a diagnostic placeholder and class-aware log. The new logic lives in `graph_state_boundary_runtime.R` and `graph_render_error_runtime.R`; `graph_state_runtime.R` is smaller rather than accumulating more restore/render branches.

# v3.73.2.2-figure-legend-materializer1


## v3.73.2.2 Figure legend materializer

- Fixed Figure legend mode changes that updated override/geometry but could keep rendering the persisted combined SVG.
- Added one lazy, hidden, reusable Figure-owned snapshot materializer. It restores only `figure_edit_states`; it never refreshes a Figure from the current source Graph.
- After the first materialization, normal `figure_plot_revisions` / `figure_snapshot_revisions` rebuild `right / left / top / bottom / none / free / inherit` without remounting an editor.
- Legacy projects may seed a missing Figure editable state only when persisted Graph and Figure SVGs are byte-identical, the Graph preview is clean, and any live Graph preview still matches that same SVG.
- Materializer settle compares `graph_render_state()` and permits at most one bounded reload, preventing the full-GraphState hydrate loop seen in the failed lazy-materialize trial.
- `FIGURE-LAYER` diagnostics now key on legend mode/source plus plot/snapshot revisions so legend-only redraws are visible in logs.
- No polling/timers were added; Statistics and Figure reorder transactions are unchanged.

## v3.73.2 Figure control surface + detached legend safety

Figure no longer hides ordinary editing controls under an `Advanced` accordion. Canvas mode, Fixed width/height and Auto-fit policy now live at the top of Step 2 beside the main Layout controls; the SVG preview toggle lives with Preview. Less-frequent Row/Panel structure and reorder tools stay discoverable as named Step-2 subsections rather than a separate advanced mode. Shared Label / Style starts collapsed to reduce initial visual density without removing it from the workflow.

The selected Figure Panel now has `自由配置の位置を初期化`. It resets only Figure-owned placement coordinates (free legend, Panel label and Inset/external-legend positions). Graph content, Crop, Graph order, style and mode choices are preserved. A detached legend re-arms its source-position bootstrap so reset returns to the position it had when first detached.

Detached legend extraction is hardened for compound/multiple-guide Graphs. The complete visible guide box is extracted as one layer, a known source side is preferred when available, and invalid extraction can no longer erase the source legend: Preview/Project persistence/Export fall back to the combined Graph instead of rendering a legend-free body with no overlay.

Fixed Canvas gap controls remain real Panel-slot spacing. Because the outer Canvas is fixed, increasing the gap reduces the space available to the slots rather than growing the Canvas; the UI now states this explicitly and labels them `Panel横間隔 / Panel縦間隔`.

## v3.73.1.7 Figure floating-control visibility

Figure workflow cards no longer clip menus that open outside their own box. Focused Figure sections are temporarily layered above later sections, and the Step 2 reorder destination uses a native select so the slot list cannot disappear behind `共通Label / Style`. Dedicated scroll owners (Figure drawer body, Statistics analysis pane, preview viewport) keep their own overflow behavior.

# v3.73.1.6-figure-layout-reorder-stability1

## v3.73.1.6 Figure layout/reorder stability

Figure Row/Grid reorder is treated as a real state transaction again. Reorder controls live in workflow Step 2 (`配置・整列`), the moved Graph/Asset remains selected, Inspector/selected Row/browser highlight follow it, and stale slot-keyed outputs are rejected when their old source no longer owns the slot. Shift, Swap, adjacent arrows, Undo and default Graph-order reset share the same ownership validator.

Slot-owned state stays in place: Panel label geometry, cell width, free-frame geometry and Row/Column identity do not travel with Graph content. Source-owned state follows the Graph/Asset through its source id, including Crop, detached/free legend, Inset, Figure-specific appearance/edit snapshot and Graph display width/height.

Figure Step 2 also provides a batch vertical-placement helper for compacting Fixed Canvas layouts without silently rewriting saved projects. New cells start with a 32 px Panel-label gutter; existing saved gutter/alignment values remain authoritative until the user applies a new setting. Statistics Analysis settings is taller and no longer horizontally clipped, and Advanced Figure dropdowns can open below the section without being cut off.

# v3.73.1.5-figure-free-legend-footprint1

## v3.73.1.5 Figure free-legend footprint

Figure `free` legends are true overlays. They no longer inherit the Row's common attached-legend slot, and persisted Figure snapshots use their saved legend-free body geometry when live gtable measurement is unavailable. This removes the empty former-legend strip from the owner Graph while preserving ordinary Row legend alignment for attached/legend-less Graphs. Fixed Canvas dimensions remain fixed; Auto Canvas follows the owner body plus the actual overlay bbox.


Statistics keeps the dedicated read-only Graph preview introduced in v3.73.1.3, but the reading layout is adjusted: the Plot now sits in the left Statistics control column immediately above the Analysis selector/settings, while Result uses the right main panel by itself. This keeps the graph physically close to the test configuration without narrowing the statistical output.

The Plot source and ownership are unchanged. Statistics still reads the existing Graph preview cache and never reveals or reparents the live Global Plot Preview. Analysis input ids, result calculation, restore settle/baseline guards, Graph/Figure ownership and materialization are unchanged.

# v3.73.1.3-statistics-plot-preview1

Statistics again shows the Graph while test results are being read, but the implementation is now separated from the Plot Editor Preview. The Statistics workspace owns a dedicated SVG Plot surface backed by the existing Graph preview cache, while the Global live/cached Editor Preview remains Plot-tab-only. This keeps the v3.73.1.1 overlap fix intact.

On wide screens Plot and Result are shown side by side so the graph can be interpreted together with ANOVA/t-test/correlation output; the Plot remains visible while reading the result area. Narrower windows stack the two regions vertically. Graph switching while Statistics is active updates the Statistics Plot to the newly selected Graph without creating another editor or reusing the live Preview stage.

# v3.73.1.2-statistics-post-restore-baseline1

This focused hotfix closes the last switch-only Statistics recipe write seen after v3.73.1.1. A dynamic ANOVA control can legitimately present an inferred default (for example `ID`) even when the saved recipe field is empty. The existing browser settle handshake correctly proves that this UI state is stable, but stability alone does not mean the user edited the recipe.

The stable restore snapshot is now held as a transient post-restore baseline. An unchanged baseline is ignored by both live recipe commit and Project serialization. As soon as an input differs from that baseline, normal recipe comparison and persistence resume. The baseline is never stored as canonical state and is discarded on Analysis/Graph restore boundaries.

No new timer, polling loop, debounce, JavaScript handler, Preview/Figure behavior, or Statistics computation path is introduced.

# v3.73.1.1-workspace-preview-tab-guard1

The Graph workspace is Editor-first again. Opening a Project or selecting another Graph automatically synchronizes the persistent single Editor; there is no separate user-visible browse/edit promotion and no top-level Edit button. A stable workspace-owned Plot / Statistics / Data View / 製作者コメント bar stays visible outside hydration and keeps its current section across Graph switches; Plot controls are Plot-only, while Statistics Analysis state remains independently gated internally. Rapid Graph changes are serialized with a latest-target queue rather than interrupting an in-flight restore. A new Project Close action performs a confirmed hard reset to pristine Graph 1.

## v3.73.0 Figure workflow + Shared Label / Style Library

**v3.73.0 ownership guard:** Shared Library bindings are Project-specific metadata; generic Graph style copy/export does not transport them, legacy v3.72 states normalize to an empty binding on load, and Figure→Graph Apply preserves the source Graph binding.


The Figure workspace now follows the publication workflow rather than exposing every internal geometry control at the same level: **Import → Layout / alignment → Shared Label / Style → Individual adjustment → Export**. Existing Plot / Facet / Axis geometry, row gutter sharing, legend-slot behavior, snapshots, crop/inset and export machinery are preserved. Fixed canvas, update policy and experimental preview controls are grouped under Advanced.

A project-level Shared Label / Style Library provides explicit semantic definitions for groups/conditions, axis labels and legend titles. Users bind raw Graph values to semantic items deliberately; the application does not infer bindings from names such as `sham`, `Vehicle`, `WT` or `control`. Linked style changes flow through the central Library and canonical GraphState rather than Graph-to-Graph synchronization.

Figure snapshots remain independent. Library changes affect Figure only when Figure Library Sync is explicitly enabled or **今すぐFigureへ反映** is pressed. Only Shared-style semantics are applied; Figure Data, Mapping and geometry are not reloaded. Affected Figure snapshots are rebuilt serially with the existing one reusable Figure Editor. Library JSON export/import carries definitions, while Graph bindings remain Project-specific.

## v3.72.27.6 Statistics restore context guard

This focused hotfix fixes a runtime error introduced by the v3.72.27.5 settle handshake. The post-flush settle callback sampled the active Statistics recipe through `stats_capture_recipe_from_inputs()`, but that helper reads Shiny `input$...` values and therefore must execute inside a reactive/isolation scope. The snapshot helper now isolates the complete recipe/input read, allowing the existing bounded browser-settle protocol to continue unchanged.

No new timer, polling loop, debounce, JavaScript handler, or Statistics/Plot coupling is introduced.

## v3.72.27.5 Statistics restore settle

This focused hotfix closes the last Analysis-switch echo observed after v3.72.27.4. A single browser round-trip was sufficient for most Analyses, but a dynamically rebuilt mapping control could still bind one client turn later. Statistics restore now keeps its existing restore guard active across a bounded browser value-stability handshake and releases only after the canonical active-type input snapshot is unchanged across consecutive round-trips.

Recipe capture is also scoped to the selected analysis type. Hidden t-test/correlation mappings are not captured while ANOVA is active (and vice versa), so renderUI defaults cannot contaminate an unrelated saved recipe. The existing browser barrier handler is reused; no new client handler, timer, polling loop, or debounce was introduced.

## v3.72.27.4 Statistics switch echo guard

This focused hotfix removes the remaining short burst of Statistics recipe saves that could occur immediately after switching Analysis. The restore pipeline already had a server-side `stats_restoring` guard, but that guard was released before the final browser input updates had completed their round trip back to Shiny.

Statistics restore now crosses the existing browser reconcile barrier after its final dynamic-control update. The restore guard remains active through the ACK flush and is released only in `session$onFlushed()`, so browser echoes from the restore transaction cannot be interpreted as user edits. No new timer, polling path, or JavaScript handler is introduced.

## v3.72.27.3 Statistics result stability

This hotfix completes the Statistics stability fix. v3.72.27.2 stopped no-op recipe writes, but normal `stats_transform_recipe()` evaluation still reacted to `stats_recipes()` commits. That invalidated the Analysis source-data pipeline, rebuilt dynamic mapping controls, echoed inputs back to Shiny and created a new real-looking recipe commit. The repeated invalidation also prevented the debounced Result output from settling, so the Result card could remain blank.

During normal Statistics editing, transform inputs are now the reactive source and the saved Analysis recipe is used only as an isolated fallback. During guarded Analysis restore, the saved recipe remains authoritative. No Statistics/Plot recoupling or timer/polling workaround is introduced.

## v3.72.27.2 Statistics recipe stability

Hotfix for the Statistics recipe save loop seen in v3.72.27.1 after opening or switching Analysis. Statistics dynamic controls can echo their restored values back through Shiny. The previous save path rewrote `stats_recipes()` even when the captured canonical recipe was unchanged, causing repeated UI invalidation and `GRAPH-EDIT-STATS-SAVE` activity.

The selected Analysis recipe is now normalized and compared before commit. Identical UI echo events are ignored; real Analysis edits still commit normally. The separate Raw Dataset + Analysis-local preparation model, Plot/Data View pipeline, persistent Graph Editor and Preview/Figure architecture are unchanged.

## v3.72.27.1 Data-transform boot guard

Hotfix for the v3.72.27 startup regression. The new Plot transform boundary had reused the name `plot_data`, which was already owned by `graph_prepared_data_runtime.R`. Because all graph runtime files are sourced into one `graphServer` environment, the later definition replaced the new transform reactive and created `dat() -> plot_data() -> dat()` recursion before the pristine singleton Editor state could be captured.

The transform-only boundary is now named `plot_source_data()`. The longstanding prepared `plot_data()` keeps its original role. Data View follows `plot_source_data()` (the original dataset plus Plot-side Wide→Long), and transform recipe normalization now tolerates startup `NULL` / zero-length / `NA` values. No Graph/Preview/Figure architecture is changed by this hotfix.

## v3.72.27 Statistics data boundary

Statistics and Plot now share the Graph's original dataset, not the Plot transformation state. Each Analysis can independently use the original dataset as-is or define its own Wide→Long preparation. Plot Mapping/style choices do not determine the Statistics factor plan. Existing saved analyses that previously relied on Plot Wide→Long are migrated once into an explicit Analysis-local preparation recipe.

Data View remains plot-oriented and shows the data actually passed to the Plot after Plot-side Wide→Long. The Plot/Statistics transform engine is shared as pure code, while their recipes remain independent.

The singleton Graph Preview is owned by the Plot tab only. Statistics, Data View and 製作者コメント hide it even when the persistent Editor module id is `graph_editor_single`.

## v3.72.26 Reconcile browser barrier

This checkpoint fixes a false warning/activation abort seen after Figure settings were applied back to a Graph. The canonical GraphState was already correct, but persistent-Editor `update*Input()` messages could be visible in the browser one client turn before their values returned to Shiny server inputs. A second canonical comparison performed in that gap incorrectly reported a mismatch.

The reconcile fallback now waits for one explicit browser round trip after the staged `sync_state()` reaches READY. The browser acknowledges on the next animation frame and only that ACK schedules the second canonical RenderState comparison. This is an ordering barrier, not a time delay: no polling or timer was added.

## v3.72.25 Restore ACK fallthrough

This release is a focused correctness fix on top of v3.72.24. The event-driven Editor restore remains in place, but successful Wide→Long parent/child binding ACKs now fall through to the server-value verification in the same reactive pass instead of returning unconditionally. This prevents the full-screen hydration overlay from remaining indefinitely when the browser was already preseeded with the requested values and therefore emits no new input change.

No warm/preload path or timer polling was restored.

## v3.72.24 Editor hydration fast path

Base: v3.72.23 materialization encapsulation, retaining v3.72.16's full-screen Editor hydration overlay and v3.72.18's Figure Apply Graph-preview publication.

This checkpoint fixes the new-Graph hydration lock and removes timer polling from the core RESHAPE/MAPPING restore path.

### New Graphs

A new Graph is born with a complete canonical GraphState copied from the singleton Editor's captured pristine default template. The Registry is initialized before Editor activation; the Editor is therefore a consumer of the new Graph's canonical state rather than the source from which defaults are inferred.

### Existing Graph hydration

- Browser binding readiness is event-driven (`shiny:bound` / `shiny:unbound` / `shiny:inputchanged`) and generation-scoped.
- Restore no longer uses 75 ms `invalidateLater()` loops.
- Persistent Wide→Long parent controls reuse their live bindings when values already match.
- Mapping semantic defaults avoid redundant NULL→`__color__` resync.
- Persistent dynamic-style finalization removes one extra server flush while keeping generation-scoped input IDs and the canonical loading guard.

### Activation safety

READY is accepted after one Shiny flush plus canonical RenderState arbitration. A failed canonical reconcile no longer leaves the full-screen synchronization mask in place; the transaction aborts safely back to Graph preview browse.

See `REFACTOR_CHECKPOINT.md`, `docs/TEST_CHECKLIST.md`, and the v3.72.24 static audit files for validation details.
## v3.73.1.1 preview-tab guard

The Graph workspace section is global across Graphs. Switching Graphs while Statistics, Data View or 製作者コメント is active no longer restores that target Graph's historical Plot Preview. The singleton cached/live Preview remains hidden until the user returns to Plot.