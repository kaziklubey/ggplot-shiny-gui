  # v4 RC7: keep one persistent Graph Editor module and one persistent live plot.
  # Every Graph selection retargets this same Editor; there is no cached-preview
  # browsing mode.
  session$onFlushed(function() {
    ensure_graph_single_editor_module()
    editing_graph_id("")
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("IDLE")

    meta0 <- isolate(graph_meta())
    selected0 <- if (nrow(meta0)) as.character(meta0$id[[1]]) else ""
    if (nzchar(selected0)) active_graph(selected0)
    publish_client_graph_catalog(
      reason = "startup-editor-first",
      selected = if (nzchar(selected0)) selected0 else NULL
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
    is_new_graph <- is.null(initial_state)

    # v4 RC7: creation is canonical-state first, but no display preview is
    # materialized. Once the state is committed, selecting the new Graph simply
    # retargets the one persistent Editor and its live ggplot output.
    state <- if (isTRUE(is_new_graph)) {
      graph_single_default_state_snapshot("graph-create-atomic")
    } else {
      tryCatch(unserialize(serialize(initial_state, NULL, version = 3)), error = function(e) initial_state)
    }

    if (!is.list(state)) {
      diag_log("GRAPH-CREATE", "ABORT canonical default state unavailable before publication", id = id)
      showNotification("新しいGraphの初期状態を作成できませんでした。", type = "error")
      return(NULL)
    }

    registry_commit(
      id,
      state,
      source = if (isTRUE(is_new_graph)) "graph-created-default" else "graph-created-from-state"
    )
    if (!cache_has(id)) {
      diag_log("GRAPH-CREATE", "ABORT canonical registry commit failed", id = id)
      showNotification("新しいGraphの状態を保存できなかったため、Graphは追加しませんでした。", type = "error")
      return(NULL)
    }

    meta <- isolate(graph_meta())
    meta <- rbind(meta, data.frame(id = id, name = name, stringsAsFactors = FALSE))
    graph_meta(meta)
    refresh_export_choices()

    if (isTRUE(select)) {
      active_graph(id)
      publish_client_graph_catalog(
        reason = if (isTRUE(is_new_graph)) "graph-created-live" else "graph-duplicated-live",
        selected = id
      )
      request_graph_editor(
        id,
        source = if (isTRUE(is_new_graph)) "graph-created-new" else "graph-duplicated",
        new_graph = isTRUE(is_new_graph)
      )
    } else {
      publish_client_graph_catalog(reason = "graph-created-background", selected = NULL)
    }

    diag_log(
      "GRAPH-CREATE",
      paste0(
        "published state_first=TRUE preview=NONE live_editor=", isTRUE(select),
        " new=", isTRUE(is_new_graph),
        " revision=", graph_state_revision_value(id),
        " render_revision=", graph_render_state_revision_value(id)
      ),
      id = id
    )
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
  # The real graphUI() shell is mounted once. Browser-local selection does not
  # retarget it; explicit edit activation replays canonical GraphState into the
  # same persistent Editor.

  # ------------------------------------------------------------------
  # Graph actions
  # ------------------------------------------------------------------
  # Legacy compatibility clicks use the same one persistent Editor.
  observeEvent(input$graph_click, {
    id <- as.character(input$graph_click %||% "")
    request_graph_editor(id, source = "legacy-click", new_graph = FALSE)
  }, ignoreInit = TRUE)

  # v4 RC7: a Graph tab click immediately targets the persistent Editor. The
  # browser sends only the Graph id; canonical values remain in the R registry.
  observeEvent(input$graph_client_selected, {
    id <- as.character(input$graph_client_selected %||% "")[1]
    if (!graph_selection_valid_id(id)) return()
    request_graph_editor(id, source = "graph-select", new_graph = FALSE)
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
