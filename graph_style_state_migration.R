# ============================================================
# Dynamic Style GraphState migration — pure helpers
# v3.73.2.20: canonicalize deterministic per-level Style defaults before
# replaying a saved GraphState into the one persistent Editor.
# ============================================================

graph_style_migration_scalar_chr <- function(x, default = "") {
  z <- unlist(x, recursive = TRUE, use.names = FALSE)
  if (!length(z) || is.na(z[[1]])) return(default)
  as.character(z[[1]])
}

# v3.81.0 style schema 5. Keep style migration pure so Project load can
# canonicalize every dormant Graph before any Editor replay. This prevents the
# first visible replay from producing a false live edit solely because current
# controls materialize newer style metadata/defaults.
graph_style_migrate_v5 <- function(style) {
  st <- style %||% list()
  if (!is.list(st)) st <- list()

  ap <- st$appearance %||% list()
  if (!is.list(ap)) ap <- list()

  base_size <- suppressWarnings(as.numeric(graph_state_scalar(ap$base_size, 13)))
  if (!length(base_size) || !is.finite(base_size[[1]])) base_size <- 13
  ap$base_size <- as.numeric(base_size[[1]])

  wrap_mode <- graph_style_migration_scalar_chr(ap$legend_wrap_mode, "auto")
  if (!wrap_mode %in% c("auto", "ncol", "nrow")) wrap_mode <- "auto"
  ap$legend_wrap_mode <- wrap_mode

  wrap_count <- suppressWarnings(as.integer(graph_state_scalar(ap$legend_wrap_count, 2L)))
  if (!length(wrap_count) || !is.finite(wrap_count[[1]])) wrap_count <- 2L
  ap$legend_wrap_count <- max(1L, min(12L, as.integer(wrap_count[[1]])))

  item_spacing <- suppressWarnings(as.numeric(graph_state_scalar(ap$legend_item_spacing, -1)))
  if (!length(item_spacing) || !is.finite(item_spacing[[1]])) item_spacing <- -1
  ap$legend_item_spacing <- max(-1, min(2, as.numeric(item_spacing[[1]])))

  text_size <- suppressWarnings(as.numeric(graph_state_scalar(ap$legend_text_size, 0)))
  if (!length(text_size) || !is.finite(text_size[[1]])) text_size <- 0
  ap$legend_text_size <- max(0, min(48, as.numeric(text_size[[1]])))

  jitter_enabled <- isTRUE(graph_state_scalar(ap$scatter_jitter_enabled, FALSE))
  jitter_x <- suppressWarnings(as.numeric(graph_state_scalar(ap$scatter_jitter_x, 0.10)))
  jitter_y <- suppressWarnings(as.numeric(graph_state_scalar(ap$scatter_jitter_y, 0)))
  if (!length(jitter_x) || !is.finite(jitter_x[[1]])) jitter_x <- 0.10
  if (!length(jitter_y) || !is.finite(jitter_y[[1]])) jitter_y <- 0
  ap$scatter_jitter_enabled <- jitter_enabled
  ap$scatter_jitter_x <- max(0, as.numeric(jitter_x[[1]]))
  ap$scatter_jitter_y <- max(0, as.numeric(jitter_y[[1]]))

  st$orders <- graph_normalize_order_state(st$orders %||% list())
  st$appearance <- ap
  st$version <- "3.81.0"
  st$schema_version <- 5L
  st
}

graph_style_migration_prepared_data <- function(state) {
  if (!is.list(state)) return(NULL)
  raw <- tryCatch(
    graph_parse_pasted_data(as.character(state$data_text %||% "")[1]),
    error = function(e) NULL
  )
  if (!is.data.frame(raw) || !ncol(raw)) return(NULL)

  r <- state$reshape %||% list()
  recipe <- graph_plot_data_transform_recipe(
    enabled = isTRUE(r$enabled),
    row_id = isTRUE(r$row_id),
    columns = as.character(r$columns %||% character(0)),
    x_name = graph_style_migration_scalar_chr(r$x_name, "Time"),
    y_name = graph_style_migration_scalar_chr(r$y_name, "Value")
  )
  transformed <- tryCatch(
    graph_apply_data_transform(raw, recipe, incomplete_is_warning = FALSE),
    error = function(e) NULL
  )
  if (is.list(transformed) && is.data.frame(transformed$data)) transformed$data else raw
}

graph_style_migration_observed_levels <- function(data, variable) {
  variable <- graph_style_migration_scalar_chr(variable, "")
  if (!is.data.frame(data) || !nzchar(variable) || !variable %in% names(data)) return(character(0))
  z <- unique(as.character(data[[variable]]))
  as.character(z[!is.na(z)])
}

graph_style_migration_factor_levels <- function(data, variable) {
  variable <- graph_style_migration_scalar_chr(variable, "")
  if (!is.data.frame(data) || !nzchar(variable) || !variable %in% names(data)) return(character(0))
  z <- data[[variable]]
  lev <- levels(z)
  if (is.null(lev) || !length(lev)) lev <- unique(as.character(z))
  as.character(lev[!is.na(lev)])
}

