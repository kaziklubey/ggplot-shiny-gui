# v3.73.1: Graph selection is editor-first. Selection changes the target Graph
# immediately; value replay is the internal transaction owned by
# server_graph_editor_runtime.R, with no user-visible browse/edit mode.

  graph_selection_valid_id <- function(id) {
    id <- as.character(id %||% "")[1]
    nzchar(id) && id %in% isolate(graph_meta())$id
  }

  select_graph_preview <- function(id, source = "server", publish = TRUE) {
    id <- as.character(id %||% "")[1]
    if (!graph_selection_valid_id(id)) return(invisible(FALSE))
    active_graph(id)
    diag_log("GRAPH-BROWSE", paste0("select source=", source, " editor_owner=", graph_single_owner()), id = id)
    if (isTRUE(publish)) {
      publish_client_preview_catalog(
        reason = paste0("graph-browse-", source),
        selected = id,
        enter_browse = FALSE
      )
    }
    invisible(TRUE)
  }

  request_graph_editor <- function(id, source = "graph-select", new_graph = FALSE, section_key = "") {
    id <- as.character(id %||% "")[1]
    if (!graph_selection_valid_id(id)) return(invisible(FALSE))
    if (project_load_action_blocked("graph-edit", id)) return(invisible(FALSE))

    owner <- graph_single_owner()
    if (isTRUE(isolate(graph_single_editor_loading()))) {
      active_graph(id)
      if (identical(id, owner)) {
        diag_log(
          "EDITOR-ACTIVATION",
          paste0(
            "duplicate ignored source=", source,
            if (nzchar(section_key)) paste0(" section=", section_key) else "",
            " mode=", as.character(isolate(graph_single_editor_mode()) %||% "")
          ),
          id = id
        )
        return(invisible(TRUE))
      }

      # Latest-selection-wins queue. Do not interrupt the current Graph value
      # replay because graph_single_load() snapshots the outgoing owner and a
      # mid-replay switch could publish a partial state.  v3.74.3 releases a
      # superseded target immediately after canonical acceptance, before its
      # final live-render/browser-image-complete cycle.
      graph_single_pending_target(list(
        id = id, source = source, new_graph = isTRUE(new_graph), section_key = section_key
      ))
      diag_log(
        "EDITOR-ACTIVATION-QUEUE",
        paste0("queued behind owner=", owner, " source=", source),
        id = id
      )
      return(invisible(TRUE))
    }

    graph_single_pending_target(NULL)
    active_graph(id)
    diag_log(
      "EDITOR-ACTIVATION",
      paste0("auto/source=", source, if (nzchar(section_key)) paste0(" section=", section_key) else ""),
      id = id
    )
    updateTabsetPanel(session, "workspace_main_tab", selected = "graph_workspace")
    graph_single_load(id, new_graph = isTRUE(new_graph))
    invisible(TRUE)
  }

  # Drain a queued Graph selection after the previous singleton Editor has
  # released its loading flag. For a superseded target v3.74.3 can release at
  # canonical acceptance (before final live render); otherwise release occurs at
  # ordinary READY/abort. No polling or timer is involved.
  observe({
    loading <- graph_single_editor_loading()
    pending <- graph_single_pending_target()
    if (isTRUE(loading) || !is.list(pending)) return()

    graph_single_pending_target(NULL)
    id <- as.character(pending$id %||% "")[1]
    if (!graph_selection_valid_id(id)) return()
    if (identical(id, graph_single_owner()) && graph_single_ready(id)) {
      show_graph_single_editor(id)
      return()
    }

    diag_log("EDITOR-ACTIVATION-QUEUE", "drain latest target", id = id)
    request_graph_editor(
      id,
      source = as.character(pending$source %||% "queued-select")[1],
      new_graph = isTRUE(pending$new_graph),
      section_key = as.character(pending$section_key %||% "")[1]
    )
  })

  resume_graph_workspace <- function() {
    id <- selected_graph_id()
    if (!graph_selection_valid_id(id)) return(invisible(FALSE))

    owner <- graph_single_owner()
    stale_owner <- identical(owner, id) &&
      identical(as.character(isolate(graph_single_editor_mode()) %||% ""), "STALE")

    # Figure -> Graph Apply intentionally invalidates the current Editor owner.
    # Reconcile only that same stale owner.  Merely returning to Graph must not
    # replay a different selected Graph.
    if (isTRUE(stale_owner)) {
      diag_log("EDITOR-ACTIVATION", "Graph workspace resumed with stale current owner; canonical resync", id = id)
      graph_single_load(id, new_graph = FALSE)
      return(invisible(TRUE))
    }

    if (identical(owner, id) && graph_single_ready(id)) {
      show_graph_single_editor(id)
      return(invisible(TRUE))
    }

    diag_log("EDITOR-ACTIVATION", "Graph workspace resumed; selected Graph auto-replay", id = id)
    request_graph_editor(id, source = "workspace-resume", new_graph = FALSE)
  }
