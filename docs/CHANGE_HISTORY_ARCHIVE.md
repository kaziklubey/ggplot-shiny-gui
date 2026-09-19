# 過去の詳細変更・検証履歴アーカイブ

このファイルは、旧バージョンごとに分散していたMarkdownの変更記録・検証記録・静的監査記録を1本に統合したものです。

- 現在版の概要: `../README.md`
- 短い時系列変更履歴: `../CHANGELOG.md`
- 現在版の詳細変更: `../V34_CHANGE_NOTES.md`
- 現在の保守原則: `../REFACTOR_CHECKPOINT.md`, `MAINTENANCE_RULES.md`

> 各節の本文は統合前の元Markdownを原則そのまま保存しています。`Source:` は旧ファイルのパスです。

> 旧版で生成された `STATIC_AUDIT.json`、`UNRESOLVED_INTERNAL_CALLS.csv`、`MODULE_API_USAGE.csv`、`FUNCTION_INDEX.csv` などの機械生成監査ファイルは、現行ソースツリーからは除外しています。必要な場合は過去のReleaseまたはGit履歴を参照してください。


---

# Release detailed change notes


## Source: `V33_CHANGE_NOTES.md`

# v3.73.2.33-doc-history-consolidation1

## Documentation consolidation

- Consolidated 90 historical/version-specific Markdown files into `docs/CHANGE_HISTORY_ARCHIVE.md`.
- The archive preserves the original Markdown text and records each former source path before its content.
- Historical top-level `V22_CHANGE_NOTES.md` through `V32_CHANGE_NOTES.md` are now stored in the archive.
- Historical `docs/V3_...TRACE.md`, `...STATIC_AUDIT_SUMMARY.md`, `docs/current/...VALIDATION.md`, and the previous pre-pivot archive are now stored in the same archive.
- Historical snapshot documents (`STAGED_REFACTOR_SUMMARY.md`, `SOURCE_ARCHITECTURE.md`, `SOURCE_INVENTORY.md`) were also moved into the archive because they describe older version-specific source states.
- Current maintainer documents remain separate: `CURRENT_ARCHITECTURE_AND_PLAN.md`, `FUNCTION_CATALOG.md`, `MAINTENANCE_RULES.md`, and `TEST_CHECKLIST.md`.
- `README.md` was rewritten as a concise Japanese user-facing guide, including startup, required runtime files, update checking, Project behavior, and documentation layout.
- `docs/README.md` was rewritten as the current documentation index.
- No Graph, Figure, Statistics, Project, or update-check runtime behavior was changed.


## Source: `V32_CHANGE_NOTES.md`

# v3.73.2.32-github-update-check1

## GitHub Release update check

- `run.bat` now invokes a focused `check_update.ps1` helper before starting Shiny.
- The helper reads the current version directly from `app_config.R`; no duplicate local version constant is maintained.
- Update source: `kaziklubey/ggplot-shiny-gui` GitHub Releases (`/releases/latest`).
- Version comparison uses the numeric dotted prefix, so tags such as `v3.73.2.32` compare cleanly with build names such as `v3.73.2.32-github-update-check1`.
- If a newer release exists, the console shows Current/Latest and lets the user press `U` to open the release page or Enter to continue with the installed version.
- Network failure, GitHub API failure, no published Release (404), PowerShell absence, or an unparseable release tag never blocks app startup.
- Set `GGPLOT_GUI_SKIP_UPDATE_CHECK=1` to disable the network check.
- No Shiny, GraphState, Figure, persistent Editor, or project persistence code is involved in update checking.

## Repository

`https://github.com/kaziklubey/ggplot-shiny-gui`

## Source: `V31_CHANGE_NOTES.md`

# v3.73.2.31-graph-settings-canonical-only1

- Graph Settings Manager の Graph-only / Graph+Figure canonical write 後に、dormant Graph へ hidden UI / graphServer materialization を起動しないよう整理。
- Settings Manager の Graph 書き込みは GraphState が正本なので、dormant Graph は canonical-only 更新とし、次回選択時に persistent Graph Editor が通常 replay する。
- 現在表示中の persistent Graph Editor owner が変更対象の場合だけ、従来どおり stale 化して即 replay。
- Figure 側は v29/v30 の明示 DIRECT-STATE 更新を維持。Graph-only 操作では Figure snapshot は自動更新しない。
- v30 で確認できた Figure-only direct edit と Inset snapshot preservation の挙動は変更しない。

狙い: Settings Manager 一括変更後の `MATERIALIZE -> READY rejected: module RenderState != canonical -> RESTORE-RETRY` ループを除去し、GraphState-first / persistent-single-editor 設計へ揃える。

## Source: `V30_CHANGE_NOTES.md`

# v3.73.2.30-graph-settings-feedback-inset-guard1

- External Graph / Figure Settings Manager now shows validation/success feedback inside the companion window instead of relying only on notifications in the main Shiny window. HTML numeric min/max validity is checked before submit, and server rejection logs now include the validation message and received value/type.
- Main Figure snapshot replacement now preserves the previous persisted Figure preview as an independent Inset snapshot when no explicit Inset snapshot exists. Refreshing a Graph used both as a Main panel source and an Inset source therefore no longer makes the Inset disappear.
- Figure refresh remains explicit DIRECT-STATE. No automatic Graph→Figure following, no hidden Graph editor, polling, or timer was added.

## Source: `V29_CHANGE_NOTES.md`

# v3.73.2.29-graph-settings-figure-edit1

## User-visible changes

- Popout table shows `G` (canonical GraphState) and `F` (Figure-owned state) for Graphs currently used as Figure main-panel sources.
- Click an editable G/F value to open a typed editor in the popout toolbar.
- Apply the edited value explicitly to Graph only, Figure only, or Graph + Figure.
- `FigureをGraphから更新` replaces selected Figure-owned main-panel GraphState/snapshots with the current canonical GraphState without changing GraphState itself.

## Architecture

- No second Shiny session, no extra Graph Editor, no timer/polling.
- Figure writes call the v22+ direct GraphState→Figure snapshot service.
- Persisted Figure SVG is deliberately bypassed for explicit Settings Manager Figure refresh, so READY and dormant Graphs follow the same path.
- Figure-only writes preserve Graph canonical state and Figure layout overrides.
- Existing v28 batch-copy input remains for compatibility; the v29 popout uses typed direct-value writes.

## Runtime diagnostics

Expected markers:

```text
GRAPH-SETTINGS-DIRECT ... scope=graph|figure|both
GRAPH-SETTINGS-FIGURE VALUE ... graph_state_unchanged=TRUE
GRAPH-SETTINGS-FIGURE REFRESH-FROM-GRAPH ... path=DIRECT-STATE persisted_svg_bypass=TRUE
FIGURE-SOURCE-SNAPSHOT ... READY path=DIRECT-STATE ...
```

## Source: `V28_CHANGE_NOTES.md`

# v3.73.2.28-graph-settings-batch1

## Scope

The external Graph Settings Manager is promoted from a read-only comparison/navigation view to a focused cross-Graph settings tool while preserving one canonical GraphState registry and one persistent Graph Editor.

- Rows with different current values are marked `差あり`.
- Graph columns can be selected independently; all Graphs are selected on the first open.
- Clicking an applicable value cell chooses it as the batch source. Selected target cells are then marked as matching or different from that source.
- `選択Graphへ適用` copies that one canonical GraphState field to selected Graphs after confirmation. This is a one-time copy, not a persistent synchronization link.
- Plot type and Mapping remain compare/jump-only to avoid invalid cross-data assignments. Batch copy is limited to labels, axes, sizing, legend placement, theme/font/palette, point/line/bar styling and error-bar styling exposed by the manager.
- Shared Library status is shown separately: Graph headers display the number of existing bindings and linked X/Y axis-label cells display `Shared`. Batch copy does not create, remove or alter Shared Library bindings.
- Figure snapshots are not refreshed or rewritten by a batch copy. Canonical Graph changes remain independent from already imported Figure snapshots.
- If the currently visible Graph is a changed target, its persistent Editor lease is marked stale and replayed immediately only when the user is already on the Graph workspace. Dormant Graph previews use the existing materialization service.

## Architecture

`server_graph_settings_batch_runtime.R` owns the explicit batch-write path. The manager validates requested paths against its own whitelist, reads the source value from canonical GraphState, updates only that nested target field, bumps the normal render revision when needed, and keeps Figure state untouched. No second Shiny session, hidden Graph Editor, timer or polling loop is introduced.

The popout remains a same-origin browser companion with no Shiny bindings of its own. It sends explicit batch requests back to the main session in the same way the v27 navigation bridge sends jump requests.

## Validation

The build is statically checked for JavaScript syntax, R delimiter/string balance, source references, merge markers and new timer/polling constructs. The v27 -> v28 patch is dry-run applied and the patched tree is compared byte-for-byte with the packaged v28 tree; ZIP CRC integrity is also checked. No R runtime is available in the build container, so interactive Shiny execution remains an on-machine validation step.

## Source: `V27_CHANGE_NOTES.md`

# v3.73.2.27-graph-settings-popout-jump1

Fixes navigation from the external Graph Settings Manager to the main Graph Editor.

- The same-origin companion window now calls the current opener's `ggplotGuiJumpToGraphSetting()` directly; `postMessage` remains only as fallback.
- Every settings jump first selects the requested Graph and opens the Graph workspace, then uses the existing persistent-editor activation path.
- Same-Graph READY jumps reveal the requested section/input immediately; other Graphs preserve the section/input until `graph-client-edit-ready`.
- Added `GRAPH-SETTINGS-JUMP` diagnostics so runtime logs confirm that the popout request reached the main Shiny session.
- No GraphState, Figure snapshot, plot calculation or editor ownership changes.

## Source: `V26_CHANGE_NOTES.md`

# v3.73.2.26-graph-settings-popout1

## Scope

- Added a prominent `全Graph設定を別ウィンドウで開く ↗` launcher in Figure > 共通Graph Label / Style.
- The companion window is created with `window.open()` and reused by name. Desktop browsers normally render the requested popup dimensions as a separate window; browser/user popup policy may still choose a tab or block it.
- The child window has no Shiny bindings and does not open the Shiny application URL. There is still exactly one Shiny session, one canonical GraphState registry and one persistent Graph Editor.
- The server converts the same canonical GraphState comparison used by the in-page manager into a read-only payload and sends it to the main client. Client JS caches the latest payload and redraws the companion window whenever values change.
- The companion preserves its table scroll position across data refreshes.
- `↗` in the companion sends a `postMessage` navigation request to the opener. The main window reuses the existing Settings Manager jump path: switch/select the Graph, open the relevant section, scroll to the input and highlight it.
- Reopening the launcher focuses/reuses the existing companion. A named window reacquired after a main-page reload is reinitialized so it cannot retain an obsolete opener bridge.
- The original in-page comparison remains available in a collapsed `画面内で全Graph設定一覧を見る` section as a fallback.

## Ownership / architecture

No Figure snapshot logic, GraphState schema, Graph replay path, graphServer lifecycle, or Shared Style persistence was changed. The external window is presentation-only and contains no hidden editor, replay barrier, polling loop or duplicated state owner.

## Validation

Static validation covers JavaScript syntax, R delimiter/string balance, source-file references, top-level function duplication, v25->v26 patch application/full-tree equality, and ZIP CRC integrity. This packaging environment does not contain R/Rscript, so browser popup behavior and Shiny runtime interaction must be verified on the Windows runtime.

## Source: `V25_CHANGE_NOTES.md`

# v3.73.2.25-graph-settings-manager1

Figure > 共通Graph Label / Style に、read-only の「全Graph設定一覧 / 設定へ移動」を追加。

- canonical GraphState から全Graphの主要設定を横並び表示。
- Mapping、Graph/X/Y title、Y range/breaks、Plot size、Legend、Theme/Font、Point/Line/Bar、Error barを比較可能。
- 各値の `↗` から、既存の persistent Graph Editor 1個へ移動し、該当セクションと入力欄を開いてハイライト。
- ManagerはGraphStateを直接変更しない。Shared Style Library / binding / Figure snapshot ownershipも変更しない。
- 同一GraphがすでにREADYならreplayせず、そのEditorをそのまま表示して該当入力へ移動する。
- 別Graphの場合だけ既存のGraph selection/replay transactionを使い、READY後に対象入力へ移動する。

これはShared Style Libraryを置換するものではなく、まず「現在どのGraphがどの値か」を見て、元設定へすぐ行ける入口を提供する最小版。

## Source: `V24_CHANGE_NOTES.md`

# v3.73.2.24-figure-legend-title-align-shared-style1

- Figure整列基準に `Axis＋凡例` を追加。通常の付随凡例をaxis bboxとの外接領域に含め、Auto/Fixed/Row個別基準で利用可能。Free legendはoverlayのため除外。
- `Graph title整列` を追加。同じRowのGraph titleをgtableのtitle bboxで検出し、Auto/Fixed Canvasの両方でタイトル上端を揃えられる。タイトル無しGraphは対象外。
- `共通Label / Style` を `共通Graph Label / Style` と明確化し、Library作成→Graph binding→Figure反映の3段階ガイドを追加。Panel label A/B/C の共通書式機能ではないこともUI上に明記。

No GraphState schema change. Existing projects using plot/facet/axis remain compatible.

## Source: `V23_CHANGE_NOTES.md`

# v3.73.2.23-figure-initial-panel-bootstrap1

Fixes the default Figure Panel 1 (`r1_c1`) staying blank until another panel/row or bulk import caused source snapshots to be loaded.

On Figure workspace activation, occupied main panels are checked once. A snapshot is created only when the panel has a source Graph and no Figure-owned in-session or persisted snapshot. Existing snapshots remain untouched, preserving Figure snapshot independence.

The bootstrap uses existing Figure-owned editable state when available, otherwise the READY Graph live snapshot fast path, otherwise the v22 direct GraphState snapshot route. No hidden UI, graphServer replay, or browser barrier is introduced.

## Source: `V22_CHANGE_NOTES.md`

# v3.73.2.22-direct-state-figure1

Figure assignment and bulk import no longer wait for a persistent Figure
renderer to replay UI values. Dormant Graphs are rendered synchronously from a
private GraphState copy, so snapshot creation cannot race mapping.y binding.

- GraphState data_text and reshape recipe are resolved before Mapping.
- Prepared data, summaries, external error bars, theme and the complete plot
  calculation are shared with the live Graph path. Plot calculation expressions
  are parsed once at startup and evaluated in a fresh computation scope.
- The snapshot payload includes the plot, panel dimensions, body, legend asset
  and body geometry. These components are retained by the Figure asset record.
- READY source Graphs retain the existing direct snapshot fast path.
- Main and Inset snapshots retain their separate storage and refresh semantics.
  Inset refresh does not replace the editable Main Figure state. Source Graph
  edits do not automatically update either snapshot.
- Snapshot jobs no longer mount or replay an editor, await a browser barrier,
  inspect Figure editor READY state, or change Figure editor ownership on exit.
  The visible Figure editor remains available for explicit editing.
- Request/revision/cancellation bookkeeping is retained. Explicit refresh
  reports failed attempts even when an older valid snapshot still exists.

Validation: R parser passed for all 62 top-level R files. The shared plot
calculation and nine data/theme helper bodies match v21 at the AST level.
Static checks confirm the direct state route contains no reactive creation,
graphServer replay, hidden UI or browser transaction. No application launch,
plot rendering, visual comparison or runtime interaction tests were performed.

The ZIP is a complete application folder. The accompanying patch applies to
the contents of the original v21 application folder (git apply -p1). Patch
application and full-tree byte equality, plus ZIP CRC integrity, are checked
when packaging. Keep the original v21 ZIP as the rollback copy.

---

# Version-specific trace / audit / validation documents


## Source: `docs/V3_73_2_29_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.29 static audit summary

Version: `v3.73.2.29-graph-settings-figure-edit1`

## Scope

- External Settings Manager only plus focused Graph/Figure write services.
- No GraphState schema change.
- No Figure layout schema change.
- No second Shiny session, hidden Graph editor, timer, polling loop, or browser semantic reconciliation added.

## Ownership paths

1. `Graphへ適用`
   - Writes canonical GraphState.
   - Uses the existing Graph revision/materialization/editor-stale handling.
   - Does not automatically update Figure.

2. `Figureだけへ適用`
   - Writes only Figure-owned GraphState for Figure main-panel source Graphs.
   - Rebuilds the Figure snapshot through `request_figure_source_snapshot(..., state_override=...)`.
   - Canonical GraphState is not changed.

3. `Graph + Figure`
   - Executes the two explicit ownership writes above with the same normalized scalar value.

4. `FigureをGraphから更新`
   - Copies the current canonical GraphState into Figure-owned state for selected Figure main-panel Graphs.
   - Always requests a DIRECT-STATE Figure snapshot.
   - Does not consult/use a persisted Figure SVG as a shortcut.

## UI

- The popout is isolated in `www/graph_settings_popout.js` rather than growing `app_client.js` further.
- G = canonical GraphState.
- F = Figure-owned GraphState.
- Typed editors are provided for the safe scalar settings exposed by the manager.
- Mapping and Plot type remain comparison/navigation-only.
- Palette remains comparison/navigation-only because selecting a palette in the normal Graph UI does not itself materialize `color_styles`; the separate palette-apply action does that.

## Static validation

- `node --check` passes for `www/app_client.js` and `www/graph_settings_popout.js`.
- Modified R files pass delimiter/string balance scanning.
- New Figure write runtime contains no `graphServer`, timer, polling, `invalidateLater`, or `Sys.sleep` path.
- New Figure refresh path calls the existing direct snapshot service and logs `persisted_svg_bypass=TRUE`.

No R runtime or browser interaction test was available in the build environment; Windows Shiny runtime verification is still required.

## Source: `docs/V3_73_2_21_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.21 value-replay live Figure static audit

- Normal Graph runtime: no `mod$load_state()`, `start_state_restore`, `VERIFY-MISS`, or canonical-reconcile execution path.
- Figure runtimes: no `request_graph_materialization()` or `graph_materialization_signal()` calls for Main, Legend, or Inset source generation.
- Live render invalidation is split from attach release so `project_settings()` remains a persistent reactive dependency.
- Wide→Long/Mapping observers use the normal reactive pipeline; only destructive auto-disable is deferred while replay is active.
- JavaScript syntax checked with `node --check`.
- All literal R source references resolve; R delimiter/string static scan passes. R/Rscript is unavailable in the build container, so an actual Shiny runtime parse/test must be performed on the Windows test machine.

## Source: `docs/V3_73_2_20_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.20 style-state migration static audit

## Runtime issue addressed

Windows v3.73.2.19 logs showed a legacy Scatter Graph repeatedly failing canonical activation on `style.raw_group_colors.Group`. The live Editor deterministically filled missing raw group colours, while the saved canonical GraphState retained the incomplete legacy tree. Reconcile therefore repeated and then aborted. The same trace also showed an initial `mean_color_mode` representation mismatch.

## Changes

- Added focused pure `graph_style_state_migration.R`.
- GraphState schema is 4.
- Legacy states materialize deterministic color/shape/linetype/raw-color defaults before replay.
- Legacy `mean_color_mode` is normalized to canonical hex.
- Scatter RenderState excludes `raw_group_colors`; it also excludes fixed `mean_color_mode` when Color Mapping is active.
- No structural restore, polling, extra Editor instance, or Graph SVG cache was added.

## Static checks

- JavaScript syntax checked with `node --check`.
- R lexical delimiter/string balance checked across all top-level R sources.
- Source registry references verified to point to existing files.
- Packaging environment has no R/Rscript; Windows runtime validation remains required.

## Source: `docs/V3_73_2_19_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.19 state replay value-swap static audit

## Scope

This release makes the persistent Graph Editor value-only after startup. Ordinary Graph switches and Project load do not structurally hydrate/rebuild the Editor.

## Key invariants checked

- `graph_single_load()` starts in `REPLAY`, not `HYDRATING`.
- Normal Graph ownership code has no `mod$load_state()` fallback.
- A missing legacy `ui_snapshot` is reconstructed in R by `graph_state_prepare_replay_snapshot()` from canonical `data_text`, reshape, mapping and plot state.
- Project load migrates GraphStates before inserting them into the Registry.
- Replay verification misses are released to one value-only canonical replay retry; persistent failure aborts instead of calling structural restore.
- Browser Graph switching does not add `client-editor-hydrating` and does not show `Graph設定を同期中…`.
- Only the persistent live Plot is visually masked while a target Graph is replayed/rendered.
- No timer/polling primitive was added.

## Static checks

- 56 top-level R files: delimiter/string/comment balance check passed.
- `www/app_client.js`: `node --check` passed.
- Literal internal `source()` / `sys.source()` targets: all present.
- Merge conflict markers: none.
- Normal Graph switch/Project-load source scan: no `mod$load_state()` caller.
- User-visible Graph-switch `同期中` strings: removed from current runtime paths.

## Runtime limitation

R/Rscript is not installed in the packaging environment, so Windows Shiny runtime validation is still required.

## Expected old-project log shape

A legacy `.ggplotpack` without `ui_snapshot` should now show approximately:

```text
PROJECT-STATE-MIGRATION ... no Editor hydrate required
EDITOR-ACTIVATION ... source=project-load-state-first
GRAPH-SINGLE-EDITOR ... mode=REPLAY
GRAPH-STATE-REPLAY ... begin
GRAPH-EDIT-STATE-REPLAY ... browser-flush complete
GRAPH-EDIT-STATE-REPLAY ... READY
GRAPH-EDIT-PLOT ...
GRAPH-SINGLE-EDITOR ... load-ready ... path=REPLAY
```

It should not show `RESHAPE-BIND`, `MAPPING-BIND`, `RESTORE-RESYNC`, or a Graph-side `mode=HYDRATING` for Project attachment.

## Source: `docs/V3_73_2_18_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.18 state-replay static audit summary

- R lexical delimiter/string scan: PASS (56 `.R` files).
- Literal `source()` / `sys.source()` target existence: PASS (52 references, all targets present).
- Named-function scan: 634 definitions; duplicate-name count did not increase relative to v3.73.2.13.
- Calls to project functions removed by this refactor: 0 dangling references detected.
- Removed normal Graph-cache / identity-fast-path symbols: 0 residual R/JS references.
- New-project Graph SVG writer: absent; manifest keeps only an empty compatibility `previews` field while Figure snapshot assets remain serializable.
- JavaScript syntax (`node --check www/app_client.js`): PASS.
- JavaScript custom message handlers: unique (no duplicate handler registration introduced).
- Timer/polling delta relative to v3.73.2.13: 0 for `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactiveTimer`, `reactivePoll`, and `later::later`.
- Merge/conflict markers: none.
- R/Rscript parse/runtime test: unavailable in the packaging environment; Windows Shiny runtime acceptance is required.

## Required Windows acceptance

1. Fresh launch: g001 reaches READY and renders once without a blank/stale Plot.
2. Create New Graph and Duplicate; edit Data/Mapping/Style differently and verify A -> B -> A state replay has no cross-Graph UI bleed.
3. Rapidly select multiple Graph tabs; only the latest queued target should own the Editor after the in-flight transaction finishes.
4. Save/reopen a new `.ggplotpack`; verify GraphState/UI state restores and the package contains no `preview/graph_*.svg` files.
5. Open a legacy project that contains Graph preview SVG; verify it loads through compatibility fallback and a re-save does not reproduce Graph SVG previews.
6. Statistics Plot preview renders on request without becoming Graph display authority.
7. Figure import/update remains explicit: later Graph edits must not mutate already imported Figure Main/Legend/Inset snapshots.
8. Figure Inset and legend/body editing still render/export/save correctly.

## Source: `docs/V3_73_2_13_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.13 static audit summary

- R lexical scan: PASS (56 files)
- source target existence: PASS (52 references)
- function index: PASS (645 functions)
- new/changed duplicate function names: 0
- unresolved project-internal calls: base=0 -> patched=0 (PASS)
- shared graphServer runtime binding collisions: 0
- shared server runtime binding collisions: 0
- removed-symbol residual references: 0
- JavaScript syntax/handler duplication: PASS
- timer/polling additions: {'invalidateLater': 0, 'later::later': 0, 'setTimeout': 0, 'setInterval': 0, 'MutationObserver': 0} (PASS)
- Statistics runtime unchanged: PASS
- Figure reorder block unchanged: PASS
- R/Rscript runtime parse: unavailable in packaging environment; Windows runtime test required.

## Source: `docs/V3_73_2_13_FAST_EQUIVALENT_SWITCH.md`

# v3.73.2.13 fast equivalent Graph switch

## Goal

Avoid paying the full persistent-Editor restore / Preview handshake / renderPlot transaction when the selected Graph has the same editor state and semantic RenderState as the plot already held by the singleton Editor.

## Fast-path contract

The path is accepted only when all of the following are true:

- a different Graph currently owns the singleton Editor and that owner is READY;
- the owner still holds the current canonical revision lease;
- current Editor GraphState and target canonical GraphState are equal after normalizing only Project-global `project_name` and NULL/empty external-error selectors;
- `mod$rendered_state()` equals the target `graph_render_state()`;
- the source Preview record is fresh for that same RenderState; and
- the module can adopt the target canonical attachment without creating a pending render.

On success the switch updates Graph identity, revision lease and visit metadata, clones/reuses the equivalent Preview record, and sends a lightweight browser retarget. It deliberately skips `graph-client-edit-begin`, restore/sync, render-gate closure, cached/live Preview ACK handshake, Shiny unbind/rebind, and `renderPlot`.

Any failed condition falls through to the existing transaction unchanged.

## Sample template cleanup

The built-in line sample keeps `mapping$id = ""`, matching the actual line Mapping UI default. This removes the immediately-following `ID -> empty` canonical commit seen in v3.73.2.12.

## Source: `docs/V3_73_2_12_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.12 static audit summary

- R lexical scan: PASS (55 files)
- source target existence: PASS (51 references)
- function index: PASS (637 functions)
- new/changed duplicate function names: 0
- unresolved project-internal calls: base=0 -> patched=0 (PASS)
- shared graphServer runtime binding collisions: 0
- shared server runtime binding collisions: 0
- removed-symbol residual references: 0
- JavaScript syntax/handler duplication: PASS
- timer/polling additions: {'invalidateLater': 0, 'later::later': 0, 'setTimeout': 0, 'setInterval': 0, 'MutationObserver': 0} (PASS)
- Statistics runtime unchanged: PASS
- Figure reorder block unchanged: PASS
- R/Rscript runtime parse: unavailable in packaging environment; Windows runtime test required.

## Source: `docs/V3_73_2_12_SAMPLE_TEMPLATE.md`

# v3.73.2.12 — canonical sample template

## Problem

The UI displayed the built-in sample dataset and automatically selected `Group` / `Post`, but the captured default GraphState still contained empty Mapping values. This created two startup authorities and required an input change / Graph round-trip before canonical state and UI converged.

## Contract

```text
built-in sample data
    +
static Editor shell defaults
    |
    v
graph_sample_graph_state()
    |
    +--> deep copy -> g001 Registry state
    +--> deep copy -> every New Graph Registry state

Duplicate -> source GraphState deep copy (unchanged)
```

The persistent Editor consumes/restores canonical GraphState. It is not responsible for inventing the initial Mapping of a New Graph.

## Built-in sample mapping

For the shipped sample dataset the deterministic Mapping policy resolves to:

- X: `Group`
- Y: `Post`
- ID: `ID`
- Color: fixed / empty
- Shape/Linetype: follow Color sentinel

The same sample text is used by `graphUI()` and the canonical template.

## Source: `docs/V3_73_2_11_POSTBIND_DEFAULT.md`

# v3.73.2.11 post-bind default capture

## Problem

The persistent Graph Editor default was intended to be captured after the first
browser/Shiny flush, when data-dependent Mapping defaults are established.
However `ensure_graph_single_editor_module()` also captured the state immediately
at module creation. `capture_graph_single_default_state()` is write-once, so the
later `startup-post-bind` capture always became a no-op.

That left the reusable new-Graph default with pre-bind Mapping values. The live
Mapping controls later selected their data-dependent X/Y defaults, so canonical
GraphState and live GraphState repeatedly diverged at `mapping.x` / `mapping.y`.

## Change

- remove the immediate `module-create` default capture;
- keep `startup-post-bind` as the one authoritative initial capture;
- remove the later startup special-case that tried to promote a READY snapshot
  into another default authority;
- keep ordinary canonical compare/reconcile as the single READY acceptance path;
- add X/Y values to default-capture/finalize and Preview mismatch diagnostics.

No timer/polling path is added. Graph creation, singleton Editor restore, Preview
ACK handshake, Statistics, and Figure ordering are otherwise unchanged.

## Source: `docs/V3_73_2_11_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.11 static audit summary

- R lexical scan: PASS (55 files)
- source target existence: PASS (51 references)
- function index: PASS (635 functions)
- new/changed duplicate function names: 0
- unresolved project-internal calls: base=0 -> patched=0 (PASS)
- shared graphServer runtime binding collisions: 0
- shared server runtime binding collisions: 0
- removed-symbol residual references: 0
- JavaScript syntax/handler duplication: PASS
- timer/polling additions: {'invalidateLater': 0, 'later::later': 0, 'setTimeout': 0, 'setInterval': 0, 'MutationObserver': 0} (PASS)
- Statistics runtime unchanged: PASS
- Figure reorder block unchanged: PASS
- R/Rscript runtime parse: unavailable in packaging environment; Windows runtime test required.

## Source: `docs/V3_73_2_10_ACCEPT_BOUNDARY.md`

# v3.73.2.10 accepted-canonical boundary

## Why v3.73.2.9 still failed

The Windows log showed two separate failures:

1. Startup g001 promoted the live Mapping defaults into the Registry, but `attached_state_seed` still held the earlier pristine seed. When the render gate opened, the module released that stale attachment, producing a Preview mismatch at `mapping.x` / `mapping.y`.
2. New g002 finished the staged restore and emitted its internal READY timing mark, but the module-level READY predicate additionally required a full live `project_settings()` snapshot. That second gate could remain unavailable even though all restore/binding checks had completed, leaving the outer editor transaction stuck.

## Contract

```text
canonical GraphState in Registry
        ↓
restore/sync canonical into singleton Editor
        ↓
Mapping/reshape/style binding verification
        ↓
module READY
        ↓
outer canonical arbitration
        ↓
module accept_canonical(Registry state)
        ├─ attached_state_seed := accepted canonical
        └─ pending RenderState := accepted canonical
        ↓
Preview bind/auth ACK
        ↓
render gate OPEN
        ↓
release the exact accepted target once
        ↓
make_plot / renderPlot / SVG preview
```

`project_settings()` remains live browser state for normal edits and persistence. It is not a second Graph-switch READY gate.

## Source: `docs/V3_73_2_10_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.10 static audit summary

