# v3.73.2.37 Phase 2.03 — active Graph style persistence.
# Legacy staged Project restore/remount/retry machinery was removed.
# Editor-local transaction primitives are initialized before runtime sourcing in
# graph_editor_primitives_runtime.R. This file owns only generic style
# import/export/copy/paste behavior.

  # ============================================================
  # Settings save / load
  # ============================================================
  style_settings <- reactive({
    list(
      version = "3.80.2",
      schema_version = 4L,
      color_styles = color_styles(),
      linetype_styles = linetype_styles(),
      shape_styles = shape_styles(),
      series_styles = series_styles(),
      regression_styles = regression_styles(),
      raw_group_colors = raw_group_colors(),
      orders = order_state(),
      legend_titles = legend_titles(),
      legend_item_labels = legend_item_labels(),
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
        scatter_point_alpha = input$scatter_point_alpha,
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
        x_tick_labels_show = input$x_tick_labels_show,
        legend_pos = input$legend_pos,
        legend_colour_show = input$legend_colour_show,
        legend_fill_show = input$legend_fill_show,
        legend_linetype_show = input$legend_linetype_show,
        legend_shape_show = input$legend_shape_show,
        legend_merge_mode = input$legend_merge_mode,
        legend_merge_linetype_shape = input$legend_merge_linetype_shape,
        legend_merge_colour_shape = input$legend_merge_colour_shape,
        legend_title_show = input$legend_title_show,
        legend_group_title = input$legend_group_title,
        legend_individual_title_show = input$legend_individual_title_show,
        legend_individual_title = input$legend_individual_title,
        legend_colour_title_show = input$legend_colour_title_show,
        legend_fill_title_show = input$legend_fill_title_show,
        legend_linetype_title_show = input$legend_linetype_title_show,
        legend_shape_title_show = input$legend_shape_title_show,
        legend_colour_title = input$legend_colour_title,
        legend_fill_title = input$legend_fill_title,
        legend_linetype_title = input$legend_linetype_title,
        legend_shape_title = input$legend_shape_title,
        legend_colour_order = graph_legend_order(input$legend_colour_order, 1L),
        legend_fill_order = graph_legend_order(input$legend_fill_order, 2L),
        legend_linetype_order = graph_legend_order(input$legend_linetype_order, 3L),
        legend_shape_order = graph_legend_order(input$legend_shape_order, 4L),
        legend_wrap_mode = input$legend_wrap_mode %||% "auto",
        legend_wrap_count = as.integer(input$legend_wrap_count %||% 2L),
        legend_item_spacing = input$legend_item_spacing %||% -1,
        legend_text_size = input$legend_text_size %||% 0,
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
    target <- isolate(graph_state_replay_target())
    mp <- if (is.list(target)) target$mapping else list(color = isolate(input$colorvar), position = isolate(input$groupvar))
    cfg <- graph_style_migrate_v4(cfg)
    cfg <- graph_normalize_legend_state(list(mapping = mp, style = cfg))$style
    restoring_style_state(TRUE)
    restore_release_scheduled <- FALSE
    on.exit({
      # If any schema/type error occurs before the normal onFlushed release is
      # scheduled, never leave this Graph permanently frozen in restore mode.
      if (!isTRUE(restore_release_scheduled)) restoring_style_state(FALSE)
    }, add = TRUE)

    # Persistent single Editor: target GraphState owns these trees completely.
    # Replace (rather than merge) them on every replay so an empty/new Graph can
    # never inherit branches from the previously visited Graph.
    color_styles(parse_style_tree(cfg$color_styles %||% list(), "color"))
    linetype_styles(parse_style_tree(cfg$linetype_styles %||% list(), "linetype"))
    shape_styles(parse_style_tree(cfg$shape_styles %||% list(), "shape"))
    if (is.null(cfg$color_styles) && !is.null(cfg$group_styles) && length(cfg$group_styles)) {
      mv <- legacy_mapping_vars(NULL)
      migrate_legacy_group_styles(cfg$group_styles, mv$color, mv$linetype, mv$shape)
    }

    ss <- list()
    if (!is.null(cfg$series_styles) && length(cfg$series_styles)) {
      for (nm in names(cfg$series_styles)) {
        st <- cfg$series_styles[[nm]]
        ss[[nm]] <- list(color = as.character(st$color %||% "#333333"))
      }
    }
    series_styles(ss)

    rs <- list()
    if (!is.null(cfg$regression_styles) && length(cfg$regression_styles)) {
      for (nm in names(cfg$regression_styles)) {
        st <- cfg$regression_styles[[nm]]
        rs[[nm]] <- list(
          color = json_chr(st$color, "#333333"),
          linetype = json_chr(st$linetype, "solid"),
          width = as.numeric(json_chr(st$width, "0.9"))
        )
      }
    }
    regression_styles(rs)

    rc <- list()
    if (!is.null(cfg$raw_group_colors) && length(cfg$raw_group_colors)) {
      # v3.1+: variable -> level -> color. Legacy flat level -> color is migrated.
      first_val <- cfg$raw_group_colors[[1]]
      if (is.list(first_val) && !is.null(names(first_val))) {
        rc <- parse_style_tree(cfg$raw_group_colors, "color")
      } else {
        mv <- legacy_mapping_vars(NULL); br <- list()
        for (nm in names(cfg$raw_group_colors)) br[[nm]] <- as.character(unlist(cfg$raw_group_colors[[nm]])[[1]])
        if (nzchar(mv$color)) rc[[mv$color]] <- br
      }
    }
    raw_group_colors(rc)

    os <- list(x = list(), group = list(), display = list(), facet = list())
    if (!is.null(cfg$orders)) {
      if (!is.null(cfg$orders$x)) os$x <- cfg$orders$x
      if (!is.null(cfg$orders$group)) os$group <- cfg$orders$group
      if (!is.null(cfg$orders$display)) os$display <- cfg$orders$display
      if (!is.null(cfg$orders$facet)) os$facet <- cfg$orders$facet
    }
    order_state(os)

    lt <- list()
    if (!is.null(cfg$legend_titles)) {
      for (nm in names(cfg$legend_titles)) {
        lt[[nm]] <- json_chr(cfg$legend_titles[[nm]], "")
      }
    }
    legend_titles(lt)

    if (!is.null(cfg$legend_item_labels)) {
      li <- list()
      for (vn in names(cfg$legend_item_labels)) {
        branch <- cfg$legend_item_labels[[vn]]
        bb <- list()
        for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], "")
        li[[vn]] <- bb
      }
      legend_item_labels(li)
    } else {
      # Persistent single Editor: an older Graph without this field must not
      # inherit legend-entry text from the previously visited Graph.
      legend_item_labels(list())
    }

    ll <- list()
    if (!is.null(cfg$level_labels)) {
      for (vn in names(cfg$level_labels)) {
        branch <- cfg$level_labels[[vn]]
        bb <- list()
        for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
        ll[[vn]] <- bb
      }
    }
    level_labels(ll)

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
      updateSliderInput(session, "scatter_point_alpha", value = as.numeric(a$scatter_point_alpha %||% 0.90))
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
      updateCheckboxInput(
        session, "x_tick_labels_show",
        value = if (is.null(a$x_tick_labels_show)) TRUE else isTRUE(a$x_tick_labels_show)
      )
      if (!is.null(a$legend_pos)) updateSelectInput(session, "legend_pos", selected = a$legend_pos)
      updateCheckboxInput(
        session, "legend_colour_show",
        value = if (is.null(a$legend_colour_show)) {
          if (is.null(a$legend_group_show)) TRUE else isTRUE(a$legend_group_show)
        } else isTRUE(a$legend_colour_show)
      )
      updateCheckboxInput(session, "legend_fill_show", value = if (is.null(a$legend_fill_show)) {
        if (is.null(a$legend_colour_show)) TRUE else isTRUE(a$legend_colour_show)
      } else isTRUE(a$legend_fill_show))
      updateSelectInput(session, "legend_merge_mode", selected = a$legend_merge_mode %||% "auto")
      for (aes in graph_legend_aesthetics()) {
        key <- paste0("legend_", aes)
        legacy_show <- if (aes %in% c("colour", "fill")) a$legend_title_show else a$legend_individual_title_show
        legacy_title <- if (aes %in% c("colour", "fill")) a$legend_group_title else a$legend_individual_title
        updateCheckboxInput(session, paste0(key, "_title_show"), value = isTRUE(a[[paste0(key, "_title_show")]] %||% legacy_show))
        updateTextInput(session, paste0(key, "_title"), value = a[[paste0(key, "_title")]] %||% legacy_title %||% "")
        updateSelectInput(session, paste0(key, "_order"), selected = as.character(graph_legend_order(a[[paste0(key, "_order")]], match(aes, graph_legend_aesthetics()))))
      }
      updateCheckboxInput(
        session, "legend_linetype_show",
        value = if (is.null(a$legend_linetype_show)) {
          if (is.null(a$legend_group_show)) TRUE else isTRUE(a$legend_group_show)
        } else isTRUE(a$legend_linetype_show)
      )
      updateCheckboxInput(
        session, "legend_shape_show",
        value = if (is.null(a$legend_shape_show)) {
          if (is.null(a$legend_individual_show)) TRUE else isTRUE(a$legend_individual_show)
        } else isTRUE(a$legend_shape_show)
      )
      updateCheckboxInput(
        session, "legend_merge_linetype_shape",
        value = if (is.null(a$legend_merge_linetype_shape)) TRUE else isTRUE(a$legend_merge_linetype_shape)
      )
      updateCheckboxInput(
        session, "legend_merge_colour_shape",
        value = if (is.null(a$legend_merge_colour_shape)) {
          if (is.null(a$legend_merge_group_individual)) TRUE else isTRUE(a$legend_merge_group_individual)
        } else isTRUE(a$legend_merge_colour_shape)
      )
      updateCheckboxInput(
        session, "legend_title_show",
        value = if (is.null(a$legend_title_show)) FALSE else isTRUE(a$legend_title_show)
      )
      updateTextInput(session, "legend_group_title", value = a$legend_group_title %||% "")
      updateCheckboxInput(session, "legend_individual_title_show", value = isTRUE(a$legend_individual_title_show))
      updateTextInput(session, "legend_individual_title", value = a$legend_individual_title %||% "")
      updateSelectInput(session, "legend_wrap_mode", selected = a$legend_wrap_mode %||% "auto")
      updateSliderInput(session, "legend_wrap_count", value = as.numeric(a$legend_wrap_count %||% 2L))
      updateNumericInput(session, "legend_item_spacing", value = as.numeric(a$legend_item_spacing %||% -1))
      updateNumericInput(session, "legend_text_size", value = as.numeric(a$legend_text_size %||% 0))
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
    } else {
      # Very old/partial GraphStates can lack appearance entirely.  Do not let
      # the persistent Editor inherit these newly-added legend controls from
      # the previously visited Graph.
      updateCheckboxInput(session, "x_tick_labels_show", value = TRUE)
      updateCheckboxInput(session, "legend_colour_show", value = TRUE)
      updateCheckboxInput(session, "legend_fill_show", value = TRUE)
      updateSelectInput(session, "legend_merge_mode", selected = "auto")
      for (aes in graph_legend_aesthetics()) {
        key <- paste0("legend_", aes)
        updateCheckboxInput(session, paste0(key, "_title_show"), value = FALSE)
        updateTextInput(session, paste0(key, "_title"), value = "")
        updateSelectInput(session, paste0(key, "_order"), selected = as.character(match(aes, graph_legend_aesthetics())))
      }
      updateCheckboxInput(session, "legend_linetype_show", value = TRUE)
      updateCheckboxInput(session, "legend_shape_show", value = TRUE)
      updateCheckboxInput(session, "legend_merge_linetype_shape", value = TRUE)
      updateCheckboxInput(session, "legend_merge_colour_shape", value = TRUE)
      updateCheckboxInput(session, "legend_title_show", value = FALSE)
      updateTextInput(session, "legend_group_title", value = "")
      updateCheckboxInput(session, "legend_individual_title_show", value = FALSE)
      updateTextInput(session, "legend_individual_title", value = "")
      updateSelectInput(session, "legend_wrap_mode", selected = "auto")
      updateSliderInput(session, "legend_wrap_count", value = 2)
      updateNumericInput(session, "legend_item_spacing", value = -1)
      updateNumericInput(session, "legend_text_size", value = 0)
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
