# ============================================================
# Graph state helpers (UI/engine independent)
# first step toward GraphState / GraphUI / GraphEngine separation.
# ============================================================

graph_state_scalar <- function(x, default = NULL) {
  if (is.null(x)) return(default)
  z <- unlist(x, use.names = FALSE)
  if (!length(z)) return(default)
  z[[1]]
}

graph_ui_seed_from_state <- function(cfg) {
  out <- list()
  if (!is.list(cfg)) return(out)
  cfg <- graph_normalize_legend_state(cfg)

  put <- function(key, value) {
    value <- graph_state_scalar(value, NULL)
    if (!is.null(value)) out[[key]] <<- value
  }

  put("text", graph_data_document_source_text(cfg))

  if (is.list(cfg$reshape)) {
    put("reshape_wide", cfg$reshape$enabled)
    put("reshape_row_id", cfg$reshape$row_id)
    put("reshape_x_name", cfg$reshape$x_name)
    put("reshape_y_name", cfg$reshape$y_name)
  }

  if (is.list(cfg$mapping)) {
    for (nm in c("x", "y", "color", "linetype", "shape", "id", "facet")) {
      key <- switch(
        nm,
        x = "xvar", y = "yvar", color = "colorvar", linetype = "linetypevar",
        shape = "shapevar", id = "idvar", facet = "facetvar"
      )
      put(key, cfg$mapping[[nm]])
    }
    # groupvar is dynamic and is still finalized by the server after data choices
    # exist, but storing the seed here documents the authoritative saved value.
    put("groupvar", cfg$mapping$position)
    put("line_series_mode", cfg$mapping$line_series_mode %||% "auto")
    put("line_series_var", cfg$mapping$line_series_var %||% "")
    put("external_error_col", cfg$mapping$external_error)
    put("external_ymin_col", cfg$mapping$external_ymin)
    put("external_ymax_col", cfg$mapping$external_ymax)
  }

  if (is.list(cfg$plot)) {
    put("plot_type", cfg$plot$type)
    put("bar_layout", cfg$plot$bar_layout %||% "side_by_side")
    put("bar_value_source", cfg$plot$bar_value_source %||% "numeric_y")
    put("bar_proportion_display", cfg$plot$bar_proportion_display %||% "percent")
    put("summary_type", cfg$plot$summary)
    put("summary_unit", cfg$plot$summary_unit)
    put("external_error_mode", cfg$plot$external_error_mode)
    put("show_raw", cfg$plot$show_raw)
    put("connect_id", cfg$plot$connect_id)
    put("scatter_connect_mode", cfg$plot$scatter_connect_mode)
    put("individual_connect_direction", cfg$plot$individual_connect_direction %||% "auto")
    out$line_breaks <- as.character(unlist(cfg$plot$line_breaks %||% character(0), use.names = FALSE))
  }

  if (is.list(cfg$labels)) {
    for (nm in c("xlab", "ylab", "title", "ymin", "ymax", "y_top_to_tick")) {
      put(nm, cfg$labels[[nm]])
    }
  }

  appearance <- if (is.list(cfg$style)) cfg$style$appearance else NULL
  if (is.list(appearance)) {
    # Plot summary semantics have a single canonical owner under cfg$plot.
    # Legacy style trees may still contain mirrors of these keys; never let
    # those stale mirrors overwrite the Plot-owned replay/browser seed.
    appearance_keys <- setdiff(names(appearance), c("summary_type", "summary_unit"))
    for (nm in appearance_keys) put(nm, appearance[[nm]])
  }
  # Persistent UI seeding uses the same canonical font representation as
  # restore/render comparison. Legacy/missing values therefore start as sans.
  out$font_family_mode <- app_normalize_font_family_mode(out$font_family_mode %||% "sans")
  out$font_family_custom <- app_normalize_font_family_custom(out$font_family_custom %||% "")

  if (!is.null(out$plot_width_px)) out$plot_width_px_direct <- out$plot_width_px
  if (!is.null(out$plot_height_px)) out$plot_height_px_direct <- out$plot_height_px
  out
}


# ui_snapshot stores only manual UI presentation state.
# Canonical plot/mapping/style values live in GraphState proper; data-dependent
# choices, conditional visibility and enabled state are derived by the already-
# running UI reactives and are deliberately not duplicated here.
graph_ui_snapshot_normalize <- function(x) {
  if (!is.list(x)) x <- list()

  normalize_panel_tree <- function(z) {
    if (!is.list(z)) return(list())
    out <- list()
    for (nm in names(z)) out[[nm]] <- isTRUE(z[[nm]])
    # Browser/jsonlite containers can carry representation-only class or row
    # attributes. Panel state is a named boolean record; retain names only so
    # those transport attributes cannot create canonical revisions.
    out_names <- names(out)
    attributes(out) <- if (is.null(out_names)) NULL else list(names = out_names)
    out
  }
  selections <- if (is.list(x$selections)) x$selections else list()
  # Keep only Graph-owned view selections. The visible Graph workspace section
  # (Plot / Statistics / Data View) is workspace-global state
  # owned by the one persistent Editor DOM, not by each GraphState.
  # Older projects may still contain selections$graph_main_tab; normalization
  # intentionally drops it at the restore/state boundary.
  keep <- intersect(names(selections), "sticky_plot")
  selections <- selections[keep]

  list(
    schema_version = 2L,
    selections = selections,
    panels = normalize_panel_tree(x$panels)
  )
}

graph_ui_snapshot_merge <- function(base = NULL, patch = NULL) {
  out <- graph_ui_snapshot_normalize(base)
  if (!is.list(patch)) return(out)
  incoming <- graph_ui_snapshot_normalize(patch)
  if (is.list(patch$selections)) out$selections <- modifyList(out$selections, incoming$selections)
  if (is.list(patch$panels)) out$panels <- modifyList(out$panels, incoming$panels)
  out$schema_version <- 2L
  out
}

graph_state_with_ui_snapshot <- function(state, snapshot = NULL) {
  if (!is.list(state)) return(state)
  state$ui_snapshot <- graph_ui_snapshot_merge(state$ui_snapshot, snapshot)
  state
}

  graph_browser_input_paths <- function(state = NULL) {
    paths <- c(
      editor_panels = "ui_snapshot.panels",
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
      plot_type = "plot.type", bar_layout = "plot.bar_layout",
      bar_value_source = "plot.bar_value_source", bar_proportion_display = "plot.bar_proportion_display", summary_type = "plot.summary",
      summary_unit = "plot.summary_unit", external_error_mode = "plot.external_error_mode",
      show_raw = "plot.show_raw", connect_id = "plot.connect_id",
      scatter_connect_mode = "plot.scatter_connect_mode",
      individual_connect_direction = "plot.individual_connect_direction",
      line_breaks = "plot.line_breaks",
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