- R lexical scan: PASS (55 files)
- source target existence: PASS (51 references)
- function index: PASS (635 functions)
- new/changed duplicate function names: 0
- unresolved project-internal calls: base=0 -> patched=0 (PASS)
- shared graphServer runtime binding collisions: 0
- shared server runtime binding collisions: 0
- removed-symbol residual references: 0
- JavaScript syntax/handler duplication: PASS
- timer/polling additions: {'invalidateLater': 0, 'later::later': 0, 'setTimeout': 0, 'setInterval': 0, 'MutationObserver': 0} (PASS)
- Statistics runtime unchanged: PASS
- Figure reorder block unchanged: PASS
- R/Rscript runtime parse: unavailable in packaging environment; Windows runtime test required.

## Source: `docs/V3_73_2_9_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.9 static audit summary

- R lexical scan: PASS (55 files)
- source target existence: PASS (51 references)
- function index: PASS (634 functions)
- new/changed duplicate function names: 0
- unresolved project-internal calls: base=0 -> patched=0 (PASS)
- shared graphServer runtime binding collisions: 0
- shared server runtime binding collisions: 0
- removed-symbol residual references: 0
- JavaScript syntax/handler duplication: PASS
- timer/polling additions: {'invalidateLater': 0, 'later::later': 0, 'setTimeout': 0, 'setInterval': 0, 'MutationObserver': 0} (PASS)
- Statistics runtime unchanged: PASS
- Figure reorder block unchanged: PASS
- R/Rscript runtime parse: unavailable in packaging environment; Windows runtime test required.

## Source: `docs/V3_73_2_9_STATE_CONTRACT.md`

# v3.73.2.9 live READY/default state contract

## Observed failure in v3.73.2.8

The plot builder completed, but preview publication was rejected because the completed/live RenderState did not equal the Registry canonical RenderState. The startup canonical seed had been captured before data-dependent browser defaults such as X/Y Mapping were fully available. `module_api$state()` could then return `attached_state_seed()` during READY arbitration, allowing the outer transaction to compare canonical state with its own fallback instead of a live browser projection.

A second semantic mismatch came from dormant Wide->Long controls: `reshape.columns` could change while `reshape.enabled == FALSE`, even though those values cannot affect the plot.

## Contract after v3.73.2.9

1. Registry remains the canonical GraphState owner.
2. The persistent Graph Editor remains one module instance.
3. Restore flags alone do not make the module READY. READY also requires a readable live `project_settings()` snapshot.
4. `attached_state_seed()` remains a remount/save safety snapshot, but cannot by itself satisfy READY arbitration.
5. On startup g001 only, the first live pristine GraphState is promoted to canonical g001 and to the reusable new-Graph default template.
6. New Graphs copy that finalized template. There is no separate new-Graph render/bootstrap path.
7. RenderState collapses dormant reshape fields while reshape is OFF.
8. Preview publication logs exact RenderState mismatch paths when a guard rejects publication.

No polling, timers, per-Graph Editor cache, or second render-acceptance state machine was added.

## Source: `docs/V3_73_2_8_SOURCE_CLEANUP_AUDIT.md`

# v3.73.2.8 source cleanup audit

## Scope

This checkpoint removes only code that was confirmed unreachable in the active v3.73.2.7 call graph, repairs dangling internal calls, and corrects current-architecture comments. Zero-caller pure helpers were **not** deleted solely on heuristic reachability; they remain listed for later individual review.

## Confirmed removals

- Removed the alpha-era graphServer-local Figure -> Graph UI-input commit transaction (`figure_commit_pending`, `figure_commit_status_state`, `figure_commit_serial`, `figure_commit_input_matches()`, `finish_figure_commit()`, `cancel_figure_commit()`, `apply_figure_patch()`). Current Figure Apply remains the server-level Registry transaction.
- Removed dead module API members: `apply_figure_patch`, `cancel_figure_commit`, `finish_figure_commit`, `figure_commit_status`, `raw_data`, `plot_source_data`, `drawn`, and transitional `load_state_direct`.
- `graph_module.R` reduced from 551 lines to 354 lines.
- Named-function count reduced from 640 to 634 without adding replacement wrappers.

## Dangling calls repaired

1. `graph_completed_render_state_snapshot()` no longer exists. `graph_output_runtime.R` now records the already completed `plot_last_built_render_state()` directly after `panel_sized_plot()` succeeds. This preserves the no-browser-reread rule without recreating a helper layer.
2. `figure_source_at_key()` was a stale rename in Figure Copy Style. It now calls the existing canonical helper `figure_layout_source_at_key()`.

Static unresolved-project-call scan: **2 -> 0**.

## Module API after cleanup

Every remaining `graphServer` module API member has at least one current R caller. Zero-caller API members after cleanup: **0**. See `V3_73_2_8_MODULE_API_USAGE.csv`.

## Comments / docs corrected

- `attached_state_seed` now documents its actual role: READY arbitration plus one accepted-canonical first-render release.
- `server.R` comments now describe Editor-first selection rather than historical browse-only ownership.
- `SOURCE_ARCHITECTURE.md` now describes the current single READY arbitration / accepted-canonical render release.
- `SOURCE_INVENTORY.md` was regenerated from the current shipped tree instead of retaining v3.72.27 line counts.

## Deferred cleanup candidates

The following zero-R-caller named helpers remain intentionally untouched pending semantic/manual review:

- `figure_extract_legend_grob()` — `figure_export.R:40`
- `figure_valid_bbox()` — `figure_renderer.R:400`
- `figure_asset_has_svg()` — `figure_asset.R:22`
- `figure_asset_source_choices()` — `figure_asset.R:83`
- `app_function_catalog()` — `app_function_catalog.R:1`
- `figure_plot_spec_for_rect()` — `figure_layout.R:1031`
- `figure_legend_handle_position()` — `figure_layout.R:1152`
- `figure_default_workspace_state()` — `figure_state.R:317`

These are not release blockers and should not be deleted merely because the in-app R call graph is empty; external maintenance/debug use must be checked first.

## Protected areas

- `graph_statistics_runtime.R`: byte-identical to v3.73.2.7.
- Figure reorder block: unchanged.
- No new timer/polling mechanism.
- Preview ACK handshake and full-screen hydration mask were not simplified.

## Runtime limitation

R/Rscript is unavailable in the packaging environment, so actual Shiny parse/runtime behavior must still be verified on Windows.

## Source: `docs/V3_73_2_8_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.8 static audit summary

- R lexical scan: PASS (55 files)
- source target existence: PASS (51 references)
- function index: PASS (634 functions)
- new/changed duplicate function names: 0
- unresolved project-internal calls: base=2 -> patched=0 (PASS)
- shared graphServer runtime binding collisions: 0
- shared server runtime binding collisions: 0
- removed-symbol residual references: 0
- JavaScript syntax/handler duplication: PASS
- timer/polling additions: {'invalidateLater': 0, 'later::later': 0, 'setTimeout': 0, 'setInterval': 0, 'MutationObserver': 0} (PASS)
- Statistics runtime unchanged: PASS
- Figure reorder block unchanged: PASS
- R/Rscript runtime parse: unavailable in packaging environment; Windows runtime test required.

## Source: `docs/V3_73_2_7_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.7 static audit summary

Scope: simplify the persistent Graph Editor render transaction by removing the post-READY bootstrap layer, separating RenderState semantics from generic state diffing, and collapsing inactive external-error controls.

## Results

- R lexical delimiter/string scan: PASS (55 top-level R files, 0 errors).
- `sys.source()` target existence: PASS (25 references, 0 missing).
- Function duplicate delta vs v3.73.2.6: PASS (no new/changed duplicate names).
- Function Index: PASS (640 source functions, 640 indexed, exact match).
- JavaScript syntax: PASS (`app_client.js`, `figure_interaction.js`).
- Duplicate Shiny custom message handlers: none.
- Timer/polling delta: PASS (`invalidateLater` 0→0, `later::later` 0→0, `setTimeout` 16→16, `setInterval` 0→0).
- Statistics runtime unchanged: PASS.
- Figure reorder block unchanged: PASS.
- R/Rscript runtime parser was not available in the packaging environment.

## Structural checks

- `graph_render_bootstrap_runtime.R` removed.
- `graph_normalize_new_graph_state()` removed.
- Shared UI default helpers retained in `graph_data_defaults.R` only.
- RenderState contract moved from `app_state_diff.R` to `graph_render_state.R`.
- Persistent Editor still uses one mounted Graph module; no per-Graph Editor DOM/module/cache was added.
- Preview ACK handshake, generation/reconcile barrier and full-screen hydration mask are unchanged.

## Source: `docs/V3_73_2_6_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.6 Static Audit Summary

Release: `v3.73.2.6-new-graph-bootstrap1`
Base: `v3.73.2.5-render-state-boundary-refactor1`

Scope: deterministic canonical defaults for genuinely new Graphs and an explicit first-render bootstrap boundary for the single persistent Graph Editor.

## Results

- R lexical delimiter/string scan: PASS — 55 `.R` files, 0 errors.
- `sys.source()` target existence: PASS — 26 references, 0 missing targets.
- Function declarations / Function Index: PASS — 650 source functions and 650 index entries, exact match.
- Duplicate function names: PASS — no new or changed duplicate-name collisions; the same 8 pre-existing duplicate-name sets remain.
- JavaScript syntax: PASS — `www/app_client.js` and `www/figure_interaction.js` pass `node --check`.
- Shiny custom message handlers: PASS — 36 + 5 handlers, no duplicate handler names in either file.
- Timer/polling diff: PASS — `invalidateLater` 0→0, `later::later` 0→0, `setTimeout` 16→16, `setInterval` 0→0.
- Statistics runtime: unchanged.
- Figure reorder block: unchanged.

## Architecture check

- New deterministic default selection is isolated in `graph_new_graph_defaults.R`.
- First-render release logic is isolated in `graph_render_bootstrap_runtime.R`.
- `graph_data_runtime.R` now calls the shared pure default functions instead of maintaining duplicate Mapping/reshape default algorithms.
- No per-Graph Editor DOM/module cache was introduced.
- No Graph READY polling/timer workaround was introduced.
- Existing saved/duplicated GraphState is not normalized by the new-Graph normalizer; only genuinely pristine/new Graphs use it.

## Runtime limitation

R / Rscript is not installed in the audit container, so Shiny runtime launch was not executed here. Windows runtime verification is still required.

## Source: `docs/V3_73_2_5_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.5 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (53 files).
- `sys.source()` targets: PASS (25 references, 0 missing).
- New/changed top-level/nested function-name collisions: PASS (0).
- Function index: PASS (637 scanned / 637 indexed).
- JavaScript syntax / custom-message handler duplication: PASS.
- Timer diff vs v3.73.2.4: `invalidateLater` 0→0, `later::later` 0→0, `setTimeout` 16→16, `setInterval` 0→0.
- Statistics runtime unchanged: PASS.
- Figure reorder block unchanged: PASS.

## Architecture check

The change removes the inline state-fallback/Plot-revision path from `graph_state_runtime.R` and introduces two focused runtimes: `graph_state_boundary_runtime.R` and `graph_render_error_runtime.R`. New top-level functions are small/focused (maximum 63 lines); the installer/wiring function is 25 lines. `graph_state_runtime.R` shrinks by roughly 80 lines and `graph_output_runtime.R` by roughly 25 lines instead of growing.

## Runtime limitation

R/Rscript is unavailable in the packaging environment, so Windows runtime validation is still required.

## Source: `docs/V3_73_2_4_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.4 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (51 files).
- `sys.source()` targets: PASS (23 references, 0 missing).
- New/changed top-level or local function-name duplicates relative to v3.73.2.3: PASS (0).
- Function Index: PASS (629 scanned / 629 indexed, exact match).
- JavaScript `node --check`: PASS.
- Custom-message handler duplicates: PASS.
- Timer delta vs v3.73.2.3: `invalidateLater` 0 -> 0; `later::later` 0 -> 0; `setTimeout` 16 -> 16; `setInterval` 0 -> 0.
- Statistics runtime unchanged: PASS.
- Figure reorder block unchanged: PASS.

## Focused regression fix

The v3.73.2.3 Windows log showed that a newly-created `g002` completed Mapping stage 3, FINAL, and READY, but `GRAPH-SINGLE-STATE-DIFF` repeatedly reported `<missing-state>`. Canonical state itself existed (`canonical_revision=1`); the missing value was the singleton module state snapshot used for READY arbitration. Reconcile therefore retried a full sync and aborted activation without changing the underlying condition.

v3.73.2.4 keeps one attached canonical GraphState safety snapshot inside the one persistent Graph Editor. When browser-backed `project_settings()` is temporarily unavailable while dynamic UI is being rebound, `module_api$state()` and semantic Plot revision arbitration may use that attached state instead of returning NULL. Successful live state snapshots refresh the safety copy. This does not add per-Graph Editor state, warm DOM, background modules, retries, timers, or polling.

## Scope / limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. Windows runtime validation should confirm that a new Project can add `g002`, reach `load-ready` without `<missing-state>` / canonical-reconcile abort, and enter the Editor normally. Figure legend behavior should remain as in v3.73.2.3, where initial materialization uses display-hold/release and subsequent side/free changes reuse the live Figure snapshot.

## Source: `docs/V3_73_2_3_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.3 static audit summary

Target: `v3.73.2.3-graph-create-legend-single-paint1`
Base: `v3.73.2.2-figure-legend-materializer1`

- R lexical scan: **PASS** — 51 `.R` files, 0 delimiter/string errors.
- `sys.source()` existence: **PASS** — 23 references, 0 missing targets.
- Function duplicate delta: **PASS** — no new/changed duplicate function names versus v3.73.2.2.
- Function Index: **PASS** — 628 declarations, exact source/index match.
- JS syntax/handler audit: **PASS** — Node parse OK; no duplicate Shiny custom-message handler names.
- Timer diff: **PASS** — base=16, patched=16; added=0 for `invalidateLater`, `later::later`, `setTimeout`, `setInterval`.
- Statistics runtime: **UNCHANGED**.
- Figure reorder transaction block: **UNCHANGED**.
- Patch roundtrip: **PASS** — repeated after final audit-status update.
- ZIP roundtrip: **PASS** — final package extraction hash tree verified against source.

## Focused checks

### New Graph activation

Cold structural hydrate now places an event-driven `session$onFlushed(..., once=TRUE)` barrier between Mapping restore messages and stage 3. This avoids reading inputs while `freezeReactiveValue()` is still active in the same flush. The pristine default Graph template is finalized from the normalized first Graph state when the startup editor reaches READY.

Expected Windows diagnostic sequence after adding a Graph:

`GRAPH-SINGLE-DEFAULT -> EDITOR-ACTIVATION -> MAPPING-BIND ... restore values sent -> stage3 browser-flush barrier queued -> stage3 start after browser flush -> HYDRATE-UI stage3 mapping committed -> RESTORE FINAL -> GRAPH-SINGLE-EDITOR load-ready`.

### Figure legend single-paint

When a persisted Figure SVG needs the lazy materializer, authored changes remain in `figure_override_drafts` while the visible `figure_requested_overrides` stays at the previous value for that source id. Workspace auto-mirroring and plot-signature invalidation use the same visible/held override. The completed Figure-owned snapshot and newest draft override are then released in the same reactive turn.

Expected first materialized legend transition:

`FIGURE-OVERRIDE -> FIGURE-LEGEND-MATERIALIZE needed=TRUE -> display-hold -> ... materializer make_plot ... -> snapshot-installed -> display-release -> FIGURE-LEGEND-BBOX -> FIGURE-LAYER`.

There should be no earlier `FIGURE-LAYER` for the newly selected legend mode before `snapshot-installed`.

## Runtime limitation

This packaging environment has no `R`/`Rscript`, so Shiny runtime execution cannot be performed here. Windows validation is still required for new-Graph activation and the Figure legend sequence.

## Source: `docs/V3_73_2_2_STATIC_AUDIT_SUMMARY.md`

# v3.73.2.2 static audit summary

Target: `v3.73.2.2-figure-legend-materializer1`

- R lexical scan: **PASS** — 51 `.R` files, 0 delimiter/string errors.
- `sys.source()` existence: **PASS** — 23 references, 0 missing targets.
- Function duplicate delta: **PASS** — no new/changed duplicate function names versus v3.73.2.
- Function Index: **PASS** — 623 declarations, exact source/index match.
- JS syntax/handler audit: **PASS** — Node parse OK; no duplicate Shiny custom-message handler names.
- Timer diff: **PASS** — base=16, patched=16, added=0 for `invalidateLater`, `later::later`, `setTimeout`, `setInterval`.
- Statistics/reorder logic: **UNCHANGED**.
- Patch roundtrip: **PASS** (repeated after this audit file is added during packaging).
- ZIP roundtrip: **PASS** — package extraction tree matches the source package exactly (repeated after this status update).

## Runtime limitation

This container has no `R`/`Rscript`, so the Shiny app itself cannot be launched here. Windows validation should run the legend sequence `inherit → left → right → top → bottom → none → free → inherit` and confirm each visual plus `FIGURE-OVERRIDE`, `FIGURE-LEGEND-BBOX`, `FIGURE-LAYER` and `FIGURE-LEGEND-MATERIALIZE` diagnostics.

## Source: `docs/V3_73_2_FIGURE_CONTROL_SURFACE_TRACE.md`

# v3.73.2 Figure control-surface trace

## Scope

This release reorganizes the Figure editor surface without changing GraphState ownership or the established Row/Free geometry engine.

- The user-facing Advanced Figure accordion is removed.
- Canvas mode, Fixed width/height, Auto-fit policy and manual refit are returned to Step 2 `配置・整列`.
- SVG Preview mode is returned to the Preview toolbar.
- Step 2 is split into compact visible `Canvas` and `Layout` cards, while Row/Panel structure and reorder controls remain discoverable subsections.
- `figure_gap_x` / `figure_gap_y` are labeled as Panel gaps. In Fixed mode the outer Canvas remains fixed; gaps consume space inside that Canvas and therefore reduce the allocated Panel slots.

## Placement reset contract

`自由配置の位置を初期化` is selected-Panel-only and placement-only.

It resets Figure-owned free-placement coordinates for Panel label, free legend, Inset and external legend. A detached legend re-arms its source-position bootstrap. It does not change Graph/Asset order, Crop, Graph content/style, legend mode, Inset source/enabled state, Graph size or Row/Column structure.

## Detached/free legend safety

Compound guide boxes are detached as one complete guide-box asset, so Graphs with multiple guides do not lose secondary legends. Preview, Project persistence and Figure export use the same guide-box selection helper.

Detachment is fail-safe: if a valid detached legend asset cannot be produced, the owner falls back to the combined Graph with its attached legend rather than showing a legend-free body with no overlay.

## Architecture guards

- One persistent Graph Editor and one Figure Editor remain unchanged.
- Figure snapshots remain independent of source Graphs.
- `figure_layout.R` and `figure_layers.R` are unchanged from v3.73.1.7.
- No timer/polling or JavaScript message-handler changes are introduced.

## Source: `docs/V3_73_1_6_FIGURE_LAYOUT_REORDER_STABILITY_TRACE.md`

# v3.73.1.6 Figure layout / reorder stability trace

## Ownership contract

- Slot-owned: `key`, row/column identity, cell width, free-frame geometry/z-index, Panel label text/geometry.
- Content package moved by Row/Grid reorder: `id`, `source_type`, `source_id`, `graph_width`, `graph_height`.
- Source-owned registries keyed by source id therefore follow automatically: Figure override (Crop / free legend / Inset / appearance), editable Figure GraphState snapshot, loaded/persisted Figure snapshot.

## Reorder transaction

1. Build candidate content reorder (`swap`, `shift`, adjacent swap, or canonical-order reset).
2. Validate identical slot keys and identical slot-owned state for every slot.
3. Validate the complete content-package multiset is unchanged.
4. Commit layout only after validation passes.
5. Follow the previously selected source to its destination key; update selected Graph, Panel key and Row.
6. Rebuild Inspector under its existing generation/ACK guard.
7. After the Shiny flush, verify logical layout, requested layout and selection all match the expected transaction; synchronize the browser blue selection border.
8. Automatic Panel labels remain slot-owned: when a previously blank slot becomes occupied, its generated label comes from that slot's row-major ordinal, not the count of occupied cells, so Shift-through-blank cannot create duplicate labels.

## Stale-output protection

Figure cell output ids are slot-keyed (`figure_cell_*_<slot>`), so they are intentionally reused after reorder. Each per-slot spec now reads the current requested layout and returns `NULL` if its captured source id no longer owns that slot. This protects the Graph body and the Inset / detached legend / label layers from an old closure repainting a reassigned slot.

## UI changes

- Reorder controls moved from `Figure Panel` Inspector to Step 2 `配置・整列`. Existing action ids are retained.
- Added `figure_reorder_reset` (canonical Graph order) and a batch vertical placement control.
- New cells default to 32 px Panel-label top gutter; existing Project state is not silently migrated.
- Advanced Figure section permits dropdown overflow and has extra bottom room.
- Statistics Analysis settings uses a taller vertical scroll area and hides accidental horizontal overflow.

## Runtime acceptance matrix

| Action | Content result | Selection | Slot label | Source overrides |
|---|---|---|---|---|
| ←/→ | swap with adjacent slot | follows moved source | stays | follows source |
| ↑/↓ | swap with same/nearest column in adjacent Row | follows source + Row | stays | follows source |
| Swap | direct two-slot swap | follows source to target | stays | follows source |
| Shift insert | stable insertion; intervening content shifts | follows source to target | stays | follows source |
| Shift into/through blank | blank participates as an empty content package | follows source | stays | follows source |
| Undo | restore previous logical layout and previous selection | restored | unchanged | source keyed |
| Reset | occupied sources sorted by Graph metadata order, then external assets; blanks last | follows selected source | unchanged | source keyed |

No timer/polling mechanism is added.

## Source: `docs/V3_73_1_5_FIGURE_FREE_LEGEND_FOOTPRINT_TRACE.md`

# v3.73.1.5 Figure Free Legend Footprint Trace

## Symptom

`test222.ggplotpack` shows excess right-side whitespace in Figure A (`g002`) and oversized Figure spacing. The package contains separate persisted assets for the detached legend case: `figure_g002.svg` is the full source visual while `figure_body_g002.svg` is the legend-free owner body and `figure_legend_g002.svg` is the detached legend.

## Root cause

Two geometry paths violated the detached-layer contract:

1. `figure_auto_layout_geometry()` represented free legends with zero legend-slot metrics but still applied another Graph's Row-common attached-legend padding to them. Thus a free owner received an empty slot even though its legend was an overlay.
2. During project bootstrap/dormant persisted-SVG geometry, `figure_source_sizes()` used the full preview metadata even when a saved `body_meta` existed. The owner footprint could therefore retain the former source-side legend strip until live remeasurement, and persisted-only snapshots had no live remeasurement path.

## Fix

- Add an explicit `legend_slot_participates` flag to natural Row geometry. Detached/free owners are excluded both from common-slot aggregation and common-slot padding application.
- Add `figure_layer_persisted_owner_meta()`. For detached/free persisted previews it uses `body_meta` for width/panel/axis/content geometry and maps the source legend bbox into body coordinates only as an overlay anchor.
- Attached legends and non-free legend-less Graphs continue to use the existing Row common-slot alignment.

## Expected behavior

- Fixed Canvas: canvas/cell dimensions do not change, but a free owner no longer has an asymmetric empty attached-legend strip. Remaining slot whitespace is fixed-layout whitespace.
- Auto Canvas: free owner width is based on the legend-free body. The final canvas expands only for the actual detached legend/Inset bbox when it extends beyond content.
- Figure snapshot ownership, free-legend drag coordinates, Inset, crop, Statistics, Graph Editor, and materialization remain unchanged.

## Source: `docs/V3_73_1_4_STATISTICS_PLOT_ABOVE_ANALYSIS_TRACE.md`

# v3.73.1.4 Statistics Plot Above Analysis Trace

## Goal

Adjust only the Statistics presentation hierarchy after runtime validation of the dedicated Plot preview. The Graph is used while configuring/interpreting the test, so it belongs immediately above Analysis controls rather than competing horizontally with Result.

## Layout

Left Statistics sidebar:

`Statistics data -> Plot -> Analysis selector -> add/delete -> Analysis settings`

Right main panel:

`Result`

The existing `stats_selected` and `stats_plot_preview` ids are moved, not recreated or renamed.

## Ownership / invariants

- `stats_plot_preview` remains a read-only SVG view backed by the existing Graph preview cache.
- Global Plot Preview remains Plot-tab-only and is not revealed/reparented.
- Statistics recipes, post-restore baseline, result calculation and Analysis-local data preparation are unchanged.
- No Graph/Figure state schema or materialization change.
- No JavaScript handler, timer, polling loop or extra editor.

## UI sizing

The Statistics sidebar is already sticky. Because Plot now shares that column with Analysis controls, the internal Analysis-settings scroll region is reduced from `46vh` to `32vh` (bounded 220-480 px). The Plot keeps its native SVG aspect ratio and full sidebar width.

## Source: `docs/V3_73_1_3_STATISTICS_PLOT_PREVIEW_TRACE.md`

# v3.73.1.3 Statistics Plot Preview Trace

## Goal

Restore a substantial Graph view inside Statistics because the test result is interpreted together with the plotted pattern. This is not a Graph-identification thumbnail.

## Ownership

- Plot tab: existing singleton Global Preview (cached/live ACK-gated Editor surface).
- Statistics tab: dedicated read-only SVG Plot surface backed by the Graph preview cache.
- Statistics must never reveal/reparent the Global Preview.
- No extra Graph editor or materializer is created.

## Data flow

`workspace-selected Graph -> graph_preview_cache / persisted Graph preview -> statistics_plot_preview provider -> stats_plot_preview renderUI`

The provider explicitly depends on selected Graph and preview-cache reactives, then reads the current preview record. A Graph switch while Statistics remains active updates only this Statistics Plot display while the ordinary persistent Editor transaction continues independently.

## UI

Wide screens use Plot + Result side by side. The Plot card is sticky to support reading long result output against the graph. Narrow screens stack Plot above Result.

## Guardrails

- Global Preview remains hidden in Statistics/Data/Comment.
- No new JavaScript handler.
- No new timer/polling loop.
- Figure/materialization ownership unchanged.
- Statistics recipe/result logic unchanged.

## Source: `docs/V3_73_1_2_STATISTICS_POST_RESTORE_BASELINE_TRACE.md`

# v3.73.1.2 Statistics post-restore baseline trace

## Observed runtime sequence

In v3.73.1.1, one Analysis switch completed the bounded restore handshake with `stable=TRUE`, then emitted one `STATS-RECIPE-COMMIT`. The resulting canonical diff contained only `statistics_recipes.<id>.anova_id`. The dynamic ANOVA UI can infer an ID column when the stored `anova_id` is empty, so the browser state was stable but intentionally different from the canonical recipe.

## Ownership rule

A stable restored UI snapshot is presentation state, not proof of user intent. It must not become canonical solely because renderUI/selectInput inferred a default.

## Fix

- Arm a transient `stats_post_restore_baseline` from the stable active-type snapshot at restore release.
- Ignore an unchanged baseline in `save_current_stats_recipe()`.
- Preserve the canonical stored recipe in `stats_recipes_for_project()` while the captured UI still exactly equals that baseline.
- Clear the baseline when a new Analysis restore starts, an Analysis is deleted, or GraphState replaces the Statistics recipe collection.
- On the first input state that differs from the baseline, clear it and resume the existing semantic compare/commit path.

No timer/polling/client-handler changes are involved.

## Source: `docs/V3_73_1_1_WORKSPACE_PREVIEW_TAB_GUARD_TRACE.md`

# v3.73.1.1 Workspace Preview tab guard trace

## Regression

After v3.73.1 moved the visible section bar outside the persistent Editor hydration mask, the section became workspace-global but `app_client.js` still stored singleton Preview visibility per semantic Graph.

Reproduction:

1. Graph A was on Plot.
2. Switch workspace to Statistics. The singleton Preview hides correctly.
3. Select Graph B and then return to Graph A.
4. `graph-global-preview-target` restored Graph A's historical Plot visibility and showed the cached/live Plot over the Statistics result.

The server-side Statistics result remained correct; this was a browser presentation ownership bug.

## Fix

`window.ggplotGuiWorkspaceMainTab` is now the single browser-side section state. Both the outer section bar and namespaced Shiny `graph_main_tab` update it. Preview target changes consult only this workspace state (with the persistent internal tab as startup fallback) and never per-Graph history.

No timer, polling, GraphState, Statistics recipe, Figure, materialization, or Preview ACK changes were introduced.

## Source: `docs/V3_73_1_EDITOR_FIRST_WORKSPACE_TRACE.md`

# v3.73.1 Editor-first workspace trace

## Goal

Restore the application-level contract that this program is an **Editor**.  Cached SVG is a latency/failure layer, not a normal viewer mode.  Statistics / Data View / comment navigation must not require a second explicit Edit action after Project load or Graph selection.

## User path

### Startup

`session first flush -> persistent graph_editor_single -> pristine g001 attach -> READY` remains unchanged.

### Project open

`Project parse -> Registry/Figure/Shared Style restore -> persisted preview catalog -> release Project lock -> request_graph_editor(selected) -> cached Preview ACK -> Editor state settle -> live bind/auth ACK -> READY`.

The Project overlay may hand off to the existing full Editor hydration mask, but there is no dormant browse-only endpoint.

### Graph switch

`Graph tab -> graph_client_selected + graph_edit_select -> request_graph_editor()`.

If no Editor transaction is running, switch immediately.  If another Graph is HYDRATING/SYNC, save only the **latest requested target** in `graph_single_pending_target`; do not interrupt or commit the partial owner.  The queue drains reactively after the current transaction releases `graph_single_editor_loading(FALSE)`.

The client keeps the hydration mask when a stale READY arrives for an older queued target, so the UI cannot flash back to an intermediate Graph.

### Main Graph section

The visible Plot / Statistics / Data View / 製作者コメント section bar is workspace-owned and remains visible outside the Editor hydration mask. It drives the hidden persistent `graph_main_tab` Bootstrap/Shiny binding, so the existing server contracts and Preview-tab ACK logic are retained without duplicating state.

The singleton `graph_main_tab` DOM survives Graph switches, so the current section stays selected across Graph ownership changes. Plot controls are shown only for Plot; Statistics keeps its own Analysis controls; Data View and 製作者コメント use the full content width instead of exposing unrelated Plot controls. Statistics still owns independent Analysis recipes and raw/custom Analysis data preparation; it is not re-coupled to Plot Mapping.

### Close Project

`閉じる -> confirmation -> project-close-reload -> full Shiny session reload -> pristine Graph 1 Editor`.

A hard reset is intentional for this first Close Project implementation because it guarantees no Graph/Figure/Shared-Style/editor lease survives the ownership boundary.

## Removed user dependency

