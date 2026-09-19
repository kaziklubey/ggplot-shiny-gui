# v3.73.2.29-graph-settings-figure-edit1 checkpoint

Graph Settings popout is now an explicit Graph/Figure value editor. Preserve the three ownership paths: Graph-only writes canonical GraphState, Figure-only writes Figure-owned GraphState and direct-state snapshot, Graph+Figure does both. `FigureをGraphから更新` is an explicit full source refresh and must remain direct-state (no persisted SVG shortcut, no hidden Graph editor/replay).

# v3.73.2.26-graph-settings-popout1 checkpoint

Graph Settings Manager external-window rule: the companion window is presentation-only. It must not start another Shiny app/session, instantiate graphServer, own GraphState, or bind Shiny inputs/outputs. The main session sends read-only settings payloads to client JS; the child window renders that payload and posts navigation requests back to the opener. Closing or reopening the child must not affect Graph/Figure ownership.

# v3.73.2.21-value-replay-live-figure1 checkpoint

## Current architecture checkpoint

Graph: one persistent Editor UI/module. Loading is GraphState value replay only; ordinary UI reactives derive Wide→Long data, Mapping choices, conditional controls, and plot errors. No semantic browser readback/reconcile is part of normal activation. Live edits advance Plot revision independently from attach transactions.

Figure: one persistent controls-only Figure renderer is reused for dormant Graph sources. Main snapshot, legacy legend regeneration, and Inset refresh are target-specific Figure-owned captures; no Figure path mounts per-Graph hidden UI/module or enters Graph structural restore.

Ownership remains `Graph canonical = GraphState`; Figure owns point-in-time snapshots and editable Figure GraphState copies independently.

# v3.73.2.20-style-state-migration1 checkpoint

Canonical ownership: `GraphState` is the only editable/persisted Graph authority. There is exactly one persistent Graph Editor and exactly one persistent live Plot surface. `GraphState$ui_snapshot` is presentation/persistence state and is intentionally excluded from RenderState comparison.

Dynamic Style compatibility is now owned by `graph_style_state_migration.R`. Saved GraphStates are canonicalized to schema 4 before replay; dormant editor preferences must be collapsed in `graph_render_state.R` rather than treated as activation-blocking render differences.

Ordinary Graph selection must follow: outgoing canonical commit -> target GraphState lookup -> state replay into the persistent Editor -> one browser replay-completion barrier -> canonical/RenderState acceptance -> arm live-output completion -> open render gate once -> one Plot publication -> READY. Do not route ordinary revisits through `project_restore_stage`, Mapping binding handshakes, cached/live Preview authorization, detached Graph DOM, timers or polling. Structural restore is compatibility fallback only.

New Project saves must not contain Graph SVG previews. Legacy `preview/graph_*.svg` data may be parsed only for backward-compatible Figure migration heuristics; it must not become Graph display authority or be re-saved. Statistics and Figure Inset may materialize temporary/direct SVGs at explicit caller boundaries. Figure Main/Inset assets remain point-in-time Figure-owned snapshots and must not auto-refresh after Graph edits.

The old `server_graph_fast_switch_runtime.R` is intentionally gone. Do not reintroduce a special identity/equivalent Graph path: all normal Graphs use replay and one live render contract.

Windows acceptance after unpacking: verify fresh g001, New Graph, Duplicate, A->B->A switches with visibly different Data/Mapping/Style, rapid multi-tab switching, Project save/reopen, legacy Project open, Statistics Plot, Figure import, Figure legend/body snapshot behavior and Figure Inset. Confirm no blank/stale Plot, no Graph switch lock, no cross-Graph UI bleed, Figure does not auto-update, and newly saved `.ggplotpack` packages contain no Graph preview SVG.

# v3.73.2.13-fast-equivalent-switch1 checkpoint

Equivalent Graph identity must not pay a restore cost. The fast path is allowed only when current Editor GraphState and target canonical GraphState are equivalent (apart from Project-global/empty selector normalization), the singleton's completed RenderState already equals the target RenderState, and the source Preview is fresh. On success, owner/lease/Preview identity changes while the existing live plot stays mounted; restore, Preview handshake and render are skipped.

