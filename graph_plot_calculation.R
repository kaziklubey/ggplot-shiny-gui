# Shared Graph/Figure plot calculation; input is a value provider supplied by the caller.
    use_value <- isTRUE(direct_value_mode())
    d <- if (identical(input$plot_type, "scatter") || use_value) {
      plot_data()
    } else {
      display_observation_data()
    }
    x <- resolved_xvar()
    y <- resolved_yvar()
    g <- effective_position_var(d)
    cvar <- resolve_color_var(d)
    lvar <- resolve_linetype_var(d)
    svar <- resolve_shape_var(d)
    facet <- if (has_selection(input$facetvar)) input$facetvar else ""
    id <- if (has_selection(input$idvar)) input$idvar else ""

    has_group <- nzchar(g)
    has_style <- nzchar(cvar)       # legacy name: Color mapping exists
    has_color <- nzchar(cvar)
    has_linetype <- nzchar(lvar)
    has_shape <- nzchar(svar)
    has_id <- nzchar(id)

    # Dynamic ggplot mapping helper. aes_string() is wrapped here so arbitrary
    # column names can be passed through .data[[...]] expressions.
    aes_ref <- function(nm) {
      paste0(".data[[", deparse(as.character(nm)), "]]")
    }

    dynamic_aes <- function(xcol = "", ycol = "", groupcol = "",
                            colourcol = "", linetypecol = "", shapecol = "",
                            ymincol = "", ymaxcol = "", fillcol = "",
                            xendcol = "", yendcol = "") {
      args <- list()
      if (nzchar(xcol)) args$x <- aes_ref(xcol)
      if (nzchar(ycol)) args$y <- aes_ref(ycol)
      if (nzchar(groupcol)) args$group <- aes_ref(groupcol)
      if (nzchar(colourcol)) args$colour <- aes_ref(colourcol)
      if (nzchar(linetypecol)) args$linetype <- aes_ref(linetypecol)
      if (nzchar(shapecol)) args$shape <- aes_ref(shapecol)
      if (nzchar(ymincol)) args$ymin <- aes_ref(ymincol)
      if (nzchar(ymaxcol)) args$ymax <- aes_ref(ymaxcol)
      if (nzchar(fillcol)) args$fill <- aes_ref(fillcol)
      if (nzchar(xendcol)) args$xend <- aes_ref(xendcol)
      if (nzchar(yendcol)) args$yend <- aes_ref(yendcol)
      suppressWarnings(do.call(ggplot2::aes_string, args))
    }

    add_interaction_key <- function(z, vars, name = ".auto_group__") {
      vars <- unique(vars[nzchar(vars) & vars %in% names(z)])
      if (!length(vars)) {
        z[[name]] <- factor(rep("all", nrow(z)))
      } else if (length(vars) == 1L) {
        z[[name]] <- factor(as.character(z[[vars[1]]]))
      } else {
        z[[name]] <- do.call(
          interaction,
          c(lapply(vars, function(v) z[[v]]), list(drop = TRUE, lex.order = TRUE))
        )
      }
      z
    }

    # Bar/Box: X×Facet内に実在する条件だけで横位置を中央揃えする。
    make_slot_layout <- function(raw, xcol, slot_vars, facetcol = "",
                                 x_positions, total_width = 0.80,
                                 spacing = 1.0, slot_name = ".slot__") {
      z <- add_interaction_key(raw, slot_vars, slot_name)
      z[[slot_name]] <- as.character(z[[slot_name]])
      global_slots <- unique(z[[slot_name]])
      global_slots <- global_slots[!is.na(global_slots)]

      key_vars <- unique(c(xcol, if (nzchar(facetcol)) facetcol else "", slot_name))
      key_vars <- key_vars[nzchar(key_vars)]
      grp <- unique(c(xcol, if (nzchar(facetcol)) facetcol else ""))
      grp <- grp[nzchar(grp)]

      lay <- z %>% distinct(across(all_of(key_vars)))
      lay$.global_order__ <- match(lay[[slot_name]], global_slots)

      lay <- lay %>%
        group_by(across(all_of(grp))) %>%
        arrange(.global_order__, .by_group = TRUE) %>%
        mutate(
          .slot_n__ = n(),
          .slot_i__ = row_number(),
          # slot幅は条件数だけで決める。spacingは中心距離だけに作用させる。
          .slot_width__ = total_width / pmax(.slot_n__, 1),
          .slot_step__ = .slot_width__ * spacing,
          .x_group__ = unname(x_positions[as.character(.data[[xcol]])]) +
            (.slot_i__ - (.slot_n__ + 1) / 2) * .slot_step__
        ) %>%
        ungroup()

      list(data=z, layout=lay, key_vars=key_vars,
           global_slots=global_slots, slot_vars=slot_vars,
           slot_name=slot_name)
    }

    apply_slot_layout <- function(z, obj) {
      z <- add_interaction_key(z, obj$slot_vars, obj$slot_name)
      z[[obj$slot_name]] <- as.character(z[[obj$slot_name]])
      keep <- unique(c(obj$key_vars, ".x_group__", ".slot_width__"))
      left_join(z, obj$layout[, keep, drop=FALSE], by=obj$key_vars)
    }

    # 横位置要因とColorは別々に扱う
    gl <- if (has_group) levels(d[[g]]) else character(0)
    if (has_group && (is.null(gl) || length(gl) == 0L)) {
      gl <- unique(as.character(d[[g]]))
    }
    gl <- gl[!is.na(gl)]

    sl <- if (has_style) levels(d[[cvar]]) else character(0)
    if (has_style && (is.null(sl) || length(sl) == 0L)) {
      sl <- unique(as.character(d[[cvar]]))
    }
    sl <- sl[!is.na(sl)]

    combo_override <- isTRUE(input$series_style_override) &&
      has_group && has_style && !identical(g, cvar)

    if (combo_override) {
      d$.style_display <- series_combo_key(
        as.character(d[[cvar]]),
        as.character(d[[g]])
      )
      style_var <- ".style_display"

      combo_levels <- series_combo_levels()
      # データに存在する組み合わせだけを残す
      observed_combo <- unique(as.character(d$.style_display))
      display_levels <- combo_levels[combo_levels %in% observed_combo]
      display_levels <- c(display_levels, setdiff(observed_combo, display_levels))
      styles <- series_style_vectors(display_levels)
    } else {
      style_var <- cvar
      display_levels <- sl
      if (has_style) {
        styles <- list(color = color_style_vector(cvar, display_levels))
      } else {
        styles <- NULL
      }
    }

    decorate_style <- function(z) {
      if (combo_override && nrow(z) > 0) {
        z$.style_display <- series_combo_key(
          as.character(z[[cvar]]),
          as.character(z[[g]])
        )
        z$.style_display <- factor(z$.style_display, levels = display_levels)
      }
      z
    }

    if (combo_override) {
      d <- decorate_style(d)
    }

    # Color mapping may use the existing Color × position override key.
    color_map_var <- if (has_color) style_var else ""

    # Linetype/Shape can either follow Color (backward-compatible default),
    # be fixed, or use an entirely different column.
    linetype_mode <- input$linetypevar %||% "__color__"
    shape_mode <- input$shapevar %||% "__color__"

    linetype_map_var <- if (identical(linetype_mode, "__color__")) {
      if (has_color) cvar else ""
    } else if (has_linetype) {
      lvar
    } else {
      ""
    }

    shape_map_var <- if (identical(shape_mode, "__color__")) {
      if (has_color) cvar else ""
    } else if (has_shape) {
      svar
    } else {
      ""
    }

    effective_has_linetype <- nzchar(linetype_map_var)
    effective_has_shape <- nzchar(shape_map_var)

    aes_levels <- function(z, var, preferred = NULL) {
      if (!nzchar(var) || !var %in% names(z)) return(character(0))
      if (!is.null(preferred) && length(preferred)) return(preferred)
      lv <- levels(z[[var]])
      if (is.null(lv) || !length(lv)) lv <- unique(as.character(z[[var]]))
      lv[!is.na(lv)]
    }

    linetype_levels <- if (effective_has_linetype) {
      if (identical(linetype_map_var, color_map_var) && has_color) {
        display_levels
      } else {
        aes_levels(d, linetype_map_var)
      }
    } else character(0)

    shape_levels <- if (effective_has_shape) {
      if (identical(shape_map_var, color_map_var) && has_color) {
        display_levels
      } else {
        aes_levels(d, shape_map_var)
      }
    } else character(0)

    linetype_values <- if (length(linetype_levels)) {
      line_style_var <- if (identical(linetype_mode, "__color__")) cvar else lvar
      linetype_style_vector(line_style_var, linetype_levels)
    } else NULL

    shape_values <- if (length(shape_levels)) {
      shape_style_var <- if (identical(shape_mode, "__color__")) cvar else svar
      shape_style_vector(shape_style_var, shape_levels)
    } else NULL

    color_legend_key <- if (combo_override) {
      paste0("__combo__::", cvar, "::", g)
    } else {
      cvar
    }

    color_title_default <- if (combo_override) paste0(cvar, " × ", g) else cvar
    color_legend_title <- if (has_color) {
      legend_title_value(color_legend_key, color_title_default)
    } else ""

    combo_display_labels <- function(keys_now) {
      if (!combo_override) return(level_label_values(cvar, keys_now))
      vapply(
        keys_now,
        function(k) {
          parts <- strsplit(k, " × ", fixed = TRUE)[[1]]
          if (length(parts) < 2L) return(k)
          a <- level_label_values(cvar, parts[1])
          b <- level_label_values(g, paste(parts[-1], collapse = " × "))
          paste0(a, " × ", b)
        },
        character(1)
      )
    }

    color_display_labels <- if (has_color) combo_display_labels(display_levels) else character(0)

    linetype_legend_key <- if (
      effective_has_linetype &&
      identical(linetype_map_var, color_map_var) &&
      has_color
    ) {
      color_legend_key
    } else {
      lvar
    }
    linetype_title_default <- if (
      effective_has_linetype &&
      identical(linetype_map_var, color_map_var) &&
      has_color
    ) color_title_default else lvar
    linetype_legend_title <- if (effective_has_linetype) {
      legend_title_value(linetype_legend_key, linetype_title_default)
    } else ""
    linetype_display_labels <- if (effective_has_linetype) {
      if (identical(linetype_map_var, color_map_var) && has_color) {
        color_display_labels
      } else {
        level_label_values(lvar, linetype_levels)
      }
    } else character(0)

    shape_legend_key <- if (
      effective_has_shape &&
      identical(shape_map_var, color_map_var) &&
      has_color
    ) {
      color_legend_key
    } else {
      svar
    }
    shape_title_default <- if (
      effective_has_shape &&
      identical(shape_map_var, color_map_var) &&
      has_color
    ) color_title_default else svar
    shape_legend_title <- if (effective_has_shape) {
      legend_title_value(shape_legend_key, shape_title_default)
    } else ""
    shape_display_labels <- if (effective_has_shape) {
      if (identical(shape_map_var, color_map_var) && has_color) {
        color_display_labels
      } else {
        level_label_values(svar, shape_levels)
      }
    } else character(0)

    raw_fixed_color <- if (identical(input$raw_color_mode, "custom_fixed")) {
      input$raw_fixed_custom
    } else {
      "gray30"
    }

    id_fixed_color <- if (identical(input$id_line_color_mode, "custom_fixed")) {
      input$id_line_custom_color
    } else {
      "gray50"
    }

    if (has_style) {
      style_key <- as.character(d[[style_var]])
      base_cols <- styles$color

      raw_cols <- if (identical(input$raw_color_mode, "group_light")) {
        setNames(vapply(base_cols, lighten_colour, character(1), amount = input$raw_lighten), names(base_cols))
      } else if (identical(input$raw_color_mode, "group")) {
        base_cols
      } else if (identical(input$raw_color_mode, "custom_group")) {
        if (combo_override) {
          # 組み合わせ上書き時は、その組み合わせの基本色を個体点にも反映
          base_cols
        } else {
          ensure_raw_group_colors(cvar, display_levels)
          rc <- raw_group_colors()[[cvar]] %||% list()
          setNames(vapply(display_levels, function(nm) as.character(rc[[nm]] %||% "#777777"), character(1)), display_levels)
        }
      } else if (identical(input$raw_color_mode, "custom_fixed")) {
        setNames(rep(input$raw_fixed_custom, length(display_levels)), display_levels)
      } else {
        setNames(rep("gray30", length(display_levels)), display_levels)
      }

      id_cols <- if (identical(input$id_line_color_mode, "group_light")) {
        setNames(vapply(base_cols, lighten_colour, character(1), amount = input$id_line_lighten), names(base_cols))
      } else if (identical(input$id_line_color_mode, "group")) {
        base_cols
      } else if (identical(input$id_line_color_mode, "custom_fixed")) {
        setNames(rep(input$id_line_custom_color, length(display_levels)), display_levels)
      } else {
        setNames(rep("gray50", length(display_levels)), display_levels)
      }
    } else {
      style_key <- rep(NA_character_, nrow(d))
      raw_cols <- NULL
      id_cols <- NULL
    }

    # ----------------------------------------------------------
    # Individual-data layer helpers
    #
    # geom_line() sorts observations by group/x internally. Passing an
    # n-row fixed colour vector outside aes() can therefore detach colours
    # from rows. Instead, draw one fixed-colour layer per Color level.
    #
    # Individual connection grouping is handled separately with
    # .id_group__, which combines ID with the currently mapped overlay
    # conditions (Series/Color/Linetype/Shape). This prevents Route a and
    # Route b of the same rat from being connected into one zig-zag line.
    # ----------------------------------------------------------
    add_id_line_layers <- function(
      p0, z, xcol, ycol, groupcol = ".id_group__",
      map_linetype = FALSE
    ) {
      if (!nrow(z)) return(p0)

      add_one <- function(p1, zz, col) {
        if (!nrow(zz)) return(p1)

        lt_col <- if (
          isTRUE(map_linetype) &&
          nzchar(linetype_map_var) &&
          linetype_map_var %in% names(zz)
        ) linetype_map_var else ""

        mp <- dynamic_aes(
          xcol = xcol,
          ycol = ycol,
          groupcol = groupcol,
          linetypecol = lt_col
        )

        args <- list(
          data = zz,
          mapping = mp,
          colour = col,
          linewidth = input$id_line_width,
          alpha = input$id_line_alpha,
          inherit.aes = FALSE
        )
        if (!nzchar(lt_col)) args$linetype <- input$id_linetype

        p1 + do.call(geom_line, args)
      }

      if (!has_color || is.null(id_cols)) {
        return(add_one(p0, z, id_fixed_color))
      }

      lev <- unique(as.character(z[[color_map_var]]))
      lev <- lev[!is.na(lev)]

      for (nm in lev) {
        zz <- z[as.character(z[[color_map_var]]) == nm, , drop = FALSE]
        col <- unname(id_cols[[nm]])

        if (is.null(col) || !length(col) || is.na(col) || !nzchar(col)) {
          col <- id_fixed_color
        }

        p0 <- add_one(p0, zz, col)
      }

      p0
    }

    add_raw_point_layers <- function(p0, z, xcol, ycol, shape_var = "") {
      if (!nrow(z)) return(p0)

      add_one <- function(p1, zz, col) {
        if (!nrow(zz)) return(p1)

        mp <- dynamic_aes(
          xcol = xcol,
          ycol = ycol,
          shapecol = shape_var
        )

        args <- list(
          mapping = mp,
          data = zz,
          colour = col,
          size = input$raw_point_size,
          alpha = input$raw_alpha,
          inherit.aes = FALSE
        )

        if (!nzchar(shape_var)) {
          args$shape <- as.numeric(input$raw_shape)
        }

        p1 + do.call(geom_point, args)
      }

      if (!has_color || is.null(raw_cols)) {
        return(add_one(p0, z, raw_fixed_color))
      }

      lev <- unique(as.character(z[[color_map_var]]))
      lev <- lev[!is.na(lev)]

      for (nm in lev) {
        zz <- z[as.character(z[[color_map_var]]) == nm, , drop = FALSE]
        col <- unname(raw_cols[[nm]])

        if (is.null(col) || !length(col) || is.na(col) || !nzchar(col)) {
          col <- raw_fixed_color
        }

        p0 <- add_one(p0, zz, col)
      }

      p0
    }

    # ---------------------------------------
    # LINE
    # ---------------------------------------
    if (input$plot_type == "line") {

      xl <- levels(d[[x]])
      if (is.null(xl)) xl <- unique(as.character(d[[x]]))

      # Line専用 X目盛間隔。
      # 単純に座標を一律倍するとggplotがscaleを再調整して見た目の
      # 目盛間隔がほぼ変わらないため、通常の1..N軸範囲を固定したまま
      # category centerだけを中央方向へ圧縮する。
      base_x_positions <- seq_along(xl)
      line_x_spacing <- suppressWarnings(as.numeric(input$line_x_spacing))
      if (!is.finite(line_x_spacing)) line_x_spacing <- 1.00
      line_x_spacing <- max(0, min(1.00, line_x_spacing))

      if (length(base_x_positions) <= 1L) {
        x_positions <- base_x_positions
      } else {
        x_center <- mean(range(base_x_positions))
        x_positions <- x_center + (base_x_positions - x_center) * line_x_spacing
      }

      d$.x_base <- x_positions[match(as.character(d[[x]]), xl)]

      # Series / Dodge controls horizontal position only.
      if (has_group) {
        n_group <- max(length(gl), 1)
        dodge_total <- suppressWarnings(as.numeric(input$line_group_dodge))
        if (!is.finite(dodge_total)) dodge_total <- 0.10
        dodge_total <- max(0, min(0.40, dodge_total))

        if (length(gl) == 0L) {
          gl <- unique(as.character(d[[g]]))
          gl <- gl[!is.na(gl)]
          n_group <- length(gl)
        }

        shiny::validate(shiny::need(
          length(gl) > 0L,
          paste0("Mappingエラー: Group列「", g, "」に有効な水準がありません。")
        ))

        if (n_group <= 1 || dodge_total == 0) {
          group_offsets <- setNames(rep(0, length(gl)), gl)
        } else {
          group_offsets <- setNames(
            seq(-dodge_total / 2, dodge_total / 2, length.out = length(gl)),
            gl
          )
        }

        mapped_offsets <- unname(group_offsets[as.character(d[[g]])])
        if (length(mapped_offsets) != nrow(d)) {
          mapped_offsets <- rep(0, nrow(d))
        } else {
          mapped_offsets[is.na(mapped_offsets)] <- 0
        }

        d$.x_group <- d$.x_base + mapped_offsets

        d <- add_stable_spread(
          d,
          x_col = x,
          group_col = g,
          facet_col = if (nzchar(facet)) facet else NULL,
          id_col = if (has_id) id else NULL,
          width = input$jitter_width
        )

        spread_scale <- max(0.02, (1 - dodge_total) / max(length(gl), 1))
        d$.x_raw <- d$.x_group + d$.spread__ * spread_scale

      } else {
        d$.x_group <- d$.x_base
        d <- add_stable_spread(
          d,
          x_col = x,
          group_col = NULL,
          facet_col = if (nzchar(facet)) facet else NULL,
          id_col = if (has_id) id else NULL,
          width = input$jitter_width
        )
        d$.x_raw <- d$.x_base + d$.spread__
      }

      # Every mapped overlay factor contributes to the actual mean/raw
      # trajectory grouping.
      overlay_vars_d <- unique(c(g, color_map_var, linetype_map_var, shape_map_var))
      if (has_id && use_value) overlay_vars_d <- unique(c(id, overlay_vars_d))
      d <- add_interaction_key(d, overlay_vars_d, ".line_group__")

      # Individual connection lines must never bridge different routes /
      # conditions of the same ID. Example:
      # ID5 × Route a and ID5 × Route b are two independent trajectories.
      if (has_id) {
        id_overlay_vars <- unique(c(
          id, g, color_map_var, linetype_map_var, shape_map_var
        ))
        d <- add_interaction_key(d, id_overlay_vars, ".id_group__")
      }

      if (use_value) {
        ext_bounds <- external_error_bounds(d, y)
        if (!is.null(ext_bounds)) {
          d$.ymin <- ext_bounds$ymin
          d$.ymax <- ext_bounds$ymax
        }

        p <- ggplot()

        line_map <- dynamic_aes(
          xcol = if (has_id) ".x_raw" else ".x_group",
          ycol = y,
          groupcol = ".line_group__",
          colourcol = color_map_var,
          linetypecol = linetype_map_var
        )

        line_args <- list(
          mapping = line_map,
          data = d,
          linewidth = input$line_width
        )
        if (!has_color) line_args$colour <- input$mean_color_mode
        if (!effective_has_linetype) line_args$linetype <- input$mean_linetype
        p <- p + do.call(geom_line, line_args)

        point_map <- dynamic_aes(
          xcol = if (has_id) ".x_raw" else ".x_group",
          ycol = y,
          colourcol = color_map_var,
          shapecol = shape_map_var
        )
        point_args <- list(mapping = point_map, data = d, size = input$point_size)
        if (!has_color) point_args$colour <- input$mean_color_mode
        if (!effective_has_shape) point_args$shape <- as.numeric(input$mean_shape)
        p <- p + do.call(geom_point, point_args)

        if (!is.null(ext_bounds)) {
          err_colour_var <- if (identical(input$error_color_mode, "group") && has_color) {
            color_map_var
          } else {
            ""
          }
          err_map <- dynamic_aes(
            xcol = if (has_id) ".x_raw" else ".x_group",
            ymincol = ".ymin",
            ymaxcol = ".ymax",
            colourcol = err_colour_var
          )
          err_args <- list(
            mapping = err_map,
            data = d,
            width = input$error_width,
            linewidth = input$error_line_width,
            inherit.aes = FALSE
          )
          if (!nzchar(err_colour_var)) {
            err_args$colour <- if (identical(input$error_color_mode, "fixed")) {
              input$error_color
            } else {
              input$mean_color_mode
            }
          }
          p <- p + do.call(geom_errorbar, err_args)
        }

      } else {
        s <- decorate_style(summary_data())
        s$.x_base <- x_positions[match(as.character(s[[x]]), xl)]

        if (has_group) {
          so <- unname(group_offsets[as.character(s[[g]])])
          if (length(so) != nrow(s)) so <- rep(0, nrow(s))
          so[is.na(so)] <- 0
          s$.x_group <- s$.x_base + so
        } else {
          s$.x_group <- s$.x_base
        }

        s <- add_interaction_key(
          s,
          unique(c(g, color_map_var, linetype_map_var, shape_map_var)),
          ".line_group__"
        )

        errcol <- switch(input$summary_type, sd = "sd", sem = "sem", ci95 = "ci95", NULL)
        if (!is.null(errcol)) {
          s$.ymin <- s$mean - s[[errcol]]
          s$.ymax <- s$mean + s[[errcol]]
        }

        p <- ggplot()

        add_summary_line_point <- function(p0) {
          line_map <- dynamic_aes(
            xcol = ".x_group",
            ycol = "mean",
            groupcol = ".line_group__",
            colourcol = color_map_var,
            linetypecol = linetype_map_var
          )
          line_args <- list(mapping = line_map, data = s, linewidth = input$line_width)
          if (!has_color) line_args$colour <- input$mean_color_mode
          if (!effective_has_linetype) line_args$linetype <- input$mean_linetype
          p0 <- p0 + do.call(geom_line, line_args)

          point_map <- dynamic_aes(
            xcol = ".x_group",
            ycol = "mean",
            colourcol = color_map_var,
            shapecol = shape_map_var
          )
          point_args <- list(mapping = point_map, data = s, size = input$point_size)
          if (!has_color) point_args$colour <- input$mean_color_mode
          if (!effective_has_shape) point_args$shape <- as.numeric(input$mean_shape)
          p0 + do.call(geom_point, point_args)
        }

        add_summary_errorbar <- function(p0) {
          if (is.null(errcol)) return(p0)

          err_colour_var <- if (identical(input$error_color_mode, "group") && has_color) {
            color_map_var
          } else {
            ""
          }

          err_map <- dynamic_aes(
            xcol = ".x_group",
            ymincol = ".ymin",
            ymaxcol = ".ymax",
            colourcol = err_colour_var
          )
          err_args <- list(
            mapping = err_map,
            data = s,
            width = input$error_width,
            linewidth = input$error_line_width,
            inherit.aes = FALSE
          )
          if (!nzchar(err_colour_var)) {
            err_args$colour <- if (identical(input$error_color_mode, "fixed")) {
              input$error_color
            } else {
              input$mean_color_mode
            }
          }
          p0 + do.call(geom_errorbar, err_args)
        }

        add_individual_layers <- function(p0) {
          if (isTRUE(input$connect_id) && has_id) {
            p0 <- add_id_line_layers(
              p0,
              d,
              xcol = ".x_raw",
              ycol = y,
              groupcol = ".id_group__"
            )
          }

          if (isTRUE(input$show_raw)) {
            raw_shape_var <- if (
              identical(input$raw_shape_mode, "group") && effective_has_shape
            ) shape_map_var else ""

            p0 <- add_raw_point_layers(
              p0,
              d,
              xcol = ".x_raw",
              ycol = y,
              shape_var = raw_shape_var
            )
          }

          p0
        }

        # 論文図では個体値を背景、平均・エラーバーを前景にするのを既定にする。
        if (isTRUE(input$summary_on_top)) {
          p <- add_individual_layers(p)
          p <- add_summary_line_point(p)
          p <- add_summary_errorbar(p)
        } else {
          p <- add_summary_line_point(p)
          p <- add_summary_errorbar(p)
          p <- add_individual_layers(p)
        }
      }

      if (input$plot_type != "box") {
        # Keep a predictable visible X frame without adding a second
        # coordinate system. `oob_keep` preserves dodge/jitter observations
        # outside the scale limits instead of censoring/removing those rows.
        edge_pad <- 0.55

        line_x_view <- if (length(xl) <= 1L) {
          c(x_positions[1] - edge_pad, x_positions[1] + edge_pad)
        } else {
          c(1 - edge_pad, length(xl) + edge_pad)
        }

        p <- p + scale_x_continuous(
          breaks = x_positions,
          labels = level_label_values(x, xl),
          limits = line_x_view,
          oob = scales::oob_keep,
          expand = expansion(mult = c(0, 0))
        )
      }
    }

    # ---------------------------------------
    # BAR
    # ---------------------------------------
    if (input$plot_type == "bar") {
      sbar <- if (use_value) d else decorate_style(summary_data())
      value_col <- if (use_value) y else "mean"
      has_errorbar <- FALSE

      if (!use_value) {
        errcol <- switch(input$summary_type, sd="sd", sem="sem", ci95="ci95", NULL)
        if (!is.null(errcol)) {
          sbar$.ymin <- sbar$mean - sbar[[errcol]]
          sbar$.ymax <- sbar$mean + sbar[[errcol]]
          has_errorbar <- TRUE
        }
      } else {
        errcol <- NULL
        ext_bounds_bar <- external_error_bounds(sbar, y)
        if (!is.null(ext_bounds_bar)) {
          sbar$.ymin <- ext_bounds_bar$ymin
          sbar$.ymax <- ext_bounds_bar$ymax
          has_errorbar <- TRUE
        }
      }

      xl <- levels(d[[x]])
      if (is.null(xl)) xl <- unique(as.character(d[[x]]))

      # Xカテゴリ間隔は、先頭カテゴリを固定して右へだけ伸ばすのではなく、
      # 1..N の中央を基準に左右対称に伸縮する。
      # spacing = 1.0 では従来の 1..N と完全に同じ位置になる。
      base_x_positions <- seq_along(xl)
      x_center <- if (length(base_x_positions)) mean(base_x_positions) else 1
      x_spacing <- suppressWarnings(as.numeric(input$x_category_spacing))
      if (!is.finite(x_spacing)) x_spacing <- 1.0
      x_positions <- setNames(
        x_center + (base_x_positions - x_center) * x_spacing,
        xl
      )

      slot_vars <- unique(c(
        if (has_group) g else "",
        if (has_color) color_map_var else ""
      ))
      slot_vars <- slot_vars[nzchar(slot_vars)]

      slot_obj <- make_slot_layout(
        d, x, slot_vars, facet, x_positions,
        total_width=0.80, spacing=input$group_spacing,
        slot_name=".bar_slot__"
      )
      d <- slot_obj$data
      keep <- unique(c(slot_obj$key_vars, ".x_group__", ".slot_width__"))
      d <- left_join(d, slot_obj$layout[, keep, drop=FALSE], by=slot_obj$key_vars)
      sbar <- apply_slot_layout(sbar, slot_obj)

      slot_width <- 0.80 / max(length(slot_obj$global_slots), 1L)

      d <- add_stable_spread(
        d, x_col=x, group_col=".bar_slot__", facet_col=if (nzchar(facet)) facet else NULL,
        id_col=if (has_id) id else NULL, width=input$jitter_width
      )
      d$.x_raw <- d$.x_group__ + d$.spread__ * slot_width

      if (has_id) {
        # Barの個体線:
        # ID × Color × 追加横並び要因を基本系列とする。
        # その系列内で同じXに複数点が残る場合は、行順に反復track番号を付け、
        # 同一block内の点同士を縦につながない。
        bar_id_vars <- unique(c(
          id,
          color_map_var,
          if (has_group) g else "",
          if (nzchar(facet)) facet else ""
        ))
        bar_id_vars <- bar_id_vars[nzchar(bar_id_vars)]

        repeat_group_vars <- unique(c(bar_id_vars, x))
        d <- d %>%
          group_by(across(all_of(repeat_group_vars))) %>%
          mutate(.bar_repeat_track__ = row_number()) %>%
          ungroup()

        bar_line_vars <- unique(c(bar_id_vars, ".bar_repeat_track__"))
        d <- add_interaction_key(d, bar_line_vars, ".id_group__")
      }

      border_matches_fill <- identical(input$bar_border_mode %||% "fixed", "fill")
      border_map_var <- if (border_matches_fill && has_color) color_map_var else ""
      bar_map <- dynamic_aes(
        xcol=".x_group__", ycol=value_col,
        fillcol=color_map_var, colourcol=border_map_var
      )
      bar_args <- list(
        mapping = bar_map,
        data = sbar,
        width = slot_width * input$bar_width,
        position = "identity",
        linewidth = input$bar_border_width
      )
      if (!has_color) bar_args$fill <- input$mean_color_mode
      if (!nzchar(border_map_var)) {
        bar_args$colour <- if (border_matches_fill) input$mean_color_mode else input$bar_border_color
      }
      p <- ggplot() + do.call(geom_col, bar_args)

      if (isTRUE(has_errorbar)) {
        err_colour_var <- if (identical(input$error_color_mode,"group") && has_color) color_map_var else ""
        err_map <- dynamic_aes(xcol=".x_group__", ymincol=".ymin", ymaxcol=".ymax", colourcol=err_colour_var)
        err_args <- list(mapping=err_map, data=sbar, width=input$error_width,
                         linewidth=input$error_line_width, inherit.aes=FALSE)
        if (!nzchar(err_colour_var)) err_args$colour <- if (identical(input$error_color_mode,"fixed")) input$error_color else input$mean_color_mode
        p <- p + do.call(geom_errorbar, err_args)
      }

      if (isTRUE(input$connect_id) && has_id) {
        p <- add_id_line_layers(p,d,xcol=".x_raw",ycol=y,groupcol=".id_group__")
      }
      if (isTRUE(input$show_raw)) {
        raw_shape_var <- if (identical(input$raw_shape_mode,"group") && effective_has_shape) shape_map_var else ""
        p <- add_raw_point_layers(p,d,xcol=".x_raw",ycol=y,shape_var=raw_shape_var)
      }

      if (input$plot_type != "box") {
        # カテゴリ間隔を大きくしても左端だけがY軸へ張り付かないよう、
        # 実際に描くバー・raw点・error barの横方向の端を集め、
        # Xカテゴリ列の中央を基準に左右対称の表示範囲を作る。
        # 余白は相対%ではなく一定量を足すため、spacingを広げたときも
        # 外側のバーとpanel端の余白が極端に小さくならない。
        bar_half_width <- 0.5 * slot_width * input$bar_width
        x_extent <- c(
          sbar$.x_group__ - bar_half_width,
          sbar$.x_group__ + bar_half_width
        )

        if (isTRUE(has_errorbar)) {
          err_half_width <- 0.5 * suppressWarnings(as.numeric(input$error_width))
          if (!is.finite(err_half_width)) err_half_width <- 0
          x_extent <- c(
            x_extent,
            sbar$.x_group__ - err_half_width,
            sbar$.x_group__ + err_half_width
          )
        }

        if ((isTRUE(input$show_raw) || (isTRUE(input$connect_id) && has_id)) &&
            ".x_raw" %in% names(d)) {
          x_extent <- c(x_extent, d$.x_raw)
        }

        x_extent <- x_extent[is.finite(x_extent)]
        frame_center <- if (length(base_x_positions)) mean(base_x_positions) else 1
        frame_pad <- 0.35
        if (length(x_extent)) {
          frame_radius <- max(abs(x_extent - frame_center), na.rm = TRUE) + frame_pad
        } else {
          frame_radius <- 0.55
        }
        # 1カテゴリでも通常の離散Xらしい左右余白を確保する。
        frame_radius <- max(frame_radius, 0.55)
        bar_x_view <- c(frame_center - frame_radius, frame_center + frame_radius)

        p <- p + scale_x_continuous(
          breaks = unname(x_positions),
          labels = level_label_values(x, xl),
          limits = bar_x_view,
          oob = scales::oob_keep,
          expand = expansion(mult = c(0, 0))
        )
      }
    }

    # ---------------------------------------
    # SCATTER
    # ---------------------------------------
    if (input$plot_type == "scatter") {
      scatter_map <- dynamic_aes(
        xcol = x,
        ycol = y,
        colourcol = color_map_var,
        shapecol = shape_map_var
      )

      point_args <- list(
        mapping = scatter_map,
        data = d,
        size = input$point_size,
        alpha = 0.90
      )
      if (!has_color) point_args$colour <- input$mean_color_mode
      if (!effective_has_shape) point_args$shape <- as.numeric(input$mean_shape)

      p <- ggplot() + do.call(geom_point, point_args)

      scatter_connect_mode <- input$scatter_connect_mode %||% "none"

      if (identical(scatter_connect_mode, "id") && has_id) {
        scatter_id_vars <- unique(c(id, color_map_var, linetype_map_var, shape_map_var))
        d <- add_interaction_key(d, scatter_id_vars, ".id_group__")
        p <- add_id_line_layers(
          p, d, xcol=x, ycol=y, groupcol=".id_group__",
          map_linetype = TRUE
        )
      }

      if (identical(scatter_connect_mode, "row")) {
        # 行i -> 行i+1を独立segmentとして描く。
        # geom_path()は非solid線で途中のcolour/linetypeが変わると
        # draw_panel()でエラーになるため、segment単位に分離する。
        if (nrow(d) >= 2L) {
          starts <- seq_len(nrow(d) - 1L)
          ends <- seq.int(2L, nrow(d))
          keep_segment <- rep(TRUE, length(starts))

          if (nzchar(facet) && facet %in% names(d)) {
            facet_start <- as.character(d[[facet]][starts])
            facet_end <- as.character(d[[facet]][ends])
            keep_segment <- !is.na(facet_start) & !is.na(facet_end) &
              facet_start == facet_end
          }

          seg <- d[starts[keep_segment], , drop = FALSE]
          seg$.xend__ <- d[[x]][ends[keep_segment]]
          seg$.yend__ <- d[[y]][ends[keep_segment]]

          seg_map <- dynamic_aes(
            xcol = x,
            ycol = y,
            xendcol = ".xend__",
            yendcol = ".yend__",
            colourcol = if (has_color) color_map_var else "",
            linetypecol = if (effective_has_linetype) linetype_map_var else ""
          )

          seg_args <- list(
            mapping = seg_map,
            data = seg,
            linewidth = input$id_line_width,
            alpha = input$id_line_alpha,
            inherit.aes = FALSE
          )
          if (!has_color) seg_args$colour <- input$mean_color_mode
          if (!effective_has_linetype) seg_args$linetype <- input$id_linetype

          p <- p + do.call(geom_segment, seg_args)
        }
      }

      # 線形回帰
      if (isTRUE(input$scatter_regression)) {
        shiny::validate(
          shiny::need(
            is.numeric(d[[x]]) && is.numeric(d[[y]]) &&
              sum(is.finite(d[[x]]) & is.finite(d[[y]])) >= 2 &&
              length(unique(d[[x]][is.finite(d[[x]])])) >= 2,
            "回帰直線には、数値のX/Yと2つ以上の異なるX値が必要です。"
          )
        )

        reg_mode <- input$scatter_regression_group %||% "overall"
        if (!reg_mode %in% c("overall", "style")) reg_mode <- "overall"
        reg_se <- isTRUE(input$scatter_regression_se)
        reg_alpha <- suppressWarnings(as.numeric(input$scatter_regression_se_alpha))
        if (!is.finite(reg_alpha)) reg_alpha <- 0.20

        if (identical(reg_mode, "overall")) {
          p <- p + geom_smooth(
            data = d,
            aes(x = .data[[x]], y = .data[[y]]),
            method = "lm",
            formula = y ~ x,
            se = reg_se,
            colour = input$scatter_regression_color,
            fill = input$scatter_regression_color,
            linetype = input$scatter_regression_linetype,
            linewidth = input$scatter_regression_width,
            alpha = reg_alpha,
            inherit.aes = FALSE
          )
        } else {
          reg_var <- if (identical(reg_mode, "style") && has_style) style_var else ""

          if (nzchar(reg_var)) {
            lev <- unique(as.character(d[[reg_var]]))
            lev <- lev[!is.na(lev)]
            ensure_regression_styles(lev)
            rs <- regression_styles()

            # 各回帰線を別レイヤーで描くことで、線ごとの色・線種・線幅を独立設定
            for (nm in lev) {
              dd <- d[as.character(d[[reg_var]]) == nm, , drop = FALSE]

              # lmには少なくとも2つの異なるXが必要
              if (nrow(dd) >= 2 && length(unique(dd[[x]])) >= 2) {
                st <- rs[[nm]]
                p <- p + geom_smooth(
                  data = dd,
                  aes(x = .data[[x]], y = .data[[y]]),
                  method = "lm",
                  formula = y ~ x,
                  se = reg_se,
                  colour = st$color,
                  fill = st$color,
                  linetype = st$linetype,
                  linewidth = st$width,
                  alpha = reg_alpha,
                  inherit.aes = FALSE
                )
              }
            }
          }
        }
      }

    }

    # ---------------------------------------
    # BOXPLOT
    # ---------------------------------------
    if (input$plot_type == "box") {
      xl <- levels(d[[x]])
      if (is.null(xl)) xl <- unique(as.character(d[[x]]))
      x_positions <- setNames(seq_along(xl), xl)

      slot_vars <- unique(c(
        if (has_group) g else "",
        if (has_color) color_map_var else ""
      ))
      slot_vars <- slot_vars[nzchar(slot_vars)]

      slot_obj <- make_slot_layout(
        d, x, slot_vars, facet, x_positions,
        total_width=0.78, spacing=input$group_spacing,
        slot_name=".box_slot__"
      )
      d <- slot_obj$data
      keep <- unique(c(slot_obj$key_vars, ".x_group__", ".slot_width__"))
      d <- left_join(d, slot_obj$layout[, keep, drop=FALSE], by=slot_obj$key_vars)

      # 箱の太さは中心間隔とは独立。
      # 各X×Facet内のslot幅に対する割合として決める。
      box_width_scale <- suppressWarnings(as.numeric(input$box_width_scale %||% 0.72))
      if (!is.finite(box_width_scale)) box_width_scale <- 0.72
      box_width_scale <- max(0, min(0.95, box_width_scale))
      d$.box_width__ <- d$.slot_width__ * box_width_scale

      # x is now an explicit numeric position, so geom_boxplot must be
      # grouped by X × slot. Grouping only by slot would pool all X levels
      # into one box near the middle of the axis.
      d <- add_interaction_key(
        d,
        c(x, ".box_slot__"),
        ".box_group__"
      )

      border_matches_fill <- identical(input$bar_border_mode %||% "fixed", "fill")
      border_map_var <- if (border_matches_fill && has_color) color_map_var else ""
      box_map <- dynamic_aes(
        xcol=".x_group__", ycol=y,
        groupcol=".box_group__", fillcol=color_map_var,
        colourcol=border_map_var
      )
      box_map$width <- rlang::sym(".box_width__")
      box_args <- list(
        mapping=box_map, data=d,
        linewidth=input$bar_border_width,
        outlier.shape=NA,
        orientation="x"
      )
      if (!has_color) box_args$fill <- input$mean_color_mode
      if (!nzchar(border_map_var)) {
        box_args$colour <- if (border_matches_fill) input$mean_color_mode else input$bar_border_color
      }
      p <- ggplot() + do.call(geom_boxplot, box_args)

      if (isTRUE(input$show_raw)) {
        d <- add_stable_spread(
          d, x_col=x, group_col=".box_slot__",
          facet_col=if (nzchar(facet)) facet else NULL,
          id_col=if (has_id) id else NULL,
          width=input$jitter_width
        )
        # 個体点は各Box中心の近傍だけに散らす。
        # jitter_width=1でも隣のBoxへ侵食しにくいよう最大45%に制限。
        raw_half_width <- d$.box_width__ * 0.45
        d$.x_raw <- d$.x_group__ + d$.spread__ * raw_half_width

        raw_shape_var <- if (
          identical(input$raw_shape_mode,"group") && effective_has_shape
        ) shape_map_var else ""

        p <- add_raw_point_layers(
          p, d, xcol=".x_raw", ycol=y, shape_var=raw_shape_var
        )
      }

      p <- p + scale_x_continuous(
        breaks=unname(x_positions),
        labels=level_label_values(x,xl),
        expand=expansion(mult=c(0.06,0.06))
      ) +
      theme(
        axis.line.x = element_line(
          colour = "black",
          linewidth = 0.5
        ),
        axis.ticks.x = element_line(
          colour = "black",
          linewidth = 0.5
        ),
        axis.ticks.length.x = grid::unit(0.12, "cm"),
        axis.text.x = element_text(colour = "black")
      )
    }

    # ---------------------------------------
    # Manual colour / linetype / shape scales
    # ---------------------------------------
    if (has_color) {
      if (input$plot_type %in% c("bar", "box")) {
        fill_values <- styles$color
        fill_levels_now <- display_levels

        if (nzchar(color_map_var) && color_map_var %in% names(d)) {
          mapped_levels <- unique(as.character(d[[color_map_var]]))
          mapped_levels <- mapped_levels[!is.na(mapped_levels)]
          keep_levels <- intersect(names(fill_values), mapped_levels)
          if (length(keep_levels)) {
            fill_values <- fill_values[keep_levels]
            fill_levels_now <- fill_levels_now[fill_levels_now %in% keep_levels]
          }
        }

        if (length(fill_values)) {
          p <- p + scale_fill_manual(
            values = fill_values,
            breaks = fill_levels_now,
            labels = color_display_labels[match(fill_levels_now, display_levels)],
            drop = FALSE
          )
        }
      }

      needs_colour_scale <- input$plot_type %in% c("line", "scatter")
      if (input$plot_type %in% c("bar", "box") &&
          identical(input$bar_border_mode %||% "fixed", "fill") &&
          nzchar(color_map_var) && color_map_var %in% names(d)) {
        needs_colour_scale <- TRUE
      }
      if (input$plot_type == "bar" &&
          identical(input$error_color_mode, "group") &&
          nzchar(color_map_var) && color_map_var %in% names(d)) {
        needs_colour_scale <- TRUE
      }

      if (isTRUE(needs_colour_scale)) {
        colour_values <- styles$color
        colour_levels_now <- display_levels

        # Manual scale should only contain levels actually represented by
        # the mapped colour variable. This prevents stale style names from
        # generating "No shared levels found" warnings.
        if (nzchar(color_map_var) && color_map_var %in% names(d)) {
          mapped_levels <- unique(as.character(d[[color_map_var]]))
          mapped_levels <- mapped_levels[!is.na(mapped_levels)]
          keep_levels <- intersect(names(colour_values), mapped_levels)
          if (length(keep_levels)) {
            colour_values <- colour_values[keep_levels]
            colour_levels_now <- colour_levels_now[colour_levels_now %in% keep_levels]
          }
        }

        if (length(colour_values)) {
          p <- p + scale_colour_manual(
            values = colour_values,
            breaks = colour_levels_now,
            labels = color_display_labels[match(colour_levels_now, display_levels)],
            drop = FALSE
          )
        }
      }
    }

    uses_mapped_linetype <- identical(input$plot_type, "line")
    if (identical(input$plot_type, "scatter")) {
      scatter_mode_now <- input$scatter_connect_mode %||% "none"
      uses_mapped_linetype <- scatter_mode_now %in% c("id", "row")
    }

    if (isTRUE(uses_mapped_linetype) &&
        effective_has_linetype && length(linetype_levels)) {
      lt_values_now <- linetype_values
      lt_levels_now <- linetype_levels
      lt_labels_now <- linetype_display_labels

      if (nzchar(linetype_map_var) && linetype_map_var %in% names(d)) {
        mapped_lt <- unique(as.character(d[[linetype_map_var]]))
        mapped_lt <- mapped_lt[!is.na(mapped_lt)]
        keep_lt <- intersect(names(lt_values_now), mapped_lt)

        if (length(keep_lt)) {
          lt_values_now <- lt_values_now[keep_lt]
          idx_lt <- match(keep_lt, lt_levels_now)
          idx_lt <- idx_lt[!is.na(idx_lt)]
          lt_levels_now <- lt_levels_now[idx_lt]
          lt_labels_now <- lt_labels_now[idx_lt]
        } else {
          lt_values_now <- character(0)
          lt_levels_now <- character(0)
          lt_labels_now <- character(0)
        }
      }

      if (length(lt_values_now) && length(lt_levels_now)) {
        p <- p + scale_linetype_manual(
          values = lt_values_now,
          breaks = lt_levels_now,
          labels = lt_labels_now,
          drop = FALSE
        )
      }
    }

    if (input$plot_type %in% c("line", "scatter", "bar", "box") &&
        effective_has_shape && length(shape_levels)) {
      p <- p + scale_shape_manual(
        values = shape_values,
        breaks = shape_levels,
        labels = shape_display_labels,
        drop = FALSE
      )
    }

    # Facet
    if (nzchar(facet)) {
      flev <- levels(d[[facet]])
      if (is.null(flev) || !length(flev)) {
        flev <- unique(as.character(d[[facet]]))
      }
      flev <- flev[!is.na(flev)]

      flab <- stats::setNames(
        level_label_values(facet, flev),
        flev
      )

      p <- p + facet_wrap(
        vars(.data[[facet]]),
        labeller = ggplot2::as_labeller(flab)
      )
    }

    # Labels
    label_args <- list(
      x = if (nzchar(input$xlab)) normalize_multiline_label(input$xlab) else x,
      y = if (nzchar(input$ylab)) normalize_multiline_label(input$ylab) else y,
      title = if (nzchar(input$title)) input$title else NULL
    )

    # Assign with single-bracket list semantics so NULL is retained as a
    # named labs() argument.  `labs(fill = NULL)` removes the guide title;
    # `$fill <- NULL` would instead delete the argument and restore ggplot's
    # default Mapping/scale title.
    legend_title_lab_value <- function(x) {
      z <- as.character(x %||% "")[1]
      if (!nzchar(trimws(z))) NULL else z
    }
    set_legend_lab <- function(args, aesthetic, value) {
      args[aesthetic] <- list(legend_title_lab_value(value))
      args
    }

    if (has_color) {
      if (input$plot_type %in% c("bar", "box")) {
        label_args <- set_legend_lab(label_args, "fill", color_legend_title)
      }
      if (input$plot_type %in% c("line", "scatter") ||
          (!use_value && input$plot_type == "bar" &&
             identical(input$error_color_mode, "group"))) {
        label_args <- set_legend_lab(label_args, "colour", color_legend_title)
      }
    }

    if (input$plot_type == "line" && effective_has_linetype) {
      label_args <- set_legend_lab(label_args, "linetype", linetype_legend_title)
    }

    if (input$plot_type %in% c("line", "scatter") && effective_has_shape) {
      label_args <- set_legend_lab(label_args, "shape", shape_legend_title)
    }

    p <- p + do.call(labs, label_args) + theme_object()

    # ---------------------------------------
    # Stable Y range
    # ---------------------------------------
    if (use_value) {
      y_candidates <- d[[y]]
      ext_range <- external_error_bounds(d, y)
      if (!is.null(ext_range)) {
        y_candidates <- c(y_candidates, ext_range$ymin, ext_range$ymax)
      }
    } else if (input$plot_type %in% c("line", "bar")) {
      s2 <- summary_data()
      y_candidates <- c(d[[y]], s2$mean)
      if (input$summary_type %in% c("sd", "sem", "ci95")) {
        errcol2 <- switch(input$summary_type, sd = "sd", sem = "sem", ci95 = "ci95")
        y_candidates <- c(y_candidates, s2$mean - s2[[errcol2]], s2$mean + s2[[errcol2]])
      }
    } else {
      y_candidates <- d[[y]]
    }

    if (input$plot_type == "bar") y_candidates <- c(y_candidates, 0)
    y_candidates <- y_candidates[is.finite(y_candidates)]
    bar_all_nonnegative <- !length(y_candidates) || min(y_candidates) >= 0

    auto_min <- if (length(y_candidates)) min(y_candidates) else 0
    auto_max <- if (length(y_candidates)) max(y_candidates) else 1
    span <- auto_max - auto_min
    if (!is.finite(span) || span <= 0) span <- max(abs(c(auto_min, auto_max)), 1)
    pad <- span * 0.05
    auto_min <- auto_min - pad
    auto_max <- auto_max + pad

    user_ymin <- suppressWarnings(as.numeric(input$ymin))
    user_ymax <- suppressWarnings(as.numeric(input$ymax))
    final_ymin <- if (is.finite(user_ymin)) user_ymin else auto_min
    final_ymax <- if (is.finite(user_ymax)) user_ymax else auto_max

    # 論文図向け: Y軸上端を最終目盛りに合わせる。
    # 手動stepでは現在上端以上の最初のtickへ、autoではpretty breakの
    # 現在上端以上のtickへ上端を合わせる。データを切らない方向にのみ調整する。
    if (isTRUE(input$y_top_to_tick) && is.finite(final_ymax) && is.finite(final_ymin) &&
        final_ymax > final_ymin) {
      if (!isTRUE(input$y_breaks_auto)) {
        step_top <- suppressWarnings(as.numeric(input$y_breaks_step))
        if (is.finite(step_top) && step_top > 0) {
          top_tick <- ceiling(final_ymax / step_top) * step_top
          if (is.finite(top_tick) && top_tick >= final_ymax) final_ymax <- top_tick
        }
      } else {
        pretty_ticks <- pretty(c(final_ymin, final_ymax), n = 5)
        pretty_ticks <- pretty_ticks[is.finite(pretty_ticks) & pretty_ticks >= final_ymax]
        if (length(pretty_ticks)) final_ymax <- min(pretty_ticks)
      }
    }

    # 正の棒グラフでは0とバー底の余白をなくす
    zero_touch <- isTRUE(
      input$plot_type == "bar" && input$bar_zero_touch && bar_all_nonnegative
    )
    if (zero_touch && (!is.finite(user_ymin) || user_ymin >= 0)) {
      final_ymin <- 0
    }

    break_is_valid <- FALSE
    break_from <- suppressWarnings(as.numeric(input$y_break_from))
    break_to <- suppressWarnings(as.numeric(input$y_break_to))

    if (isTRUE(input$y_break_enabled) &&
        is.finite(break_from) && is.finite(break_to) &&
        break_to > break_from &&
        break_from > final_ymin &&
        break_to < final_ymax) {
      break_is_valid <- TRUE
    }

    if (break_is_valid) {
      # Do not combine coord_cartesian() with ggbreak.  Applying both creates
      # duplicated/compressed panels and overlapping tick labels.
      gap_space <- suppressWarnings(as.numeric(input$y_break_space))
      if (!is.finite(gap_space)) gap_space <- 0.08
      gap_space <- max(0.02, min(0.30, gap_space))

      p <- p +
        scale_y_continuous(
          limits = c(final_ymin, final_ymax),
          breaks = y_break_values(final_ymin, final_ymax),
          expand = expansion(mult = c(if (zero_touch) 0 else 0.02, if (isTRUE(input$y_top_to_tick)) 0 else 0.05))
        ) +
        ggbreak::scale_y_break(
          c(break_from, break_to),
          scales = 1,
          space = gap_space
        )

      # ggbreak supplies the actual discontinuous scale.  A custom text
      # annotation inside the data panel caused label collisions in v1.8,
      # so the visual cue is now a small caption outside the plotting data.
      if (isTRUE(input$y_break_symbol)) {
        p <- p +
          labs(caption = paste0("∿  Y-axis omitted: ", break_from, " – ", break_to)) +
          theme(
            plot.caption = element_text(
              hjust = 0,
              size = max(7, input$base_size * 0.70),
              margin = margin(t = 4)
            )
          )
      }

    } else {
      if (final_ymax > final_ymin) {
        p <- p +
          scale_y_continuous(
            breaks = y_break_values(final_ymin, final_ymax),
            expand = expansion(mult = c(if (zero_touch) 0 else 0.05, if (isTRUE(input$y_top_to_tick)) 0 else 0.05))
          ) +
          coord_cartesian(
            ylim = c(final_ymin, final_ymax),
            clip = "off"
          )
      }
    }

