# v3.70.0: extracted from server.R; sourced into the same server function environment.

  # ------------------------------------------------------------------
  # Figure workspace / lazy preparation
  # ------------------------------------------------------------------
  figure_collect_live_layout <- function(meta) {
    figure_sanitize_layout(figure_layout_state(), meta, auto_fill = FALSE, external_assets = isolate(figure_external_assets()))
  }
  # v3.3.56: figure_layout_rects moved to its Figure module.
  # v3.3.56: figure_override_for moved to its Figure module.
  # v3.3.56: figure_apply_plot_override moved to its Figure module.
  # v3.3.56: figure_label_band moved to its Figure module.

  # Figureでは元Graphのpanel寸法を正本として扱う。Legend overrideをかけても
  # panelサイズは変えず、必要ならセルへ収まる倍率だけpanel寸法へ適用する。
  # v3.3.56: figure_plot_for_scale moved to its Figure module.
  # v3.3.56: figure_plot_spec_for_rect moved to its Figure module.
  # v3.3.56: figure_plot_offsets moved to its Figure module.


  # Panel label is positioned relative to the actual rendered plot geometry.
  # plot_axis uses the measured panel-left edge (the Y-axis side), instead of an
  # approximate percentage of the whole plot image.
  # v3.3.56: figure_label_position moved to its Figure module.
  # v3.3.56: figure_plot_panel_zone moved to its Figure module.
  # v3.3.56: figure_legend_handle_position moved to its Figure module.


  # Release the restore seed only after all four browser inputs visibly match
  # the restored values. Until then the seed remains authoritative.
  observe({
    seed <- figure_control_restore_seed()
    if (is.null(seed)) return()
    vals <- c(
      suppressWarnings(as.numeric(input$figure_canvas_width %||% NA_real_)),
      suppressWarnings(as.numeric(input$figure_canvas_height %||% NA_real_)),
      suppressWarnings(as.numeric(input$figure_gap_x %||% NA_real_)),
      suppressWarnings(as.numeric(input$figure_gap_y %||% NA_real_))
    )
    target <- c(seed$width, seed$height, seed$gap_x, seed$gap_y)
    mode_now <- as.character(input$figure_size_mode %||% "")[1]
    mode_target <- as.character(seed$mode %||% figure_requested_size_mode())[1]
    basis_now <- as.character(input$figure_size_basis %||% "")[1]
    basis_target <- as.character(seed$basis %||% figure_requested_size_basis())[1]
    title_align_now <- as.character(input$figure_title_align %||% "")[1]
    title_align_target <- as.character(seed$title_align %||% figure_requested_title_align())[1]
    policy_now <- as.character(input$figure_autofit_policy %||% "")[1]
    policy_target <- as.character(seed$autofit_policy %||% figure_requested_autofit_policy())[1]
    layout_now <- as.character(input$figure_layout_mode %||% "")[1]
    layout_target <- as.character(seed$layout_mode %||% figure_requested_layout_mode())[1]
    if (all(is.finite(vals)) && all(abs(vals - target) <= 0.5) &&
        identical(mode_now, mode_target) && identical(basis_now, basis_target) &&
        identical(title_align_now, title_align_target) &&
        identical(policy_now, policy_target) && identical(layout_now, layout_target)) {
      diag_log("FIGURE-CONTROL-RESTORE", paste0(
        "release layout_mode=", layout_now, " size_mode=", mode_now,
        " basis=", basis_now, " title_align=", title_align_now,
        " autofit_policy=", policy_now
      ))
      figure_control_restore_seed(NULL)
    }
  })

  # v3.73.2.3: a legend transition may need one lazy Figure-owned
  # materialization before the new override can be displayed safely. Keep the
  # requested/display state frozen for only those pending source ids while the
  # authored draft continues to accept edits. The materializer releases the
  # newest draft atomically with the completed snapshot.
  figure_visible_requested_overrides <- function(drafts) {
    out <- drafts %||% list()
    current <- isolate(figure_requested_overrides())
    ids <- union(names(out), names(current))
    if (!length(ids) ||
        !exists("figure_legend_materializer_pending", mode = "function", inherits = TRUE)) {
      return(out)
    }
    for (id in ids) {
      held <- isTRUE(tryCatch(figure_legend_materializer_pending(id), error = function(e) FALSE))
      if (!held) next
      previous <- current[[id]]
      if (!is.list(previous)) previous <- figure_default_override(id)
      out[[id]] <- previous
    }
    out
  }

  # Figure内のレイアウト/サイズ/overrideは入力変更をそのまま現在状態へ反映する。
  observe({
    meta <- graph_meta()
    layout <- figure_collect_live_layout(meta)

    restore_seed <- figure_control_restore_seed()
    fw <- if (!is.null(restore_seed)) restore_seed$width else suppressWarnings(as.numeric(input$figure_canvas_width %||% 1600))
    fh <- if (!is.null(restore_seed)) restore_seed$height else suppressWarnings(as.numeric(input$figure_canvas_height %||% 1000))
    gx <- if (!is.null(restore_seed)) restore_seed$gap_x else suppressWarnings(as.numeric(input$figure_gap_x %||% 12))
    gy <- if (!is.null(restore_seed)) restore_seed$gap_y else suppressWarnings(as.numeric(input$figure_gap_y %||% 12))
    size_mode <- if (!is.null(restore_seed)) as.character(restore_seed$mode %||% "fixed") else as.character(input$figure_size_mode %||% "auto")
    if (!size_mode %in% c("auto", "fixed")) size_mode <- "auto"
    size_basis <- if (!is.null(restore_seed)) as.character(restore_seed$basis %||% "plot") else as.character(input$figure_size_basis %||% "plot")
    if (!size_basis %in% c("plot", "facet", "axis", "axis_legend")) size_basis <- "plot"
    title_align <- if (!is.null(restore_seed)) as.character(restore_seed$title_align %||% "none") else as.character(input$figure_title_align %||% "none")
    if (!title_align %in% c("none", "row_top")) title_align <- "none"
    layout_mode <- if (!is.null(restore_seed)) as.character(restore_seed$layout_mode %||% "row") else as.character(input$figure_layout_mode %||% "row")
    if (!layout_mode %in% c("row", "free")) layout_mode <- "row"
    autofit_policy <- if (!is.null(restore_seed)) as.character(restore_seed$autofit_policy %||% "live") else as.character(input$figure_autofit_policy %||% "live")
    if (!autofit_policy %in% c("live", "manual", "lock")) autofit_policy <- "live"
    if (!is.finite(fw) || fw < 300) fw <- 1600
    if (!is.finite(fh) || fh < 300) fh <- 1000
    if (!is.finite(gx)) gx <- 12
    if (!is.finite(gy)) gy <- 12
    fw <- min(max(fw, 300), 6000)
    fh <- min(max(fh, 300), 6000)
    gx <- min(max(gx, 0), 300)
    gy <- min(max(gy, 0), 300)

    source_ids <- unique(unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
    }), use.names = FALSE))
    source_ids <- source_ids[nzchar(source_ids)]
    ids <- unique(unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) {
        if (identical(as.character(cell$source_type %||% "internal_graph"), "internal_graph")) as.character(cell$id %||% "") else ""
      }, character(1))
    }), use.names = FALSE))
    ids <- ids[nzchar(ids)]

    # v3.4.0-alpha1: Panel labels are position-owned, not Graph-owned.
    # Swapping Graphs therefore keeps A/B/C/D on the Figure positions.
    # Panel labels are slot-owned.  Use the row-major slot ordinal rather than
    # the number of currently occupied cells so Shift through a blank cannot
    # create duplicate automatic labels (for example two "E" panels).
    slot_index <- 0L
    label_state_changed <- FALSE
    for (rr in seq_along(layout)) {
      for (cc in seq_along(layout[[rr]]$cells)) {
        slot_index <- slot_index + 1L
        cell <- layout[[rr]]$cells[[cc]]
        if (nzchar(as.character(cell$id %||% "")) &&
            !nzchar(as.character(cell$panel_label %||% "")) &&
            isTRUE(cell$panel_label_auto %||% TRUE)) {
          cell$panel_label <- if (slot_index <= length(LETTERS)) LETTERS[[slot_index]] else paste0("P", slot_index)
          cell$panel_label_auto <- TRUE
          layout[[rr]]$cells[[cc]] <- cell
          label_state_changed <- TRUE
        }
      }
    }
    if (label_state_changed) figure_layout_state(layout)

    # Source-specific Figure overrides retain crop/legend/inset/alignment state.
    drafts <- figure_override_drafts()
    changed <- FALSE
    for (id in source_ids) {
      if (is.null(drafts[[id]])) {
        drafts[[id]] <- figure_default_override(id)
        changed <- TRUE
      }
    }
    if (changed) figure_override_drafts(drafts)

    current_sel <- isolate(figure_selected_graph())
    if (length(source_ids) && !current_sel %in% source_ids) {
      figure_selected_graph(source_ids[[1]])
      # locate its current panel key
      key <- ""
      for (row in layout) {
        for (cell in row$cells %||% list()) {
          if (identical(as.character(cell$id %||% ""), source_ids[[1]])) key <- as.character(cell$key %||% "")
        }
      }
      figure_selected_panel_key(key)
    } else if (!length(source_ids) && nzchar(current_sel)) {
      figure_selected_graph("")
      figure_selected_panel_key("")
    }

    # Phase 8: Row height and per-panel width ratio are Fixed-canvas-only
    # inputs.  In Auto fit they do not participate in geometry, so strip them
    # from the *derived geometry request* while keeping the authored values in
    # figure_layout_state().  This prevents a Fixed-only edit from invalidating
    # the entire Auto-fit geometry/preview pipeline.
    layout_for_geometry <- layout
    if (identical(size_mode, "auto")) {
      layout_for_geometry <- lapply(layout_for_geometry, function(row) {
        row$height <- 1
        row$cells <- lapply(row$cells %||% list(), function(cell) {
          cell$width <- 1
          cell
        })
        row
      })
    }
    figure_requested_layout(layout_for_geometry)
    figure_requested_width(fw)
    figure_requested_height(fh)
    figure_requested_gap_x(gx)
    figure_requested_gap_y(gy)
    figure_requested_size_mode(size_mode)
    figure_requested_size_basis(size_basis)
    figure_requested_title_align(title_align)
    figure_requested_layout_mode(layout_mode)
    # Auto-fit policy has a single owner in its dedicated observer below.
    figure_requested_external_assets(isolate(figure_external_assets()))
    figure_requested_ids(ids)
    figure_requested_overrides(figure_visible_requested_overrides(drafts))
  })

  # Figure専用overrideは保存ボタンなしで即時反映。ただし、ggplotの
  # 再生成が必要な項目だけ別signatureへ切り出す。Labelの文字/位置/サイズ
  # などoverlay-only変更ではplot outputsを無効化しない。
  observe({
    drafts <- figure_override_drafts()
    visible_overrides <- figure_visible_requested_overrides(drafts)
    figure_requested_overrides(visible_overrides)

    sig <- lapply(visible_overrides, function(z) {
      ov <- modifyList(figure_default_override(), z %||% list())
      source_ov <- figure_layer_source_override(ov)
      list(
        # F1-4d: only the source Graph geometry belongs in the ggplot/SVG
        # signature. Detached legend x/y are Figure-layer placement state and
        # must not regenerate the Graph every time the user drops the legend.
        # The detached flag is retained so entering a layer prepares the
        # separate legend-free body exactly once.
        detached = figure_legend_is_detached(ov),
        legend = as.character(source_ov$legend %||% "inherit"),
        legend_title = figure_normalize_legend_title_mode(source_ov$legend_title),
        legend_background = figure_detached_legend_background_mode(ov),
        legend_gap = suppressWarnings(as.numeric(source_ov$legend_gap %||% 8)),
        legend_x = suppressWarnings(as.numeric(source_ov$legend_x %||% 0.72)),
        legend_y = suppressWarnings(as.numeric(source_ov$legend_y %||% 0.08)),
        appearance = ov$appearance %||% figure_default_appearance_override()
      )
    })
    old <- isolate(figure_plot_overrides())
    if (!identical(old, sig)) {
      changed_ids <- union(names(old), names(sig))
      for (id in changed_ids) {
        if (!identical(old[[id]], sig[[id]])) {
          cur <- isolate(figure_plot_revisions[[id]] %||% 0L)
          figure_plot_revisions[[id]] <- as.integer(cur) + 1L
        }
      }
      figure_plot_overrides(sig)
    }
  })

  # Figure Graph loading is cache-first. A persisted packaged SVG is already a
  # complete display snapshot, so assigning/reloading that Graph in Figure must
  # not instantiate graphServer merely to reproduce the same picture.
  #
  # Priority:
  #   1) already-live/ready Graph -> refresh the Figure snapshot from live state
  #   2) persisted SVG preview   -> reuse it directly, no Graph hydrate
  #   3) no usable cache         -> direct GraphState calculation
  #
  # This preserves the meaning of "Graphを読み込む" after a Graph was edited: a
  # ready live module still wins over the older packaged preview.
  snapshot_ready_graph_for_figure <- function(id, strict_validate = FALSE, import_editor_state = FALSE, import_reason = "explicit-source-refresh", reload_editor = TRUE) {
    mod <- source_graph_module(id)
    if (is.null(mod) || !isTRUE(tryCatch(isolate(mod$ready()), error = function(e) FALSE))) {
      return(FALSE)
    }

    comp <- tryCatch({
      if (is.function(mod$figure_components)) isolate(mod$figure_components()) else NULL
    }, error = function(e) {
      diag_log("FIGURE-CACHE", paste0("live components ERROR: ", conditionMessage(e)), id = id)
      NULL
    })
    p <- tryCatch({
      if (is.list(comp) && !is.null(comp$plot)) comp$plot
      else if (is.function(mod$figure_plot)) isolate(mod$figure_plot())
      else isolate(mod$plot())
    }, error = function(e) {
      diag_log("FIGURE-CACHE", paste0("live plot ERROR: ", conditionMessage(e)), id = id)
      NULL
    })
    ex <- tryCatch({
      if (is.list(comp) && is.list(comp$meta)) comp$meta
      else if (is.function(mod$figure_meta)) isolate(mod$figure_meta())
      else isolate(mod$export())
    }, error = function(e) {
      diag_log("FIGURE-CACHE", paste0("live meta ERROR: ", conditionMessage(e)), id = id)
      NULL
    })

    if (is.null(p) || !is.list(ex)) return(FALSE)
    # GraphState ownership stays canonical. The source module contributes only
    # the rendered plot/export snapshot; Figure editor state is seeded from the
    # Registry so an otherwise-current materializer can never reintroduce stale
    # non-render metadata (for example Statistics recipes or project fields).
    source_state <- if (cache_has(id)) cache_get(id) else NULL
    # v3.46: a live Graph becoming READY is not permission to overwrite the
    # Figure-owned editable GraphState.  Import source state only at an explicit
    # selected-panel refresh or explicit bulk Figure import boundary.
    if (isTRUE(import_editor_state) && is.list(source_state)) {
      seed_figure_editor_from_source(
        id, source_state, reason = import_reason, reload_editor = reload_editor
      )
    } else if (is.list(source_state) && id %in% names(isolate(figure_edit_states()))) {
      diag_log("FIGURE-SOURCE-SYNC", "ignored automatic graph snapshot; Figure-owned state preserved", id = id)
    }
    epw <- suppressWarnings(as.numeric(ex$panel_width_px %||% NA_real_)[1])
    eph <- suppressWarnings(as.numeric(ex$panel_height_px %||% NA_real_)[1])
    if (!is.finite(epw) || epw <= 0 || !is.finite(eph) || eph <= 0) return(FALSE)
    # Strict gtable remeasurement is only required for Figure -> source commit
    # confirmation. Ordinary Figure loading already has a READY Graph plus valid
    # export geometry metadata; revalidating every selected Graph synchronously
    # made the single R thread block for seconds per Graph.
    if (isTRUE(strict_validate)) {
      validated <- tryCatch(
        figure_plot_for_scale(p, figure_default_override(id), ex, 1),
        error = function(e) {
          diag_log("FIGURE-CACHE", paste0("commit validation ERROR: ", conditionMessage(e)), id=id)
          NULL
        }
      )
      if (is.null(validated) || !identical(validated$geometry_source %||% "unknown", "gtable")) return(FALSE)
    }
    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    assets <- isolate(figure_loaded_assets())
    plots[[id]] <- p
    exports[[id]] <- ex
    assets[[id]] <- figure_make_internal_asset(id, comp = comp, plot = p, meta = ex)
    figure_loaded_plots(plots)
    figure_loaded_exports(exports)
    figure_loaded_assets(assets)
    refresh_figure_geometry_source_revision(id, source_state)
    bump_figure_snapshot_revision(id)
    # Figure owns this point-in-time source snapshot. Do not publish a
    # duplicate Graph SVG side cache: normal Graph rendering stays live-only.
    diag_log("FIGURE-CACHE", "LIVE-HIT refreshed Figure-owned snapshot", id = id)
    TRUE
  }

  capture_inset_snapshot_from_ready_graph <- function(owner_id, source_id, reason = "inset-update") {
    owner_id <- as.character(owner_id %||% "")[1]
    source_id <- as.character(source_id %||% "")[1]
    if (!nzchar(owner_id) || !nzchar(source_id)) return(FALSE)

    mod <- source_graph_module(source_id)
    if (is.null(mod) || !isTRUE(mod$ready())) return(FALSE)

    # F1-5p: Inset refresh must be completely independent from the Main Panel
    # Figure snapshot. Do NOT call snapshot_ready_graph_for_figure() here: that
    # would overwrite a Figure-edited Main Graph copy when the same source Graph
    # is also used by an Inset. Capture plot/meta directly from the source module.
    comp <- tryCatch({
      if (is.function(mod$figure_components)) isolate(mod$figure_components()) else NULL
    }, error=function(e) NULL)
    inset_plot <- tryCatch({
      if (is.list(comp) && !is.null(comp$plot)) comp$plot
      else if (is.function(mod$figure_plot)) isolate(mod$figure_plot())
      else isolate(mod$plot())
    }, error=function(e) NULL)
    inset_export <- tryCatch({
      if (is.list(comp) && is.list(comp$meta)) comp$meta
      else if (is.function(mod$figure_meta)) isolate(mod$figure_meta())
      else isolate(mod$export())
    }, error=function(e) NULL)
    if (is.null(inset_plot) || !is.list(inset_export)) return(FALSE)

    # Materialize the vector snapshot directly into Figure ownership. The
    # Graph workspace no longer maintains an SVG cache, so Inset refresh must
    # never transit through the retired Graph SVG cache.
    source_state <- if (cache_has(source_id)) cache_get(source_id) else NULL
    render_revision <- if (is.function(mod$render_revision)) {
      tryCatch(isolate(mod$render_revision()), error = function(e) NA_integer_)
    } else NA_integer_
    rec <- tryCatch(
      graph_preview_record_from_plot(
        id = source_id,
        state = source_state,
        plot = inset_plot,
        export_meta = inset_export,
        render_revision = render_revision,
        reason = reason
      ),
      error = function(e) NULL
    )
    if (!is.list(rec) || !nzchar(rec$svg %||% "")) return(FALSE)
    rec$figure_plot <- inset_plot
    rec$figure_export <- inset_export

    inset_cache <- isolate(figure_inset_preview_cache())
    inset_cache[[source_id]] <- rec
    figure_inset_preview_cache(inset_cache)

    # The Inset layer depends on the source snapshot revision, so this invalidates
    # only consumers of that explicit snapshot rather than following every Graph
    # render.
    bump_figure_snapshot_revision(source_id)
    diag_log(
      "FIGURE-INSET",
      paste0(
        "explicit snapshot owner=", owner_id,
        " source=", source_id,
        " chars=", nchar(rec$svg %||% ""),
        " source_revision=", suppressWarnings(as.integer(rec$render_revision %||% NA_integer_)[1])
      ),
      id = owner_id
    )
    TRUE
  }

  observeEvent(input$figure_inset_refresh, {
    owner_id <- as.character(isolate(figure_selected_graph() %||% ""))[1]
    if (!nzchar(owner_id)) {
      showNotification("更新するPanelを選択してください。", type = "warning", duration = 3)
      return()
    }

    ovs <- isolate(figure_requested_overrides())
    ov <- figure_override_for(owner_id, ovs)
    inset <- ov$inset %||% figure_default_inset()
    source_id <- as.character(inset$source_id %||% "")[1]
    if (!isTRUE(inset$enabled) || !nzchar(source_id)) {
      showNotification("Inset sourceを選択して有効化してください。", type = "warning", duration = 3)
      return()
    }

    ext <- isolate(figure_requested_external_assets())
    if (source_id %in% names(ext %||% list())) {
      # External assets are already immutable Figure-side objects; there is no
      # Graph workspace source to refresh.
      showNotification("外部AssetのInsetは現在のFigure Assetをそのまま使用します。", type = "message", duration = 2)
      return()
    }

    if (capture_inset_snapshot_from_ready_graph(owner_id, source_id)) {
      figure_inset_refresh_target(list(owner_id = "", source_id = ""))
      showNotification("InsetをGraphから更新しました。", type = "message", duration = 2)
      return()
    }

    # Dormant Graph: build from canonical values synchronously. The Inset
    # snapshot does not borrow the Figure editor or overwrite the Main copy.
    expected_revision <- request_figure_inset_snapshot(
      owner_id, source_id, reason = "figure-inset-explicit-refresh"
    )
    figure_inset_refresh_target(list(
      owner_id = owner_id, source_id = source_id, revision = expected_revision
    ))
    diag_log(
      "FIGURE-INSET",
      paste0("explicit refresh queued direct state revision=", expected_revision),
      id = source_id
    )
    showNotification("Inset source Graphを読み込み中です。", type = "message", duration = 2)
  }, ignoreInit = TRUE)

  observe({
    figure_source_snapshot_generation()
    target <- figure_inset_refresh_target()
    owner_id <- as.character(target$owner_id %||% "")[1]
    source_id <- as.character(target$source_id %||% "")[1]
    expected_revision <- suppressWarnings(as.integer(target$revision %||% NA_integer_))
    if (!nzchar(owner_id) || !nzchar(source_id) || !is.finite(expected_revision)) return()

    completed <- figure_source_snapshot_completed_revision(
      source_id, target_type = "inset", owner_id = owner_id
    )
    if (completed < expected_revision) return()
    rec <- isolate(figure_inset_preview_cache())[[source_id]]
    figure_inset_refresh_target(list(owner_id = "", source_id = "", revision = NA_integer_))
    if (!figure_source_snapshot_success(source_id, "inset", owner_id) ||
        is.null(rec) || !isTRUE(valid_graph_preview_record(rec))) {
      diag_log("FIGURE-INSET", "explicit direct state refresh failed", id = source_id)
      showNotification("Inset sourceのsnapshotを作成できませんでした。", type = "warning", duration = 3)
      return()
    }
    showNotification("InsetをGraphから更新しました。", type = "message", duration = 2)
  })

  observeEvent(input$figure_graph_refresh_selected, {
    id <- as.character(isolate(figure_selected_graph() %||% ""))[1]
    key <- as.character(isolate(figure_selected_panel_key() %||% ""))[1]
    if (!nzchar(id) || !nzchar(key)) {
      showNotification("更新するFigure Panelを選択してください。", type = "message", duration = 2)
      return()
    }

    ext <- isolate(figure_external_assets())
    if (id %in% names(ext)) {
      showNotification("外部AssetはGraphから更新できません。", type = "warning", duration = 3)
      return()
    }

    # This action means "take the current Graph state now".  Do not satisfy it
    # from a packaged/persisted Figure snapshot.  A READY Graph is snapshotted
    # immediately; a dormant Graph is replayed through the one persistent Figure renderer.
    clear_figure_svg_cache()
    if (isTRUE(snapshot_ready_graph_for_figure(id, import_editor_state = TRUE, import_reason = "selected-panel-refresh", reload_editor = TRUE))) {
      figure_panel_refresh_target(list(id = "", key = ""))
      diag_log("FIGURE-PANEL-REFRESH", paste0("LIVE-HIT key=", key), id = id)
      showNotification("選択PanelをGraphから更新しました。", type = "message", duration = 2)
      return()
    }

    expected_revision <- request_figure_source_snapshot(
      id, reason = "figure-panel-explicit-refresh", import_editor_state = TRUE
    )
    figure_panel_refresh_target(list(id = id, key = key, revision = expected_revision))
    diag_log("FIGURE-PANEL-REFRESH", paste0("queued Figure direct state build key=", key, " revision=", expected_revision), id = id)
    showNotification("選択PanelのGraphを読み込み中です。", type = "message", duration = 2)
  }, ignoreInit = TRUE)

  observe({
    figure_source_snapshot_generation()
    target <- figure_panel_refresh_target()
    id <- as.character(target$id %||% "")[1]
    key <- as.character(target$key %||% "")[1]
    expected <- suppressWarnings(as.integer(target$revision %||% NA_integer_))
    if (!nzchar(id) || !is.finite(expected)) return()
    if (figure_source_snapshot_completed_revision(id) < expected) return()

    figure_panel_refresh_target(list(id = "", key = "", revision = NA_integer_))
    if (!figure_source_snapshot_success(id) || !isTRUE(figure_editor_snapshot_available(id))) {
      diag_log("FIGURE-PANEL-REFRESH", paste0("failed after direct state build key=", key), id = id)
      showNotification("選択PanelのGraph snapshotを作成できませんでした。", type = "warning", duration = 3)
      return()
    }

    diag_log("FIGURE-PANEL-REFRESH", paste0("READY-SNAPSHOT key=", key, " mode=direct-state"), id = id)
    showNotification("選択PanelをGraphから更新しました。", type = "message", duration = 2)
  })

  observeEvent(input$figure_graph_load, {
    # Main Figure Graph refresh only.  Inset sources have their own explicit
    # update action and must not be refreshed as a side effect of this button.
    ids <- as.character(isolate(figure_requested_ids()))
    close_figure_load_progress()
    if (!length(ids)) {
      figure_queue(character(0))
      figure_load_pending(FALSE)
      figure_load_target_ids(character(0))
      return()
    }

    # Freeze requested IDs for this explicit load run.
    figure_load_target_ids(ids)
    clear_figure_svg_cache()

    persisted <- isolate(figure_persisted_previews())
    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    assets <- isolate(figure_loaded_assets())
    fallback_ids <- character(0)
    fallback_expected <- list()

    diag_log("FIGURE-CACHE", paste0("load request ids=", paste(ids, collapse = ",")))

    for (id in ids) {
      # A ready live Graph is authoritative because it may contain edits newer
      # than the packaged SVG. Snapshot it without rebuilding the module.
      if (snapshot_ready_graph_for_figure(id, import_editor_state = TRUE, import_reason = "bulk-import-live", reload_editor = FALSE)) {
        # Helper updates the reactive snapshot registries; keep the local copies
        # in sync so the final assignment below cannot overwrite that refresh.
        plots <- isolate(figure_loaded_plots())
        exports <- isolate(figure_loaded_exports())
        assets <- isolate(figure_loaded_assets())
        next
      }

      # Even when the visual snapshot can be satisfied from persisted SVG, the
      # Figure needs its own editable GraphState copy. Canonical registry/cache
      # state is enough; no graphServer hydrate is required merely to create it.
      canonical_state <- tryCatch(cache_get(id), error = function(e) NULL)
      if (is.list(canonical_state)) {
        seed_figure_editor_from_source(
          id, canonical_state, reason = "bulk-import-canonical", reload_editor = FALSE
        )
      }

      rec <- persisted[[id]]
      cache_ok <- is.list(rec) && nzchar(rec$svg %||% "")
      if (cache_ok) {
        # Remove stale in-session live snapshots so renderer intentionally falls
        # through to figure_persisted_previews()[[id]].
        plots[[id]] <- NULL
        exports[[id]] <- NULL
        assets[[id]] <- NULL
        bump_figure_snapshot_revision(id)
        diag_log(
          "FIGURE-CACHE",
          paste0("HIT persisted SVG chars=", nchar(rec$svg %||% ""), " -> no instantiate"),
          id = id
        )
      } else {
        plots[[id]] <- NULL
        exports[[id]] <- NULL
        assets[[id]] <- NULL
        fallback_ids <- c(fallback_ids, id)
        fallback_expected[[id]] <- request_figure_source_snapshot(
          id, reason = "figure-cache-miss", import_editor_state = TRUE
        )
        diag_log("FIGURE-CACHE", "MISS no persisted SVG/live snapshot -> queued single Figure direct state build", id = id)
      }
    }

    figure_loaded_plots(plots)
    figure_loaded_exports(exports)
    figure_loaded_assets(assets)

    fallback_ids <- unique(fallback_ids)
    figure_load_expected_revisions(fallback_expected)
    if (!length(fallback_ids)) {
      figure_queue(character(0))
      figure_load_pending(FALSE)
      figure_load_target_ids(character(0))
      figure_load_expected_revisions(list())
      reload_selected_figure_editor_after_bulk(ids, reason = "bulk-import-cache-complete")
      diag_log("FIGURE-BULK-IMPORT", paste0("complete ids=", paste(ids, collapse = ","), " fallback=0"))
      showNotification("全GraphをFigureへ読み込みました。以後のGraph更新は自動反映されません。", type = "message", duration = 3)
      return()
    }

    prog <- shiny::Progress$new(session, min = 0, max = length(fallback_ids))
    prog$set(
      message = "Figure用Graphを読み込み中",
      value = 0,
      detail = paste0("cache miss 0 / ", length(fallback_ids), " Graph")
    )
    figure_load_progress(prog)
    # Only cache misses enter the Figure state calculation queue.
    figure_load_target_ids(fallback_ids)
    figure_load_pending(TRUE)
    figure_queue(fallback_ids)
  }, ignoreInit = TRUE)

  # One cache-miss Graph per turn; all plot inputs come from its frozen state.
  # The snapshot service has no editor/UI/restore dependency.
  observe({
    figure_source_snapshot_generation()
    pending <- figure_load_pending()
    q <- figure_queue()
    if (!isTRUE(pending) || !length(q)) return()

    id <- q[[1]]
    target_ids <- isolate(figure_load_target_ids())
    expected <- suppressWarnings(as.integer((isolate(figure_load_expected_revisions())[[id]]) %||% NA_integer_))
    if (!is.finite(expected)) {
      expected <- request_figure_source_snapshot(id, reason = "figure-cache-miss", import_editor_state = TRUE)
      exps <- isolate(figure_load_expected_revisions())
      exps[[id]] <- expected
      figure_load_expected_revisions(exps)
    }
    if (figure_source_snapshot_completed_revision(id) < expected) return()

    q2 <- q[-1]
    figure_queue(q2)
    done_n <- length(target_ids) - length(q2)
    prog <- isolate(figure_load_progress())
    if (!is.null(prog)) {
      try(prog$set(
        value = done_n,
        detail = paste0(done_n, " / ", length(target_ids), " Graph")
      ), silent = TRUE)
    }
    diag_log(
      "FIGURE-CACHE",
      paste0(
        if (isTRUE(figure_editor_snapshot_available(id))) "DIRECT-STATE READY" else "DIRECT-STATE FAILED",
        " revision=", expected
      ),
      id = id
    )
  })

  # Finalise only after every requested Graph has either produced a snapshot or
  # been attempted. Failed snapshots stay NULL and are reported in the status;
  # they never masquerade as successfully loaded panels.
  observe({
    pending <- figure_load_pending()
    q <- figure_queue()
    if (!isTRUE(pending) || length(q)) return()

    ids <- isolate(figure_load_target_ids())
    plots <- isolate(figure_loaded_plots())
    failed <- ids[!vapply(ids, function(id) !is.null(plots[[id]]), logical(1))]

    prog <- isolate(figure_load_progress())
    if (!is.null(prog)) {
      detail <- if (length(failed)) {
        paste0("完了 / 読み込み失敗 ", length(failed), " Graph")
      } else {
        "読み込み完了"
      }
      try(prog$set(value = length(ids), detail = detail), silent = TRUE)
    }

    figure_load_pending(FALSE)
    figure_load_target_ids(character(0))
    figure_load_expected_revisions(list())
    close_figure_load_progress()
    reload_selected_figure_editor_after_bulk(ids, reason = "bulk-import-fallback-complete")
    diag_log(
      "FIGURE-BULK-IMPORT",
      paste0("complete ids=", paste(ids, collapse = ","), " failed=", paste(failed, collapse = ","))
    )

    if (length(failed)) {
      meta <- isolate(graph_meta())
      nm <- meta$name[match(failed, meta$id)]
      nm[is.na(nm) | !nzchar(nm)] <- failed[is.na(nm) | !nzchar(nm)]
      showNotification(
        paste0("Figure用に読み込めなかったGraph: ", paste(nm, collapse = ", ")),
        type = "warning", duration = 6
      )
    } else {
      showNotification("全GraphをFigureへ読み込みました。以後のGraph更新は自動反映されません。", type = "message", duration = 3)
    }
  })

  # v3.3.69: source dimensions for content-driven geometry.  Auto Figure
  # sizing is anchored to the Graph-side *plot panel* dimensions, while the
  # full visual box (axes/titles/outside legend) is retained for the Figure
  # bounding box.  This keeps equal 600x600 panels visually equal even when
  # one Graph has a right/top legend.
  figure_source_sizes <- reactive({
    figure_geometry_revision()
    layout <- figure_requested_layout()
    ids <- unique(unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
    }), use.names = FALSE))
    ids <- ids[nzchar(ids)]
    internal_assets <- figure_loaded_assets()
    external_assets <- figure_requested_external_assets()
    previews <- figure_persisted_previews()
    exports <- figure_loaded_exports()
    plots <- figure_loaded_plots()
    ovs <- isolate(figure_requested_overrides())
    out <- list()

    for (id in ids) {
      if (id %in% names(external_assets)) {
        exa <- external_assets[[id]]
        mm <- exa$meta %||% list(width=600, height=600, panel_width=600, panel_height=600)
        ww <- suppressWarnings(as.numeric(mm$width %||% 600)[1]); if (!is.finite(ww) || ww <= 0) ww <- 600
        hh <- suppressWarnings(as.numeric(mm$height %||% 600)[1]); if (!is.finite(hh) || hh <= 0) hh <- 600
        pw <- suppressWarnings(as.numeric(mm$panel_width %||% ww)[1]); if (!is.finite(pw) || pw <= 0) pw <- ww
        ph <- suppressWarnings(as.numeric(mm$panel_height %||% hh)[1]); if (!is.finite(ph) || ph <= 0) ph <- hh
        bb <- list(left=0, top=0, width=pw, height=ph)
        out[[id]] <- list(
          width=ww, height=hh, panel_width=pw, panel_height=ph,
          panel_left=0, panel_top=0,
          panel_bbox=bb, facet_bbox=bb, axis_outer_bbox=bb,
          content_outer_bbox=bb, title_bbox=list(left=NA_real_,top=NA_real_,width=0,height=0),
          legend_bbox=list(left=NA_real_,top=NA_real_,width=0,height=0),
          legend_visual_bbox=list(left=NA_real_,top=NA_real_,width=0,height=0),
          legend_outside_bbox=list(left=NA_real_,top=NA_real_,width=0,height=0),
          legend_outside_visual_bbox=list(left=NA_real_,top=NA_real_,width=0,height=0),
          legend_state="unknown", geometry_source="external_asset"
        )
        next
      }

      asset <- internal_assets[[id]]
      p_raw <- asset$plot %||% plots[[id]]
      ex <- asset$meta %||% exports[[id]] %||% list(
        panel_width_px = 600, panel_height_px = 600, reference_res = 120
      )
      ov <- figure_override_for(id, ovs)
      geometry_revision <- figure_geometry_source_revisions[[id]] %||% 0L
      bootstrap_deferred <- isTRUE(isolate(figure_geometry_bootstrap_deferred()))
      workspace_dormant <- !figure_workspace_is_active()
      # v3.72.13: hidden Figure UI is allowed to remain materialized, but source
      # gtable measurement is a Figure-workspace responsibility. While Graph is
      # active, use persisted/cached metadata only so Graph selection/editor
      # hydration does not compete with Figure geometry work.
      measurement_deferred <- isTRUE(bootstrap_deferred || workspace_dormant)
      measured <- if (measurement_deferred) NULL else figure_measure_source_geometry_cached(
        id = id,
        geometry_revision = geometry_revision,
        p_raw = p_raw,
        ov = ov,
        ex = ex
      )
      meta <- if (!is.null(measured)) {
        list(
          width = measured$width, height = measured$height,
          panel_left = measured$panel_left, panel_top = measured$panel_top,
          panel_width = measured$panel_width, panel_height = measured$panel_height,
          panel_bbox = measured$panel_bbox, facet_bbox = measured$facet_bbox,
          axis_outer_bbox = measured$axis_outer_bbox,
          content_outer_bbox = measured$content_outer_bbox,
          title_bbox = measured$title_bbox,
          legend_bbox = measured$legend_bbox,
          legend_visual_bbox = measured$legend_visual_bbox %||% measured$legend_bbox,
          legend_outside_bbox = measured$legend_outside_bbox,
          legend_outside_visual_bbox = measured$legend_outside_visual_bbox %||% measured$legend_outside_bbox,
          legend_state = measured$legend_state %||% "unknown",
          geometry_source = measured$geometry_source %||% "unknown"
        )
      } else {
        if (measurement_deferred) {
          reason <- if (workspace_dormant) "workspace dormant" else "project bootstrap"
          diag_log("FIGURE-GEOMETRY-DEFER", paste0(reason, "; persisted metadata used; gtable measurement skipped"), id = id)
        }
        # Persisted detached/free previews carry a dedicated legend-free body.
        # Use that body for the owner footprint during dormant/project-bootstrap
        # geometry, while keeping mapped legend bboxes only for the overlay.
        persisted_meta <- figure_layer_persisted_owner_meta(previews[[id]], ov)
        asset$meta %||% persisted_meta %||% ex %||% list()
      }

      ww <- suppressWarnings(as.numeric(meta$width %||% meta$plot_width_px %||% 600)[1])
      hh <- suppressWarnings(as.numeric(meta$height %||% meta$plot_height_px %||% 600)[1])
      pw <- suppressWarnings(as.numeric(meta$panel_width %||% meta$panel_width_px %||% ex$panel_width_px %||% 600)[1])
      ph <- suppressWarnings(as.numeric(meta$panel_height %||% meta$panel_height_px %||% ex$panel_height_px %||% 600)[1])
      pl <- suppressWarnings(as.numeric(meta$panel_left %||% 0)[1])
      pt <- suppressWarnings(as.numeric(meta$panel_top %||% 0)[1])
      if (!is.finite(ww) || ww <= 0) ww <- 600
      if (!is.finite(hh) || hh <= 0) hh <- 600
      if (!is.finite(pw) || pw <= 0) pw <- 600
      if (!is.finite(ph) || ph <= 0) ph <- 600
      if (!is.finite(pl)) pl <- 0
      if (!is.finite(pt)) pt <- 0
      out[[id]] <- list(
        width = ww, height = hh, panel_width = pw, panel_height = ph,
        panel_left = pl, panel_top = pt,
        panel_bbox = meta$panel_bbox, facet_bbox = meta$facet_bbox,
        axis_outer_bbox = meta$axis_outer_bbox, content_outer_bbox = meta$content_outer_bbox,
        title_bbox = meta$title_bbox,
        legend_bbox = meta$legend_bbox, legend_visual_bbox = meta$legend_visual_bbox %||% meta$legend_bbox,
        legend_outside_bbox = meta$legend_outside_bbox, legend_outside_visual_bbox = meta$legend_outside_visual_bbox %||% meta$legend_outside_bbox,
        legend_state = meta$legend_state %||% "unknown",
        geometry_source = meta$geometry_source %||% "unknown"
      )

      bbox_sig <- function(z) {
        if (!is.list(z)) return("none")
        vals <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
        if (length(vals) != 4L || any(!is.finite(vals)) || vals[3] <= 0 || vals[4] <= 0) return("none")
        paste0(round(vals[1], 1), ",", round(vals[2], 1), ",", round(vals[3], 1), "x", round(vals[4], 1))
      }
      panel_sig <- bbox_sig(meta$panel_bbox)
      facet_sig <- bbox_sig(meta$facet_bbox)
      axis_sig <- bbox_sig(meta$axis_outer_bbox)
      title_sig <- bbox_sig(meta$title_bbox)
      legend_sig <- bbox_sig(meta$legend_bbox)
      legend_visual_sig <- bbox_sig(meta$legend_visual_bbox %||% meta$legend_bbox)
      outside_legend_sig <- bbox_sig(meta$legend_outside_bbox)
      geom_key <- paste(id, panel_sig, facet_sig, axis_sig, title_sig, legend_sig, legend_visual_sig, outside_legend_sig, meta$geometry_source %||% "", sep = "|")
      if (!exists(geom_key, envir = diag_graph_geometry_seen, inherits = FALSE)) {
        assign(geom_key, TRUE, envir = diag_graph_geometry_seen)
        diag_log("GRAPH-GEOMETRY", paste0(
          "panel=", panel_sig, " facet=", facet_sig, " axis_outer=", axis_sig,
          " title=", title_sig,
          " legend=", legend_sig, " legend_visual=", legend_visual_sig, " legend_outside=", outside_legend_sig,
          " source=", meta$geometry_source %||% "unknown"
        ), id = id)
        if (!identical(meta$geometry_source %||% "unknown", "gtable")) {
          diag_log("GRAPH-GEOMETRY-FALLBACK", "gtable geometry unavailable; using legacy/fallback dimensions", id = id)
        }
      }
      gkey <- paste(id, round(pw, 1), round(ph, 1), round(ww, 1), round(hh, 1), sep = "|")
      if (!exists(gkey, envir = diag_graph_size_meta_seen, inherits = FALSE)) {
        assign(gkey, TRUE, envir = diag_graph_size_meta_seen)
        diag_log("GRAPH-SIZE-META", paste0(
          "plot_panel=", round(pw, 1), "x", round(ph, 1),
          " visual=", round(ww, 1), "x", round(hh, 1),
          " panel_offset=", round(pl, 1), ",", round(pt, 1)
        ), id = id)
      }
      outside <- ov$legend %in% c("right", "left", "top", "bottom")
      side_extra <- switch(ov$legend,
        right = max(0, ww - (pl + pw)), left = max(0, pl), top = max(0, pt),
        bottom = max(0, hh - (pt + ph)), 0
      )
      lkey <- paste(id, ov$legend, round(ww, 1), round(hh, 1), round(pw, 1), round(ph, 1), sep = "|")
      if (!exists(lkey, envir = diag_figure_legend_bbox_seen, inherits = FALSE)) {
        assign(lkey, TRUE, envir = diag_figure_legend_bbox_seen)
        diag_log("FIGURE-LEGEND-BBOX", paste0(
          "legend=", ov$legend, " outside=", outside,
          " panel=", round(pw, 1), "x", round(ph, 1),
          " visual=", round(ww, 1), "x", round(hh, 1),
          if (outside) paste0(" side_extra=", round(side_extra, 1)) else ""
        ), id = id)
      }
    }
    out
  })

  figure_geometry_live <- reactive({
    figure_geometry_revision()
    layout <- figure_requested_layout()
    geo_ovs <- isolate(figure_requested_overrides())
    mode <- figure_requested_size_mode()
    basis <- figure_requested_size_basis()
    if (!basis %in% c("plot", "facet", "axis", "axis_legend")) basis <- "plot"
    title_align <- figure_requested_title_align()
    if (!title_align %in% c("none", "row_top")) title_align <- "none"
    gx <- figure_requested_gap_x()
    gy <- figure_requested_gap_y()
    layout_mode <- figure_requested_layout_mode()
    if (!layout_mode %in% c("row", "free")) layout_mode <- "row"
    if (identical(layout_mode, "free")) {
      source_sizes <- figure_source_sizes()
      seeded <- figure_seed_free_geometry(
        layout,
        row_rects = if (identical(mode, "auto")) {
          figure_auto_layout_geometry(layout, source_sizes, geo_ovs, gx, gy, figure_auto_outer_margin(), size_basis = basis, title_align = title_align)$rects
        } else {
          figure_layout_rects(layout, figure_requested_width(), figure_requested_height(), gx, gy)
        }
      )
      geo <- figure_free_layout_geometry(
        seeded, source_sizes, geo_ovs,
        canvas_w = figure_requested_width(), canvas_h = figure_requested_height(),
        padding = figure_requested_free_padding(), size_basis = basis
      )
      diag_log("FIGURE-FREE-GEOMETRY", paste0(
        "canvas=", round(geo$canvas_width,1), "x", round(geo$canvas_height,1),
        " panels=", length(geo$rects)
      ))
      return(geo)
    }
    if (identical(mode, "auto")) {
      source_sizes <- figure_source_sizes()
      geo <- figure_auto_layout_geometry(
        layout, source_sizes, geo_ovs,
        gx, gy, figure_auto_outer_margin(), size_basis = basis, title_align = title_align
      )
      geo <- figure_expand_auto_canvas_for_free_legends(geo, source_sizes, geo_ovs)
      for (rect in geo$rects %||% list()) {
        id <- as.character(rect$id %||% "")
        if (!nzchar(id)) next
        bw <- suppressWarnings(as.numeric(rect$basis_width %||% NA_real_)[1])
        bh <- suppressWarnings(as.numeric(rect$basis_height %||% NA_real_)[1])
        sc <- suppressWarnings(as.numeric(rect$basis_scale %||% NA_real_)[1])
        vw <- suppressWarnings(as.numeric(rect$width %||% NA_real_)[1])
        src <- source_sizes[[id]] %||% list()
        base_vh <- suppressWarnings(as.numeric(src$height %||% NA_real_)[1])
        vh <- if (is.finite(base_vh) && is.finite(sc)) base_vh * sc else NA_real_
        rect_basis <- as.character(rect$size_basis %||% basis)[1]
        agl <- suppressWarnings(as.numeric(rect$axis_common_left %||% NA_real_)[1])
        agt <- suppressWarnings(as.numeric(rect$axis_common_top %||% NA_real_)[1])
        agr <- suppressWarnings(as.numeric(rect$axis_common_right %||% NA_real_)[1])
        agb <- suppressWarnings(as.numeric(rect$axis_common_bottom %||% NA_real_)[1])
        sig <- paste(id, rect$key %||% "", rect_basis, round(bw, 1), round(bh, 1), round(sc, 4), round(vw, 1), round(vh, 1),
                     round(agl, 1), round(agt, 1), round(agr, 1), round(agb, 1), sep = "|")
        if (!exists(sig, envir = diag_figure_size_basis_seen, inherits = FALSE)) {
          assign(sig, TRUE, envir = diag_figure_size_basis_seen)
          diag_log(
            "FIGURE-SIZE-BASIS",
            paste0(
              "mode=", rect_basis,
              " requested=", basis,
              " row=", rect$row %||% "",
              " key=", rect$key %||% "",
              " basis=", if (is.finite(bw)) round(bw, 1) else "NA", "x", if (is.finite(bh)) round(bh, 1) else "NA",
              " scale=", if (is.finite(sc)) round(sc, 4) else "NA",
              " visual=", if (is.finite(vw)) round(vw, 1) else "NA", "x", if (is.finite(vh)) round(vh, 1) else "NA",
              if (identical(rect_basis, "axis") && all(is.finite(c(agl, agt, agr, agb)))) {
                paste0(" shared_gutter=", round(agl, 1), ",", round(agt, 1), ",", round(agr, 1), ",", round(agb, 1))
              } else ""
            ), id = id
          )
        }
      }
      row_sig <- if (length(geo$rows)) paste(vapply(geo$rows, function(z) {
        paste0("r", z$row, "=", round(z$width, 1), "x", round(z$height, 1), "[", z$count, ",", z$size_basis %||% basis, "]")
      }, character(1)), collapse = ";") else "none"
      key <- paste0(round(geo$canvas_width, 1), "x", round(geo$canvas_height, 1), "|", basis, "|", title_align, "|", row_sig)
      if (!exists(key, envir = diag_figure_autofit_seen, inherits = FALSE)) {
        assign(key, TRUE, envir = diag_figure_autofit_seen)
        diag_log("FIGURE-AUTOFIT", paste0(
          "mode=auto content_bbox=", round(geo$content_width, 1), "x", round(geo$content_height, 1),
          " canvas=", round(geo$canvas_width, 1), "x", round(geo$canvas_height, 1),
          " title_align=", title_align,
          " rows=", row_sig
        ))
      }
      return(geo)
    }
    cw <- figure_requested_width()
    ch <- figure_requested_height()
    source_sizes <- figure_source_sizes()
    geo <- figure_fixed_basis_layout_geometry(
      layout, source_sizes, geo_ovs,
      canvas_w = cw, canvas_h = ch, gap_x = gx, gap_y = gy, size_basis = basis,
      title_align = title_align
    )
    rects <- geo$rects %||% list()
    fit_sig <- if (length(rects)) paste(vapply(rects, function(z) {
      rf <- suppressWarnings(as.numeric(z$fixed_basis_fit_scale %||% NA_real_)[1])
      paste0(z$key %||% "", "=", if (is.finite(rf)) round(rf, 4) else "na")
    }, character(1)), collapse=",") else "none"
    key <- paste0("fixed|", round(cw, 1), "x", round(ch, 1), "|", basis, "|", title_align, "|", fit_sig)
    if (!exists(key, envir = diag_figure_autofit_seen, inherits = FALSE)) {
      assign(key, TRUE, envir = diag_figure_autofit_seen)
      diag_log("FIGURE-AUTOFIT", paste0(
        "mode=fixed canvas=", round(cw, 1), "x", round(ch, 1),
        " basis=", basis, " title_align=", title_align,
        " panels=", length(rects), " row_fit={", fit_sig, "}"
      ))
    }
    geo
  })

  # v3.4.0-alpha2: optional Auto-fit freeze. Fixed canvas always remains live.
  figure_geometry_manual <- eventReactive(figure_autofit_revision(), {
    isolate(figure_geometry_live())
  }, ignoreInit = FALSE)

  figure_geometry <- reactive({
    if (!identical(figure_requested_size_mode(), "auto")) return(figure_geometry_live())
    policy <- figure_requested_autofit_policy()
    if (identical(policy, "live")) return(figure_geometry_live())
    figure_rebind_frozen_geometry(figure_geometry_manual(), figure_requested_layout())
  })

  observeEvent(input$figure_refit_now, {
    policy <- isolate(figure_requested_autofit_policy())
    if (identical(policy, "lock")) {
      showNotification("Layout Lock中です。ManualまたはLiveへ切り替えてください。", type="message", duration=2)
      return()
    }
    figure_autofit_revision(isolate(figure_autofit_revision()) + 1L)
    diag_log("FIGURE-AUTOFIT-POLICY", paste0("refit policy=", policy))
  }, ignoreInit=TRUE)

  observeEvent(input$figure_autofit_policy, {
    policy <- as.character(input$figure_autofit_policy %||% "live")[1]
    if (!policy %in% c("live","manual","lock")) policy <- "live"
    restore_seed <- isolate(figure_control_restore_seed())
    if (!is.null(restore_seed)) {
      target <- as.character(restore_seed$autofit_policy %||% "live")[1]
      diag_log("FIGURE-AUTOFIT-POLICY", paste0(
        "restore-gated input=", policy, " target=", target
      ))
      return()
    }
    old <- isolate(figure_requested_autofit_policy())
    if (identical(old, policy)) return()
    # Capture the current live geometry only when leaving Live. Manual <-> Lock
    # preserves the existing frozen rects; switching Lock to Manual must not
    # unexpectedly refit a layout the user explicitly froze.
    if (identical(old, "live") && policy %in% c("manual","lock")) {
      figure_autofit_revision(isolate(figure_autofit_revision()) + 1L)
    }
    figure_requested_autofit_policy(policy)
    diag_log("FIGURE-AUTOFIT-POLICY", paste0("policy=", old, "->", policy))
  }, ignoreInit=TRUE)

  figure_preview_ready <- reactive({
    figure_queue()
    figure_load_pending()
    layout <- figure_requested_layout()
    all_sources <- unique(unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
    }), use.names=FALSE))
    all_sources <- all_sources[nzchar(all_sources)]
    if (!length(all_sources)) return(FALSE)
    ids <- figure_requested_ids()
    plots <- figure_loaded_plots()
    persistent <- figure_persisted_previews()
    ext <- figure_requested_external_assets()
    graphs_ok <- all(vapply(ids, function(id) !is.null(plots[[id]]) || !is.null(persistent[[id]]), logical(1)))
    assets_ok <- all(vapply(setdiff(all_sources, ids), function(id) id %in% names(ext), logical(1)))
    isTRUE(graphs_ok) && isTRUE(assets_ok)
  })

  output$figure_preview_status <- renderText({
    operation <- figure_explicit_load_status()
    if (nzchar(operation)) return(operation)
    ids <- figure_requested_ids()
    ext <- figure_requested_external_assets()
    layout <- figure_requested_layout()
    all_sources <- unique(unlist(lapply(layout, function(row) {
      vapply(row$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
    }), use.names=FALSE))
    all_sources <- all_sources[nzchar(all_sources)]
    if (!length(all_sources)) return("FigureにGraph / Assetを配置してください。")

    if (isTRUE(figure_load_pending()) || length(figure_queue())) {
      plots_now <- figure_loaded_plots()
      persistent_now <- figure_persisted_previews()
      ready_n <- sum(vapply(ids, function(id) {
        !is.null(plots_now[[id]]) || !is.null(persistent_now[[id]])
      }, logical(1)))
      return(paste0("Graphを読み込み中… ", ready_n, " / ", length(ids),
                    "  | Asset ", sum(setdiff(all_sources, ids) %in% names(ext)), " / ", length(setdiff(all_sources, ids))))
    }

    plots <- figure_loaded_plots()
    persistent <- figure_persisted_previews()
    loaded_n <- sum(vapply(ids, function(id) !is.null(plots[[id]]) || !is.null(persistent[[id]]), logical(1)))
    asset_ids <- setdiff(all_sources, ids)
    asset_n <- sum(asset_ids %in% names(ext))
    if (loaded_n == length(ids) && asset_n == length(asset_ids)) {
      paste0(
        "準備済み（Graph ", loaded_n, " / ", length(ids), "・Asset ", asset_n, " / ", length(asset_ids), "） ",
        round(figure_geometry()$canvas_width), " × ", round(figure_geometry()$canvas_height), " px ",
        "[", if (identical(figure_requested_layout_mode(), "free")) "Free" else "Row", "] ",
        if (identical(figure_requested_size_mode(), "auto")) paste0("[Canvas Auto: ", switch(figure_requested_autofit_policy(), live="常時追従", manual="手動更新", lock="固定", "常時追従"), "]") else "[Canvas Fixed]",
        if (identical(figure_requested_size_mode(), "auto")) paste0(
          " [基準: ", switch(figure_requested_size_basis(), plot = "Plot", facet = "Facet", axis = "軸ラベル", axis_legend = "軸＋凡例", "Plot"), "]"
        ) else "",
        if (identical(figure_requested_title_align(), "row_top")) " [Graph title: Row上端揃え]" else ""
      )
    } else {
      paste0("未準備sourceがあります（Graph ", loaded_n, "/", length(ids), "・Asset ", asset_n, "/", length(asset_ids), "）")
    }
  })

  # ------------------------------------------------------------------
  # Figure Preview rendering
  # ------------------------------------------------------------------
  # v3.3.48 performance experiment:
  # - The outer canvas depends only on layout/canvas geometry.
  # - Each occupied cell owns its own reactive plot spec and UI output.
  # - A legend/style override increments only that Graph's revision, therefore
  #   only that Panel is rebuilt.
  # - Label text/position/size are browser overlays and are updated through a
  #   custom message without re-running ggplot at all.
  # This is an intermediate step toward the future SVG-layer editor while
  # keeping the current ggplot/grob export path intact.

  # Experimental vector preview ------------------------------------------------
  # The ggplot remains authoritative; this SVG is only a browser display cache.
  # v3.3.50 embeds the generated SVG inline in the panel DOM. Layout-only edits
  # reuse the cached source SVG and only change CSS geometry.
  # v3.3.56: figure_plot_svg_text moved to its Figure module.

  figure_live_base_asset <- function(id, p_raw, ov, ex, snapshot_revision, plot_revision) {
    if (is.null(p_raw)) return(NULL)
    key <- paste0("base::", as.character(id))
    sig <- paste(
      as.character(id),
      as.integer(snapshot_revision %||% 0L),
      as.integer(plot_revision %||% 0L),
      sep = "|"
    )
    cached <- if (exists(key, envir = figure_svg_cache, inherits = FALSE)) {
      get(key, envir = figure_svg_cache, inherits = FALSE)
    } else NULL
    if (is.list(cached) && identical(cached$signature, sig)) return(cached)

    render_ov <- figure_layer_source_override(ov)
    rendered <- tryCatch(figure_plot_for_scale(p_raw, render_ov, ex, 1), error = function(e) NULL)
    if (is.null(rendered) || is.null(rendered$plot)) return(NULL)
    svg <- figure_plot_svg_text(
      rendered$plot,
      rendered$width,
      rendered$height,
      reference_res = ex$reference_res %||% 120
    )

    # Layer preparation keeps one stable source-side anchor only for guide-box
    # extraction, plus a second legend-free Graph body for actual owner sizing.
    # Preview therefore never needs to keep or clip the old side-legend strip.
    body_rendered <- NULL
    body_svg <- ""
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
        body_ov <- render_ov; body_ov$legend <- "none"
        body_rendered <- tryCatch(figure_plot_for_scale(p_raw, body_ov, ex, 1), error=function(e) NULL)
        if (is.list(body_rendered) && !is.null(body_rendered$plot)) {
          body_svg <- figure_plot_svg_text(
            body_rendered$plot, body_rendered$width, body_rendered$height,
            reference_res = ex$reference_res %||% 120
          )
        }
      } else {
        # Never make a legend disappear merely because detach extraction failed.
        # Keep the combined source SVG visible and diagnose the fallback; a
        # later successful materialization can still create the free layer.
        legend_asset <- NULL
        diag_log(
          "FIGURE-LEGEND-DETACH-FALLBACK",
          paste0("source_origin=", figure_legend_source_origin(ov), " reason=legend-asset-unavailable"),
          id=id
        )
      }
    }
    body_meta <- if (is.list(body_rendered)) list(
      width=body_rendered$width, height=body_rendered$height,
      panel_left=body_rendered$panel_left, panel_top=body_rendered$panel_top,
      panel_width=body_rendered$panel_width, panel_height=body_rendered$panel_height,
      panel_bbox=body_rendered$panel_bbox, facet_bbox=body_rendered$facet_bbox,
      axis_outer_bbox=body_rendered$axis_outer_bbox, content_outer_bbox=body_rendered$content_outer_bbox,
      title_bbox=body_rendered$title_bbox,
      legend_bbox=body_rendered$legend_bbox, legend_visual_bbox=body_rendered$legend_visual_bbox,
      legend_outside_bbox=body_rendered$legend_outside_bbox,
      legend_outside_visual_bbox=body_rendered$legend_outside_visual_bbox
    ) else NULL

    ans <- list(
      signature = sig,
      svg = svg,
      body_svg = body_svg,
      body_meta = body_meta,
      legend_svg = if (is.list(legend_asset)) legend_asset$svg %||% "" else "",
      legend_width = if (is.list(legend_asset)) legend_asset$width %||% NA_real_ else NA_real_,
      legend_height = if (is.list(legend_asset)) legend_asset$height %||% NA_real_ else NA_real_,
      legend_guide_box = if (is.list(legend_asset)) legend_asset$guide_box_name %||% "" else "",
      legend_guide_candidates = if (is.list(legend_asset)) legend_asset$guide_box_candidates %||% NA_integer_ else NA_integer_,
      plot = rendered$plot,
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
    assign(key, ans, envir = figure_svg_cache)
    ans
  }
  # v3.3.56: figure_fit_cached_geometry moved to its Figure module.
  # v3.3.56: figure_persisted_spec_for_rect moved to its Figure module.
  # v3.3.56: figure_build_cell_ui moved to its Figure module.

  # Create one output pair per occupied layout cell. Re-running this observer on
  # a structural layout change simply rebinds the currently visible cell keys;
  # stale outputs are harmless because their UI hosts no longer exist.
  observe({
    layout <- figure_requested_layout()
    if (!length(layout)) return()
    geo <- figure_geometry()
    canvas_w <- geo$canvas_width
    canvas_h <- geo$canvas_height
    rects <- geo$rects
    if (!length(rects)) return()

    for (rr in rects) {
      id0 <- as.character(rr$id %||% "")
      if (!nzchar(id0)) next

      local({
        rect <- rr
        id <- id0
        cell_ui_id <- paste0("figure_cell_ui_", rect$key)
        inset_layer_ui_id <- paste0("figure_cell_inset_layer_", rect$key)
        legend_layer_ui_id <- paste0("figure_cell_legend_layer_", rect$key)
        label_layer_ui_id <- paste0("figure_cell_label_layer_", rect$key)
        plot_output_id <- paste0("figure_cell_plot_", rect$key)

        spec_r <- reactive({
          # v3.73.1.6 reorder ownership guard: output ids are slot-keyed and
          # therefore reused after Shift/Swap. A stale closure from the former
          # owner must never paint into a slot that now belongs to another source.
          current_owner <- figure_layout_source_at_key(figure_requested_layout(), rect$key)
          if (!identical(as.character(current_owner %||% ""), as.character(id %||% ""))) return(NULL)
          # Per-Graph revision is the targeted invalidation key for overrides.
          figure_plot_revisions[[id]]
          figure_snapshot_revisions[[id]]
          assets <- isolate(figure_loaded_assets())
          external_assets <- isolate(figure_requested_external_assets())
          external_asset <- external_assets[[id]]
          asset <- assets[[id]]
          plots <- isolate(figure_loaded_plots())
          p_raw <- asset$plot %||% plots[[id]]
          exports <- isolate(figure_loaded_exports())
          ex <- external_asset$meta %||% asset$meta %||% exports[[id]] %||% list(
            plot_width_px = 600, plot_height_px = 600,
            panel_width_px = 600, panel_height_px = 600,
            reference_res = 120
          )
          # The revision above guarantees reactivity; isolate the full override
          # list so another Graph's edit cannot invalidate this Panel.
          ov <- figure_apply_slot_label_to_override(
            figure_override_for(id, isolate(figure_requested_overrides())), rect
          )
          if (!is.null(external_asset)) {
            sp <- figure_fit_cached_geometry(external_asset$meta %||% ex, rect, ov)
            if (is.null(sp)) return(NULL)
            sp$external_asset <- external_asset
            sp$svg_text <- external_asset$svg %||% ""
          } else if (!is.null(p_raw)) {
            use_svg_now <- isTRUE(input$figure_svg_preview %||% TRUE)
            if (!isTRUE(use_svg_now)) {
              # Raster/plot fallback must be generated at the same scale used by
              # its geometry. A 1x fixed-panel ggplot inside a 2x device is not
              # equivalent to whole-SVG scaling. Keep plot + geometry as a pair.
              sp <- tryCatch(figure_plot_spec_for_rect_whole_scale(p_raw, ov, ex, rect), error=function(e) NULL)
              if (is.null(sp)) return(NULL)
              sp$svg_text <- ""
            } else {
              base <- figure_live_base_asset(
                id, p_raw, ov, ex,
                isolate(figure_snapshot_revisions[[id]] %||% 0L),
                isolate(figure_plot_revisions[[id]] %||% 0L)
              )
              if (is.null(base)) return(NULL)
              detached_now <- figure_legend_is_detached(ov)
              # F1-4g: detached legends no longer reserve their old right/left/
              # top/bottom strip. Fit the owner Graph from the legend-free body.
              fit_meta <- if (isTRUE(detached_now) && is.list(base$body_meta)) base$body_meta else base$meta
              sp <- figure_fit_cached_geometry(fit_meta, rect, ov)
              if (is.null(sp)) return(NULL)
              sp$svg_text <- base$svg
              if (isTRUE(detached_now) && is.list(base$body_meta)) {
                sc_leg <- suppressWarnings(as.numeric(sp$scale %||% 1)[1])
                if (!is.finite(sc_leg) || sc_leg <= 0) sc_leg <- 1
                # Preserve source-legend location in the new body coordinate
                # system for the initial detach; manual placement is Graph-relative.
                sp$legend_bbox <- figure_layer_scale_bbox(
                  figure_layer_map_bbox_to_body(base$meta, base$body_meta, base$meta$legend_bbox), sc_leg
                )
                sp$legend_visual_bbox <- figure_layer_scale_bbox(
                  figure_layer_map_bbox_to_body(base$meta, base$body_meta, base$meta$legend_visual_bbox %||% base$meta$legend_bbox), sc_leg
                )
                sp$legend_outside_bbox <- figure_layer_scale_bbox(
                  figure_layer_map_bbox_to_body(base$meta, base$body_meta, base$meta$legend_outside_bbox), sc_leg
                )
                sp$legend_outside_visual_bbox <- figure_layer_scale_bbox(
                  figure_layer_map_bbox_to_body(base$meta, base$body_meta, base$meta$legend_outside_visual_bbox %||% base$meta$legend_outside_bbox), sc_leg
                )
                sp$legend_state <- base$meta$legend_state %||% sp$legend_state
              }
              if (isTRUE(detached_now) && nzchar(base$legend_svg %||% "")) {
                sp$legend_svg_text <- base$legend_svg
                sc_leg <- suppressWarnings(as.numeric(sp$scale %||% 1)[1])
                if (!is.finite(sc_leg) || sc_leg <= 0) sc_leg <- 1
                lw <- suppressWarnings(as.numeric(base$legend_width %||% NA_real_)[1])
                lh <- suppressWarnings(as.numeric(base$legend_height %||% NA_real_)[1])
                if (is.finite(lw) && lw > 0) sp$legend_layer_width <- lw * sc_leg
                if (is.finite(lh) && lh > 0) sp$legend_layer_height <- lh * sc_leg
                sp$legend_guide_box <- as.character(base$legend_guide_box %||% "")
                sp$legend_guide_candidates <- suppressWarnings(as.integer(base$legend_guide_candidates %||% NA_integer_)[1])
              }
              if (isTRUE(detached_now) && nzchar(base$body_svg %||% "") && is.list(base$body_meta)) {
                sp$body_svg_text <- base$body_svg
                sp$body_geometry <- figure_scale_geometry_meta(base$body_meta, sp$scale %||% 1)
                if (is.list(sp$body_geometry)) {
                  # The fitted geometry is already the body geometry, so there
                  # is no source-side legend offset to compensate.
                  sp$body_left <- 0
                  sp$body_top <- 0
                  sp$layer_body_mode <- "separate-svg"
                }
              } else if (isTRUE(detached_now)) {
                sp$layer_body_mode <- "persisted-or-strip-fallback"
              } else {
                sp$layer_body_mode <- "combined-svg"
              }
              # If SVG generation fails, use a rect-specific plot and its own
              # matching geometry instead of mixing cached 1x plot + scaled box.
              if (!nzchar(base$svg %||% "")) {
                sp <- tryCatch(figure_plot_spec_for_rect_whole_scale(p_raw, ov, ex, rect), error=function(e) NULL)
                if (is.null(sp)) return(NULL)
                sp$svg_text <- ""
              } else {
                sp$plot <- NULL
              }
            }
          } else {
            persisted <- isolate(figure_persisted_previews())[[id]]
            sp <- figure_persisted_spec_for_rect(persisted, rect, ov)
            if (!is.null(sp)) {
              vkey <- paste0("figure:", rect$key, ":", id, ":", round(rect$width, 1), "x", round(rect$height, 1))
              if (!exists(vkey, envir = diag_svg_viewport_seen, inherits = FALSE)) {
                assign(vkey, TRUE, envir = diag_svg_viewport_seen)
                diag_log("SVG-VIEWPORT", paste0("Figure key=", rect$key, " cell=", round(rect$width, 1), "x", round(rect$height, 1), " fitted=", round(sp$width, 1), "x", round(sp$height, 1), " contain=TRUE"), id = id)
              }
            }
          }
          if (is.null(sp)) return(NULL)
          sp$id <- id
          sp$rect <- rect

          # v3.3.67 diagnostics: Graph target size is independent from the
          # Panel allocation. NA means legacy Auto sizing.
          gw <- suppressWarnings(as.numeric(rect$graph_width %||% NA_real_)[1])
          gh <- suppressWarnings(as.numeric(rect$graph_height %||% NA_real_)[1])
          target_label <- paste0(
            if (is.finite(gw)) round(gw, 1) else "Auto", "x",
            if (is.finite(gh)) round(gh, 1) else "Auto"
          )

          # v3.3.66 diagnostics: distinguish the Figure panel frame from the
          # fitted plot frame. Log once per geometry so layout edits remain
          # readable instead of flooding the console.
          frame_key <- paste0(
            rect$key, ":", id, ":",
            round(rect$width, 1), "x", round(rect$height, 1), ":",
            round(sp$width, 1), "x", round(sp$height, 1), ":",
            "legend=", as.character(ov$legend %||% "inherit")[1], ":",
            "origin=", figure_legend_source_origin(ov), ":",
            "pr=", isolate(figure_plot_revisions[[id]] %||% 0L), ":",
            "sr=", isolate(figure_snapshot_revisions[[id]] %||% 0L)
          )
          if (!exists(frame_key, envir = diag_figure_frame_seen, inherits = FALSE)) {
            assign(frame_key, TRUE, envir = diag_figure_frame_seen)
            off <- figure_plot_offsets(rect, sp, ov)
            diag_log(
              "FIGURE-GRAPH-SIZE",
              paste0(
                "key=", rect$key, " target=", target_label,
                " basis_scale=", if (is.finite(suppressWarnings(as.numeric(rect$basis_scale %||% NA_real_)[1]))) round(as.numeric(rect$basis_scale), 4) else "NA",
                " rendered=", round(sp$width, 1), "x", round(sp$height, 1)
              ),
              id = id
            )
            diag_log(
              "FIGURE-PANEL",
              paste0("key=", rect$key, " panel=", round(rect$width, 1), "x", round(rect$height, 1)),
              id = id
            )
            diag_log(
              "FIGURE-PLOT-FRAME",
              paste0(
                "key=", rect$key, " left=", round(off$dx, 1), " top=", round(off$dy, 1),
                " frame=", round(sp$width, 1), "x", round(sp$height, 1), " clip=TRUE"
              ),
              id = id
            )
            diag_log(
              "FIGURE-ASSET-FIT",
              paste0(
                "key=", rect$key, " source=", id,
                " fitted=", round(sp$width, 1), "x", round(sp$height, 1),
                " contain=TRUE"
              ),
              id = id
            )
            leg_vis <- figure_layer_valid_bbox(sp$legend_visual_bbox %||% sp$legend_bbox)
            owner_frame <- figure_graph_display_frame(rect, sp, ov)
            rel_txt <- if (!figure_legend_is_detached(ov)) {
              "n/a"
            } else if (isTRUE(ov$legend_free_auto)) {
              "auto"
            } else {
              paste0(
                round(suppressWarnings(as.numeric(ov$legend_free_x %||% ov$legend_x %||% 0.75)[1]), 4), ",",
                round(suppressWarnings(as.numeric(ov$legend_free_y %||% ov$legend_y %||% 0.08)[1]), 4)
              )
            }
            diag_log(
              "FIGURE-LAYER",
              paste0(
                "key=", rect$key,
                " legend_scope=", figure_legend_layer_scope(ov),
                " legend_mode=", as.character(ov$legend %||% "inherit"),
                " source_origin=", figure_legend_source_origin(ov),
                " body_mode=", as.character(sp$layer_body_mode %||% if (figure_legend_is_detached(ov)) "fallback" else "combined")[1],
                " owner_frame=", round(owner_frame$x,1), ",", round(owner_frame$y,1), ",", round(owner_frame$width,1), "x", round(owner_frame$height,1),
                " rel=", rel_txt,
                " legend_visual=", if (is.null(leg_vis)) "none" else paste0(round(leg_vis$left,1), ",", round(leg_vis$top,1), ",", round(leg_vis$width,1), "x", round(leg_vis$height,1)),
                " legend_asset=", if (nzchar(sp$legend_svg_text %||% "")) paste0(round(sp$legend_layer_width %||% NA_real_,1), "x", round(sp$legend_layer_height %||% NA_real_,1)) else "none",
                " guide_box=", if (nzchar(as.character(sp$legend_guide_box %||% ""))) as.character(sp$legend_guide_box) else "none",
                " candidates=", if (is.finite(suppressWarnings(as.numeric(sp$legend_guide_candidates %||% NA_real_)[1]))) as.integer(sp$legend_guide_candidates) else "NA"
              ),
              id=id
            )
          }
          sp
        })

        output[[cell_ui_id]] <- renderUI({
          figure_panel_display_revisions[[id]]
          sp <- spec_r()
          if (is.null(sp)) return(div(class = "figure-cell-unloaded", "未読み込み"))
          ov <- figure_apply_slot_label_to_override(
            figure_override_for(id, isolate(figure_requested_overrides())),
            rect
          )
          use_svg <- isTRUE(input$figure_svg_preview %||% TRUE)
          # Persisted package preview is shown even when the experimental toggle
          # is OFF if the Graph has not yet been lazily restored; otherwise the
          # panel would be blank despite having a valid saved preview.
          svg_text <- if (nzchar(sp$persisted_svg %||% "")) {
            sp$persisted_svg
          } else if (isTRUE(use_svg)) {
            sp$svg_text %||% NULL
          } else NULL
          effective_svg <- isTRUE(use_svg) || (is.null(sp$plot) && nzchar(svg_text %||% ""))
          ex_assets_now <- isolate(figure_requested_external_assets())
          ext_main <- sp$external_asset %||% NULL
          ext_legend <- figure_external_legend_asset(ext_main, ex_assets_now)
          figure_build_cell_ui(
            rect, sp, ov, svg_text = svg_text, use_svg = effective_svg,
            external_asset = ext_main,
            external_legend_asset = ext_legend
          )
        })

        # F1-5: Inset is a Figure-canvas layer, not a Panel child. It follows
        # the owner Graph display frame and may cross Panel boundaries.
        output[[inset_layer_ui_id]] <- renderUI({
          figure_panel_display_revisions[[id]]
          sp <- spec_r()
          if (is.null(sp)) return(NULL)
          ov <- figure_apply_slot_label_to_override(
            figure_override_for(id, isolate(figure_requested_overrides())), rect
          )
          inset <- ov$inset %||% figure_default_inset()
          inset_id <- as.character(inset$source_id %||% "")[1]
          if (!isTRUE(inset$enabled) || !nzchar(inset_id)) return(NULL)

          ex_assets_now <- isolate(figure_requested_external_assets())
          inset_asset <- ex_assets_now[[inset_id]]
          inset_svg <- NULL
          inset_source_kind <- if (!is.null(inset_asset)) "external-asset" else "none"
          inset_source_revision <- NA_integer_
          inset_source_plot_type <- ""
          if (is.null(inset_asset)) {
            # F1-5b explicit snapshot contract: an internal Inset never follows
            # the retired Graph SVG cache directly.  Its source changes only when the
            # user presses the Inset update action.  A persisted Figure preview
            # remains the cache-first fallback after Project reload.
            figure_snapshot_revisions[[inset_id]]
            inset_rec <- figure_inset_preview_cache()[[inset_id]]
            figure_rec <- figure_persisted_previews()[[inset_id]]
            rec <- NULL
            if (is.list(inset_rec) && nzchar(inset_rec$svg %||% "")) {
              rec <- inset_rec
              inset_source_kind <- "figure-inset-explicit"
            } else if (is.list(figure_rec) && nzchar(figure_rec$svg %||% "")) {
              rec <- figure_rec
              inset_source_kind <- "figure-preview-persisted-fallback"
            }
            if (is.list(rec)) {
              inset_svg <- rec$svg %||% NULL
              inset_source_revision <- suppressWarnings(as.integer(rec$render_revision %||% NA_integer_)[1])
              st2 <- rec$state %||% NULL
              if (is.list(st2)) inset_source_plot_type <- as.character(st2$plot_type %||% "")[1]
            }
          }
          ipos <- figure_layer_inset_canvas_position(rect, sp, ov)
          if (!is.null(ipos)) {
            diag_log(
              "FIGURE-INSET",
              paste0(
                "key=", rect$key,
                " source=", inset_id,
                " source_kind=", inset_source_kind,
                " source_revision=", if (is.finite(inset_source_revision)) inset_source_revision else "NA",
                " source_plot_type=", if (nzchar(inset_source_plot_type)) inset_source_plot_type else "NA",
                " anchor=owner-graph",
                " rel=", round(ipos$rel_x,4), ",", round(ipos$rel_y,4), ",", round(ipos$rel_width,4), "x", round(ipos$rel_height,4),
                " canvas=", round(ipos$x,1), ",", round(ipos$y,1), ",", round(ipos$width,1), "x", round(ipos$height,1),
                " layer_z=", figure_layer_z("inset")
              ),
              id=id
            )
          }
          figure_build_inset_layer_ui(rect, sp, ov, inset_svg = inset_svg, inset_asset = inset_asset)
        })

        # F1-4 Figure Layer Model: detached legend and panel label are rendered
        # outside the Graph cell stacking context. A Figure-space legend can
        # therefore cross Panel boundaries without falling behind neighbours.
        output[[legend_layer_ui_id]] <- renderUI({
          figure_panel_display_revisions[[id]]
          sp <- spec_r()
          if (is.null(sp)) return(NULL)
          ov <- figure_apply_slot_label_to_override(
            figure_override_for(id, isolate(figure_requested_overrides())), rect
          )
          if (!figure_legend_is_detached(ov)) return(NULL)
          svg_text <- if (nzchar(sp$persisted_svg %||% "")) sp$persisted_svg else sp$svg_text %||% NULL
          figure_build_detached_legend_layer_ui(rect, sp, ov, svg_text)
        })

        output[[label_layer_ui_id]] <- renderUI({
          figure_panel_display_revisions[[id]]
          sp <- spec_r()
          if (is.null(sp)) return(NULL)
          ov <- figure_apply_slot_label_to_override(
            figure_override_for(id, isolate(figure_requested_overrides())), rect
          )
          figure_build_label_layer_ui(rect, sp, ov)
        })

        output[[plot_output_id]] <- renderPlot({
          sp <- spec_r()
          shiny::req(!is.null(sp), !is.null(sp$plot))
          sp$plot
        },
        width = function() {
          sp <- spec_r()
          if (is.null(sp)) return(100)
          max(1, round(sp$raster_natural_width %||% sp$width))
        },
        height = function() {
          sp <- spec_r()
          if (is.null(sp)) return(100)
          max(1, round(sp$raster_natural_height %||% sp$height))
        },
        res = 120,
        execOnResize = FALSE)
      })
    }
  })

  output$figure_preview_area <- renderUI({
    layout <- figure_requested_layout()
    if (!length(layout)) return(NULL)

    geo <- figure_geometry()
    canvas_w <- geo$canvas_width
    canvas_h <- geo$canvas_height

    meta <- graph_meta()
    external_assets <- figure_requested_external_assets()
    rects <- geo$rects
    selected_key <- isolate(figure_selected_panel_key())

    grid_cells <- lapply(rects, function(rect) {
      id <- as.character(rect$id %||% "")
      base_style <- sprintf(
        "left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;z-index:%d;",
        rect$x, rect$y, rect$width, rect$height, as.integer(rect$z_index %||% rect$index %||% 1)
      )
      cell_class <- paste(
        "figure-grid-cell",
        if (identical(as.character(rect$key), as.character(selected_key))) "selected" else ""
      )

      if (!nzchar(id)) {
        return(div(
          class = paste(cell_class, "empty"), style = base_style,
          `data-figure-key` = rect$key, `data-figure-id` = "",
          "空白"
        ))
      }

      nm <- if (id %in% meta$id) meta$name[match(id, meta$id)] else if (id %in% names(external_assets)) external_assets[[id]]$name %||% id else id
      if (!length(nm) || is.na(nm) || !nzchar(nm)) nm <- id

      div(
        class = cell_class,
        style = base_style,
        `data-figure-key` = rect$key,
        `data-figure-id` = id,
        `data-figure-row` = as.character(rect$row %||% ""),
        `data-figure-col` = as.character(rect$col %||% ""),
        `data-cell-width` = sprintf("%.4f", rect$width),
        `data-cell-height` = sprintf("%.4f", rect$height),
        div(
          class = "figure-cell-ui-host",
          uiOutput(paste0("figure_cell_ui_", rect$key))
        ),
        div(class = "figure-cell-caption", title = nm, nm)
      )
    })

    session$sendCustomMessage("fit-figure-preview", list())

    div(
      class = "figure-preview-viewport",
      div(
        class = "figure-preview-stage",
        div(
          class = "figure-preview-canvas",
        `data-canvas-width` = as.character(round(canvas_w)),
        `data-canvas-height` = as.character(round(canvas_h)),
        `data-layout-mode` = as.character(figure_requested_layout_mode()),
        style = sprintf("width:%dpx;height:%dpx;", round(canvas_w), round(canvas_h)),
        div(class = "figure-canvas-graph-layer", div(class = "figure-preview-grid", grid_cells)),
        div(
          class = "figure-canvas-inset-layer",
          lapply(rects, function(rect) {
            if (!nzchar(as.character(rect$id %||% ""))) return(NULL)
            uiOutput(paste0("figure_cell_inset_layer_", rect$key))
          })
        ),
        div(
          class = "figure-canvas-legend-layer",
          lapply(rects, function(rect) {
            if (!nzchar(as.character(rect$id %||% ""))) return(NULL)
            uiOutput(paste0("figure_cell_legend_layer_", rect$key))
          })
        ),
        div(
          class = "figure-canvas-label-layer",
          lapply(rects, function(rect) {
            if (!nzchar(as.character(rect$id %||% ""))) return(NULL)
            uiOutput(paste0("figure_cell_label_layer_", rect$key))
          })
        ),
          div(class = "figure-canvas-interaction-layer")
        )
      )
    )
  })

  # ------------------------------------------------------------------
  # Export writers
  # ------------------------------------------------------------------
  # v3.3.56: figure_draw_to_device() moved to figure_export.R.

  write_figure_export <- function(path, format) {
    layout <- isolate(figure_requested_layout())
    overrides <- isolate(figure_requested_overrides())
    gap_x <- isolate(figure_requested_gap_x())
    gap_y <- isolate(figure_requested_gap_y())
    mode <- isolate(figure_requested_size_mode())

    # v3.3.70: Preview geometry is the single source of truth for Figure export.
    # Previously Auto-fit export rebuilt its own source-size table from cached
    # metadata, which could omit panel_width/panel_height and current legend
    # overrides. That produced a different canvas/rect allocation than Preview.
    preview_geo <- isolate(figure_geometry())
    canvas_w <- suppressWarnings(as.numeric(preview_geo$canvas_width)[1])
    canvas_h <- suppressWarnings(as.numeric(preview_geo$canvas_height)[1])
    export_rects <- preview_geo$rects %||% list()
    if (!is.finite(canvas_w) || canvas_w <= 0 || !is.finite(canvas_h) || canvas_h <= 0) {
      stop("Figure Preview geometryを取得できませんでした。")
    }

    # Graph export sources only. External Figure assets are validated separately
    # by figure_preview_ready() and rendered by figure_draw_to_device().
    ids <- unique(as.character(isolate(figure_requested_ids()) %||% character(0)))
    ids <- ids[nzchar(ids)]

    if (!length(ids)) {
      all_sources <- unique(unlist(lapply(layout, function(row) {
        vapply(row$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
      }), use.names = FALSE))
      all_sources <- all_sources[nzchar(all_sources)]
      if (!length(all_sources)) stop("FigureにGraph / Assetが配置されていません。")
    }
    if (!isTRUE(isolate(figure_preview_ready()))) stop("Figureに未読み込みのGraphがあります。「Graphを読み込む」を押してください。")

    diag_log(
      "FIGURE-EXPORT-GEOMETRY",
      paste0(
        "mode=", mode,
        " preview_canvas=", round(canvas_w, 1), "x", round(canvas_h, 1),
        " export_canvas=", round(canvas_w, 1), "x", round(canvas_h, 1),
        " rects=", length(export_rects)
      )
    )

    ref_res <- 120
    width_in <- canvas_w / ref_res
    height_in <- canvas_h / ref_res

    # F1-5m/F1-5o: SVG and PDF share the vector compositor. Persisted Figure
    # SVG Panels must stay as vector primitives; only PNG uses the grid/raster
    # compatibility path. PDF is produced from the composed vector SVG via
    # librsvg/Cairo PDF, never through figure_svg_snapshot_grob().
    vector_svg_mode <- identical(format, "svg")
    vector_pdf_mode <- identical(format, "pdf")
    vector_compositor_mode <- isTRUE(vector_svg_mode) || isTRUE(vector_pdf_mode)
    closed <- FALSE
    dev_id <- NA_integer_
    if (!isTRUE(vector_compositor_mode)) {
      app_open_png_device(
        filename = path, width_px = canvas_w, height_px = canvas_h, res = ref_res
      )
      dev_id <- grDevices::dev.cur()
      on.exit({
        if (!isTRUE(closed) && identical(grDevices::dev.cur(), dev_id)) {
          try(grDevices::dev.off(), silent = TRUE)
        }
      }, add = TRUE)
    }

    # Export must never silently drop a cache-first Figure Panel. Prefer the
    # in-session Figure plot snapshot when present; otherwise use the persisted
    # Figure SVG snapshot directly. Project packages intentionally do not persist
    # heavyweight ggplot/render R objects.
    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    persisted <- isolate(figure_persisted_previews())
    svg_fallback_ids <- character(0)
    missing_ids <- character(0)
    for (id in ids) {
      if (!is.null(plots[[id]])) next
      rec <- persisted[[id]] %||% list()
      ov_id <- figure_override_for(id, overrides)
      svg_ok <- nzchar(rec$svg %||% "")
      if (figure_legend_is_detached(ov_id)) {
        # Detached/free legends require the F1-5e separated body. Never revive
        # the obsolete full-height guide-strip fallback during export.
        svg_ok <- svg_ok && nzchar(rec$body_svg %||% "") && nzchar(rec$legend_svg %||% "")
      }
      if (isTRUE(svg_ok)) svg_fallback_ids <- c(svg_fallback_ids, id) else missing_ids <- c(missing_ids, id)
    }
    if (length(missing_ids)) {
      stop(paste0(
        "Figure export sourceが不足しています: ", paste(unique(missing_ids), collapse = ", "),
        "。該当PanelをGraphから更新してから再度保存してください。"
      ))
    }
    diag_log(
      "FIGURE-EXPORT-SOURCES",
      paste0(
        "live_plot=", length(setdiff(ids, svg_fallback_ids)),
        " persisted_svg=", length(svg_fallback_ids),
        if (length(svg_fallback_ids)) paste0(" svg_ids={", paste(svg_fallback_ids, collapse=","), "}") else ""
      )
    )
    if (length(svg_fallback_ids) && !isTRUE(vector_compositor_mode)) {
      for (id in svg_fallback_ids) {
        rec <- persisted[[id]] %||% list()
        ov_id <- figure_override_for(id, overrides)
        rect_id <- NULL
        for (rr in export_rects) {
          if (identical(as.character(rr$id %||% ""), id)) { rect_id <- rr; break }
        }
        sp_diag <- if (!is.null(rect_id)) tryCatch(
          figure_persisted_spec_for_rect(rec, rect_id, ov_id),
          error=function(e) NULL
        ) else NULL
        svg_diag_text <- if (is.list(sp_diag)) as.character(sp_diag$persisted_svg %||% "")[1] else ""
        svg_diag_w <- if (is.list(sp_diag)) sp_diag$width %||% NA_real_ else NA_real_
        svg_diag_h <- if (is.list(sp_diag)) sp_diag$height %||% NA_real_ else NA_real_
        dg <- tryCatch(
          figure_svg_snapshot_diagnostics(svg_diag_text, svg_diag_w, svg_diag_h),
          error=function(e) list(ok=FALSE, reason=paste0("diagnostic-error:", conditionMessage(e)))
        )
        diag_log(
          "FIGURE-SVG-RASTER-DIAG",
          paste0(
            "ok=", isTRUE(dg$ok),
            " size=", dg$width %||% NA, "x", dg$height %||% NA,
            " embedded_images=", dg$embedded_images %||% NA,
            " transparent_root=", dg$transparent_root %||% NA,
            " white_bg_rect=", dg$white_bg_rect %||% NA,
            " edge_band=", dg$edge_band %||% NA,
            " edge_total=", dg$edge_total %||% NA,
            " edge_transparent=", dg$edge_transparent %||% NA,
            " edge_partial=", dg$edge_partial %||% NA,
            " edge_opaque=", dg$edge_opaque %||% NA,
            " edge_min_nonzero=", dg$edge_min_nonzero %||% NA,
            " edge_max_partial=", dg$edge_max_partial %||% NA,
            " partial_pixels=", dg$partial_pixels %||% NA,
            " premultiplied_candidates=", dg$premultiplied_candidates %||% NA,
            " unpremultiplied=", dg$unpremultiplied %||% FALSE,
            if (!isTRUE(dg$ok)) paste0(" reason=", dg$reason %||% "unknown") else ""
          ),
          id=id
        )
      }
    }
    if (isTRUE(vector_compositor_mode)) {
      vector_svg_path <- if (isTRUE(vector_svg_mode)) path else tempfile("figure_vector_", fileext = ".svg")
      if (isTRUE(vector_pdf_mode)) {
        on.exit(try(unlink(vector_svg_path), silent = TRUE), add = TRUE)
      }
      draw_summary <- figure_write_svg_vector(
        vector_svg_path, layout, canvas_w, canvas_h, overrides, plots, exports, gap_x, gap_y,
        rects = export_rects,
        external_assets = isolate(figure_requested_external_assets()),
        inset_snapshots = isolate(figure_inset_preview_cache()),
        persisted_previews = persisted,
        reference_res = ref_res
      )
      if (isTRUE(vector_pdf_mode)) {
        if (!requireNamespace("rsvg", quietly = TRUE) ||
            !exists("rsvg_pdf", envir = asNamespace("rsvg"), inherits = FALSE)) {
          stop("Figure PDFのベクター出力には rsvg::rsvg_pdf() が必要です。rsvg パッケージを更新してください。")
        }
        svg_raw <- readBin(vector_svg_path, what = "raw", n = file.info(vector_svg_path)$size)
        tryCatch(
          rsvg::rsvg_pdf(svg_raw, file = path),
          error = function(e) stop("Figure PDFのベクター変換に失敗しました: ", conditionMessage(e))
        )
        diag_log(
          "FIGURE-PDF-VECTOR",
          paste0(
            "vector_compositor=TRUE converter=rsvg_pdf",
            " panels=", length(draw_summary$drawn_ids %||% character(0)),
            " persisted_vector=", length(draw_summary$persisted_svg_ids %||% character(0)),
            " textlength_removed=", as.integer(draw_summary$textlength_removed %||% 0L)
          )
        )
      } else {
        diag_log(
          "FIGURE-SVG-VECTOR",
          paste0(
            "vector_compositor=TRUE",
            " panels=", length(draw_summary$drawn_ids %||% character(0)),
            " persisted_vector=", length(draw_summary$persisted_svg_ids %||% character(0)),
            " illustrator_textlength_removed=", as.integer(draw_summary$textlength_removed %||% 0L)
          )
        )
      }
    } else {
      draw_summary <- figure_draw_to_device(
        layout, canvas_w, canvas_h, overrides, plots, exports, gap_x, gap_y,
        rects = export_rects,
        external_assets = isolate(figure_requested_external_assets()),
        inset_snapshots = isolate(figure_inset_preview_cache()),
        persisted_previews = persisted
      )
    }
    if (is.list(draw_summary) && length(draw_summary$missing_ids %||% character(0))) {
      stop(paste0(
        "Figure exportで描画できないPanelがありました: ",
        paste(unique(draw_summary$missing_ids), collapse = ", ")
      ))
    }
    if (is.list(draw_summary)) {
      not_drawn <- setdiff(ids, unique(as.character(draw_summary$drawn_ids %||% character(0))))
      if (length(not_drawn)) {
        stop(paste0(
          "Figure exportでPanelが出力されませんでした: ",
          paste(not_drawn, collapse = ", ")
        ))
      }
    }
    if (!isTRUE(vector_compositor_mode)) {
      grDevices::dev.off()
      closed <- TRUE
    }
    invisible(TRUE)
  }


  output$download_figure <- downloadHandler(
    filename = function() {
      fmt <- isolate(input$figure_export_format %||% "png")
      ext <- switch(fmt, png = "png", pdf = "pdf", svg = "svg", "png")
      paste0(safe_name(input$project_name, "Project"), "_Figure.", ext)
    },
    content = function(file) {
      fmt <- isolate(input$figure_export_format %||% "png")
      write_figure_export(file, fmt)
    }
  )