The top-level Graph `編集` button is removed.  The compatibility JavaScript activation helper remains only as a non-UI fallback; ordinary selection always auto-hydrates the Editor.

## Preserved invariants

- one persistent Graph Editor;
- one Figure Editor;
- GraphState Registry canonical;
- cached SVG derived only;
- full hydration mask;
- Preview cached/live/auth ACK handshake;
- no timer/polling synchronization;
- Figure snapshot independence;
- Statistics recipe independence;
- Shared Style central Library / explicit binding rules.

## Windows validation focus

1. Startup shows editable Graph 1 as before.
2. Open the existing multi-Graph Project: selected Graph auto-hydrates without pressing Edit.
3. Open Statistics and switch Graph 1 -> Graph 2: Statistics stays selected and Graph 2 result/recipe appears after sync; no Edit button exists.
4. Return to Plot: Graph 2 is already the Editor owner; no promotion action is required.
5. Repeat from Data View and 製作者コメント.
6. Click Graph tabs rapidly (e.g. g002 -> g003 -> g004): only the latest target should become visible after serialized READY transitions; no partial-state commit/reconcile failure.
7. Close Project, confirm, and verify the app returns to fresh Graph 1 with no previous Figure/Shared Style/Statistics state.

## Source: `docs/V3_73_0_FIGURE_WORKFLOW_SHARED_STYLE_TRACE.md`

# v3.73.0 Figure workflow / Shared Style trace

## UI workflow

1. **取込** — copy canonical Graphs into independent Figure snapshots.
2. **配置・整列** — Row/Free, Plot/Facet/Axis basis and gaps. Existing axis-gutter and legend-slot geometry remains authoritative.
3. **共通Label / Style** — manage the project Shared Library, opt Figure sync in/out, or apply explicitly.
4. **個別調整** — selected Panel, Figure Graph editor, Legend/Crop/Inset and assets.
5. **Export** — SVG/PDF/PNG.

Advanced contains lower-frequency Canvas fixed size, autofit policy and experimental SVG preview controls.

## Shared Library state

Pure state helpers live in `shared_style_state.R`. A Library item has a stable semantic `id`, mutable `display`, `kind` (`level`, `axis_label`, `legend_title`) and managed appearance fields. Per-Graph bindings are stored under `GraphState$style$shared_library`; they are Project-specific metadata and are removed from RenderState comparison. Concrete Library values are materialized into the existing `level_labels`, `color_styles`, `shape_styles`, `linetype_styles`, axis-label and legend-title fields.

## Graph transaction

Only the persistent interactive Graph Editor receives the live project Library and a write callback. Background Graph materializers and the Figure controls editor receive an isolated empty fallback and cannot mutate the Library.

A linked user edit follows:

`Graph control → local Graph style reactive → central Library callback → Shared Library commit → linked canonical GraphStates → affected materialization queue`.

There is no direct Graph A → Graph B message. Axis binding is Library-authoritative in v3.73.0; its browser text control is not written back during the low-priority adapter, avoiding an update-message race.

## Figure transaction

Figure Library Sync defaults OFF. Manual Apply or explicit auto-sync performs:

`Figure snapshots → resolve current source Graph binding metadata only → apply Library values to Figure-owned GraphState → queue affected ids → reusable single Figure Editor force-load → existing bounded settle → snapshot → next id`.

Data, Mapping, Statistics and Figure geometry are not copied from the source Graph in this transaction. This permits the normal workflow where Figure is imported before semantic bindings are created. The current live Figure editor state is captured before the batch so Figure-only edits are preserved. A READY editor whose state differs from the latest queued state is force-reloaded rather than snapshotted. Existing settle failure aborts the batch.

## Persistence / portability

Project save stores the Library definition, each Graph's binding metadata and Figure sync setting. Old Projects normalize to an empty Library and sync OFF. Library JSON Import/Export carries definitions only; bindings never auto-attach in another Project.

## Expected diagnostics

- `SHARED-STYLE-LIBRARY commit source=... items=...`
- `SHARED-STYLE-APPLY source=... graphs={...} figure={...}`
- `SHARED-STYLE-FIGURE queued={...} reason=...`
- existing `FIGURE-SINGLE-EDITOR ... settle-check ... load-ready` while rebuilding
- `SHARED-STYLE-FIGURE snapshot rebuilt remaining={...}`
- `SHARED-STYLE-RESTORE items=... figure_sync=...` on Project load

A Figure settle failure should emit `SHARED-STYLE-FIGURE batch aborted...` and leave no Shared Style queue active.
## Ownership and compatibility guards added during audit

- Generic Graph style export and cross-Graph style copy/paste never carry `style.shared_library`; semantic bindings are Project-specific ownership metadata, not portable appearance.
- Figure → Graph Apply preserves the current source Graph binding metadata. Figure snapshots cannot overwrite a newer Graph-side binding.
- Shared Library write-through first collects all values bound to the same semantic item and commits only one unambiguous changed value; conflicting simultaneous observations leave the Library unchanged.
- Binding-only canonical metadata changes are persisted without waking Graph materialization or Figure snapshot rebuilds. Only concrete RenderState changes trigger those paths.
- v3.72 Project GraphStates and saved Figure editable states are normalized once on load to `shared_style_default_binding()`. This is a compatibility migration only; it does not bind any semantic item or enable Library sync.
- Portable Library JSON contains definitions only. Project save/load carries Graph bindings and Figure sync opt-in. Import never auto-binds by raw names.

## Source: `docs/V3_72_27_6_STATIC_AUDIT_SUMMARY.md`

# v3.72.27.6 Static Audit Summary

Overall: **PASS_STATIC**

- R lexical delimiter/string scan: PASS (47 files)
- Literal `source()` / `sys.source()` targets: PASS (23 literal refs, 0 missing)
- Retired warm/preload executable identifiers: PASS (0)
- Top-level R function redefinitions: PASS (0)
- Function Index: PASS (559/559)
- Shared `graphServer` binding collision surface: PASS; no function/binding names added or renamed from v3.72.27.5
- Materialization runtime: byte-identical to v3.72.27.5
- Client custom-message handler set: unchanged (34 unique / 38 raw)
- `node --check`: PASS for `www/app_client.js` and `www/figure_interaction.js`
- Focused Statistics restore-context checks: PASS
  - whole restore snapshot executes inside `isolate({ ... })`
  - active-analysis-type capture retained
  - bounded max-attempt=4 settle handshake retained
  - existing browser barrier ACK path retained
- Timer/polling counts unchanged: `invalidateLater=0`, `later::later=0`, `setTimeout=16`, `MutationObserver=1`
- `git diff --check`: PASS
- Patch roundtrip: PASS
- ZIP integrity: PASS

## Runtime limitation

The packaging environment has no R/Rscript executable, so this is a static audit. Windows runtime validation is still required. The expected regression test is specifically that the first `STATS-RESTORE-BARRIER acked` proceeds to `settling` / another barrier round-trip instead of raising `Can't access reactive value 'stats_name' outside of reactive consumer`.

## Source: `docs/V3_72_27_5_STATIC_AUDIT_SUMMARY.md`

# v3.72.27.5 static audit summary

Overall: **PASS (static audit)**

- R lexical delimiter/string scan: PASS — 47 R files.
- Literal `source()` / `sys.source()` targets: PASS — 43 references, 0 missing.
- Retired warm/preload executable identifiers: PASS — 0.
- Top-level R function redefinitions: PASS — 0.
- Function Index: PASS — 559 scanned / 559 indexed.
- Shared `graphServer` runtime-local binding collisions: PASS — 0.
- Focused Statistics helpers: PASS — restore snapshot/settle/request/type-capture helpers remain <=64 lines.
- Materialization encapsulation: PASS — materialization runtime is byte-identical to v3.72.27.4; no scope change.
- Custom message handlers: PASS — `app_client.js` 34/34 unique; combined 38 raw / 34 unique; no new Statistics-specific handler.
- `node --check`: PASS — `www/app_client.js`, `www/figure_interaction.js`.
- Timer/polling counts unchanged from v3.72.27.4: `invalidateLater` 0→0, `later::later` 0→0, `setTimeout` 16→16, `MutationObserver` 1→1.
- Focused restore-settle checks: PASS — attempt-scoped ACK validation, bounded max=4 handshake, canonical serialized snapshot comparison, active-type-only recipe capture, existing restore guard, and existing browser barrier reuse.
- Version/docs consistency: PASS.
- Diff whitespace check: PASS.
- Patch roundtrip: PASS.
- ZIP integrity: PASS.

## Runtime issue addressed

The v3.72.27.4 Windows trace showed the barrier working for the first two Analysis switches, but one later dynamic input still arrived after `released` and produced a single recipe commit. The diff also contained inactive t-test/correlation fields while ANOVA was active, showing that hidden dynamic controls could auto-select defaults and contaminate the recipe.

The fix keeps `stats_restoring` active until the active Analysis input snapshot is identical across consecutive existing browser-barrier round trips (bounded to four attempts), and recipe capture now persists only the selected analysis type's mapping fields. No timer, polling loop, new debounce, MutationObserver, or new JavaScript handler was introduced.

`R` / `Rscript` is not installed in this packaging environment, so this is a static audit rather than an R parser/runtime test. Windows runtime validation should confirm `requested -> acked -> settling -> requested -> acked -> released stable=TRUE`, no `STATS-RECIPE-COMMIT` on switch-only restore, a normal commit after one real user edit, and continued `STATS-RESULT` output.

## Source: `docs/V3_72_27_4_STATIC_AUDIT_SUMMARY.md`

# v3.72.27.4 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (47 files).
- `source()` / `sys.source()` literal targets: PASS (43 references, 0 missing).
- Retired warm/preload executable identifiers: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index membership: PASS (557 scanned / 557 indexed).
- Shared `graphServer` runtime-local binding collisions: PASS (0 duplicates).
- Materialization private-state leak scan: PASS (0 external references to queue/barrier internals).
- Active `www/app_client.js` custom-message handler duplicates: PASS (34 unique / 34 occurrences). Combined shipped JS remains 34 unique / 38 raw occurrences, unchanged from v3.72.27.3 because `figure_interaction.js` carries 4 mirrored handlers.
- Existing `graph-editor-reconcile-barrier` handler is reused; no Statistics-specific JS handler added.
- `node --check`: PASS for `www/app_client.js` and `www/figure_interaction.js`.
- Statistics switch-echo barrier boundary checks: PASS.
- Version/docs consistency: PASS.
- `git diff --check`: PASS.
- Compared with v3.72.27.3: `invalidateLater` 0 -> 0; `setTimeout` 16 -> 16; `later::later` 0 -> 0; `MutationObserver` 1 -> 1.
- Patch roundtrip against v3.72.27.3: PASS.
- ZIP integrity / extracted-tree comparison: PASS.

## Root-cause check

v3.72.27.3 stopped the continuous Statistics reactive loop and restored Result rendering, but `stats_restoring(FALSE)` was still executed at the end of the server-side restore phases before the last `update*Input()` messages had completed their browser → Shiny round trip. Analysis-switch restore echoes could therefore arrive after the guard was released and be captured as real edits, producing a short burst of recipe commits/saves.

## Fix boundary

Statistics restore now reuses the already-shipped `graph-editor-reconcile-barrier` client handler. The final restore phase requests a namespaced `stats_restore_barrier_ack`, validates the current Analysis id and restore token, keeps `stats_restoring == TRUE` for the entire ACK flush, and releases the guard only in `session$onFlushed()`. Because the generic save path reads the guard via `isolate()`, releasing it does not itself schedule a save. No timer, polling loop, extra debounce, MutationObserver, or new JS handler was added.

## Scope / limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. Windows runtime validation should confirm `STATS-RESTORE-BARRIER requested -> acked -> released`, no restore-echo `STATS-RECIPE-COMMIT`, normal commit after one real user edit, and continued `STATS-RESULT` output.

## Source: `docs/V3_72_27_3_STATIC_AUDIT_SUMMARY.md`

# v3.72.27.3 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (47 files).
- `source()` / `sys.source()` literal targets: PASS (43 references, 0 missing).
- Retired warm/preload executable identifiers: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index membership: PASS (556 scanned / 556 indexed).
- Shared `graphServer` runtime-local binding collisions: PASS (0 duplicates).
- Active custom-message handler set: PASS (34 unique / 38 raw occurrences; unchanged from v3.72.27.2).
- `node --check`: PASS.
- Statistics result-stability boundary checks: PASS (10/10).
- Version/docs consistency: PASS.
- `git diff --check`: PASS.
- Patch roundtrip against v3.72.27.2: PASS.
- ZIP integrity / extracted-tree comparison: PASS.
- Compared with v3.72.27.2: `invalidateLater` 0 -> 0; `setTimeout` 16 -> 16; `later::later` 0 -> 0; `MutationObserver` 1 -> 1.

## Root-cause check

v3.72.27.2 stopped no-op recipe writes, but normal `stats_transform_recipe()` still depended reactively on `stats_recipes()`. A real recipe commit invalidated `stats_source_data()`, rebuilt dynamic Statistics mapping controls, echoed browser values back to Shiny and committed again. That repeated invalidation also prevented the existing 180 ms debounced `stats_result` from settling, which explains the blank Result panel in the Windows log.

## Fix boundary

During guarded Analysis restore, the saved recipe remains reactive and authoritative. During normal editing, `stats_transform_recipe()` now uses `isolate(stats_selected_recipe())` only as fallback for unbound inputs; Statistics browser transform inputs own normal reactivity. The v3.72.27.2 semantic recipe-equality guard remains. Successful result rendering now emits `STATS-RESULT type=<...> chars=<...>`.

## Scope / limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. Windows runtime validation must confirm that Statistics becomes idle after restore/Analysis switching and that Result displays ANOVA/t-test/correlation output (or a visible validation message).

## Source: `docs/V3_72_27_2_STATIC_AUDIT_SUMMARY.md`

# v3.72.27.2 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (47 files).
- Literal `source()` / `sys.source()` targets: PASS (43 references, 0 missing).
- Retired warm/preload executable identifiers: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index: PASS (556 scanned / 556 indexed).
- Shared `graphServer` runtime-local binding collisions: PASS (0 duplicates).
- Touched `save_current_stats_recipe()` size: PASS (32 lines).
- Custom-message handler set: unchanged from v3.72.27.1 (34 unique handlers).
- `node --check`: PASS.
- Statistics recipe-stability boundary checks: PASS (7/7).
- Compared with v3.72.27.1: `invalidateLater` 0 -> 0; `setTimeout` 16 -> 16; `later::later` 0 -> 0; `MutationObserver` 1 -> 1.

## Root-cause check

The v3.72.27.1 runtime log showed a Statistics save storm after opening/switching Analysis. `save_current_stats_recipe()` rewrote the full `stats_recipes()` reactive collection even when the selected Analysis recipe was semantically unchanged. Because dynamic Statistics controls are derived from that collection, the write could rebuild UI, echo the same input values back through Shiny, and trigger another save.

## Fix boundary

The selected stored recipe and the input-captured candidate are normalized before comparison. If they are identical, `stats_recipes()` is not mutated. Real Analysis edits still commit and emit `STATS-RECIPE-COMMIT`. The Analysis-name observer likewise skips identical-name writes. Statistics remains Raw Dataset + Analysis-local preparation; Plot/Data View, persistent Editor, Preview ACK/render-gate, Figure snapshot, and materialization ownership are unchanged.

## Scope / limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. Windows runtime validation should confirm that opening Statistics and switching saved Analyses settles to idle instead of continuously emitting `GRAPH-EDIT-STATS-SAVE`. A real Statistics control edit should produce a recipe commit and persist through Graph switch and Project save/reload.

## Source: `docs/V3_72_27_1_STATIC_AUDIT_SUMMARY.md`

# v3.72.27.1 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (47 files).
- `source()` / `sys.source()` targets: PASS (63 references, 0 missing).
- Retired warm/preload executable identifiers: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index: PASS (556 scanned / 556 indexed).
- Shared `graphServer` runtime-local binding collisions: PASS (0 duplicates).
- Focused `graph_data_transform.R` function size <= 70 lines: PASS; max 41 lines.
- Active custom-message handler duplicates: PASS (34 handlers).
- `node --check`: PASS.
- v3.72.27.1 hotfix boundary checks: PASS (10/10).
- Version/docs consistency: PASS.
- Compared with v3.72.27: `invalidateLater` 0 -> 0; `setTimeout` 16 -> 16; `later::later` 0 -> 0; `MutationObserver` 1 -> 1.

## Root-cause check

The v3.72.27 regression was a shared-namespace name collision, not merely a startup timing issue. `graph_data_runtime.R` introduced a transform-only `plot_data`, while `graph_prepared_data_runtime.R` already defined prepared `plot_data`. Since both are sourced into the same `graphServer` environment, the later binding produced `dat() -> plot_data() -> dat()` recursion. v3.72.27.1 renames the transform-only boundary to `plot_source_data()` and audits the shared runtime namespace for duplicate bindings.

## Scope / limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. Windows runtime validation must confirm that startup reaches `captured pristine default state`, g001 attaches without `default-state-missing`, Data View follows Plot-side Wide→Long, and Statistics remains based on Raw Dataset + Analysis-local preparation.

## Source: `docs/V3_72_27_STATIC_AUDIT_SUMMARY.md`

# v3.72.27 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (47 files).
- `source()` / `sys.source()` targets: PASS (43 references, 0 missing).
- Retired warm/preload executable identifiers: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index: PASS (556 scanned / 556 indexed).
- New/refactored focused function size <= 70 lines: PASS; max 40 lines.
- Active custom-message handler duplicates: PASS (34 handlers).
- `node --check`: PASS for active `app_client.js` and reference `figure_interaction.js`.
- Statistics Raw Dataset / Analysis-local transform boundary: PASS (17/17 checks).
- Version/docs consistency: PASS.
- Compared with v3.72.26: `invalidateLater` 0 -> 0; `setTimeout` 12 -> 12; `later::later` 0 -> 0; `MutationObserver` 1 -> 1.

## Explicit v3.72.27 boundary checks

- pure_transform_sourced_before_graph_module: **PASS**
- statistics_runtime_extracted_and_sourced: **PASS**
- statistics_uses_raw_graph_data: **PASS**
- statistics_no_plot_dat_call: **PASS**
- statistics_no_reference_plot: **PASS**
- analysis_transform_fields_persisted: **PASS**
- legacy_plot_reshape_migration: **PASS**
- plot_data_uses_pure_transform: **PASS**
- data_view_uses_plot_data: **PASS**
- statistics_ui_says_raw_dataset: **PASS**
- statistics_mapping_independent: **PASS**
- figure_apply_preserves_statistics: **PASS**
- state_restore_migrates_legacy_recipe: **PASS**
- module_api_exposes_data_boundaries: **PASS**
- preview_semantic_singleton_id: **PASS**
- preview_nonplot_immediate_hide: **PASS**
- preview_css_authoritative_hide: **PASS**

## Scope / limitation

Statistics is internally decoupled from Plot `dat()`/Mapping/rendering in this checkpoint, but Statistics, Data View and 製作者コメント are still mounted inside the persistent Graph module. Moving those surfaces into browse mode without Plot Editor hydration is intentionally left as a separate UI/runtime transaction after this data boundary is runtime-validated.

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. The Windows runtime cases in `docs/TEST_CHECKLIST.md` remain required.

## Source: `docs/V3_72_26_STATIC_AUDIT_SUMMARY.md`

# v3.72.26 static audit summary

- Version: `v3.72.26-reconcile-browser-barrier1`
- R lexical delimiter/string scan: 45 files; failures=0
- Literal source/sys.source refs: 22; missing=0
- Top-level function duplicates: 0
- Function index: 543 scanned / 543 indexed; exact=True
- JavaScript custom-message handlers: no duplicate handler names; `node --check` passes for active JS.
- Timer/polling counts unchanged vs v3.72.25: `{'invalidateLater(': 0, 'later::later(': 0, 'setTimeout(': 16, 'setInterval(': 0, 'MutationObserver(': 0}`
- Retired warm/preload active-code hits: 0
- Reconcile barrier request function: exactly one; 33 lines.
- Browser barrier handler: exactly one; uses `requestAnimationFrame`, no `setTimeout` in the barrier implementation.
- Reconcile attempt limit remains one retry (`attempt < 1L`).
- The old forced settle tick immediately after `mod$sync_state(canonical)` is removed.
- Barrier state is explicitly cleared at 5 transaction boundaries/success paths.
- ACK validation is token + Graph id + generation + attempt scoped.
- `git -c core.whitespace=cr-at-eol diff --no-index --check` passes.
- v3.72.25 → v3.72.26 patch roundtrip reproduces the target tree exactly.
- R/Rscript is unavailable in this environment, so Windows R parser/runtime verification remains required.

## Regression guard

A first canonical RenderState mismatch may still trigger exactly one `sync_state(canonical)` retry. That retry is not accepted merely because the browser barrier ACK arrives: after the ACK, the server reads the Editor state again and the RenderState must actually match canonical. A remaining mismatch still aborts activation back to Preview browse.

The barrier exists only to order asynchronous `update*Input()` propagation across the browser → Shiny-server round trip; it does not weaken canonical ownership or state comparison.

## Source: `docs/V3_72_25_STATIC_AUDIT_SUMMARY.md`

# v3.72.25 static audit summary

- Version: `v3.72.25-restore-ack-fallthrough1`
- R lexical delimiter/string scan: 45 files; failures=0
- Literal source/sys.source refs: 22; missing=0
- Top-level function duplicates: 0
- ACK fallthrough: parent=True, child=True
- Timer/polling counts unchanged vs v3.72.24: True — `{'invalidateLater(': 0, 'later::later(': 0, 'setTimeout(': 16, 'setInterval(': 0, 'MutationObserver(': 0}`
- Retired warm/preload active-code hits: 0
- Function index rows: 542 (no function additions/removals in this focused patch).
- Active JavaScript passes `node --check` (run separately).
- R/Rscript is unavailable in this environment, so Windows runtime/parser verification remains required.

Regression guard: successful RESHAPE parent/child browser ACK must fall through to Shiny input verification in the same reactive execution. Already-matching preseeds must not rely on a future input invalidation.

## Source: `docs/V3_72_24_STATIC_AUDIT_SUMMARY.md`

# v3.72.24 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (45 files).
- `source()` / `sys.source()` targets: PASS (41 references, 0 missing).
- Retired warm/preload executable identifiers: PASS (0 matches).
- Materialization private state outside boundary: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index: PASS (542 scanned / 542 indexed).
- Newly added focused function size <= 60 lines: PASS; max 32 lines.
- Active custom-message handler duplicates: PASS (33 handlers).
- `node --check`: PASS for active `app_client.js` and reference `figure_interaction.js`.
- RESHAPE/MAPPING binding-check timer polling: PASS (none).
- Restore R timer primitives (`Sys.sleep` / `later::later` / `invalidateLater`): PASS (none).
- v3.72.24 required wiring: PASS.
- Version/docs consistency: PASS.
- Compared with v3.72.23: `invalidateLater` 4 -> 0; `setTimeout` 14 -> 12; `later::later` 0 -> 0.

## Limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. The Windows runtime cases in `docs/TEST_CHECKLIST.md` remain required.

## Source: `docs/V3_72_23_STATIC_AUDIT_SUMMARY.md`

# v3.72.23 static audit summary

Overall static status: **PASS**

- R lexical delimiter/string scan: PASS (45 files).
- `source()` / `sys.source()` targets: PASS (41 references, 0 missing).
- Retired warm/preload runtime identifiers in executable R/JS/CSS: PASS (0 matches).
- `server_graph_preload_legacy.R` removed: PASS.
- Materialization private state referenced outside runtime: PASS (0 matches).
- Top-level R function redefinitions: PASS (0 duplicates).
- Function index: PASS (539 scanned / 539 indexed).
- Materialization function size: PASS (max 53 lines; audit threshold 60).
- Active custom-message handler duplicates: PASS (32 handlers).
- `node --check`: PASS for `app_client.js` and reference `figure_interaction.js`.
- Materialization timer/polling primitives: PASS (none).
- Compared with v3.72.18 active runtime: `later::later` 3 -> 0; `setTimeout` 19 -> 14; `invalidateLater` 4 -> 4.

## Limitation

`R` / `Rscript` is not installed in the packaging environment, so this is a static audit rather than an R parser/runtime test. Windows/R 4.3.1 smoke tests in `TEST_CHECKLIST.md` remain required before treating runtime equivalence as confirmed.

## Source: `docs/V3_72_8_FIGURE_APPLY_PREVIEW_STYLE_GUARD_TRACE.md`

# v3.72.8 Figure Apply / Preview / Dynamic Style Guard

Version: `v3.72.8-figure-apply-preview-style-guard1`

## Problem reproduced with test222.ggplotpack

The packaged canonical GraphState for Graph 3 contains the Figure-applied red/blue style, while the persisted Graph SVG still contains the older orange/blue style. This proves that Figure -> Graph commit reached canonical state, but a stale Graph preview could survive and be serialized with the newer state.

A second issue appeared when the persistent Editor restored Graph 3: dynamic style inputs could report values from the previous Graph after the restore guard was released, causing `style.color_styles.Group.CTL/EXP` to become a new canonical change.

## Changes

1. Figure -> source Graph Apply now calls `invalidate_graph_preview_artifacts()` after canonical commit. It removes both in-session Graph preview and persisted Graph preview for that Graph, then marks the Graph dirty.
2. Project save no longer serializes a persisted Graph SVG fallback for a dirty Graph that cannot be refreshed because it is dormant. Missing preview is preferred to a state/SVG mismatch.
3. Dynamic style restore remains guarded for an extra browser flush. After renderUI rebuild, the target canonical color/linetype/shape/raw-color/legend-title/level-label trees are reasserted, then the guard is released on the next `onFlushed()` callback.
4. No new timer/polling mechanism was added.

## Expected runtime order

After Figure Apply:

```
FIGURE-APPLY-DIFF ...
STATE-COMMIT ... source=figure-editor-apply
GRAPH-PREVIEW-INVALIDATE ... reason=figure-editor-apply
FIGURE-COMMIT ...
```

If Project is saved before opening that Graph:

```
GRAPH-PREVIEW ... Project save omitted stale fallback for dirty dormant Graph
```

On Graph restore/revisit when dynamic styles differ:

```
RESTORE-STYLE-GUARD canonical dynamic style reasserted; release deferred one flush
RESTORE-STYLE-GUARD release after canonical dynamic style flush
PREVIEW-MODE restore complete...
```

The restore itself must not create a new canonical change such as:

```
STATE-COMMIT ... render_paths={style.color_styles.Group.CTL,style.color_styles.Group.EXP}
```

unless the user actually edits those colors after restore.

## Regression checks

- Figure snapshots keep explicit ownership semantics and are not automatically refreshed from Graph.
- Figure-only geometry remains outside source GraphState.
- Graph preview fallback remains available for clean dormant Graphs.
- Single persistent Editor remains unchanged; no per-Graph DOM/module cache was introduced.
- Preview ACK/render gate design from v3.72.6+ remains intact.

## Source: `docs/V3_72_7_EDITOR_DELTA_SYNC_TRACE.md`

# v3.72.7-editor-delta-sync1

## Goal

Reduce work when the persistent singleton Graph Editor moves between Graphs,
without reintroducing per-Graph Shiny modules/DOM or an unbounded ggplot cache.

The canonical architecture remains:

```text
GraphState registry + persisted SVG per Graph
                ↓
       one persistent Editor
```

## Changes

### 1. Direct Editor sync now uses a GraphState delta mask

Before a compatible fixed-shell sync, the module snapshots the state currently
represented by the Editor and compares it with the target GraphState using
`app_state_diff_paths()`.

Only changed branches are sent back to browser inputs/reactive style state:

- plot dimensions only when width/height differ;
- Statistics recipe UI only when recipes differ;
- project name / plot type only when changed;
- Mapping sends only changed fixed controls;
- Plot / labels restore is branch-scoped;
- color/linetype/shape/series/regression/raw/order/legend-label state is branch-scoped;
- appearance controls are field-scoped;
- dynamic style UI rebuild is skipped unless Mapping/plot structure or a dynamic
  style branch changed.

Full Project hydration retains full-restore semantics.

### 2. Lightweight editor-visit cache

The server records only revision metadata per Graph:

```text
state_revision
render_state_revision
generation
```

No per-Graph Editor DOM, module, prepared data, or ggplot object is retained.
The metadata is updated after successful Editor commits/READY and removed on
Graph delete or whole-Project replacement.

Diagnostics:

```text
GRAPH-SINGLE-EDITOR-CACHE revisit=TRUE fresh=TRUE ...
EDITOR-SYNC-DELTA paths=N {...}
EDITOR-SYNC-DELTA mapping sent={...} skipped=N
```

### 3. Render gate is permission; semantic revision decides expensive rebuild

During HYDRATING the newest RenderState is stored as pending. At READY, the
final target RenderState is compared with the last successfully built plot
state.

- If different: `plot_build_revision` advances once, then `make_plot()` builds.
- If identical: the revision is not advanced.

The existing render gate still protects all switch transactions.

Because opening the render gate itself invalidates Shiny reactives, `make_plot()`
also requires `plot_build_pending == FALSE`. This prevents a consumer from
building once with the previous revision in the short interval between gate
open and final semantic revision release. The module then keeps exactly one
reference to the last successful ggplot object. If the revision and RenderState
are unchanged, `make_plot()` returns that object immediately (`CACHE-HIT`)
rather than rebuilding ggplot.

This is a single-object cache, not a per-Graph cache, so memory use does not
scale with Graph count.

Diagnostics:

```text
PLOT-REVISION READY reuse-hit render_state_unchanged; revision not advanced
GRAPH-EDIT-PLOT make_plot CACHE-HIT rev=... render_state_unchanged
```

## Expected runtime behavior

For compatible same-structure switches:

```text
Graph A -> Graph B
cached SVG B immediately visible
Editor sync uses only changed fields
READY / Preview ACK handshake
one final plot build only if B RenderState differs from current built plot
```

For metadata-only / render-equivalent switches:

```text
Editor delta sync
READY
plot revision not advanced
last completed plot reused
```

For Graphs with incompatible raw-data/reshape/plot structure, the existing
structural HYDRATING path remains in use.

## Manual checks

1. Load the same `.ggplotpack` used for v3.72.6 tests.
2. Switch repeatedly between two Graphs with the same plot type/schema.
3. Confirm `EDITOR-SYNC-DELTA` appears and Mapping `sent` contains only fields
   that actually differ.
4. Confirm unchanged appearance does not cause a large batch of input updates.
5. Confirm Plot type / Mapping / color / size edits after READY still redraw.
6. Confirm switching to a genuinely different RenderState still produces one
   final `make_plot START` after the Preview ACK handshake.
7. If two Graphs are render-equivalent, confirm `READY reuse-hit` / `CACHE-HIT`
   and no expensive `make_plot START` for the switch.