graph_style_migration_normalize_branch <- function(tree, variable, levels_now, kind) {
  if (!is.list(tree)) tree <- list()
  variable <- graph_style_migration_scalar_chr(variable, "")
  levels_now <- as.character(levels_now)
  if (!nzchar(variable) || !length(levels_now)) return(tree)

  branch <- tree[[variable]]
  if (is.atomic(branch) && length(branch)) branch <- as.list(branch)
  if (!is.list(branch)) branch <- list()

  defaults <- switch(
    kind,
    color = graph_default_palette(length(levels_now), "okabe_ito"),
    shape = rep(graph_default_shapes(), length.out = length(levels_now)),
    linetype = rep(graph_default_linetypes(), length.out = length(levels_now)),
    rep(NA, length(levels_now))
  )
  for (i in seq_along(levels_now)) {
    lv <- levels_now[[i]]
    z <- branch[[lv]]
    if (is.null(z) || !length(z)) {
      branch[[lv]] <- unname(defaults[[i]])
    } else if (identical(kind, "color")) {
      branch[[lv]] <- graph_normalise_colour(
        graph_style_migration_scalar_chr(z, unname(defaults[[i]])),
        unname(defaults[[i]])
      )
    } else if (identical(kind, "shape")) {
      q <- suppressWarnings(as.numeric(graph_style_migration_scalar_chr(z, as.character(defaults[[i]]))))
      branch[[lv]] <- if (length(q) && is.finite(q[[1]])) q[[1]] else unname(defaults[[i]])
    } else {
      branch[[lv]] <- graph_style_migration_scalar_chr(z, unname(defaults[[i]]))
    }
  }
  tree[[variable]] <- branch
  tree
}

graph_style_migration_mapping_vars <- function(state, prepared_data) {
  mp <- state$mapping %||% list()
  pl <- state$plot %||% list()

  color_var <- graph_style_migration_scalar_chr(mp$color, "")
  if (identical(color_var, "__fixed__") || !color_var %in% names(prepared_data)) color_var <- ""

  shape_mode <- graph_style_migration_scalar_chr(mp$shape, "__color__")
  shape_var <- if (identical(shape_mode, "__color__")) color_var else shape_mode
  if (!shape_var %in% names(prepared_data)) shape_var <- ""

  line_mode <- graph_style_migration_scalar_chr(mp$linetype, "__color__")
  line_var <- if (identical(line_mode, "__color__")) color_var else line_mode
  plot_type <- graph_style_migration_scalar_chr(pl$type, "line")
  if (!plot_type %in% c("line", "scatter") || !line_var %in% names(prepared_data)) line_var <- ""

  list(color = color_var, shape = shape_var, linetype = line_var)
}

graph_style_migration_normalize_raw_colors <- function(raw_tree, color_tree, color_var, color_levels) {
  if (!is.list(raw_tree)) raw_tree <- list()
  if (!nzchar(color_var) || !length(color_levels)) return(raw_tree)

  raw_branch <- raw_tree[[color_var]]
  flat_legacy <- is.null(raw_branch) && length(raw_tree) &&
    all(vapply(raw_tree, function(z) !is.list(z) || is.null(names(z)), logical(1)))
  if (isTRUE(flat_legacy)) {
    raw_branch <- raw_tree
    raw_tree <- list()
  }
  if (is.atomic(raw_branch) && length(raw_branch)) raw_branch <- as.list(raw_branch)
  if (!is.list(raw_branch)) raw_branch <- list()

  base <- color_tree[[color_var]] %||% list()
  for (lv in color_levels) {
    fallback <- graph_lighten_colour(base[[lv]] %||% "#333333", amount = 0.45)
    z <- raw_branch[[lv]]
    raw_branch[[lv]] <- if (is.null(z) || !length(z)) {
      fallback
    } else {
      graph_normalise_colour(graph_style_migration_scalar_chr(z, fallback), fallback)
    }
  }
  raw_tree[[color_var]] <- raw_branch
  raw_tree
}

graph_state_materialize_dynamic_style_defaults <- function(state, prepared_data = NULL) {
  if (!is.list(state)) return(state)
  old_schema <- suppressWarnings(as.integer(graph_state_scalar(state$schema_version, 0L)))
  if (!is.finite(old_schema)) old_schema <- 0L
  if (old_schema >= 4L) return(state)

  if (!is.data.frame(prepared_data) || !ncol(prepared_data)) {
    prepared_data <- graph_style_migration_prepared_data(state)
  }
  if (!is.data.frame(prepared_data) || !ncol(prepared_data)) {
    state$schema_version <- max(4L, old_schema)
    return(state)
  }

  st <- state$style %||% list()
  if (!is.list(st)) st <- list()
  ap <- st$appearance %||% list()
  if (!is.list(ap)) ap <- list()
  vars <- graph_style_migration_mapping_vars(state, prepared_data)

  color_levels <- graph_style_migration_observed_levels(prepared_data, vars$color)
  shape_levels <- graph_style_migration_factor_levels(prepared_data, vars$shape)
  line_levels <- graph_style_migration_factor_levels(prepared_data, vars$linetype)

  st$color_styles <- graph_style_migration_normalize_branch(st$color_styles, vars$color, color_levels, "color")
  st$shape_styles <- graph_style_migration_normalize_branch(st$shape_styles, vars$shape, shape_levels, "shape")
  st$linetype_styles <- graph_style_migration_normalize_branch(st$linetype_styles, vars$linetype, line_levels, "linetype")
  st$raw_group_colors <- graph_style_migration_normalize_raw_colors(
    st$raw_group_colors, st$color_styles, vars$color, color_levels
  )

  if (!is.null(ap$mean_color_mode)) {
    ap$mean_color_mode <- graph_normalise_colour(
      graph_style_migration_scalar_chr(ap$mean_color_mode, "#000000"),
      "#000000"
    )
  }
  st$appearance <- ap
  state$style <- st
  state$schema_version <- max(4L, old_schema)
  state
}
