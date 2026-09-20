# Legend Policy — Variable × Aesthetic × Layer role
#
# This file is the single source of truth for guide visibility, merge planning,
# layer legend contribution and final guide rendering.  It is deliberately
# independent of Shiny reactives so the same policy is used by live Graphs and
# DIRECT-STATE Figure/Export rendering.

graph_legend_bool <- function(value, default = TRUE) {
  if (is.null(value) || !length(value)) return(isTRUE(default))
  isTRUE(value)
}

# Group title's legacy/shared-library key remains compatible with older projects.
graph_group_legend_key <- function(state) {
  ap <- state$style$appearance %||% list()
  mp <- state$mapping %||% list()
  key <- graph_state_scalar(mp$color, "")
  if (isTRUE(ap$series_style_override) && nzchar(key) &&
      nzchar(graph_state_scalar(mp$position, ""))) {
    key <- paste0("__combo__::", key, "::", graph_state_scalar(mp$position, ""))
  }
  key
}

# Canonical compatibility migration for legend state.  New controls are
# aesthetic-oriented.  Legacy group/individual flags are read only as defaults
# when the new fields are absent, so old .ggplotpack projects keep their view.
graph_normalize_legend_state <- function(state) {
  if (!is.list(state)) return(state)
  ap <- state$style$appearance %||% list()
  key <- graph_group_legend_key(state)

  if (is.null(ap$legend_group_title)) {
    ap$legend_group_title <- graph_state_scalar(
      state$style$legend_titles[[key]],
      graph_state_scalar(state$mapping$color, "")
    )
  }
  if (is.null(ap$legend_individual_title)) ap$legend_individual_title <- ""
  if (is.null(ap$legend_title_show)) ap$legend_title_show <- FALSE
  if (is.null(ap$legend_individual_title_show)) ap$legend_individual_title_show <- FALSE

  legacy_group <- graph_legend_bool(ap$legend_group_show, TRUE)
  legacy_shape <- graph_legend_bool(ap$legend_individual_show, TRUE)
  legacy_merge <- graph_legend_bool(ap$legend_merge_group_individual, TRUE)

  if (is.null(ap$legend_colour_show)) ap$legend_colour_show <- legacy_group
  if (is.null(ap$legend_linetype_show)) ap$legend_linetype_show <- legacy_group
  if (is.null(ap$legend_shape_show)) ap$legend_shape_show <- legacy_shape
  if (is.null(ap$legend_merge_linetype_shape)) ap$legend_merge_linetype_shape <- TRUE

  # Compatibility-only state.  There is intentionally no visible control for
  # this in the new UI; it preserves the old Color+Shape merge/split choice.
  if (is.null(ap$legend_merge_colour_shape)) {
    ap$legend_merge_colour_shape <- legacy_merge
  }

  state$style$appearance <- ap
  state
}

graph_legend_component_ids <- function(active_names, edges) {
  active_names <- unique(active_names)
  if (!length(active_names)) return(setNames(character(0), character(0)))

  parent <- setNames(active_names, active_names)
  root <- function(x) {
    while (!identical(parent[[x]], x)) x <- parent[[x]]
    x
  }
  unite <- function(a, b) {
    if (!a %in% active_names || !b %in% active_names) return()
    ra <- root(a); rb <- root(b)
    if (!identical(ra, rb)) parent[[rb]] <<- ra
  }

  for (edge in edges) {
    if (length(edge) >= 2L) unite(edge[[1]], edge[[2]])
  }

  out <- vapply(active_names, root, character(1))
  names(out) <- active_names
  out
}