Any failed condition must fall through to the existing persistent-Editor transaction. Do not weaken the fast-path equivalence checks to make more switches qualify.

# v3.73.2.12-sample-template1 checkpoint


## v3.73.2.12 sample-template checkpoint

New Graph initialization now has one state authority: the built-in sample GraphState template. `graph_sample_data_text()` owns the sample dataset and `graph_sample_graph_state()` applies deterministic data-derived Mapping to the Editor shell baseline. g001 and New Graph deep-copy that template. UI input round-trips are not part of Graph creation.

Current focus: authoritative post-bind pristine GraphState capture. Immediate module-create capture was removed because it prevented the intended post-bind capture from ever taking effect.

# v3.73.2.10 Accepted-canonical boundary checkpoint

The persistent Graph Editor now has one acceptance boundary again. Restore/binding verification establishes module READY. The outer transaction arbitrates canonical state, then explicitly hands the accepted Registry GraphState back to the module exactly once via `accept_canonical()`. That handoff synchronizes the module attachment and pending render target before Preview authorization opens `render_gate`.

Do not reintroduce a second full-browser-state READY gate. `project_settings()` remains the source for ordinary live edits and Registry commits, not an additional Graph-switch acceptance prerequisite.

# v3.73.2.9 Live READY/default checkpoint

The persistent Editor remains one instance. The outer transaction accepts a Graph only after the module can expose a live browser-backed `project_settings()` state. The attached canonical fallback remains a safety snapshot for remount/save paths, but cannot satisfy READY arbitration by itself. Startup g001 is the only place where live pristine browser defaults are promoted into the reusable canonical default template.

# v3.73.2.8 Source cleanup checkpoint

Current rule: treat the active call graph as source of truth. Historical handoff/docs explain design intent but do not justify keeping unreachable migration paths. The persistent Graph Editor remains singleton; Registry is canonical; Figure Apply is server-level Registry commit; first render after READY uses the accepted attached canonical target exactly once.

Cleanup completed in this checkpoint:
- old graphServer Figure-commit transaction removed;
- dead module API wrappers removed;
- dangling completed-render-state call replaced with the already-owned `plot_last_built_render_state`;
- stale Figure source helper name corrected;
- comments/docs updated to Editor-first semantics.

---

# v3.73.2.7 Simple render contract checkpoint

The persistent Graph Editor has one acceptance boundary. `graph_single_accept_loaded_state()` owns READY/canonical RenderState comparison and at most one fallback reconcile. After Preview ACKs, opening `render_gate` releases the already-attached accepted canonical target exactly once; the module must not re-run an independent browser-state bootstrap acceptance step.

GraphState is the editable/persisted state; RenderState is only the subset that can affect the current Plot. Hidden inactive controls must be semantically collapsed in `graph_render_state_apply_semantics()`. In particular, external-error column selectors do not participate when the current Plot cannot use them. Persistence may still retain their values for later reactivation.

A genuinely new Graph has no special canonicalization path. `graph_single_default_state_snapshot()` deep-copies the finalized persistent-Editor default and `seed_new_graph_default_state()` commits it before activation. Browser defaults are UI presentation, not a second state authority.

No polling/timers, per-Graph Editor DOM/module, extra Preview handshake, or extra reconciliation loop may be added to solve state timing. New responsibilities should be implemented as small pure/runtime functions and wired into the existing transaction, not appended as branches to a giant function.

Windows acceptance: fresh Project must reach stable g001 READY without repeated `mapping.external_error/external_ymin/external_ymax` reconcile loops. Create g002 and confirm it renders; duplicate it before and after a Preview exists and both copies must use the same ordinary render path. Existing rendered Graph duplication and Figure/Statistics behavior must not regress.

# v3.73.2 Figure control-surface checkpoint

Figure remains an editor-first workflow. Ordinary Canvas/Layout controls must not be hidden behind an Advanced mode. Step 2 owns Canvas mode, Fixed width/height, Auto-fit policy, Layout mode/basis and Panel gaps. Preview owns the SVG-preview toggle. Secondary structure/reorder controls may be collapsed under explicit named subsections, but their location must remain obvious.

