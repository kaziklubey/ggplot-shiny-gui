# Figure workspace activation owns geometry only. Displaying the workspace is
# never permission to import GraphState into Figure-owned state.

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
