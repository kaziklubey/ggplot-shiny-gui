# v3.73.2.23: Figure workspace lifecycle and first-view snapshot bootstrap.
# Figure layout/source ownership is persistent. Entering the workspace may only
# materialize a missing Figure-owned snapshot; it must never refresh one that
# already exists.

  figure_workspace_is_active <- function() {
    isTRUE(isolate(figure_workspace_active()))
  }

  figure_main_panel_source_ids <- function() {
    layout <- isolate(figure_layout_state())
    meta_ids <- as.character(isolate(graph_meta())$id %||% character(0))
    ids <- unique(unlist(lapply(layout %||% list(), function(row) {
      vapply(row$cells %||% list(), function(cell) {
        st <- as.character(cell$source_type %||% "internal_graph")[1]
        id <- as.character(cell$id %||% cell$source_id %||% "")[1]
        if (identical(st, "internal_graph") && nzchar(id)) id else ""
      }, character(1))
    }), use.names = FALSE))
    intersect(ids[nzchar(ids)], meta_ids)
  }

  figure_main_snapshot_exists <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(FALSE)
    if (exists("figure_editor_snapshot_available", mode = "function", inherits = TRUE) &&
        isTRUE(figure_editor_snapshot_available(id))) return(TRUE)
    persisted <- isolate(figure_persisted_previews())
    rec <- persisted[[id]]
    is.list(rec) && nzchar(as.character(rec$svg %||% "")[1])
  }

  figure_bootstrap_missing_main_snapshots <- function(reason = "workspace-first-view") {
    if (!exists("request_figure_source_snapshot", mode = "function", inherits = TRUE)) return(invisible(FALSE))
    ids <- figure_main_panel_source_ids()
    if (!length(ids)) return(invisible(FALSE))
    edit_states <- isolate(figure_edit_states())
    queued <- character(0)

    for (id in ids) {
      if (isTRUE(figure_main_snapshot_exists(id))) next
      # Automatic first-view bootstrap is one-shot. Failed prior attempts are
      # left for explicit Refresh/Bulk Import instead of retrying on every tab visit.
      if (figure_source_snapshot_completed_revision(id, "main") > 0L ||
          isTRUE(figure_source_snapshot_pending(id))) next

      owned_state <- edit_states[[id]]
      if (is.list(owned_state)) {
        request_figure_source_snapshot(
          id, reason = reason, import_editor_state = FALSE,
          state_override = owned_state, target_type = "main"
        )
        queued <- c(queued, id)
        next
      }

      request_figure_source_snapshot(id, reason = reason, import_editor_state = TRUE)
      queued <- c(queued, id)
    }

    if (length(queued)) {
      diag_log("FIGURE-BOOTSTRAP", paste0("queued missing main snapshots={", paste(unique(queued), collapse = ","), "} reason=", reason))
    }
    invisible(length(queued) > 0L)
  }

  enter_figure_workspace <- function(reason = "tab-open") {
    if (figure_workspace_is_active()) return(invisible(FALSE))
    figure_workspace_active(TRUE)
    released <- isTRUE(release_figure_geometry_bootstrap(reason))
    # Re-evaluate Figure geometry once on activation. release_figure_geometry_bootstrap()
    # already bumps the revision when Project bootstrap defer was active.
    if (!released) {
      figure_geometry_revision(as.integer(isolate(figure_geometry_revision()) %||% 0L) + 1L)
    }
    diag_log("FIGURE-RUNTIME", paste0("ACTIVE reason=", reason))
    figure_bootstrap_missing_main_snapshots(reason = "workspace-first-view")
    invisible(TRUE)
  }

  leave_figure_workspace <- function(reason = "tab-leave") {
    if (!figure_workspace_is_active()) return(invisible(FALSE))
    figure_workspace_active(FALSE)
    diag_log("FIGURE-RUNTIME", paste0("DORMANT reason=", reason, " geometry_measurement=suspended"))
    invisible(TRUE)
  }

  sync_figure_workspace_lifecycle <- function(tab, reason = "workspace-tab") {
    tab <- as.character(tab %||% "")[1]
    if (identical(tab, "figure_workspace")) {
      enter_figure_workspace(reason)
    } else {
      leave_figure_workspace(reason)
    }
  }

  observeEvent(input$workspace_main_tab, {
    sync_figure_workspace_lifecycle(input$workspace_main_tab, reason = "workspace-tab")
  }, ignoreInit = FALSE)