`自由配置の位置を初期化` is placement-only. It may reset Panel-label coordinates/offsets, free-legend placement bootstrap and Inset/external-legend X/Y. It must not mutate Graph/Asset order, Crop, source content, style, legend mode, Inset source/enabled state, Graph size or Row/Column structure.

Detached legend extraction must treat the selected guide box as one complete asset, including multiple guides inside that box. If legend extraction is unavailable or invalid, Preview/Project save/Export must retain the combined Graph legend rather than producing a legend-free owner body with no overlay.

Windows acceptance with `test222.ggplotpack`: verify Fixed/Auto Canvas controls are visible without opening Advanced; Fixed width/height appears when Fixed is selected; Auto policy appears for Auto; Panel gaps change slot spacing while the 1600x1000 outer Canvas remains fixed. On a Graph with multiple guides, switch Legend to free and confirm all guide content stays visible and draggable. Move the free legend/Panel label/Inset, press the position reset, and confirm placement returns while Crop/Graph order/content remain unchanged.

# v3.73.1.7 Figure UI overflow checkpoint

Figure workflow section chrome must never clip interactive floating UI. `.figure-config-section` stays visually card-like but uses visible overflow; the focused section is layered above later siblings. Only explicit scroll/clip owners (for example the Figure drawer body, plot viewport, Statistics analysis/result panes) may crop descendants. Step 2 `移動/交換先` is intentionally native (`selectize=FALSE`) because it is a finite slot chooser, not a search field.

Windows acceptance: open Step 2 `配置・整列`, expand `移動/交換先`, and confirm every Row/Panel destination remains visible above the following `共通Label / Style` section. Repeat with other Figure select/dropdown controls near section bottoms; no menu should be hidden merely because it extends beyond a card boundary. Reorder behavior from v3.73.1.6 must remain unchanged.

# v3.73.1.6 Figure reorder/state-ownership checkpoint

Row/Grid reorder must preserve ownership, not merely visual order. Slot-owned fields remain attached to the slot; source-owned Graph/Asset content follows the source. Every reorder validates both invariants before commit. Selection follows the moved source, including selected Row, Inspector generation and browser highlight; Undo restores the prior selection. Slot-keyed Figure outputs verify their current source owner so delayed renders from an old owner cannot paint into a newly reassigned slot.

Windows acceptance with `test222.ggplotpack`: test ←/→/↑/↓, Shift insert across occupied and blank slots, Swap, Undo and Graph-order reset. After every operation confirm Panel labels remain in their slots, Graph width/height move with the Graph, Crop/free legend/Inset remain attached to the same Graph source, selection/Inspector follow the moved Graph, and no old Graph frame remains in the vacated slot. Cross-row moves must also move the selected Row. `FIGURE-REORDER-VERIFY` should report layout/requested/selected_key/selected_source all TRUE.

Also verify Step 2 batch vertical placement (`上 + 32px`) compacts Fixed Canvas top whitespace, Advanced dropdowns are not clipped at the bottom, and Statistics Analysis settings is taller without a horizontal scrollbar.

# v3.73.1.5 Figure free-legend footprint checkpoint

A Figure `free` legend is an overlay, not a Row alignment slot. It must neither contribute to nor receive the common attached-legend reservation. When rendering from a persisted Figure snapshot without live gtable measurement, the saved `body_meta` is the owner Graph footprint; full-preview legend bboxes are mapped into body coordinates only for detached overlay placement.

Windows acceptance with `test222.ggplotpack`: Figure A/g002 and the other free-legend Graph must lose the asymmetric right-side empty strip. In Fixed 1600x1000 mode, residual whitespace from equal fixed cells is allowed but should be approximately balanced around the owner body. In Auto mode, the owner body must not reserve the old attached-legend strip; canvas may grow only when the actual free legend or Inset extends outside the content bbox. Attached-legend Graphs must retain Row alignment.

