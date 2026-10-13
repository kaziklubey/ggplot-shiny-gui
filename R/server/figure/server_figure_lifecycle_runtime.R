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

  # The Figure lifecycle owns destruction/materialization of derived runtime
  # state. Project I/O replaces canonical state and invokes this one reset; it
  # does not publish renderer requests itself.
  reset_figure_runtime <- function() {
    # Project replacement always stages Figure canonically while dormant, even
    # when the upload was initiated from the Figure workspace. This prevents
    # activation-owned observers from materializing the old/new Figure midway
    # through the atomic restore.
    figure_workspace_active(FALSE)
    figure_control_restore_seed(NULL)
    close_figure_load_progress()
    if (exists("reset_figure_legend_materializer", mode = "function", inherits = TRUE)) reset_figure_legend_materializer()
    reset_figure_source_snapshot_service(reason = "figure-runtime-reset")
    reset_figure_editors(clear_states = TRUE)
    figure_queue(character(0))
    figure_load_pending(FALSE)
    figure_load_target_ids(character(0))
    figure_load_expected_revisions(list())
    figure_inset_refresh_target(list(owner_id = "", source_id = ""))
    figure_panel_refresh_target(list(id = "", key = ""))
    figure_inset_preview_cache(list())
    figure_requested_ids(character(0))
    figure_requested_layout(list())
    figure_requested_overrides(list())
    figure_plot_overrides(list())
    figure_requested_size_mode("auto")
    figure_requested_size_basis("panel_legend")
    figure_requested_title_align("none")
    figure_requested_layout_mode("row")
    figure_requested_autofit_policy("live")
    figure_autofit_revision(0L)
    figure_geometry_revision(0L)
    figure_reorder_undo(NULL)
    figure_requested_free_padding(24)
    figure_requested_external_assets(list())
    figure_loaded_plots(list())
    figure_loaded_exports(list())
    figure_loaded_assets(list())
    figure_persisted_previews(list())
    clear_figure_svg_cache()
    clear_figure_geometry_cache()
    clear_figure_geometry_source_state()
    figure_selected_row(1L)
    figure_selected_graph("")
    figure_selected_panel_key("")
    figure_drag_syncing(FALSE)
    figure_inspector_syncing(FALSE)
    invisible(NULL)
  }

  enter_figure_workspace <- function(reason = "tab-open") {
    if (figure_workspace_is_active()) return(invisible(FALSE))
    figure_workspace_active(TRUE)
    # Activation is the sole owner of browser controls and renderer hydration.
    # Project restore only stages this canonical seed while the workspace sleeps.
    seed <- isolate(figure_control_restore_seed())
    if (is.list(seed)) {
      updateSelectInput(session, "figure_size_mode", selected = seed$mode %||% "auto")
      updateSelectInput(session, "figure_size_basis", selected = seed$basis %||% "panel_legend")
      updateSelectInput(session, "figure_title_align", selected = seed$title_align %||% "none")
      updateSelectInput(session, "figure_layout_mode", selected = seed$layout_mode %||% "row")
      updateSelectInput(session, "figure_autofit_policy", selected = seed$autofit_policy %||% "live")
      updateNumericInput(session, "figure_canvas_width", value = seed$width %||% 1600)
      updateNumericInput(session, "figure_canvas_height", value = seed$height %||% 1000)
      updateNumericInput(session, "figure_gap_x", value = seed$gap_x %||% 12)
      updateNumericInput(session, "figure_gap_y", value = seed$gap_y %||% 12)
      figure_requested_autofit_policy(as.character(seed$autofit_policy %||% "live"))
      figure_requested_free_padding(as.numeric(seed$free_padding %||% 24))
    }
    bump_figure_layout_ui()
    figure_geometry_revision(as.integer(isolate(figure_geometry_revision()) %||% 0L) + 1L)
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
