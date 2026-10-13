# Pure display derivation, shared by explicit replay and live pool observers.
# Never writes defaults to GraphState or to the Editor's working Style trees.
graph_slot_pool_names <- function() {
  c("color_style", "linetype_style", "shape_style", "series_style", "raw_group_color")
}

# Canonical dependencies, not cached state. Data changes are evaluated by the
# display generator; unrelated mapping/plot/order fields do not dirty pools.
graph_slot_pool_state_dependencies <- function(pool, cfg) {
  mp <- cfg$mapping %||% list()
  st <- cfg$style %||% list()
  type <- graph_state_scalar(cfg$plot$type, "line")
  cv <- graph_state_scalar(mp$color, "")
  if (identical(cv, "__fixed__")) cv <- ""
  gv <- if (graph_plot_supports_position(type)) graph_state_scalar(mp$position, "") else ""
  lv <- if (graph_plot_supports_mapping(type, "linetype")) graph_state_scalar(mp$linetype, "__color__") else ""
  if (identical(lv, "__color__")) lv <- cv
  sv <- graph_state_scalar(mp$shape, "__color__")
  if (identical(sv, "__color__")) sv <- cv
  ordering <- function(v) {
    kind <- if (identical(v, graph_state_scalar(mp$x, "")) && !identical(type, "scatter")) {
      "x"
    } else if (nzchar(gv) && identical(v, gv)) "group" else "display"
    list(kind = kind, values = (st$orders[[kind]] %||% list())[[v]])
  }
  if (pool %in% c("color_style", "linetype_style", "shape_style")) {
    kind <- switch(pool, color_style = "color", linetype_style = "linetype", shape_style = "shape")
    v <- switch(kind, color = cv, linetype = lv, shape = sv)
    return(list(variable = v, order = ordering(v),
      values = (st[[paste0(kind, "_styles")]] %||% list())[[v]],
      fill = if (identical(kind, "color")) (st$fill_none_styles %||% list())[[v]],
      show_fill = if (identical(kind, "color")) graph_plot_uses_fill(type)))
  }
  combo <- isTRUE(st$appearance$series_style_override) && nzchar(cv) && nzchar(gv) && !identical(cv, gv)
  raw_key <- if (combo) paste0("__combo__::", cv, "::", gv) else cv
  if (identical(pool, "series_style") && !combo) return(list(enabled = FALSE))
  list(color = cv, position = if (combo) gv else "", combo = combo,
    color_order = ordering(cv), group_order = if (combo) ordering(gv),
    base = (st$color_styles %||% list())[[cv]],
    series = if (combo) st$series_styles,
    raw = if (identical(pool, "raw_group_color")) (st$raw_group_colors %||% list())[[raw_key]],
    labels = if (identical(pool, "raw_group_color")) list(
      color = (st$level_labels %||% list())[[cv]],
      group = if (combo) (st$level_labels %||% list())[[gv]]))
}