# v3.73.1.4 Statistics Plot-above-Analysis checkpoint

Statistics layout ownership remains split by purpose: the left sidebar is the Plot + Analysis configuration workspace, and the right main panel is Result. The dedicated read-only Statistics Plot must appear directly above the existing Analysis selector/settings. Moving the UI must not alter `stats_plot_preview`, Statistics recipe/result computation, Global Preview visibility/ACK, or Graph/Figure ownership.

Windows acceptance: open Statistics on a saved Graph and verify the left column order is Statistics data -> Plot -> Analysis selector/actions/settings, while Result occupies the right panel. Switch Analyses and Graphs and confirm the Plot/result/restore behavior from v3.73.1.3 remains unchanged.

# v3.73.1.3 Statistics Plot preview checkpoint

Statistics uses the plotted Graph as part of result interpretation, not merely as an identity thumbnail. Therefore the Statistics section owns its own substantial Plot display beside Result. This display is presentation-only and reads the existing Graph preview record; it is not the singleton live Global Plot Preview and must never reparent/reveal that Editor surface while Statistics is active.

Graph changes in Statistics update the dedicated Plot preview from the workspace-selected Graph. The persistent Graph Editor remains single, the Global Preview remains Plot-tab-only, and no timer/polling or second editor path is introduced.

Windows acceptance: open Statistics and verify Plot + Result are simultaneously visible; switch Graphs while remaining in Statistics and verify the Statistics Plot changes without the Global Preview overlay returning. Plot tab must still restore the normal live Global Preview.

# v3.73.1.2 Statistics post-restore baseline guard

Windows v3.73.1.1 showed a stable two-round-trip Statistics restore followed by one `STATS-RECIPE-COMMIT` whose only canonical difference was `anova_id`. The dynamic ANOVA UI had inferred `ID` for an empty saved `anova_id`; the browser snapshot was stable, but the generic save path still compared that stable presentation default against the empty canonical recipe and classified it as an edit.

The fix keeps canonical recipe ownership unchanged. At restore release, the stable active-type input snapshot is recorded in a transient `stats_post_restore_baseline`. Save and Project-serialization paths ignore that exact baseline. The first input state that differs from the baseline clears the guard and follows the ordinary semantic commit path. Restore/Graph replacement clears the baseline.

Windows acceptance: switch Analysis without touching any setting. After `STATS-RESTORE-BARRIER released ... stable=TRUE`, `STATS-RESTORE-BASELINE armed` may appear, but no `STATS-RECIPE-COMMIT` and no canonical `statistics_recipes...anova_id` diff should follow. A real subsequent control edit must still commit once and refresh `STATS-RESULT`.

# v3.73.1.1 Workspace Preview tab guard checkpoint

The outer Graph workspace section bar is the sole presentation owner for Plot / Statistics / Data View / 製作者コメント. Preview visibility is workspace-global, never per Graph. Graph target changes must not resurrect a cached/live Plot while a non-Plot section is active. The existing Preview transaction/ACK protocol and persistent Graph Editor remain unchanged.

# v3.73.1 Editor-first workspace checkpoint

## Contract

The application is an Editor. Cached SVG remains a derived latency/failure layer, not the default interaction mode. Graph selection automatically requests the single persistent Editor.

## Selection safety

A Graph switch never interrupts a running REPLAY/RENDER transaction. `graph_single_pending_target` stores only the latest requested target and drains after the current ACK-gated transaction releases. This prevents partial replay state from being committed as the outgoing Graph. Client READY for an older queued target does not reveal or overwrite the newer selection.

## Section continuity

The persistent `graph_main_tab` stays mounted, so Plot / Statistics / Data View / 製作者コメント selection survives Graph changes. Statistics is not re-coupled to Plot Mapping; v3.72.27 Analysis recipe/data-preparation boundaries remain unchanged.

## Project close

Close Project uses a confirmation and hard session reload to pristine Graph 1. This intentionally favors complete ownership cleanup over a fragile manual reset of Graph/Figure/Shared-Style/editor reactive state.

# v3.73.0 Figure workflow / Shared Style checkpoint

