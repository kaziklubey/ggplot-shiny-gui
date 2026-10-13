
  # ------------------------------------------------------------------
  # Project save / load
  # ------------------------------------------------------------------
  # GraphState phase 3:
  # Project serialization reads Graph state from the canonical registry only.
  # Main Data text has a separate Graph-owned Data Document transport: its browser
  # capture-phase save hook flushes graphId/generation/seq before the Shiny save
  # action, and the save workflow starts its download only from session$onFlushed.
  # This helper therefore closes the remaining server-resident editor/state race;
  # it is not a second Data text transport. Hidden/evicted Graphs are already
  # represented by their canonical registry entries.
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
      keep_ids <- intersect(
        names(overrides_now),
        unique(c(as.character(meta_now$id), names(isolate(figure_external_assets()))))
      )
      overrides_now <- overrides_now[keep_ids]
    }
    edit_states_now <- isolate(figure_edit_states())
    if (!is.list(edit_states_now)) edit_states_now <- list()
    # Figure-owned GraphState outlives panel placement. Persist every state whose
    # source Graph still exists, including temporarily unplaced Figure Graphs.
    edit_states_now <- edit_states_now[intersect(names(edit_states_now), as.character(meta_now$id))]

    list(
      version = 12L,
      renderer_schema = "asset-layer-v7-editable-graph-snapshot",
      autofit_policy = as.character(if (!is.null(seed)) seed$autofit_policy %||% "live" else isolate(figure_requested_autofit_policy()) %||% "live"),
      size_mode = as.character(if (!is.null(seed)) seed$mode %||% "fixed" else isolate(figure_requested_size_mode()) %||% "fixed"),
      size_basis = figure_normalize_alignment_basis(if (!is.null(seed)) seed$basis %||% "panel_legend" else isolate(figure_requested_size_basis()) %||% "panel_legend"),
      title_align = as.character(if (!is.null(seed)) seed$title_align %||% "none" else isolate(figure_requested_title_align()) %||% "none"),
      layout_mode = as.character(if (!is.null(seed)) seed$layout_mode %||% "row" else isolate(figure_requested_layout_mode()) %||% "row"),
      free_canvas_padding = as.numeric(if (!is.null(seed)) seed$free_padding %||% 24 else isolate(figure_requested_free_padding()) %||% 24),
      external_assets = isolate(figure_external_assets()),
      canvas_width = min(max(cw, 300), 6000),
      canvas_height = min(max(ch, 300), 6000),
      gap_x = max(gx, 0),
      gap_y = max(gy, 0),
      column_ratios = figure_shared_column_ratios(layout_now),
      layout = figure_reindex_layout(layout_now),
      overrides = overrides_now,
      editable_graph_states = edit_states_now
    )
  }

  figure_layout_diag <- function(layout) {
    layout <- figure_reindex_layout(layout)
    keys <- unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) as.character(cell$key %||% ""), character(1))
    }), use.names = FALSE)
    list(rows = length(layout), keys = keys[nzchar(keys)])
  }

  restore_figure_project_state <- function(saved, id_map, meta) {
    # Project restore owns one atomic canonical replacement. Clear the previous
    # Figure runtime exactly once; requested/render state is activation-owned.
    reset_figure_runtime()
    shared_style_graph_replay_pending(NULL)
    figure_inspector_folds(list())
    # Live plot objects are never persisted. F1-5p does persist the lightweight
    # editable GraphState copy separately from SVG preview caches.
    figure_external_assets(list())

    if (is.null(saved) || !is.list(saved)) {
      figure_layout_initialized(FALSE)
      figure_layout_state(figure_default_layout_state())
      figure_override_drafts(list())
      figure_autofit_revision(0L)
      figure_geometry_revision(0L)
      figure_reorder_undo(NULL)
      figure_edit_states(list())
      figure_control_restore_seed(list(width = 1600, height = 1000, gap_x = 12, gap_y = 12, mode = "auto", basis = "panel_legend", title_align = "none", layout_mode = "row", autofit_policy = "live", free_padding = 24))
      diag_log("FIGURE-RESTORE", "canonical default staged; runtime=dormant")
      return(invisible(FALSE))
    }

    cw <- suppressWarnings(as.numeric(saved$canvas_width %||% 1600)[1])
    ch <- suppressWarnings(as.numeric(saved$canvas_height %||% 1000)[1])
    gx <- suppressWarnings(as.numeric(saved$gap_x %||% 12)[1])
    gy <- suppressWarnings(as.numeric(saved$gap_y %||% 12)[1])
    # Legacy Projects predate content-driven sizing. Projects can be
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
    # migration: old panel_auto/plot/facet/axis/axis_legend values are
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
    free_padding <- max(free_padding, 0)
    external_assets <- saved$external_assets %||% list()
    if (!is.list(external_assets)) external_assets <- list()
    if (!is.finite(cw)) cw <- 1600
    if (!is.finite(ch)) ch <- 1000
    if (!is.finite(gx)) gx <- 12
    if (!is.finite(gy)) gy <- 12
    cw <- min(max(cw, 300), 6000)
    ch <- min(max(ch, 300), 6000)
    gx <- max(gx, 0)
    gy <- max(gy, 0)

    layout <- saved$layout %||% figure_default_layout_state()
    # Project payload stores the Figure-wide column vector explicitly.
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

    # migration: older saved Figure schemas stored Panel label style on the source
    # override. Move those legacy values into the currently occupied Slot and
    # remove them from source-owned override state. Internal Graph duplication
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
        # Existing slot values from v8+ remain authoritative. For legacy
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
      valid_graph_ids <- as.character(meta$id %||% character(0))
      for (old_id in names(saved_edit_states)) {
        new_id <- if (old_id %in% names(id_map)) as.character(id_map[[old_id]]) else if (old_id %in% valid_graph_ids) old_id else ""
        if (!nzchar(new_id) || !new_id %in% valid_graph_ids) next
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
    figure_autofit_revision(0L)
    figure_reorder_undo(NULL)
    figure_external_assets(external_assets)
    figure_control_restore_seed(list(width = cw, height = ch, gap_x = gx, gap_y = gy, mode = size_mode, basis = size_basis, title_align = title_align, layout_mode = layout_mode, autofit_policy = autofit_policy, free_padding = free_padding))
    diag_log(
      "FIGURE-RESTORE",
      paste0(
        "canonical_rows=", restored_diag$rows,
        " canonical_cells=", paste(restored_diag$keys, collapse = ","),
        " runtime=dormant"
      )
    )

    invisible(TRUE)
  }

  build_project <- function() {
    # Close the user-edit/save races before serialization. First merge each
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
        library = shared_style_normalize_library(shiny::isolate(shared_style_library()))
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

  # Graph SVG package records were retired. Figure snapshot
  # records below remain explicit project assets.


  collect_figure_snapshot_preview_records <- function() {
    meta_now <- isolate(graph_meta())
    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    assets <- isolate(figure_loaded_assets())
    persisted <- isolate(figure_persisted_previews())
    ovs <- isolate(figure_requested_overrides())
    out <- list()

    owned_ids <- unique(c(
      names(isolate(figure_edit_states())), names(assets), names(plots), names(persisted)
    ))
    for (id in intersect(as.character(meta_now$id %||% character(0)), owned_ids)) {
      # Preserve Figure ownership across temporary panel removal and Project
      # save/load. Only Figure-owned state/assets are eligible; a newer live
      # Graph preview must never replace an explicitly frozen Figure source.
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
      # Figure snapshot. For detached/free legends, persist three coordinated
      # artifacts: the stable source-side anchor SVG/geometry, a legend-free
      # owner Graph body, and the tight guide-box legend asset. This lets a
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
              body_meta <- figure_render_geometry_meta(
                body_rendered,
                reference_res = ex$reference_res %||% 120,
                include_legend_state = TRUE,
                include_geometry_source = TRUE,
                include_reference_res = TRUE
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
        meta = figure_render_geometry_meta(
          rendered,
          reference_res = ex$reference_res %||% 120,
          include_legend_state = TRUE,
          include_geometry_source = TRUE,
          include_reference_res = TRUE
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
    # GraphState is the only persisted Graph authority. Graph SVG
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
    diag_log("PACK", paste0("read_project_file path=", basename(path), " bytes=", tryCatch(file.info(path)$size, error = function(e) NA)))

    # packaged Project may contain files either at archive root or
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
              figure_entries <- man$figure_previews %||% list()
              diag_log(
                "PACK",
                paste0(
                  "manifest=", manifest_path,
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
                    if (identical(kind, "inset")) {
                      rec$owner_id <- old_id
                      rec$source_id <- as.character(ent$source_id %||% "")[1]
                    }
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
              figure_previews <- read_preview_entries(figure_entries, "figure")
              inset_previews <- read_preview_entries(man$figure_inset_previews %||% list(), "inset")
            } else {
              diag_log("PACK", "no preview/manifest.rds found after extraction")
            }
            diag_log(
              "PACK",
              paste0("pending figure previews loaded=", length(figure_previews))
            )
            project_bundle_pending_previews(figure_previews)
            project_bundle_pending_inset_previews(inset_previews)
            return(cfg)
          }
        }
      }
    }

    diag_log("PACK", "not a usable packaged Project; trying legacy RDS")
    rds_error <- NULL
    cfg <- tryCatch(
      readRDS(path),
      error = function(e) {
        rds_error <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(cfg)) return(cfg)

    project_read_error(paste0("RDS: ", rds_error %||% "unknown"))
    NULL
  }

  # Project bootstrap is state-first. The persistent Editor already exists;
  # loading a Project replaces canonical GraphState and replays the selected
  # Graph values into that same Editor.
  project_stage_state_target <- function(target, figure_preview_count) {
    target <- as.character(target %||% "")[1]
    if (!nzchar(target)) return(invisible(FALSE))

    set_project_load_phase("selected")

    # Project bootstrap is state-first. Other Graphs remain state-only until
    # they are selected; Figure and Export use only explicit Figure snapshots.
    active_graph(target)
    # do not queue a Project catalog before/around owner transition.
    # publish_client_graph_catalog() sends on the next Shiny flush; a payload
    # captured while editing_graph_id still named the old/empty owner could
    # arrive after graph-client-edit-begin and make browser hydration reject
    # the canonical target as an owner mismatch. graph_meta/editing_graph_id
    # already drive the normal metadata observer, so Project bootstrap should
    # use the same owner-first path as ordinary Graph selection.
    started <- isTRUE(activate_graph_editor_target(target, source = "project-load-state-first", new_graph = FALSE))
    if (!started && isTRUE(isolate(project_load_locked())) && is.null(isolate(project_load_failure()))) {
      fail_project_load_lock(target, "selected-graph-activation-start-failed")
      return(invisible(FALSE))
    }

    diag_log(
      "PROJECT-STATE-FIRST",
      sprintf(
        "selected Editor attach started; Figure snapshots=%d",
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

  # Candidate-only Project upload timing correlation. Browser diagnostic
  # events carry client timestamps so delayed R observer entry can be separated
  # from browser-side file-input progression without relying on Shiny private
  # upload internals.
  project_upload_diag_state <- new.env(parent = emptyenv())

  observeEvent(input$project_open_intent_browser, {
    z <- input$project_open_intent_browser
    client_ms <- suppressWarnings(as.numeric(z$clientAtMs %||% NA_real_)[1])
    now_ms <- as.numeric(Sys.time()) * 1000
    diag_log(
      "PROJECT-OPEN-INTENT",
      paste0(
        "phase=", as.character(z$phase %||% "?"),
        " client_at=", if (is.finite(client_ms)) format(as.POSIXct(client_ms / 1000, origin = "1970-01-01"), "%H:%M:%OS3") else "unavailable",
        " client_to_r_ms=", if (is.finite(client_ms)) round(now_ms - client_ms) else "unavailable"
      )
    )
  }, ignoreInit = TRUE, priority = 350)

  observeEvent(input$project_upload_diag_browser, {
    z <- input$project_upload_diag_browser
    selection_id <- as.character(z$selectionId %||% "")[1]
    phase <- as.character(z$phase %||% "")[1]
    client_ms <- suppressWarnings(as.numeric(z$clientAtMs %||% NA_real_)[1])
    selected_ms <- suppressWarnings(as.numeric(z$selectedAtMs %||% NA_real_)[1])
    now_ms <- as.numeric(Sys.time()) * 1000
    if (nzchar(selection_id)) {
      key <- paste0("s_", gsub("[^A-Za-z0-9_]", "_", selection_id))
      st <- if (exists(key, envir = project_upload_diag_state, inherits = FALSE)) {
        get(key, envir = project_upload_diag_state, inherits = FALSE)
      } else list()
      st[[phase]] <- list(client_ms = client_ms, server_ms = now_ms)
      st$selected_ms <- selected_ms
      assign(key, st, envir = project_upload_diag_state)
    }
    diag_log(
      "PROJECT-UPLOAD-DIAG",
      paste0(
        "selection_id=", if (nzchar(selection_id)) selection_id else "?",
        " phase=", if (nzchar(phase)) phase else "?",
        " client_at=", if (is.finite(client_ms)) format(as.POSIXct(client_ms / 1000, origin = "1970-01-01"), "%H:%M:%OS3") else "unavailable",
        " client_to_r_ms=", if (is.finite(client_ms)) round(now_ms - client_ms) else "unavailable",
        " selection_to_client_phase_ms=", if (is.finite(client_ms) && is.finite(selected_ms)) round(client_ms - selected_ms) else "unavailable"
      )
    )
  }, ignoreInit = TRUE)

  # The browser timestamps the file-input change before Shiny queues/upload
  # work. Keep this measurement separate from the Project progress owner: it
  # records upload latency; startup is completed before user interaction.
  observeEvent(input$project_upload_selected, {
    selected <- input$project_upload_selected
    selected_ms <- suppressWarnings(as.numeric(selected$selectedAtMs %||% NA_real_)[1])
    selection_id <- as.character(selected$selectionId %||% "")[1]
    now_ms <- as.numeric(Sys.time()) * 1000
    diag_log(
      "PROJECT-UPLOAD-TIMING",
      paste0(
        "stage=selection-received",
        " selection_id=", if (nzchar(selection_id)) selection_id else "?",
        " file_bytes=", as.character(selected$fileSize %||% "?"),
        " selected_at=", if (is.finite(selected_ms)) format(as.POSIXct(selected_ms / 1000, origin = "1970-01-01"), "%H:%M:%OS3") else "unavailable",
        " selection_to_server_ms=", if (is.finite(selected_ms)) round(now_ms - selected_ms) else "unavailable"
      )
    )
  }, ignoreInit = TRUE, priority = 300)

  observeEvent(input$upload_project_all, {
    req(input$upload_project_all$datapath)

    selected <- isolate(input$project_upload_selected)
    selection_id <- as.character(selected$selectionId %||% "")[1]
    selected_ms_entry <- suppressWarnings(as.numeric(selected$selectedAtMs %||% NA_real_)[1])
    observer_enter_ms <- as.numeric(Sys.time()) * 1000
    diag_log(
      "PROJECT-UPLOAD-DIAG",
      paste0(
        "selection_id=", if (nzchar(selection_id)) selection_id else "?",
        " phase=r-upload-observer-enter",
        " selection_to_r_observer_ms=", if (is.finite(selected_ms_entry)) round(observer_enter_ms - selected_ms_entry) else "unavailable"
      )
    )

    if (project_load_action_blocked("project-reload")) return(invisible(NULL))
    selected_ms <- suppressWarnings(as.numeric(selected$selectedAtMs %||% NA_real_)[1])
    selected_name <- as.character(selected$fileName %||% "")[1]
    selected_size <- suppressWarnings(as.numeric(selected$fileSize %||% NA_real_)[1])
    uploaded_name <- as.character(input$upload_project_all$name %||% "")[1]
    uploaded_size <- suppressWarnings(as.numeric(input$upload_project_all$size %||% NA_real_)[1])
    matched <- is.finite(selected_ms) && identical(selected_name, uploaded_name) &&
      is.finite(selected_size) && is.finite(uploaded_size) && identical(selected_size, uploaded_size)
    diag_log(
      "PROJECT-UPLOAD-TIMING",
      paste0(
        "stage=upload-ready selection_id=", if (nzchar(selection_id)) selection_id else "?",
        " bytes=", if (is.finite(uploaded_size)) uploaded_size else "?",
        " selection_to_lock_ms=", if (isTRUE(matched)) round(as.numeric(Sys.time()) * 1000 - selected_ms) else "unavailable",
        " selection_match=", isTRUE(matched)
      )
    )
    begin_project_load_lock()
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

    # A validated Project request owns the Editor immediately. Invalidate the
    # old Graph transaction before the phase flush and registry restore, so
    # any remaining old callbacks cannot advance while the new Project waits.
    editor_activation_supersede("project-replace")
    editing_graph_id("")
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("IDLE")
    project_file_read(TRUE)
    set_project_load_phase("restoring")

    # The file-read phase is already visible while the browser uploads the
    # selected file. Flush the restoring phase before the synchronous registry
    # restore begins, so the displayed phase describes the work actually in
    # progress. This is a progress-UI boundary only; replay dispatch and
    # completion remain on their existing transport lifecycle.
    session$onFlushed(function() {
      if (!isTRUE(isolate(project_load_locked()))) return(invisible(NULL))

    # Only clear the current Figure workspace after the new Project file has
    # been validated. A broken/unreadable file must not destroy the Figure the
    # user was already editing.
    session$sendCustomMessage("figure-collapse-workspace-controls", list(reason = "project-load"))

    shared_cfg <- cfg$shared_style %||% list()
    restored_library <- shared_style_normalize_library(shared_cfg$library %||% NULL)
    shared_style_library(restored_library)
    # Figure no longer has a Shared Style auto-sync mode. Older projects may
    # contain shared_style$figure_sync; it is intentionally ignored so Figure
    # remains a frozen owner until an explicit Common Settings apply.
    diag_log(
      "SHARED-STYLE-RESTORE",
      paste0("items=", length(restored_library$items), " figure_sync=retired")
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
    # Project replacement invalidates the old Graph owner before the canonical
    # Registry is cleared. This prevents the outgoing Graph from being
    # committed into the newly loaded Project when the new target attaches.
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
    id_map <- stats::setNames(created, source_ids)
    restore_figure_project_state(cfg$figure, id_map, new_meta)

    # Remap packaged Figure snapshots. Figure keeps the explicitly refreshed
    # source snapshot it had when the Project was saved.
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
        if (nzchar(new_id) && valid_rec) {
          rec <- records[[old_id]]
          if (identical(kind, "inset")) {
            old_source <- as.character(rec$source_id %||% "")[1]
            rec$owner_id <- new_id
            rec$source_id <- if (old_source %in% names(id_map)) {
              as.character(id_map[[old_source]])
            } else old_source
          }
          mapped[[new_id]] <- rec
        }
      }
      mapped
    }
    diag_log(
      "PREVIEW-MAP",
      paste0(
        "source_ids=", paste(source_ids, collapse = ","),
        " figure_pending_ids=", paste(names(pending_figure_previews), collapse = ","),
        " id_map=", paste(paste0(names(id_map), "->", as.character(id_map)), collapse = ",")
      )
    )
    mapped_figure_previews <- map_preview_records(pending_figure_previews, "figure")
    figure_persisted_previews(mapped_figure_previews)
    mapped_inset_previews <- map_preview_records(isolate(project_bundle_pending_inset_previews()), "inset")
    # Current packages key Inset snapshots by owner Graph. resume1 and older
    # packages keyed them by source Graph and carried no source_id metadata.
    # Fan that legacy frozen asset out to every restored owner that referenced
    # the source, then continue with the single owner-keyed runtime model.
    normalized_inset_previews <- list()
    restored_overrides <- isolate(figure_override_drafts())
    for (mapped_id in names(mapped_inset_previews)) {
      rec <- mapped_inset_previews[[mapped_id]]
      source_id <- as.character(rec$source_id %||% "")[1]
      if (nzchar(source_id)) {
        owner_id <- as.character(rec$owner_id %||% mapped_id)[1]
        normalized_inset_previews[[owner_id]] <- rec
        next
      }
      legacy_source_id <- mapped_id
      for (owner_id in names(restored_overrides)) {
        inset <- (restored_overrides[[owner_id]] %||% list())$inset %||% list()
        if (!isTRUE(inset$enabled) ||
            !identical(as.character(inset$source_type %||% "internal_graph")[1], "internal_graph") ||
            !identical(as.character(inset$source_id %||% "")[1], legacy_source_id)) next
        migrated <- rec
        migrated$owner_id <- owner_id
        migrated$source_id <- legacy_source_id
        normalized_inset_previews[[owner_id]] <- migrated
      }
    }
    mapped_inset_previews <- normalized_inset_previews
    # Older Projects may have only a Main Figure preview for an Inset source.
    # Resolve that migration once at restore time into the owner-keyed cache;
    # Viewer, export, and Main replacement then use no source-key fallback.
    for (source_id in names(mapped_figure_previews)) {
      migrated <- figure_materialize_persisted_inset_fallbacks(
        mapped_inset_previews,
        restored_overrides,
        source_id,
        mapped_figure_previews[[source_id]]
      )
      mapped_inset_previews <- migrated$cache
    }
    figure_inset_preview_cache(mapped_inset_previews)
    for (id in names(mapped_inset_previews)) bump_figure_snapshot_revision(id)
    mapped_figure_previews <- isolate(figure_persisted_previews())
    if (length(mapped_figure_previews)) {
      for (id in names(mapped_figure_previews)) bump_figure_snapshot_revision(id)
    }
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
             " mapped_figure_previews=", length(mapped_figure_previews),
             " target=", target),
      id = target
    )
    project_stage_state_target(
      target,
      figure_preview_count = length(mapped_figure_previews)
    )
    }, once = TRUE)
    invisible(NULL)
  })

  # Close Project is an explicit hard boundary. A full session reset
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
