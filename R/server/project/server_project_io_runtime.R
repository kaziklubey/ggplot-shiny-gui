# v3.70.0: extracted from server.R; sourced into the same server function environment.

  # ------------------------------------------------------------------
  # Project save / load
  # ------------------------------------------------------------------
  # v3.4.0 alpha6 GraphState phase 3:
  # Project serialization reads Graph state from the canonical registry only.
  # The active editor is synchronously committed immediately before build_project()
  # so an edit followed by an immediate Save cannot be lost behind the normal
  # debounced live-commit observer. Hidden/evicted Graphs are already represented
  # by their canonical registry entries.
  flush_active_graph_to_registry <- function(source = "pre-save-active-flush") {
    id <- as.character(isolate(editing_graph_id()) %||% "")[1]
    if (!nzchar(id) || !graph_single_ready(id)) return(invisible(FALSE))
    if (!graph_single_revision_is_current(id)) {
      diag_log(
        "STATE-SAVE-FLUSH",
        paste0(
          "skipped stale Editor canonical_revision=", graph_state_revision_value(id),
          " source=", source
        ),
        id = id
      )
      return(invisible(FALSE))
    }

    mod <- graph_single_mod()
    if (is.null(mod)) return(invisible(FALSE))
    live <- tryCatch(isolate(mod$state()), error = function(e) {
      diag_log("STATE-SAVE-FLUSH", paste0("failed: ", conditionMessage(e)), id = id)
      NULL
    })
    if (is.null(live) || !is.list(live)) return(invisible(FALSE))

    changed <- graph_single_publish_state(id, live, source = source)
    plot_type <- tryCatch(as.character((cache_get(id)$plot$type) %||% "<NULL>")[1], error = function(e) "<ERR>")
    diag_log(
      "STATE-SAVE-FLUSH",
      paste0("committed=", isTRUE(changed), " plot_type=", plot_type),
      id = id
    )
    invisible(TRUE)
  }

  # Statistics recipes are part of canonical GraphState. Hidden source
  # materializers are read-only and are never flushed back into the Registry.


  graph_state_for_save <- function(id) {
    if (!cache_has(id)) {
      diag_log("STATE-SAVE", "source=registry missing=TRUE", id = id)
      return(NULL)
    }

    st <- cache_get(id)
    plot_type <- tryCatch(as.character(st$plot$type %||% "<NULL>")[1], error = function(e) "<ERR>")
    stats_rr <- st$statistics_recipes
    stats_n <- if (is.list(stats_rr)) length(stats_rr) else 0L
    stats_ids <- if (stats_n) paste(names(stats_rr) %||% seq_len(stats_n), collapse = ",") else ""
    stats_selected <- as.character(st$statistics_selected_id %||% "")[1]
    diag_log(
      "STATE-SAVE",
      paste0(
        "source=registry plot_type=", plot_type,
        " statistics_recipes=", stats_n,
        " ids={", stats_ids, "}",
        " selected=", if (nzchar(stats_selected)) stats_selected else "<none>",
        " results_saved=FALSE"
      ),
      id = id
    )
    st
  }
  # v3.3.56: figure_default_layout_state moved to its Figure module.

  figure_state_for_save <- function() {
    seed <- isolate(figure_control_restore_seed())
    cw <- if (!is.null(seed)) seed$width else suppressWarnings(as.numeric(isolate(input$figure_canvas_width %||% figure_requested_width()))[1])
    ch <- if (!is.null(seed)) seed$height else suppressWarnings(as.numeric(isolate(input$figure_canvas_height %||% figure_requested_height()))[1])
    gx <- if (!is.null(seed)) seed$gap_x else suppressWarnings(as.numeric(isolate(input$figure_gap_x %||% figure_requested_gap_x()))[1])
    gy <- if (!is.null(seed)) seed$gap_y else suppressWarnings(as.numeric(isolate(input$figure_gap_y %||% figure_requested_gap_y()))[1])
    if (!is.finite(cw)) cw <- 1600
    if (!is.finite(ch)) ch <- 1000
    if (!is.finite(gx)) gx <- 12
    if (!is.finite(gy)) gy <- 12
    meta_now <- isolate(graph_meta())
    layout_now <- figure_sanitize_layout(isolate(figure_layout_state()), meta_now, auto_fill = FALSE, external_assets = isolate(figure_external_assets()))
    overrides_now <- isolate(figure_override_drafts())
    if (length(overrides_now)) {
      overrides_now <- lapply(overrides_now, figure_strip_slot_label_fields_from_override)
      layout_ids <- unique(unlist(lapply(layout_now, function(row) {
        vapply(row$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
      }), use.names = FALSE))
      keep_ids <- intersect(names(overrides_now), layout_ids[nzchar(layout_ids)])
      overrides_now <- overrides_now[keep_ids]
    }
    edit_states_now <- isolate(figure_edit_states())
    if (!is.list(edit_states_now)) edit_states_now <- list()
    layout_internal_ids <- unique(unlist(lapply(layout_now, function(row) {
      vapply(row$cells %||% list(), function(cell) {
        if (identical(as.character(cell$source_type %||% "internal_graph"), "internal_graph")) as.character(cell$id %||% "") else ""
      }, character(1))
    }), use.names = FALSE))
    layout_internal_ids <- layout_internal_ids[nzchar(layout_internal_ids)]
    edit_states_now <- edit_states_now[intersect(names(edit_states_now), layout_internal_ids)]

    list(
      version = 12L,
      renderer_schema = "asset-layer-v7-editable-graph-snapshot",
      autofit_policy = as.character(isolate(figure_requested_autofit_policy()) %||% "live"),
      size_mode = as.character(isolate(figure_requested_size_mode()) %||% "fixed"),
      size_basis = figure_normalize_alignment_basis(isolate(figure_requested_size_basis()) %||% "panel_legend"),
      title_align = as.character(isolate(figure_requested_title_align()) %||% "none"),
      layout_mode = as.character(isolate(figure_requested_layout_mode()) %||% "row"),
      free_canvas_padding = as.numeric(isolate(figure_requested_free_padding()) %||% 24),
      external_assets = isolate(figure_external_assets()),
      canvas_width = min(max(cw, 300), 6000),
      canvas_height = min(max(ch, 300), 6000),
      gap_x = min(max(gx, 0), 300),
      gap_y = min(max(gy, 0), 300),
      column_ratios = figure_shared_column_ratios(layout_now),
      layout = figure_reindex_layout(layout_now),
      overrides = overrides_now,
      editable_graph_states = edit_states_now
    )
  }

  reset_figure_workspace <- function(reset_layout = TRUE) {
    shared_style_graph_replay_pending(NULL)
    figure_inspector_folds(list())
    close_figure_load_progress()
    if (exists("reset_figure_legend_materializer", mode = "function", inherits = TRUE)) reset_figure_legend_materializer()
    reset_figure_source_snapshot_service(reason = "figure-workspace-reset")
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
    figure_override_drafts(list())
    figure_plot_overrides(list())
    figure_control_restore_seed(NULL)
    figure_requested_size_mode("auto")
    figure_requested_size_basis("panel_legend")
    figure_requested_title_align("none")
    figure_requested_layout_mode("row")
    figure_requested_autofit_policy("live")
    figure_autofit_revision(0L)
    figure_geometry_revision(0L)
    figure_reorder_undo(NULL)
    figure_requested_free_padding(24)
    figure_external_assets(list())
    figure_requested_external_assets(list())
    figure_loaded_plots(list())
    figure_loaded_exports(list())
    figure_loaded_assets(list())
    figure_persisted_previews(list())
    project_legacy_graph_previews(list())
    clear_figure_svg_cache()
    clear_figure_geometry_cache()
    clear_figure_geometry_source_state()
    figure_selected_row(1L)
    figure_selected_graph("")
    figure_selected_panel_key("")
    figure_drag_syncing(FALSE)
    figure_inspector_syncing(FALSE)
    if (isTRUE(reset_layout)) {
      figure_layout_initialized(FALSE)
      figure_layout_state(figure_default_layout_state())
      bump_figure_layout_ui()
    }
    invisible(NULL)
  }

  figure_layout_diag <- function(layout) {
    layout <- figure_reindex_layout(layout)
    keys <- unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) as.character(cell$key %||% ""), character(1))
    }), use.names = FALSE)
    list(rows = length(layout), keys = keys[nzchar(keys)])
  }

  restore_figure_project_state <- function(saved, id_map, meta) {
    figure_inspector_folds(list())
    # Live plot objects are never persisted. F1-5p does persist the lightweight
    # editable GraphState copy separately from SVG preview caches.
    if (exists("reset_figure_legend_materializer", mode = "function", inherits = TRUE)) reset_figure_legend_materializer()
    reset_figure_source_snapshot_service(reason = "project-figure-restore")
    reset_figure_editors(clear_states = TRUE)
    figure_queue(character(0))
    figure_load_pending(FALSE)
    figure_load_target_ids(character(0))
    figure_load_expected_revisions(list())
    figure_inset_refresh_target(list(owner_id = "", source_id = ""))
    figure_panel_refresh_target(list(id = "", key = ""))
    figure_inset_preview_cache(list())
    figure_loaded_plots(list())
    figure_loaded_exports(list())
    figure_loaded_assets(list())
    figure_external_assets(list())
    figure_requested_external_assets(list())
    clear_figure_svg_cache()
    clear_figure_geometry_cache()
    clear_figure_geometry_source_state()
    figure_requested_ids(character(0))
    figure_plot_overrides(list())
    figure_selected_row(1L)
    figure_selected_graph("")
    figure_selected_panel_key("")

    if (is.null(saved) || !is.list(saved)) {
      figure_layout_initialized(FALSE)
      figure_layout_state(figure_default_layout_state())
      figure_override_drafts(list())
      figure_requested_width(1600)
      figure_requested_height(1000)
      figure_requested_gap_x(12)
      figure_requested_gap_y(12)
      figure_requested_size_mode("auto")
      figure_requested_size_basis("panel_legend")
      figure_requested_title_align("none")
      figure_requested_layout_mode("row")
      figure_requested_autofit_policy("live")
      figure_autofit_revision(0L)
      figure_geometry_revision(0L)
      figure_reorder_undo(NULL)
      figure_requested_free_padding(24)
      figure_control_restore_seed(list(width = 1600, height = 1000, gap_x = 12, gap_y = 12, mode = "auto", basis = "panel_legend", title_align = "none", layout_mode = "row", autofit_policy = "live"))
      updateSelectInput(session, "figure_size_mode", selected = "auto")
      updateSelectInput(session, "figure_size_basis", selected = "panel_legend")
      updateSelectInput(session, "figure_title_align", selected = "none")
      updateSelectInput(session, "figure_layout_mode", selected = "row")
      updateSelectInput(session, "figure_autofit_policy", selected = "live")
      updateNumericInput(session, "figure_canvas_width", value = 1600)
      updateNumericInput(session, "figure_canvas_height", value = 1000)
      updateNumericInput(session, "figure_gap_x", value = 12)
      updateNumericInput(session, "figure_gap_y", value = 12)
      bump_figure_layout_ui()
      return(invisible(FALSE))
    }

    cw <- suppressWarnings(as.numeric(saved$canvas_width %||% 1600)[1])
    ch <- suppressWarnings(as.numeric(saved$canvas_height %||% 1000)[1])
    gx <- suppressWarnings(as.numeric(saved$gap_x %||% 12)[1])
    gy <- suppressWarnings(as.numeric(saved$gap_y %||% 12)[1])
    # Legacy Projects predate content-driven sizing.  v3.3.67 Projects can be
    # recognized by their per-Graph target sizes, so those migrate naturally to
    # Auto fit; older Projects without Graph sizes preserve Fixed behavior.
    if (is.null(saved$size_mode)) {
      legacy_layout <- saved$layout %||% list()
      has_graph_size <- any(vapply(legacy_layout, function(row) {
        any(vapply(row$cells %||% list(), function(cell) {
          gw0 <- suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)[1])
          gh0 <- suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)[1])
          (is.finite(gw0) && gw0 > 0) || (is.finite(gh0) && gh0 > 0)
        }, logical(1)))
      }, logical(1)))
      size_mode <- if (has_graph_size) "auto" else "fixed"
    } else {
      size_mode <- as.character(saved$size_mode)[1]
    }
    if (!size_mode %in% c("auto", "fixed")) size_mode <- "fixed"
    # v3.80.7 migration: old panel_auto/plot/facet/axis/axis_legend values are
    # normalized once at the Project boundary into the explicit contract.
    size_basis <- figure_normalize_alignment_basis(saved$size_basis %||% "panel_legend")
    # Graph-title alignment was a workaround for label drift. Panel labels now
    # have their own Figure-owned band/anchor, so old title alignment is retired.
    title_align <- "none"
    layout_mode <- as.character(saved$layout_mode %||% "row")[1]
    if (!layout_mode %in% c("row", "free")) layout_mode <- "row"
    autofit_policy <- as.character(saved$autofit_policy %||% "live")[1]
    if (!autofit_policy %in% c("live", "manual", "lock")) autofit_policy <- "live"
    free_padding <- suppressWarnings(as.numeric(saved$free_canvas_padding %||% 24)[1])
    if (!is.finite(free_padding)) free_padding <- 24
    free_padding <- min(max(free_padding, 0), 500)
    external_assets <- saved$external_assets %||% list()
    if (!is.list(external_assets)) external_assets <- list()
    if (!is.finite(cw)) cw <- 1600
    if (!is.finite(ch)) ch <- 1000
    if (!is.finite(gx)) gx <- 12
    if (!is.finite(gy)) gy <- 12
    cw <- min(max(cw, 300), 6000)
    ch <- min(max(ch, 300), 6000)
    gx <- min(max(gx, 0), 300)
    gy <- min(max(gy, 0), 300)

    layout <- saved$layout %||% figure_default_layout_state()
    # v3.80.8: Project payload stores the Figure-wide column vector explicitly.
    # Older Projects migrate from their per-cell width values at this boundary.
    saved_column_ratios <- saved$column_ratios %||% attr(layout, "column_ratios", exact = TRUE)
    if (length(saved_column_ratios)) layout <- figure_set_shared_column_ratios(layout, saved_column_ratios)
    saved_diag <- figure_layout_diag(layout)
    diag_log(
      "FIGURE-RESTORE",
      paste0(
        "saved_rows=", saved_diag$rows,
        " saved_cells=", paste(saved_diag$keys, collapse = ",")
      )
    )
    layout <- figure_reindex_layout(layout)
    for (r in seq_along(layout)) {
      for (c in seq_along(layout[[r]]$cells)) {
        source_type <- as.character(layout[[r]]$cells[[c]]$source_type %||% "internal_graph")
        old_id <- as.character(layout[[r]]$cells[[c]]$source_id %||% layout[[r]]$cells[[c]]$id %||% "")
        new_id <- ""
        new_type <- source_type
        if (identical(source_type, "internal_graph") && nzchar(old_id) && old_id %in% names(id_map)) {
          new_id <- as.character(id_map[[old_id]])
        } else if (identical(source_type, "external_asset") && old_id %in% names(external_assets)) {
          new_id <- old_id
        } else {
          new_type <- "internal_graph"
        }
        layout[[r]]$cells[[c]]$id <- new_id
        layout[[r]]$cells[[c]]$source_type <- new_type
        layout[[r]]$cells[[c]]$source_id <- new_id
      }
    }
    layout <- figure_sanitize_layout(layout, meta, auto_fill = FALSE, external_assets = external_assets)
    restored_diag <- figure_layout_diag(layout)
    diag_log(
      "FIGURE-RESTORE",
      paste0(
        "restored_rows=", restored_diag$rows,
        " restored_cells=", paste(restored_diag$keys, collapse = ",")
      )
    )

    old_overrides <- saved$overrides %||% list()
    if (!is.list(old_overrides)) old_overrides <- list()
    new_overrides <- list()
    if (length(old_overrides) && length(names(old_overrides))) {
      for (old_id in names(old_overrides)) {
        new_id <- if (old_id %in% names(id_map)) as.character(id_map[[old_id]]) else if (old_id %in% names(external_assets)) old_id else ""
        if (!nzchar(new_id)) next
        old_ov <- old_overrides[[old_id]]
        if (!is.list(old_ov)) old_ov <- list()
        if (is.list(old_ov$inset)) {
          ins_id <- as.character(old_ov$inset$source_id %||% "")[1]
          if (nzchar(ins_id) && ins_id %in% names(id_map)) {
            old_ov$inset$source_id <- as.character(id_map[[ins_id]])
            old_ov$inset$source_type <- "internal_graph"
          } else if (nzchar(ins_id) && ins_id %in% names(external_assets)) {
            old_ov$inset$source_type <- "external_asset"
          } else if (nzchar(ins_id)) {
            old_ov$inset$enabled <- FALSE
            old_ov$inset$source_id <- ""
          }
        }
        new_overrides[[new_id]] <- modifyList(figure_default_override(new_id), old_ov)
      }
    }

    # alpha3 migration: alpha1/alpha2 stored Panel label style on the source
    # override.  Move those legacy values into the currently occupied Slot and
    # remove them from source-owned override state.  Internal Graph duplication
    # is still forbidden, so the legacy source -> Slot mapping is unambiguous.
    legacy_slot_fields <- c(
      "label_size", "top_gutter", "label_mode", "label_anchor",
      "label_x_offset", "label_y_offset", "label_x", "label_y"
    )
    for (rr in seq_along(layout)) {
      for (cc in seq_along(layout[[rr]]$cells)) {
        cell <- layout[[rr]]$cells[[cc]]
        sid <- as.character(cell$source_id %||% cell$id %||% "")[1]
        if (!nzchar(sid) || is.null(new_overrides[[sid]])) next
        old_ov <- new_overrides[[sid]]
        # Existing slot values from v8+ remain authoritative.  For legacy
        # projects, reindexed defaults indicate no slot-owned style existed.
        saved_version <- suppressWarnings(as.integer(saved$version %||% 0L)[1])
        if (!is.finite(saved_version)) saved_version <- 0L
        if (saved_version < 8L) {
          legacy_label <- as.character(old_ov$panel_label %||% "")[1]
          if (!is.na(legacy_label) && nzchar(legacy_label) && !nzchar(as.character(cell$panel_label %||% "")[1])) {
            cell$panel_label <- legacy_label
            cell$panel_label_auto <- FALSE
          }
          for (nm in legacy_slot_fields) {
            if (!is.null(old_ov[[nm]])) cell[[nm]] <- old_ov[[nm]]
          }
          layout[[rr]]$cells[[cc]] <- figure_make_cell(
            rr, cc, id = sid, width = cell$width,
            source_type = cell$source_type, source_id = sid,
            graph_width = cell$graph_width, graph_height = cell$graph_height,
            free_x = cell$free_x, free_y = cell$free_y,
            free_width = cell$free_width, free_height = cell$free_height,
            z_index = cell$z_index,
            panel_label = cell$panel_label,
            panel_label_auto = cell$panel_label_auto,
            label_size = cell$label_size, top_gutter = cell$top_gutter,
            label_mode = cell$label_mode, label_anchor = cell$label_anchor,
            label_x_offset = cell$label_x_offset, label_y_offset = cell$label_y_offset,
            label_x = cell$label_x, label_y = cell$label_y
          )
        }
        new_overrides[[sid]] <- figure_strip_slot_label_fields_from_override(old_ov)
      }
    }

    # F1-5p: restore Figure-owned editable GraphState snapshots independently
    # from source GraphState. Old Projects simply have none; in that case the
    # persisted Figure SVG remains viewable but editing is gated until the user
    # explicitly refreshes that Panel from its source Graph.
    saved_edit_states <- saved$editable_graph_states %||% list()
    mapped_edit_states <- list()
    if (is.list(saved_edit_states) && length(saved_edit_states)) {
      valid_layout_internal <- unique(unlist(lapply(layout, function(row) {
        vapply(row$cells %||% list(), function(cell) {
          if (identical(as.character(cell$source_type %||% "internal_graph"), "internal_graph")) as.character(cell$id %||% "") else ""
        }, character(1))
      }), use.names = FALSE))
      valid_layout_internal <- valid_layout_internal[nzchar(valid_layout_internal)]
      for (old_id in names(saved_edit_states)) {
        new_id <- if (old_id %in% names(id_map)) as.character(id_map[[old_id]]) else if (old_id %in% valid_layout_internal) old_id else ""
        if (!nzchar(new_id) || !new_id %in% valid_layout_internal) next
        st_edit <- saved_edit_states[[old_id]]
        if (is.list(st_edit)) {
          mapped_edit_states[[new_id]] <- graph_state_prepare_replay_snapshot(
            shared_style_normalize_graph_state(st_edit)
          )
        }
      }
    }
    figure_edit_states(mapped_edit_states)
    if (length(mapped_edit_states)) {
      diag_log("FIGURE-EDIT-RESTORE", paste0("editable_states=", length(mapped_edit_states), " ids={", paste(names(mapped_edit_states), collapse=","), "}"))
    }

    # Mark initialized before publishing layout so the metadata sanitizer does
    # not auto-fill restored blank cells with different Graphs.
    figure_layout_initialized(TRUE)
    figure_layout_state(layout)
    figure_override_drafts(new_overrides)
    figure_requested_width(cw)
    figure_requested_height(ch)
    figure_requested_gap_x(gx)
    figure_requested_gap_y(gy)
    figure_requested_size_mode(size_mode)
    figure_requested_size_basis(size_basis)
    figure_requested_title_align(title_align)
    figure_requested_layout_mode(layout_mode)
    figure_requested_autofit_policy(autofit_policy)
    figure_autofit_revision(isolate(figure_autofit_revision()) + 1L)
    figure_reorder_undo(NULL)
    figure_requested_free_padding(free_padding)
    figure_external_assets(external_assets)
    figure_requested_external_assets(external_assets)

    # Publish the restored logical layout to the Figure renderer immediately.
    # Previously the renderer waited for a later reactive pass to copy
    # figure_layout_state() into figure_requested_layout(). During Project
    # restoration that left a window where the reset one-row layout could be
    # rendered instead of the persisted multi-row layout.
    restored_ids <- unique(unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) {
        if (identical(as.character(cell$source_type %||% "internal_graph"), "internal_graph")) as.character(cell$id %||% "") else ""
      }, character(1))
    }), use.names = FALSE))
    restored_ids <- restored_ids[nzchar(restored_ids)]
    figure_requested_layout(layout)
    figure_requested_ids(restored_ids)
    figure_requested_overrides(new_overrides)

    figure_control_restore_seed(list(width = cw, height = ch, gap_x = gx, gap_y = gy, mode = size_mode, basis = size_basis, title_align = title_align, layout_mode = layout_mode, autofit_policy = autofit_policy))
    updateSelectInput(session, "figure_size_mode", selected = size_mode)
    updateSelectInput(session, "figure_size_basis", selected = size_basis)
    updateSelectInput(session, "figure_title_align", selected = title_align)
    updateSelectInput(session, "figure_layout_mode", selected = layout_mode)
    updateSelectInput(session, "figure_autofit_policy", selected = autofit_policy)
    updateNumericInput(session, "figure_canvas_width", value = cw)
    updateNumericInput(session, "figure_canvas_height", value = ch)
    updateNumericInput(session, "figure_gap_x", value = gx)
    updateNumericInput(session, "figure_gap_y", value = gy)
    bump_figure_layout_ui()

    requested_diag <- figure_layout_diag(isolate(figure_requested_layout()))
    diag_log(
      "FIGURE-RESTORE",
      paste0(
        "published_rows=", requested_diag$rows,
        " published_cells=", paste(requested_diag$keys, collapse = ",")
      )
    )

    # Verify once after the restore flush. If another initialization observer
    # published the temporary default layout, restore the persisted layout
    # again rather than silently losing rows/panels. This is event/flush based
    # (not a fixed delay) and only acts on an actual mismatch.
    expected_rows <- restored_diag$rows
    expected_keys <- restored_diag$keys
    restored_layout <- layout
    restored_overrides <- new_overrides
    session$onFlushed(function() {
      cur <- isolate(figure_layout_state())
      cur_diag <- figure_layout_diag(cur)
      req_diag <- figure_layout_diag(isolate(figure_requested_layout()))
      state_ok <- identical(cur_diag$rows, expected_rows) && identical(cur_diag$keys, expected_keys)
      requested_ok <- identical(req_diag$rows, expected_rows) && identical(req_diag$keys, expected_keys)
      diag_log(
        "FIGURE-RESTORE",
        paste0(
          "postflush_state_rows=", cur_diag$rows,
          " requested_rows=", req_diag$rows,
          " expected_rows=", expected_rows
        )
      )
      if (!state_ok || !requested_ok) {
        diag_log("FIGURE-RESTORE", "postflush mismatch detected; re-publishing persisted layout")
        figure_layout_initialized(TRUE)
        figure_layout_state(restored_layout)
        figure_override_drafts(restored_overrides)
        figure_requested_layout(restored_layout)
        figure_requested_ids(restored_ids)
        figure_requested_overrides(restored_overrides)
        bump_figure_layout_ui()
      }
    }, once = TRUE)

    invisible(TRUE)
  }

  build_project <- function() {
    # Close the user-edit/save races before serialization.  First merge each
    # READY module's in-memory Statistics recipe collection into its canonical
    # GraphState; then commit the active editor's complete state so the selected
    # Analysis' currently visible inputs win over the in-memory recipe snapshot.
    # Computed Statistics output is never serialized.
    try(flush_active_graph_to_registry(), silent = TRUE)

    # Commit the currently visible Figure Inspector values before serialising. In most
    # interactions its observer has already done this, but this closes the small
    # race where the user edits a field and immediately saves the Project.
    try(capture_current_figure_override(), silent = TRUE)
    meta <- isolate(graph_meta())
    graphs <- vector("list", nrow(meta))
    names(graphs) <- meta$id

    for (i in seq_len(nrow(meta))) {
      id <- meta$id[i]
      graphs[[id]] <- list(
        name = meta$name[i],
        state = graph_state_for_save(id)
      )
    }

    list(
      version = "3.4.0-alpha6-a4-semantic-fix",
      app = "ggplot GUI",
      project_uuid = {
        uo <- shiny::isolate(project_uuid_save_override())
        if (!is.null(uo) && valid_project_uuid(uo)) as.character(uo) else shiny::isolate(project_uuid())
      },
      project_name = {
        nm_override <- shiny::isolate(project_name_save_override())
        if (!is.null(nm_override) && nzchar(as.character(nm_override))) {
          as.character(nm_override)
        } else {
          shiny::isolate(input$project_name)
        }
      },
      active_graph = selected_graph_id(),
      project_options = list(
        remember_save_destination = isTRUE(shiny::isolate(project_remember_pref()))
      ),
      shared_style = list(
        schema_version = 1L,
        library = shared_style_normalize_library(shiny::isolate(shared_style_library())),
        figure_sync = isTRUE(shiny::isolate(figure_shared_style_sync()))
      ),
      graphs = graphs,
      figure = figure_state_for_save()
    )
  }

  project_filename <- function() {
    nm_override <- shiny::isolate(project_name_save_override())
    project_name_now <- if (!is.null(nm_override) &&
                            nzchar(as.character(nm_override))) {
      as.character(nm_override)
    } else {
      shiny::isolate(input$project_name)
    }

    paste0(
      safe_name(
        project_name_now,
        paste0("ggplot_project_", Sys.Date())
      ),
      ".ggplotpack"
    )
  }

  project_bundle_filename <- function() project_filename()

  # Graph SVG package records were retired in v3.73.2.18. Figure snapshot
  # records below remain explicit project assets.


  collect_figure_snapshot_preview_records <- function() {
    meta_now <- isolate(graph_meta())
    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    assets <- isolate(figure_loaded_assets())
    persisted <- isolate(figure_persisted_previews())
    ovs <- isolate(figure_requested_overrides())
    out <- list()

    referenced_ids <- figure_referenced_graph_ids()
    for (id in intersect(as.character(meta_now$id %||% character(0)), referenced_ids)) {
      # Preserve Figure's explicit-refresh semantics across Project save/load.
      # v3.72: unreferenced historical Figure snapshots are not serialized; a
      # later re-add must import the current Graph rather than resurrect cache.
      # Only an in-session Figure snapshot (or an older persisted Figure
      # snapshot) is eligible here. A newer live Graph preview must NOT silently
      # replace a Figure source that the user has not explicitly reloaded.
      p <- assets[[id]]$plot %||% plots[[id]]
      ex <- assets[[id]]$meta %||% exports[[id]]
      if (is.null(p)) {
        old <- persisted[[id]]
        if (is.list(old) && nzchar(old$svg %||% "")) out[[id]] <- old
        next
      }
      if (!is.list(ex)) ex <- list(panel_width_px = 600, panel_height_px = 600, reference_res = 120)

      ov <- figure_override_for(id, ovs)
      # F1-5e: mirror the live Figure layer preparation when serialising a
      # Figure snapshot.  For detached/free legends, persist three coordinated
      # artifacts: the stable source-side anchor SVG/geometry, a legend-free
      # owner Graph body, and the tight guide-box legend asset.  This lets a
      # cache-first Project restore reproduce the final Figure immediately,
      # without waiting for the source Graph module to hydrate.
      render_ov <- figure_layer_source_override(ov)
      rendered <- tryCatch(figure_plot_for_scale(p, render_ov, ex, 1), error = function(e) NULL)
      if (is.null(rendered) || is.null(rendered$plot)) next
      svg <- tryCatch(
        figure_plot_svg_text(rendered$plot, rendered$width, rendered$height, ex$reference_res %||% 120),
        error = function(e) ""
      )
      if (!nzchar(svg %||% "")) next

      body_svg <- ""
      body_meta <- NULL
      legend_asset <- NULL
      if (figure_legend_is_detached(ov)) {
        legend_plot <- figure_apply_detached_legend_background(rendered$plot, ov)
        legend_asset <- tryCatch(
          figure_legend_grob_asset(
            legend_plot,
            reference_res = ex$reference_res %||% 120,
            preferred_origin = figure_legend_source_origin(ov)
          ),
          error = function(e) NULL
        )
        if (figure_legend_asset_is_valid(legend_asset)) {
          body_ov <- render_ov
          body_ov$legend <- "none"
          body_rendered <- tryCatch(figure_plot_for_scale(p, body_ov, ex, 1), error = function(e) NULL)
          if (is.list(body_rendered) && !is.null(body_rendered$plot)) {
            body_svg <- tryCatch(
              figure_plot_svg_text(
                body_rendered$plot, body_rendered$width, body_rendered$height,
                ex$reference_res %||% 120
              ),
              error = function(e) ""
            )
            if (nzchar(body_svg %||% "")) {
              body_meta <- list(
                width = body_rendered$width,
                height = body_rendered$height,
                panel_left = body_rendered$panel_left,
                panel_top = body_rendered$panel_top,
                panel_width = body_rendered$panel_width,
                panel_height = body_rendered$panel_height,
                panel_bbox = body_rendered$panel_bbox,
                facet_bbox = body_rendered$facet_bbox,
                axis_outer_bbox = body_rendered$axis_outer_bbox,
                content_outer_bbox = body_rendered$content_outer_bbox,
                title_bbox = body_rendered$title_bbox,
                legend_bbox = body_rendered$legend_bbox,
                legend_visual_bbox = body_rendered$legend_visual_bbox %||% body_rendered$legend_bbox,
                legend_outside_bbox = body_rendered$legend_outside_bbox,
                legend_outside_visual_bbox = body_rendered$legend_outside_visual_bbox %||% body_rendered$legend_outside_bbox,
                legend_state = body_rendered$legend_state %||% "unknown",
                geometry_source = body_rendered$geometry_source %||% "unknown",
                reference_res = ex$reference_res %||% 120
              )
            }
          }
        } else {
          legend_asset <- NULL
          diag_log(
            "FIGURE-LEGEND-DETACH-FALLBACK",
            paste0("save source_origin=", figure_legend_source_origin(ov), " reason=legend-asset-unavailable"),
            id=id
          )
        }
      }

      out[[id]] <- list(
        svg = svg,
        body_svg = body_svg,
        body_meta = body_meta,
        legend_svg = if (is.list(legend_asset)) legend_asset$svg %||% "" else "",
        legend_width = if (is.list(legend_asset)) legend_asset$width %||% NA_real_ else NA_real_,
        legend_height = if (is.list(legend_asset)) legend_asset$height %||% NA_real_ else NA_real_,
        meta = list(
          width = rendered$width,
          height = rendered$height,
          panel_left = rendered$panel_left,
          panel_top = rendered$panel_top,
          panel_width = rendered$panel_width,
          panel_height = rendered$panel_height,
          panel_bbox = rendered$panel_bbox,
          facet_bbox = rendered$facet_bbox,
          axis_outer_bbox = rendered$axis_outer_bbox,
          content_outer_bbox = rendered$content_outer_bbox,
          title_bbox = rendered$title_bbox,
          legend_bbox = rendered$legend_bbox,
          legend_visual_bbox = rendered$legend_visual_bbox %||% rendered$legend_bbox,
          legend_outside_bbox = rendered$legend_outside_bbox,
          legend_outside_visual_bbox = rendered$legend_outside_visual_bbox %||% rendered$legend_outside_bbox,
          legend_state = rendered$legend_state %||% "unknown",
          geometry_source = rendered$geometry_source %||% "unknown",
          reference_res = ex$reference_res %||% 120
        )
      )
    }
    out
  }

  write_project_package <- function(file) {
    root <- tempfile("ggplot_project_")
    dir.create(root, recursive = TRUE, showWarnings = FALSE)
    on.exit(unlink(root, recursive = TRUE, force = TRUE), add = TRUE)
    dir.create(file.path(root, "preview"), recursive = TRUE, showWarnings = FALSE)
    dir.create(file.path(root, "assets"), recursive = TRUE, showWarnings = FALSE)

    proj_obj <- build_project()
    saveRDS(proj_obj, file.path(root, "project.rds"), compress = "gzip", version = 3)
    # v3.73.2.18: GraphState is the only persisted Graph authority. Graph SVG
    # previews are no longer generated or serialized; Figure snapshots remain
    # explicit point-in-time assets and continue to be packaged.
    previews <- list()
    figure_previews <- collect_figure_snapshot_preview_records()
    inset_previews <- collect_figure_inset_preview_records()
    diag_log(
      "PACK-SAVE",
      paste0(
        "graphs=", length(proj_obj$graphs %||% list()),
        " graph_preview_records=", length(previews),
        " figure_preview_records=", length(figure_previews),
        if (length(previews)) paste0(" graph_ids=", paste(names(previews), collapse = ",")) else "",
        if (length(figure_previews)) paste0(" figure_ids=", paste(names(figure_previews), collapse = ",")) else ""
      )
    )
    # Manifest v5 adds independent Inset snapshot assets. The empty
    # `previews` field is retained as a compatibility placeholder for readers of
    # older packages; no new Graph SVG files are written.
    manifest <- list(version = 5L, previews = list(), figure_previews = list(),
                     figure_inset_previews = write_figure_inset_preview_entries(root, inset_previews))
    if (length(figure_previews)) {
      for (id in names(figure_previews)) {
        rec <- figure_previews[[id]]
        if (!nzchar(rec$svg %||% "")) next
        fn <- paste0("figure_", safe_name(id, id), ".svg")
        out_svg <- file.path(root, "preview", fn)
        writeLines(rec$svg, out_svg, useBytes = TRUE)
        diag_log(
          "PACK-SAVE",
          paste0("write Figure snapshot file=", fn, " chars=", nchar(rec$svg %||% ""), " bytes=", file.info(out_svg)$size),
          id = id
        )
        ent <- list(file = fn, meta = rec$meta %||% list())

        if (nzchar(rec$body_svg %||% "") && is.list(rec$body_meta)) {
          body_fn <- paste0("figure_body_", safe_name(id, id), ".svg")
          body_path <- file.path(root, "preview", body_fn)
          writeLines(rec$body_svg, body_path, useBytes = TRUE)
          ent$body <- list(file = body_fn, meta = rec$body_meta)
          diag_log(
            "PACK-SAVE",
            paste0("write Figure body file=", body_fn, " chars=", nchar(rec$body_svg %||% ""), " bytes=", file.info(body_path)$size),
            id = id
          )
        }

        if (nzchar(rec$legend_svg %||% "")) {
          legend_fn <- paste0("figure_legend_", safe_name(id, id), ".svg")
          legend_path <- file.path(root, "preview", legend_fn)
          writeLines(rec$legend_svg, legend_path, useBytes = TRUE)
          ent$legend <- list(
            file = legend_fn,
            width = rec$legend_width %||% NA_real_,
            height = rec$legend_height %||% NA_real_
          )
          diag_log(
            "PACK-SAVE",
            paste0(
              "write Figure legend file=", legend_fn,
              " chars=", nchar(rec$legend_svg %||% ""),
              " size=", round(suppressWarnings(as.numeric(rec$legend_width %||% NA_real_)[1]), 1),
              "x", round(suppressWarnings(as.numeric(rec$legend_height %||% NA_real_)[1]), 1),
              " bytes=", file.info(legend_path)$size
            ),
            id = id
          )
        }

        manifest$figure_previews[[id]] <- ent
      }
    }
    saveRDS(manifest, file.path(root, "preview", "manifest.rds"), compress = "gzip", version = 3)
    diag_log(
      "PACK-SAVE",
      paste0("manifest graph_previews=", length(manifest$previews),
             " figure_previews=", length(manifest$figure_previews))
    )
    writeLines(
      c(
        "This folder is reserved for external Figure assets.",
        "Future versions may place imported SVG/raster/inset sources here."
      ),
      file.path(root, "assets", "README.txt"),
      useBytes = TRUE
    )

    oldwd <- getwd()
    on.exit(setwd(oldwd), add = TRUE)
    setwd(root)
    members <- list.files(".", recursive = TRUE, all.files = FALSE, no.. = TRUE)
    if (!length(members)) stop("Project package is empty")
    zip::zipr(zipfile = normalizePath(file, mustWork = FALSE), files = members)
  }

  output$download_project_package <- downloadHandler(
    filename = function() project_bundle_filename(),
    contentType = "application/zip",
    content = function(file) write_project_package(file)
  )
  outputOptions(output, "download_project_package", suspendWhenHidden = FALSE)

  output$download_project_all <- downloadHandler(
    filename = function() project_filename(),
    contentType = "application/zip",
    content = function(file) {
      diag_log("PROJECT-SAVE", paste0("format=ggplotpack filename=", project_filename()))
      write_project_package(file)
    }
  )

  # Browser側のFile System Access APIが取得するための非表示endpoint。
  # display:none の中にあっても必ず有効なRDSを生成できるよう、
  # suspendWhenHidden=FALSE を明示する。
  output$download_project_overwrite_payload <- downloadHandler(
    filename = function() project_filename(),
    contentType = "application/zip",
    content = function(file) {
      diag_log("PROJECT-SAVE", paste0("format=ggplotpack filename=", project_filename()))
      write_project_package(file)
    }
  )

  outputOptions(
    output,
    "download_project_overwrite_payload",
    suspendWhenHidden = FALSE
  )
  outputOptions(
    output,
    "download_project_all",
    suspendWhenHidden = FALSE
  )

  observeEvent(input$save_project_as_all, {
    filename_now <- project_filename()
    project_name_now <- as.character(input$project_name %||% "MyProject")
    old_uuid <- isolate(project_uuid())
    candidate_uuid <- new_project_uuid()
    project_uuid_save_override(candidate_uuid)
    remember_now <- isTRUE(project_remember_pref())

    session$onFlushed(function() {
      session$sendCustomMessage(
        "prepare-project-save-as",
        list(
          fallbackLinkId = "download_project_all",
          filename = filename_now,
          projectName = project_name_now,
          projectKey = candidate_uuid,
          oldProjectKey = old_uuid,
          remember = remember_now
        )
      )
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$project_save_as_target, {
    tg <- input$project_save_as_target
    if (is.null(tg)) return()

    selected_name <- as.character(tg$projectName %||% "")
    selected_uuid <- as.character(tg$projectKey %||% "")
    if (!nzchar(selected_name)) return()
    if (!valid_project_uuid(selected_uuid)) selected_uuid <- isolate(project_uuid_save_override())
    if (!valid_project_uuid(selected_uuid)) selected_uuid <- new_project_uuid()

    project_uuid_save_override(selected_uuid)
    project_name_save_override(selected_name)
    updateTextInput(session, "project_name", value = selected_name)
    old_uuid <- isolate(project_uuid())
    remember_now <- isTRUE(tg$remember)

    session$onFlushed(function() {
      session$sendCustomMessage(
        "commit-project-save-as",
        list(
          linkId = "download_project_overwrite_payload",
          filename = paste0(safe_name(selected_name, selected_name), ".ggplotpack"),
          projectName = selected_name,
          projectKey = selected_uuid,
          oldProjectKey = old_uuid,
          remember = remember_now
        )
      )
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$overwrite_project_all, {
    filename_now <- project_filename()
    project_key_now <- isolate(project_uuid())
    remember_now <- isTRUE(project_remember_pref())

    session$onFlushed(function() {
      session$sendCustomMessage(
        "overwrite-project-file",
        list(
          linkId = "download_project_overwrite_payload",
          filename = filename_now,
          projectKey = project_key_now,
          remember = remember_now
        )
      )
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$project_save_destination_available, {
    z <- input$project_save_destination_available
    if (is.null(z)) return()
    current_key <- isolate(project_uuid())
    response_key <- as.character(z$projectKey %||% "")
    if (nzchar(response_key) && !identical(response_key, current_key)) return()
    project_save_destination_available(isTRUE(z$available) && isTRUE(project_remember_pref()))
  }, ignoreInit = TRUE)

  observeEvent(input$project_remember_manual_state, {
    z <- input$project_remember_manual_state
    if (is.null(z)) return()
    remember_now <- isTRUE(z$value)
    project_remember_pref(remember_now)
    project_key <- isolate(project_uuid())
    if (remember_now) {
      session$sendCustomMessage("check-project-save-destination", list(projectKey = project_key, remember = TRUE))
    } else {
      project_save_destination_available(FALSE)
      session$sendCustomMessage("forget-project-save-destination", list(projectKey = project_key))
    }
  }, ignoreInit = TRUE)

  observeEvent(input$remember_project_save_destination, {
    remember_now <- isTRUE(input$remember_project_save_destination)
    project_remember_pref(remember_now)
    project_key <- isolate(project_uuid())
    if (remember_now) {
      session$sendCustomMessage("check-project-save-destination", list(projectKey = project_key, remember = TRUE))
    } else {
      project_save_destination_available(FALSE)
      session$sendCustomMessage("forget-project-save-destination", list(projectKey = project_key))
    }
  }, ignoreInit = FALSE)

  observeEvent(input$project_save_as_status, {
    st <- input$project_save_as_status
    if (is.null(st)) return()

    pending_uuid <- isolate(project_uuid_save_override())
    project_name_save_override(NULL)
    project_uuid_save_override(NULL)

    if (isTRUE(st$ok)) {
      saved_uuid <- as.character(st$projectKey %||% pending_uuid %||% "")
      if (valid_project_uuid(saved_uuid)) project_uuid(saved_uuid)
      saved_project_name <- as.character(st$projectName %||% "")
      if (nzchar(saved_project_name)) {
        updateTextInput(session, "project_name", value = saved_project_name)
        session$sendCustomMessage(
          "set-project-name-input",
          list(name = saved_project_name)
        )
      }

      if (isTRUE(st$remembered)) {
        project_remember_pref(TRUE)
        project_save_destination_available(TRUE)
      } else {
        # Session overwrite works, but persistent destination storage remains unavailable
        # because "保存先を記憶する" is OFF.
        project_save_destination_available(FALSE)
      }

      msg <- paste0(
        "Projectを保存しました: ",
        st$name %||% project_filename()
      )
      if (isTRUE(st$remembered)) {
        msg <- paste0(msg, "（保存先を記憶）")
      }

      showNotification(
        msg,
        type = "message",
        duration = 3
      )

    } else if (isTRUE(st$fallback)) {
      fallback_uuid <- as.character(st$projectKey %||% pending_uuid %||% "")
      if (valid_project_uuid(fallback_uuid)) project_uuid(fallback_uuid)
      showNotification(
        st$message %||% "通常の保存へ切り替えました。",
        type = "warning",
        duration = 4
      )
    } else if (isTRUE(st$cancelled)) {
      invisible(NULL)
    } else {
      showNotification(
        paste0(
          "Projectの保存に失敗しました: ",
          st$message %||% "不明なエラー"
        ),
        type = "error",
        duration = 5
      )
    }
  }, ignoreInit = TRUE)

  observeEvent(input$project_overwrite_status, {
    st <- input$project_overwrite_status
    if (is.null(st)) return()

    if (isTRUE(st$ok)) {
      if (isTRUE(st$remembered)) {
        project_remember_pref(TRUE)
        project_save_destination_available(TRUE)
      }

      msg <- paste0(
        "Projectを上書き保存しました: ",
        st$name %||% project_filename()
      )
      if (isTRUE(st$remembered)) {
        msg <- paste0(msg, "（保存先を記憶）")
      }
      showNotification(
        msg,
        type = "message",
        duration = 2
      )
    } else if (isTRUE(st$fallback)) {
      showNotification(
        st$message %||% "通常の保存へ切り替えました。",
        type = "warning",
        duration = 4
      )
    } else {
      showNotification(
        paste0("Projectの上書き保存に失敗しました: ", st$message %||% "不明なエラー"),
        type = "error",
        duration = 5
      )
    }
  }, ignoreInit = TRUE)


  project_read_error <- reactiveVal(NULL)

  read_project_file <- function(path) {
    project_read_error(NULL)
    project_bundle_pending_previews(list())
    project_bundle_pending_inset_previews(list())
    project_bundle_pending_graph_previews(list())
    diag_log("PACK", paste0("read_project_file path=", basename(path), " bytes=", tryCatch(file.info(path)$size, error = function(e) NA)))

    # v3.3.54: packaged Project may contain files either at archive root or
    # below one enclosing folder. Discover project.rds/manifest by basename
    # instead of assuming one fixed ZIP layout.
    zip_list <- tryCatch(
      utils::unzip(path, list = TRUE),
      error = function(e) {
        diag_log("PACK-ERROR", paste0("zip list failed: ", conditionMessage(e)))
        NULL
      }
    )
    if (is.data.frame(zip_list)) {
      zn <- as.character(zip_list$Name %||% character(0))
      diag_log(
        "PACK",
        paste0(
          "zip entries=", length(zn),
          " project.rds candidates=", sum(basename(zn) == "project.rds"),
          " manifest candidates=", sum(basename(zn) == "manifest.rds"),
          " svg candidates=", sum(grepl("\\.svg$", zn, ignore.case = TRUE))
        )
      )
    }

    if (is.data.frame(zip_list) && any(basename(as.character(zip_list$Name)) == "project.rds")) {
      exdir <- tempfile("ggplotpack_")
      dir.create(exdir, recursive = TRUE, showWarnings = FALSE)
      extract_members <- as.character(zip_list$Name %||% character(0))
      legacy_render_members <- extract_members[
        grepl("^figure_render_.*\\.rds$", basename(extract_members), ignore.case = TRUE)
      ]
      if (length(legacy_render_members)) {
        extract_members <- setdiff(extract_members, legacy_render_members)
        diag_log(
          "PACK",
          paste0("skip legacy Figure render RDS during extraction count=", length(legacy_render_members))
        )
      }
      ok <- tryCatch({
        utils::unzip(path, files = extract_members, exdir = exdir)
        TRUE
      }, error = function(e) {
        diag_log("PACK-ERROR", paste0("unzip failed: ", conditionMessage(e)))
        FALSE
      })
      if (isTRUE(ok)) {
        extracted <- list.files(exdir, recursive = TRUE, full.names = TRUE, all.files = FALSE)
        project_candidates <- extracted[basename(extracted) == "project.rds"]
        diag_log(
          "PACK",
          paste0("extracted files=", length(extracted), " project candidates=", length(project_candidates))
        )
        if (length(project_candidates)) {
          project_path <- project_candidates[[1]]
          package_root <- dirname(project_path)
          diag_log("PACK", paste0("project.rds=", project_path, " package_root=", package_root))
          cfg <- tryCatch(
            readRDS(project_path),
            error = function(e) {
              diag_log("PACK-ERROR", paste0("project.rds read failed: ", conditionMessage(e)))
              NULL
            }
          )
          if (!is.null(cfg)) {
            manifest_candidates <- c(
              file.path(package_root, "preview", "manifest.rds"),
              extracted[basename(extracted) == "manifest.rds"]
            )
            manifest_candidates <- unique(manifest_candidates[file.exists(manifest_candidates)])
            graph_previews <- list()
            figure_previews <- list()
            inset_previews <- list()
            diag_log("PACK", paste0("manifest existing candidates=", length(manifest_candidates)))
            if (length(manifest_candidates)) {
              manifest_path <- manifest_candidates[[1]]
              man <- tryCatch(
                readRDS(manifest_path),
                error = function(e) {
                  diag_log("PACK-ERROR", paste0("manifest read failed: ", conditionMessage(e)))
                  NULL
                }
              )
              graph_entries <- man$previews %||% list()
              # v1 packages had only one preview role. Treat that legacy asset
              # as both Graph preview and Figure snapshot on load.
              figure_entries <- man$figure_previews %||% graph_entries
              diag_log(
                "PACK",
                paste0(
                  "manifest=", manifest_path,
                  " graph preview entries=", length(graph_entries),
                  " figure preview entries=", length(figure_entries)
                )
              )
              read_preview_entries <- function(entries, kind) {
                out <- list()
                if (!is.list(entries) || !length(entries)) return(out)
                preview_dir <- dirname(manifest_path)
                for (old_id in names(entries)) {
                  ent <- entries[[old_id]]
                  rel <- as.character(ent$file %||% "")
                  svg_path <- file.path(preview_dir, rel)
                  exists_svg <- nzchar(rel) && file.exists(svg_path)
                  diag_log(
                    "PACK-PREVIEW",
                    paste0("kind=", kind, " manifest id=", old_id, " file=", rel, " exists=", exists_svg),
                    id = old_id
                  )
                  if (!exists_svg) next
                  svg <- tryCatch(
                    paste(readLines(svg_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
                    error = function(e) {
                      diag_log("PACK-ERROR", paste0("SVG read failed: ", conditionMessage(e)), id = old_id)
                      ""
                    }
                  )
                  valid_svg <- nzchar(svg) && grepl("<svg\\b", svg, perl = TRUE)
                  diag_log(
                    "PACK-PREVIEW",
                    paste0("kind=", kind, " loaded chars=", nchar(svg), " valid_svg=", valid_svg, " ", diag_svg_colors(svg)),
                    id = old_id
                  )
                  if (valid_svg) {
                    rec <- list(svg = svg, meta = ent$meta %||% list())
                    if (identical(kind, "figure")) {
                      body_ent <- ent$body %||% NULL
                      if (is.list(body_ent)) {
                        body_rel <- as.character(body_ent$file %||% "")[1]
                        body_path <- file.path(preview_dir, body_rel)
                        if (nzchar(body_rel) && file.exists(body_path)) {
                          body_svg <- tryCatch(
                            paste(readLines(body_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
                            error = function(e) ""
                          )
                          if (nzchar(body_svg) && grepl("<svg\\b", body_svg, perl = TRUE)) {
                            rec$body_svg <- body_svg
                            rec$body_meta <- body_ent$meta %||% list()
                          }
                        }
                      }

                      legend_ent <- ent$legend %||% NULL
                      if (is.list(legend_ent)) {
                        legend_rel <- as.character(legend_ent$file %||% "")[1]
                        legend_path <- file.path(preview_dir, legend_rel)
                        if (nzchar(legend_rel) && file.exists(legend_path)) {
                          legend_svg <- tryCatch(
                            paste(readLines(legend_path, warn = FALSE, encoding = "UTF-8"), collapse = "\n"),
                            error = function(e) ""
                          )
                          if (nzchar(legend_svg) && grepl("<svg\\b", legend_svg, perl = TRUE)) {
                            rec$legend_svg <- legend_svg
                            rec$legend_width <- suppressWarnings(as.numeric(legend_ent$width %||% NA_real_)[1])
                            rec$legend_height <- suppressWarnings(as.numeric(legend_ent$height %||% NA_real_)[1])
                          }
                        }
                      }

                      diag_log(
                        "PACK-PREVIEW",
                        paste0(
                          "kind=figure layers body=", nzchar(rec$body_svg %||% ""),
                          " legend=", nzchar(rec$legend_svg %||% ""),
                          if (nzchar(rec$legend_svg %||% "")) paste0(
                            " legend_size=", round(rec$legend_width %||% NA_real_, 1),
                            "x", round(rec$legend_height %||% NA_real_, 1)
                          ) else ""
                        ),
                        id = old_id
                      )
                    }
                    out[[old_id]] <- rec
                  }
                }
                out
              }
              graph_previews <- read_preview_entries(graph_entries, "graph")
              figure_previews <- read_preview_entries(figure_entries, "figure")
              inset_previews <- read_preview_entries(man$figure_inset_previews %||% list(), "inset")
            } else {
              diag_log("PACK", "no preview/manifest.rds found after extraction")
            }
            diag_log(
              "PACK",
              paste0("pending graph previews loaded=", length(graph_previews),
                     " figure previews loaded=", length(figure_previews))
            )
            project_bundle_pending_graph_previews(graph_previews)
            project_bundle_pending_previews(figure_previews)
            project_bundle_pending_inset_previews(inset_previews)
            return(cfg)
          }
        }
      }
    }

    diag_log("PACK", "not a usable packaged Project; trying legacy RDS/JSON")
    rds_error <- NULL
    cfg <- tryCatch(
      readRDS(path),
      error = function(e) {
        rds_error <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(cfg)) return(cfg)

    json_error <- NULL
    cfg <- tryCatch(
      jsonlite::read_json(path, simplifyVector = FALSE),
      error = function(e) {
        json_error <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(cfg)) return(cfg)

    project_read_error(
      paste0(
        "RDS: ", rds_error %||% "unknown",
        " / JSON: ", json_error %||% "unknown"
      )
    )
    NULL
  }

  # Project bootstrap is state-first. The persistent Editor already exists;
  # loading a Project replaces canonical GraphState and replays the selected
  # Graph values into that same Editor.
  project_stage_state_target <- function(target, legacy_graph_preview_count, figure_preview_count) {
    target <- as.character(target %||% "")[1]
    if (!nzchar(target)) return(invisible(FALSE))

    figure_visible <- identical(as.character(isolate(input$workspace_main_tab) %||% "")[1], "figure_workspace")
    figure_geometry_bootstrap_deferred(!figure_visible)

    # Project bootstrap is state-first. Old packaged Graph SVGs are accepted by
    # the reader only for migration compatibility and are deliberately ignored
    # as a display/runtime authority. Other Graphs remain state-only until they
    # are selected; Figure and Export render directly from canonical state.
    active_graph(target)
    complete_project_load_lock("registry/Figure snapshots staged; selected persistent Editor attach")

    # RC13.8: do not queue a Project catalog before/around owner transition.
    # publish_client_graph_catalog() sends on the next Shiny flush; a payload
    # captured while editing_graph_id still named the old/empty owner could
    # arrive after graph-client-edit-begin and make browser hydration reject
    # the canonical target as an owner mismatch. graph_meta/editing_graph_id
    # already drive the normal metadata observer, so Project bootstrap should
    # use the same owner-first path as ordinary Graph selection.
    request_graph_editor(target, source = "project-load-state-first", new_graph = FALSE)

    diag_log(
      "PROJECT-STATE-FIRST",
      sprintf(
        "selected Editor attach started; ignored legacy Graph previews=%d Figure snapshots=%d",
        as.integer(legacy_graph_preview_count %||% 0L),
        as.integer(figure_preview_count %||% 0L)
      ),
      id = target
    )
    showNotification(
      "Project一式を読み込みました。選択Graphを表示します。",
      type = "message", duration = 3
    )
    invisible(TRUE)
  }

  observeEvent(input$upload_project_all, {
    req(input$upload_project_all$datapath)

    if (project_load_action_blocked("project-reload")) return(invisible(NULL))
    begin_project_load_lock()
    # A new load owns its own bootstrap lifecycle. Clear any deferred work left
    # by a previous Project before validating/replacing canonical state.
    figure_geometry_bootstrap_deferred(FALSE)
    project_file_read(FALSE)

    cfg <- read_project_file(input$upload_project_all$datapath)

    if (is.null(cfg) || !is.list(cfg)) {
      detail <- isolate(project_read_error())
      if (is.null(detail) || !nzchar(as.character(detail))) {
        detail <- if (is.null(cfg)) "Projectを読み込めませんでした。" else "Projectファイルの形式が正しくありません。"
      }
      showNotification(
        paste0("Project読込エラー: ", detail),
        type = "error",
        duration = 10
      )
      fail_project_load_lock(NULL, detail)
      return(invisible(NULL))
    }

    project_file_read(TRUE)

    # Only clear the current Figure workspace after the new Project file has
    # been validated. A broken/unreadable file must not destroy the Figure the
    # user was already editing.
    reset_figure_workspace(reset_layout = TRUE)

    shared_cfg <- cfg$shared_style %||% list()
    restored_library <- shared_style_normalize_library(shared_cfg$library %||% NULL)
    restored_figure_sync <- isTRUE(shared_cfg$figure_sync)
    shared_style_library(restored_library)
    figure_shared_style_sync(restored_figure_sync)
    updateCheckboxInput(session, "figure_shared_style_sync", value = restored_figure_sync)
    diag_log(
      "SHARED-STYLE-RESTORE",
      paste0("items=", length(restored_library$items), " figure_sync=", restored_figure_sync)
    )

    loaded_uuid <- as.character(cfg$project_uuid %||% "")
    uuid_was_missing <- !valid_project_uuid(loaded_uuid)
    if (uuid_was_missing) {
      loaded_uuid <- new_project_uuid()
      showNotification(
        "旧ProjectをUUID方式へ移行しました。次回保存時にProject IDが記録されます。",
        type = "message", duration = 5
      )
    }
    project_uuid(loaded_uuid)
    project_uuid_save_override(NULL)

    loaded_project_name <- NULL
    if (!is.null(cfg$project_name)) {
      loaded_project_name <- as.character(cfg$project_name)
      updateTextInput(
        session, "project_name",
        value = loaded_project_name
      )
      session$sendCustomMessage(
        "set-project-name-input",
        list(name = loaded_project_name)
      )
    }

    # Project単位の保存先記憶設定を復元する。
    popt <- cfg$project_options
    remember_restore <- if (is.null(popt)) FALSE else isTRUE(popt$remember_save_destination)
    project_remember_pref(remember_restore)
    updateCheckboxInput(session, "remember_project_save_destination", value = remember_restore)
    if (remember_restore) {
      if (isTRUE(uuid_was_missing) && !is.null(loaded_project_name) && nzchar(loaded_project_name)) {
        session$sendCustomMessage(
          "migrate-project-save-destination",
          list(
            oldKey = safe_name(loaded_project_name, loaded_project_name),
            newKey = loaded_uuid
          )
        )
      } else {
        session$sendCustomMessage(
          "check-project-save-destination",
          list(projectKey = loaded_uuid, remember = TRUE)
        )
      }
    }

    # Project replacement is state-first. Dormant Graphs have no hidden UI/module
    # to tear down; replace the canonical Registry after invalidating the one
    # persistent Editor owner below.
    project_legacy_graph_previews(list())

    # Project replacement invalidates the old Graph owner before the canonical
    # Registry is cleared.  This prevents the outgoing Graph from being
    # committed into the newly loaded Project when the new target attaches.
    editing_graph_id("")
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("IDLE")
    graph_single_pending_target(NULL)
    graph_single_editor_generation(as.integer(isolate(graph_single_editor_generation()) %||% 0L) + 1L)
    graph_editor_ui_panel_store(list())
    if (length(ls(envir = graph_single_editor_visit_cache, all.names = TRUE))) {
      rm(list = ls(envir = graph_single_editor_visit_cache, all.names = TRUE),
         envir = graph_single_editor_visit_cache)
    }

    graph_state_cache(list())
    graph_meta(data.frame(
      id = character(0),
      name = character(0),
      stringsAsFactors = FALSE
    ))

    entries <- list()
    old_active <- NULL

    if (!is.null(cfg$graphs) && length(cfg$graphs)) {
      entries <- cfg$graphs
      old_active <- as.character(cfg$active_graph %||% "")
    } else {
      # v1.14以前の単一Graph Project
      entries <- list(
        old_graph_1 = list(name = "Graph 1", state = cfg)
      )
      old_active <- "old_graph_1"
    }

    source_ids <- names(entries)
    if (is.null(source_ids) || length(source_ids) != length(entries) || any(!nzchar(source_ids))) {
      source_ids <- paste0("old_graph_", seq_along(entries))
      names(entries) <- source_ids
    }
    created <- character(0)
    new_meta <- data.frame(
      id = character(0),
      name = character(0),
      stringsAsFactors = FALSE
    )

    # 重要:
    # ここではGraph module/UIを生成しない。
    # RDSからstateだけregistryへ読み込む。
    for (i in seq_along(entries)) {
      e <- entries[[i]]
      st <- if (!is.null(e$state)) e$state else e
      st <- shared_style_normalize_graph_state(st)
      old_graph_schema <- suppressWarnings(as.integer(graph_state_scalar(st$schema_version, 0L)))
      if (!is.finite(old_graph_schema)) old_graph_schema <- 0L
      old_style_schema <- suppressWarnings(as.integer(graph_state_scalar((st$style %||% list())$schema_version, 0L)))
      if (!is.finite(old_style_schema)) old_style_schema <- 0L
      st <- graph_state_prepare_replay_snapshot(st)
      new_graph_schema <- suppressWarnings(as.integer(graph_state_scalar(st$schema_version, 0L)))
      if (!is.finite(new_graph_schema)) new_graph_schema <- 0L
      new_style_schema <- suppressWarnings(as.integer(graph_state_scalar((st$style %||% list())$schema_version, 0L)))
      if (!is.finite(new_style_schema)) new_style_schema <- 0L
      if (old_graph_schema < 4L && is.list(st) && new_graph_schema >= 4L) {
        diag_log(
          "PROJECT-STYLE-MIGRATION",
          "dynamic style defaults canonicalized from data/mapping; no Editor reconcile required",
          id = source_ids[[i]]
        )
      }
      if (old_style_schema < 4L && is.list(st) && new_style_schema >= 4L) {
        diag_log(
          "PROJECT-STYLE-SCHEMA-MIGRATION",
          "style schema canonicalized at Project load boundary; first Editor replay should remain clean",
          id = source_ids[[i]]
        )
      }
      nm <- as.character(e$name %||% paste0("Graph ", i))

      id <- next_id()
      created <- c(created, id)
      new_meta <- rbind(
        new_meta,
        data.frame(id = id, name = nm, stringsAsFactors = FALSE)
      )
      cache_set(id, st)
    }

    if (!length(created)) {
      id <- next_id()
      created <- id
      new_meta <- data.frame(
        id = id,
        name = "Graph 1",
        stringsAsFactors = FALSE
      )
    }

    graph_meta(new_meta)
    project_load_ids(created)
    update_project_load_lock(NULL)

    id_map <- stats::setNames(created, source_ids)
    restore_figure_project_state(cfg$figure, id_map, new_meta)

    # Remap packaged Graph previews and Figure snapshots independently. Graph
    # workspace uses the latest Graph-owned SVG; Figure keeps the explicitly
    # refreshed source snapshot it had when the Project was saved.
    pending_graph_previews <- isolate(project_bundle_pending_graph_previews())
    pending_figure_previews <- isolate(project_bundle_pending_previews())
    map_preview_records <- function(records, kind) {
      mapped <- list()
      if (!length(records)) return(mapped)
      for (old_id in names(records)) {
        if (!old_id %in% names(id_map)) {
          diag_log("PREVIEW-MAP", paste0("kind=", kind, " no matching saved Graph ID; skipped"), id = old_id)
          next
        }
        new_id <- as.character(id_map[[old_id]])
        valid_rec <- is.list(records[[old_id]]) && nzchar(records[[old_id]]$svg %||% "")
        diag_log(
          "PREVIEW-MAP",
          paste0("kind=", kind, " old=", old_id, " new=", new_id, " valid_record=", valid_rec),
          id = old_id
        )
        if (nzchar(new_id) && valid_rec) mapped[[new_id]] <- records[[old_id]]
      }
      mapped
    }
    diag_log(
      "PREVIEW-MAP",
      paste0(
        "source_ids=", paste(source_ids, collapse = ","),
        " graph_pending_ids=", paste(names(pending_graph_previews), collapse = ","),
        " figure_pending_ids=", paste(names(pending_figure_previews), collapse = ","),
        " id_map=", paste(paste0(names(id_map), "->", as.character(id_map)), collapse = ",")
      )
    )
    mapped_graph_previews <- map_preview_records(pending_graph_previews, "graph")
    mapped_figure_previews <- map_preview_records(pending_figure_previews, "figure")
    # Legacy Graph previews may exist in older packages. Keep them only in a
    # migration-only store used by the old Figure legend seed heuristic; never
    # install them into the live Graph workspace.
    project_legacy_graph_previews(mapped_graph_previews)
    figure_persisted_previews(mapped_figure_previews)
    mapped_inset_previews <- map_preview_records(isolate(project_bundle_pending_inset_previews()), "inset")
    figure_inset_preview_cache(mapped_inset_previews)
    for (id in names(mapped_inset_previews)) bump_figure_snapshot_revision(id)
    # v3.72 lifecycle rule: Figure owns state/cache only for sources that are
    # currently referenced by the restored Figure layout (or enabled insets).
    # This also cleans older packages that persisted snapshots for every Graph.
    figure_gc_unreferenced_sources(reason = "project-restore")
    mapped_figure_previews <- isolate(figure_persisted_previews())
    if (length(mapped_figure_previews)) {
      for (id in names(mapped_figure_previews)) bump_figure_snapshot_revision(id)
    }
    project_bundle_pending_graph_previews(list())
    project_bundle_pending_previews(list())
    project_bundle_pending_inset_previews(list())

    target_index <- match(old_active, source_ids)
    if (is.na(target_index)) target_index <- 1L
    target <- created[target_index]

    refresh_export_choices()

    # State-first Project restore: Registry is authoritative, Figure keeps its
    # explicit snapshots, and only the selected Graph is attached to the one
    # persistent Editor. No Graph SVG bootstrap and no eager all-Graph restore.
    diag_log(
      "PROJECT",
      paste0("restore registry graphs=", length(created),
             " legacy_graph_previews_ignored=", length(mapped_graph_previews),
             " mapped_figure_previews=", length(mapped_figure_previews),
             " target=", target),
      id = target
    )
    project_stage_state_target(
      target,
      legacy_graph_preview_count = length(mapped_graph_previews),
      figure_preview_count = length(mapped_figure_previews)
    )
  })

  # v3.73.1: Close Project is an explicit hard boundary.  A full session reset
  # is safer than manually clearing dozens of Graph/Figure/editor reactive
  # owners and guarantees the app returns to the normal pristine g001 Editor.
  observeEvent(input$close_project_all, {
    if (project_load_action_blocked("project-close")) return(invisible(NULL))
    showModal(modalDialog(
      title = "Projectを閉じる",
      p("現在のProjectを閉じて、新しいGraph 1の編集状態へ戻ります。"),
      p(strong("未保存の変更は失われます。")),
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("close_project_confirm", "Projectを閉じる", class = "btn-danger")
      ),
      easyClose = TRUE
    ))
  }, ignoreInit = TRUE)

  observeEvent(input$close_project_confirm, {
    removeModal()
    diag_log("PROJECT-CLOSE", "confirmed; hard session reset to pristine Editor")
    session$sendCustomMessage("project-close-reload", list())
  }, ignoreInit = TRUE)
