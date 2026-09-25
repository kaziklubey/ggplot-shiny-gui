# v4.0.1-browser-state-read-audit1 validation

Scope: browser-direct stale-read audit. The triggering confirmed bug was Plot width/height being accepted into canonical `style.appearance.*` while `effective_plot_width_px()` / `effective_plot_height_px()` still read the intentionally stale Shiny mirrors. The same read class was audited across the module runtime rather than fixed one control at a time.

Static ownership audit:

- Browser-owned key universe checked: 119 snapshot input keys plus reshape, palette and plot-size aliases (130 keys total for this audit).
- Outside the synchronous canonical snapshot plot context, direct browser-owned `input$...` reads must be either arguments to `graph_mapping_value()`, `graph_plot_value()`, `graph_label_value()`, `graph_reshape_value()`, `graph_appearance_value()` / generic browser-owned accessor, or one of the documented pristine-startup reshape fallbacks.
- Focused regression reports zero unwrapped stale browser-owned reads under that contract.
- Deliberate exceptions: `R/plot/calculation/graph_plot_calculation.R`, `graph_state_plot_helpers.R`, and `graph_state_plot.R` operate on a synchronous canonical snapshot list named `input`; startup reshape controls may be read directly only before any attached GraphState exists. Top-level Project-name I/O is outside the namespaced editor browser-patch channel.

Functional changes covered statically:

- Full Editor canonical read source: attached accepted GraphState.
- Figure Controls canonical read source: Figure-owned attached state plus Figure-local browser overlay.
- Plot width/height renderer reads canonical appearance values; old direct Shiny mirror reads are absent.
- Width/height slider and direct numeric aliases synchronize in the browser working copy without introducing a second R-side owner.
- Style copy/save, Shared Style helpers, data/mapping dependent choices, prepared data helpers, plot notes, line-break state, external error fields, theme/base size, legend/y-break and Scatter regression reads use the canonical boundary where they consume browser-owned controls.
- `.aesthetic-style-panel` no longer clips Selectize dropdowns.

Checks in this container:

- JavaScript syntax: 28 files PASS.
- JavaScript regressions: 25 PASS / 0 FAIL, including the new browser-state read audit.
- Lightweight R lexical balance scan: 121 `.R` files / 0 delimiter-string failures (not a substitute for `R parse()`).
- Literal R `source()` / `sys.source()` / `parse()` references: 0 missing.
- `R/bootstrap/FILE_LAYOUT.json`: 93 mapped R paths / 0 missing.
- R/Rscript is not installed in this container, so R parse and Shiny/browser runtime acceptance remain pending.

Windows acceptance focus:

1. Change Plot width and height with both slider and direct numeric fields; panel/axis length must change and the aliases must remain coherent.
2. Change Y range, y-break step/auto, theme/base font size, legend placement/size, bar/line widths and spacing; each visible control must affect the current Graph without a second edit/revisit.
3. Spot-check Scatter regression controls, external error mapping, line breaks and style copy/save immediately after browser-direct edits.
4. Repeat representative size/style edits in Figure Controls: Figure must update locally while the source Graph remains unchanged until explicit Apply/Refresh.
5. Open the palette dropdown in Mapping Appearance and confirm it is not clipped by the card boundary.
6. Re-check Graph switching and Wide→Long once to ensure no ownership regression.


# v4.0.1-palette-action-canonical1 validation

Scope: palette apply action canonical read boundary only. `apply_palette` now resolves `palette_preset` via `graph_appearance_value()` so Full Editor and Figure Controls use accepted state rather than stale Shiny input mirrors.

# ggplot GUI v4.0 Validation

## v4.0.1-reshape-figure-canonical1 candidate

Runtime evidence motivating this repair:

- Enabling Wide→Long changed canonical `reshape.*`, but no `mapping.y` commit followed; `make_plot` then ended in ~0.01–0.02 s without `path=DIRECT-STATE`, consistent with pre-ggplot X/Y validation. Disabling Wide→Long immediately restored a normal `DIRECT-STATE accepted-canonical` render.
- Figure Controls replay uses browser-direct working-copy transport (`figure_controls` profile), so retaining an input-driven fallback for Mapping/Appearance derived UI was inconsistent with the transport contract and could leave `Mappingの見た目` empty/stale while the Figure plot itself rendered from Figure-owned working state.