8. Confirm Graph deletion and Project replacement do not retain visit metadata.
9. Figure lifecycle behavior should be unchanged from v3.72.6.

## Static-safety intent

No new timer, polling, MutationObserver, or per-Graph module/DOM cache is added.
The Preview cached/live ACK transaction from v3.72.6 is unchanged.

## Source: `docs/V3_72_6_CLIENT_CACHE_BUST_TRACE.md`

# v3.72.6-client-cache-bust1

## Purpose

v3.72.5 correctly introduced Preview transaction ACK gating, but runtime logs showed every transaction stuck at `cached_acked=FALSE` and no `render-gate OPEN`. The browser did return `graph_global_preview_target_ack`, but the ACK lacked the new `transactionId`. This is consistent with the browser reusing an older cached `app_client.js`.

## Change

- `app_client.js` and `app_styles.css` are loaded with `?v=<APP_VERSION>`.
- `app_client.js` reports the version actually loaded through `graph_client_asset_version`.
- Server logs `CLIENT-ASSET ... match=TRUE/FALSE`.
- Preview handshake behavior itself is unchanged.

## Expected runtime sequence

```text
CLIENT-ASSET app_client version=v3.72.6-client-cache-bust1 server=v3.72.6-client-cache-bust1 match=TRUE
...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=CACHED-ACK ...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=STATE-SETTLED cached_acked=TRUE ...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=LIVE-BIND-ACK ...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=LIVE-AUTH-ACK ...
GRAPH-SINGLE-EDITOR render-gate OPEN ...
```

After the gate opens, normal user edits such as changing plot type must produce a non-deferred plot revision and `make_plot START` immediately.

## Source: `docs/V3_72_5_PREVIEW_ACK_GATE_TRACE.md`

# v3.72.5 Preview ACK gate

## Runtime symptom addressed

In v3.72.4 the HYDRATING live-holder deferral worked, but direct persistent-shell Graph switches could still finish state restore and render the target Graph before the earlier cached-target custom message had been applied by the browser. Runtime order for g004 showed the target `make_plot()` / live render completing before `mode=cached reason=target-change`, causing a visible target-live -> target-cached -> target-live round trip.

## Transaction contract

Each persistent-editor switch creates `single-editor:<generation>:<graphId>`. The render gate remains closed through these phases:

1. `CACHED-ACK` — the browser applied the target cached SVG (skipped when no cached SVG exists).
2. `STATE-SETTLED` — the module restore reached its stable canonical GraphState.
3. `LIVE-BIND-REQUEST` / `LIVE-BIND-ACK` — the READY live output holder is created and Shiny-bound while live image promotion remains unauthorized.
4. `LIVE-AUTH-REQUEST` / `LIVE-AUTH-ACK` — the browser authorizes only the current transaction holder.
5. Render gate opens, producing one fresh target render; only its later IMG load may promote cached -> live.

ACKs whose transaction id or Graph id does not match the current generation are ignored. No timer, polling, or sleep primitive is added.

## Expected diagnostic order

```text
GRAPH-SINGLE-EDITOR pending target cached preview requested txn=...
GLOBAL-PREVIEW ... prefer_live=FALSE ... txn=...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=CACHED-ACK ...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=STATE-SETTLED ... render_gate=CLOSED
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=LIVE-BIND-REQUEST ... render_gate=CLOSED
GLOBAL-PREVIEW ... prefer_live=TRUE ... txn=...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=LIVE-BIND-ACK ...
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=LIVE-AUTH-REQUEST ... render_gate=CLOSED
GRAPH-SINGLE-PREVIEW-HANDSHAKE phase=LIVE-AUTH-ACK ...
GRAPH-SINGLE-EDITOR render-gate OPEN after cached/live/auth Preview ACKs
GRAPH-EDIT-PLOT make_plot START ...
GLOBAL-PREVIEW-MODE mode=live reason=plot-image-load
```

There should be no `make_plot START` for the target between `CACHED-ACK` and the final authorization ACK.

## Source: `docs/V3_72_4_PREVIEW_READY_BIND_TRACE.md`

# v3.72.4-preview-ready-bind1

## Purpose

Remove the remaining visible Graph-switch round trip where the target cached SVG appears briefly, then the persistent live layer re-displays an older image, and only afterward the target Graph's fresh live image arrives.

## Runtime evidence from v3.72.3

The v3.72.3 log showed this order on Graph switches:

1. `single-editor-switch-pending` requested the target cached SVG with `prefer_live=FALSE`.
2. Browser entered `mode=cached reason=target-change`.
3. While the target was still `HYDRATING`, `mode=live reason=plot-image-load` fired.
4. The target Graph's own `make_plot START` occurred later, after READY.

Therefore the early live promotion could not be the target's newly rendered plot. The shared live output holder was still being created and Shiny-bound during HYDRATING, allowing the persistent output binding to replay an existing/previous image.

## Change

### Browser Preview lifecycle

`www/app_client.js` now uses the following lifecycle for the persistent single Editor:

```text
Graph switch begins
  -> target cached SVG inserted
  -> old live output unbound/cleared
  -> NO live output holder is created
  -> NO Shiny.bindAll(live) during HYDRATING

Graph reaches READY
  -> preferLive=TRUE arrives for the current target
  -> create the singleton live output holder
  -> bind the live layer to Shiny
  -> keep cached SVG visible while the fresh image is pending
  -> fresh IMG load promotes cached -> live exactly once
```

This removes the stale-live route structurally instead of relying only on an IMG-load guard.

### Diagnostics

Added:

```text
GLOBAL-PREVIEW-LIVE-BIND
```

Expected switch sequence:

```text
GLOBAL-PREVIEW ... single-editor-switch-pending ... prefer_live=FALSE
GLOBAL-PREVIEW-MODE ... mode=cached
... HYDRATING / deferred plot revisions ...
render-gate OPEN
make_plot START
GLOBAL-PREVIEW ... single-editor-show ... prefer_live=TRUE
GLOBAL-PREVIEW-LIVE-BIND ... READY bind holder_created=TRUE
GLOBAL-PREVIEW-MODE ... mode=live reason=plot-image-load
```

There should be no `mode=live reason=plot-image-load` between the pending cached target and READY/live binding.

## Deliberately unchanged

- Figure source lifecycle / GC / fresh import
- GraphState / RenderState contract
- plot revision coalescing introduced in v3.72.2/v3.72.3
- Preview scaling policy
- export behavior
- synchronization timers / polling primitives

## Runtime checks

1. Load a `.ggplotpack` whose selected Graph has a persisted SVG.
2. Confirm target cached SVG appears during restore and remains stable until the fresh target live plot is ready.
3. Switch repeatedly among line/bar/box Graphs.
4. Confirm there is no visible return to the preceding Graph between cached and live target views.
5. Confirm ordinary edits still update the current live plot.
6. Confirm Figure tab behavior remains unchanged.

## Source: `docs/V3_72_3_PREVIEW_TRANSACTION_GUARD_TRACE.md`

# v3.72.3 Preview transaction guard

Base: v3.72.2-plot-revision1

## Runtime symptom addressed

During a persistent single-Editor Graph switch, the shared Preview stage is retargeted to the new Graph's cached SVG before the Editor finishes HYDRATING. A late browser IMG `load` event and dimension message from the previous Graph can still arrive in that shared DOM. In v3.72.2 this could promote the new target from cached to live before the new Graph had rendered, visually bouncing between the previous and current Graph.

The diagnostic log showed this directly: a target entered cached mode and then `mode=live reason=plot-image-load` while `render-gate` was still closed and before the target Graph's first `make_plot()`.

## Changes

### 1. Preview live promotion is transaction-authorized

`graph-global-preview-target` now records whether the current target is authorized to use live output (`preferLive=TRUE`) and the expected live holder id.

The capture-phase IMG load handler promotes cached -> live only when:

- the current target has been explicitly authorized by the READY request; and
- the loaded IMG is contained by the currently expected live holder.

Late IMG load events from the previous Graph are ignored and logged as `GLOBAL-PREVIEW-LIVE-GUARD`.

If READY authorization arrives after the fresh image is already complete, the handler checks the current holder and promotes the already-complete current image safely.

### 2. Dimension publication is blocked during HYDRATING

The reactive `set-plot-dimensions` publisher now requires the external `render_gate` and `initial_restore_done()`.

This prevents previous/intermediate Editor dimensions such as 600x600 from resizing the new Graph's cached Preview during a switch. Opening the gate at READY wakes the observer and publishes the final target dimensions once.

### 3. Plot revision changes are coalesced during the transaction

While `render_gate` is closed, RenderState changes are remembered in `plot_build_render_state()` but do not advance `plot_build_revision`.

This means reshape, Mapping and dynamic style binding stages may update the semantic state many times during HYDRATING without producing revision 9 -> 10 -> 11 ... noise. The gate-open transition already invalidates `make_plot()` once at READY, where it reads the final isolated inputs.

Ordinary user edits after READY still advance `plot_build_revision` normally.

## Intentionally unchanged

- Figure source GC / fresh import behavior from v3.72.0+
- Graph/Figure ownership rules
- Project cache-first restore
- Preview scaling formula
- Plot builders and plot-type semantics
- Existing synchronization mechanisms; no timer/polling primitive was added

## Runtime checks

1. Load the same `.ggplotpack` used for v3.72.2.
2. During Project target g005 restore, cached g005 should remain visible until g005 is READY and its own live image is available.
3. Switch g005 -> g004 -> g003 -> g002 -> g006 -> g005.
4. During each HYDRATING transaction, look for `GLOBAL-PREVIEW-LIVE-GUARD ... ignored plot-image-load` instead of an early `GLOBAL-PREVIEW-MODE ... mode=live`.
5. There should be no previous-Graph `live-dimensions` resize of the new cached target while the gate is closed.
6. `PLOT-REVISION ... deferred transaction=HYDRATING` may appear, but `make_plot START` should occur only after READY/gate-open for restore changes.
7. After READY, an ordinary Mapping/color/axis edit must still advance a revision and redraw.

## Source: `docs/V3_72_2_PLOT_REVISION_TRACE.md`

# v3.72.2 plot-revision1

## Goal

Reduce redundant ggplot rebuilds without suppressing legitimate user edits. v3.72.1 proved that `render_changed=FALSE` could still be followed by `make_plot START` because the plot reactive still registered direct dependencies on its many Shiny inputs.

## Runtime contract

```text
UI / dynamic bindings
        ↓
project_settings()  (full GraphState)
        ↓
graph_render_state()
        ↓ only when semantic RenderState changes
plot_build_revision + 1
        ↓
make_plot()
        ↓ cached completed ggplot
 ├─ panel sizing / dimensions
 ├─ live renderPlot
 ├─ Graph SVG preview
 ├─ Figure components
 └─ export
```

`make_plot()` still depends on the existing `render_gate()` and `initial_restore_done()` transaction guards. Everything inside the expensive builder is evaluated under `isolate()`, with `plot_build_revision()` as its normal semantic invalidation source.

## Preview freshness

Preview publication no longer requires full GraphState identity. It compares:

```text
graph_render_state(module state)
==
graph_render_state(canonical Registry state)
==
completed RenderState
```

Therefore a `project_name`/schema/export-only change cannot stale or discard a valid rendered SVG. Full GraphState is still stored in Registry and in the preview record; only freshness comparison uses RenderState.

## Font settle follow-up

`style_settings()` now persists `font_family_mode_effective()` / `font_family_custom_effective()` rather than transient browser binding values. This preserves an explicit user font while preventing Selectize materialisation from creating a second GraphState representation.

## Static safety checks

- All 65 direct `input$...` names referenced by `graph_plot_runtime.R` are represented by `project_settings()` or `style_settings()`.
- Figure lifecycle files were byte-identical to v3.72.1.
- No synchronization primitive was added.
- Source targets resolve.
- Modified R files pass the local strings/comments/delimiter scanner.
- `www/app_client.js` and `www/figure_interaction.js` pass `node --check`.
- Runtime R/Shiny validation still requires the user's R 4.3.1 environment because R/Rscript is not installed in the build container.

## Expected log change

New diagnostic:

```text
GRAPH-EDIT-PLOT-REVISION revision=N paths={...}
GRAPH-EDIT-PLOT make_plot START rev=N type=...
```

For a metadata-only commit the desired pattern is:

```text
STATE-COMMIT ... render_changed=FALSE
# no new PLOT-REVISION
# no new make_plot START
```

For a real appearance/data change:

```text
PLOT-REVISION revision=N+1 paths={style...,mapping...,data_text...}
make_plot START rev=N+1
```

## Smoke test

1. Load the same `.ggplotpack` used for v3.72.1.
2. Switch g005 → g004 → g005; each READY switch should normally have one `make_plot START`.
3. Switch through g003/g002/g006 and confirm no Graph loses mapping/style.
4. Change one color once: one semantic revision/build should follow.
5. Rapidly change a color several times: multiple semantic revisions are still allowed in this version; coalescing is intentionally deferred.
6. Change Project name only: no `make_plot START` should follow.
7. Open Figure and verify v3.72.1 delete→GC→fresh-import behavior remains intact.

## Source: `docs/V3_72_1_FONT_SETTLE_TRACE.md`

# v3.72.1 font-settle1

Baseline: v3.72.0-redraw-figure-lifecycle1.

## Goal

Remove the remaining restore-time font-family oscillation without changing Figure lifecycle or continuous user-edit behavior.

## Changes

- Added pure canonical font helpers in `app_shared_helpers.R`:
  - `app_normalize_font_family_mode()`
  - `app_normalize_font_family_custom()`
  - `app_effective_font_family()`
- Render-state comparison now uses the effective ggplot font family rather than the selector representation (`mode` + `custom`).
- Added one local persistent-Editor boundary function:
  - `apply_font_family_state_to_editor()`
- Both cold restore and fixed-shell Graph sync call the same font restore function.
- Missing legacy font fields explicitly restore to `sans` / empty custom text instead of retaining the previous Graph's browser value.
- Module-side effective font values are updated synchronously before Selectize/TextInput update messages are sent, so late browser ACKs that merely confirm the same value do not invalidate the plot.
- Graph UI preseed and style save paths use the same canonical font helpers.
- Added diagnostics:
  - `FONT-RESTORE` for the target mode/custom/effective family applied by a restore transaction.
  - `FONT-BIND` only when a browser binding actually changes the module-side effective font value.

## Intentionally unchanged

- Figure source GC / new-import lifecycle from v3.72.0.
- Render gate transaction semantics.
- Color-picker continuous edit behavior; rapid color changes may still legitimately produce stale-render skips.
- Preview scaling and plot device sizing.
- Existing synchronization primitives; no new timers, polling, sleeps, observers based on browser mutation, or debounce layers were added.

## Runtime checks

1. Open the same project used for v3.72.0.
2. Switch repeatedly between g004/g005/g006.
3. Check that `font_family_mode` no longer appears as a repeated post-READY render diff when the effective font is unchanged.
4. Check `FONT-RESTORE` target values and verify no contradictory `FONT-BIND` follows.
5. Confirm Graphs using an explicit installed font retain that font.
6. Confirm `custom` font mode still restores custom text and renders with that family.
7. Confirm Figure delete -> GC -> re-add still performs a fresh import.
8. Exercise rapid color changes; behavior is intentionally unchanged in this build.

## Source: `docs/V3_72_0_REDRAW_FIGURE_LIFECYCLE_TRACE.md`

# v3.72.0 redraw + Figure lifecycle

Base: v3.71.0-redraw-sync-audit1.

## Figure source lifecycle

- A Graph owns Figure-side snapshot/edit/cache state only while the current Figure references it.
- References include main Figure panels and enabled insets belonging to currently referenced main panels.
- Removing the last reference garbage-collects Figure-owned editable state, loaded plot/export/assets, persisted Figure preview, Figure override state, inset snapshot, and Figure geometry/revision caches.
- Re-adding that Graph is a fresh import from the current source Graph.
- If the source Graph is already READY, new assignment imports immediately.
- Otherwise assignment records a one-shot pending import; preload READY consumes that pending import.
- Existing Figure-owned Graphs retain explicit-refresh semantics and are never overwritten merely because source Graph preload becomes READY.
- Project save serializes Figure snapshots only for currently referenced Graphs.
- Project restore removes unreferenced historical Figure snapshots from older packages.

Expected diagnostics:

```text
FIGURE-SOURCE ... fresh_import=TRUE
FIGURE-SOURCE-GC ...
FIGURE-SOURCE-SYNC new assignment imported immediately from READY Graph
```

or, for a cold source:

```text
FIGURE-SOURCE-SYNC new assignment waiting for source READY
PRELOAD ... READY
FIGURE-SOURCE-SYNC preload READY consumed pending new assignment
```

## Redraw reduction

### Dynamic label default materialization

Dynamic legend-title and level-label inputs previously wrote their visual defaults back into GraphState after READY:

```text
NULL -> "Time"
NULL -> original factor level
```

Those transitions are visually identical but invalidated plot reactives. v3.72 no longer stores a generated default unless the user actually changes it.

### Effective font mode

The Selectize font input may briefly be NULL and later report the UI default `sans`. Plot consumers now depend on an effective font-mode reactive that only changes when the normalized mode changes.

### GraphState vs render-state revision

Canonical GraphState still stores project/editor/persistence metadata. A render-state projection now excludes metadata that cannot alter the plot, including project name/version/export metadata, sticky-preview UI state, duplicate `style$axes`, and materialized display-label defaults.

`registry_commit()` now logs `render_changed=TRUE/FALSE`. Only render-changing commits advance the render-state revision and mark the Graph preview dirty.

Graph preview observers depend on this render-state revision rather than the entire GraphState registry. This preserves the guarded retry when a plot-changing canonical commit lands after render completion, while preventing metadata-only commits from scheduling redundant SVG publication attempts.

## Synchronization primitives

No new timers/polling primitives were added.

```text
Sys.sleep          0 -> 0
setTimeout        23 -> 23
setInterval        0 -> 0
MutationObserver   1 -> 1
invalidateLater    4 -> 4
reactivePoll       0 -> 0
reactiveTimer      0 -> 0
```

## Runtime validation targets

1. Switch among g002-g006 and compare `make_plot START`, `GRAPH-SINGLE-STATE-DIFF`, `STATE-COMMIT render_changed=...`, and `skip state mismatch` counts with v3.71.
2. A newly opened/restored Graph should no longer acquire default `legend_titles.*` or `level_labels.*` solely because their dynamic controls bind.
3. Edit a Graph not currently present in Figure, then assign it to a Figure panel. The first Figure rendering should use the edited Graph without pressing refresh.
4. Remove that Graph from every Figure panel/inset. Confirm `FIGURE-SOURCE-GC` evicts it.
5. Edit the source Graph again and re-add it. Confirm the new current Graph is imported, not the old Figure snapshot.
6. Keep one duplicate panel or enabled inset referencing the Graph while removing another panel. Confirm no GC occurs until the last reference disappears.
7. Existing Figure-owned Graphs must remain independent from later source Graph edits until explicit refresh/apply actions.

## Source: `docs/V3_71_0_REDRAW_SYNC_AUDIT_TRACE.md`

# v3.71.0 redraw / Figure-source audit

## Purpose

This revision deliberately avoids another rendering workaround. v3.70 already proved that the persistent render gate blocks HYDRATING/SYNC draws, but runtime logs still show some post-READY state commits followed by extra Plot builds. The goal of this build is to identify the exact changed GraphState paths and the Plot consumer requesting each evaluation.

## New diagnostics

- `GRAPH-SINGLE-STATE-DIFF source=load-ready` — canonical Registry vs state accepted at READY.
- `GRAPH-SINGLE-STATE-DIFF source=live` — canonical Registry vs later debounced editor state.
- `PLOT-CONSUMER request=dimensions` — Plot requested for native geometry measurement.
- `PLOT-CONSUMER request=live-render` — main Graph `renderPlot`.
- `PLOT-CONSUMER request=figure-components` / `figure-plot` — Figure/preview snapshot path.
- `PLOT-CONSUMER request=module-plot` / `export-meta` / `stats-reference` — other consumers.
- `FIGURE-APPLY-DIFF requested paths={...}` — fields requested by explicit Figure -> source Graph apply.
- `FIGURE-APPLY-DIFF post-commit payload-vs-registry=<none>` — expected success condition. Any path listed here means source apply did not preserve the intended GraphState.

## Ownership contract

Figure Graph editing remains an independent editable GraphState copy. It does not automatically modify the source Graph. Explicit `元Graphへ反映` commits the Figure GraphState. Figure-only layout, panel geometry/labels, crop, inset, detached/free legend placement/background, external assets, and Figure export geometry remain outside the source GraphState.

## What to inspect in the next runtime log

For any Graph that redraws more than once after READY, inspect the closest `GRAPH-SINGLE-STATE-DIFF source=live` and `PLOT-CONSUMER` lines. This distinguishes a true late input/state change from a second consumer evaluating the same cached Plot.

For a Figure change that appears not to reach the source Graph, press `元Graphへ反映` and inspect `FIGURE-APPLY-DIFF`. `requested paths` shows what should change; `post-commit ...=<none>` proves the Registry accepted the exact payload.

## Source: `docs/V3_69_0_RUNTIME_DECOMPOSITION_TRACE.md`

# v3.69.0-runtime-decomposition1

`graphServer()` keeps ownership of all reactive state, but major pre-plot responsibilities are now physically separated and sourced into the same local environment.

New runtime files:

- `graph_helpers_runtime.R`
- `graph_data_runtime.R`
- `graph_order_ui_runtime.R`
- `graph_style_ui_runtime.R`
- `graph_prepared_data_runtime.R`

Existing runtime files remain:

- `graph_plot_runtime.R`
- `graph_output_runtime.R`
- `graph_restore_runtime.R`
- `graph_state_runtime.R`

This is intentionally not a new Shiny-module hierarchy.  The sourced code executes in the existing `graphServer()` call frame, preserving current reactive ownership and cross-section references.

## Source: `docs/V3_68_0_PLOT_CONTRACT_TRACE.md`

# v3.68.0-plot-contract1

This stage centralizes plot-type identity/capability rules without changing plot builders.

## New contract API

- `graph_plot_type_specs()`
- `graph_plot_type_ids()`
- `graph_plot_type_choices()`
- `graph_plot_type_normalize()`
- `graph_plot_type_spec()`
- `graph_plot_supports_mapping()`
- `graph_plot_restore_input_ids()`

UI plot choices and restore/mapping capability decisions now consume the same contract. Legacy `violin` project values normalize to the existing box path in one location.

## Source: `docs/V3_67_1_UI_BOOTSTRAP_CLEANUP_TRACE.md`

# v3.67.1-source-cleanup2-ui

## Scope

Behavior-preserving source cleanup extending v3.67.0 to `ui.R` and `global.R`. No redraw fix or overlay behavior is introduced here.

## UI change

Before:

```text
ui.R (~5,311 lines)
  = CSS + browser JS + Shiny component tree
```

After:

```text
ui.R (entry)
ui_shell.R (component hierarchy)
www/app_styles.css
www/app_client.js
```

The CSS and JS assets were extracted from the existing inline R string literals. Escaped R quotes/backslashes were converted to their browser-visible form; handler/function ordering was not changed.

## Global bootstrap change

Before: package attachment, helpers, geometry code, source ordering and graphServer precompile all lived in `global.R`.

After:

```text
global.R
  -> app_dependencies.R
  -> app_shared_helpers.R
  -> app_module_registry.R
```

## Safety intent

This revision does not intentionally change Shiny IDs, module namespaces, GraphState ownership, restore stages, preview logic, render gate, Figure logic, or Project save/load behavior.

## Validation

- `node --check www/app_client.js`
- source target existence check
- UI extraction/reconstruction checks against v3.67.0
- custom lexical balance scan for modified/new R files
- synchronization primitive count comparison against v3.67.0
- ZIP integrity and re-extracted SHA-256 comparison

R/Rscript is not installed in the build container, so runtime R parse/launch must be confirmed on the user's R installation.

## Source: `docs/V3_67_0_SOURCE_CLEANUP_TRACE.md`

# v3.67.0-source-cleanup1

## Purpose

This revision is intentionally a **source-organization pass**, not a rendering-behavior rewrite.
The current app accumulated multiple generations of Graph runtime code: the present persistent
single Editor path and older per-Graph/warm/preload paths. Before changing plot invalidation,
this revision makes those responsibilities visible in the file structure.

## Main changes

### graph_module.R split

`graph_module.R` was ~9.6k lines. Four large contiguous sections were moved without changing
their local ownership: each file is `sys.source()`d into the existing `graphServer()` environment.

- `graph_plot_runtime.R` — prepared plot construction / `make_plot()` (~1.5k lines)
- `graph_output_runtime.R` — plot output, dimensions, preview-facing output logic (~0.5k lines)
- `graph_restore_runtime.R` — settings apply, restore/sync transaction machinery (~2.7k lines)
- `graph_state_runtime.R` — GraphState capture/project state/remount lifecycle (~1.8k lines)
- `graph_module.R` — module shell, data/mapping/style primitives, downloads and returned API (~3.0k lines)

The split is deliberately lexical: the sourced code executes in the same `graphServer()` local
environment. No new reactive owner or cross-module store is introduced.

### server.R split

Three contiguous Graph-runtime sections were isolated:

- `server_graph_editor_runtime.R` — per-Graph compatibility module creation plus persistent single-Editor lifecycle
- `server_graph_preload_legacy.R` — old warm/preload/background restore machinery
- `server_graph_workspace_runtime.R` — legacy `show_graph()` plus current Graph workspace actions

This does **not** yet remove the legacy runtime. It makes the old and current paths separately
auditable so removal can be done deliberately in the next pass.

### Dead code removed

Only functions with zero call/reference sites after the split were removed:

- `figure_commit_edit_revision_snapshot()`
- `figure_clear_committed_fields()`
- `warm_needs_cold()`
- `write_project_file()`
- `schedule_project_preload()`
- `mapping_matches_project()`
- nested `queue_numeric()` in Figure patch handling

No reachable runtime branch was intentionally removed.

## Why this is needed before redraw work

Current plot invalidation is spread across:

1. direct `input$...` dependencies in `make_plot()` (65 unique direct input names),
2. prepared-data/mapping/theme reactives,
3. output size reactives,
4. restore/sync input updates,
5. persistent single-Editor lifecycle,
6. legacy per-Graph/warm/preload lifecycle.

Changing redraw behavior while all of these are interleaved in two ~10k-line files makes it too
easy to add another gate rather than remove a cause. This revision creates boundaries first.

## Next cleanup pass

The next pass should be behavioral and smaller in scope:

1. make persistent single Editor the only ordinary Graph editing path;
2. keep legacy per-Graph module creation only where still proven necessary (legacy package/export/Figure);
3. remove browser/lazy activation state that has no current caller;
4. introduce one explicit plot invalidation boundary rather than adding more callback suppression;
5. separate `UI state ready` from `live plot ready`.

## Validation performed

- Extracted runtime chunks are brace/string/comment balanced under a lexical scanner.
- Removed function names have zero remaining references.
- No new timer/sleep synchronization primitive was added.
- JavaScript files were syntax-checked with Node where applicable.
- ZIP CRC and extracted-file hashes are checked during packaging.

R itself is not installed in the build container, so final R parser/runtime validation remains the
user-side `source('run.R')` smoke test.

## Source: `docs/V3_66_3_EDITOR_FIRST_RENDERGATE_TRACE.md`

# v3.66.3 editor-first render-gate trace

## Why

v3.66.2 proved that dropping one post-READY state callback is not a stable deduplication rule. Runtime logs still showed extra `make_plot()` / `renderPlot()` calls after the suppression line, and complex Graphs could emit several additional renders plus transient Mapping mismatches.

## Change

The persistent single Editor now receives an external reactive `render_gate`. Ordinary and Figure-owned Graph modules default to an open gate.

Transaction:

1. `graph_single_load()` sets `graph_single_render_gate(FALSE)` before any GraphState synchronization.
2. Existing restore/sync machinery updates reshape, Mapping, style, dimensions and other controls while the gate is closed.
3. `make_plot()` requires `render_gate() == TRUE`.
4. `output$plot` independently requires the same gate with `cancelOutput = TRUE`.
5. After READY settle, server commits the completed canonical state, requests the normal single-editor show/preview handoff, then sets `graph_single_render_gate(TRUE)`.
6. That one FALSE -> TRUE transition releases the completed Plot state.

## Removed

`graph_single_post_ready_callback_guard` and the "suppress first post-ready state callback" branch from v3.66.2 are removed.

## Expected diagnostics

During each switch:

```text
[GRAPH-SINGLE-EDITOR][gXXX] render-gate CLOSED for Graph switch transaction
... sync/hydrate ...
[GRAPH-SINGLE-EDITOR][gXXX] load-ready ...
[GRAPH-SINGLE-EDITOR][gXXX] render-gate OPEN; release completed state for one render
[GRAPH-EDIT-PLOT][gXXX] make_plot START ...
[GRAPH-EDIT-DRAW][gXXX] output$plot renderPlot entered
```

No `make_plot START` should occur for the single Editor between CLOSED and OPEN.

## Validation note

The build environment used to package this artifact does not provide `R`/`Rscript`, so runtime `parse()` could not be executed here. Modified R files were checked by focused diff review and lexical delimiter/string scanning; JavaScript syntax was checked with Node. Runtime confirmation on the user's R installation remains the decisive validation.

## Source: `docs/V3_66_2_EDITOR_FIRST_DEDUP_TRACE.md`

# v3.66.2 editor-first dedup trace

## Purpose
Reduce the duplicate post-READY render cycle seen in v3.66.1 without adding the loading overlay yet.

## Observed runtime sequence
After `graph-single-editor-load-ready` committed the settled state, the debounced `project_settings()` observer emitted one additional `on_state_change()` callback. That callback committed as `source=graph-single-editor` and was followed by another `make_plot()` / `renderPlot()` cycle.

## Change
- Add `graph_single_post_ready_callback_guard` scoped by editor generation + graph id.
- Arm it only after the settled `graph-single-editor-load-ready` commit.
- Drop exactly the first subsequent `on_state_change()` callback for the same graph/generation.
- Clear the guard at the start of each new editor-load transaction.
- All later callbacks commit normally, so ordinary user edits are unaffected after the one transaction echo is consumed.

## Expected diagnostic
After READY, the log should contain:

`[GRAPH-SINGLE-EDITOR][gXXX] suppressed first post-ready state callback from sync transaction`

and should no longer show the former immediate `STATE-COMMIT source=graph-single-editor` followed by the extra automatic plot build for that switch.

## Not changed
- editor-first UI
- fixed persistent DOM/module
- cached -> live preview handling
- GraphState restore/hydrate stages
- duplicate/delete/style/export behavior
- no overlay added yet

## Source: `docs/V3_66_1_EDITOR_FIRST_REACTIVEFIX_TRACE.md`

# v3.66.1 Editor-first reactive fix trace

