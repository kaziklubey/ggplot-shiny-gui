# Snapshot-side canonical accessor contract. The live Graph/Figure editor defines
# the same helpers against accepted GraphState/browser working state. This
# synchronous context already exposes canonical values as a plain `input` list,
# so shared calculation code can use one API in both environments.
graph_mapping_value <- function(key, fallback = "") {
    input_key <- switch(
      as.character(key %||% "")[1],
      x = "xvar", y = "yvar", position = "groupvar", color = "colorvar",
      linetype = "linetypevar", shape = "shapevar", id = "idvar",
      facet = "facetvar", line_series_mode = "line_series_mode",
      line_series_var = "line_series_var", external_error = "external_error_col",
      external_ymin = "external_ymin_col", external_ymax = "external_ymax_col",
      ""
    )
    if (!nzchar(input_key)) return(fallback)
    value <- input[[input_key]]
    if (is.null(value) || !length(value)) fallback else value[[1]]
  }

graph_plot_value <- function(key, fallback = "") {
    input_key <- switch(
      as.character(key %||% "")[1],
      type = "plot_type", summary = "summary_type", summary_unit = "summary_unit",
      external_error_mode = "external_error_mode", show_raw = "show_raw",
      connect_id = "connect_id", scatter_connect_mode = "scatter_connect_mode",
      line_breaks = "line_breaks", ""
    )
    if (!nzchar(input_key)) return(fallback)
    value <- input[[input_key]]
    if (is.null(value) || !length(value)) return(fallback)
    if (identical(input_key, "line_breaks")) return(value)
    value[[1]]
  }

graph_label_value <- function(key, fallback = "") {
    input_key <- switch(
      as.character(key %||% "")[1],
      xlab = "xlab", ylab = "ylab", title = "title", ymin = "ymin", ymax = "ymax",
      y_top_to_tick = "y_top_to_tick", ""
    )
    if (!nzchar(input_key)) return(fallback)
    value <- input[[input_key]]
    if (is.null(value) || !length(value)) fallback else value[[1]]
  }

graph_appearance_value <- function(key, fallback = "") {
    input_key <- as.character(key %||% "")[1]
    if (!nzchar(input_key)) return(fallback)
    value <- input[[input_key]]
    if (is.null(value) || !length(value)) fallback else value[[1]]
  }

# Private, synchronous state calculation helpers.
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
    tree <- rv()
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

ensure_series_styles <- function(keys_now) {
    if (!length(keys_now)) return()
    d <- dat(); cv <- resolve_color_var(d)
    base_levels <- if (nzchar(cv)) unique(as.character(d[[cv]])) else character(0)
    base_levels <- base_levels[!is.na(base_levels)]
    if (nzchar(cv) && length(base_levels)) ensure_style_branch("color", cv, base_levels)
    base <- if (nzchar(cv)) color_styles()[[cv]] else list()
    ss <- series_styles(); changed <- FALSE
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

series_combo_levels <- function() {
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
  }

effective_position_var <- function(d = NULL) {
    plot_now <- input$plot_type %||% "line"
    if (!plot_now %in% c("line", "bar", "box")) return("")
    v <- input$groupvar %||% ""
    if (!has_selection(v)) return("")
    if (!is.null(d) && !v %in% names(d)) return("")
    v
  }

resolve_color_var <- function(d) {
    mode <- input$colorvar %||% ""
    if (identical(mode, "__fixed__") || !nzchar(mode)) return("")
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

resolve_linetype_var <- function(d) {
    # LinetypeはLine、またはScatterの接続線で使用する。
    if (!(input$plot_type %||% "line") %in% c("line", "scatter")) return("")
    mode <- input$linetypevar %||% "__color__"
    if (identical(mode, "__color__")) {
      return(resolve_color_var(d))
    }
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

resolve_shape_var <- function(d) {
    mode <- input$shapevar %||% "__color__"
    if (identical(mode, "__color__")) {
      return(resolve_color_var(d))
    }
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

style_levels <- function() {
    d <- dat()
    v <- resolve_color_var(d)
    if (!nzchar(v)) return(character(0))
    ordered_levels_for_var(d, v)
  }

ensure_regression_styles <- function(levels_now) {
    if (!length(levels_now)) return()

    rs <- regression_styles()
    changed <- FALSE

    # 現在のColor/Linetype styleを初期値に利用
    d0 <- dat(); cv0 <- resolve_color_var(d0); lv0 <- resolve_linetype_var(d0)
    cbranch <- if (nzchar(cv0)) color_styles()[[cv0]] else list()
    lbranch <- if (nzchar(lv0)) linetype_styles()[[lv0]] else list()
    fallback_cols <- default_palette(length(levels_now), "okabe_ito")

    for (i in seq_along(levels_now)) {
      nm <- levels_now[i]
      if (is.null(rs[[nm]])) {
        col0 <- cbranch[[nm]]
        lt0 <- lbranch[[nm]]

        if (is.null(col0) || !length(col0) || is.na(col0[[1]]) || !nzchar(as.character(col0[[1]]))) {
          col0 <- fallback_cols[i]
        } else {
          col0 <- as.character(col0[[1]])
        }

        if (is.null(lt0) || !length(lt0) || is.na(lt0[[1]]) || !nzchar(as.character(lt0[[1]]))) {
          lt0 <- "solid"
        } else {
          lt0 <- as.character(lt0[[1]])
        }

        rs[[nm]] <- list(
          color = col0,
          linetype = lt0,
          width = 0.9
        )
        changed <- TRUE
      }
    }

    if (changed) regression_styles(rs)
  }

ensure_raw_group_colors <- function(variable_name, levels_now) {
    if (!nzchar(variable_name) || !length(levels_now)) return()
    ensure_style_branch("color", variable_name, levels_now)
    base <- color_styles()[[variable_name]] %||% list()
    tree <- raw_group_colors(); br <- tree[[variable_name]] %||% list(); changed <- FALSE
    for (lv in levels_now) if (is.null(br[[lv]])) { br[[lv]] <- lighten_colour(base[[lv]] %||% "#333333", amount = 0.45); changed <- TRUE }
    if (changed) { tree[[variable_name]] <- br; raw_group_colors(tree) }
  }

y_break_values <- function(ymin, ymax) {
    manual_y_break_values(ymin, ymax, input$y_breaks_step, input$y_breaks_auto)
  }