**v3.73.0 ownership guard:** Shared Library bindings are Project-specific metadata; generic Graph style copy/export does not transport them, legacy v3.72 states normalize to an empty binding on load, and Figure→Graph Apply preserves the source Graph binding.


## Scope

- Reorganize Figure UI in the user's publication workflow without rewriting the mature geometry runtime.
- Introduce a central Shared Label / Style Library with explicit semantic binding.
- Keep GraphState canonical, Figure snapshots independent, and both Graph/Figure editor counts at one.

## Ownership contract

- **Library**: semantic definition (`id`, display, kind, Color/Fill/Shape/Line and managed attributes).
- **GraphState**: project-specific binding metadata plus concrete render-facing style values.
- **FigureState**: independent snapshot. Shared Style may update only when Figure sync is ON or Apply Now is explicit; Data/Mapping/geometry never flow through this path.
- **Portable Library JSON**: definitions only. Graph bindings are not portable and are never inferred automatically.

## Runtime transaction

`Library change → central Library commit → affected canonical GraphState only → affected Graph materialization only`. Figure auto/manual apply is a separate opt-in path: `resolve source binding metadata only → update Figure-owned GraphState → force-load existing single Figure Editor → bounded settle → snapshot → next affected Figure Graph`. No timer/polling path and no extra editor instance is introduced.

The Figure batch captures the currently live Figure editor state before semantic mutation and never allows an obsolete READY editor state to overwrite a queued canonical Figure state. A failed existing Figure settle transaction aborts the Shared Style batch safely.

## Windows validation target

1. Open an old `.ggplotpack`: Figure geometry should be unchanged; Shared Library is empty and Figure sync is OFF.
2. Create semantic items and explicitly bind Graph levels/axis/legend fields. No automatic binding should occur.
3. Change a linked Library level style: only linked Graphs should change/materialize.
4. With Figure sync OFF, Figure snapshots must remain unchanged. `今すぐFigureへ反映` must rebuild only affected Figure snapshots through one Figure Editor.
5. Enable Figure sync, change the Library again, and verify sequential settle/snapshot logs without timer/polling.
6. Save/reload the Project: Library, Graph bindings and Figure sync state must restore.
7. Export the Library JSON and import it into another Project: definitions restore, bindings do not auto-attach.

# v3.72.27.6 Statistics restore-context checkpoint

## Runtime issue

The v3.72.27.5 Windows trace reached the first Statistics restore barrier ACK, then failed with `Can't access reactive value 'stats_name' outside of reactive consumer`. The new settle helper was called from `session$onFlushed()`, where there is no reactive consumer, while `stats_capture_recipe_from_inputs()` reads `input$stats_name` and the other Statistics inputs.

## Fix

- Wrap the complete `stats_restore_input_snapshot()` body in `isolate({ ... })`, not only the `stats_recipes()` read.
- Keep the v3.72.27.5 bounded browser stability handshake and active-analysis-type capture unchanged.
- Do not add a timer, polling loop, debounce, MutationObserver, or new JavaScript handler.

## Validation target

On Windows, Analysis restore must continue past the first barrier ACK with no reactive-context error, perform one or more settle attempts, release with `stable=TRUE` (or bounded `FALSE_MAX` only if genuinely unstable), and emit `STATS-RESULT`. Switching Analysis alone should not emit `STATS-RECIPE-COMMIT`; a real user edit should still commit once.

# v3.72.27.5 Statistics restore-settle checkpoint

## Residual issue

The v3.72.27.4 Windows trace showed the barrier working for the first two Analysis switches, but a third Analysis still produced one `STATS-RECIPE-COMMIT` about 130 ms after `STATS-RESTORE-BARRIER released`. Its state diff included inactive t-test/correlation mappings (`ttest_group`, `ttest_dv`, `cor_x`, `cor_y`) as well as `anova_id`, showing that a late dynamic renderUI bind could both outlive the first barrier and leak auto-selected defaults from dormant analysis types.

## Fix