## Runtime failure reproduced from user log

Startup reached the editor-first g001 attach and entered `GRAPH-EDIT-EDITOR-SYNC`, then Shiny raised:

```text
input$plot_type でエラー:
Can't access reactive value 'plot_type' outside of reactive consumer.
```

The editor-first rollback invokes the persistent-editor sync from startup `onFlushed`, which is an explicit transaction callback rather than an observer/reactive expression. The old direct-sync helper had been written while ordinary calls came from reactive consumers, so it still read `input$plot_type` directly.

## Fix

Inside `sync_editor_from_state(cfg)`:

1. Target plot type is now derived only from canonical GraphState: `json_chr(cfg$plot$type, "line")`.
2. The fixed `plot_type` select is updated unconditionally from that canonical target. No `input$plot_type` read is needed during the transaction.
3. Prepared data is obtained as `isolate(dat())` because the explicit transaction needs a snapshot, not a reactive dependency.
4. The whole function was audited and now has no direct `input$...` reads.
5. Mapping verification remains in the existing reactive stage-3 observer after the browser flush.

## Scope

No loading overlay was added. No change was made to Editor-first selection semantics, cached-to-live preview handoff, Graph duplication/deletion, Figure delete confirmation, Graph format copy, export, or Statistics behavior.

## Source: `docs/V3_66_0_EDITOR_FIRST_ROLLBACK_TRACE.md`

# v3.66.0 editor-first rollback trace

## Goal

Rollback only the viewer-style behavior added after the persistent single Editor became fast enough. Keep later correctness fixes. Do not add the loading overlay yet.

## Removed from the active path

- Graph-tab browse-only navigation.
- Section-click activation of a selected-but-not-editing Graph.
- Startup hiding of the persistent Editor controls.
- Browse-only two-column layout and stale-control hiding.
- Session fold-memory restoration as part of Graph activation.

The old browser-preview helpers remain present as dormant compatibility code, but the client preview container is permanently hidden and no active catalog path enters browse mode.

## Active flow

- Startup mounts one persistent Editor and captures pristine defaults.
- g001 attaches automatically after bindings are available.
- Graph tab click emits `graph_edit_select` directly.
- `graph_single_load()` is the single attach/sync entry point.
- Created/duplicated selected Graphs attach immediately.
- Cache-first Project load restores Registry/SVG first, clears old owner, then attaches the selected target.
- Deleting the current Graph attaches the replacement target.
- Global preview continues cached-first and switches to live on image load.

## Retained later fixes

- Registry-canonical duplicate path and preview/state pairing checks.
- Delete cleanup and Figure stale-reference sanitization / warning.
- Graph-format payload corrections and export source resolution.
- Persistent single Editor, fixed Mapping DOM, direct SYNC where structurally compatible.

## Synchronization policy

No new synchronization primitives. Overlay is deliberately deferred to the next revision after runtime validation.

## Source: `docs/V3_65_2_ACTIVATION_LAYOUT_TRACE.md`

# v3.65.2 activation layout trace

## Symptom

With v3.65.1 the dormant/collapsed Editor controls still appeared *below* the cached preview during browse.

## Cause

`graph_client_browser` and `graph_panels` were sibling block elements. Browse CSS intentionally hid the live plot column and expanded the control column to 100%, so the browser preview occupied one block row and the persistent Editor summaries occupied the next row. The startup/pristine hide rule did not change this layout once a Project supplied a saved preview.

## Fix

- Wrap `graph_client_browser` and `graph_panels` in `graph_workspace_body`.
- While browsing, add `client-browse-layout` and render a two-column CSS grid: Editor summaries on the left, cached preview on the right.
- Keep the singleton Editor DOM mounted and keep all control bodies hidden while browsing.
- On edit READY (or same-Graph live edit), remove the browse grid class and return to the ordinary graph module layout.
- On narrow screens (<900px), fall back to one column.

## Architecture preserved

- Graph tab change: selected Graph only, no GraphState synchronization.
- Section click/Edit: attach selected Graph to the persistent Editor.
- Registry remains canonical.
- Accordion state remains session-only.
- No new timer/polling synchronization.

## Source: `docs/V3_65_1_ACTIVATION_PREVIEW_TRACE.md`

# v3.65.1 activation / preview trace

## Runtime symptom from v3.65.0

- `g002` completed structural hydration and reached READY, so GraphState restoration itself succeeded.
- The client then requested `preferLive=TRUE` while the new live image had not loaded yet.
- The old client logic simultaneously selected `graph-preview-mode-live` and `graph-preview-live-pending`. CSS hid the cached layer because mode was live, and hid the live layer because it was pending. The result was a blank Graph area until the IMG load event.

## Fix

- If `preferLive=TRUE`, a cached SVG exists, and the live layer is not a reused warm layer, keep preview mode `cached` while marking live as pending.
- The existing IMG `load` listener performs the final cached -> live transition.
- `graph_panels` starts with `client-browse-hidden client-pristine-no-preview` in the initial HTML so the dormant singleton Editor cannot appear before JavaScript receives its first catalog.

## Scope

No GraphState, mapping, restore-stage, Figure, copy, delete, format, or export semantics were changed. No new timer/polling primitive was added.

## Static validation

- 15 top-level `.R` files: lexical delimiter/string/backtick scan PASS.
- Embedded JavaScript extracted from `ui.R`: `node --check` PASS.
- `www/figure_interaction.js`: `node --check` PASS.
- Runtime Shiny validation remains required on the user's R environment.

## Source: `docs/V3_65_0_ACTIVATION_TRACE.md`

# v3.65.0 activation-control1 — static trace

## Scope

This release intentionally changes only activation gating and deletion UX around the persistent singleton Graph Editor.

## Ownership/state trace

- `editing_graph_id`: canonical server-side owner of `graph_editor_single`.
- `graph_single_editor_loading`: TRUE while one SYNC/HYDRATING transaction is in flight.
- `graph_single_editor_mode`: IDLE / HYDRATING / SYNC / READY.
- `graph_single_editor_generation`: invalidates stale settle callbacks when ownership changes/deletes.
- `graph_client_selected`: client-side browse selection; does not imply Editor ownership.
- `window.ggplotGuiPendingEditorActivation`: session-only pending section activation; last clicked section wins.
- `window.ggplotGuiGraphEditorUiState`: session-only accordion memory; never serialized into GraphState/Project.

## Activation flow

1. Browse changes only client selection + cached preview.
2. While browse/SYNC/HYDRATING, stale Editor contents are not interactive.
3. A section click starts one `graph_edit_select -> graph_single_load()` transaction.
4. Additional clicks for the same Graph while loading do not start new transactions; only the pending section key is updated.
5. `graph-client-edit-ready` releases controls and restores the target Graph's session-only folds.
6. A fresh startup Graph with no persisted preview and no Editor owner hides the dormant parameter shell; the Editor bar is the fallback activation affordance.

## Figure delete warning

Before showing the Graph delete confirmation, the server counts:

- internal Graph references in `figure_layout_state()` cells;
- enabled internal Graph inset references in `figure_override_drafts()`.

If any are found, the modal warns that deleting the Graph also removes those Figure references. Deletion cleanup and the existing Figure sanitizer are unchanged.

## Synchronization audit

No new timer/polling primitive was added relative to v3.64.2:

- `Sys.sleep`: 0 -> 0
- `setTimeout`: 19 -> 19
- `setInterval`: 0 -> 0
- `MutationObserver`: 1 -> 1
- `invalidateLater`: 4 -> 4
- `reactivePoll`: 0 -> 0
- `reactiveTimer`: 0 -> 0

## Runtime limitation

The build environment has Node.js but no R/Rscript. R files were therefore checked with a lexical delimiter/string/backtick scan; the client JavaScript fragment was checked with `node --check`. Runtime Shiny behavior must be confirmed on the user's R environment.

## Source: `docs/V3_64_2_FORMAT_EXPORT_TRACE.md`

# v3.64.2 Graph style / export static trace

## Graph書式 entry points

- `style_clipboard` is session-scoped (`server.R`) and is shared across Graphs / Projects in one app session.
- Copy: `style_settings()` -> `style_clipboard`.
- Paste: `style_clipboard` -> `apply_style_config()`.
- Save: `style_settings()` -> JSON.
- Load: JSON -> `apply_style_config()`.
- The toolbar lives in the editor main panel. In browse-only mode the stale main panel is hidden, so a Graph that is merely selected but not the current editor owner cannot expose the old Graph's style toolbar.

## Style payload contract

Included:
- color / linetype / shape / series / regression styles
- raw-point and ID-line display styles
- display order state
- legend-title / condition display-label overrides
- theme / font / base size
- summary visual settings retained for compatibility
- regression appearance
- bar / box / spacing settings
- error-bar appearance
- Y-axis break settings
- legend placement / legend key width / facet spacing
- plot width / plot height
- v3.64.2: Y minimum, Y maximum, top-to-last-tick

Intentionally excluded:
- raw Data and reshape source
- Mapping and external-error column bindings
- Statistics recipes/results
- plot type / Graph structural identity
- Graph title / X-axis title / Y-axis title text
- top-level export target and export format
- preview Auto/manual zoom
- session-only accordion fold memory
- `sticky_plot` in newly emitted payloads (older JSON is still accepted)

Rationale: Graph書式 should describe the rendered/exported appearance while avoiding source-data identity, analysis recipes and editor-only presentation state.

## Export path audit

The single-editor architecture introduced an asymmetry:
- actual export (`write_one_graph`) already used `source_graph_module(id)`, which can resolve the persistent editor owner;
- readiness/preparation/status used legacy `modules[[id]]` directly.

That could leave Current / Selected / All export disabled or "preparing" even though the current Graph was READY in `graph_editor_single`.

v3.64.2:
1. adds `source_graph_ready(id)`;
2. uses it for export pending, ready, status and final not-ready checks;
3. explicitly depends on `editing_graph_id`, editor mode and loading state;
4. never schedules a legacy background preload for the Graph currently owned by the persistent editor;
5. waits for an in-flight persistent editor transaction instead.

## Export-size semantics

Top-level SVG / PNG / PDF output dimensions follow the Graph's plot width / height. Those dimensions are part of Graph書式, so copying a style also copies the output-size basis. Export target/format remain global action choices and are not Graph state.

## Manual checks

1. Edit Graph A and export with target = Current. Download should enable when the persistent editor is READY.
2. Choose target = Selected and include A plus dormant Graphs. A should count as ready without spawning a legacy A module; dormant Graphs may prepare normally.
3. Choose target = All. Same rule as above.
4. Copy style from A to B. Confirm width/height and Y range/top-to-tick follow A.
5. Confirm Graph title and X/Y axis-title text on B remain unchanged.
6. Confirm scroll-follow (`sticky_plot`) and accordion state do not change after paste.
7. Save style JSON and load it into another Graph. Confirm the same contract.
8. Load an older style JSON containing `sticky_plot`; it should remain backward-compatible.

## Source: `docs/V3_64_1_DUPLICATE_DELETE_TRACE.md`

# v3.64.1 duplicate / delete static trace

## Scope

Static audit of Graph copy and delete paths after the persistent single-editor / lazy UI pivot.

## Duplicate path

Entry: `observeEvent(input$graph_duplicate, ...)`.

Previous risk:

- The handler read `modules[[id]]`, but ordinary editing now lives in the singleton `graph_editor_single` module.
- Therefore an immediate duplicate of the currently edited Graph could copy Registry state / SVG that lagged the live editor.
- `create_graph(... initial_preview=...)` seeds the inherited SVG as a clean preview associated with `initial_state`, so pairing a stale SVG with a newer state is especially unsafe.

Current rule:

1. If source == `editing_graph_id` and single editor is loading, block Copy.
2. If source == ready single-editor owner, synchronously `graph_single_commit("duplicate-source")`.
3. Copy state only from canonical Registry (`cache_get`).
4. Refresh source SVG through `refresh_graph_preview_from_live(... mod_override=graph_single_mod())`.
5. Inherit the SVG only when its embedded `state` exactly matches the copied canonical state.
6. For dormant Graphs, do not inherit a preview while `graph_preview_is_dirty(id)` is true.
7. Session-only fold memory is not copied. `create_graph()` selects the duplicate in browse mode; first section activation establishes that Graph's own session UI memory.

## Delete path

Entry: `observeEvent(input$graph_delete, ...)` and confirmation handler.

Existing cleanup verified:

- canonical GraphState cache
- persisted Graph preview
- live Graph preview cache / dirty marker / preview observer
- Figure persisted snapshot references
- Figure loaded plot/export/asset/draft references
- preload queue / current target / pending display / restore target
- Figure requested ids and geometry cache
- `graph_meta` row
- active/editor owner fallback
- client preview catalog (which prunes missing Graph session UI-state ids)
- Figure layout is reactively sanitized against current `graph_meta`; stale Figure Inspector selection is cleared.

Additional hardening:

- block deletion when target == persistent editor owner and `graph_single_editor_loading()` is true;
- when deleting editor owner, clear loading/mode, bump generation, clear settle transaction;
- clear Figure snapshot revision and commit-edit revision records;
- client preview-catalog handler also clears a pending section activation if its Graph id no longer exists.

## UI memory semantics

The per-Graph accordion state is browser-session presentation state, not GraphState.

- Copy: does not inherit it.
- Delete: removed id is pruned.
- Project replacement: whole map is cleared.
- Session end: map naturally disappears.

## Intended manual checks

1. Edit Graph A, change a visible setting, immediately Copy. Confirm copied Graph has the latest setting.
2. Immediately Copy while A is visibly syncing: operation should be refused until ready.
3. Copy A while its sections are open. Select copy: sections should be closed; activating a section should not restore A's fold pattern.
4. Delete a non-editing browsed Graph: remaining editor owner should stay valid.
5. Delete current editor owner: editor shell should clear, remaining Graph should be browsed, then activate normally.
6. Delete a Graph used in Figure: Figure cell/Inspector must no longer retain the deleted source id.
7. Try Delete while single editor is syncing the target: operation should be refused until ready.

## Source: `docs/V3_64_0_STATIC_TRACE.md`

# v3.64.0-lazyui1 static state trace

This note documents the ordinary Graph browse/edit path after the lazy-Editor change.

## Persistent identities

| State | Location | Meaning | Persistence |
|---|---|---|---|
| `graph_client_selected` | browser -> Shiny input | Graph currently viewed/selected | current page/session |
| `editing_graph_id` | `server.R` reactiveVal | Graph whose GraphState currently owns the fixed Editor | current Shiny session |
| `graph_single_editor_module` | `server.R` reactiveVal | one fixed `graph_editor_single` module | current Shiny session |
| `graph_state_cache` | `server.R` reactiveVal | canonical GraphState Registry | session + serialized Project state |
| `graph_single_default_state` | `server.R` reactiveVal | pristine Editor state captured before any Graph owns it | current Shiny session |
| `ggplotGuiGraphEditorUiState` | browser JS object | per-Graph fold/open presentation state | current browser session only |

## Writers of `editing_graph_id`

Ordinary single-editor activation writes the target at the start of `graph_single_load()`, before the previous Graph commit is published. Project/delete lifecycle code may clear or set it as part of explicit project transitions. Graph tab browse alone does not write it.

## Browse path

`graph tab click -> ggplotGuiBrowseGraph(id)`

- updates `ggplotGuiClientSelectedGraph`;
- captures folds only if the Graph being left is exactly the READY editor owner;
- closes top-level parameter sections;
- shows cached browser SVG;
- leaves persistent Editor DOM mounted;
- hides the stale live/main pane through browse CSS;
- sends `graph_client_selected` and `graph_client_mode='browse'`;
- does **not** send `graph_edit_select`.

Therefore no GraphState attach/hydration is started by ordinary browsing.

## Section activation path

`top-level summary click` is intercepted only when:

- the module is `graph_editor_single`, and
- selected Graph != editing Graph, or editor is not READY.

The click is consumed, its `data-ui-section` key is saved in `ggplotGuiPendingEditorActivation`, then the existing `graph_edit_select` input is sent.

Server path:

`graph_edit_select -> graph_single_load(id)`

1. captures previous editor state if another owner exists;
2. switches `editing_graph_id` to target;
3. blocks reverse Registry commits with `graph_single_editor_loading=TRUE`;
4. commits previous owner explicitly;
5. loads canonical target GraphState;
6. chooses `SYNC` only when compatible, otherwise structural `HYDRATING`;
7. after ready/settle commits target state and sends `graph-client-edit-ready`.

Browser READY path restores the target Graph's session-only fold map and forcibly opens the section that initiated activation.

## Pristine Graph path

A target with no entry in `graph_state_cache` is pristine, regardless of the caller's `new_graph` flag. This specifically covers startup `g001`.

Default state capture is attempted:

1. immediately after fixed module creation;
2. after a browser flush (`startup-post-bind`);
3. on first activation only when no Graph previously owned the shell.

Once an editor owner exists, `mod$state()` is never eligible to become the pristine default.

A pristine target is seeded into Registry before Editor attachment. The old incidental-shell branch (`graph-single-editor-new` / `load-ready new/default`) is removed.

## Session-only fold memory

Remembered elements:

- `details.control-section` (stable `data-ui-section` keys);
- static `details.control-subsection` (keyed by parent top section + subsection index).

Not remembered yet:

- scroll position;
- arbitrary nested unnamed `<details>` inside style blocks;
- active tab within Graph main panel.

These can be added later without changing GraphState.

## Synchronization policy

No new timing primitive was introduced. v3.64.0-lazyui1 keeps the v3.63.2 counts for:

- `Sys.sleep`: 0
- `setInterval`: 0
- `reactivePoll`: 0
- `reactiveTimer`: 0
- existing `setTimeout`, `MutationObserver`, and `invalidateLater`: unchanged

The new behavior is event-driven: Graph click, section click, existing Editor READY message.

## Source: `docs/current/V3_61_0_VALIDATION.md`

# v3.61.0 validation

## Scope

Graph workspace true single-editor architecture.

- One fixed Graph editor DOM/module namespace: `graph_editor_single`.
- Graph tab browse remains cached-SVG only.
- Explicit Edit is the only normal path that loads a GraphState into the editor.
- `editing_graph_id` is logical ownership; DOM/module identity does not depend on Graph ID.
- Figure keeps its own independent Figure-owned single editor.
- Legacy per-Graph module/remount machinery remains only for compatibility/export fallback and is bypassed by normal Graph editing.

## Transaction

Expected normal edit switch:

```text
commit previous GraphState
-> editor_mode = HYDRATING
-> load_state(target)
-> staged reshape/mapping restore
-> post-flush state settle
-> editor_mode = READY
-> show fixed editor
```

During HYDRATING, singleton `on_state_change` does not commit mixed transient values to the Registry.

## Static validation

- All 15 `.R` files pass the local lexical delimiter/string/backtick scan.
- Embedded JavaScript extracted from `ui.R` passes `node --check`.
- No increase from v3.60.2 in `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer` occurrences.
- Patch applies cleanly to the exact v3.60.2 source baseline and reproduces the release tree exactly.
- ZIP CRC test passes and a fresh ZIP extraction matches the release tree exactly.
- R/Rscript is unavailable in the build environment, so no R/Shiny/browser runtime test was performed.

## Manual smoke test

1. Open an existing `.ggplotpack`; browse several Graph tabs. No Graph editor hydrate should start.
2. Edit g003. Expect one `[GRAPH-SINGLE-EDITOR][g003] load-request ... mode=HYDRATING`, then `load-ready`.
3. Click g004 without Edit. g004 cached preview should show; singleton editor is hidden but remains alive.
4. Click g003. Existing editor should reappear immediately; no `UI-MOUNT`, `UI-REMOUNT`, or new graphServer instance should occur.
5. From g003, browse g004 and press Edit. Expect `commit previous=g003`, then one singleton load of g004; there must not be a second Graph graphServer instance.
6. Return to g003 and explicitly Edit if g004 currently owns the editor. g003 should load into the same singleton module, not remount a g003 DOM.
7. Add a new Graph. It should become selected+editing automatically and load the pristine default state rather than inheriting the prior Graph.
8. Verify Figure behavior remains the v3.60.1/v3.60.2 single-Figure-editor flow and source/Figure state boundaries remain intact.

## Source: `docs/current/V3_60_2_VALIDATION.md`

# v3.60.2 validation

## Scope

Narrow Graph-workspace presentation fix on top of v3.60.1.

- Same-Graph tab click (`selected_graph_id == editing_graph_id`) preserves Edit mode when the live editor panel still exists.
- The cached browser SVG is not shown on top of that same live editor.
- Different-Graph tab clicks remain preview-only and hide, rather than destroy, the editing Graph DOM/bindings.
- Figure single-editor `HYDRATING -> READY` transaction behavior is intentionally unchanged.

## Static validation performed

- Exact baseline: `ggplot_gui_v3_60_1_source.zip`.
- Runtime R changes: `ui.R` plus the `server.R` version diagnostic only.
- 15 top-level `.R` files passed delimiter/string/backtick lexical scan.
- Embedded JavaScript was extracted from `ui.R`; `node --check` passed.
- No increase from v3.60.1 in `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer` occurrences across runtime R/JS files.
- Patch `git apply --check` passed against a fresh exact v3.60.1 baseline.
- Applying the patch to that fresh baseline reproduced the release tree exactly.
- Source ZIP CRC test passed.
- Re-extracted ZIP tree matched the release tree exactly.
- R / Rscript were not available in the build environment; no R/Shiny/browser runtime test was performed.

## Expected runtime smoke test

1. Edit Graph 3 until its editor is READY.
2. Click Graph 3's tab again.
   - Graph 3 remains in Edit mode.
   - No duplicate browser preview appears above the Graph 3 editor.
   - No new `UI-MOUNT`, `MODULE instantiate`, or `RESTORE` occurs from that click.
3. Click Graph 2.
   - Graph 2 cached SVG appears immediately.
   - Graph 3 editor controls are hidden, not destroyed.
4. Click Graph 3 again.
   - The already-live Graph 3 editor reappears immediately without hydrate/remount.
5. Recheck the first Figure edit; v3.60.1 Figure transaction behavior should be unchanged.

## Source: `docs/current/V3_60_1_VALIDATION.md`

# v3.60.1 validation

## Scope

Runtime changes are intentionally limited to `server.R` and `ui.R`. Documentation changes update the current roadmap/changelog only.

### Graph presentation fix

- Browser selection remains client-side SVG only.
- If a different Graph still owns the live editor, `#graph_panels` is hidden with the existing `client-browse-hidden` mechanism while the Editor shell reports selected vs editing ownership.
- The editor DOM/module is not removed or rebound by this visibility change.

### Figure hydration transaction

- Explicit modes: `IDLE`, `HYDRATING`, `READY`.
- Reusable Figure controls are hidden throughout hydration.
- `on_state_change` stays blocked while `figure_single_editor_loading` is true.
- After module `ready()`, state is sampled on consecutive Shiny flush checkpoints; the wrapper is shown only after two stable comparisons. After five unstable checkpoints it remains hidden and requires an explicit same-panel retry; unstable state is never exposed as READY.
- No FigureState/snapshot write occurs merely because a load completed.
- Same-item edit retains the existing `reuse-hit` path.

## Static validation

- R lexical delimiter/string/backtick scan: PASS (15 R files).
- Embedded JavaScript extracted from `ui.R` and checked with `node --check`: PASS.
- No added `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer`.
- Runtime R diff versus docs-clean v3.60.0: `server.R`, `ui.R` only.
- Patch applies to exact docs-clean v3.60.0 baseline and reproduces the release tree: PASS.
- ZIP CRC and re-extracted tree match: PASS.
- R/Shiny/browser runtime test: NOT RUN in the build environment.

## Manual smoke test

1. Open packaged Project, edit Graph A, then click Graph B without editing it. Expected: Graph B SVG preview is visible; Graph A controls are hidden but ownership remains shown in the shell.
2. Click Edit on Graph B. Expected: normal editor transition, Graph B controls appear when ready.
3. Figure: select panels freely. Expected: no Figure Graph editor hydrate from selection alone.
4. Click `このPanelを編集` on an editable Figure panel. Expected log: `mode=HYDRATING`, `restore-ready; waiting for post-restore settle`, one or more `settle-check`, then `load-ready`. Controls should appear only after `load-ready`.
5. Immediately change one Figure Graph setting once controls appear. Expected: the first change persists; it is not reverted by late restore reflection.
6. Re-edit the same Figure panel. Expected: `reuse-hit`; no state reload.

## Source: `docs/V3_60_0_DOCS_CLEAN_VALIDATION.md`

# v3.60.0 documentation-clean validation

This package is a documentation-only cleanup of the exact v3.60.0 source tree.

## Intended changes
- Runtime code/assets/configuration remain byte-identical to v3.60.0.
- Historical pre-v3.59 markdown is consolidated into one archive with full source text and duplicate-path inventory.
- v3.59+ validation notes are retained under `docs/current/`.
- Runtime-required text files remain in the root.

## Checks
- non-documentation file byte comparison against v3.60.0: PASS (performed during packaging)
- archive includes every removed markdown file by SHA256 inventory: PASS
- `req.txt`, `anovakun_489.txt`, `anovakun_489_10.txt`: retained
- no runtime R/JS files changed
- ZIP CRC and re-extracted tree comparison: performed during packaging

## Source: `docs/current/V3_60_0_VALIDATION.md`

# v3.60.0 validation

## Scope

Architecture transition, phase 1:

- Figure selection (`selected_figure_item`) is separated from Figure Graph-editor ownership (`figure_editing_graph`).
- Figure tab activation and panel clicks are browse/inspect only.
- A new explicit **このPanelを編集** action loads the selected Figure-owned GraphState.
- One fixed Figure controls-only `graphServer`/DOM is reused across Figure Graphs.
- Figure state switching uses the existing `mod$load_state()` staged restore path; editor writes are gated while loading and released only when `mod$ready()` is true.
- Existing Graph browse/edit separation remains unchanged; only the Graph editor-shell label was corrected to name the actual editing Graph.

Full Graph-side single-editor conversion is not part of v3.60.0. This release deliberately validates the reusable-editor pattern on the Figure side first, where logs showed repeated per-panel `FIGURE-EDIT-MOUNT` / binding restore costs.

## Expected runtime behavior

1. Open an existing Project and click **Figure**.
   - Figure preview/layout should appear.
   - No `FIGURE-EDIT-MOUNT` / `FIGURE-SINGLE-EDITOR UI inserted` should occur merely because the Figure tab opened.
2. Click several Figure panels.
   - Inspector/selection changes.
   - No Figure Graph editor hydrate should occur.
3. Click **このPanelを編集** on a panel with an editable Figure GraphState.
   - Exactly one `FIGURE-SINGLE-EDITOR ... UI inserted` should occur on the first edit.
   - The reusable editor hydrates and reaches `FIGURE-SINGLE-EDITOR ... load-ready`.
4. Select a different panel without pressing edit.
   - Figure status should show selected vs editing as different.
   - Editor remains on the previous Graph; no restore begins.
5. Press **このPanelを編集** for the different editable Graph.
   - No second editor DOM/module insertion should occur.
   - Expect `FIGURE-SINGLE-EDITOR[gXXX] load-request previous=gYYY`, staged restore logs, then `load-ready`.
6. Re-edit the already editing panel.
   - Expect `FIGURE-SINGLE-EDITOR ... reuse-hit`; no restore.

## Static validation performed

- 15 top-level R files passed a lexical delimiter/string/backtick scan.
- Embedded JavaScript was extracted from `ui.R` and passed `node --check`.
- Runtime R changes are limited to `server.R`, `figure_ui_module.R`, and `ui.R`.
- No new synchronization primitive was added. Counts for existing `setTimeout`, `MutationObserver`, `invalidateLater`, etc. were compared against v3.59.2 and are unchanged; `Sys.sleep`, `setInterval`, `reactivePoll`, and `reactiveTimer` remain absent where absent in baseline.
- Patch apply/tree and ZIP CRC/re-extract checks are performed during packaging.

## Runtime validation

Not executed in the build environment. R/Rscript is unavailable here. Browser/Shiny behavior must be validated from the user's runtime logs.

## Source: `docs/current/V3_59_2_VALIDATION.md`

# v3.59.2 validation

## Scope

This release is intentionally narrow. It changes the fresh-session Graph startup path only.

- `graphUI("g001")` remains the static UI shell already present in `ui.R`.
- On the first Shiny browser flush of a pristine new session, `g001` becomes both selected and editing and the existing live editor lifecycle is started automatically.
- If Project restore has already started before that flush, the eager startup editor is skipped.
- Existing packaged Project restore remains cache-first / preview-first and clears `editing_graph_id` as before.
- Figure behavior is unchanged.
- No single-editor transaction redesign is included yet.

## Runtime files changed

- `server.R`

Documentation changed:

- `README.md`
- `CHANGELOG.md`
- `V3_59_2_VALIDATION.md` added

## Static validation performed

- All 15 `.R` files passed a delimiter/string/backtick lexical scan.
- Compared against the exact v3.59.1 source baseline: only `server.R` changed among runtime `.R` files.
- No newly added `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer` synchronization.
- `ui.R` / embedded JavaScript was not changed in this release, so no new JavaScript syntax path was introduced.
- Patch applies cleanly to the exact v3.59.1 baseline and reproduces the v3.59.2 release tree exactly.
- Source ZIP passes CRC validation and re-extracts to an exact tree match.

## Runtime validation status

No R/Shiny/browser runtime test was executed in the build environment. `R` / `Rscript` are unavailable there.

## Manual smoke test

1. Start the app without loading a Project.
   - Expected: `g001` Editor begins automatically after the first browser flush.
   - Expected diagnostics: `STARTUP-EDITOR ... scheduled`, then `EDITOR-SHELL[g001] startup-new-project-auto-edit`, followed by the normal editor lifecycle and `EDITOR-SHELL[g001] ready`.
   - No parameter click should be required to instantiate `graphServer`.
2. Start the app and then load an existing `.ggplotpack`.
   - Expected: restored Graphs remain cache-first / preview-first; Project restore does not hydrate restored Graphs merely because they are selected.
   - The temporary startup `g001` editor may already have been constructed before the user chooses the file; Project replacement drops that old module/DOM through the existing replacement path.
3. Create another new Graph with `+`.
   - Expected: existing v3.59.1 behavior remains: the new Graph becomes selected + editing and opens directly.

## Source: `docs/current/V3_59_1_VALIDATION.md`

# v3.59.1 validation

## Scope

Graph-side UX/state-flow preparation only. This release keeps v3.59.0 client-side preview-first browsing and adds a persistent lightweight Editor shell plus explicit separation between the Graph being browsed and the Graph owning the live editor.

### Runtime changes

