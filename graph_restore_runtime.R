  # ============================================================
  # Settings save / load
  # ============================================================
  style_settings <- reactive({
    list(
      version = "3.3.41",
      schema_version = 2L,
      color_styles = color_styles(),
      linetype_styles = linetype_styles(),
      shape_styles = shape_styles(),
      series_styles = series_styles(),
      regression_styles = regression_styles(),
      raw_group_colors = raw_group_colors(),
      orders = order_state(),
      legend_titles = legend_titles(),
      level_labels = level_labels(),
      shared_library = shared_style_binding(),
      # v3.64.2-format-export1: axis range is part of the rendered Graph
      # formatting and should travel with Graph書式.  Axis/title text remains
      # Graph-specific content and is intentionally not copied here.
      axes = list(
        ymin = input$ymin,
        ymax = input$ymax,
        y_top_to_tick = input$y_top_to_tick
      ),
      appearance = list(
        series_style_override = input$series_style_override,
        palette_preset = input$palette_preset,
        raw_palette_preset = input$raw_palette_preset,
        scatter_regression = input$scatter_regression,
        scatter_regression_group = input$scatter_regression_group,
        scatter_regression_color = input$scatter_regression_color,
        scatter_regression_linetype = input$scatter_regression_linetype,
        scatter_regression_width = input$scatter_regression_width,
        scatter_regression_se = input$scatter_regression_se,
        scatter_regression_se_alpha = input$scatter_regression_se_alpha,
        theme = input$theme,
        # Persist the render-facing canonical font state. Browser Selectize
        # binding values may settle later, but equivalent UI materialisation
        # must not change GraphState/RenderState.
        font_family_mode = app_normalize_font_family_mode(font_family_mode_effective()),
        font_family_custom = app_normalize_font_family_custom(font_family_custom_effective()),
        base_size = input$base_size,
        summary_type = input$summary_type,
        summary_unit = input$summary_unit %||% "row",
        mean_color_mode = input$mean_color_mode,
        mean_linetype = input$mean_linetype,
        mean_shape = input$mean_shape,
        point_size = input$point_size,
        line_width = input$line_width,
        line_group_dodge = input$line_group_dodge,
        line_x_spacing = input$line_x_spacing,
        plot_width_px = effective_plot_width_px(),
        plot_height_px = effective_plot_height_px(),
        bar_width = input$bar_width,
        bar_zero_touch = input$bar_zero_touch,
        group_spacing = input$group_spacing,
        box_width_scale = input$box_width_scale,
        x_category_spacing = input$x_category_spacing,
        bar_border_mode = input$bar_border_mode,
        bar_border_color = input$bar_border_color,
        bar_border_width = input$bar_border_width,
        raw_color_mode = input$raw_color_mode,
        raw_fixed_custom = input$raw_fixed_custom,
        raw_lighten = input$raw_lighten,
        raw_alpha = input$raw_alpha,
        raw_shape_mode = input$raw_shape_mode,
        raw_shape = input$raw_shape,
        raw_point_size = input$raw_point_size,
        jitter_width = input$jitter_width,
        id_line_color_mode = input$id_line_color_mode,
        id_line_custom_color = input$id_line_custom_color,
        id_line_lighten = input$id_line_lighten,
        id_linetype = input$id_linetype,
        id_line_width = input$id_line_width,
        id_line_alpha = input$id_line_alpha,
        summary_on_top = input$summary_on_top,
        error_color_mode = input$error_color_mode,
        error_color = input$error_color,
        error_width = input$error_width,
        error_line_width = input$error_line_width,
        y_break_enabled = input$y_break_enabled,
        y_breaks_auto = input$y_breaks_auto,
        y_breaks_step = input$y_breaks_step,
        y_break_from = input$y_break_from,
        y_break_to = input$y_break_to,
        y_break_space = input$y_break_space,
        y_break_symbol = input$y_break_symbol,
        legend_pos = input$legend_pos,
        legend_key_width = input$legend_key_width,
        facet_spacing_x = input$facet_spacing_x
      )
    )
  })

  parse_style_tree <- function(x, kind) {
    out <- list(); if (is.null(x) || !length(x)) return(out)
    for (vn in names(x)) {
      br <- list(); src <- x[[vn]]
      for (lv in names(src)) {
        z <- unlist(src[[lv]], use.names = FALSE)
        if (!length(z)) next
        br[[lv]] <- if (identical(kind, "shape")) {
          q <- suppressWarnings(as.numeric(z[[1]])); if (is.finite(q)) q else 16
        } else as.character(z[[1]])
      }
      out[[vn]] <- br
    }
    out
  }

  legacy_mapping_vars <- function(mapping = NULL) {
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(mapping)) {
      cv <- if (!is.null(d)) resolve_color_var(d) else ""
      lv <- if (!is.null(d)) resolve_linetype_var(d) else ""
      sv <- if (!is.null(d)) resolve_shape_var(d) else ""
    } else {
      cv <- json_chr(mapping$color); if (!nzchar(cv)) cv <- json_chr(mapping$series)
      lm <- json_chr(mapping$linetype, "__color__"); lv <- if (identical(lm,"__color__")) cv else lm
      sm <- json_chr(mapping$shape, "__color__"); sv <- if (identical(sm,"__color__")) cv else sm
    }
    list(color=cv, linetype=lv, shape=sv)
  }

  json_safe_tree <- function(x) {
    # jsonliteのkeep_vec_names warningを避ける。
    # JSON objectとして保持したいnamed atomic vectorはnamed listへ変換する。
    if (is.data.frame(x)) {
      return(x)
    }

    if (is.atomic(x) && !is.null(names(x))) {
      nm <- names(x)
      if (length(nm) && any(nzchar(nm))) {
        out <- as.list(unname(x))
        names(out) <- nm
        return(out)
      }
      return(unname(x))
    }

    if (is.list(x)) {
      out <- lapply(x, json_safe_tree)
      names(out) <- names(x)
      return(out)
    }

    x
  }

  output$download_style <- downloadHandler(
    filename = function() paste0("ggplot_style_", Sys.Date(), ".json"),
    content = function(file) {
      cfg <- style_settings()
      # Shared Library bindings are Project-specific semantic links and must
      # not travel with a generic Graph-format file. Library definitions have
      # their own explicit import/export surface in Figure.
      cfg$shared_library <- NULL
      jsonlite::write_json(json_safe_tree(cfg), file, pretty = TRUE, auto_unbox = TRUE)
    }
  )

  apply_style_config <- function(cfg, success_message = "書式を適用しました。", release_guard = TRUE, notify = TRUE) {
    restoring_style_state(TRUE)
    restore_release_scheduled <- FALSE
    on.exit({
      # If any schema/type error occurs before the normal onFlushed release is
      # scheduled, never leave this Graph permanently frozen in restore mode.
      if (!isTRUE(restore_release_scheduled)) restoring_style_state(FALSE)
    }, add = TRUE)

    if (!is.null(cfg$color_styles)) color_styles(parse_style_tree(cfg$color_styles, "color"))
    if (!is.null(cfg$linetype_styles)) linetype_styles(parse_style_tree(cfg$linetype_styles, "linetype"))
    if (!is.null(cfg$shape_styles)) shape_styles(parse_style_tree(cfg$shape_styles, "shape"))
    if (is.null(cfg$color_styles) && !is.null(cfg$group_styles) && length(cfg$group_styles)) {
      mv <- legacy_mapping_vars(NULL)
      migrate_legacy_group_styles(cfg$group_styles, mv$color, mv$linetype, mv$shape)
    }

    if (!is.null(cfg$series_styles) && length(cfg$series_styles)) {
      ss <- list()
      for (nm in names(cfg$series_styles)) {
        st <- cfg$series_styles[[nm]]
        ss[[nm]] <- list(color = as.character(st$color %||% "#333333"))
      }
      series_styles(ss)
    }

    if (!is.null(cfg$regression_styles) && length(cfg$regression_styles)) {
      rs <- list()
      for (nm in names(cfg$regression_styles)) {
        st <- cfg$regression_styles[[nm]]
        rs[[nm]] <- list(
          color = json_chr(st$color, "#333333"),
          linetype = json_chr(st$linetype, "solid"),
          width = as.numeric(json_chr(st$width, "0.9"))
        )
      }
      regression_styles(rs)
    }

    if (!is.null(cfg$raw_group_colors) && length(cfg$raw_group_colors)) {
      # v3.1+: variable -> level -> color. Legacy flat level -> color is migrated.
      first_val <- cfg$raw_group_colors[[1]]
      if (is.list(first_val) && !is.null(names(first_val))) {
        raw_group_colors(parse_style_tree(cfg$raw_group_colors, "color"))
      } else {
        mv <- legacy_mapping_vars(NULL); rc <- list(); br <- list()
        for (nm in names(cfg$raw_group_colors)) br[[nm]] <- as.character(unlist(cfg$raw_group_colors[[nm]])[[1]])
        if (nzchar(mv$color)) rc[[mv$color]] <- br
        raw_group_colors(rc)
      }
    }

    if (!is.null(cfg$orders)) {
      os <- list(x = list(), group = list(), facet = list())
      if (!is.null(cfg$orders$x)) os$x <- cfg$orders$x
      if (!is.null(cfg$orders$group)) os$group <- cfg$orders$group
      if (!is.null(cfg$orders$facet)) os$facet <- cfg$orders$facet
      order_state(os)
    }

    if (!is.null(cfg$legend_titles)) {
      lt <- list()
      for (nm in names(cfg$legend_titles)) {
        lt[[nm]] <- json_chr(cfg$legend_titles[[nm]], "")
      }
      legend_titles(lt)
    }

    if (!is.null(cfg$level_labels)) {
      ll <- list()
      for (vn in names(cfg$level_labels)) {
        branch <- cfg$level_labels[[vn]]
        bb <- list()
        for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
        ll[[vn]] <- bb
      }
      level_labels(ll)
    }

    ax <- cfg$axes
    if (!is.null(ax)) {
      if (!is.null(ax$ymin)) updateTextInput(session, "ymin", value = json_chr(ax$ymin, ""))
      if (!is.null(ax$ymax)) updateTextInput(session, "ymax", value = json_chr(ax$ymax, ""))
      if (!is.null(ax$y_top_to_tick)) {
        updateCheckboxInput(session, "y_top_to_tick", value = isTRUE(ax$y_top_to_tick))
      }
    }

    a <- cfg$appearance
    apply_font_family_state_to_editor(a)
    if (!is.null(a)) {
      if (!is.null(a$series_style_override)) updateCheckboxInput(session, "series_style_override", value = isTRUE(a$series_style_override))
      if (!is.null(a$palette_preset)) updateSelectInput(session, "palette_preset", selected = json_chr(a$palette_preset))
      if (!is.null(a$raw_palette_preset)) updateSelectInput(session, "raw_palette_preset", selected = json_chr(a$raw_palette_preset))
      if (!is.null(a$scatter_regression)) updateCheckboxInput(session, "scatter_regression", value = isTRUE(a$scatter_regression))
      if (!is.null(a$scatter_regression_group)) updateSelectInput(session, "scatter_regression_group", selected = json_chr(a$scatter_regression_group))
      if (!is.null(a$scatter_regression_color)) colourpicker::updateColourInput(session, "scatter_regression_color", value = json_chr(a$scatter_regression_color))
      if (!is.null(a$scatter_regression_linetype)) updateSelectInput(session, "scatter_regression_linetype", selected = json_chr(a$scatter_regression_linetype))
      if (!is.null(a$scatter_regression_width)) updateSliderInput(session, "scatter_regression_width", value = as.numeric(a$scatter_regression_width))
      if (!is.null(a$scatter_regression_se)) updateCheckboxInput(session, "scatter_regression_se", value = isTRUE(a$scatter_regression_se))
      if (!is.null(a$scatter_regression_se_alpha)) updateSliderInput(session, "scatter_regression_se_alpha", value = as.numeric(a$scatter_regression_se_alpha))
      if (!is.null(a$theme)) updateSelectInput(session, "theme", selected = a$theme)
      if (!is.null(a$base_size)) updateSliderInput(session, "base_size", value = as.numeric(a$base_size))
      if (!is.null(a$summary_type)) updateSelectInput(session, "summary_type", selected = a$summary_type)
      if (!is.null(a$summary_unit)) {
        updateRadioButtons(session, "summary_unit", selected = json_chr(a$summary_unit, "row"))
      }
      if (!is.null(a$mean_color_mode)) {
        colourpicker::updateColourInput(session, "mean_color_mode", value = normalise_colour(a$mean_color_mode, "#000000"))
      }
      if (!is.null(a$mean_linetype)) updateSelectInput(session, "mean_linetype", selected = a$mean_linetype)
      if (!is.null(a$mean_shape)) updateSelectInput(session, "mean_shape", selected = as.character(a$mean_shape))
      if (!is.null(a$point_size)) updateSliderInput(session, "point_size", value = as.numeric(a$point_size))
      if (!is.null(a$line_width)) updateSliderInput(session, "line_width", value = as.numeric(a$line_width))
      if (!is.null(a$line_group_dodge)) updateSliderInput(session, "line_group_dodge", value = as.numeric(a$line_group_dodge))
      if (!is.null(a$line_x_spacing)) updateSliderInput(session, "line_x_spacing", value = as.numeric(a$line_x_spacing))
      if (!is.null(a$plot_width_px)) {
        pw <- safe_num1(a$plot_width_px, NA_real_)
        updateNumericInput(session, "plot_width_px_direct", value = pw)
        if (is.finite(pw) && pw >= 300 && pw <= 1400) updateSliderInput(session, "plot_width_px", value = pw)
      }
      if (!is.null(a$plot_height_px)) {
        ph <- safe_num1(a$plot_height_px, NA_real_)
        updateNumericInput(session, "plot_height_px_direct", value = ph)
        if (is.finite(ph) && ph >= 220 && ph <= 900) updateSliderInput(session, "plot_height_px", value = ph)
      }
      if (!is.null(a$bar_width)) updateSliderInput(session, "bar_width", value = as.numeric(a$bar_width))
      if (!is.null(a$bar_zero_touch)) updateCheckboxInput(session, "bar_zero_touch", value = isTRUE(a$bar_zero_touch))
      if (!is.null(a$group_spacing)) updateSliderInput(session, "group_spacing", value = as.numeric(a$group_spacing))
      if (!is.null(a$box_width_scale)) updateSliderInput(session, "box_width_scale", value = as.numeric(a$box_width_scale))
      if (!is.null(a$x_category_spacing)) updateSliderInput(session, "x_category_spacing", value = as.numeric(a$x_category_spacing))
      updateRadioButtons(session, "bar_border_mode", selected = json_chr(a$bar_border_mode, "fixed"))
      if (!is.null(a$bar_border_color)) {
        colourpicker::updateColourInput(session, "bar_border_color", value = normalise_colour(a$bar_border_color, "#000000"))
      }
      if (!is.null(a$bar_border_width)) updateSliderInput(session, "bar_border_width", value = as.numeric(a$bar_border_width))
      if (!is.null(a$raw_fixed_custom)) colourpicker::updateColourInput(session, "raw_fixed_custom", value = normalise_colour(a$raw_fixed_custom, "#555555"))
      if (!is.null(a$raw_color_mode)) {
        raw_mode_saved <- json_chr(a$raw_color_mode, "group_light")
        if (raw_mode_saved %in% c("black", "gray30", "white", "red3", "blue3", "darkgreen")) {
          updateSelectInput(session, "raw_color_mode", selected = "custom_fixed")
          colourpicker::updateColourInput(session, "raw_fixed_custom", value = normalise_colour(raw_mode_saved, "#555555"))
        } else {
          updateSelectInput(session, "raw_color_mode", selected = raw_mode_saved)
        }
      }
      if (!is.null(a$raw_lighten)) updateSliderInput(session, "raw_lighten", value = as.numeric(a$raw_lighten))
      if (!is.null(a$raw_alpha)) updateSliderInput(session, "raw_alpha", value = as.numeric(a$raw_alpha))
      if (!is.null(a$raw_shape_mode)) updateSelectInput(session, "raw_shape_mode", selected = a$raw_shape_mode)
      if (!is.null(a$raw_shape)) updateSelectInput(session, "raw_shape", selected = as.character(a$raw_shape))
      if (!is.null(a$raw_point_size)) updateSliderInput(session, "raw_point_size", value = as.numeric(a$raw_point_size))
      if (!is.null(a$jitter_width)) updateSliderInput(session, "jitter_width", value = as.numeric(a$jitter_width))
      if (!is.null(a$id_line_color_mode)) {
        id_mode_saved <- json_chr(a$id_line_color_mode, "group_light")
        if (id_mode_saved %in% c("black", "gray30", "gray50", "white", "red3", "blue3", "darkgreen")) {
          updateSelectInput(session, "id_line_color_mode", selected = "custom_fixed")
          colourpicker::updateColourInput(session, "id_line_custom_color", value = normalise_colour(id_mode_saved, "#4D4D4D"))
        } else {
          updateSelectInput(session, "id_line_color_mode", selected = id_mode_saved)
        }
      }
      if (!is.null(a$id_line_custom_color)) colourpicker::updateColourInput(session, "id_line_custom_color", value = normalise_colour(a$id_line_custom_color, "#4D4D4D"))
      if (!is.null(a$id_line_lighten)) updateSliderInput(session, "id_line_lighten", value = as.numeric(a$id_line_lighten))
      if (!is.null(a$id_linetype)) updateSelectInput(session, "id_linetype", selected = a$id_linetype)
      if (!is.null(a$id_line_width)) updateSliderInput(session, "id_line_width", value = as.numeric(a$id_line_width))
      if (!is.null(a$id_line_alpha)) updateSliderInput(session, "id_line_alpha", value = as.numeric(a$id_line_alpha))
      if (!is.null(a$summary_on_top)) updateCheckboxInput(session, "summary_on_top", value = isTRUE(a$summary_on_top))
      if (!is.null(a$error_color_mode)) updateSelectInput(session, "error_color_mode", selected = a$error_color_mode)
      if (!is.null(a$error_color)) colourpicker::updateColourInput(session, "error_color", value = a$error_color)
      if (!is.null(a$error_width)) updateSliderInput(session, "error_width", value = as.numeric(a$error_width))
      if (!is.null(a$error_line_width)) updateSliderInput(session, "error_line_width", value = as.numeric(a$error_line_width))
      if (!is.null(a$y_break_enabled)) updateCheckboxInput(session, "y_break_enabled", value = isTRUE(a$y_break_enabled))
      if (!is.null(a$y_breaks_auto)) updateCheckboxInput(session, "y_breaks_auto", value = isTRUE(a$y_breaks_auto))
      if (!is.null(a$y_breaks_step)) updateNumericInput(session, "y_breaks_step", value = as.numeric(a$y_breaks_step))
      if (!is.null(a$y_break_from)) updateNumericInput(session, "y_break_from", value = as.numeric(a$y_break_from))
      if (!is.null(a$y_break_to)) updateNumericInput(session, "y_break_to", value = as.numeric(a$y_break_to))
      if (!is.null(a$y_break_space)) updateSliderInput(session, "y_break_space", value = as.numeric(a$y_break_space))
      if (!is.null(a$y_break_symbol)) updateCheckboxInput(session, "y_break_symbol", value = isTRUE(a$y_break_symbol))
      if (!is.null(a$legend_pos)) updateSelectInput(session, "legend_pos", selected = a$legend_pos)
      if (!is.null(a$legend_key_width)) {
        updateSliderInput(
          session, "legend_key_width",
          value = as.numeric(a$legend_key_width)
        )
      }
      if (!is.null(a$facet_spacing_x)) {
        updateSliderInput(session, "facet_spacing_x", value = as.numeric(a$facet_spacing_x))
      }
      if (!is.null(a$sticky_plot)) updateCheckboxInput(session, "sticky_plot", value = isTRUE(a$sticky_plot))
    }

    style_restore_epoch(isolate(style_restore_epoch()) + 1L)
    restore_release_scheduled <- TRUE
    if (isTRUE(release_guard)) {
      session$onFlushed(function() {
        restoring_style_state(FALSE)
        if (isTRUE(notify) && !is.null(success_message) && nzchar(as.character(success_message)[1])) {
          showNotification(success_message, type = "message")
        }
      }, once = TRUE)
    }
    invisible(TRUE)
  }

  observeEvent(input$upload_style, {
    req(input$upload_style$datapath)

    cfg <- tryCatch(
      jsonlite::read_json(input$upload_style$datapath, simplifyVector = FALSE),
      error = function(e) {
        showNotification(
          paste0("設定ファイルを読み込めませんでした: ", conditionMessage(e)),
          type = "error", duration = 5
        )
        NULL
      }
    )
    if (is.null(cfg)) {
      restoring_style_state(FALSE)
      return(invisible(NULL))
    }

    apply_style_config(cfg, "設定を読み込みました。")
  })

  observeEvent(input$copy_style, {
    cfg <- isolate(style_settings())
    # Shared Library binding is Project-specific semantic metadata. Generic
    # Graph-format copy/paste may cross Projects, so carry only concrete style.
    cfg$shared_library <- NULL
    style_clipboard(cfg)
    showNotification(
      "このGraphの書式をコピーしました。別のGraph / Projectで「書式を貼り付け」を押せます。",
      type = "message", duration = 4
    )
  })

  observeEvent(input$paste_style, {
    cfg <- isolate(style_clipboard())
    if (is.null(cfg)) {
      showNotification(
        "コピーされた書式がありません。先にコピー元Graphで「書式をコピー」を押してください。",
        type = "warning", duration = 5
      )
      return(invisible(NULL))
    }

    apply_style_config(cfg, "書式を貼り付けました。Data / Mapping / Statisticsは変更していません。")
  })

  # local null-coalescing helper used above
  `%||%` <- function(a, b) if (is.null(a)) b else a

  init_timing_emit("RESTORE-MACHINERY-BEGIN")

  # Project読込は動的UIの再生成をまたぐため、段階的に復元する。
  pending_project <- reactiveVal(NULL)
  # v3.63.0-editor-shell1: direct editor sync is not a restore transaction.
  # Keep its target state separate so fixed Mapping DOM observers are not
  # invalidated by pending_project/deferred_initial_state.
  direct_sync_project <- reactiveVal(NULL)
  # v3.72.7: fixed-shell Graph revisits keep only a lightweight delta mask.
  # This is session-only synchronization metadata; no per-Graph DOM/module or
  # ggplot object is retained. NULL means full restore semantics, character(0)
  # means the target GraphState is already identical to the current editor.
  direct_sync_diff_paths <- reactiveVal(NULL)
  project_restore_stage <- reactiveVal(0)
  project_restore_wait_count <- reactiveVal(0L)
  project_restore_wait_phase <- reactiveVal("")
  # v3.73.2.3: full hydrate must cross a real browser flush after Mapping
  # update messages before stage 3 verifies server-side input values. This is
  # an event barrier, not polling/timing.
  mapping_stage3_flush_pending <- reactiveVal(FALSE)
  # Event-driven restore: the wait counter is now a guard against repeated
  # reactive state transitions, not a timer. Browser binding completion arrives
  # through generation-scoped ACK events.
  project_restore_wait_limit <- 120L
  # Avoid flooding diagnostics when several genuine binding/value changes occur
  # while stage2 converges. One successful Wide→Long snapshot per restore is enough.
  restore_diag_stage2_available_logged <- reactiveVal(FALSE)

  abort_project_restore <- function(message) {
    diag("RESTORE-ERROR", paste0("stage=", isolate(project_restore_stage()), " ", message))
    restore_error(message)
    project_restore_stage(0)
    project_restore_wait_count(0L)
    project_restore_wait_phase("")
    mapping_stage3_flush_pending(FALSE)
    reset_mapping_binding_wait()
    reset_reshape_binding_wait(clear_seed = TRUE)
    pending_project(NULL)
    direct_sync_project(NULL)
    direct_sync_diff_paths(NULL)
    initial_restore_done(FALSE)
    initial_restore_started(FALSE)
    # Preserve the source state for an explicit activate/retry; never publish
    # this half-restored module as a valid materialized source.
    restoring_style_state(FALSE)
    restore_notify(FALSE)
    showNotification(
      paste0("Graph設定の復元を中止しました: ", message),
      type = "error", duration = 8
    )
    invisible(FALSE)
  }

  # Phase 13: cooperatively cancel an unfinished initial Project hydrate.
  # This is intentionally different from abort_project_restore(): user-driven
  # preemption is not an error, must not notify, and must preserve the original
  # deferred GraphState so a later selection can restart from canonical state.
  cancel_initial_restore <- function(reason = "preempt") {
    if (isTRUE(isolate(initial_restore_done()))) return(invisible(FALSE))
    if (!isTRUE(isolate(initial_restore_started())) &&
        identical(isolate(project_restore_stage()), 0)) {
      return(invisible(FALSE))
    }

    stage0 <- isolate(project_restore_stage())
    diag("RESTORE-CANCEL", paste0("reason=", reason, " stage=", stage0))

    # Stop every restore observer at its existing stage gate. Browser acks that
    # arrive later cannot advance the restore because their pending tokens are
    # cleared here; the next attempt creates fresh generations.
    project_restore_stage(0)
    project_restore_wait_count(0L)
    project_restore_wait_phase("")
    mapping_stage3_flush_pending(FALSE)
    pending_project(NULL)
    direct_sync_project(NULL)
    direct_sync_diff_paths(NULL)
    reset_mapping_binding_wait()
    reset_reshape_binding_wait(clear_seed = TRUE)
    mapping_restore_resync_count(0L)
    restore_stage3_done(FALSE)
    restore_final_done(FALSE)
    restore_error(NULL)
    restoring_style_state(FALSE)
    restore_notify(FALSE)
    initial_restore_started(FALSE)
    initial_restore_done(FALSE)
    restore_parent_preseed_match(FALSE)
    restore_parent_preseed_consumed(FALSE)
    restore_activation_generation(as.integer(isolate(restore_activation_generation()) %||% 0L) + 1L)
    # deferred_initial_state() deliberately remains intact.
    invisible(TRUE)
  }

  restore_wait <- function(message, phase = "generic") {
    phase <- as.character(phase %||% "generic")[1]
    current_phase <- as.character(isolate(project_restore_wait_phase()) %||% "")[1]
    if (!identical(current_phase, phase)) {
      project_restore_wait_phase(phase)
      project_restore_wait_count(0L)
      diag("RESTORE-PHASE", paste0("phase=", phase, " wait_reset=TRUE"))
    }
    n <- isolate(project_restore_wait_count()) + 1L
    project_restore_wait_count(n)
    if (n >= project_restore_wait_limit) {
      abort_project_restore(message)
      return(FALSE)
    }
    TRUE
  }

  # Diagnostics-only helpers for restore-time Wide→Long failures.
  # They read restore/input state only through isolate(), never mutate state,
  # and never call raw_dat()/dat() themselves. Existing event-driven restore
  # control flow (return/wait counters/stage transitions) stays unchanged.
  restore_diag_checkpoint <- function() {
    n <- suppressWarnings(as.integer(isolate(project_restore_wait_count())))
    if (!length(n) || is.na(n)) n <- 0L
    n %in% c(0L, 20L, 60L, 119L)
  }

  restore_diag_value <- function(x) {
    if (is.null(x) || !length(x)) return("<NULL>")
    z <- as.character(x)
    z[is.na(z)] <- "<NA>"
    z[z == ""] <- "<EMPTY>"
    paste(z, collapse = "|")
  }

  restore_binding_ack_diag <- function(ack) {
    if (is.null(ack)) return("ack=<NULL>")
    states <- ack$states %||% list()
    state_txt <- if (!length(states)) {
      "<none>"
    } else {
      paste(vapply(states, function(st) {
        field <- as.character(st$field %||% st$id %||% "?")[1]
        exists <- isTRUE(st$exists)
        bound <- isTRUE(st$bound)
        readable <- if (is.null(st$valueReadable)) TRUE else isTRUE(st$valueReadable)
        value <- restore_diag_value(st$value)
        paste0(field, "[exists=", exists, ",bound=", bound, ",readable=", readable, ",value=", value, "]")
      }, character(1)), collapse = ";")
    }
    paste0(
      "elapsed_ms=", restore_diag_value(ack$elapsedMs),
      " dom_inputs=", restore_diag_value(ack$domInputCount),
      " bound_inputs=", restore_diag_value(ack$boundInputCount),
      " states={", state_txt, "}"
    )
  }


  # v3.55 restore fast path: the browser binding ACK already includes the
  # current bound value for every requested field.  When graphUI/renderUI was
  # pre-seeded with the saved Project value, do not send the same update*Input
  # message again.  This does not bypass the server-observed gate: restore still
  # waits until input$... carries the expected value before advancing.
  restore_ack_field_value <- function(ack, field) {
    states <- ack$states %||% list()
    if (!length(states)) return(NULL)
    for (st in states) {
      if (identical(as.character(st$field %||% "")[1], as.character(field)[1]) &&
          isTRUE(st$exists) && isTRUE(st$bound) &&
          (is.null(st$valueReadable) || isTRUE(st$valueReadable))) return(st$value)
    }
    NULL
  }

  restore_ack_scalar_matches <- function(ack, field, expected, logical_value = FALSE) {
    got <- restore_ack_field_value(ack, field)
    if (is.null(got)) return(FALSE)
    if (isTRUE(logical_value)) {
      g <- tolower(as.character(got)[1] %||% "")
      gv <- g %in% c("true", "1", "on", "yes")
      return(identical(gv, isTRUE(expected)))
    }
    identical(as.character(got)[1] %||% "", as.character(expected)[1] %||% "")
  }

  restore_ack_set_matches <- function(ack, field, expected) {
    got <- restore_ack_field_value(ack, field)
    if (is.null(got)) return(FALSE)
    got <- as.character(unlist(got, use.names = FALSE))
    expected <- as.character(expected)
    length(got) == length(expected) && setequal(got, expected)
  }

  restore_current_reshape_parent_matches <- function(expected) {
    actual_enabled <- tryCatch(input$reshape_wide, error = function(e) NULL)
    actual_row_id <- tryCatch(input$reshape_row_id, error = function(e) NULL)
    actual_x <- tryCatch(input$reshape_x_name, error = function(e) NULL)
    actual_y <- tryCatch(input$reshape_y_name, error = function(e) NULL)
    !is.null(actual_enabled) && identical(isTRUE(actual_enabled), isTRUE(expected$enabled)) &&
      !is.null(actual_row_id) && identical(isTRUE(actual_row_id), isTRUE(expected$row_id)) &&
      !is.null(actual_x) && identical(as.character(actual_x)[1], as.character(expected$x_name)[1]) &&
      !is.null(actual_y) && identical(as.character(actual_y)[1], as.character(expected$y_name)[1])
  }

  restore_diag_condition <- function(label, e, cfg) {
    tryCatch({
      r <- cfg$reshape %||% list()
      msg <- tryCatch(conditionMessage(e), error = function(...) "")
      cls <- paste(class(e), collapse = "/")
      diag(
        "RESHAPE-DIAG",
        paste0(
          label,
          " stage=", isolate(project_restore_stage()),
          " wait=", isolate(project_restore_wait_count()),
          " condition_class=", if (nzchar(cls)) cls else "<none>",
          " condition_message=", if (nzchar(msg)) msg else "<EMPTY>",
          " saved_enabled=", isTRUE(r$enabled),
          " input_enabled=", restore_diag_value(isolate(input$reshape_wide)),
          " saved_cols={", paste(json_vec(r$columns), collapse = ","), "}",
          " input_cols={", restore_diag_value(isolate(input$reshape_columns)), "}",
          " saved_x=", restore_diag_value(r$x_name),
          " input_x=", restore_diag_value(isolate(input$reshape_x_name)),
          " saved_y=", restore_diag_value(r$y_name),
          " input_y=", restore_diag_value(isolate(input$reshape_y_name)),
          " row_id=", restore_diag_value(isolate(input$reshape_row_id)),
          " text_chars=", {
            txt <- isolate(input$text)
            if (is.null(txt) || !length(txt)) 0L else nchar(as.character(txt[1]), type = "chars", allowNA = TRUE)
          }
        )
      )
    }, error = function(...) invisible(NULL))
    invisible(NULL)
  }

  restore_diag_snapshot <- function(label, cfg, d = NULL) {
    tryCatch({
      r <- cfg$reshape %||% list()
      cols <- isolate(input$reshape_columns)
      warn <- isolate(reshape_warning())
      numeric_n <- if (is.data.frame(d)) sum(vapply(d, is.numeric, logical(1))) else NA_integer_
      diag(
        "RESHAPE-DIAG",
        paste0(
          label,
          " stage=", isolate(project_restore_stage()),
          " wait=", isolate(project_restore_wait_count()),
          " saved_enabled=", isTRUE(r$enabled),
          " input_enabled=", restore_diag_value(isolate(input$reshape_wide)),
          " saved_cols={", paste(json_vec(r$columns), collapse = ","), "}",
          " input_cols={", restore_diag_value(cols), "}",
          " saved_x=", restore_diag_value(r$x_name),
          " input_x=", restore_diag_value(isolate(input$reshape_x_name)),
          " saved_y=", restore_diag_value(r$y_name),
          " input_y=", restore_diag_value(isolate(input$reshape_y_name)),
          " warning=", restore_diag_value(warn),
          " dat_dims=", if (is.data.frame(d)) paste0(nrow(d), "x", ncol(d)) else "<NULL>",
          " numeric_cols=", if (is.na(numeric_n)) "<NA>" else numeric_n,
          " dat_names={", if (is.data.frame(d)) paste(names(d), collapse = ",") else "", "}"
        )
      )
    }, error = function(...) invisible(NULL))
    invisible(NULL)
  }

  # Project全体から渡されたinitial_stateは、必要になるまで復元しない。
  # 表示中Graphを先に復元し、残りはProject Managerが順次activateする。
  deferred_initial_state <- reactiveVal(initial_state)
  # Persistent single-Editor canonical attachment. This is one state for the one
  # mounted Editor, not a per-Graph cache. During dynamic UI replacement the
  # browser-backed project_settings() reactive can be temporarily unavailable.
  # The outer Editor transaction arbitrates this attached canonical state at READY;
  # after acceptance, graph_state_boundary_runtime.R releases it exactly once as
  # the first render target. Ordinary READY user edits still come from live
  # project_settings().
  attached_state_seed <- reactiveVal(initial_state)
  restore_activation_generation <- reactiveVal(0L)
  initial_restore_started <- reactiveVal(is.null(initial_state))
  initial_restore_done <- reactiveVal(is.null(initial_state))
  restore_stage3_done <- reactiveVal(is.null(initial_state))
  restore_final_done <- reactiveVal(is.null(initial_state))
  mapping_restore_resync_count <- reactiveVal(0L)
  mapping_restore_resync_limit <- 4L
  mapping_restore_resync_interval <- 20L

  # Mapping restore must not advance from stage2 until the dynamic Mapping
  # inputs for the current UI generation are actually bound in the browser.
  # The generation token prevents a late ack from a replaced renderUI tree
  # from satisfying a newer restore attempt.
  mapping_binding_generation <- reactiveVal(0L)
  mapping_binding_pending <- reactiveVal(NULL)

  reset_mapping_binding_wait <- function() {
    mapping_binding_pending(NULL)
    session$sendCustomMessage(
      "mapping-restore-binding-cancel",
      list(ackId = session$ns("mapping_restore_binding_ack"))
    )
    invisible(NULL)
  }

  request_mapping_binding_ack <- function(fields, plot_type) {
    fields <- unique(as.character(fields))
    fields <- fields[nzchar(fields)]
    next_generation <- isolate(mapping_binding_generation()) + 1L
    mapping_binding_generation(next_generation)
    pending <- list(
      generation = next_generation,
      fields = fields,
      plot_type = as.character(plot_type)[1]
    )
    mapping_binding_pending(pending)

    ids <- unname(vapply(fields, session$ns, character(1)))
    diag(
      "MAPPING-BIND",
      paste0(
        "request generation=", next_generation,
        " plot_type=", pending$plot_type,
        " fields=", paste(fields, collapse = ",")
      )
    )
    restore_timing_last_mapping_generation <<- next_generation
    restore_timing_mark("MAPPING-BIND-REQUEST", next_generation)
    session$sendCustomMessage(
      "mapping-restore-binding-check",
      list(
        generation = next_generation,
        fields = lapply(seq_along(fields), function(i) {
          list(field = fields[[i]], id = ids[[i]])
        }),
        ackId = session$ns("mapping_restore_binding_ack")
      )
    )
    invisible(pending)
  }


  restore_error <- reactiveVal(NULL)
  # A transient browser race may justify one automatic retry, but a permanent
  # restore mismatch must never turn the materialization poll into an infinite loop.
  restore_retry_count <- reactiveVal(0L)
  restore_retry_limit <- 1L
  restore_notify <- reactiveVal(FALSE)
  # Figure controls-only restore can trust the static parent controls after the
  # outer mount ACK, but dynamic child/mapping controls are verified later.
  restore_parent_preseed_match <- reactiveVal(FALSE)
  restore_parent_preseed_consumed <- reactiveVal(FALSE)
  plot_drawn <- reactiveVal(FALSE)
  # Phase 13.1: monotonically increases only after output$plot has completed
  # building a valid live plot. Server-side Graph preview publication observes
  # this epoch and applies its own GraphState/browser-generation guards.
  plot_render_revision <- reactiveVal(0L)
  last_render_state <- reactiveVal(NULL)

  # Browser DOM is virtualized independently from this persistent server module.
  # Each remount therefore has its own browser generation.  The render epoch is
  # advanced only after the browser confirms that the newly inserted live plot
  # layer exists and has been made visible.
  remount_generation <- reactiveVal(0L)
  remount_pending_generation <- reactiveVal(NA_integer_)
  remount_seed_browser_generation <- reactiveVal(NA_integer_)
  remount_render_epoch <- reactiveVal(0L)
  # Canonical GraphState seed used only while a READY persistent module is
  # reconnecting to a newly materialized browser DOM. Dynamic Mapping controls
  # are server-rendered and therefore cannot rely on graphUI()'s static seeds.
  # Keep this seed until BOTH the browser remount handshake has succeeded and
  # the rebound browser inputs confirm the same semantic mapping.  Input values
  # can become correct before the live DOM handshake completes; releasing at
  # that earlier point re-opens a small state-bounce window.
  remount_state_seed <- reactiveVal(NULL)
  remount_seed_browser_ready <- reactiveVal(FALSE)
  # Server module lifetime outlives the browser DOM.  Track whether this
  # namespace currently owns a materialized browser subtree so stale renders
  # from an evicted generation cannot drive UI-SWITCH after the DOM is gone.
  browser_ui_active <- reactiveVal(TRUE)

  # v3.54: cached/live Preview mode is owned by the fixed singleton Graph
  # workspace viewport. Its diagnostic ACK is handled once in server.R rather
  # than by every persistent graphServer module.

  # Dynamic Style UIは復元中に一度古い/default input値を持つことがある。
  # その値が保存済みstyleを逆上書きしないよう、復元完了flushまでobserverを止める。
  restoring_style_state <- reactiveVal(FALSE)
  style_restore_epoch <- reactiveVal(0L)


  json_chr <- function(x, default = "") {
    if (is.null(x)) return(default)
    z <- unlist(x, use.names = FALSE)
    if (!length(z)) return(default)
    as.character(z[[1]])
  }

  json_vec <- function(x) {
    if (is.null(x)) return(character(0))
    as.character(unlist(x, use.names = FALSE))
  }

  normalize_order_tree <- function(x) {
    out <- list(x = list(), group = list(), facet = list())
    if (is.null(x)) return(out)

    for (kind in c("x", "group", "facet")) {
      branch <- x[[kind]]
      if (is.null(branch)) next
      for (nm in names(branch)) {
        out[[kind]][[nm]] <- json_vec(branch[[nm]])
      }
    }
    out
  }


  # ------------------------------------------------------------
  # Fast seed: Projectから生成したmoduleでは、画面UIの復元より先に
  # Plotに使う内部Style / order stateだけを保存値で初期化する。
  # これにより復元途中にdefault paletteでPlotが作られるのを防ぐ。
  # ------------------------------------------------------------
  seed_internal_state <- function(cfg) {
    if (is.null(cfg)) return(invisible(FALSE))

    st <- cfg$style
    if (!is.null(st)) {
      if (!is.null(st$color_styles)) color_styles(parse_style_tree(st$color_styles, "color"))
      if (!is.null(st$linetype_styles)) linetype_styles(parse_style_tree(st$linetype_styles, "linetype"))
      if (!is.null(st$shape_styles)) shape_styles(parse_style_tree(st$shape_styles, "shape"))
      if (is.null(st$color_styles) && !is.null(st$group_styles) && length(st$group_styles)) {
        mv <- legacy_mapping_vars(cfg$mapping)
        migrate_legacy_group_styles(st$group_styles, mv$color, mv$linetype, mv$shape)
      }

      if (!is.null(st$series_styles) && length(st$series_styles)) {
        ss <- list()
        for (nm in names(st$series_styles)) {
          z <- st$series_styles[[nm]]
          col <- json_chr(z$color, "#333333")
          ss[[nm]] <- list(color = col)
        }
        series_styles(ss)
      }

      if (!is.null(st$regression_styles) && length(st$regression_styles)) {
        rs <- list()
        for (nm in names(st$regression_styles)) {
          z <- st$regression_styles[[nm]]
          rs[[nm]] <- list(
            color = json_chr(z$color, "#333333"),
            linetype = json_chr(z$linetype, "solid"),
            width = suppressWarnings(as.numeric(json_chr(z$width, "1")))
          )
        }
        regression_styles(rs)
      }

      if (!is.null(st$raw_group_colors) && length(st$raw_group_colors)) {
        first_val <- st$raw_group_colors[[1]]
        if (is.list(first_val) && !is.null(names(first_val))) {
          raw_group_colors(parse_style_tree(st$raw_group_colors, "color"))
        } else {
          mv <- legacy_mapping_vars(cfg$mapping); rc <- list(); br <- list()
          for (nm in names(st$raw_group_colors)) br[[nm]] <- json_chr(st$raw_group_colors[[nm]], "#777777")
          if (nzchar(mv$color)) rc[[mv$color]] <- br
          raw_group_colors(rc)
        }
      }

      if (!is.null(st$orders)) {
        order_state(normalize_order_tree(st$orders))
      }

      if (!is.null(st$legend_titles)) {
        lt <- list()
        for (nm in names(st$legend_titles)) {
          lt[[nm]] <- json_chr(st$legend_titles[[nm]], "")
        }
        legend_titles(lt)
      }

      if (!is.null(st$level_labels)) {
        ll <- list()
        for (vn in names(st$level_labels)) {
          branch <- st$level_labels[[vn]]
          bb <- list()
          for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
          ll[[vn]] <- bb
        }
        level_labels(ll)
      }
      shared_style_binding(shared_style_normalize_binding(st$shared_library %||% NULL))
    } else {
      shared_style_binding(shared_style_default_binding())
    }

    invisible(TRUE)
  }

  # initial_stateがあるGraphはmodule生成時点で内部stateを先にhydrate。
  # UI inputの段階復元は後で行う。
  if (!is.null(initial_state)) {
    diag("RESTORE", "seed_internal_state begin")
    seed_internal_state(initial_state)
    diag("RESTORE", "seed_internal_state end")
  }

  mapping_project_status <- function(cfg) {
    mp <- cfg$mapping
    if (is.null(mp)) {
      return(list(
        ok = TRUE,
        mismatch = character(0),
        expected = character(0),
        actual = character(0),
        raw = character(0),
        target_plot_type = json_chr(cfg$plot$type, input$plot_type %||% "line")
      ))
    }

    target_plot_type <- graph_plot_type_normalize(
      json_chr(cfg$plot$type, input$plot_type %||% "line")
    )

    input_value <- function(x) {
      if (is.null(x) || !length(x)) return(NA_character_)
      as.character(x)[1]
    }
    raw_label <- function(x) {
      if (is.null(x) || !length(x)) return("<NULL>")
      z <- as.character(x)[1]
      if (identical(z, "")) return("<EMPTY>")
      z
    }

    expected <- c(
      x = json_chr(mp$x),
      y = json_chr(mp$y),
      color = json_chr(mp$color),
      shape = json_chr(mp$shape, "__color__"),
      id = json_chr(mp$id),
      facet = json_chr(mp$facet)
    )
    if (!nzchar(expected[["color"]]) && is.null(mp$position)) {
      expected[["color"]] <- json_chr(mp$series)
    }
    if (identical(expected[["color"]], "__fixed__")) expected[["color"]] <- ""

    raw_inputs <- list(
      x = input$xvar,
      y = input$yvar,
      color = input$colorvar,
      shape = input$shapevar,
      id = input$idvar,
      facet = input$facetvar
    )
    actual <- vapply(raw_inputs, input_value, character(1))
    raw <- vapply(raw_inputs, raw_label, character(1))

    if (graph_plot_supports_mapping(target_plot_type, "position")) {
      expected_position <- json_chr(mp$position, json_chr(mp$series))
      raw_inputs$position <- input$groupvar
      expected <- c(expected, position = expected_position)
      actual <- c(actual, position = input_value(raw_inputs$position))
      raw <- c(raw, position = raw_label(raw_inputs$position))
    }

    if (graph_plot_supports_mapping(target_plot_type, "linetype")) {
      expected_linetype <- json_chr(mp$linetype, "__color__")
      raw_inputs$linetype <- input$linetypevar
      expected <- c(expected, linetype = expected_linetype)
      actual <- c(actual, linetype = input_value(raw_inputs$linetype))
      raw <- c(raw, linetype = raw_label(raw_inputs$linetype))
    }

    # Mapping controls use two equivalent browser/server representations for
    # "no mapping": an empty string from the select input, or NULL while the
    # optional dynamic control has no selected value to send back to Shiny.
    # Treat NULL/length-0 as semantically empty *only when the saved value is
    # itself empty*.  Non-empty saved mappings still require an exact value, so
    # this cannot accidentally accept a missing x/y/color/etc. mapping.
    actual_cmp <- actual[names(expected)]
    expected_cmp <- as.character(expected)
    semantic_empty <- expected_cmp == "" & is.na(actual_cmp)
    actual_cmp[semantic_empty] <- ""
    # Shape/Linetype use __color__ as their semantic default.  During a
    # renderUI replacement Shiny can briefly report NULL even though the newly
    # bound control was created with that exact default.  The preceding browser
    # binding ACK already proved that the control exists; treat this transient
    # NULL as the saved semantic default rather than forcing a redundant resync.
    semantic_color_default <- names(expected_cmp) %in% c("shape", "linetype") &
      expected_cmp == "__color__" & is.na(actual_cmp)
    actual_cmp[semantic_color_default] <- "__color__"

    mismatch <- names(expected)[
      is.na(actual_cmp) |
        as.character(actual_cmp) != expected_cmp
    ]

    list(
      ok = !length(mismatch),
      mismatch = mismatch,
      expected = expected,
      actual = actual,
      raw = raw,
      target_plot_type = target_plot_type
    )
  }

  resync_mapping_fields <- function(cfg, fields) {
    if (!length(fields)) return(invisible(FALSE))
    mp <- cfg$mapping
    if (is.null(mp)) return(invisible(FALSE))

    target_plot_type <- graph_plot_type_normalize(
      json_chr(cfg$plot$type, input$plot_type %||% "line")
    )

    restored_color <- json_chr(mp$color)
    if (!nzchar(restored_color) && is.null(mp$position) && nzchar(json_chr(mp$series))) {
      restored_color <- json_chr(mp$series)
    }
    if (identical(restored_color, "__fixed__")) restored_color <- ""

    expected_by_field <- c(
      x = json_chr(mp$x),
      y = json_chr(mp$y),
      color = restored_color,
      shape = json_chr(mp$shape, "__color__"),
      id = json_chr(mp$id),
      facet = json_chr(mp$facet)
    )
    if (graph_plot_supports_mapping(target_plot_type, "position")) {
      expected_by_field <- c(
        expected_by_field,
        position = json_chr(mp$position, json_chr(mp$series))
      )
    }
    if (graph_plot_supports_mapping(target_plot_type, "linetype")) {
      expected_by_field <- c(
        expected_by_field,
        linetype = json_chr(mp$linetype, "__color__")
      )
    }

    input_ids <- c(
      x = "xvar", y = "yvar", color = "colorvar", shape = "shapevar",
      id = "idvar", facet = "facetvar", position = "groupvar",
      linetype = "linetypevar"
    )

    fields <- intersect(fields, names(expected_by_field))
    if (!length(fields)) return(invisible(FALSE))

    for (nm in fields) {
      input_id <- input_ids[[nm]]
      freezeReactiveValue(input, input_id)
      updateSelectInput(session, input_id, selected = expected_by_field[[nm]])
    }

    # Dynamic controls may be replaced after the first update. Keep their
    # saved values as renderUI seeds until the browser returns the exact value.
    if ("position" %in% fields && target_plot_type %in% c("line", "bar", "box")) {
      restore_position_seed(expected_by_field[["position"]])
    }
    if ("linetype" %in% fields && target_plot_type %in% c("line", "scatter")) {
      restore_linetype_seed(expected_by_field[["linetype"]])
    }

    invisible(TRUE)
  }