- Keep `stats_restoring == TRUE` until the active Analysis input snapshot is stable across consecutive existing browser-barrier ACK flushes.
- Use a bounded transaction handshake (maximum four attempts), not a timer/polling loop.
- Validate Analysis id, restore token and barrier attempt for every ACK.
- Capture/save only the mapping fields owned by the currently selected analysis type; preserve dormant type-specific recipe fields unchanged.
- Keep common Analysis settings and Analysis-local data preparation unchanged.

## Validation target

On Windows, each Analysis switch should show `STATS-RESTORE-BARRIER requested/acked`, at least one `settling` transition, then `released ... stable=TRUE`. Switching alone must not emit `STATS-RECIPE-COMMIT`; a real control edit must still emit one commit and refresh `STATS-RESULT`. Project save/reload must preserve all Analysis recipes.

# v3.72.27.4 Statistics switch-echo checkpoint

## Residual issue

v3.72.27.3 stopped the continuous Statistics loop and restored Result rendering, but Windows runtime logs still showed a short cluster of `STATS-SAVE` / `STATS-RECIPE-COMMIT` entries after an Analysis switch. `load_stats_recipe()` correctly set `stats_restoring(TRUE)`, yet the final restore phase cleared it before the browser had returned all `update*Input()` echoes to Shiny.

## Fix

- Keep `stats_restoring == TRUE` after the final dynamic Statistics restore batch.
- Reuse the existing `graph-editor-reconcile-barrier` client handler with a namespaced `stats_restore_barrier_ack` input.
- Validate the Analysis id + restore token on ACK so stale acknowledgements cannot release a newer restore transaction.
- Keep the guard active for the entire ACK server flush; release it only from `session$onFlushed()`.
- Do not add a new timer, polling loop, debounce, MutationObserver, or Statistics-specific JavaScript handler.

## Validation target

On Windows, switching Analysis should produce `STATS-RESTORE-BARRIER requested`, `acked`, then `released`. Restore echoes must not produce `STATS-RECIPE-COMMIT`. After release, one real control edit must still commit normally and the Result panel must continue to emit `STATS-RESULT`. Project save/reload must preserve the selected Analysis recipe.

# v3.72.27.3 Statistics result-stability checkpoint

## Regression cause

v3.72.27.2 correctly avoided writing a semantically identical Analysis recipe, but `stats_transform_recipe()` still called reactive `stats_selected_recipe()` in normal operation. A legitimate recipe commit therefore invalidated `stats_source_data()`, which rebuilt the dynamic ANOVA/t-test/correlation mapping UI. Recreated inputs echoed values back to the recipe observer, creating another commit and another rebuild.

The repeated input/rebuild cycle also continuously invalidated the 180 ms debounced Statistics result reactive, so the Result panel could remain blank even though the selected Analysis was valid.

## Fix

- During `stats_restoring() == TRUE`, the saved Analysis recipe remains a reactive authoritative source.
- During normal editing, `stats_transform_recipe()` isolates `stats_selected_recipe()` and uses it only as fallback for not-yet-bound inputs. Browser Statistics transform inputs are the reactive source.
- Keep the v3.72.27.2 canonical equality guard at the recipe commit boundary.
- Emit `STATS-RESULT type=<...> chars=<...>` when a result successfully renders.
- Do not add debounce/polling workarounds beyond the pre-existing 180 ms result debounce.

## Validation target

On Windows: open a saved Graph with Statistics recipes, open Statistics, switch Analysis, and leave it idle. `STATS-RECIPE-COMMIT` / `STATS-SAVE` must not stream continuously. The Result panel must render ANOVA/t-test/correlation output (or a visible validation message). A valid result should emit one `STATS-RESULT` diagnostic after inputs settle.

# v3.72.27.2 Statistics recipe-stability checkpoint

## Regression cause

`save_current_stats_recipe()` wrote the full `stats_recipes()` reactive collection on every Statistics input echo, even when the selected Analysis recipe was semantically identical to the stored canonical recipe. Because dynamic Statistics UI is derived from that collection, the write could rebuild controls, re-emit browser inputs and trigger another save. The runtime log therefore showed repeated `GRAPH-EDIT-STATS-SAVE` entries at roughly flush cadence.