- `server.R`
  - adds `editing_graph_id` distinct from browser selection / legacy `active_graph`;
  - Project cache-first open clears editor ownership and remains preview-only;
  - explicit Edit assigns editor ownership and uses the existing `client-edit` lifecycle;
  - genuinely new Graphs are edit-first and start the existing editor lifecycle immediately;
  - current-Graph export/save flush now uses the explicit editing Graph rather than preview selection;
  - deleting the editing Graph clears editor ownership; deleting a merely selected Graph preserves another live editor;
  - adds concise `[EDITOR-SHELL]` diagnostics.
- `ui.R`
  - adds an always-visible compact Editor shell bar;
  - browse-only selection updates the shell without hydrating a Graph module;
  - if Graph A remains edited while Graph B is browsed, A's existing editor DOM is preserved rather than hidden/retargeted;
  - Edit/new-Graph readiness updates the shell through existing Shiny message flow.

Figure, Statistics/Analysis, ggplot rendering, preview scaling, export rendering engine, JIT/precompile, restore ordering and binding machinery are unchanged.

## Static validation performed

- 15 top-level `.R` files: delimiter/string/backtick lexical scan: PASS.
- Embedded JavaScript extracted from `ui.R`: `node --check`: PASS.
- Added-line scan confirms no new `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer`.
- Runtime-code diff is limited to `server.R` and `ui.R`; remaining changes are version/docs/validation.
- ZIP CRC test: PASS.
- Release ZIP re-extraction SHA256 tree comparison: PASS.
- Patch applies cleanly to the exact v3.59.0 source baseline and reproduces the v3.59.1 release tree: PASS.

No R/Shiny/browser runtime test was executed for this build.

## Expected manual smoke test

1. Open an existing packaged Project: saved SVG preview appears immediately; Editor shell is visible but no Graph hydrate starts until Edit.
2. Browse Graph 2 / Graph 3: preview switches client-side; `selected_graph_id` changes while `editing_graph_id` remains unchanged.
3. Edit a selected Graph: the existing editor lifecycle hydrates that Graph; shell reports it as editing when ready.
4. While Graph A is editing, browse Graph B: B's SVG preview appears immediately while A remains the editing Graph until explicit Edit on B.
5. Create a genuinely new Graph with `+`: it becomes selected + editing and opens its editor automatically, with no second Edit click.
6. Delete a merely browsed Graph while another Graph is editing: the existing editor remains owned by the editing Graph. Delete the editing Graph: editor ownership is cleared and the shell returns to preview-only state.

## Source: `docs/current/V3_59_0_VALIDATION.md`

# v3.59.0 validation

Baseline: exact `ggplot_gui_v3_58_5_1_source.zip`, SHA256 `032bb1d27ae783f884ed5babd4f58a58f7b0299f7ee3a6eb62cf1e07ba195f0e`.

## Architecture change

v3.59.0 is intentionally a direction change rather than another warm-remount optimization.

- Graph tab clicks are **client-first preview selection**. The browser switches among cached SVG records without calling `show_graph()` and without mounting/restoring a Graph editor.
- The browser sends only lightweight selected-ID bookkeeping (`graph_client_selected` / browse-mode state). That bookkeeping does not hydrate, bind, restore, or render a Graph.
- A persisted `.ggplotpack` with usable Graph previews opens with **no background Graph hydration**. `schedule_project_preload(target)` is no longer called on the cache-first path.
- Hydration starts only after explicit **編集 / このGraphを編集**. The existing serial mount → bind → restore lifecycle is retained for that explicit edit transition.
- While the edit lifecycle is running, the cached browser preview remains visible. It is released only after the editor reaches READY.
- Returning from Figure to Graph respects browser browse mode and does not silently hydrate a dormant Graph.
- Rename/delete/duplicate operate on the browser-selected Graph. A dormant duplicate uses canonical GraphState + cached SVG and therefore does not require source hydration.
- `GraphState Registry` remains canonical truth. Browser SVG data is display-only cache.
- Existing Figure behavior, Statistics/Analysis logic, ggplot rendering/export engine, JIT precompile, and Figure snapshot ownership were not redesigned here.
- Export option `current` is intentionally relabeled **現在編集中のGraph** and keeps its prior hydrated-editor semantics; preview-only browsing does not start export hydration.

## Runtime files changed

- `server.R`
- `ui.R`

Documentation changed: `README.md`, `CHANGELOG.md`; this validation file is new.

## Static checks actually run

- PASS: delimiter/string/backtick lexical scan of all 15 `.R` files.
- PASS: embedded JavaScript extracted from the R string and actually checked with `node --check`.
- PASS: no newly added `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer` in runtime diff.
- PASS: dangerous selector-quote grep used for the historical `querySelector("[id$="...")` failure pattern.
- PASS: runtime diff limited to `server.R` and `ui.R`.
- PASS: release ZIP CRC and exact extracted-tree SHA comparison.
- PASS: patch applied to a fresh exact v3.58.5.1 baseline and reproduced the release tree.

R/Rscript, Shiny, and a browser runtime were not available/executed for this build. Static checks do **not** establish end-to-end correctness or performance.

## First smoke test

1. Open the same packaged Project.
2. Before pressing Edit, click `g002 → g004 → g006 → g003`.
3. Expected: SVG changes immediately. There should be no `UI-MOUNT`, `MODULE instantiate`, `RESTORE`, or `PRELOAD START` caused by those tab clicks.
4. Press **編集** on one Graph.
5. Expected: `[CLIENT-BROWSE] edit requested; hydrate on demand`, followed by the existing single Graph restore lifecycle. The SVG preview should remain visible until READY.
6. Click a different Graph tab after editing.
7. Expected: return immediately to client SVG browsing; no new Graph hydrate until Edit is pressed again.

This smoke test is deliberately aimed at the new boundary: **viewing a Graph is no longer the same operation as editing a Graph**.

---

# Historical architecture / inventory snapshots


## Source: `docs/archive/PRE_PIVOT_HISTORY_v3_49_to_v3_58_5_1.md`

# Pre-pivot architecture/history archive (v3.49–v3.58.5.1)

This file consolidates the documentation that accumulated before the v3.59 architecture pivot.
The pivot changed the optimization target from **making Graph/Figure restore and remount faster** to **avoiding editor hydrate during browse, then reusing a single editor for explicit editing**.

## Why this archive exists

The old ZIP had many version-specific validation and design notes in both the project root and `docs/`, including exact duplicates. They are historically useful, but keeping them as dozens of top-level files obscured the current architecture. This archive preserves their content while removing those duplicate/obsolete files from the active documentation surface.

Runtime support text files are intentionally **not** archived or removed: `req.txt`, `anovakun_489.txt`, and `anovakun_489_10.txt` remain in place because the application references them.

## Condensed pre-pivot timeline

- **v3.49–v3.51:** restore diagnostics, error visibility, preview-stage restructuring, and targeted runtime checklists.
- **v3.52:** removed diagnostic-only sparse binding probes while keeping progression-critical ACK gates.
- **v3.53–v3.54:** moved toward a singleton Graph Preview; v3.54 fixed it in one stable outer location.
- **v3.55:** restore fast path using preseeded browser values, deferred hidden Figure-editor hydrate, and READY live-preview revisit.
- **v3.56–v3.56.2:** instrumentation isolated first-call `graphServer` latency and identified compiler/JIT cost.
- **v3.57:** `compiler::cmpfun(graphServer)` moved to startup; subsequent 3.57.x releases fixed preview geometry/remount and selector-escaping issues.
- **v3.58–v3.58.3.6:** preview scaling, Statistics recipe persistence, sticky-follow/tab visibility, and several parser/UI hotfixes.
- **v3.58.4–v3.58.4.1:** Figure editor fast/no-op paths plus restore correctness fixes (ACK/value phase split, Figure apply cancellation, checkbox-group capture, remount-generation proof, manual retry).
- **v3.58.5–v3.58.5.1:** warm-DOM/LRU experiment. Runtime evidence showed repeated `state-mismatch` rejection and no useful warm hits; this helped motivate the v3.59 pivot.

## Current interpretation of the old work

The restore/remount work was not wasted: it established the important correctness boundaries (Registry canonical truth, explicit Figure↔Graph synchronization, generation-safe ACKs, no arbitrary sleeps/polling) and exposed the true cost center: browser/Shiny editor establishment rather than `make_plot()`. Those lessons remain constraints for the single-editor architecture.

---

## Archived source inventory

- `RESTORE_OPTIMIZATION_NOTES.md` — SHA256 `3ef59faaa33c2b56f55b9358c4200af4e0b2598b8cb7995cd1ac7cd74f3ffa27`
- `V3_54_VALIDATION.md` — SHA256 `62f3d73dc55c2094cab34be83190e53e26f3aa6cdfd0ae124a30cf7e6a3243b9` — duplicate paths: `docs/V3_54_VALIDATION.md`
- `V3_55_VALIDATION.md` — SHA256 `d9963c0ec7e414fdc6e9d17726343c008aa9a7e5e9d83c12aa69251aecaa4f12` — duplicate paths: `docs/V3_55_VALIDATION.md`
- `V3_56_1_VALIDATION.md` — SHA256 `e667220383f5c4dfda8cbd02d6a0b07d70345b31ce6cbb2fa45884b44386df57`
- `V3_56_2_VALIDATION.md` — SHA256 `7021b1619072ff68e3c116e75e92b166e41d1835fd6561e028605d13d8fbc3cb`
- `V3_56_VALIDATION.md` — SHA256 `bf68389861ed8ada4e6d69aba6259d97a5f746fe07187ecbbe1d6256b4f7e6c7`
- `V3_57_1_VALIDATION.md` — SHA256 `20965c6d3e1d56507e221c90ec3e733044657676c00e2599c70b73f8b316fcfa`
- `V3_57_2_1_VALIDATION.md` — SHA256 `907bc7e880d85c679547fd79d680b5be86c5286d1e2a94bce46fd0f4aa4e7ba4`
- `V3_57_2_2_VALIDATION.md` — SHA256 `8ed5cdf2d03cbca44e45fc23b42cb1781fae4b8136e7709cce0d10cc15e83947`
- `V3_57_2_VALIDATION.md` — SHA256 `329fb288140e22614cc011ead1f9a1436686c9a5aec87891cf2d9126ea327305`
- `V3_57_VALIDATION.md` — SHA256 `5b0052ceb6ba22919d2ba82146d48a1bf53aed38b086fbfce230ce94252d646b` — duplicate paths: `docs/V3_57_VALIDATION.md`
- `V3_58_1_VALIDATION.md` — SHA256 `9ff3b598f74f674f00c3a9e632f545d1872489dc246ada6ab86d754d630ec709` — duplicate paths: `docs/V3_58_1_VALIDATION.md`
- `V3_58_2_VALIDATION.md` — SHA256 `163e57e936eece4bd946fb628f1a6a3629cf541190d8876a017e25d0f6814a9f` — duplicate paths: `docs/V3_58_2_VALIDATION.md`
- `V3_58_3_1_VALIDATION.md` — SHA256 `eed3e1db2a33ff88b3bea3206158db77a7359a5bee3b6fddd77c21c2a16a0094` — duplicate paths: `docs/V3_58_3_1_VALIDATION.md`
- `V3_58_3_2_VALIDATION.md` — SHA256 `5b1ff9677b8901acf272326d7791ebb712d71bb86351e50f48f56c092e3941e6`
- `V3_58_3_4_VALIDATION.md` — SHA256 `83a85ac9c7c95cde714b030e842b31563d3b61a4a55ac65ecabd9a36c87feffb`
- `V3_58_3_5_VALIDATION.md` — SHA256 `2efb518c3d971e362ca5edced4cd08117f64ee586e5d5e3ef719754f12376176`
- `V3_58_3_6_VALIDATION.md` — SHA256 `760bd9d90215eaf8ad5b4bf14e3b090f1607b08efff7250cba0eaf32cd3db359`
- `V3_58_3_VALIDATION.md` — SHA256 `5aa3328656ba41892657c29e5b638c2e0d172eb59140848ce3f5d1466ff7288e` — duplicate paths: `docs/V3_58_3_VALIDATION.md`
- `V3_58_4_1_VALIDATION.md` — SHA256 `d5cfdcf6db3170c1ef75d07c5ec88834fd444c04235e4b66ee259956311c9d4c` — duplicate paths: `docs/V3_58_4_1_VALIDATION.md`
- `V3_58_4_VALIDATION.md` — SHA256 `7948c6b28a7d4ee725a88620fce4d975d1cdd0f961b786ffc4c5b2d32edbec60` — duplicate paths: `docs/V3_58_4_VALIDATION.md`
- `V3_58_5_1_VALIDATION.md` — SHA256 `359f143f6e2e66b602c8b34eb55c4b5be5e74c16c60062e62acf695de550a4a9`
- `V3_58_5_VALIDATION.md` — SHA256 `a89d547786ab02b3697516fc492d4aa64a15fce56a81ffed2eb76d7ab877542b`
- `V3_58_VALIDATION.md` — SHA256 `4824ac8c5c6a34daf6cd903d335ce7c3ff5e6868c63d0a527ac11578a30321ad` — duplicate paths: `docs/V3_58_VALIDATION.md`
- `docs/BUILD_INFO.md` — SHA256 `fa2f10d83dc029be1bba7e2a1c1339a68ee9ca468cd5ff261f6ee9a2b7e7cd83`
- `docs/HANDOFF_NEW_CHAT.md` — SHA256 `2ae3062e327c22e9441c43996b429880d8cbda946107da32340823797f48359e`
- `docs/RUNTIME_CHECKLIST.md` — SHA256 `4f1d0ac331e0c233ef18eff0ae413afe62fd7cbdac559248393432ac359f85ed`
- `docs/V3_49_VALIDATION.md` — SHA256 `421c33b2618e146d0192c1fea3676261e56b8f576d4207543414e4cb6d973c4a`
- `docs/V3_50_1_VALIDATION.md` — SHA256 `22c2e024bf28a5749999209c45f7fe12f026910cb723f92e548e2494ff686c6f`
- `docs/V3_50_RESTORE_TIMING.md` — SHA256 `be28424673a94e84ba80fa324a4eaba36f7452ea539a15e22897b7a3d14cff62`
- `docs/V3_50_VALIDATION.md` — SHA256 `711540b6d11537a00a1579f01d436cbd8dc42a2926c717d2d86ee01aa76a829b`
- `docs/V3_51_PREVIEW_STAGE.md` — SHA256 `25a01ab46e40ff58d2ae69e72c2ef2c4cc0793002bc017862af594fac451dc9f`
- `docs/V3_51_VALIDATION.md` — SHA256 `7bd59580e23eaec49edad849d6ed702a1329b76a4be21e0c966e8216d4c3e197`
- `docs/V3_53_SINGLETON_GRAPH_PREVIEW.md` — SHA256 `cc87d1db0d3e12ee1a9f0f20a43e9d93e703be550cfd29bfc458bf00ac5d6395`
- `docs/V3_53_VALIDATION.md` — SHA256 `f33b9208f553192a1ec6b3b596e5ecc057e3f049747d6fbff31164ebc6a63e23`
- `docs/V3_54_FIXED_SINGLETON_GRAPH_PREVIEW.md` — SHA256 `7bcdef6cb39ad4b728e37288e4668a6403a15adb544038ca9902ed6238534e8c`
- `docs/V3_55_RESTORE_FASTPATH.md` — SHA256 `e87743a458f735269b525f854acbcb3fa2c326a59e717fa04da365e46ad4c841`

---

# Full archived originals


## Source: `RESTORE_OPTIMIZATION_NOTES.md`

# v3.52 Restore optimization note

## What changed

v3.52 removes only the diagnostic-only sparse browser probes that were scheduled at 0, 250, 1000, 3000, and 4500 ms for each restore binding-check request.

Those probes repeatedly scanned the same requested fields and sent extra Shiny inputs, but they never controlled restore progression. The progression-critical terminal binding ACK remains unchanged and still verifies that every requested field exists and is Shiny-bound for the current generation.

## What was not changed

- RESHAPE-PARENT binding ACK gate
- RESHAPE-BIND binding ACK gate
- MAPPING-BIND binding ACK gate
- saved-value sent -> server-observed confirmation gates
- generation guards / stale ACK rejection
- restore ordering and resync behavior
- mount ACK, preload, preempt/cancel, remount
- v3.51 Graph Preview cached/live overlay design
- Graph <-> Figure synchronization
- Figure Preview

## Audit result

There is no safe duplicate progression-critical binding probe across RESHAPE-PARENT, RESHAPE-BIND, and MAPPING-BIND. They target different input sets that become available at different restore stages. Therefore v3.52 does not skip any of those required checks.

## Real-machine verification

1. Confirm startup log contains `server start v3.52`.
2. Load the same `0.ggplotpack`.
3. Let at least one Graph complete first restore without rapidly switching away.
4. Confirm restore reaches READY and Graph content/mappings match v3.51.
5. Compare `[RESTORE] timing` intervals against v3.51, especially request->ACK and SENT->OBSERVED.
6. Confirm no `BIND-PROBE` lines are emitted; this is intentional in v3.52.
7. Confirm v3.51 preview behavior remains: cached preview during restore and `PREVIEW-MODE ... mode=live reason=plot-image-load` after live image load.

---

## Source: `V3_54_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_54_VALIDATION.md`

# v3.54 validation

Scope: Graph-tab Preview presentation only.

Expected invariants:
- exactly one `#graph_global_preview_stage` in the document;
- stage parent remains `#graph_global_preview_home`;
- Graph switching updates only cached HTML + live output binding and anchor geometry;
- cached→live occurs only on actual plot image `load`;
- restore/preload does not wait for global Preview target ACK;
- no new MutationObserver, sleep, or polling loop;
- Figure Preview / Figure Editor unchanged.

Real-machine check:
1. Open the same project and confirm `server start v3.54`.
2. Switch g004→g002→g003→g004 normally.
3. Confirm `GLOBAL-PREVIEW ... attached=TRUE positioned=TRUE stage_count=1`.
4. Confirm `GLOBAL-PREVIEW-MODE ... mode=live reason=plot-image-load`.
5. Confirm first cached preview is slightly smaller and does not jump vertically.
6. Confirm Statistics/Data View hide the Graph Preview and returning to Plot restores it.

Build-time results:
- static delimiter/string scan: PASS for all 15 runtime `.R` files;
- embedded JavaScript extracted from `ui.R`: `node --check` PASS;
- `www/figure_interaction.js`: `node --check` PASS;
- exactly one static `graph_global_preview_stage`: PASS;
- no `appendChild(stage)`, `unbindAll(stage)`, or `bindAll(stage)`: PASS;
- target switching uses live-layer-only unbind/bind: PASS;
- no newly added `MutationObserver`, `Sys.sleep`, or `setInterval`: PASS;
- R/Rscript unavailable in the build environment, so no R parser/Shiny runtime test is claimed.

---

## Source: `V3_55_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_55_VALIDATION.md`

# v3.55 validation

Scope: first-hydrate latency + READY Preview revisit only.

Expected invariants:
- server-observed restore gates remain mandatory;
- binding generation matching and timeout ACK behavior unchanged;
- hidden Figure Editor hydration is deferred only while Graph workspace is active; Figure-owned editable state remains stored;
- entering Figure hydrates the selected deferred editor;
- READY Graph revisit uses live Preview directly, without cached-SVG reset;
- Preview live panel scale is display-only and does not change plot/export device state;
- no GraphState/Figure ownership changes; no new sleep, MutationObserver, or polling path.

Build-time results:
- static delimiter/string scan: PASS for all 15 runtime `.R` files;
- embedded JavaScript extracted from `ui.R`: `node --check` PASS;
- `www/figure_interaction.js`: `node --check` PASS;
- v3.55 fast path is conditional on exact ACK value match; fallback update path remains present;
- no R/Rscript available in build environment, so no R parser/Shiny runtime test is claimed.

Real-machine check:
1. Confirm `server start v3.55`.
2. Load the same project while staying on Graph. Confirm `FIGURE-EDIT-LAZY ... deferred` and no `FIGURE-EDIT-MODULE` until Figure tab is opened.
3. Look for `RESTORE-FAST` lines. Compare READY timing against v3.54.
4. After a Graph is READY, switch away and back. Confirm `GLOBAL-PREVIEW ... prefer_live=TRUE` and no cached-mode flash for that revisit.
5. Enter Figure and confirm `FIGURE-EDIT-LAZY ... hydrate deferred editor`, then normal Figure Editor restore/READY.
6. Confirm live Preview is modestly smaller while export/plot size settings remain unchanged.

---

## Source: `V3_56_1_VALIDATION.md`

# v3.56.1 validation

Scope: instrumentation hotfix only.

Expected code change:
- graph_module.R: preserve moduleServer() return value across the post-call INIT-TIMING marker.
- server.R: version string only.
- docs/changelog.

Real-machine verification:
1. Startup log contains `server start v3.56.1`.
2. First Graph emits `CALLSITE-BEFORE-GRAPHSERVER` then `OUTER-ENTER`.
3. After `CALLSITE-AFTER-GRAPHSERVER`, no `$ operator is invalid for atomic vectors` error occurs.
4. Restore continues to READY.
5. Compare first Graph `CALLSITE-BEFORE-GRAPHSERVER` -> `OUTER-ENTER`; if it is still ~5 s while `INNER-ENTER` -> `INNER-RETURN` remains ~0.3 s, the delay is outside the graphServer body and is consistent with first-call/JIT compilation.

---

## Source: `V3_56_2_VALIDATION.md`

# v3.56.2 validation

Purpose: fix the instrumentation return-value regression and directly test the first-call JIT/byte-compilation hypothesis.

Expected log sequence for the first hydrated Graph:

1. `[JIT-PROBE] begin ... body_type_before=...`
2. `[JIT-PROBE] compile_ok elapsed_ms=... body_type_after=...`
3. `[INIT-TIMING] mark=CALLSITE-BEFORE-GRAPHSERVER`
4. `[INIT-TIMING] mark=OUTER-ENTER`
5. normal `INNER-RETURN`, `MODULESERVER-CALL-END`, `CALLSITE-AFTER-GRAPHSERVER` and READY progression.

Interpretation:

- If `compile_ok elapsed_ms` is about 4-5 s and `CALLSITE-BEFORE -> OUTER-ENTER` becomes near-zero, the earlier delay was byte compilation/JIT.
- If compile is fast but `CALLSITE-BEFORE -> OUTER-ENTER` is still about 4-5 s, JIT is unlikely to be the main cause.

The probe does not call `enableJIT()` and therefore does not modify the session's global JIT level.

---

## Source: `V3_56_VALIDATION.md`

# v3.56 validation

Instrumentation-only build derived from v3.55.

Purpose: isolate first-call graphServer initialization latency.

Expected diagnostics:
- `INIT-TIMING mark=CALLSITE-BEFORE-GRAPHSERVER`
- `INIT-TIMING mark=OUTER-ENTER`
- `INIT-TIMING mark=MODULESERVER-CALL-BEGIN`
- `INIT-TIMING mark=INNER-ENTER`
- section markers through `MODULE-API-BEGIN` / `INNER-RETURN`
- `INIT-TIMING mark=MODULESERVER-CALL-END`
- call-site AFTER marker

No restore/preload/preview synchronization behavior is intentionally changed.

Static validation performed in this environment:
- All 15 top-level `.R` files passed delimiter/string/comment/backtick scan.
- `ui.R` is byte-identical to v3.55.
- `www/figure_interaction.js` is byte-identical to v3.55 and passed `node --check`.
- No new `Sys.sleep`, `MutationObserver`, `setInterval`, or `setTimeout` occurrences were introduced in `graph_module.R` / `server.R`.
- R / Rscript are unavailable in this environment, so no R parser or Shiny runtime test was run.

---

## Source: `V3_57_1_VALIDATION.md`

# v3.57.1 validation

Scope: Graph Preview display geometry only.

Expected runtime behavior:
- Initial cached Graph preview and READY live revisit use the same persisted viewport ratio.
- READY revisit remains `prefer_live=TRUE`, `force_reset=FALSE`; no cached bounce is reintroduced.
- No fixed `zoom: 0.90` is applied.
- Plot/export device dimensions remain unchanged.
- `GLOBAL-PREVIEW` diagnostics include `viewport=<w>x<h>` and `ratio=<r>` for direct comparison across first load and READY revisit.

Packaging validation:
- 15 runtime `.R` files passed a quote/comment/backtick-aware delimiter scan.
- The newly added JavaScript expressions passed `node --check` in an isolated syntax harness.
- No new `Sys.sleep`, `setTimeout`, `setInterval`, or `MutationObserver` was added by the v3.57 -> v3.57.1 diff.
- R/Rscript was not available in the build environment, so no local Shiny runtime test is claimed.

---

## Source: `V3_57_2_1_VALIDATION.md`

# v3.57.2.1 validation

Hotfix only: escape-safe CSS attribute selectors inside the R-embedded JavaScript in `ui.R`.
The v3.57.2 source used JS single-quoted strings containing unescaped double quotes, which prematurely terminated the surrounding R string and caused `parse()` to fail around ui.R:2013.

Changes:
- four `querySelector()` selectors rewritten as R-safe JS double-quoted strings with single quotes inside the CSS attribute value.
- session version diagnostic updated to v3.57.2.1.

No restore, preview sizing logic, Figure reverse-apply logic, synchronization, polling, timeout, or state-machine behavior changed.

---

## Source: `V3_57_2_2_VALIDATION.md`

# v3.57.2.2 validation

Scope: READY-remount Preview flicker only.

- READY remount live layer is hidden with `graph-preview-live-pending` while the new DOM still has its native size.
- Existing `set-plot-dimensions` message with `reason=remount-ack` removes the pending class immediately after applying fitted dimensions.
- Plot image load is an event-driven fallback reveal; no new timeout, polling, `setInterval`, `MutationObserver`, or sleep was added.
- Initial cached -> live hydrate behavior is unchanged.
- Expected log sequence: `PREVIEW-REVEAL hidden` -> `PREVIEW-REVEAL dimensions-applied` -> `PREVIEW-REVEAL visible`.

---

## Source: `V3_57_2_VALIDATION.md`

# v3.57.2 validation

Scope: two narrow fixes only.

1. READY Graph remount now replays the measured `set-plot-dimensions` message after browser remount ACK, because the singleton live Preview DOM is recreated after the original reactive dimension message may already have fired.
2. `prepare_remount_state()` now seeds internal style/order reactive stores from canonical GraphState before remount, so a Figure -> source Graph commit updates colour/shape/series style trees without launching a restore against absent browser inputs.
3. Added diagnostic-only `PREVIEW-DIMS` and `FIGURE-APPLY-STYLE` logs. No new timer, polling loop, sleep, or MutationObserver was added.

R runtime/Shiny execution was not available in the build container; static checks only.

---

## Source: `V3_57_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_57_VALIDATION.md`

# v3.57 validation

Purpose: move the confirmed first `graphServer` byte-compilation cost out of Graph hydration and reuse one compiled closure everywhere.

Expected startup/runtime diagnostics:

1. Session start logs `[PRECOMPILE] ok=TRUE elapsed_ms=...`. On the tested machine this is expected to be around 4-5 s because v3.56.2 measured `compiler::cmpfun(graphServer)` at 4900 ms.
2. On the first hydrated Graph, `[INIT-TIMING] mark=CALLSITE-BEFORE-GRAPHSERVER` should be followed immediately by `mark=OUTER-ENTER` instead of a 4-5 s gap.
3. Figure Editor creation should use the same precompiled closure and should not trigger a second first-call compile pause.

No restore gates, GraphState ownership, Preview routing, Figure synchronization, preload/preempt/cancel/remount behavior, sleeps, polling, or MutationObserver logic are changed.

---

## Source: `V3_58_1_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_1_VALIDATION.md`

# v3.58.1 validation

Scope: Graph Preview layout boundary only.

Expected behavior:

1. Auto fit scales only the graph display inside `graph-preview-viewport`.
2. Manual 25–150% changes only the graph display; overflow scrollbars stay inside the graph viewport.
3. `Graph書式` remains directly below the viewport and never enters its scroll surface.
4. `グラフをスクロールに追従` still follows the outer `plot_follow`, therefore graph + Graph書式 move together vertically.
5. The rounded `plot_panel` border is not visible in Graph Preview, but the DOM remains for sizing/sticky logic.
6. Figure, export dimensions, GraphState, restore, explicit Figure sync and JIT precompile are unchanged.
7. No new sleeps, timers, polling, or MutationObserver.

Static validation in the build environment is recorded in the delivery response. R/Shiny runtime execution is not available in that environment.

---

## Source: `V3_58_2_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_2_VALIDATION.md`

# v3.58.2 validation

Scope: Preview native-canvas scaling/tab visibility and Statistics recipe persistence/restore.

Statistics semantics: recipes/settings and optional custom data source text are saved; computed test output is not saved; opening Statistics restores the recipe and recomputes from current data.

Preview semantics: visible only on Plot; Auto fits the entire native graph; manual 25–150% scales the graph itself; manual overflow scrolls only inside Preview; Graph書式 remains outside zoom/scroll.

---

## Source: `V3_58_3_1_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_3_1_VALIDATION.md`

# v3.58.3.1 validation

Scope: parser-only hotfix on top of v3.58.3.

- Fixed `ui.R` sticky-follow selectors to use R-safe escaped double quotes inside JavaScript CSS attribute selectors.
- No changes to the v3.58.3 Statistics persistence, tab visibility, Preview scaling, or follow behavior.
- Embedded JavaScript syntax checked with Node after reconstructing the affected snippet.
- No new `Sys.sleep`, `setTimeout`, `setInterval`, polling loop, or `MutationObserver`.
- ZIP CRC and extracted-tree match checked during packaging.
- R runtime validation is not available in this build environment; user-side `source('run.R')` is the decisive parse/runtime check.

---

## Source: `V3_58_3_2_VALIDATION.md`

# v3.58.3.2 validation

Scope: hotfix only for the missing `controls_only` argument introduced by v3.58.3.

Expected runtime:

- Source Graph: `graphServer(..., controls_only = FALSE)`.
- Figure hidden controls editor: `graphServer(..., controls_only = TRUE)`.
- The v3.58.3 tab-state observer is skipped only for Figure controls-only editors.
- Module construction must proceed past the previous line 4172 failure, so `pending_project`, `initial_restore_done`, `restoring_style_state`, and `style_restore_epoch` are created normally.

Static validation performed in the build environment:

- delimiter/string scan of top-level R files
- embedded JavaScript syntax check with Node
- grep for newly introduced sleep/timer/polling/MutationObserver synchronization
- ZIP CRC test and extracted-tree comparison

R/Shiny runtime execution is not available in the build environment.

---

## Source: `V3_58_3_4_VALIDATION.md`

# v3.58.3.4 validation

Scope: rebase v3.58.3.3 behavior on known-good v3.58.3.2, with R-safe embedded-JS selectors.

Expected checks:
- `source('run.R')` parses and starts.
- Statistics / Data View / 製作者コメント hide Global Preview; Plot restores it.
- Rapid Analysis adds produce unique monotonic default names.
- Statistics recipe save/reload/recalculation remains unchanged from v3.58.3.2.
- No new sleeps, timers, polling, or MutationObserver.

