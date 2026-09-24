# ============================================================
# Bar / Box appearance contract — pure helpers
# v3.81.1: existing border ownership + no-fill semantics.
# ============================================================

# A fill colour remains an ordinary colour. "No fill" is stored separately as
# semantic state so Color/Fill mapping continues to own one palette and the
# colour value remains available for matching borders/other aesthetics.
graph_bar_box_normalize_fill_none_tree <- function(x) {
  if (!is.list(x)) return(list())
  out <- list()
  for (vn in names(x) %||% character(0)) {
    src <- x[[vn]]
    if (is.atomic(src) && length(src)) src <- as.list(src)
    if (!is.list(src)) next
    branch <- list()
    for (lv in names(src) %||% character(0)) {
      z <- unlist(src[[lv]], recursive = TRUE, use.names = FALSE)
      branch[[lv]] <- length(z) > 0L && isTRUE(as.logical(z[[1]]))
    }
    if (length(branch)) out[[vn]] <- branch
  }
  out
}

graph_bar_box_fill_none_levels <- function(tree, variable_name) {
  variable_name <- as.character(variable_name %||% "")[1]
  if (!nzchar(variable_name)) return(character(0))
  tree <- graph_bar_box_normalize_fill_none_tree(tree)
  branch <- tree[[variable_name]] %||% list()
  names(branch)[vapply(branch, isTRUE, logical(1))]
}

graph_bar_box_set_fill_none <- function(tree, variable_name, level_name, enabled) {
  tree <- graph_bar_box_normalize_fill_none_tree(tree)
  variable_name <- as.character(variable_name %||% "")[1]
  level_name <- as.character(level_name %||% "")[1]
  if (!nzchar(variable_name) || !nzchar(level_name)) return(tree)
  branch <- tree[[variable_name]] %||% list()
  branch[[level_name]] <- isTRUE(enabled)
  tree[[variable_name]] <- branch
  tree
}

graph_bar_box_apply_no_fill <- function(values, no_fill_keys) {
  if (!length(values) || is.null(names(values))) return(values)
  keys <- intersect(names(values), unique(as.character(no_fill_keys %||% character(0))))
  if (length(keys)) values[keys] <- NA_character_
  values
}

graph_bar_box_fixed_fill <- function(colour, no_fill = FALSE) {
  if (isTRUE(no_fill)) NA_character_ else as.character(colour %||% "#000000")[1]
}

graph_bar_box_combo_no_fill_keys <- function(no_fill_levels, group_levels, key_fun) {
  no_fill_levels <- unique(as.character(no_fill_levels %||% character(0)))
  group_levels <- unique(as.character(group_levels %||% character(0)))
  if (!length(no_fill_levels) || !length(group_levels) || !is.function(key_fun)) return(character(0))
  as.vector(outer(no_fill_levels, group_levels, Vectorize(key_fun)))
}

graph_bar_box_border_linetype_choices <- function() {
  c(
    "実線" = "solid",
    "破線" = "dashed",
    "点線" = "dotted",
    "一点鎖線" = "dotdash",
    "長い破線" = "longdash",
    "二重点線" = "twodash",
    "Dash / Gap を指定" = "custom"
  )
}

graph_bar_box_clamp_dash_unit <- function(x, default) {
  z <- suppressWarnings(as.integer(round(as.numeric(x)[1])))
  if (!length(z) || !is.finite(z)) z <- as.integer(default)
  max(1L, min(15L, z))
}

graph_bar_box_custom_linetype <- function(dash = 4, gap = 2) {
  dash <- graph_bar_box_clamp_dash_unit(dash, 4L)
  gap <- graph_bar_box_clamp_dash_unit(gap, 2L)
  paste0(toupper(as.character(as.hexmode(dash))), toupper(as.character(as.hexmode(gap))))
}

graph_bar_box_border_linetype <- function(mode = "solid", dash = 4, gap = 2) {
  mode <- as.character(mode %||% "solid")[1]
  allowed <- c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash", "custom")
  if (!mode %in% allowed) mode <- "solid"
  if (identical(mode, "custom")) graph_bar_box_custom_linetype(dash, gap) else mode
}