## Fix

- Normalize the stored selected recipe and the newly captured candidate before comparison.
- Return without mutating `stats_recipes()` when the two canonical recipes are identical.
- Commit and emit `STATS-RECIPE-COMMIT` only for a real recipe change.
- Skip identical Analysis-name writes as well.
- Do not change Statistics data ownership, Plot reshape ownership, GraphState ownership or Editor/Preview/Figure lifecycle.

## Validation target

Windows runtime should open Statistics, switch among saved Analyses and then remain idle without a continuous `GRAPH-EDIT-STATS-SAVE` stream. A real control edit should produce one recipe commit and persist through Graph switch and Project save/reload.

# v3.72.27.1 Data-transform boot-guard checkpoint

## Regression cause

`graph_data_runtime.R` introduced a transform-only reactive named `plot_data`, but `graph_prepared_data_runtime.R` already owned a different `plot_data` reactive. Both files are sourced into the same `graphServer` environment. The later prepared-data definition therefore replaced the transform reactive captured by name, producing `dat() -> plot_data() -> dat()` recursion during startup. The singleton Editor could not reach pristine default-state capture and activation later aborted with `default-state-missing`.

## Fix

- Transform-only data is `plot_source_data()`: raw Graph dataset plus Plot-owned Wide→Long only.
- `dat()` remains the compatibility boundary and delegates to `plot_source_data()`.
- Existing prepared `plot_data()` remains Mapping-aware and unchanged.
- Data View uses `plot_source_data()`.
- Transform recipe normalization is safe for unbound startup inputs (`NULL`, zero-length, blank, `NA`).

## New invariant

Runtime files sourced into the shared `graphServer` environment must not define the same local reactive/function/state binding unless the override is explicitly designed and documented. Release audit must scan this boundary.

# v3.72.27 Statistics raw-data / Analysis recipe checkpoint

## Data ownership

- `data_text` / original parsed Graph dataset is the Statistics base for Graph-linked analyses.
- Plot owns its own Wide→Long recipe, Mapping, style and Preview.
- Each Statistics Analysis owns an independent optional data-preparation recipe.
- Data View owns no transform state; it displays the current Plot-data result.
- Figure editing no longer owns or writes back `statistics_recipes`.

## Compatibility migration

Old Analysis recipes did not store a data transform and implicitly consumed Plot `dat()`. On restore only, an old Graph-linked recipe inherits the saved Plot Wide→Long recipe once. The normalized Analysis is then independent; changing Plot reshape later does not change the Analysis preparation.

## Source boundaries

- Pure transform engine: `graph_data_transform.R`.
- Plot data pipeline: `graph_data_runtime.R`.
- Statistics state/data/test runtime: `graph_statistics_runtime.R`.
- GraphState restore machinery: `graph_restore_runtime.R` (Statistics implementation removed).

## Preview tab ownership

The persistent Graph editor namespace is `graph_editor_single`, not the semantic Graph id. Browser tab handling resolves that namespace to the actual editing Graph. Non-Plot tabs always hide the singleton Preview stage; Plot can reveal it only for the current semantic Graph.

## Current scope

This checkpoint removes Plot-data/Plot-render coupling from Statistics internally, but Statistics/Data View/Comment are still rendered inside the persistent Graph module. Moving those surfaces into the browse workspace without Editor hydration is a separate UI/runtime boundary change and is not claimed here.

# v3.72.26 Reconcile browser barrier checkpoint

## Scope

Focused fix on top of v3.72.25. It does not change browse-first Graph selection, Figure ownership, source materialization, Preview ACK ordering, or the hydrate ACK-fallthrough optimization.

## Transaction change

When the first READY RenderState differs from canonical, the persistent Editor may perform one `sync_state(canonical)` reconcile. v3.72.26 no longer compares again immediately after server-side READY. Instead:

1. the reconcile restore reaches normal READY;
2. the server sends a generation/attempt/token scoped `graph-editor-reconcile-barrier` message;
3. the browser crosses one `requestAnimationFrame` and ACKs;
4. only the ACK schedules the second canonical RenderState comparison;
5. a remaining mismatch still aborts safely back to Preview browse.

