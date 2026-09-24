# Pure value helpers shared by live Graph and direct-state Figure rendering.
manual_y_break_values <- function(ymin, ymax, step, automatic = FALSE) {
  if (isTRUE(automatic)) return(ggplot2::waiver())
  scalar_finite <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x)
  step <- suppressWarnings(tryCatch(as.numeric(step), error = function(e) NA_real_))
  if (!scalar_finite(step) || step <= 0 || !scalar_finite(ymin) ||
      !scalar_finite(ymax) || ymax <= ymin) return(ggplot2::waiver())
  first <- ceiling(ymin / step)
  last <- floor(ymax / step)
  if (!is.finite(first) || !is.finite(last)) return(ggplot2::waiver())
  if (first > last) return(numeric(0))
  count <- last - first + 1
  # Check before allocating, including division/count overflow.
  if (!is.finite(count) || count > 5000) return(ggplot2::waiver())
  vals <- (first + (seq_len(as.integer(count)) - 1)) * step
  if (any(!is.finite(vals))) return(ggplot2::waiver())
  vals
}

# Source IDs belong to the containing registry key. Packaged records need not
# carry GraphState or a render revision; geometry and frozen SVG are sufficient.
valid_graph_preview_record <- function(rec) {
  positive_scalar <- function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0
  is.list(rec) && is.character(rec$svg) && length(rec$svg) == 1L &&
    !is.na(rec$svg) && nzchar(rec$svg) && grepl("<svg\\b", rec$svg, perl = TRUE) &&
    is.list(rec$meta) && positive_scalar(rec$meta$width) && positive_scalar(rec$meta$height)
}