# Pure policy calculation.  `mapping` contains the effective variables after
# __color__/fixed resolution; `appearance` contains scalar saved/UI values.
graph_build_legend_policy <- function(mapping, appearance, plot_type,
                                      layer_context = list()) {
  mapping <- mapping %||% list()
  appearance <- appearance %||% list()
  plot_type <- as.character(plot_type %||% "line")[1]

  colour_var <- as.character(mapping$colour %||% "")[1]
  fill_var <- as.character(mapping$fill %||% "")[1]
  linetype_var <- as.character(mapping$linetype %||% "")[1]
  shape_var <- as.character(mapping$shape %||% "")[1]

  colour_active <- nzchar(colour_var)
  fill_active <- nzchar(fill_var)
  linetype_active <- nzchar(linetype_var) && graph_legend_bool(layer_context$uses_linetype, TRUE)
  shape_active <- nzchar(shape_var) && graph_legend_bool(layer_context$uses_shape, TRUE)

  colour_show <- graph_legend_bool(appearance$legend_colour_show,
                                   graph_legend_bool(appearance$legend_group_show, TRUE))
  linetype_show <- graph_legend_bool(appearance$legend_linetype_show,
                                     graph_legend_bool(appearance$legend_group_show, TRUE))
  shape_show <- graph_legend_bool(appearance$legend_shape_show,
                                  graph_legend_bool(appearance$legend_individual_show, TRUE))

  items <- list(
    colour = list(active = colour_active, variable = colour_var,
                  show = colour_active && colour_show),
    fill = list(active = fill_active, variable = fill_var,
                show = fill_active && colour_show),
    linetype = list(active = linetype_active, variable = linetype_var,
                    show = linetype_active && linetype_show),
    shape = list(active = shape_active, variable = shape_var,
                 show = shape_active && shape_show)
  )

  same <- function(a, b) {
    isTRUE(items[[a]]$show) && isTRUE(items[[b]]$show) &&
      nzchar(items[[a]]$variable) && identical(items[[a]]$variable, items[[b]]$variable)
  }

  merge_linetype_shape <- same("linetype", "shape") &&
    graph_legend_bool(appearance$legend_merge_linetype_shape, TRUE)
  merge_colour_shape <- same("colour", "shape") &&
    graph_legend_bool(appearance$legend_merge_colour_shape,
                      graph_legend_bool(appearance$legend_merge_group_individual, TRUE))
  merge_fill_shape <- same("fill", "shape") &&
    graph_legend_bool(appearance$legend_merge_colour_shape,
                      graph_legend_bool(appearance$legend_merge_group_individual, TRUE))

  # Color/Fill and Linetype are group-level aesthetics in the legacy UI.  When
  # they encode the same variable they remain one guide, preserving prior plots.
  edges <- list()
  if (same("colour", "fill")) edges <- append(edges, list(c("colour", "fill")))
  if (same("colour", "linetype")) edges <- append(edges, list(c("colour", "linetype")))
  if (same("fill", "linetype")) edges <- append(edges, list(c("fill", "linetype")))
  if (merge_colour_shape) edges <- append(edges, list(c("colour", "shape")))
  if (merge_fill_shape) edges <- append(edges, list(c("fill", "shape")))
  if (merge_linetype_shape) edges <- append(edges, list(c("linetype", "shape")))

  shown <- names(items)[vapply(items, function(x) isTRUE(x$show), logical(1))]
  components <- graph_legend_component_ids(shown, edges)

  # Stable ordering is part of the policy.  In current ggplot2, distinct order
  # values also keep same-title/same-break guides separate when merge is OFF.
  preferred <- c("fill", "colour", "linetype", "shape")
  component_order <- list()
  next_order <- 1L
  orders <- setNames(rep(NA_integer_, length(items)), names(items))
  for (aes in preferred) {
    if (!aes %in% names(components)) next
    comp <- components[[aes]]
    if (is.null(component_order[[comp]])) {
      component_order[[comp]] <- next_order
      next_order <- next_order + 1L
    }
    orders[[aes]] <- component_order[[comp]]
  }

  list(
    plot_type = plot_type,
    items = items,
    components = components,
    orders = orders,
    merge = list(
      linetype_shape = merge_linetype_shape,
      colour_shape = merge_colour_shape,
      fill_shape = merge_fill_shape
    )
  )
}

graph_legend_merge_plan <- function(policy) {
  policy$components %||% setNames(character(0), character(0))
}

# Named show.legend vectors keep each layer responsible only for the guides it
# semantically explains.  This prevents a point mapped to Color+Shape from
# injecting its point glyph into an unrelated Color guide.
graph_legend_layer_flags <- function(policy, layer_role) {
  item <- policy$items %||% list()
  shown <- function(aes) isTRUE(item[[aes]]$active) && isTRUE(item[[aes]]$show)
  active <- function(aes) isTRUE(item[[aes]]$active)

  out <- switch(
    as.character(layer_role)[1],
    summary_line = c(
      colour = shown("colour"),
      linetype = shown("linetype")
    ),
    line_point = c(
      colour = FALSE,
      shape = shown("shape")
    ),
    scatter_point = c(
      colour = shown("colour"),
      shape = shown("shape")
    ),
    raw_point = c(shape = shown("shape")),
    id_line = c(linetype = shown("linetype")),
    scatter_segment = c(colour = FALSE, linetype = shown("linetype")),
    bar_main = c(fill = shown("fill"), colour = FALSE),
    box_main = c(fill = shown("fill"), colour = FALSE),
    errorbar = c(colour = FALSE),
    regression = FALSE,
    FALSE
  )

  if (is.logical(out) && length(out) > 1L && !is.null(names(out))) {
    keep <- names(out)[vapply(names(out), active, logical(1))]
    out <- out[keep]
    if (!length(out)) return(FALSE)
  }
  out
}