This closes the Figure→Graph case where `connect_id` / `error_width` had already been updated in the browser but their Shiny server values arrived just after canonical arbitration.

## Invariants

- Canonical Registry remains the source of truth.
- No stale Editor state is accepted or published merely because the barrier ACK arrived. The post-ACK RenderState must still match canonical.
- One reconcile attempt remains the maximum.
- No timer/polling/sleep/MutationObserver was introduced.
- Barrier state is generation-scoped and cleared on switch, STALE, accept, and abort.

# v3.72.25 Restore ACK fallthrough checkpoint

Scope is intentionally narrow: repair the no-op ACK deadlock in the v3.72.24 event-driven restore state machine. `RESHAPE-PARENT-SENT` and `RESHAPE-BIND-SENT` now continue into server-value verification in the same observer execution. This preserves the timer-free design while guaranteeing that already-matching inputs can complete without a future invalidation.

Runtime regression target: open an existing Wide→Long graph whose `reshape_columns` browser preseed already matches the canonical state; the sequence must reach `RESHAPE-BIND-OBSERVED`, then Mapping restore and `GRAPH-SINGLE-EDITOR ... load-ready`.

# v3.72.24 Editor hydration fast-path checkpoint

## Scope

This checkpoint keeps the v3.72.23 materialization boundary intact and focuses only on the persistent Graph Editor restore transaction.

## Canonical new-Graph default

The singleton Editor's pristine startup state is captured once as `graph_single_default_state()`. `create_graph()` obtains a deep-copied snapshot through `graph_single_default_state_snapshot()` and commits it to the Registry through `seed_new_graph_default_state()` before requesting Editor activation. There is no second hand-written set of default values.

## Restore progression

- RESHAPE/MAPPING browser binding checks are generation-scoped event transactions.
- `mapping-restore-binding-check` performs one requestAnimationFrame inspection and then reacts only to Shiny binding/input events; there is no 50 ms polling loop.
- The three 75 ms `invalidateLater()` loops were removed. Server restore observers progress when their actual reactive dependencies or ACK inputs change.
- Persistent-shell Wide→Long parent controls skip their browser binding ACK when their currently bound values already equal the saved canonical parent state.
- Mapping semantic defaults `shape=__color__` / `linetype=__color__` do not enter resync merely because a newly rebound control reports a transient NULL after its generation has already been ACKed.
- Persistent dynamic-style generation scoping removes the need for the extra post-reassert whole-server flush.

## READY / activation rule

`mod$ready()` already means staged restore and style finalization are complete. The outer single-Editor transaction now crosses one `session$onFlushed()` boundary and compares the loaded state with canonical RenderState instead of waiting for repeated whole-state equality. Canonical mismatch still gets one full-state reconcile attempt.

If that reconcile still fails, `graph_single_abort_activation()` releases the render gate and browser hydration mask and returns the selected Graph to preview browse. It does **not** reveal an Editor with no publish lease.

## Runtime validation targets

1. Load a project, browse several Graphs, then edit a cold Graph with Wide→Long enabled. RESHAPE-PARENT/RESHAPE-BIND/MAPPING-BIND must complete without timer polling.
2. Create a new Graph after editing a structurally different Graph. The new Graph must become editable and the `新規Graphを準備中…` overlay must clear.
3. Confirm the new Graph starts from the same canonical default state as a pristine startup Graph.
4. Reopen the new Graph after browsing/editing another Graph; no stale mapping/style values may appear.
5. Existing Graph switching with shared `Group` levels must retain each Graph's own dynamic style.
6. Figure → Graph Apply, Figure source materialization, and Selected/All Export must behave as v3.72.23.
7. An intentionally forced canonical mismatch must not leave the hydration overlay permanent; activation should fall back to browse.

## Build-environment limitation

The packaging environment does not provide `R` / `Rscript`. Static lexical/source/JS audits are performed here; the Windows R runtime checks above remain required.
