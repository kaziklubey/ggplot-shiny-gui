# v3.73.2.29 — focused canonical GraphState batch-write helpers.
# The legacy v28 batch input copies one whitelisted scalar GraphState setting
# from a source Graph to selected target Graphs. It remains a one-time Graph-only
# copy; v29 typed Graph/Figure writes live in R/server/graph/settings/server_graph_settings_value_runtime.R.

  graph_settings_manager_set_path <- function(state, path, value) {
    if (!is.list(state)) return(state)
    parts <- strsplit(as.character(path %||% "")[1], ".", fixed = TRUE)[[1]]
    if (!length(parts) || any(!nzchar(parts))) return(state)

    set_rec <- function(node, rest) {
      if (!is.list(node)) node <- list()
      key <- rest[[1]]
      if (length(rest) == 1L) {
        # Single-bracket assignment preserves an explicit NULL element rather
        # than deleting the field. This is an intentional canonical write.
        node[key] <- list(value)
        return(node)
      }
      child <- if (key %in% (names(node) %||% character(0))) node[[key]] else list()
      if (!is.list(child)) child <- list()
      child <- set_rec(child, rest[-1])
      node[key] <- list(child)
      node
    }

    set_rec(state, parts)
  }

  graph_settings_manager_commit_exact <- function(id, state, source = "settings-manager-batch") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state) || !cache_has(id)) return(list(changed=FALSE, render=FALSE))
    previous <- cache_get(id)
    if (!is.list(previous) || identical(previous, state)) return(list(changed=FALSE, render=FALSE))

    render_changed <- isTRUE(graph_render_state_changed(previous, state))
    render_paths <- graph_render_diff_paths(previous, state)
    cache_set(id, state, source = source)
    if (isTRUE(render_changed)) {
      bump_graph_render_state_revision(id)
    }
    diag_log(
      "GRAPH-SETTINGS-APPLY",
      paste0(
        "commit source=", source,
        " render_changed=", isTRUE(render_changed),
        if (length(render_paths)) paste0(" paths={", paste(head(render_paths, 12L), collapse=","), if (length(render_paths) > 12L) ",..." else "", "}") else ""
      ),
      id = id
    )
    list(changed=TRUE, render=render_changed)
  }


  graph_settings_manager_finalize_graph_changes <- function(render_changed, reason = "settings-manager-batch") {
    render_changed <- unique(as.character(render_changed %||% character(0)))
    render_changed <- render_changed[nzchar(render_changed)]
    if (!length(render_changed)) {
      return(invisible(list(owner_visible = FALSE, canonical_only = character(0))))
    }

    # v31: Settings Manager writes are already authoritative canonical GraphState
    # edits. Do not spin up disposable hidden Graph UIs / graphServer instances
    # merely to materialize dormant Graphs. Graph preview publication was retired
    # in v18, Figure refresh now has an explicit DIRECT-STATE path, and dormant
    # Graphs will replay the canonical state when they are next selected.
    owner <- as.character(isolate(graph_single_owner()) %||% "")[1]
    if (nzchar(owner) && owner %in% render_changed &&
        exists("graph_single_mark_stale", mode="function", inherits=TRUE)) {
      graph_single_mark_stale(owner, reason = reason)
    }

    owner_visible_graph <- nzchar(owner) && owner %in% render_changed &&
      identical(as.character(input$workspace_main_tab %||% ""), "graph_workspace")
    if (isTRUE(owner_visible_graph)) {
      request_graph_editor(owner, source = reason, new_graph = FALSE)
    }

    dormant_ids <- setdiff(render_changed, if (isTRUE(owner_visible_graph)) owner else character(0))
    if (length(dormant_ids)) {
      diag_log(
        "GRAPH-SETTINGS-CANONICAL",
        paste0(
          "canonical-only ids={", paste(dormant_ids, collapse=","), "}",
          " reason=", reason,
          " hidden_materialization=FALSE",
          " replay=on-next-visit"
        )
      )
    }
    invisible(list(owner_visible = owner_visible_graph, canonical_only = dormant_ids))
  }

  observeEvent(input$graph_settings_manager_apply, {
    req <- input$graph_settings_manager_apply %||% list()
    source_id <- as.character(req$sourceId %||% "")[1]
    path <- as.character(req$path %||% "")[1]
    target_ids <- unique(as.character(unlist(req$targetIds %||% character(0), use.names = FALSE)))
    target_ids <- target_ids[nzchar(target_ids)]

    meta_ids <- as.character(isolate(graph_meta())$id %||% character(0))
    rec <- graph_settings_manager_row_for_path(path)
    if (!nzchar(source_id) || !source_id %in% meta_ids || !is.list(rec) || !isTRUE(rec$apply)) {
      diag_log("GRAPH-SETTINGS-APPLY", paste0("REJECT source=", source_id, " path=", path, " reason=invalid-request"))
      showNotification("この設定は一括適用できません。", type = "warning")
      return()
    }
    target_ids <- intersect(setdiff(target_ids, source_id), meta_ids)
    if (!length(target_ids)) {
      showNotification("適用先Graphを選択してください。", type = "message")
      return()
    }

    source_state <- if (cache_has(source_id)) cache_get(source_id) else NULL
    got <- graph_settings_manager_get_result(source_state, path)
    if (!is.list(source_state) || !isTRUE(got$found)) {
      diag_log("GRAPH-SETTINGS-APPLY", paste0("REJECT source=", source_id, " path=", path, " reason=source-value-missing"), id = source_id)
      showNotification("基準Graphにこの設定値がありません。", type = "warning")
      return()
    }

    changed <- character(0)
    render_changed <- character(0)
    for (id in target_ids) {
      old <- if (cache_has(id)) cache_get(id) else NULL
      if (!is.list(old)) next
      new <- graph_settings_manager_set_path(old, path, got$value)
      result <- graph_settings_manager_commit_exact(id, new, source = "settings-manager-batch")
      if (isTRUE(result$changed)) changed <- c(changed, id)
      if (isTRUE(result$render)) render_changed <- c(render_changed, id)
    }

    changed <- unique(changed)
    render_changed <- unique(render_changed)
    # If a target is the visible persistent Graph Editor, replay it now;
    # dormant Graph previews keep the existing materialization service.
    graph_settings_manager_finalize_graph_changes(render_changed, reason = "settings-manager-batch")

    diag_log(
      "GRAPH-SETTINGS-APPLY",
      paste0(
        "DONE path=", path,
        " source=", source_id,
        " targets={", paste(target_ids, collapse=","), "}",
        " changed={", paste(changed, collapse=","), "}",
        " figure_snapshot_unchanged=TRUE"
      ),
      id = source_id
    )

    if (length(changed)) {
      showNotification(
        paste0(rec$label, " を ", length(changed), " Graphへ適用しました。Figure snapshotは変更していません。"),
        type = "message",
        duration = 4
      )
    } else {
      showNotification("選択Graphはすでに同じ値です。", type = "message", duration = 3)
    }
  }, ignoreInit = TRUE)