---

## Source: `V3_58_3_5_VALIDATION.md`

# v3.58.3.5 validation

Scope: Graph Preview visibility only.

- Uses the namespaced `*-graph_main_tab` Shiny `shiny:inputchanged` event as the authoritative browser signal.
- Plot => singleton Global Preview visible; Statistics / Data View / 製作者コメント => hidden.
- Existing Statistics recipe persistence/recalculation, Analysis naming, Preview scale, Figure, restore, and explicit Graph/Figure sync are unchanged.
- No sleep, timeout, interval, polling, or MutationObserver added.

---

## Source: `V3_58_3_6_VALIDATION.md`

# v3.58.3.6 validation

Scope: Graph sub-tab visibility boundary only.

Expected behavior:
- Plot: singleton Preview + Graph書式 visible.
- Statistics / Data View / 製作者コメント: entire singleton Preview stage hidden, including live/cached layers and Graph書式.
- Returning to Plot reuses the existing mounted DOM; no forced remount/re-hydrate.

Implementation note:
- Existing `graph-preview-tab-hidden` class is retained.
- The class now sets `display:none !important` on `#graph_global_preview_stage` in addition to visibility/pointer-events suppression.
- This prevents descendant `.graph-preview-mode-live .graph-preview-live-layer { visibility: visible; }` and cached-layer visibility rules from overriding the parent tab-hidden state.

Static checks performed in build environment:
- lightweight R delimiter/string scan
- extracted embedded JavaScript syntax check with Node where available
- no newly added sleep/timeout/polling/MutationObserver
- ZIP CRC test
- packaged tree matches staged source tree

R/Shiny runtime test was not available in the build environment.

---

## Source: `V3_58_3_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_3_VALIDATION.md`

# v3.58.3 validation

Scope is intentionally limited to three regressions on top of v3.58.2.

1. **Statistics Project persistence**
   - Contract remains recipe-only: computed ANOVA/t-test/correlation results are not serialized.
   - `project_settings()` now invalidates when the recipe collection changes.
   - Project save flushes in-memory recipe collections to canonical GraphState before serialization; active Graph is then fully flushed so current visible recipe inputs are captured.
   - Expected logs on save include `[STATS-SAVE]` and `[STATE-SAVE] ... statistics_recipes=N ... results_saved=FALSE`.
   - Expected load log is `[STATS-RESTORE] ... loaded recipes=N ... results_saved=FALSE recalc_on_open=TRUE`.

2. **Graph Preview tab visibility**
   - Plot: singleton Preview visible.
   - Statistics / Data View / 製作者コメント: singleton Preview hidden.
   - Uses the namespaced Shiny `graph_main_tab` value, not inferred Bootstrap pane ancestry.

3. **Sticky Graph follow**
   - With `グラフをスクロールに追従` enabled, the Global Preview-owned `plot_follow` is updated directly on page scroll.
   - Preview + Graph書式 remain one sticky unit.
   - Existing safety remains: mobile or vertically oversized Graph sections stay in normal flow.

Preview Auto/manual scale math and GraphState/Figure explicit-sync semantics are otherwise unchanged. No new sleep, polling, timer, or MutationObserver synchronization was introduced.

---

## Source: `V3_58_4_1_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_4_1_VALIDATION.md`

# v3.58.4.1 validation

Scope: static validation only. No R/Shiny runtime or browser interaction test was performed.

## Targeted changes

1. Restore wait accounting split by binding/value phase.
2. Figure→source apply cancels unfinished restore/preload before DOM eviction and reseeds from Registry canonical state.
3. checkboxGroup binding values are collected as selected-value arrays with a separate readability flag.
4. READY remount ACK is generation-scoped and checks the current DOM's relevant bound inputs against the canonical remount seed.
5. Figure controls-only preseed gate is staged: parent match/unconfirmed/mismatch first; child reshape and Mapping validation later.
6. Explicit Graph selection after terminal restore failure starts a fresh canonical generation; automatic retry limit remains 1.

## Static checks

- Top-level R delimiter/string scan: PASS (15 files).
- Embedded JavaScript extraction from `ui.R` and `node --check`: PASS.
- No newly added `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, or `invalidateLater` synchronization primitives in the runtime diff. Existing synchronization code outside this patch is unchanged.
- Dangerous R/JavaScript quote-pattern grep for the prior selector regression: PASS.
- Runtime source changes limited to `graph_module.R`, `server.R`, and `ui.R`; documentation changes only in README/CHANGELOG/this validation note.
- R/Rscript is not available in the build environment; no R parse/runtime test was run.

---

## Source: `V3_58_4_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_4_VALIDATION.md`

# v3.58.4 validation

Scope: Figure editor performance only.

## Intended behavior
- Opening/selecting a Figure-owned Graph editor reuses the canonical pre-seeded controls.
- After the existing browser mount ACK, matching plot/reshape/mapping inputs skip the full staged restore.
- If the preseed gate does not match, the previous staged restore path runs unchanged.
- UI events that do not change canonical Figure GraphState do not rebuild the Figure plot/snapshot/geometry.
- Actual draw-affecting changes still update Figure-owned state/snapshot normally.
- Source Graph state is still changed only by explicit `元Graphへ反映`.

## Diagnostics
- Fast accept: `[FIGURE-EDIT-FAST] ... full staged restore skipped`
- Fast fallback: `[FIGURE-EDIT-RESTORE-FAST] ... preseed gate rejected ...` followed by normal staged restore logs
- No-op click/reselection: `[FIGURE-EDIT-NOOP] canonical draw state unchanged; snapshot/geometry rebuild skipped`

## Static validation
- No new sleep / timeout / polling / MutationObserver mechanism is introduced.
- Changes are limited to Figure controls-only restore acceptance, Figure no-op state suppression, version/docs.
- Source Graph restore/remount path is not routed through the new fast accept method.

---

## Source: `V3_58_5_1_VALIDATION.md`

# v3.58.5.1 validation

Baseline: exact uploaded `ggplot_gui_v3_58_5_source.zip`.

## Scope

- Corrects only the Graph warm-retention path.
- In v3.58.5, a just-hidden READY warm Graph could report a transient `state-mismatch`; `warm_trim()` treated every non-hit as a legacy `show-ready-switch` eviction, destroying the DOM/bindings that the warm cache was meant to retain.
- v3.58.5.1 re-admits only the `state-mismatch` case by committing the still-valid live UI through the existing guarded Registry path (`warm_keep_outgoing()` / `warm_write_allowed()`), then re-evaluating `warm_reason()`.
- True rejection remains cold and logs `[WARM-UI][gXXX] retain rejected reason=<...>` before the existing `show-ready-switch` eviction.
- LRU limit remains two hidden READY Graphs. Preload READY eviction remains unchanged.
- Figure editor hydrate/binding, restore timing, Statistics/Analysis, Preview scale, sticky follow, export, and JIT paths were not changed.

## Expected smoke test (not executed)

`g002 → g003 → g002`

Expected diagnostics:
1. First switch: `[WARM-UI][g002] hide`.
2. No immediate `[UI-EVICT][g002] reason=show-ready-switch` for that retained Graph.
3. Return: `[WARM-UI][g002] hit`.
4. No `UI-MOUNT` or `UI-REMOUNT` for g002 on the warm return.

## Static checks

- PASS: delimiter/string/backtick lexical scan of all 15 R files.
- PASS: runtime diff is limited to `server.R`; documentation/version notes are `README.md`, `CHANGELOG.md`, and this validation file.
- PASS: no newly added `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer`.
- JavaScript was not modified, so no new embedded-JS syntax path was introduced.
- No R/Rscript, Shiny, browser, UI-interaction, or performance test was run.

Static checks cannot establish browser timing or end-to-end correctness; the smoke test above is the next required runtime check.

---

## Source: `V3_58_5_VALIDATION.md`

# v3.58.5 validation

Baseline: exact `ggplot_gui_v3_58_4_1_source.zip`, SHA256 `168bb4c570ec5f74c0aaee03b5d6a195c63722d9d2610ac4d2e9ae56e2bff61d`.

## Scope and behavior

- Runtime files: `server.R`, `graph_module.R` (read-only lifecycle probe only), `ui.R` (Graph warm output retention/routing only).
- Normal Graph switches synchronously persist eligible outgoing live state and retain at most two hidden READY UIs, excluding active. LRU never cancels pending restore/remount/preload work or a generation barrier. Protected work is trimmed after its lifecycle settles.
- A hit requires the same module and restore/remount generation, confirmed binding admission, READY/idle status, current canonical revision/state, and no invalidation or pending work. It uses hide/show, with no prepare_remount/mount/remount ACK/staged restore.
- Cold misses retain the existing v3.58.4.1 restore/remount functions and ACK protocol. The former singleton Preview teardown is bypassed only for retained warm layers; they are neither moved nor cloned. Missing retained browser bindings request cold recovery.
- External canonical writes invalidate warm metadata without initiating source DOM restore. A stale UI cannot write through module-live, save or eviction safety nets. Recovery is generation/revision scoped; stale debounced snapshots are rejected against current module state. Existing reverse apply still evicts with persist_state=FALSE and does not restore absent source DOM.
- Figure snapshots, explicit refresh, editor hydrate, preload READY eviction, Statistics/Analysis, scale calculations, sticky follow, export and JIT are preserved. Hidden outputs retain their existing suspension settings. Newly created, unconfirmed UIs take the cold route until a binding acknowledgement exists.
- Logs use `[WARM-UI][gXXX] hit`, `hide`, `evict reason=lru`, `invalidate reason=...`, and `cold reason=...`.

## Checks

- PASS: delimiter/string/escape lexical scan of all 15 R files. This is not R parsing or runtime validation.
- PASS: embedded JavaScript actually extracted from the R string, decoded, and checked with `node --check`.
- PASS: dangerous quote-pattern search on added runtime lines; no newly added forbidden synchronization primitives (`Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, `reactiveTimer`).
- PASS: runtime diff review; protected Figure/reverse-apply/preload READY/save blocks and scale calculations match the baseline. The shared module differs only by its read-only warm lifecycle API.
- PASS: ZIP CRC; re-extracted per-path SHA256 tree exactly matches the release tree.
- PASS: patch check and application to a fresh baseline; resulting per-path SHA256 tree exactly matches the release tree.

No R/Rscript, Shiny, browser, UI interaction or performance test was run, as requested. Static checks do not establish browser timing, latency or end-to-end correctness. Existing historical validation notes refer to their own releases.

Apply `ggplot_gui_v3_58_5.patch` from inside the extracted v3.58.4.1 source directory (`git apply`); the patch uses paths relative to that directory. The release ZIP has one top-level `ggplot_gui_v3_58_5/` directory.

---

## Source: `V3_58_VALIDATION.md`

Exact duplicates removed from active tree: `docs/V3_58_VALIDATION.md`

# v3.58 validation

Scope: Graph Preview display scaling only.

Expected behavior:
- Default Auto fit. Native R renderPlot/export dimensions remain unchanged.
- Auto scale = min(available_width/native_width, available_height/native_height, 1).
- Manual 25–150% slider changes browser display only.
- Manual overflow stays inside Preview scrolling; cached SVG and live plot use the same display size.
- Preview scale is not persisted to GraphState/project.
- No new sleeps/timeouts/polling/MutationObserver.

Runtime R/Shiny validation was not available in the build environment; static validation is recorded separately in the release response.

---

## Source: `docs/BUILD_INFO.md`

# Current build: v3.58.3.1

This source package is based on v3.58.2. The historical manifest below is retained for reference and was not regenerated.

# Build info — v3.58.2

Built: 2026-09-16 from `ggplot_gui_v3_58_1_source.zip` as the sole runtime baseline.
Runtime changes are limited to the Graph Preview layout boundary: Auto/manual zoom and overflow belong to the graph-only viewport, while `Graph書式` remains outside that viewport but inside the existing sticky `plot_follow` unit. The structural `plot_panel` remains but its decorative border is hidden in Graph Preview. Figure behavior, GraphState, export dimensions, restore gates, JIT precompile, preload/remount ownership, and explicit Graph↔Figure synchronization are unchanged.
R/Rscript are unavailable in the build environment; no end-to-end Shiny/browser runtime validation is claimed.

## File SHA-256 (this manifest excluded)

```text
27a4e29f4877e1e30e160b43f4e4ac24ee4a89a2a2bd7ed0e82603370cfcd4d8  CHANGELOG.md
b37a7276aacf0f359d74944a75de5544892e39d2a8b24729002d45440a642c76  README.md
3ef59faaa33c2b56f55b9358c4200af4e0b2598b8cb7995cd1ac7cd74f3ffa27  RESTORE_OPTIMIZATION_NOTES.md
62f3d73dc55c2094cab34be83190e53e26f3aa6cdfd0ae124a30cf7e6a3243b9  V3_54_VALIDATION.md
d9963c0ec7e414fdc6e9d17726343c008aa9a7e5e9d83c12aa69251aecaa4f12  V3_55_VALIDATION.md
e667220383f5c4dfda8cbd02d6a0b07d70345b31ce6cbb2fa45884b44386df57  V3_56_1_VALIDATION.md
7021b1619072ff68e3c116e75e92b166e41d1835fd6561e028605d13d8fbc3cb  V3_56_2_VALIDATION.md
bf68389861ed8ada4e6d69aba6259d97a5f746fe07187ecbbe1d6256b4f7e6c7  V3_56_VALIDATION.md
20965c6d3e1d56507e221c90ec3e733044657676c00e2599c70b73f8b316fcfa  V3_57_1_VALIDATION.md
907bc7e880d85c679547fd79d680b5be86c5286d1e2a94bce46fd0f4aa4e7ba4  V3_57_2_1_VALIDATION.md
8ed5cdf2d03cbca44e45fc23b42cb1781fae4b8136e7709cce0d10cc15e83947  V3_57_2_2_VALIDATION.md
329fb288140e22614cc011ead1f9a1436686c9a5aec87891cf2d9126ea327305  V3_57_2_VALIDATION.md
5b0052ceb6ba22919d2ba82146d48a1bf53aed38b086fbfce230ce94252d646b  V3_57_VALIDATION.md
9ff3b598f74f674f00c3a9e632f545d1872489dc246ada6ab86d754d630ec709  V3_58_1_VALIDATION.md
4824ac8c5c6a34daf6cd903d335ce7c3ff5e6868c63d0a527ac11578a30321ad  V3_58_VALIDATION.md
c668efb4445ce9d27b2c7433e93338850fdd623c06a771b4a54a7db71c145f67  anovakun_489.txt
77afbc96a28ae0cb1c4a8e12d196a2db7387097d8f47a9b12bfc36166debbf57  anovakun_489_10.txt
2ae3062e327c22e9441c43996b429880d8cbda946107da32340823797f48359e  docs/HANDOFF_NEW_CHAT.md
4f1d0ac331e0c233ef18eff0ae413afe62fd7cbdac559248393432ac359f85ed  docs/RUNTIME_CHECKLIST.md
421c33b2618e146d0192c1fea3676261e56b8f576d4207543414e4cb6d973c4a  docs/V3_49_VALIDATION.md
22c2e024bf28a5749999209c45f7fe12f026910cb723f92e548e2494ff686c6f  docs/V3_50_1_VALIDATION.md
be28424673a94e84ba80fa324a4eaba36f7452ea539a15e22897b7a3d14cff62  docs/V3_50_RESTORE_TIMING.md
711540b6d11537a00a1579f01d436cbd8dc42a2926c717d2d86ee01aa76a829b  docs/V3_50_VALIDATION.md
25a01ab46e40ff58d2ae69e72c2ef2c4cc0793002bc017862af594fac451dc9f  docs/V3_51_PREVIEW_STAGE.md
7bd59580e23eaec49edad849d6ed702a1329b76a4be21e0c966e8216d4c3e197  docs/V3_51_VALIDATION.md
cc87d1db0d3e12ee1a9f0f20a43e9d93e703be550cfd29bfc458bf00ac5d6395  docs/V3_53_SINGLETON_GRAPH_PREVIEW.md
f33b9208f553192a1ec6b3b596e5ecc057e3f049747d6fbff31164ebc6a63e23  docs/V3_53_VALIDATION.md
7bcdef6cb39ad4b728e37288e4668a6403a15adb544038ca9902ed6238534e8c  docs/V3_54_FIXED_SINGLETON_GRAPH_PREVIEW.md
62f3d73dc55c2094cab34be83190e53e26f3aa6cdfd0ae124a30cf7e6a3243b9  docs/V3_54_VALIDATION.md
e87743a458f735269b525f854acbcb3fa2c326a59e717fa04da365e46ad4c841  docs/V3_55_RESTORE_FASTPATH.md
d9963c0ec7e414fdc6e9d17726343c008aa9a7e5e9d83c12aa69251aecaa4f12  docs/V3_55_VALIDATION.md
5b0052ceb6ba22919d2ba82146d48a1bf53aed38b086fbfce230ce94252d646b  docs/V3_57_VALIDATION.md
9ff3b598f74f674f00c3a9e632f545d1872489dc246ada6ab86d754d630ec709  docs/V3_58_1_VALIDATION.md
4824ac8c5c6a34daf6cd903d335ce7c3ff5e6868c63d0a527ac11578a30321ad  docs/V3_58_VALIDATION.md
9291c5376290521da603dd13107a0921b54c491c7ee12ef2c6f2f5f19a12b36c  figure_asset.R
e1446d71409586ea13b9750b6857315611f28d67575e8fdcf07377959a404f4a  figure_export.R
c6877298b3026aa37975b75f3d2ff92897450bf137fe9ad61ca96511b7fcd251  figure_interaction.R
48c2fba8dc7b1e551d5aa688d860ffbc43d3105123ba2855d2df65a441a85291  figure_layers.R
81cf1621bdef4ca596e3abf8fcb56f9bf148cc46363bb419d73955ab301cdf72  figure_layout.R
f3bc2b76bc8d5709728973ec746ddd7fc410e14a05f716e6eb7f5637df99190d  figure_renderer.R
27f92e6d0872e87a12a35b376f0affd408c23fd9b54eb5ad5a0871712e8f410d  figure_state.R
1b84787a57fa975abd5ee9f3827073751cd4b96655f1e0c5ffad0b86fe049477  figure_ui_module.R
d6539919f7ad59d5ea09ef0e1b4d5499bfeab0a50ba09c17affba2a63d088fc1  global.R
fdd5f84dae2dcb093629d2da29bb8d0fb7b9f8e9fbe738937b2bc1bd4ebcd655  graph_module.R
b5cc66207d82dd32413d1a7f0d0749c73b63900ae0600061b19182132e99b3d7  graph_module.R.bak
f8167fac5c48d88b4f468e3ceb5b7fc076e708bd8fc17a29e173b226ed8d540c  graph_state.R
c761cc99531aef7c6e021b36b0cae6520bfdc104fb1f0a733ef26d330bf80c46  graph_ui_module.R
3291e92a12e1f2e5e90d6a722c4e90e62917e2cb1024ac33cb2b48f6bfda643f  req.txt
04eccf3fe57e54b29d90539b24b63bfeab8666da8fa315ee13e3eba176cd90a7  run.R
eec18aa0da2297e88dd1b3f7cb95bfcab455a6bddc4090a5689577b6769b5f2c  run.bat
510d30ad1b68e2346085856dae1d35876340abd0427d25fc508814ea5396854e  server.R
10ca66b265500d452483a2275c7b9b94114ed98cd20a81465f7182654ed88d3f  server.R.bak
7951230cd6ea2d21c285a8b8bfca146a43799f91cbf417237624c5eefe4e3b52  ui.R
30ceb0a3f627e5befe41175a7b330bb23b02f97dc78c8a7042bc4cde6b3102da  ui.R.bak
e7b5d8f6ffb6bf6c8bc32bfe3c12d1deef5f8b0ed55be663a66be0efc1697da0  www/figure_interaction.js
```

---

## Source: `docs/HANDOFF_NEW_CHAT.md`

# v3.49 handoff addendum

v3.49 is implemented from the sole attached v3.48 clean baseline. See ../CHANGELOG.md and V3_49_VALIDATION.md for scope and evidence. The next implementation version is v3.50. The v3.48 handoff below is retained as historical architecture context; its proposed v3.49 work is superseded by this addendum. Restore failures have been observed in prior audits; this release surfaces them, it does not fix their underlying causes.

---

# v3.49 handoff addendum

v3.49 is implemented from the sole attached v3.48 clean baseline. See ../CHANGELOG.md and V3_49_VALIDATION.md for scope and evidence. The next implementation version is v3.50. The v3.48 handoff below is retained as historical architecture context; its proposed v3.49 work is superseded by this addendum. Restore failures have been observed in prior audits; this release surfaces them, it does not fix their underlying causes.

---

# v3.49 handoff addendum

v3.49 is implemented from the sole attached v3.48 clean baseline. See ../CHANGELOG.md and V3_49_VALIDATION.md for scope and evidence. The next implementation version is v3.50. The v3.48 handoff below is retained as historical architecture context; its proposed v3.49 work is superseded by this addendum. Restore failures have been observed in prior audits; this release surfaces them, it does not fix their underlying causes.

---

# New-chat handoff — ggplot GUI v3.48

## Start here

Use `ggplot_gui_v3_48_clean_source.zip` as the baseline. Do **not** base new work on v3.47. Keep changes small and version linearly: next implementation version is **v3.49**.

The current app is an R/Shiny ggplot GUI with a Graph workspace and an explicit Figure composition workspace. The priority is preserving authored state while making Graph/Figure switching and restoration feel seamless.

## Core architecture / invariants

### Graph

- `GraphState Registry` is the canonical runtime truth for Graph state.
- Browser UI/DOM is transient and must not become authoritative merely because it is mounted.
- Persisted/cached SVG is a preview/cache, not canonical state.
- Restore/remount uses browser ACK + generation/cancel guards. Never bypass these casually.

### Figure

- Figure owns layout, crop, panel label, free legend position/background/gap, Inset, external assets, and Figure geometry.
- Figure Graph editing uses a **Figure-owned editable GraphState copy**.
- Source Graph and Figure Graph state are deliberately independent.
- Main Graph and Inset snapshots are independent.
- A Graph is not intentionally duplicated multiple times in the same Figure, so Graph-ID-level Figure snapshots are acceptable.

### Explicit synchronization rules

- Normal Graph preload/render/READY must **not** update Figure automatically.
- Panel selection must only select; it must not refresh from source.
- `全GraphをFigureへ読み込む` = explicit bulk source Graph → Figure import / initial Figure creation.
- `Graphから再読込` = explicit selected Figure panel replacement from its source Graph.
- Ordinary Figure edits do not update source Graph.
- `元Graphへ反映` = explicit Figure → canonical source Graph commit.
- Reverse apply must not immediately run source `load_state()` against absent Graph DOM. Restore is deferred to normal Graph remount.
- Reverse apply does not refresh the Figure snapshot; Figure stays unchanged until explicit Graph → Figure refresh.

## Figure UI hierarchy

- `Layout / Canvas` — full width above Figure Preview, foldable.
- Visible primary button near Layout/Preview: `全GraphをFigureへ読み込む`.
- Drawer priority:
  1. Figure Panel — primary, initially expanded
  2. Overlay
  3. Sources / Assets
  4. Graph settings — secondary, initially collapsed
  5. Export
- `Graphから再読込` / `元Graphへ反映` remain in Graph settings.

## Version status

### v3.46

Established explicit-only Graph → Figure synchronization and removed automatic Figure reset/overwrite paths.

### v3.47

Attempted two seamless-UI changes:

1. Skip unconditional Figure Layout rebuild on Figure-tab re-entry.
2. Persist Inspector fold state with new browser JS and probe Layout DOM presence.

The new browser JS caused a regression: later existing Shiny handlers could fail to register. Symptoms included `UI-MOUNT-ACK` timeout and Figure panel clicks not reaching the server.

### v3.48

Emergency fix:

- Removed the v3.47 Inspector `MutationObserver`/fold-persistence block.
- Removed the browser `figure-layout-presence-probe` path.
- Restored existing `graph-ui-mount-check` and Figure-panel click handler path.
- Kept only the safer server-side improvement: reopening Figure reuses existing Layout DOM and logs `Figure tab activated; reuse existing layout DOM; render skipped`.

**Do not reintroduce the v3.47 browser block without isolating it from existing handler registration and testing browser runtime errors.**

## Current confirmed runtime behavior

v3.48 no longer exhibits the v3.47 stuck mount-ACK failure. Runtime examples show ACKs returning normally (tens of milliseconds to ~1.5 s depending on browser load), followed by module creation and restore.

The remaining issue is **restore/hydration latency**:

- full Graph restore commonly spends several seconds after mount ACK;
- restore walks through staged browser binding: reshape parent → reshape columns → mapping controls → remaining style/control restore → plot → READY;
- selecting another Graph while restore is in flight cancels/preempts work and restarts hydration for the new Graph;
- a Figure Editor can restore concurrently with Graph restore, increasing browser input-binding load;
- a once-restored Graph may be evicted from browser DOM and later require another restore/remount path.

This is currently considered a performance/churn problem, not a timeout-setting problem.

## Work audit currently requested

A Work-mode runtime audit has been handed off to measure:

- click → mount ACK → module instantiate → restore stages → READY;
- first restore vs returning to an already-restored Graph;
- preempt/cancel cost;
- Figure ↔ Graph switching;
- unnecessary parent DOM replacement vs simple SVG/content update;
- scroll/details/selection/focus preservation;
- Figure Panel selection vs Graph settings changes vs explicit source reload.

The audit is instructed to produce at most **3 v3.49 candidates**, ranked by effect and risk, and not to perform broad refactoring.

When that audit returns, review it before implementing v3.49.

## Likely v3.49 questions — do not assume answers yet

1. Can a Graph with usable cached SVG defer full hydration until the user actually needs editable controls?
2. Can Figure Editor hydration be deferred until Figure is active / its editor is needed, avoiding competition with Graph hydration?
3. Can an already-restored Graph avoid unnecessary full re-restore after UI virtualization/remount while preserving canonical GraphState and remount safety?
4. Which restore binding barriers are semantically necessary, and which are repeated browser churn?
5. Does Figure Graph settings editing unnecessarily rebuild a wider Preview/Canvas subtree when geometry is unchanged?

These are hypotheses only. Prefer runtime evidence before changing them.

## Things not to change casually

- GraphState registry ownership.
- Figure-owned editable GraphState independence.
- generation/cancel/ACK guards.
- lazy/preemptible hydrate semantics.
- explicit source synchronization rules.
- Inset snapshot independence.
- Figure free legend coordinate/background behavior.
- vector SVG/PDF export pipeline.
- project cache-first behavior.
- timeout values or sleeps as a performance workaround.

## Validation expectations for future patches

This environment may not have R/Rscript. Never claim an R runtime test unless it actually ran.

For source builds, at minimum:

- static/custom R delimiter/string scan, clearly labeled as static rather than R parse;
- `node --check` for changed JS / embedded extracted JS where applicable;
- grep/reference checks around changed handlers/observers;
- previous-version → new-version patch dry-run;
- apply patch to a fresh previous-version tree and verify exact match;
- ZIP integrity and extracted-tree exact match;
- then user Windows runtime test for restore/remount behavior.

## Runtime log markers worth watching

- `UI-MOUNT-DISPATCH`
- `UI-MOUNT-ACK`
- `MODULE ... instantiate complete`
- `MODULE-INIT-DRAIN`
- `RESTORE ... start_state_restore BEGIN`
- `RESHAPE-PARENT`
- `RESHAPE-BIND`
- `MAPPING-BIND`
- `final onFlushed END`
- `READY`
- `PRELOAD ... PREEMPT`
- `RESTORE-CANCEL`
- `UI-REMOUNT-CANCEL`
- `FIGURE-LAYOUT-UI`
- `FIGURE-EDIT-MOUNT`
- `FIGURE-EDIT-RESTORE`
- `FIGURE-SOURCE-SYNC`

## Preferred development style

- Diagnose from source + runtime log.
- Small local patches, no broad refactors.
- No sleeps/timeouts as synchronization fixes.
- Preserve restore/remount normal behavior.
- Keep user-facing versions linear (`v3.49`, `v3.50`, ...).

---

## Source: `docs/RUNTIME_CHECKLIST.md`

# v3.49 targeted runtime checklist — not yet executed for this build

- Select a Figure editor with a restore failure; confirm its error replaces preparing. Switch Panels and verify no other editor's error leaks in.
- Explicit selected reload / bulk import: verify progress even with cached snapshots, target-specific source errors and retry-clear behavior. Unrelated Graph errors must not appear. Existing pending work remains pending on failure; no automatic retry/cancel is introduced.
- Open Crop/Inset and close Label/Legend, switch Panels repeatedly (including external assets), and confirm folds persist. Fold clicks must not recreate the Inspector. New Project/workspace reset restores defaults.
- Check rapid fold click then Panel selection, Figure↔Graph round trips, selected reload, successful bulk import and snapshot-failure notifications.
- Confirm normal mount ACK / Figure panel clicks and no new browser console errors.

The older checklist below remains applicable. No full Shiny/browser test is claimed.

---

# v3.49 targeted runtime checklist — not yet executed for this build

- Select a Figure editor with a restore failure; confirm its error replaces preparing. Switch Panels and verify no other editor's error leaks in.
- Explicit selected reload / bulk import: verify progress even with cached snapshots, target-specific source errors and retry-clear behavior. Unrelated Graph errors must not appear. Existing pending work remains pending on failure; no automatic retry/cancel is introduced.
- Open Crop/Inset and close Label/Legend, switch Panels repeatedly (including external assets), and confirm folds persist. Fold clicks must not recreate the Inspector. New Project/workspace reset restores defaults.
- Check rapid fold click then Panel selection, Figure↔Graph round trips, selected reload, successful bulk import and snapshot-failure notifications.
- Confirm normal mount ACK / Figure panel clicks and no new browser console errors.

The older checklist below remains applicable. No full Shiny/browser test is claimed.

---

# v3.49 targeted runtime checklist — not yet executed for this build

- Select a Figure editor with a restore failure; confirm its error replaces preparing. Switch Panels and verify no other editor's error leaks in.
- Explicit selected reload / bulk import: verify progress even with cached snapshots, target-specific source errors and retry-clear behavior. Unrelated Graph errors must not appear. Existing pending work remains pending on failure; no automatic retry/cancel is introduced.
- Open Crop/Inset and close Label/Legend, switch Panels repeatedly (including external assets), and confirm folds persist. Fold clicks must not recreate the Inspector. New Project/workspace reset restores defaults.
- Check rapid fold click then Panel selection, Figure↔Graph round trips, selected reload, successful bulk import and snapshot-failure notifications.
- Confirm normal mount ACK / Figure panel clicks and no new browser console errors.

The older checklist below remains applicable. No full Shiny/browser test is claimed.

