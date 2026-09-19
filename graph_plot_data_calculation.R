compute_plot_data <- function() {
    d <- dat()

    x_now <- resolved_xvar()
    y_now <- resolved_yvar()

    shiny::validate(shiny::need(
      !is.null(y_now) && length(y_now) && y_now %in% names(d),
      "Y列を選択してください。"
    ))
    shiny::validate(shiny::need(
      !is.null(x_now) && length(x_now) && x_now %in% names(d),
      "X列を選択してください。"
    ))
    shiny::validate(shiny::need(
      !identical(x_now, y_now),
      "Mappingエラー: X と Y には別の列を指定してください。"
    ))

    # このreactive内では、UI再生成中でも最後の有効Mappingを使う。
    xvar_now <- as.character(x_now)[1]
    yvar_now <- as.character(y_now)[1]

    # 現行GUIでは 横位置要因 / Color / ID / Facet は離散的な割り当て。
    # Yと同じ列を使うと後段でfactor化され、sd()等が失敗するため明示的に止める。
    cvar_guard <- resolve_color_var(d)
    lvar_guard <- resolve_linetype_var(d)
    svar_guard <- resolve_shape_var(d)

    categorical_map <- c(
      effective_position_var(d),
      cvar_guard,
      lvar_guard,
      svar_guard,
      if (has_selection(input$idvar)) input$idvar else "",
      if (has_selection(input$facetvar)) input$facetvar else ""
    )
    categorical_map <- unique(categorical_map[nzchar(categorical_map)])

    shiny::validate(shiny::need(
      !yvar_now %in% categorical_map,
      paste0(
        "Mappingエラー: Y列「", yvar_now,
        "」が 横位置要因 / Color / ID / Facet と重複しています。",
        " Project復元時にこの表示が出た場合はMappingを確認して再保存してください。"
      )
    ))

    d[[yvar_now]] <- suppressWarnings(as.numeric(d[[yvar_now]]))
    d <- d[!is.na(d[[yvar_now]]), , drop = FALSE]
    shiny::validate(shiny::need(nrow(d) > 0, "Y列に数値データがありません。"))

    if (identical(input$plot_type %||% "line", "scatter")) {
      x_num_test <- suppressWarnings(as.numeric(d[[xvar_now]]))
      shiny::validate(shiny::need(
        sum(is.finite(x_num_test)) > 0L,
        "散布図のX軸には数値列を選択してください。"
      ))
    }

    # X軸:
    # 散布図では回帰・相関用に数値Xを保持する。
    # それ以外のカテゴリ型プロットでは設定順をfactor levelへ反映する。
    if (has_selection(xvar_now) && xvar_now %in% names(d)) {
      if (identical(input$plot_type, "scatter")) {
        if (!is.numeric(d[[xvar_now]])) {
          x_chr <- trimws(as.character(d[[xvar_now]]))
          present <- !is.na(x_chr) & nzchar(x_chr)
          x_num <- suppressWarnings(as.numeric(x_chr))

          # Convert character numerics only when every present value converts.
          # Mixed columns such as 1, 2, Control remain categorical instead of
          # silently dropping Control.
          if (any(present) && all(is.finite(x_num[present]))) {
            d[[xvar_now]] <- x_num
          } else {
            obs_x <- unique(x_chr[present])
            d[[xvar_now]] <- factor(x_chr, levels = obs_x)
          }
        }
      } else {
        xl <- get_saved_order("x", xvar_now, unique(as.character(d[[xvar_now]])))
        d[[xvar_now]] <- factor(as.character(d[[xvar_now]]), levels = xl)
      }
    }

    if (has_selection(input$groupvar) && input$groupvar %in% names(d)) {
      observed_group <- unique(as.character(d[[input$groupvar]]))
      observed_group <- observed_group[!is.na(observed_group)]

      gl <- get_saved_order("group", input$groupvar, observed_group)

      # Project復元途中などで保存orderが空・staleでも、
      # 実データの水準へ必ずフォールバックする。
      if (length(gl) == 0L) {
        gl <- observed_group
      } else {
        gl <- c(gl[gl %in% observed_group], setdiff(observed_group, gl))
      }

      d[[input$groupvar]] <- factor(as.character(d[[input$groupvar]]), levels = gl)
    }

    cvar_plot <- resolve_color_var(d)
    if (nzchar(cvar_plot) && cvar_plot %in% names(d)) {
      observed_style <- unique(as.character(d[[cvar_plot]]))
      observed_style <- observed_style[!is.na(observed_style)]

      # If the same variable was already ordered as X or Group, preserve that
      # factor order. A factor that merely came from Wide→Long is not enough to
      # suppress Color's own ordering.
      preserve_color_order <- cvar_plot %in% c(
        xvar_now %||% "",
        if (has_selection(input$groupvar)) input$groupvar else ""
      ) && is.factor(d[[cvar_plot]])
      existing_levels <- if (preserve_color_order) levels(d[[cvar_plot]]) else character(0)
      if (length(existing_levels)) {
        sl <- existing_levels
      } else {
        sl <- style_levels()
        if (length(sl) == 0L) {
          sl <- observed_style
        } else {
          sl <- c(sl[sl %in% observed_style], setdiff(observed_style, sl))
        }
      }

      d[[cvar_plot]] <- factor(as.character(d[[cvar_plot]]), levels = sl)
    }

    # Linetype / Shape がColorとは別の列なら独立factorとして保持する。
    # 同じ列がすでにX/Group/Colorとして明示的に順序付けされた場合だけ保護する。
    extra_aes_vars <- unique(c(resolve_linetype_var(d), resolve_shape_var(d)))
    extra_aes_vars <- extra_aes_vars[nzchar(extra_aes_vars)]
    already_ordered_vars <- unique(c(
      xvar_now %||% "",
      if (has_selection(input$groupvar)) input$groupvar else "",
      cvar_plot
    ))
    for (v in extra_aes_vars) {
      if (!v %in% names(d)) next
      if (identical(v, cvar_plot)) next
      if (v %in% already_ordered_vars && is.factor(d[[v]])) next
      obs <- unique(as.character(d[[v]]))
      obs <- obs[!is.na(obs)]
      d[[v]] <- factor(as.character(d[[v]]), levels = obs)
    }

    # Facetは専用順序を使う。ただし同じ列が先にX/Group/Color/Linetype/Shape
    # として順序付け済みなら、最後にFacetがその順序を壊さない。
    if (has_selection(input$facetvar) && input$facetvar %in% names(d)) {
      facet_prior_role <- input$facetvar %in% unique(c(already_ordered_vars, extra_aes_vars))
      if (!(facet_prior_role && is.factor(d[[input$facetvar]]))) {
        observed_facet <- unique(as.character(d[[input$facetvar]]))
        observed_facet <- observed_facet[!is.na(observed_facet)]

        fl <- get_saved_order("facet", input$facetvar, observed_facet)
        if (length(fl) == 0L) {
          fl <- observed_facet
        } else {
          fl <- c(fl[fl %in% observed_facet], setdiff(observed_facet, fl))
        }

        d[[input$facetvar]] <- factor(
          as.character(d[[input$facetvar]]),
          levels = fl
        )
      }
    }

    d
  }