Changes:

- Reconcile Mapping atomically for any reshape key that can alter effective schema: enabled, row-id, selected columns, names-to and values-to.
- Generalize the existing Data mapping reconcile helper to a schema-change helper while keeping the old Data entry point as a compatibility alias.
- Figure derived Mapping/Plot/Appearance accessors now read the frozen Figure-owned attached state plus the profile-local browser overlay; they still never read or mutate the source Graph registry.

Checks in this ChatGPT container:

- JavaScript syntax: 26 files PASS.
- JavaScript regressions: 23 PASS / 0 FAIL, including focused reshape/Figure canonical and Shared Style regressions.
- R/Rscript is unavailable here, so Windows R parse/runtime acceptance remains required for the new R edits.
- Runtime acceptance target: enabling valid Wide-to-Long should log RESHAPE-MAPPING-RECONCILE when X/Y/etc. must change, then make_plot path=DIRECT-STATE accepted-canonical; Figure Mapping appearance should resolve from the Figure-owned mapping without requiring Shiny input mirrors.

## v4.0.1-shared-style-isolation1 / Checkpoint C candidate

Confirmed runtime evidence inherited from the Work session before this candidate:

- Checkpoint B Line boundary was reproduced against real ggplot2: the original `geom_line()` path raised the documented varying-colour/non-solid-linetype error, while the adjacent-segment candidate drew successfully; all-solid remained ordinary `GeomLine`.
- Shared Style per-Graph isolation bug was reproduced: Graph 1 bound `Group/CTL`, Graph 2 bound `Group/EXP`, and the second Graph's binding leaked into Graph 1 before the replay fix.
- Library reverse-flow bug was reproduced while Figure was visible: `library-edit` advanced canonical GraphState and invalidated the current owner lease, but a delayed Graph observer still called the Shared Library callback and wrote stale Graph values back. The prior flush-scoped guard was not sufficient.

Checkpoint C changes:

- `graph_style_persistence_runtime.R`: restore Graph-owned Shared Style binding metadata on every replay before browser-direct early return.
- `server_graph_editor_runtime.R`: require `graph_single_revision_is_current(owner)` before accepting Graph -> Library write-through; stale callbacks are logged as `SHARED-STYLE-LIBRARY-SKIP`.
- `graph_shared_style_runtime.R`: removed the timing-based one-flush guard.
- Focused JS regression asserts Graph-local replay restoration and canonical lease rejection ordering.

Checks available in this ChatGPT container:

- JavaScript syntax (`www/*.js`, `tests/*.js`): PASS.
- JavaScript regressions: 22 PASS / 0 FAIL, including the Shared Style focused regression.
- R/Rscript is not installed in this container, so the two new R edits have not been re-parsed here. Work had already passed R parse for 94 files before the final lease-gate edit.
- Browser runtime acceptance of the final lease-gate candidate remains PENDING.

Required Windows acceptance before Checkpoint C is promoted to PASS:

1. Graph 1 bind `Group/CTL`; Graph 2 bind `Group/EXP`; switch G1/G2 repeatedly and confirm each retains its own binding and appearance.
2. While Figure is visible, edit the Shared Library display name and colour. Confirm the edit does not revert; log should show owner lease invalidation and, if a delayed stale callback fires, `SHARED-STYLE-LIBRARY-SKIP` rather than `SHARED-STYLE-LIBRARY commit source=graph-editor`.
3. Return to each Graph and confirm the Library edit is reflected through canonical replay without cross-Graph binding replacement.
4. Save Project, exit/restart, reload, and confirm Library items plus G1/G2 binding metadata restore.
5. Confirm existing Figure snapshot does not change automatically when Shared Style auto-sync is off.

## v4.0.1-mapping-style-canonical1 candidate

Scope is limited to the Full Editor Mapping/Appearance derived-UI read boundary. Accepted browser-direct Mapping values are read from the attached canonical GraphState rather than stale Shiny input mirrors. The Data transport path, persistent single Editor, Figure lifecycle and snapshot ownership are unchanged.

