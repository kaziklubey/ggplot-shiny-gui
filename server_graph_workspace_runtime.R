  # v3.73.2.18: legacy show_graph()/Global Preview compatibility display
  # path retired. Ordinary selection always targets the persistent Editor.

  # v3.66.0 editor-first rollback: instantiate the one persistent Graph
  # Editor shell at startup and attach the initial g001 as soon as the fixed DOM
  # bindings are available.  The Editor is visible from first paint; there is no
  # preview-only/browse state.
  session$onFlushed(function() {
    ensure_graph_single_editor_module()
    editing_graph_id("")
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("IDLE")

    meta0 <- isolate(graph_meta())
    selected0 <- if (nrow(meta0)) as.character(meta0$id[[1]]) else ""
    if (nzchar(selected0)) active_graph(selected0)
    publish_client_preview_catalog(
      reason = "startup-editor-first",
      selected = if (nzchar(selected0)) selected0 else NULL,
      enter_browse = FALSE
    )
    diag_log(
      "EDITOR-SHELL",
      paste0("persistent shell ready; editor-first selected=", if (nzchar(selected0)) selected0 else "<none>")
    )
    # Build the built-in sample GraphState once from the persistent Editor's
    # static shell. Sample data and Mapping are filled deterministically by the
    # template builder, so browser input round-trips are not part of creation.
    session$onFlushed(function() {
      capture_graph_single_default_state("startup-post-bind")
      if (nzchar(selected0) && !isTRUE(isolate(project_load_locked())) && selected0 %in% isolate(graph_meta())$id) {
        diag_log("EDITOR-FIRST", "startup initial Graph attach requested", id = selected0)
        graph_single_load(selected0, new_graph = TRUE)
      }
    }, once = TRUE)
  }, once = TRUE)

  create_graph <- function(name, initial_state = NULL, select = TRUE) {
    id <- next_id()

    meta <- isolate(graph_meta())
    meta <- rbind(
      meta,
      data.frame(id = id, name = name, stringsAsFactors = FALSE)
    )
    graph_meta(meta)

    if (!is.null(initial_state)) cache_set(id, initial_state)

    is_new_graph <- is.null(initial_state)
    if (isTRUE(is_new_graph)) {
      # A new Graph is born as a deep copy of the same built-in sample
      # GraphState used by g001. The Editor is only a consumer/editor of it.
      seed_new_graph_default_state(id)
    }

    # v3.73.2.18: Graph creation/duplication is state-only. Figure owns its
    # own imported snapshots; a new Graph never inherits an SVG side cache.

    # Editor-first: any selected Graph becomes the persistent Editor target
    # immediately; there is no cached-preview or browse-only stop.
    refresh_export_choices()
    if (isTRUE(select)) {
      publish_client_preview_catalog(
        reason = if (isTRUE(is_new_graph)) "graph-created-new" else "graph-created-from-state",
        selected = id,
        enter_browse = FALSE
      )
      request_graph_editor(
        id,
        source = if (isTRUE(is_new_graph)) "graph-created-new" else "graph-created-from-state",
        new_graph = isTRUE(is_new_graph)
      )
    } else {
      publish_client_preview_catalog(reason = "graph-created-background", selected = NULL, enter_browse = FALSE)
    }
    id
  }

  # ------------------------------------------------------------------
  # Graph workspace actions
  # ------------------------------------------------------------------
  # Project restore is state-first; there is no hidden per-Graph restore UI or
  # materialization progress lifecycle.

  # ------------------------------------------------------------------
  # Persistent Graph workspace
  # ------------------------------------------------------------------
  # The real graphUI() shell is mounted once. Graph identity changes only by
  # replaying canonical GraphState values into that same persistent Editor.

  # ------------------------------------------------------------------
  # Graph actions
  # ------------------------------------------------------------------
  # Compatibility clicks still update selection, but the normal browser Graph
  # tabs now request persistent Editor replay immediately.
  observeEvent(input$graph_click, {
    id <- as.character(input$graph_click %||% "")
    request_graph_editor(id, source = "legacy-click", new_graph = FALSE)
  }, ignoreInit = TRUE)

  # Browser-side cached preview selection updates canonical workspace selection
  # without touching the persistent Editor transaction.
  observeEvent(input$graph_client_selected, {
    id <- as.character(input$graph_client_selected %||% "")[1]
    if (!graph_selection_valid_id(id)) return()
    active_graph(id)
    diag_log("GRAPH-BROWSE", "client selection acknowledged", id = id)
  }, ignoreInit = TRUE)

  observeEvent(input$graph_edit_select, {
    req <- input$graph_edit_select
    id <- if (is.list(req)) as.character(req$id %||% "")[1] else as.character(req %||% "")[1]
    src <- if (is.list(req)) as.character(req$source %||% "button")[1] else "button"
    sec_key <- if (is.list(req)) as.character(req$sectionKey %||% "")[1] else ""
    request_graph_editor(id, source = src, new_graph = FALSE, section_key = sec_key)
  }, ignoreInit = TRUE)

  # v3.61.0: Graph editor readiness is owned by graph_single_load() and its
  # REPLAY -> READY settle transaction above. Per-Graph editor-ready observers
  # are intentionally bypassed.

  # Workspace return is view lifecycle only.  It may reconcile the same stale
  # owner after Figure Apply, but it never replays a different browsed Graph.
  observeEvent(input$workspace_main_tab, {
    if (!identical(as.character(input$workspace_main_tab %||% ""), "graph_workspace")) return()
    resume_graph_workspace()
  }, ignoreInit = TRUE)

  # Compatibility event from older cached-Parameters DOM. Route it into the
  # one persistent Editor instead of reviving a per-Graph source module.
  observeEvent(input$graph_ui_edit_request, {
    req <- input$graph_ui_edit_request
    id <- as.character(req$id %||% "")[1]
    sec <- as.character(req$section %||% "")[1]
    if (!nzchar(id) || project_load_action_blocked("graph-edit", id)) return()
    diag_log(
      "USER",
      paste0("graph_ui_edit_request -> persistent Editor section=", sec,
             " nonce=", as.character(req$nonce %||% "")),
      id = id
    )
    request_graph_editor(
      id,
      source = "legacy-parameter-ui",
      new_graph = FALSE,
      section_key = sec
    )
  }, ignoreInit = TRUE)