compute_summary_grouping_vars <- function() {
    d <- plot_data()
    grouping <- resolved_xvar()

    pos_var <- effective_position_var(d)
    if (nzchar(pos_var)) grouping <- c(grouping, pos_var)

    cvar_sum <- resolve_color_var(d)
    if (nzchar(cvar_sum)) grouping <- c(grouping, cvar_sum)

    if (identical(input$plot_type, "line")) {
      lvar_sum <- resolve_linetype_var(d)
      svar_sum <- resolve_shape_var(d)
      if (nzchar(lvar_sum)) grouping <- c(grouping, lvar_sum)
      if (nzchar(svar_sum)) grouping <- c(grouping, svar_sum)
    }

    if (has_selection(input$facetvar)) grouping <- c(grouping, input$facetvar)
    unique(grouping[nzchar(grouping) & grouping %in% names(d)])
  }

compute_id_mean_data <- function() {
    d <- plot_data()
    if (!identical(input$summary_unit %||% "row", "id_mean")) return(d)

    idv <- input$idvar %||% ""
    shiny::validate(
      shiny::need(
        has_selection(idv) && idv %in% names(d),
        "「個体IDごとに先に平均」を使うには、Mappingで「個体ID」を指定してください。"
      )
    )

    grouping <- summary_grouping_vars()

    # Bar/BoxのShapeはsummaryを分割しないが、個体点の表示属性として保持する。
    # 同じID×条件セル内でShape水準が複数ある場合は一意に決められないためNAにする。
    shape_var <- resolve_shape_var(d)
    shape_extra <- nzchar(shape_var) && !shape_var %in% grouping && shape_var %in% names(d)

    first_group <- unique(c(idv, grouping))
    out <- d %>%
      group_by(across(all_of(first_group))) %>%
      summarise(
        .id_mean_y__ = mean(.data[[resolved_yvar()]], na.rm = TRUE),
        .groups = "drop"
      )

    if (shape_extra) {
      shape_lookup <- d %>%
        group_by(across(all_of(first_group))) %>%
        summarise(
          .shape_value__ = {
            z <- as.character(.data[[shape_var]])
            z <- unique(z[!is.na(z)])
            if (length(z) == 1L) z[[1]] else NA_character_
          },
          .groups = "drop"
        )
      names(shape_lookup)[names(shape_lookup) == ".shape_value__"] <- shape_var
      out <- left_join(out, shape_lookup, by = first_group)
      original_levels <- levels(d[[shape_var]])
      if (!is.null(original_levels) && length(original_levels)) {
        out[[shape_var]] <- factor(out[[shape_var]], levels = original_levels)
      }
    }

    out
  }