graph_legend_title_text <- function(value) {
  if (is.null(value) || !length(value)) return(NULL)
  z <- as.character(value)[1]
  if (!nzchar(trimws(z))) NULL else z
}

graph_legend_component_title <- function(policy, aesthetic, titles) {
  components <- policy$components %||% character(0)
  if (!aesthetic %in% names(components)) return(NULL)
  comp <- components[[aesthetic]]
  members <- names(components)[components == comp]

  # Visible title precedence follows semantic ownership: Color/Fill title for
  # a component containing those aesthetics, otherwise Line/Shape title.
  if (any(members %in% c("colour", "fill"))) {
    return(graph_legend_title_text(titles$colour))
  }
  if (any(members %in% c("linetype", "shape"))) {
    return(graph_legend_title_text(titles$individual))
  }
  NULL
}

graph_legend_guide_override <- function(policy, aesthetic) {
  items <- policy$items %||% list()
  comp <- policy$components %||% character(0)
  same_component <- function(a, b) {
    a %in% names(comp) && b %in% names(comp) && identical(comp[[a]], comp[[b]])
  }

  if (identical(aesthetic, "colour")) {
    out <- list()

    # For line plots the Colour guide explains the group colour only.  Keep it
    # as a line-only key unless Colour+Shape intentionally belong to the same
    # merged variable/guide.  This also suppresses the fixed summary-point
    # glyph that ggplot2 may otherwise draw in the Colour key.
    if (identical(policy$plot_type, "line") &&
        !same_component("colour", "shape")) out$shape <- NA

    if (identical(policy$plot_type, "scatter") && isTRUE(items$shape$active) &&
        !same_component("colour", "shape")) out$shape <- 16
    if (identical(policy$plot_type, "line") && isTRUE(items$linetype$active) &&
        !same_component("colour", "linetype")) out$linetype <- "solid"
    if (length(out)) return(out)
    return(NULL)
  }
  if (identical(aesthetic, "fill")) return(NULL)
  if (identical(aesthetic, "linetype")) {
    out <- list()
    if (isTRUE(items$colour$active) && !same_component("linetype", "colour")) out$colour <- "#333333"
    if (isTRUE(items$shape$active) && !same_component("linetype", "shape")) out$shape <- NA
    if (length(out)) return(out)
    return(NULL)
  }
  if (identical(aesthetic, "shape")) {
    out <- list()
    if (isTRUE(items$colour$active) && !same_component("shape", "colour")) out$colour <- "#333333"
    if (isTRUE(items$fill$active) && !same_component("shape", "fill")) out$fill <- "#333333"
    if (isTRUE(items$linetype$active) && !same_component("shape", "linetype")) out$linetype <- 0
    if (length(out)) return(out)
    return(NULL)
  }
  NULL
}

# Apply title + guide visibility/order/key overrides to an already-built plot.
# Plot data/layers are intentionally outside this function.
graph_apply_legend_guides <- function(plot, policy, titles = list()) {
  items <- policy$items %||% list()
  guide_args <- list()
  lab_args <- list()

  for (aes in c("fill", "colour", "linetype", "shape")) {
    it <- items[[aes]]
    if (is.null(it) || !isTRUE(it$active)) next

    if (!isTRUE(it$show)) {
      guide_args[[aes]] <- "none"
      next
    }

    title <- graph_legend_component_title(policy, aes, titles)
    # Single-bracket assignment retains an explicit NULL in labs().
    lab_args[aes] <- list(title)

    override <- graph_legend_guide_override(policy, aes)
    gargs <- list(order = as.integer(policy$orders[[aes]] %||% 1L))
    if (!is.null(override) && length(override)) gargs$override.aes <- override
    guide_args[[aes]] <- do.call(ggplot2::guide_legend, gargs)
  }

  if (length(lab_args)) plot <- plot + do.call(ggplot2::labs, lab_args)
  if (length(guide_args)) plot <- plot + do.call(ggplot2::guides, guide_args)
  plot
}