---

# Focused Runtime Checklist — v3.48 baseline / v3.49 candidates

Use the same representative `.ggplotpack` when comparing builds.

## 1. Project load

- Cached Graph previews appear before all Graphs are fully hydrated.
- Project lock releases after cache-first registry/preview restore.
- Saved active Graph can hydrate without mount ACK timeout.
- Figure layout, occupied cells, Figure snapshots, and Figure-owned editable states restore.

## 2. Graph restore timing

For each tested Graph record timestamps for:

1. click / `SHOW`
2. `UI-MOUNT-DISPATCH`
3. `UI-MOUNT-ACK`
4. module instantiate complete
5. `MODULE-INIT-DRAIN` ACK
6. `start_state_restore BEGIN`
7. `RESHAPE-PARENT` ACK
8. `RESHAPE-BIND` server value observed
9. `MAPPING-BIND` ACK / mapping committed
10. `final onFlushed END`
11. plot complete
12. `READY`

Test both first hydration and return to a previously restored Graph.

## 3. Preempt / cancel

While one Graph is restoring, select another Graph.

Expected:

- old restore receives `RESTORE-CANCEL` / `UI-REMOUNT-CANCEL` as appropriate;
- stale ACKs/callbacks cannot mark the old Graph READY;
- half-restored browser state is not committed as canonical GraphState;
- requested Graph becomes the active restore target promptly.

## 4. Figure switching

Repeat Graph → Figure → Graph → Figure.

Expected:

- Figure re-entry logs reuse of existing Layout DOM rather than an unconditional Layout render;
- Figure Panel selection works;
- selected panel is retained unless the user selects another one;
- no automatic source Graph → Figure refresh occurs;
- no source Graph changes merely from opening Figure.

## 5. Explicit synchronization

- `全GraphをFigureへ読み込む`: intentional bulk Graph → Figure import only.
- `Graphから再読込`: selected panel only.
- `元Graphへ反映`: canonical source Graph commit only; source browser restore waits for normal Graph remount.
- normal preload/READY: `FIGURE-SOURCE-SYNC ... ignored ... explicit import required`.

## 6. Figure ownership

- Figure Graph settings alter Figure-owned state, not source Graph.
- Crop, panel label, free legend position/background/gap, Inset and external assets stay Figure-owned.
- Inset refresh does not alter main Graph snapshot.

## 7. DOM / visual churn checks

Observe separately:

- Graph persistent UI root
- Figure Layout root
- Figure Preview
- Inspector
- Figure Editor

Distinguish parent DOM replacement from child/SVG content update. Check whether scroll position, focus, selected panel, and open/closed disclosure state change unexpectedly.

## 8. Export smoke test

After editing Figure:

- PNG exports all occupied Panels and Figure-only layers.
- SVG remains vector where expected.
- PDF uses vector SVG composition path.
- detached/free legend and Inset remain present.

## v3.48 regression-specific checks

- No `UI-MOUNT-ACK ... server timeout` caused by missing browser handler registration.
- Figure panel click reaches server.
- Do not re-add v3.47 Inspector MutationObserver / Layout presence-probe code during unrelated optimization.

---

## Source: `docs/V3_49_VALIDATION.md`

# v3.49 patch / changelog / validation

## Provenance and scope

- Sole code baseline: ggplot_gui_v3_48_clean_source(1).zip, obtained from the referenced conversation attachment (local materialization of the requested /mnt/data file).
- Baseline SHA-256: 6cf6bceb10230e3fe4f62df99632731a1a6fb06574866f21da43178aff8979c1; matches the architecture pack's declared baseline hash.
- Constraints read: architecture README, module responsibilities, control flows, function contracts, v3.48 handoff, Custom R Plot handoff (future feature excluded), and the follow-up findings/error-display design.
- Runtime edits: server.R, figure_ui_module.R, ui.R only. All other runtime files are byte-identical to v3.48.

## v3.49 — Figure status and Inspector fold state

- Figure Graph Editor reads the selected Figure module's existing restore_error(). Explicit reload/import status reads only its source target IDs, before cached-snapshot readiness. The existing Progress message now exposes restore failures while leaving pending/queue/retry behavior unchanged.
- Six Inspector groups retain open/closed state across figure_panel_detail / figure_overlay_detail replacements. Existing heading clicks send stable keys; server markup uses isolated transient fold state. Defaults are restored on Figure workspace reset / Project restore. Fold clicks do not invalidate renderUI, and fold state is not saved into GraphState or project data.
- No new MutationObserver, presence probe, timeout, or delay. No Preview structural optimization. Graph/Figure synchronization, ACK, generation/cancel, remount, preload, geometry and export are unchanged.

## Validation

- PASS: custom static delimiter/string/comment/backtick scan of all 15 R files.
- PASS: actual R 4.4.3 parse of all 15 R files. R was available at C:/Program Files/R/R-4.4.3/bin/Rscript.exe. Startup locale warnings were handled by selecting a UTF-8 LC_CTYPE in the validation script.
- PASS: node --check on the active inline JS extracted via R's parsed string value, and the unchanged www/figure_interaction.js reference file.
- PASS: isolated R presentation-function tests for selected/target scoping, unrelated-Graph exclusion, retry/error clearing, explicit-operation precedence, editor preparation/ready and fold defaults/restoration/reset. Inputs are mocked; this is not a Shiny session test.
- PASS: extracted JS heading-click handler tests with a mock DOM: open/close, unrelated click, optional transport-error isolation.
- PASS: reference checks for all six stable keys; no new MutationObserver or presence probe. Existing JS after figure-editor-select is byte-identical.
- PASS: 13 protected lifecycle/synchronization/Preview function bodies match v3.48 exactly as parsed R expressions. Remaining lifecycle observers are untouched in the patch.
- PASS: patch dry-run and application to a fresh extraction of the sole v3.48 ZIP; applied tree byte-for-byte matches the release tree.
- PASS: ZIP central-directory CRC/size validation; separate extraction byte-for-byte matches the release tree.

## Limits and use

Full Shiny/browser runtime tests have not run for v3.49. Shiny was not available on this R installation's default library path. No restore-speed improvement or underlying restore-failure repair is claimed. Existing restore/import queues deliberately remain unchanged on errors; status now identifies failure instead of implying uninterrupted progress. Existing snapshot-creation failure notifications remain in place.

Apply the companion patch from the root of a fresh extracted v3.48 clean source using git apply --check, then git apply. The source ZIP is ready to extract and run. The targeted runtime checklist is included under docs/RUNTIME_CHECKLIST.md.

## v3.49.1 inspector fold hotfix

- Fix scope: Figure Inspector fold/open state only.
- Mechanism: current DOM fold classes are snapshotted at the explicit panel click boundary and sent with `figure_panel_clicked`; server stores the snapshot before selected-panel renderUI invalidation.
- No MutationObserver or DOM presence probe.
- Preview structural rendering and restore/status logic unchanged.

---

## Source: `docs/V3_50_1_VALIDATION.md`

# v3.50.1 validation

Scope: two local fixes only: Graph cached/live double-display fallback and restore timing log visibility.

Static checks performed in the build container:
- Static R delimiter/string/comment/backtick scan: PASS.
- Planned restore timing marks still present: PASS.
- No new MutationObserver or presence-probe implementation added: PASS.
- Runtime R/Shiny parse test: NOT RUN (R/Rscript unavailable in this container).

Real-machine check:
1. Startup log must contain `[SESSION] server start v3.50.1`.
2. During initial Graph restore, log should contain `[RESTORE][gXXX] timing attempt=...` lines.
3. After first live plot draw, expect `UI-SWITCH` and/or `browser confirm ... cached_removed=TRUE`; persisted SVG and live plot must not remain stacked.
4. Cached SVG should remain visible while restore is still in progress.

---

## Source: `docs/V3_50_RESTORE_TIMING.md`

# v3.50 restore timing instrumentation

This release is instrumentation-only. It does not change restore gates, ACK handling, retry limits, preload/preemption, remount behavior, cached-SVG behavior, or Figure synchronization.

## New log tag

`RESTORE-TIMING`

Each restore attempt receives an `attempt` number. Binding-dependent marks also include the existing browser-binding `generation`.

Expected marks:

- `BEGIN`
- `RESHAPE-PARENT-REQUEST`
- `RESHAPE-PARENT-ACK` (`delta_ms` from request)
- `RESHAPE-PARENT-SENT`
- `RESHAPE-PARENT-OBSERVED` (`delta_ms` from sent)
- `RESHAPE-BIND-REQUEST`
- `RESHAPE-BIND-ACK` (`delta_ms` from request)
- `RESHAPE-BIND-SENT`
- `RESHAPE-BIND-OBSERVED` (`delta_ms` from sent)
- `MAPPING-BIND-REQUEST`
- `MAPPING-BIND-ACK` (`delta_ms` from request)
- `MAPPING-BIND-SENT`
- `MAPPING-BIND-OBSERVED` (`delta_ms` from sent)
- `MAPPING-COMMITTED`
- `FINAL-BEGIN` (`delta_ms` from mapping commit)
- `FINAL-END` (`delta_ms` from final begin)
- `READY` (`delta_ms` from final end)

For reshape-disabled Graphs, the RESHAPE-PARENT / RESHAPE-BIND marks may be absent by design.

## What to compare on the real machine

For each Graph and Figure Editor restore, compare:

1. browser binding latency: `*-REQUEST -> *-ACK`
2. Shiny value reflection latency: `*-SENT -> *-OBSERVED`
3. tail latency: `MAPPING-COMMITTED -> FINAL-BEGIN -> FINAL-END -> READY`

Use the same `attempt` and, for binding phases, the same `generation` when pairing lines. Existing `BIND-PROBE elapsed_ms` remains a browser-side diagnostic and should not be treated as the full server round-trip time.

---

## Source: `docs/V3_50_VALIDATION.md`

# v3.50 validation

## Scope

Instrumentation only. Runtime code change is confined to `graph_module.R`; `ui.R`, `server.R`, and browser JS remain byte-identical to v3.49.1.

## Checks performed

- Static R delimiter/string/comment/backtick scan: PASS (not a real R parse).
- `www/figure_interaction.js` `node --check`: PASS.
- All planned `RESTORE-TIMING` marks present: PASS.
- `graph_module.R` patch removes no pre-existing line; changes are additions only: PASS.
- `ui.R`, `server.R`, `www/figure_interaction.js` byte-identical to v3.49.1: PASS.
- No new `Sys.sleep`, timeout hack, `MutationObserver`, or presence-probe code in the patch: PASS.
- ZIP CRC/integrity and extracted-tree equality: PASS at packaging time.

R/Rscript was not available in the build environment, so no R parser or Shiny runtime/browser test is claimed.

---

## Source: `docs/V3_51_PREVIEW_STAGE.md`

# v3.51 Graph Preview stage

## Scope
Graph tab preview presentation only. Figure Preview and restore sequencing are not changed.

## Model
Each Graph shell owns one stable `graph-preview-stage` containing:
- `graph-preview-cached-layer` (persisted/live SVG cache)
- `graph-preview-live-layer` (Shiny `plotOutput`)

The cached layer is absolutely overlaid on the live layer. It never contributes a second vertical block.

## Transition
- cached SVG available: stage starts in `graph-preview-mode-cached`
- restore/READY: does not change preview mode
- actual live plot IMG load in the browser: stage changes to `graph-preview-mode-live`
- cached SVG remains mounted but hidden

## Remount
A READY Graph can reuse an in-session cached SVG only when that preview record contains a GraphState identical to the canonical state and the preview is not dirty. Otherwise remount retains the previous no-stale-preview behavior.

## Runtime checks
1. Startup log contains `server start v3.51`.
2. Open the same packaged project that previously produced duplicated plots.
3. During hydration, exactly one visible preview should be present (cached SVG).
4. After the live plot image appears, exactly one visible plot should remain; no second vertically stacked copy.
5. Log should contain `[PREVIEW-MODE][gXXX] mode=live reason=plot-image-load ...` for a cached-to-live takeover.
6. Revisit a READY Graph and confirm remount still works and no stale preview flashes.
7. Rapidly switch Graphs during restore and confirm PREEMPT/CANCEL behavior is unchanged.

---

## Source: `docs/V3_51_VALIDATION.md`

# v3.51 validation

Baseline: `ggplot_gui_v3_50_1_source.zip`.

## Scope
Graph-tab preview presentation only. `graph_ui_module.R`, `ui.R`, `graph_module.R`, and the narrowly scoped READY-remount cache eligibility branch in `server.R` are the only runtime files changed.

## Static validation
- 15 active `.R` files: delimiter/string scan PASS.
- Embedded active JavaScript extracted from `ui.R`: `node --check` PASS.
- `www/figure_interaction.js`: `node --check` PASS.
- Preview mode mock test: cached -> live class/ARIA/ACK transition PASS; duplicate live transition is a no-op.
- Structural check: cached layer is absolute overlay inside one stable stage; old `graph-live-plot-ready` and `live_plot_switch_ack` runtime paths are absent.
- Patch added no `MutationObserver`, polling loop / `setTimeout`, `Sys.sleep`, or cached-preview `removeUI` synchronization.
- Existing remount browser probe/timing path was not redesigned; v3.51 adds no new polling or timeout synchronization.

## Runtime claims
R/Rscript were not available in the build container, so R parser execution and end-to-end Shiny/browser tests were not run here.

## Real-machine checks
1. Startup must log `[SESSION] server start v3.51`.
2. Load the packaged project that previously showed duplicated cached/live plots.
3. During hydration, only the saved SVG should be visible.
4. After the live plot image loads, only the live plot should be visible in the same viewport; no vertically stacked duplicate.
5. Expect `[PREVIEW-MODE][gXXX] mode=live reason=plot-image-load cached_exists=TRUE live_exists=TRUE` when a cached preview hands over to live.
6. Revisit a READY Graph and verify remount works; if an in-session matching cache is available, it may be used until live image load. No stale old-style preview should flash.
7. Rapid Graph switching during restore should preserve existing PREEMPT/CANCEL behavior.
8. Figure Preview should be unchanged.

---

## Source: `docs/V3_53_SINGLETON_GRAPH_PREVIEW.md`

# v3.53 Singleton Graph Preview — Option A

## Purpose

Reuse one Graph Preview viewport across Graph selection instead of creating a separate cached/live Preview stage inside every Graph UI.

## Structure

```text
Graph workspace
  graph_global_preview_stage   # one DOM node for the session
    graph_global_preview_cached_layer
    graph_global_preview_live_layer

Graph gXXX UI
  gXXX-preview_slot            # target only
```

When a Graph is shown, server sends `graph-global-preview-target` after the target Graph UI flush. The browser keeps a reference to the singleton stage, moves the same node into that Graph's slot, replaces cached content, creates only the selected Graph's namespaced `plot_container` output binding, then calls `Shiny.bindAll()`.

The cached SVG is shown immediately when available. The stage changes to live only when the actual Shiny plot `<img>` fires `load`.

## Boundaries

This does not change GraphState ownership, graphServer lifecycle, restore gates, mount ACK, preload/preempt/cancel, remount state, Figure source synchronization, Figure Preview, or project persistence.

---

## Source: `docs/V3_53_VALIDATION.md`

# v3.53 validation

## Build-time checks

- Baseline: `ggplot_gui_v3_52_source.zip` only.
- All 15 runtime `.R` files passed a static delimiter/string/backtick/comment scan.
- Embedded JavaScript extracted from `ui.R` passed `node --check`.
- `www/figure_interaction.js` passed `node --check`.
- Singleton Preview mock passed: repeated g002 -> g003 target changes moved the same stage object and `stageCount` remained 1.
- Runtime source contains exactly one static `id = "graph_global_preview_stage"`; per-Graph full UI contains only `preview_slot`.
- No new `MutationObserver`, `Sys.sleep`, `setInterval`, or preview polling loop was added by the v3.53 diff.
- v3.52 restore timing instrumentation remains present.

## Runtime validation limitation

R / Rscript are not installed in the build environment, so a real R parser / Shiny/browser runtime test is **not** claimed here. Real-machine validation should confirm target ACK `stage_count=1`, cached-first display, plot-image-load -> live mode, Graph switching, and READY remount.

---

## Source: `docs/V3_54_FIXED_SINGLETON_GRAPH_PREVIEW.md`

# v3.54 Fixed Singleton Graph Preview

## Purpose

Make the Graph Preview UI truly reusable across Graph selection. v3.53 reused one stage but moved that stage into each Graph's `preview_slot`; v3.54 keeps the stage under `graph_panels` permanently and changes only its inner content plus visual anchor geometry.

## Structure

```text
Graph workspace / #graph_panels
  #graph_global_preview_home
    #graph_global_preview_stage        # one DOM node; parent never changes
      #graph_global_preview_cached_layer
      #graph_global_preview_live_layer

Graph gXXX UI
  gXXX-preview_anchor                  # layout/position anchor only
```

On Graph selection:
1. the selected Graph's cached SVG HTML replaces only the cached layer;
2. only the live layer is unbound;
3. the selected Graph's namespaced `plot_container` output holder replaces the old live holder;
4. only the live layer is rebound;
5. the fixed stage is positioned over the selected Graph's anchor;
6. cached -> live still waits for the actual Shiny plot `<img>` `load` event.

The outer stage is never removed, reparented, unbound, or rebound during Graph switching.

## Boundaries

No change to GraphState ownership, staged restore gates, mount ACK, generation/cancel, preload/preempt, persistent graphServer lifetime, READY remount semantics, Figure source synchronization, Figure Preview, project serialization, or v3.52 timing instrumentation.

---

## Source: `docs/V3_55_RESTORE_FASTPATH.md`

# v3.55 Restore fast path

This release targets first-hydrate latency without removing restore correctness gates.

1. Browser binding ACK snapshots already contain current values. If those values exactly match the saved state pre-seeded into graphUI/renderUI, the redundant update input message is skipped. The server still waits for its own `input$...` value to match before restore advances.
2. Figure Editor hydration is deferred while the Graph workspace is active, avoiding startup contention with the active Graph restore. Figure-owned editable GraphState remains stored and is hydrated when the Figure tab is entered.
3. Revisiting a READY Graph routes the shared Preview directly to live mode rather than cached SVG first.

No sleep/timeout workaround, MutationObserver, or polling path was added.

---

## Source: `docs/STAGED_REFACTOR_SUMMARY.md`

# Staged source refactor summary

All stages are intended as independently runnable checkpoints. No stage intentionally changes user-facing graph semantics.

| Stage | Version | Main purpose |
|---|---|---|
| Small | v3.67.2-function-boundaries1 | Top-level UI function boundaries + centralized version config |
| Medium | v3.68.0-plot-contract1 | Central plot-type schema/capability contract |
| Large | v3.69.0-runtime-decomposition1 | Decompose graphServer pre-plot responsibilities while retaining one reactive owner |
| Final | v3.70.0-function-catalog1 | Promote reusable pure/UI factory functions and publish function catalog |

## Static metrics

| Version | r_files | r_lines | functions | observe | observeEvent | reactive | reactiveVal | input_refs | Sys.sleep | setTimeout | setInterval | MutationObserver | invalidateLater | reactivePoll | reactiveTimer |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| baseline | 26 | 25322 | 479 | 49 | 107 | 55 | 180 | 900 | 0 | 23 | 0 | 1 | 4 | 0 | 0 |
| small | 27 | 25341 | 484 | 49 | 107 | 55 | 180 | 900 | 0 | 23 | 0 | 1 | 4 | 0 | 0 |
| medium | 28 | 25400 | 491 | 49 | 107 | 55 | 180 | 900 | 0 | 23 | 0 | 1 | 4 | 0 | 0 |
| large | 33 | 25420 | 491 | 49 | 107 | 55 | 180 | 900 | 0 | 23 | 0 | 1 | 4 | 0 | 0 |
| final | 41 | 25558 | 477 | 49 | 107 | 55 | 180 | 899 | 0 | 23 | 0 | 1 | 4 | 0 | 0 |

## UI literal-ID parity

- **baseline:** same set as v3.67.1 baseline = `True`; unique IDs = 278
- **small:** same set as v3.67.1 baseline = `True`; unique IDs = 278
- **medium:** same set as v3.67.1 baseline = `True`; unique IDs = 278
- **large:** same set as v3.67.1 baseline = `True`; unique IDs = 278
- **final:** same set as v3.67.1 baseline = `True`; unique IDs = 278

## Source reference check

- **baseline:** source refs=22, missing targets=0
- **small:** source refs=23, missing targets=0
- **medium:** source refs=24, missing targets=0
- **large:** source refs=29, missing targets=0
- **final:** source refs=37, missing targets=0

## Source: `docs/SOURCE_ARCHITECTURE.md`

# Source architecture — v3.73.2.8

## Application entry points

```text
run.R
  -> shiny::runApp()
     -> global.R
     -> ui.R
     -> server.R
```

`app_module_registry.R` owns Graph/Figure source order. `server.R` owns canonical registries and sources the focused server runtime files.

## Canonical Graph model

```text
GraphState Registry (canonical)
        |
        +--> cached Graph SVG preview (derived visual seed)
        |
        +--> persistent single Graph Editor (primary workspace; auto-hydrated on selection)
        |
        `--> read-only source materializer (Figure / Export / old Project fallback)
```

The Registry is authoritative. Browser inputs, live plots, cached SVG and background source modules are derived views and must not write canonical GraphState unless they are the explicit persistent Editor transaction.

## Graph Editor-first selection path

```text
Graph tab click
  -> select target
  -> request_graph_editor() automatically
  -> one fixed graph_editor_single module
  -> latest-target queue if another transaction is in flight
  -> HYDRATING / SYNC
  -> cached/live/auth Preview ACK handshake
  -> READY
```

Cached SVG is still used to hide latency and as a failure-safe fallback, but ordinary Graph selection no longer enters a user-visible browse-only mode. The v3.72.16 full-editor hydration mask remains the presentation policy: incomplete Editor DOM is not exposed while GraphState is synchronizing.


### Shared graphServer runtime namespace invariant

All `graph_*_runtime.R` files sourced by `graph_module.R` execute in the same local `graphServer` environment. Local reactive/function/state names are therefore shared bindings, not module-private names. v3.72.27 accidentally defined `plot_data` in both the transform runtime and the longstanding prepared-data runtime, creating a recursion after the later source overwrote the earlier binding. The transform boundary is now named `plot_source_data()`, and release audit checks for duplicate runtime-local bindings.

## Source materialization path

`server_graph_materialization_runtime.R` is the only backend for source preparation required by Figure, bulk Export and preview-less legacy Project compatibility.

```text
request/schedule materialization
  -> serial queue
  -> disposable per-Graph browser UI mount/bind ACK
  -> read-only graphServer source module
  -> canonical GraphState restore
  -> READY + RenderState validation
  -> canonical revision lease claim
  -> Figure/Export consumer
  -> disposable source DOM eviction
```

Important invariants:

- `source_graph_module()` exposes a background source module only when its revision lease matches the current canonical GraphState.
- `cache_set()` invalidates an existing source lease on every canonical state change.
- A stale READY source module is therefore not reusable until it is restored from canonical state again.
- Background source modules are instantiated with `on_state_change = NULL`; they are read-only materializers.
- Figure/Export code does not call old preload/warm APIs directly.
- Materialization queue/barrier state is private to `server_graph_materialization_runtime.R`; outside files use named service functions only.
- Serial materialization barriers use generation-scoped ACKs and Shiny flush boundaries. Persistent Editor RESHAPE/MAPPING restore is also event-driven in v3.72.24: binding readiness comes from Shiny browser events and no 75 ms `invalidateLater()` restore loop remains.

## Figure lifecycle

`server_figure_lifecycle_runtime.R` owns Figure ACTIVE/DORMANT state. Hidden Figure UI may remain mounted, but expensive source geometry measurement is suppressed while Graph workspace is active.

Figure-owned state remains separate from source GraphState. Explicit Figure -> Graph Apply commits canonical GraphState first, invalidates the old Graph preview, then publishes a newly rendered Graph-owned preview from the committed state.

## Retired architecture

The following are no longer current runtime architecture:

- `server_graph_preload_legacy.R`
- Graph warm/LRU DOM retention
- `warm_*` server helpers
- warm preview layers in `www/app_client.js`
- direct Figure/Export calls to preload queue/promotion functions

Historical trace/archive documents may still mention those names and are intentionally retained as history.

## Current Editor hydrate/render path

- New Graphs are initialized from one captured canonical default GraphState before Editor activation.
- RESHAPE/MAPPING binding readiness is event-driven (`shiny:bound` / `shiny:unbound` / `shiny:inputchanged`) rather than timer-polled.
- Persistent Wide→Long parent controls reuse the already-bound parent UI when its values match canonical state.
- `shape` / `linetype` semantic defaults avoid redundant NULL resync after a generation ACK.
- READY arbitration compares canonical RenderState once in the outer persistent-Editor transaction.
- After acceptance, the attached canonical GraphState is released exactly once as the first render target; ordinary READY edits use live `project_settings()`.
- A failed reconcile aborts safely, clears the hydration mask, and leaves cached Preview as fallback.

## Data / Statistics boundary (v3.72.27.1)

```text
GraphState.data_text
        |
        +--> raw_dat() ----------------------> Statistics Analysis
        |                                      + per-Analysis preparation recipe
        |                                      + independent factor/DV/ID choices
        |
        `--> Plot transform recipe --> plot_source_data()
                                      +--> dat() compatibility boundary
                                      |      `--> prepared plot_data() --> Plot pipeline
                                      `--> Data View
```

- Statistics no longer consumes Plot `dat()` and does not consult Plot Mapping for its ANOVA factor plan.
- Every Analysis owns its own optional data-preparation recipe. New recipes default to `as_is`; `wide_to_long` is available independently per Analysis.
- Plot and Statistics share only the pure transform engine in `graph_data_transform.R`; their transform state is separate.
- Data View intentionally remains Plot-oriented and displays `plot_source_data()`: the original Graph table after Plot-owned Wide→Long and before Mapping-specific preparation.
- Legacy Analysis recipes that had no explicit transform are migrated once from the saved Plot Wide→Long state so existing Projects retain their historical analysis input table.
- Figure editing no longer owns `statistics_recipes`; Figure -> Graph Apply preserves canonical Statistics state.

The Statistics/Data View/製作者コメント surfaces are still mounted inside the persistent Graph module in this checkpoint. Their data/render dependencies are separated first; moving those surfaces into browse mode without Editor hydration is a later UI/runtime boundary change.

## Historical notes and remaining cleanup

The v3.72.27.1 recursion/Statistics migration notes are retained in archive/handoff documents and are no longer current startup work items. Current cleanup should be driven by the active v3.73 source call graph: remove unreachable migration paths only after caller verification, keep materialization/restore compatibility APIs that still have callers, and treat cached Preview as derived state.

## Source: `docs/SOURCE_INVENTORY.md`

# Source inventory — v3.73.2.13-fast-equivalent-switch1

Generated from the shipped source tree after the equivalent-state fast-switch refactor. Line/byte counts describe the current files.

| File | Lines | Bytes |
|---|---:|---:|
| `anovakun_489.txt` | 3,074 | 184,944 |
| `anovakun_489_10.txt` | 3,074 | 184,944 |
| `app_config.R` | 6 | 152 |
| `app_dependencies.R` | 14 | 258 |
| `app_function_catalog.R` | 120 | 13,054 |
| `app_module_registry.R` | 48 | 2,187 |
| `app_shared_helpers.R` | 366 | 15,369 |
| `app_state_diff.R` | 52 | 2,047 |
| `CHANGELOG.md` | 275 | 34,570 |
| `figure_asset.R` | 122 | 5,214 |
| `figure_export.R` | 772 | 37,269 |
| `figure_interaction.R` | 404 | 17,201 |
| `figure_layers.R` | 229 | 10,324 |
| `figure_layout.R` | 1,508 | 73,284 |
| `figure_renderer.R` | 709 | 31,902 |
| `figure_state.R` | 328 | 14,154 |
| `figure_sync_contract.R` | 88 | 3,660 |
| `figure_ui_module.R` | 441 | 23,489 |
| `global.R` | 6 | 291 |
| `graph_core_functions.R` | 136 | 4,245 |
| `graph_data_defaults.R` | 178 | 5,792 |
| `graph_data_runtime.R` | 1,031 | 37,407 |
| `graph_data_transform.R` | 153 | 5,349 |
| `graph_helpers_runtime.R` | 262 | 9,787 |
| `graph_module.R` | 375 | 17,173 |
| `graph_order_ui_runtime.R` | 111 | 3,975 |
| `graph_output_runtime.R` | 424 | 16,537 |
| `graph_plot_contract.R` | 67 | 2,527 |
| `graph_plot_runtime.R` | 1,575 | 56,543 |
| `graph_prepared_data_runtime.R` | 623 | 23,436 |
| `graph_render_error_runtime.R` | 51 | 1,318 |
| `graph_render_state.R` | 125 | 4,597 |
| `graph_restore_runtime.R` | 1,077 | 48,250 |
| `graph_shared_style_runtime.R` | 274 | 12,199 |
| `graph_state.R` | 77 | 2,817 |
| `graph_state_boundary_runtime.R` | 185 | 6,596 |
| `graph_state_runtime.R` | 2,065 | 91,376 |
| `graph_statistics_runtime.R` | 1,920 | 65,552 |
| `graph_style_ui_runtime.R` | 307 | 12,262 |
| `graph_ui_bindings.R` | 53 | 2,888 |
| `graph_ui_module.R` | 1,358 | 57,529 |
| `README.md` | 207 | 23,473 |
| `REFACTOR_CHECKPOINT.md` | 365 | 31,873 |
| `req.txt` | 16 | 124 |
| `run.bat` | 58 | 1,138 |
| `run.R` | 29 | 1,132 |
| `server.R` | 2,812 | 124,529 |
| `server_export_prepare_runtime.R` | 129 | 4,077 |
| `server_figure_controls_runtime.R` | 1,943 | 93,044 |
| `server_figure_legend_reactivity_runtime.R` | 581 | 23,760 |
| `server_figure_lifecycle_runtime.R` | 40 | 1,605 |
| `server_figure_workspace_runtime.R` | 1,950 | 93,198 |
| `server_graph_editor_runtime.R` | 1,016 | 44,335 |
| `server_graph_export_runtime.R` | 144 | 3,663 |
| `server_graph_fast_switch_runtime.R` | 152 | 6,920 |
| `server_graph_materialization_runtime.R` | 874 | 37,579 |
| `server_graph_selection_runtime.R` | 121 | 4,584 |
| `server_graph_workspace_runtime.R` | 395 | 15,683 |
| `server_project_io_runtime.R` | 1,745 | 73,611 |
| `server_shared_style_runtime.R` | 462 | 21,834 |
| `shared_style_state.R` | 345 | 12,650 |
| `ui.R` | 7 | 247 |
| `ui_shell.R` | 339 | 11,480 |