compute_display_observation_data <- function() {
    if (!identical(input$summary_unit %||% "row", "id_mean")) return(plot_data())
    d <- id_mean_data()
    d[[resolved_yvar()]] <- d$.id_mean_y__
    d$.id_mean_y__ <- NULL
    d
  }

compute_summary_data <- function() {
    d <- id_mean_data()
    grouping <- summary_grouping_vars()
    y_source <- if (identical(input$summary_unit %||% "row", "id_mean")) {
      ".id_mean_y__"
    } else {
      resolved_yvar()
    }

    d %>%
      group_by(across(all_of(grouping))) %>%
      summarise(
        n = sum(!is.na(.data[[y_source]])),
        mean = mean(.data[[y_source]], na.rm = TRUE),
        sd = stats::sd(.data[[y_source]], na.rm = TRUE),
        sem = sd / sqrt(n),
        ci95 = ifelse(n > 1, stats::qt(0.975, df = n - 1) * sem, NA_real_),
        .groups = "drop"
      )
  }

compute_direct_value_mode <- function() {
    identical(input$summary_type %||% "mean", "value") &&
      (input$plot_type %||% "line") %in% c("line", "bar")
  }

compute_theme_object <- function() {
    fam <- selected_font_family()

    legend_key_width <- suppressWarnings(as.numeric(input$legend_key_width))
    if (!is.finite(legend_key_width) || legend_key_width < 0) {
      legend_key_width <- 1.8
    }

    th <- switch(
      input$theme,
      classic = theme_classic(base_size = input$base_size, base_family = fam),
      bw = theme_bw(base_size = input$base_size, base_family = fam),
      minimal = theme_minimal(base_size = input$base_size, base_family = fam),
      gray = theme_gray(base_size = input$base_size, base_family = fam)
    )
    th + theme(
      legend.position = input$legend_pos,
      legend.key.width = grid::unit(legend_key_width, "cm"),
      panel.spacing.x = grid::unit(
        suppressWarnings(as.numeric(input$facet_spacing_x %||% 0.12)), "cm"
      ),
      text = element_text(family = fam),
      plot.title = element_text(family = fam),
      axis.title = element_text(family = fam),
      axis.text = element_text(family = fam),
      legend.title = element_text(family = fam),
      legend.text = element_text(family = fam),
      strip.text = element_text(family = fam)
    )
  }

