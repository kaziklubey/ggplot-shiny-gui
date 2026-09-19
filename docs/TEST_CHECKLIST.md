# Runtime test checklist

Use the checkpoints in order when validating on the Windows/R 4.3.1 environment.

## Common smoke test for every ZIP

1. Start with `source('run.R')`.
2. Confirm the version string in `[SESSION] server start ...`.
3. Confirm the initial Graph editor appears.
4. Open the existing `.ggplotpack` test Project.
5. Switch through all Graph tabs.
6. Open Figure, select/move panels, then return to Graph.
7. Make one ordinary Graph edit and verify the Preview refreshes.
8. Save/export at least one Graph.

## Medium-specific

- Confirm line / bar / scatter / box Projects restore to the same type.
- Confirm legacy saved `violin` type still opens through the historical box compatibility path.
- Check Position and Linetype Mapping restoration on types that use them.

## Final-specific

- Paste tab-separated data and whitespace-separated data once each.
- Confirm seeded Graph controls restore after Project load.
- Confirm Project save/load and Graph/Figure exports still work after server runtime decomposition.

The refactor intentionally does not claim runtime equivalence until these checks are run in an R environment; the build environment used for packaging does not contain R/Rscript.


## v3.72.2 plot revision smoke test

- Project load completes and Graph mappings/styles match v3.72.1.
- Graph switch logs `PLOT-REVISION` only for semantic render changes.
- A `STATE-COMMIT ... render_changed=FALSE` is not immediately followed by a new `make_plot START` unless a separate render revision/remount requires it.
- Project-name-only changes do not rebuild the plot or invalidate a valid Graph SVG.
- g003/g006 first-open dynamic colors/legend titles settle without losing values.
- Figure delete → source GC → re-add still imports the current Graph.

## v3.73.2.36 Phase 2 direct-state source boundary

- [ ] Static scan: no runtime reference to `schedule_graph_materialization`, `request_graph_materialization`, `ensure_graph_ui`, `instantiate_graph`, `source_graph_module`, `source_graph_ready`, or `modules[[id]]` remains.
- [ ] Normal Graph A -> B -> A still uses one persistent Editor and one live Plot; no hidden Graph module is created.
- [ ] Figure new assignment, selected-panel refresh, Inset refresh, and bulk import work for dormant Graphs via `DIRECT-STATE` diagnostics.
- [ ] Editing a Graph, then explicit Graph -> Figure refresh, imports the latest stable canonical state without persisted-SVG reuse.
- [ ] Bulk Export `Selected` and `All` export dormant Graphs without preparing/mounting Graph editors.
- [ ] Shared Style change updates dormant Graph canonical states without mounting them; the visible Graph updates through the normal persistent replay only.
- [ ] Figure Shared Style sync regenerates affected Figure-owned snapshots direct-state; no sequential Figure Editor switching occurs.
- [ ] Project save/reopen restores canonical GraphState + Figure-owned snapshots; only the selected Graph attaches to the persistent Editor.
- [ ] Graph deletion during ordinary idle state has no hidden materialization teardown dependency.


## v3.72.24 Editor hydration fast path

- [ ] Create a new Graph after editing a non-default Graph; `新規Graphを準備中…` clears and the Editor is usable.
- [ ] New Graph canonical state equals the captured pristine default template; no values are inherited from the previously edited Graph.
- [ ] Cold-edit a Wide→Long Graph; RESHAPE-PARENT, RESHAPE-BIND, and MAPPING-BIND finish without 50/75 ms polling diagnostics.
- [ ] Switch among Graphs with overlapping dynamic style levels; no cross-Graph color/shape/linetype contamination.
- [ ] Force/reproduce a canonical reconcile failure; full-screen hydration mask clears and browse mode is restored.
- [ ] Figure → Graph Apply still generates a fresh Graph preview.
- [ ] Figure assignment/refresh and Selected/All Export still materialize source Graphs correctly.



## v3.72.27.1 startup recursion hotfix

- [ ] Start with `source('run.R')`; no `evaluation nested too deeply`, `Error in if`, or repeated `dat` stack appears before the first Graph attach.
- [ ] Startup log reaches `GRAPH-SINGLE-EDITOR captured pristine default state` before `EDITOR-FIRST` requests g001 attachment.
- [ ] g001 initial attach does not report `default-state-missing`.
- [ ] With Plot Wide→Long OFF, Data View equals the parsed original Graph dataset.
- [ ] With Plot Wide→Long ON, Data View shows the transformed columns/rows while Statistics new Analysis still starts from the original dataset.
- [ ] Existing line/bar/scatter/box Graphs render normally; prepared Mapping behavior is unchanged.
- [ ] Open an existing Project and switch Graphs repeatedly; no `dat() <-> plot_data()` recursion appears.

## v3.72.27 Statistics raw-data / Analysis recipe

- [ ] Open a Graph whose Plot uses Wide→Long. Create a new Statistics Analysis: it must start from the original dataset (`as-is`), not inherit Plot Wide→Long.
- [ ] In Analysis A, run a test directly on original wide columns (for example paired Pre/Post) with `as-is`. Save/switch away/switch back; all variable choices and result must restore.
- [ ] In Analysis B on the same Graph, enable Analysis-local Wide→Long for Pre/Post -> Condition/Value and configure a factor plan using the generated columns. Switch A <-> B repeatedly; each Analysis keeps its own preparation and test settings.
- [ ] Change the Plot-side Wide→Long columns/names after A/B exist. Statistics A/B preparation must not change.
- [ ] Data View must continue to show the current Plot data, including Plot-side Wide→Long when enabled.
- [ ] Save and reopen the Project. Analysis-local preparation, factor plan, DV/ID/factor selections, t-test/correlation settings and names must persist; calculated results are recalculated, not serialized.
- [ ] Open a legacy Project whose Analysis recipe predates v3.72.27 and whose Plot had Wide→Long enabled. Its historical Statistics input table must be preserved by one-time migration into the Analysis recipe. After restore, changing Plot reshape must no longer change that Analysis.
- [ ] Figure -> Graph Apply must preserve all `statistics_recipes` while applying Plot-owned GraphState fields.
- [ ] Enter Statistics, Data View and 製作者コメント. The singleton Plot Preview must be completely hidden; returning to Plot must restore it for the current semantic Graph.
- [ ] Confirm Statistics does not request/render `stats_reference_plot` and does not trigger a Plot rebuild merely because the Statistics tab opens.
