# v3.69.0: extracted from graph_module.R; sourced into graphServer local environment.
# Section: HELPERS-BEGIN


  # ============================================================
  # Helpers
  # ============================================================
  has_selection <- graph_has_selection

  # Plot size inputs may briefly be NULL / numeric(0) while browser values are
  # replayed. Always normalize to one finite numeric before use.
  safe_num1 <- graph_safe_num1


  complete_order <- graph_complete_order

  lighten_colour <- graph_lighten_colour

  normalise_colour <- graph_normalise_colour

  default_palette <- graph_default_palette

  default_linetypes <- graph_default_linetypes()
  default_shapes <- graph_default_shapes()

  # Dynamic style controls live inside one persistent Editor DOM.  The same
  # variable/level names (for example Group/CTL) can occur in several Graphs,
  # so a globally stable input id would let the browser retain Graph A's
  # colourInput value and report it while Graph B is being rebuilt.
  #
  # Keep the semantic part stable, but namespace the browser input id by the
  # current dynamic-style UI generation.  style_restore_epoch is incremented
  # exactly when those renderUI controls are intentionally rebuilt, therefore
  # stale inputs from the previous Graph become unreachable without retaining
  # per-Graph DOM/modules.
  style_input_id <- function(prefix, variable_name, level_name = NULL) {
    base_id <- graph_style_input_id(prefix, variable_name, level_name)
    epoch <- as.integer(style_restore_epoch() %||% 0L)
    paste0(base_id, "_ui", epoch)
  }

  # Color / Linetype / Shape は変数名ごとに完全分離して保持する。
  # list(variable = list(level = value, ...), ...)
  color_styles <- reactiveVal(list())
  linetype_styles <- reactiveVal(list())
  shape_styles <- reactiveVal(list())

  # Color × 横位置要因の組み合わせ別「色」上書き
  # key: "CTL × Pre" など
  series_styles <- reactiveVal(list())

  # 散布図の回帰線スタイル（回帰グループ名をキーに保存）
  regression_styles <- reactiveVal(list())

  # 個体点の水準別カスタム色
  raw_group_colors <- reactiveVal(list())

  # 変数名ごとのカテゴリ順序を保持
  order_state <- reactiveVal(graph_normalize_order_state())

  # グラフ表示専用の名称。元データの列名・水準値は変更しない。
  # legend_titles: legend key -> displayed title
  # level_labels: data variable -> original level -> displayed level
  legend_titles <- reactiveVal(list())
  # Graph-specific legend entry text. Unlike level_labels(), these overrides
  # affect legend keys only and do not rename X-axis categories or facet strips.
  # legend key -> original level -> displayed legend text
  legend_item_labels <- reactiveVal(list())
  level_labels <- reactiveVal(list())

  # v3.73.0: project-level Shared Label / Style Library bindings are Graph
  # metadata, while the concrete display/style values above remain the render
  # authority. Binding is explicit; no name-based auto matching is performed.
  shared_style_binding <- reactiveVal(shared_style_default_binding())

  legend_title_value <- function(key, default_title) {
    st <- legend_titles()
    z <- st[[key]]
    # Empty text is an intentional "no title" value.  Earlier builds treated
    # an empty string as missing and silently restored the default variable
    # name, so users could not actually remove a legend title.
    if (is.null(z) || !length(z)) {
      default_title
    } else {
      as.character(z)[1]
    }
  }

  level_label_values <- function(var_name, levels_now) {
    levels_now <- as.character(levels_now)
    if (!length(levels_now) || !nzchar(var_name)) return(levels_now)

    st <- level_labels()
    branch <- st[[var_name]]
    if (is.null(branch)) branch <- list()

    vapply(
      levels_now,
      function(lv) {
        z <- branch[[lv]]
        if (is.null(z) || !length(z) || !nzchar(trimws(as.character(z)[1]))) lv else as.character(z)[1]
      },
      character(1)
    )
  }

  legend_item_label_values <- function(legend_key, levels_now, default_labels = NULL) {
    levels_now <- as.character(levels_now)
    if (!length(levels_now) || !nzchar(as.character(legend_key %||% "")[1])) return(levels_now)
    if (is.null(default_labels) || length(default_labels) != length(levels_now)) default_labels <- levels_now
    default_labels <- as.character(default_labels)

    st <- legend_item_labels()
    branch <- st[[as.character(legend_key)[1]]]
    if (is.null(branch)) branch <- list()

    vapply(seq_along(levels_now), function(i) {
      z <- branch[[levels_now[i]]]
      if (is.null(z) || !length(z) || !nzchar(trimws(as.character(z)[1]))) default_labels[i] else as.character(z)[1]
    }, character(1))
  }

  get_saved_order <- function(kind, var_name, observed) {
    st <- graph_normalize_order_state(order_state())
    branch <- st[[kind]]
    saved <- if (is.null(branch)) NULL else branch[[var_name]]
    if (is.null(saved)) saved <- character(0)
    complete_order(saved, observed)
  }

  set_saved_order <- function(kind, var_name, values) {
    st <- graph_normalize_order_state(isolate(order_state()))
    if (is.null(st[[kind]])) st[[kind]] <- list()
    st[[kind]][[var_name]] <- values
    order_state(st)
  }

  ordered_levels_for_var <- function(d, var_name) {
    var_name <- as.character(var_name %||% "")[1]
    if (!nzchar(var_name) || is.null(d) || !var_name %in% names(d)) return(character(0))
    observed <- unique(as.character(d[[var_name]]))
    observed <- observed[!is.na(observed)]
    if (!length(observed)) return(character(0))

    x_now <- as.character(input$xvar %||% "")[1]
    if (nzchar(x_now) && identical(var_name, x_now) && !identical(input$plot_type %||% "line", "scatter")) {
      return(get_saved_order("x", var_name, observed))
    }

    g_now <- effective_position_var(d)
    if (nzchar(g_now) && identical(var_name, g_now)) {
      return(get_saved_order("group", var_name, observed))
    }

    get_saved_order("display", var_name, observed)
  }

  ensure_style_branch <- function(kind, variable_name, levels_now) {
    variable_name <- as.character(variable_name %||% "")
    levels_now <- as.character(levels_now)
    if (!nzchar(variable_name) || !length(levels_now)) return(invisible(FALSE))

    rv <- switch(kind,
      color = color_styles,
      linetype = linetype_styles,
      shape = shape_styles
    )
    tree <- isolate(rv())
    branch <- tree[[variable_name]]
    if (is.null(branch)) branch <- list()
    changed <- FALSE

    if (identical(kind, "color")) {
      defaults <- default_palette(length(levels_now), "okabe_ito")
    } else if (identical(kind, "linetype")) {
      defaults <- rep(default_linetypes, length.out = length(levels_now))
    } else {
      defaults <- rep(default_shapes, length.out = length(levels_now))
    }

    for (i in seq_along(levels_now)) {
      lv <- levels_now[i]
      if (is.null(branch[[lv]])) {
        branch[[lv]] <- unname(defaults[i])
        changed <- TRUE
      }
    }
    if (changed) {
      tree[[variable_name]] <- branch
      rv(tree)
    }
    invisible(changed)
  }

  aesthetic_style_vector <- function(kind, variable_name, levels_now) {
    ensure_style_branch(kind, variable_name, levels_now)
    rv <- switch(kind,
      color = color_styles,
      linetype = linetype_styles,
      shape = shape_styles
    )
    branch <- rv()[[variable_name]]
    if (is.null(branch)) branch <- list()
    vals <- vapply(levels_now, function(lv) {
      z <- branch[[lv]]
      if (identical(kind, "color")) as.character(z %||% "#333333")
      else if (identical(kind, "linetype")) as.character(z %||% "solid")
      else as.numeric(z %||% 16)
    }, if (identical(kind, "shape")) numeric(1) else character(1))
    setNames(vals, levels_now)
  }

  color_style_vector <- function(variable_name, levels_now) {
    aesthetic_style_vector("color", variable_name, levels_now)
  }
  linetype_style_vector <- function(variable_name, levels_now) {
    aesthetic_style_vector("linetype", variable_name, levels_now)
  }
  shape_style_vector <- function(variable_name, levels_now) {
    aesthetic_style_vector("shape", variable_name, levels_now)
  }

  migrate_legacy_group_styles <- function(legacy, color_var = "", line_var = "", shape_var = "") {
    if (is.null(legacy) || !length(legacy)) return(invisible(FALSE))
    scalar_chr <- function(x, default) {
      z <- unlist(x, use.names = FALSE)
      if (!length(z)) default else as.character(z[[1]])
    }
    scalar_num <- function(x, default) {
      z <- suppressWarnings(as.numeric(scalar_chr(x, as.character(default))))
      if (!is.finite(z)) default else z
    }

    if (nzchar(color_var)) {
      tree <- isolate(color_styles()); br <- tree[[color_var]] %||% list()
      for (lv in names(legacy)) br[[lv]] <- scalar_chr(legacy[[lv]]$color, "#333333")
      tree[[color_var]] <- br; color_styles(tree)
    }
    if (nzchar(line_var)) {
      tree <- isolate(linetype_styles()); br <- tree[[line_var]] %||% list()
      for (lv in names(legacy)) br[[lv]] <- scalar_chr(legacy[[lv]]$linetype, "solid")
      tree[[line_var]] <- br; linetype_styles(tree)
    }
    if (nzchar(shape_var)) {
      tree <- isolate(shape_styles()); br <- tree[[shape_var]] %||% list()
      for (lv in names(legacy)) br[[lv]] <- scalar_num(legacy[[lv]]$shape, 16)
      tree[[shape_var]] <- br; shape_styles(tree)
    }
    invisible(TRUE)
  }

  series_combo_key <- graph_series_combo_key

  series_combo_levels <- reactive({
    if (!isTRUE(input$series_style_override)) return(character(0))
    d <- dat()
    g0 <- effective_position_var(d)
    cvar0 <- resolve_color_var(d)
    if (!nzchar(cvar0) || !nzchar(g0) || identical(cvar0, g0)) return(character(0))
    observed <- graph_series_combo_key(as.character(d[[cvar0]]), as.character(d[[g0]]))
    observed <- unique(observed[!is.na(observed)])
    if (!length(observed)) return(character(0))
    sl0 <- ordered_levels_for_var(d, cvar0)
    gl0 <- ordered_levels_for_var(d, g0)
    preferred <- as.vector(outer(sl0, gl0, series_combo_key))
    c(preferred[preferred %in% observed], setdiff(observed, preferred))
  })

  ensure_series_styles <- function(keys_now) {
    if (!length(keys_now)) return()
    d <- dat(); cv <- resolve_color_var(d)
    base_levels <- if (nzchar(cv)) unique(as.character(d[[cv]])) else character(0)
    base_levels <- base_levels[!is.na(base_levels)]
    if (nzchar(cv) && length(base_levels)) ensure_style_branch("color", cv, base_levels)
    base <- if (nzchar(cv)) isolate(color_styles())[[cv]] else list()
    ss <- isolate(series_styles()); changed <- FALSE
    for (key in keys_now) {
      if (is.null(ss[[key]])) {
        parts <- strsplit(key, " × ", fixed = TRUE)[[1]]; style_nm <- parts[1]
        ss[[key]] <- list(color = as.character(base[[style_nm]] %||% "#333333"))
        changed <- TRUE
      }
    }
    if (changed) series_styles(ss)
  }

  series_style_vectors <- function(keys_now) {
    ensure_series_styles(keys_now); ss <- series_styles()
    list(color = setNames(vapply(keys_now, function(k) as.character(ss[[k]]$color %||% "#333333"), character(1)), keys_now))
  }

