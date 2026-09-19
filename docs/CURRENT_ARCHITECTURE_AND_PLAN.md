# Current architecture and forward plan

## v3.73.1 Editor-first workspace

The application is an **editor**, not a preview viewer.  Cached SVG remains an important latency-hiding layer, but ordinary Graph selection no longer stops in a browse-only mode.

Core model:

```text
Graph / Figure item = persistent canonical state + cached preview
Graph workspace      = one persistent Editor, always the primary surface
Graph selection      = select target -> auto hydrate/sync Editor -> READY
Cached SVG           = visual seed / transaction fallback, never a separate user mode
```

### Graph selection / editor ownership

`active_graph()` is the selected Graph and `editing_graph_id()` is the Graph currently owned by the singleton Editor. They may differ **only while an ACK-gated switch is in flight** (or during failure fallback), not as a normal browse state.

```text
Graph tab click
  -> selected Graph changes immediately
  -> current Editor transaction finishes if already in flight
  -> latest pending target wins
  -> graph_single_load(target)
  -> cached target ACK when available
  -> state settle / canonical reconcile
  -> live bind ACK
  -> live authorize ACK
  -> READY
```

The outgoing Graph is never interrupted mid-hydrate.  Rapid selections are serialized through one latest-target queue so a partially restored Editor state cannot be committed as canonical GraphState.

### Plot / Statistics / Data View / comment

The Graph workspace owns a stable outer section bar (Plot / Statistics / Data View / 製作者コメント) outside the hydration mask. It drives the existing hidden `graph_main_tab` binding, so the current section survives Graph ownership changes without creating a second source of truth. A user may stay on Statistics, Data View or the comment tab while switching Graphs; no separate Edit action is required. Plot controls are visible only on Plot, Statistics uses its Analysis controls, and Data View / comment use the full content width. Plot rendering remains gated to the Plot section, and Statistics keeps its independent Analysis recipe/data-preparation boundary.

Statistics is still implemented inside the persistent `graphServer` owner in v3.73.1; the important change in this release is that its **navigation and availability no longer depend on a user-visible browse/edit promotion step**.  A later extraction may move Statistics/Data/Notes to separate workspace services if profiling shows value, without changing their canonical ownership rules.

### Project open / close

Project open stages Registry + persisted SVG/Figure snapshots first, then automatically hydrates the selected Graph Editor.  Project close is an explicit hard boundary: after confirmation the Shiny session reloads to the normal pristine `g001 / Graph 1` Editor, ensuring Graph/Figure/Shared-Library/editor leases from the closed Project cannot leak into the next workspace.

## Canonical state

- GraphState Registry remains the canonical truth.
- Figure-owned editable GraphState remains separate from source GraphState.
- DOM is transient and must never become canonical.
- Persisted SVG is a display cache, not state truth.
- Shared Label / Style Library is Project-owned central semantic state; Graph bindings remain Project-specific metadata.

## Required invariants

1. The Graph workspace is Editor-first; no ordinary selection requires an explicit Edit button.
2. Only one persistent Graph Editor exists. Graph identity is data, never module identity.
3. A running Graph hydrate/sync transaction is never interrupted by another Graph commit; latest requested target is queued and drained after READY/abort.
4. Registry is canonical; preview is cache.
5. Statistics recipes remain independent of Plot Mapping and Plot Wide→Long mutable state.
6. Background source materialization/READY never updates an existing Figure-owned snapshot automatically; only explicit Figure operations may do so.
7. Figure-only state never leaks into source GraphState.
8. Shared Style never directly synchronizes Graph-to-Graph and never auto-binds by name.
9. Do not add synchronization via `Sys.sleep`, `setTimeout`, `setInterval`, `MutationObserver`, `invalidateLater`, `reactivePoll`, or `reactiveTimer`; reuse existing event/ACK/flush boundaries instead.

## Historical pivot (v3.59-v3.72)

