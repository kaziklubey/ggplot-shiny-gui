# v4.0 RC5 PoC — bridge between browser-owned working values and the existing
# graphServer runtime.  Browser values are never canonical here: the outer
# server owns the canonical GraphState and exposes only accepted overrides.

  graph_browser_patch_path_contract <- function(state = NULL) {
    paths <- c(
      project_name = "project_name", text = "data_text",
      reshape_wide = "reshape.enabled", reshape_row_id = "reshape.row_id",
      reshape_columns = "reshape.columns", reshape_x_name = "reshape.x_name",
      reshape_y_name = "reshape.y_name",
      xvar = "mapping.x", yvar = "mapping.y", colorvar = "mapping.color",
      linetypevar = "mapping.linetype", shapevar = "mapping.shape",
      idvar = "mapping.id", facetvar = "mapping.facet",
      groupvar = "mapping.position", line_series_mode = "mapping.line_series_mode",
      line_series_var = "mapping.line_series_var",
      external_error_col = "mapping.external_error",
      external_ymin_col = "mapping.external_ymin",
      external_ymax_col = "mapping.external_ymax",
      plot_type = "plot.type", summary_type = "plot.summary",
      summary_unit = "plot.summary_unit", external_error_mode = "plot.external_error_mode",
      show_raw = "plot.show_raw", connect_id = "plot.connect_id",
      scatter_connect_mode = "plot.scatter_connect_mode", line_breaks = "plot.line_breaks",
      xlab = "labels.xlab", ylab = "labels.ylab", title = "labels.title",
      ymin = "labels.ymin", ymax = "labels.ymax", y_top_to_tick = "labels.y_top_to_tick"
    )
    app <- if (is.list(state) && is.list(state$style) && is.list(state$style$appearance)) {
      state$style$appearance
    } else list()
    default_style_keys <- setdiff(names(graph_snapshot_input_defaults()), names(paths))
    for (key in unique(c(names(app), default_style_keys))) {
      if (!key %in% names(paths) && !identical(key, "sticky_plot")) {
        paths[[key]] <- paste0("style.appearance.", key)
      }
    }
    if ("plot_width_px" %in% names(app)) paths[["plot_width_px_direct"]] <- "style.appearance.plot_width_px"
    if ("plot_height_px" %in% names(app)) paths[["plot_height_px_direct"]] <- "style.appearance.plot_height_px"
    paths
  }

  if (is.null(browser_patch_override) || !is.function(browser_patch_override)) {
    browser_patch_override <- function() NULL
  }

  graph_browser_patch_override_snapshot <- function() {
    out <- tryCatch(browser_patch_override(), error = function(e) NULL)
    if (!is.list(out) || !isTRUE(out$active) || !is.list(out$values)) return(NULL)
    out
  }

  graph_apply_browser_patch_overlay <- function(state) {
    if (!is.list(state)) return(state)
    ov <- graph_browser_patch_override_snapshot()
    if (is.null(ov)) return(state)

    set_path <- function(node, path, value) {
      parts <- strsplit(as.character(path %||% "")[1], ".", fixed = TRUE)[[1]]
      if (!length(parts) || any(!nzchar(parts))) return(node)
      put <- function(x, rest) {
        if (!is.list(x)) x <- list()
        key <- rest[[1]]
        if (length(rest) == 1L) { x[key] <- list(value); return(x) }
        x[key] <- list(put(x[[key]] %||% list(), rest[-1]))
        x
      }
      put(node, parts)
    }
    paths <- ov$paths %||% list()
    for (nm in intersect(names(ov$values), names(paths))) {
      state <- set_path(state, paths[[nm]], ov$values[[nm]])
    }
    state
  }


  graph_apply_browser_patch_style_overlay <- function(style) {
    if (!is.list(style)) return(style)
    ov <- graph_browser_patch_override_snapshot()
    if (is.null(ov)) return(style)
    if (!is.list(style$appearance)) style$appearance <- list()
    paths <- ov$paths %||% list()
    for (nm in intersect(names(ov$values), names(paths))) {
      path <- as.character(paths[[nm]] %||% "")[1]
      if (!startsWith(path, "style.appearance.")) next
      key <- sub("^style\\.appearance\\.", "", path)
      if (nzchar(key) && !grepl("\\.", key)) style$appearance[[key]] <- ov$values[[nm]]
    }
    style
  }

  graph_browser_patch_direct_render_active <- function() {
    !is.null(graph_browser_patch_override_snapshot())
  }