external_error_bounds <- function(z, ycol) {
    mode <- input$external_error_mode %||% "none"
    if (!isTRUE(direct_value_mode()) || identical(mode, "none")) return(NULL)

    shiny::validate(
      shiny::need(ycol %in% names(z), "Y列が見つかりません。")
    )
    yv <- z[[ycol]]

    if (identical(mode, "symmetric")) {
      ecol <- input$external_error_col %||% ""
      shiny::validate(
        shiny::need(nzchar(ecol) && ecol %in% names(z), "Error barに使用する誤差列を指定してください。"),
        shiny::need(is.numeric(z[[ecol]]), "Error barの誤差列には数値列を指定してください。")
      )
      ev <- z[[ecol]]
      shiny::validate(
        shiny::need(!any(is.finite(ev) & ev < 0, na.rm = TRUE), "±誤差列には0以上の値を指定してください。")
      )
      return(list(
        ymin = yv - ev,
        ymax = yv + ev,
        mode = mode,
        error = ecol
      ))
    }

    if (identical(mode, "bounds")) {
      low_col <- input$external_ymin_col %||% ""
      high_col <- input$external_ymax_col %||% ""
      shiny::validate(
        shiny::need(nzchar(low_col) && low_col %in% names(z), "Error barの下限列を指定してください。"),
        shiny::need(nzchar(high_col) && high_col %in% names(z), "Error barの上限列を指定してください。"),
        shiny::need(is.numeric(z[[low_col]]), "Error barの下限列には数値列を指定してください。"),
        shiny::need(is.numeric(z[[high_col]]), "Error barの上限列には数値列を指定してください。")
      )
      lo <- z[[low_col]]
      hi <- z[[high_col]]
      shiny::validate(
        shiny::need(
          !any(is.finite(lo) & is.finite(hi) & lo > hi, na.rm = TRUE),
          "Error barの下限列に上限列より大きい値があります。"
        )
      )
      return(list(
        ymin = lo,
        ymax = hi,
        mode = mode,
        lower = low_col,
        upper = high_col
      ))
    }

    NULL
  }

add_stable_spread <- function(d, x_col, group_col = NULL, facet_col = NULL,
                                id_col = NULL, width = 0.18) {
    d$.row_order__ <- seq_len(nrow(d))
    grouping <- c(x_col)
    if (!is.null(group_col) && nzchar(group_col)) grouping <- c(grouping, group_col)
    if (!is.null(facet_col) && nzchar(facet_col)) grouping <- c(grouping, facet_col)
    grouping <- unique(grouping)

    if (!is.null(id_col) && nzchar(id_col)) {
      d <- d %>%
        group_by(across(all_of(grouping))) %>%
        arrange(.data[[id_col]], .by_group = TRUE) %>%
        mutate(
          .spread_n__ = n(),
          .spread_rank__ = row_number(),
          .spread__ = ifelse(
            .spread_n__ <= 1, 0,
            ((.spread_rank__ - 1) / (.spread_n__ - 1) - 0.5) * 2 * width
          )
        ) %>%
        ungroup()
    } else {
      d <- d %>%
        group_by(across(all_of(grouping))) %>%
        mutate(
          .spread_n__ = n(),
          .spread_rank__ = row_number(),
          .spread__ = ifelse(
            .spread_n__ <= 1, 0,
            ((.spread_rank__ - 1) / (.spread_n__ - 1) - 0.5) * 2 * width
          )
        ) %>%
        ungroup()
    }

    d %>% arrange(.row_order__)
  }