The previous performance pivot separated browse selection from explicit editor activation.  That architecture established the single persistent Editor, canonical Registry, cached preview, materialization service, and ACK-gated restore machinery.  v3.73.1 keeps those internals but removes browse-only as the normal **user workflow** because the application is fundamentally an editor.


### Transactional hydrate
A single editor must not merely replay the old restore flow. Introduce an explicit editor state machine:

```text
READY -> HYDRATING -> READY
```

During `HYDRATING`, ordinary writeback/render observers must be gated. Target flow:

```text
load canonical state
-> build dynamic choices/UI
-> synchronize input values
-> confirm internal model
-> READY
-> at most one required render
```

### Revision/cache stage
After single editors stabilize, introduce at minimum:

```text
state_revision
preview_revision
editor_dirty
```

Then add explicit data/stat/plot/preview invalidation only as needed.

## Performance interpretation

Runtime logs repeatedly show `make_plot()` around tenths of a second, while editor mount/binding/restore can take seconds. Therefore the main strategy remains: **reduce how often editor establishment is required**, not micro-optimize ggplot construction first.

## v3.60.1 stabilization before Graph single-editor

Two migration invariants are now explicit:

- A live Graph editor may remain mounted while another Graph is browsed, but its controls are hidden whenever `selected_graph_id != editing_graph_id`. Browse remains SVG-only and never retargets the editor.
- The Figure reusable editor is a state machine: `IDLE -> HYDRATING -> READY`. During `HYDRATING`, controls are hidden and `on_state_change` writeback remains gated. `READY` is published only after the loaded module state is stable across consecutive Shiny flush checkpoints. Loading a Figure-owned GraphState is view hydration and must not itself mutate FigureState or the Figure snapshot.

The next architectural step remains a true fixed-namespace Single Graph Editor with transaction load/commit.

## v3.73.2.36 direct-state source boundary

The hidden per-Graph materialization compatibility layer is retired from active runtime. `server_graph_materialization_runtime.R` and its disposable Graph DOM/module lifecycle are removed.

- Normal Graph editing: one persistent `graph_editor_single` module only.
- Figure Main/Inset/import: canonical or Figure-owned GraphState -> server-side direct renderer -> Figure-owned snapshot.
- Export: canonical GraphState -> server-side direct export renderer -> file.
- Shared Style Graph: update canonical state; only the visible singleton owner may be replayed. Dormant Graphs remain state-only.
- Shared Style Figure: update Figure-owned state and regenerate snapshots direct-state. The visible Figure Editor, when present, is presentation sync only.
- Project load: state-first. Dormant Graphs do not have hidden UI/module restore work.

Do not reintroduce `schedule_graph_materialization()`, `request_graph_materialization()`, per-Graph hidden `graphUI()` / `graphServer()`, source-module revision leases, browser materialization drain barriers, or Figure-editor sequential generation queues.


## v3.72.24 Editor hydrate fast path

The v3.72.23 materialization boundary is unchanged. Editor hydration now removes timer-driven restore progression and formalizes new-Graph defaults.

- `seed_new_graph_default_state()` commits a deep-copied snapshot of the pristine singleton default GraphState before new-Graph Editor activation.
- RESHAPE/MAPPING browser binding checks are generation-scoped event transactions; the 50 ms browser polling loop is removed.
- The three restore-side 75 ms `invalidateLater()` loops are removed.
- Persistent-shell RESHAPE parent controls skip binding ACK when current bound values already match canonical state.
- Mapping `shape` / `linetype` semantic defaults treat a transient post-ACK NULL as `__color__`, preventing the new-Graph false resync seen in v3.72.23 logs.
- Persistent dynamic-style reassertion no longer waits one extra whole-server flush.
- The outer Editor transaction no longer requires repeated equality of the entire GraphState after `ready()`. It crosses one flush and arbitrates against canonical RenderState.
- If the one canonical reconcile retry still fails, `graph_single_abort_activation()` reopens the render gate, clears the hydration mask and returns to browse rather than exposing an unleased Editor or leaving the UI blocked.
