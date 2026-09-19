# Synchronous GraphState -> Figure payload. These definitions never create a
# Shiny module, reactive, observer, input binding or browser transaction.
# Calculation expressions are loaded once, and shared with the live builder.
graph_plot_calculation <- parse("graph_plot_calculation.R", encoding = "UTF-8")
graph_plot_data_definitions <- parse("graph_plot_data_calculation.R", encoding = "UTF-8")
graph_state_plot_definitions <- parse("graph_state_plot_helpers.R", encoding = "UTF-8")

graph_build_plot <- function(context) {
  scope <- new.env(parent = context)
  eval(graph_plot_calculation, envir = scope)
  scope$p
}

# Missing fields use the same defaults as the Graph controls. Explicit saved
# values, including empty strings and FALSE, always take precedence.
graph_snapshot_input_defaults <- function() {
  list(
    plot_type = "line", summary_type = "sem", summary_unit = "row",
    show_raw = TRUE, connect_id = FALSE, scatter_connect_mode = "none",
    xvar = "", yvar = "", groupvar = "", colorvar = "",
    linetypevar = "__color__", shapevar = "__color__", idvar = "", facetvar = "",
    external_error_mode = "none", external_error_col = "",
    external_ymin_col = "", external_ymax_col = "",
    xlab = "", ylab = "", title = "", ymin = "", ymax = "",
    theme = "classic", base_size = 13, font_family_mode = "sans", font_family_custom = "",
    mean_color_mode = "#000000", mean_linetype = "solid", mean_shape = 16,
    point_size = 2.8, line_width = 0.9, line_group_dodge = 0.10, line_x_spacing = 1,
    bar_width = 0.82, bar_zero_touch = TRUE, group_spacing = 1,
    box_width_scale = 0.72, x_category_spacing = 1, bar_border_mode = "fixed",
    bar_border_color = "#000000", bar_border_width = 0.5,
    raw_color_mode = "group_light", raw_fixed_custom = "#555555", raw_lighten = 0.45,
    raw_alpha = 0.95, raw_shape_mode = "group", raw_shape = 16,
    raw_point_size = 2.2, jitter_width = 0.18,
    id_line_color_mode = "group_light", id_line_custom_color = "#4D4D4D",
    id_line_lighten = 0.60, id_linetype = "solid", id_line_width = 0.45,
    id_line_alpha = 0.55, summary_on_top = TRUE,
    error_color_mode = "fixed", error_color = "#000000", error_width = 0.15,
    error_line_width = 0.6, series_style_override = FALSE,
    scatter_regression = FALSE, scatter_regression_group = "overall",
    scatter_regression_color = "#333333", scatter_regression_linetype = "solid",
    scatter_regression_width = 0.9, scatter_regression_se = TRUE,
    scatter_regression_se_alpha = 0.20,
    y_breaks_auto = TRUE, y_breaks_step = 1, y_top_to_tick = TRUE,
    y_break_enabled = FALSE, y_break_from = 2, y_break_to = 10,
    y_break_space = 0.08, y_break_symbol = TRUE,
    legend_pos = "right", legend_key_width = 1.8, facet_spacing_x = 0.12
  )
}

graph_snapshot_inputs <- function(state) {
  values <- utils::modifyList(graph_snapshot_input_defaults(), graph_ui_seed_from_state(state))
  # plot is authoritative; older appearance trees can duplicate summary fields.
  for (name in c("summary", "summary_unit")) {
    value <- graph_state_scalar(state$plot[[name]])
    key <- if (identical(name, "summary")) "summary_type" else name
    if (!is.null(value)) values[[key]] <- value
  }
  if (!values$plot_type %in% c("line", "bar", "scatter", "box")) {
    stop("Unsupported saved plot type: ", values$plot_type)
  }
  values
}

