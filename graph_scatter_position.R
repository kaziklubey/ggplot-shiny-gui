# ============================================================
# Scatter point position contract
# ============================================================
# Scatter jitter belongs to point positioning only. Connection lines and
# regression layers keep the canonical unjittered data coordinates.

graph_scatter_jitter_spec <- function(enabled = FALSE, x_width = 0, y_width = 0) {
  norm_width <- function(x) {
    z <- suppressWarnings(as.numeric(x))
    if (!length(z) || !is.finite(z[[1]])) return(0)
    max(0, as.numeric(z[[1]]))
  }
  list(
    enabled = isTRUE(enabled),
    x_width = norm_width(x_width),
    y_width = norm_width(y_width)
  )
}

graph_scatter_jitter_active <- function(spec) {
  is.list(spec) && isTRUE(spec$enabled) &&
    (isTRUE(spec$x_width > 0) || isTRUE(spec$y_width > 0))
}

graph_scatter_point_position <- function(enabled = FALSE, x_width = 0, y_width = 0, seed = 3810L) {
  spec <- graph_scatter_jitter_spec(enabled, x_width, y_width)
  if (!graph_scatter_jitter_active(spec)) return(NULL)
  ggplot2::position_jitter(
    width = spec$x_width,
    height = spec$y_width,
    seed = as.integer(seed)[1]
  )
}
