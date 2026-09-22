# figure_layout_tracks.R — shared Fixed-Canvas row/column track allocator
# v3.80.8: Fixed layout has one Figure-wide column model and one row model.
# Figure-wide column ratios are canonical layout metadata. Per-cell `width`
# values are a derived compatibility mirror maintained by figure_reindex_layout.

figure_track_num <- function(x, fallback = 1) {
  z <- suppressWarnings(as.numeric(x %||% fallback)[1])
  if (!is.finite(z) || z <= 0) fallback else z
}

figure_shared_column_ratios <- function(layout) {
  if (!length(layout)) return(numeric(0))
  max_col <- max(vapply(layout, function(row) length(row$cells %||% list()), integer(1)), 0L)
  if (max_col < 1L) return(numeric(0))

  out <- rep(NA_real_, max_col)
  saved <- suppressWarnings(as.numeric(attr(layout, "column_ratios", exact = TRUE)))
  if (length(saved)) {
    take <- seq_len(min(length(saved), max_col))
    ok <- is.finite(saved[take]) & saved[take] > 0
    out[take[ok]] <- pmin(pmax(saved[take[ok]], 0.1), 10)
  }

  # Migration fallback for legacy layouts that only stored widths per cell.
  for (cc in seq_len(max_col)) {
    if (is.finite(out[[cc]]) && out[[cc]] > 0) next
    vals <- vapply(layout, function(row) {
      cells <- row$cells %||% list()
      if (length(cells) < cc) return(NA_real_)
      figure_track_num(cells[[cc]]$width, NA_real_)
    }, numeric(1))
    vals <- vals[is.finite(vals) & vals > 0]
    out[[cc]] <- if (length(vals)) vals[[1]] else 1
  }
  out
}

figure_set_shared_column_ratios <- function(layout, ratios) {
  if (!length(layout)) return(layout)
  max_col <- max(vapply(layout, function(row) length(row$cells %||% list()), integer(1)), 0L)
  if (max_col < 1L) return(layout)

  current <- figure_shared_column_ratios(layout)
  incoming <- suppressWarnings(as.numeric(ratios))
  out <- current
  if (length(incoming)) {
    take <- seq_len(min(length(incoming), max_col))
    ok <- is.finite(incoming[take]) & incoming[take] > 0
    out[take[ok]] <- pmin(pmax(incoming[take[ok]], 0.1), 10)
  }
  attr(layout, "column_ratios") <- out
  for (rr in seq_along(layout)) {
    cells <- layout[[rr]]$cells %||% list()
    if (!length(cells)) next
    for (cc in seq_along(cells)) layout[[rr]]$cells[[cc]]$width <- out[[cc]]
  }
  layout
}

figure_set_shared_column_ratio <- function(layout, col, value) {
  cc <- suppressWarnings(as.integer(col)[1])
  x <- suppressWarnings(as.numeric(value)[1])
  if (!is.finite(cc) || cc < 1L || !is.finite(x) || x <= 0) return(layout)
  ratios <- figure_shared_column_ratios(layout)
  if (cc > length(ratios)) return(layout)
  x <- min(max(x, 0.1), 10)
  if (isTRUE(all.equal(ratios[[cc]], x))) return(layout)
  ratios[[cc]] <- x
  figure_set_shared_column_ratios(layout, ratios)
}

figure_shared_row_ratios <- function(layout) {
  if (!length(layout)) return(numeric(0))
  vapply(layout, function(row) figure_track_num(row$height, 1), numeric(1))
}

figure_shared_track_plan <- function(layout, canvas_w, canvas_h, gap_x = 12, gap_y = 12) {
  cw <- max(1, suppressWarnings(as.numeric(canvas_w)[1]))
  ch <- max(1, suppressWarnings(as.numeric(canvas_h)[1]))
  gx <- max(0, suppressWarnings(as.numeric(gap_x)[1])); if (!is.finite(gx)) gx <- 12
  gy <- max(0, suppressWarnings(as.numeric(gap_y)[1])); if (!is.finite(gy)) gy <- 12

  row_ratios <- figure_shared_row_ratios(layout)
  col_ratios <- figure_shared_column_ratios(layout)
  nr <- length(row_ratios); nc <- length(col_ratios)
  if (!nr || !nc) {
    return(list(row_heights=numeric(0), column_widths=numeric(0), row_starts=numeric(0), column_starts=numeric(0),
                row_ratios=row_ratios, column_ratios=col_ratios, gap_x=gx, gap_y=gy))
  }

  usable_h <- max(1, ch - gy * max(0, nr - 1L))
  usable_w <- max(1, cw - gx * max(0, nc - 1L))
  row_heights <- usable_h * row_ratios / sum(row_ratios)
  column_widths <- usable_w * col_ratios / sum(col_ratios)
  row_starts <- c(0, head(cumsum(row_heights + gy), -1L))
  column_starts <- c(0, head(cumsum(column_widths + gx), -1L))

  list(
    row_heights=row_heights, column_widths=column_widths,
    row_starts=row_starts, column_starts=column_starts,
    row_ratios=row_ratios, column_ratios=col_ratios,
    gap_x=gx, gap_y=gy
  )
}

figure_shared_track_rects <- function(layout, canvas_w, canvas_h, gap_x = 12, gap_y = 12) {
  if (!length(layout)) return(list())
  plan <- figure_shared_track_plan(layout, canvas_w, canvas_h, gap_x, gap_y)
  if (!length(plan$row_heights) || !length(plan$column_widths)) return(list())

  rects <- list(); idx <- 0L
  for (r in seq_along(layout)) {
    cells <- layout[[r]]$cells %||% list()
    if (!length(cells)) next
    for (cc in seq_along(cells)) {
      idx <- idx + 1L
      cell <- cells[[cc]]
      rects[[idx]] <- list(
        index = idx,
        key = cell$key %||% paste0("r", r, "_c", cc),
        row = r, col = cc,
        id = as.character(cell$id %||% ""),
        source_type = as.character(cell$source_type %||% "internal_graph"),
        source_id = as.character(cell$source_id %||% cell$id %||% ""),
        panel_label = as.character(cell$panel_label %||% ""),
        label_size = figure_num_or(cell$label_size, 18, 6, 72),
        top_gutter = figure_num_or(cell$top_gutter, 48, 0, 240),
        label_mode = as.character(cell$label_mode %||% "align")[1],
        label_anchor = as.character(cell$label_anchor %||% "panel")[1],
        label_x_offset = figure_num_or(cell$label_x_offset, 0, -300, 300),
        label_y_offset = figure_num_or(cell$label_y_offset, 0, -300, 300),
        label_x = figure_num_or(cell$label_x, 0.06, -0.2, 1.2),
        label_y = figure_num_or(cell$label_y, 0.02, -0.2, 1.2),
        graph_width = suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)[1]),
        graph_height = suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)[1]),
        track_column_ratio = plan$column_ratios[cc],
        track_row_ratio = plan$row_ratios[r],
        x = plan$column_starts[cc], y = plan$row_starts[r],
        width = plan$column_widths[cc], height = plan$row_heights[r]
      )
    }
  }
  rects
}