graph_slot_pool_spec <- function(pool, cfg, d) {
  mp <- cfg$mapping %||% list()
  st <- cfg$style %||% list()
  ap <- st$appearance %||% list()
  plot_type <- graph_state_scalar(cfg$plot$type, "line")
  variable <- function(value) {
    v <- as.character(graph_state_scalar(value, ""))
    if (nzchar(v) && v %in% names(d)) v else ""
  }
  cv <- variable(mp$color)
  gv <- if (graph_plot_supports_position(plot_type)) variable(mp$position) else ""
  lv <- graph_state_scalar(mp$linetype, "__color__")
  lv <- if (graph_plot_supports_mapping(plot_type, "linetype")) {
    if (identical(lv, "__color__")) cv else variable(lv)
  } else ""
  sv <- graph_state_scalar(mp$shape, "__color__")
  sv <- if (identical(sv, "__color__")) cv else variable(sv)
  ordered <- function(v) {
    if (!nzchar(v)) return(character(0))
    obs <- unique(as.character(d[[v]]))
    obs <- obs[!is.na(obs)]
    kind <- if (identical(v, graph_state_scalar(mp$x, "")) && !identical(plot_type, "scatter")) {
      "x"
    } else if (identical(v, gv)) "group" else "display"
    graph_complete_order((st$orders[[kind]] %||% list())[[v]] %||% character(0), obs)
  }
  defaults <- function(kind, v, levels_now) {
    values <- switch(kind,
      color = graph_default_palette(length(levels_now), "okabe_ito"),
      linetype = rep(graph_default_linetypes(), length.out = length(levels_now)),
      shape = rep(graph_default_shapes(), length.out = length(levels_now)))
    branch <- (st[[paste0(kind, "_styles")]] %||% list())[[v]] %||% list()
    setNames(lapply(seq_along(levels_now), function(i) branch[[levels_now[[i]]]] %||% unname(values[[i]])), levels_now)
  }
  spec <- function(kind, entries, context_key, empty_text, options = list()) {
    list(kind = kind, entries = entries, context_key = context_key,
      empty_text = empty_text, options = options)
  }
  context <- function(v, levels_now) paste(c(v, levels_now), collapse = "\u001f")
  if (pool %in% c("color_style", "linetype_style", "shape_style")) {
    kind <- switch(pool, color_style = "color", linetype_style = "linetype", shape_style = "shape")
    v <- switch(kind, color = cv, linetype = lv, shape = sv)
    lev <- ordered(v)
    values <- defaults(kind, v, lev)
    fill <- (st$fill_none_styles %||% list())[[v]] %||% list()
    entries <- lapply(lev, function(key) {
      entry <- list(key = key, label = key, value = as.character(values[[key]])[1])
      if (identical(kind, "color")) entry$fillNone <- isTRUE(fill[[key]])
      entry
    })
    bar_box <- graph_plot_uses_fill(plot_type)
    return(spec(if (identical(kind, "color")) "color_fill" else kind,
      entries, if (identical(kind, "color")) context(v, c(lev, paste0("barbox=", bar_box))) else context(v, lev),
      switch(kind, color = "Colorに使う列がありません。", linetype = "Linetypeは固定です。", shape = "Shapeは固定です。"),
      if (identical(kind, "color")) list(showFillNone = bar_box) else list()))
  }
  combo <- isTRUE(ap$series_style_override) && nzchar(cv) && nzchar(gv) && !identical(cv, gv)
  color_levels <- ordered(cv)
  base <- defaults("color", cv, color_levels)
  keys <- if (combo) {
    observed <- unique(graph_series_combo_key(as.character(d[[cv]]), as.character(d[[gv]])))
    observed <- observed[!is.na(observed)]
    preferred <- as.vector(outer(color_levels, ordered(gv), graph_series_combo_key))
    c(preferred[preferred %in% observed], setdiff(observed, preferred))
  } else character(0)
  series_color <- function(key) {
    saved <- (st$series_styles[[key]] %||% list())$color
    color_level <- strsplit(key, " × ", fixed = TRUE)[[1]][1]
    as.character(saved %||% base[[color_level]] %||% "#333333")[1]
  }
  if (identical(pool, "series_style")) {
    return(spec("color", lapply(keys, function(key) list(key = key, label = key, value = series_color(key))),
      paste(keys, collapse = "\u001f"),
      "Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。"))
  }
  raw_key <- if (combo) paste0("__combo__::", cv, "::", gv) else cv
  raw_levels <- if (combo) keys else color_levels
  label <- function(v, key) {
    saved <- (st$level_labels[[v]] %||% list())[[key]]
    if (is.null(saved) || !length(saved) || !nzchar(trimws(as.character(saved)[1]))) key else as.character(saved)[1]
  }
  branch <- (st$raw_group_colors %||% list())[[raw_key]] %||% list()
  entries <- lapply(raw_levels, function(key) {
    display <- if (combo) {
      parts <- strsplit(key, " × ", fixed = TRUE)[[1]]
      paste0(label(cv, parts[1]), " × ", label(gv, paste(parts[-1], collapse = " × ")))
    } else label(cv, key)
    saved <- branch[[key]]
    value <- if (!is.null(saved) && length(saved) && nzchar(as.character(saved)[1])) {
      as.character(saved)[1]
    } else graph_lighten_colour(if (combo) series_color(key) else base[[key]] %||% "#333333", 0.45)
    list(key = key, label = display, value = value)
  })
  spec("color", entries, context(raw_key, raw_levels), "Colorに使う系列がありません。")
}