graph_snapshot_data <- function(state) {
  raw <- graph_parse_pasted_data(graph_state_scalar(state$data_text, ""))
  if (!is.data.frame(raw) || ncol(raw) < 2L) stop("2列以上のデータが必要です。")
  reshape <- state$reshape %||% list()
  recipe <- graph_plot_data_transform_recipe(
    enabled = isTRUE(graph_state_scalar(reshape$enabled, FALSE)),
    row_id = isTRUE(graph_state_scalar(reshape$row_id, TRUE)),
    columns = unlist(reshape$columns %||% character(0), use.names = FALSE),
    x_name = graph_state_scalar(reshape$x_name, "Time"),
    y_name = graph_state_scalar(reshape$y_name, "Value")
  )
  # Preserve normal Graph transform behavior, including its raw-data fallback.
  graph_apply_data_transform(raw, recipe)$data
}

# These are ordinary private value closures, not reactive state. Style default
# materialization may update this copy only; no Graph/Figure registry is held.
graph_snapshot_store <- function(value) {
  force(value)
  function(replacement) {
    if (!missing(replacement)) value <<- replacement
    value
  }
}

graph_snapshot_memo <- function(calculate) {
  force(calculate)
  ready <- FALSE
  value <- NULL
  function() {
    if (!ready) {
      value <<- calculate()
      ready <<- TRUE
    }
    value
  }
}

graph_snapshot_context <- function(state) {
  scope <- new.env(parent = environment(graph_snapshot_context))
  scope$input <- graph_snapshot_inputs(state)
  scope$dat <- graph_snapshot_store(graph_snapshot_data(state))
  scope$has_selection <- graph_has_selection
  scope$complete_order <- graph_complete_order
  scope$lighten_colour <- graph_lighten_colour
  scope$default_palette <- graph_default_palette
  scope$default_linetypes <- graph_default_linetypes()
  scope$default_shapes <- graph_default_shapes()
  scope$series_combo_key <- graph_series_combo_key
  style <- state$style %||% list()
  for (name in c("color_styles", "linetype_styles", "shape_styles", "series_styles",
                 "regression_styles", "raw_group_colors", "legend_titles", "level_labels")) {
    scope[[name]] <- graph_snapshot_store(style[[name]] %||% list())
  }
  scope$order_state <- graph_snapshot_store(style$orders %||% list())
  eval(graph_state_plot_definitions, envir = scope)
  eval(graph_plot_data_definitions, envir = scope)
  eval(quote({
    resolved_xvar <- function() input$xvar
    resolved_yvar <- function() input$yvar
    selected_font_family <- function() app_effective_font_family(
      input$font_family_mode, input$font_family_custom)
  }), envir = scope)
  for (name in c("plot_data", "summary_grouping_vars", "id_mean_data",
                 "display_observation_data", "summary_data", "direct_value_mode", "theme_object")) {
    scope[[name]] <- graph_snapshot_memo(scope[[paste0("compute_", name)]])
  }
  scope
}

graph_state_figure_snapshot <- function(state) {
  if (!is.list(state)) stop("GraphState is required")
  state <- unserialize(serialize(state, NULL))
  scope <- graph_snapshot_context(state)
  plot <- graph_build_plot(scope)
  size <- graph_saved_plot_size_from_state(state)
  meta <- list(panel_width_px = size$width, panel_height_px = size$height, reference_res = 120)
  # Components are owned by this payload. Figure placement/legend overrides
  # remain downstream and can be changed without consulting the source Graph.
  body <- figure_plot_for_scale(plot + ggplot2::theme(legend.position = "none"),
                                figure_default_override(""), meta, 1)
  legend <- figure_legend_grob_asset(plot, reference_res = 120)
  comp <- list(source_type = "internal_graph", plot = plot, meta = meta,
    body = body, legend = legend, geometry = body[setdiff(names(body), "plot")],
    capabilities = list(vector_preview = TRUE, style_override = TRUE,
                        legend_component = TRUE, external_asset = FALSE))
  list(components = comp, plot = plot, meta = meta, render_revision = NA_integer_)
}