Static checks:

- focused regression verifies canonical accessors for X/Y/Color/Linetype/Shape/position/Facet/line-series/plot type and preserves the Data transport boundary
- all bundled JavaScript syntax/regressions and available dependency-free R regressions are run
- protected persistent Editor, browser-direct patch, Data transport and Figure source regions are compared with the baseline
- ZIP CRC, fresh extraction and patch-applied tree identity are verified

Observed in this build environment:

- JavaScript syntax: 24 files passed
- JavaScript regressions: 21 files passed
- R parse: 94 source files passed under R 4.4.3
- dependency-free R regressions: 14 passed
- `v4_rc2_formalization_regression.R` fails on the unchanged baseline at its legacy `app_draw_static_plot(p)` assertion and is therefore not attributed to this change
- `v4_0_1_json_safe_tree_runtime.R` was not runnable because `jsonlite` is not installed in this R library
- R emitted non-fatal locale warnings because `C.UTF-8` is unavailable on this Windows host

R/Shiny/browser behavior still requires the Windows spot check below; static checks alone do not prove live slot-pool rendering.

Windows spot check:

1. start the app and confirm the pristine default Graph opens normally
2. paste the previously problematic full-size dataset once and select Bar / Color=`番号`
3. confirm the plot remains colored and Mappingの見た目 immediately lists the `番号` levels rather than `Colorに使う列がありません。`
4. repeat with explicit Linetype, Shape, 横位置, Facet and line-series selections; confirm Category order and Mappingチェック follow the visible Mapping
5. switch Graphs and return; confirm the same values are reconstructed from that Graph's canonical state
6. confirm Figure edits remain snapshot-owned and do not change the source Graph until explicit Apply/Refresh

## v4.0.1-json-cleanup1 candidate

Static scope is limited to JSON/Shiny serialization boundaries and retirement of legacy Project JSON loading. Current Style / Shared Style JSON remain supported. The runtime architecture is otherwise unchanged.

Build-container checks:

- JavaScript syntax / existing JS regressions
- explicit `jsonlite::toJSON()` / `write_json()` audit
- no active legacy Project `read_json(path, ...)` fallback
- Project file picker no longer advertises `.json`
- new static JSON-cleanup regression

R/Rscript is unavailable in this container, so the included R regression and the actual disappearance of the warning still require Windows runtime confirmation.

Windows spot check:

1. startup log is `server start v4.0.1-json-cleanup1`
2. load a current `.ggplotpack`
3. perform the reshape -> Line path that previously reproduced the warning
4. switch Graphs once and edit a normal Mapping/Style control
5. export Graph Style JSON and Shared Style JSON once
6. confirm `Input to asJSON(keep_vec_names=TRUE) is a named vector...` does not appear

この文書は、RCごとに散在していたvalidationを正式v4.0向けに集約したものです。詳細な個別記録は `docs/history/` に保存しています。

## 最終基準

Runtime baseline: `v4.0-rc13.10-main-tab-atomic-restore1`

Formal package version: `v4.0`

正式化時のruntime code変更はありません。バージョン表記、version pin regression、文書配置だけを整理しています。

## Windows実機で確認済みの主要項目

### Graph / Editor

- persistent single Full Editor
- browser-direct Graph switching
- Graph state isolation
- Graph 1 / Graph 2往復
- rapid edit coalescing
- stale revision rejection
- no-op patch early return
- draw-time ggplot error後に有効設定へ復帰

### Project / first hydration

- multi-Graph Project save / exit / restart / reload
- Graphごとのstate分離
- Figure snapshot restore
- Project load直後selected Graphのcanonical replay
- fractional Bar widthが小数のまま編集可能

### Statistics

確認済み：

- Statistics tab activation
- Analysis recipe作成
- ANOVA結果表示
- Graph切替後のrecipe/result保持
- Graph間Statistics分離
- Project保存 / 再起動 / 再読込
- Statistics recipe復元と結果再計算
- Figure -> Graph Apply後もGraph Statisticsを保持
- ProjectをStatisticsタブで保存した場合の初回atomic restore

RC13.10の最終実機ログでは、手動tab clickなしで次の順序まで到達しています。

1. `GRAPH-EDIT-MAIN-TAB-RESTORE ... requested=Statistics transport=updateTabsetPanel`
2. `GRAPH-EDIT-STATS-RESTORE ... Analysis 1`
3. restore barrier attempt 1 / 2 完了
4. `GRAPH-EDIT-STATS-RESULT ... chars=249`

これにより、外側section button、実tab pane、R `input$graph_main_tab`、Statistics lifecycleが初回loadから揃うことを確認しています。

### Figure

- Figure-owned frozen snapshot
- explicit Graph -> Figure Import / Refresh
- explicit Figure -> Graph Apply
- Apply後のGraph Data / reshape / Statistics保護
- persistent Figure Layout
- multi-panel Figure save / restore

### Export

Graph:

- PNG
- SVG
- PDF
- editable PPTX

Figure:

- PNG
- SVG
- PDF
- editable PPTX
- DrawingML shape出力
- `persisted_raster=0`を維持する経路
- first-click rvg empty-DML edgeの1回限定retry
- SVG fullwidth percent export normalization

## Automated regression

RC13.10 build時には、Node環境で以下を確認しています。

- `node --check www/app_client.js` PASS
- RC10〜RC13.10 JavaScript regression PASS
- RC13 rapid-edit / Figure stability regression PASS
- RC13.7 Statistics activation regression PASS
- RC13.8 Project-first / fractional numeric regression PASS
- RC13.9 split-state regression guard PASS
- RC13.10 atomic main-tab restore regression PASS

正式v4.0化後も同じJavaScript regression群を実行して確認します。

## Numeric control audit

RC13.8でFull Editor / Figure Controls / Settings Manager / Figure layoutを横断監査しました。

代表的なcontinuous controls:

- `bar_width`
- `line_width`
- `box_width_scale`
- point size
- alpha
- jitter X/Y
- dodge / group spacing / category spacing
- border / error line width
- facet spacing
- legend key / item spacing

これらはdouble semanticsです。

代表的なdiscrete controls:

- shape ID
- dash / gap ID
- legend order
- row / column / slot index
- whole-pixel layout controls

これらはinteger semanticsを維持します。

詳細表は `docs/history/V4_RC13_8_NUMERIC_CONTROL_AUDIT.md` を参照してください。

## Build環境上の制約

RC13.10を作成したbuild containerにはR/Rscriptがなかったため、その環境ではR/Shiny runtime regressionを実行していません。JavaScript/static regressionとWindows R 4.4.3実機ログを組み合わせて検証しています。

正式v4.0 package作成時も、R runtime behaviorはRC13.10から変更していません。

## 既知の非ブロッカー

- invalid ggplot時の `Error: [object Object]` 表示品質
- 一部環境でのArial PostScript warning
- jsonlite named-vector warning（v4.0.1候補でcleanup済み、Windows実機再確認待ち）
- 51カテゴリ超slot poolの広範な実ブラウザ確認
- Facet round-tripの追加確認

これらはv4.0正式化を止めるblockerとしては扱っていません。

## 正式v4.0パッケージ整理時の再確認

RC13.10から正式v4.0へ整理した際に、次を再確認しました。

- `APP_VERSION = "v4.0"`
- `www/*.js` の `node --check` PASS
- `tests/*.js` の全JavaScript regression PASS
- literal `source()` / `sys.source()`参照: missing 0
- `R/bootstrap/FILE_LAYOUT.json` のR entry: missing 0
- RC13.10とのruntime file比較: `R/bootstrap/app_config.R` のversion文字列以外に差分 0
- RC文書は内容を削除せず `docs/history/` へ移動

R/Rscriptはこの整理環境にも存在しないため、正式v4.0名へ変更した後のR runtime再実行は行っていません。runtime implementationはRC13.10と同一です。

### data-mapping-reconcile1 static checks
- Data patch reconciliation is limited to `key == "text"`.
- Valid target-derived Mapping plan is written into the same canonical commit as `data_text`.
- Invalid/partial data leaves prior Mapping unchanged.
- No Graph Editor ownership/replay architecture changes.
