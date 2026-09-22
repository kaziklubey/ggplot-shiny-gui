# figure_layout_auto.R — Auto Row layout policy
# v3.80.6-refactor1: Auto layout is orchestration plus focused geometry helpers.
# No Figure/Graph ownership changes are introduced here.

# v3.73.2.51: Auto Figure rows share one horizontal column-track model.
# A wide attached legend (or any other horizontal decoration) in a lower Row
# may enlarge its own column, but it must not move the start of the next column
# relative to Rows above it. Keep each Graph's natural content placement and
# absorb the difference as empty space at the right edge of the narrower cell.
figure_apply_shared_column_tracks <- function(rects = list(), rows = list(), gap_x = 12, outer_margin = 0) {
  if (!length(rects) || !length(rows)) return(list(rects=rects, rows=rows, column_widths=numeric()))
  gx <- suppressWarnings(as.numeric(gap_x)[1]); if (!is.finite(gx) || gx < 0) gx <- 0
  om <- suppressWarnings(as.numeric(outer_margin)[1]); if (!is.finite(om) || om < 0) om <- 0

  cols <- vapply(rects, function(z) suppressWarnings(as.integer(z$col %||% NA_integer_)[1]), integer(1))
  widths <- vapply(rects, function(z) suppressWarnings(as.numeric(z$width %||% NA_real_)[1]), numeric(1))
  ok <- is.finite(cols) & cols >= 1L & is.finite(widths) & widths > 0
  if (!any(ok)) return(list(rects=rects, rows=rows, column_widths=numeric()))

  max_col <- max(cols[ok])
  col_widths <- rep(1, max_col)
  for (cc in seq_len(max_col)) {
    ww <- widths[ok & cols == cc]
    if (length(ww) && any(is.finite(ww))) col_widths[cc] <- max(ww[is.finite(ww)], 1)
  }
  starts <- om + c(0, head(cumsum(col_widths + gx), -1L))

  rects <- lapply(rects, function(z) {
    cc <- suppressWarnings(as.integer(z$col %||% NA_integer_)[1])
    if (!is.finite(cc) || cc < 1L || cc > length(col_widths)) return(z)
    natural_w <- suppressWarnings(as.numeric(z$width %||% col_widths[cc])[1])
    if (!is.finite(natural_w) || natural_w <= 0) natural_w <- col_widths[cc]
    z$column_natural_width <- natural_w
    z$column_track_width <- col_widths[cc]
    z$x <- starts[cc]
    z$width <- col_widths[cc]
    z
  })

  rows <- lapply(rows, function(z) {
    rr <- suppressWarnings(as.integer(z$row %||% NA_integer_)[1])
    row_cols <- vapply(rects, function(q) {
      qr <- suppressWarnings(as.integer(q$row %||% NA_integer_)[1])
      qc <- suppressWarnings(as.integer(q$col %||% NA_integer_)[1])
      if (is.finite(rr) && is.finite(qr) && rr == qr && is.finite(qc) && qc >= 1L) qc else NA_integer_
    }, integer(1))
    row_cols <- row_cols[is.finite(row_cols)]
    if (!length(row_cols)) return(z)
    last_col <- max(row_cols)
    z$width <- sum(col_widths[seq_len(last_col)]) + gx * max(0, last_col - 1L)
    z$shared_column_tracks <- TRUE
    z
  })

  list(rects=rects, rows=rows, column_widths=col_widths)
}

figure_auto_row_context <- function(row, default_basis = "panel_legend") {
  cells <- row$cells %||% list()
  occupied_idx <- which(vapply(cells, function(cell) nzchar(as.character(cell$id %||% "")), logical(1)))
  if (!length(occupied_idx)) return(NULL)

  # Preserve intentional interior blanks, trim only trailing blanks.
  active_cells <- cells[seq_len(max(occupied_idx))]
  row_basis <- figure_normalize_alignment_basis(row$size_basis %||% "inherit", fallback = "panel_legend", allow_inherit = TRUE)
  effective_basis <- if (identical(row_basis, "inherit")) figure_normalize_alignment_basis(default_basis) else row_basis

  list(active_cells = active_cells, row_basis = row_basis, effective_basis = effective_basis)
}

figure_auto_measure_row_sizes <- function(active_cells, effective_basis, source_sizes = list(), overrides = list()) {
  lapply(active_cells, function(cell) {
    id <- as.character(cell$id %||% "")
    if (!nzchar(id)) return(NULL)
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)

    z <- figure_natural_graph_size(cell, source_sizes[[id]] %||% list(), ov, basis = effective_basis)
    z$size_basis <- effective_basis
    z$alignment_measure <- figure_alignment_reservations(
      source_sizes[[id]] %||% list(), z$scale, basis = effective_basis,
      detached_legend = figure_legend_is_detached(ov)
    )
    z
  })
}

figure_auto_attach_row_crop <- function(sizes, active_cells, overrides = list()) {
  Map(function(z, cell) {
    if (!is.list(z)) return(NULL)
    id <- as.character(cell$id %||% "")
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
    figure_attach_crop_metadata(z, ov)
  }, sizes, active_cells)
}

figure_auto_fill_blank_slots <- function(sizes, active_cells, effective_basis) {
  real_sizes <- Filter(is.list, sizes)
  row_h <- max(vapply(real_sizes, function(z) z$height, numeric(1)), 1)
  occ_widths <- vapply(seq_along(sizes), function(i) if (is.list(sizes[[i]])) sizes[[i]]$width else NA_real_, numeric(1))
  blank_w <- if (any(is.finite(occ_widths))) stats::median(occ_widths[is.finite(occ_widths)]) else 600
  sizes <- Map(function(z, cell) {
    if (is.list(z)) return(z)
    list(
      width = max(1, blank_w), height = row_h, band = 0,
      size_basis = effective_basis, basis_width = NA_real_, basis_height = NA_real_,
      basis_left = NA_real_, basis_top = NA_real_, scale = NA_real_,
      content_left = NA_real_, content_top = NA_real_,
      content_width = NA_real_, content_height = NA_real_
    )
  }, sizes, active_cells)
  list(sizes = sizes, row_height = row_h)
}

figure_auto_rect_from_cell <- function(cell, sz, index, row_index, col_index, x, row_height) {
  list(
    index = index,
    key = cell$key %||% paste0("r", row_index, "_c", col_index),
    row = as.integer(cell$row %||% row_index),
    col = as.integer(cell$col %||% col_index),
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
    auto_fit = TRUE,
    size_basis = sz$size_basis,
    basis_width = sz$basis_width,
    basis_height = sz$basis_height,
    basis_left = sz$basis_left,
    basis_top = sz$basis_top,
    basis_scale = sz$scale,
    crop_source_width = suppressWarnings(as.numeric(sz$crop_source_width %||% NA_real_)[1]),
    crop_source_height = suppressWarnings(as.numeric(sz$crop_source_height %||% NA_real_)[1]),
    crop_source_content_width = suppressWarnings(as.numeric(sz$crop_source_content_width %||% NA_real_)[1]),
    crop_source_content_height = suppressWarnings(as.numeric(sz$crop_source_content_height %||% NA_real_)[1]),
    crop_left_px = suppressWarnings(as.numeric(sz$crop_left_px %||% NA_real_)[1]),
    crop_top_px = suppressWarnings(as.numeric(sz$crop_top_px %||% NA_real_)[1]),
    crop_width_frac = suppressWarnings(as.numeric(sz$crop_width_frac %||% 1)[1]),
    crop_height_frac = suppressWarnings(as.numeric(sz$crop_height_frac %||% 1)[1]),
    content_left = suppressWarnings(as.numeric(sz$content_left %||% NA_real_)[1]),
    content_top = suppressWarnings(as.numeric(sz$content_top %||% NA_real_)[1]),
    content_width = suppressWarnings(as.numeric(sz$content_width %||% NA_real_)[1]),
    content_height = suppressWarnings(as.numeric(sz$content_height %||% NA_real_)[1]),
    panel_common_left = suppressWarnings(as.numeric(sz$panel_common_left %||% NA_real_)[1]),
    panel_common_top = suppressWarnings(as.numeric(sz$panel_common_top %||% NA_real_)[1]),
    panel_common_right = suppressWarnings(as.numeric(sz$panel_common_right %||% NA_real_)[1]),
    panel_common_bottom = suppressWarnings(as.numeric(sz$panel_common_bottom %||% NA_real_)[1]),
    axis_common_left = suppressWarnings(as.numeric(sz$axis_common_left %||% NA_real_)[1]),
    axis_common_top = suppressWarnings(as.numeric(sz$axis_common_top %||% NA_real_)[1]),
    axis_common_right = suppressWarnings(as.numeric(sz$axis_common_right %||% NA_real_)[1]),
    axis_common_bottom = suppressWarnings(as.numeric(sz$axis_common_bottom %||% NA_real_)[1]),
    alignment_anchor_kind = as.character(sz$alignment_anchor_kind %||% "panel")[1],
    x = x,
    y = NA_real_,
    width = sz$width,
    height = row_height
  )
}

figure_auto_prepare_layout_rows <- function(layout, size_basis, source_sizes, overrides) {
  contexts <- lapply(layout, figure_auto_row_context, default_basis = size_basis)
  measured <- lapply(contexts, function(ctx) {
    if (is.null(ctx)) return(NULL)
    figure_auto_measure_row_sizes(ctx$active_cells, ctx$effective_basis, source_sizes, overrides)
  })
  plans <- lapply(measured, figure_auto_alignment_plan)
  shared_left <- max(c(0, vapply(plans, function(p) if (is.null(p)) 0 else p$left, numeric(1))))
  lapply(seq_along(contexts), function(r) {
    ctx <- contexts[[r]]
    if (is.null(ctx)) return(NULL)
    sizes <- measured[[r]]
    plan <- plans[[r]]
    if (!is.null(plan)) {
      # Auto rows share column starts; use one panel-left target across rows.
      plan$left <- shared_left
      sizes <- figure_auto_apply_alignment_plan(sizes, plan)
    }
    sizes <- figure_auto_attach_row_crop(sizes, ctx$active_cells, overrides)
    c(ctx, figure_auto_fill_blank_slots(sizes, ctx$active_cells, ctx$effective_basis))
  })
}

figure_auto_layout_geometry <- function(layout, source_sizes = list(), overrides = list(),
                                        gap_x = 12, gap_y = 12, outer_margin = figure_auto_outer_margin(),
                                        size_basis = "panel_legend",
                                        title_align = c("none", "row_top")) {
  layout <- figure_reindex_layout(layout)
  size_basis <- figure_normalize_alignment_basis(size_basis)
  title_align <- match.arg(title_align)
  gap_x <- max(0, suppressWarnings(as.numeric(gap_x)[1]))
  gap_y <- max(0, suppressWarnings(as.numeric(gap_y)[1]))
  outer_margin <- max(0, suppressWarnings(as.numeric(outer_margin)[1]))
  if (!is.finite(gap_x)) gap_x <- 12
  if (!is.finite(gap_y)) gap_y <- 12
  if (!is.finite(outer_margin)) outer_margin <- 0

  rows <- list()
  rects <- list()
  y <- outer_margin
  idx <- 0L
  prepared_rows <- figure_auto_prepare_layout_rows(layout, size_basis, source_sizes, overrides)

  for (r in seq_along(layout)) {
    prepared <- prepared_rows[[r]]
    if (is.null(prepared)) next
    ctx <- prepared
    sizes <- prepared$sizes
    row_h <- prepared$row_height
    row_w <- sum(vapply(sizes, function(z) z$width, numeric(1))) + gap_x * max(0, length(sizes) - 1L)
    x <- outer_margin

    for (j in seq_along(ctx$active_cells)) {
      idx <- idx + 1L
      rect <- figure_auto_rect_from_cell(ctx$active_cells[[j]], sizes[[j]], idx, r, j, x, row_h)
      rect$y <- y
      rects[[idx]] <- rect
      x <- x + sizes[[j]]$width + gap_x
    }

    rows[[length(rows) + 1L]] <- list(
      row = r, width = row_w, height = row_h, count = length(ctx$active_cells), y = y,
      size_basis = ctx$effective_basis, basis_override = ctx$row_basis
    )
    y <- y + row_h + gap_y
  }

  if (!length(rows)) {
    return(list(rects = list(), rows = list(), content_width = 1, content_height = 1,
                canvas_width = 1, canvas_height = 1, outer_margin = outer_margin))
  }

  shared_cols <- figure_apply_shared_column_tracks(rects, rows, gap_x, outer_margin)
  rects <- shared_cols$rects
  rows <- shared_cols$rows

  content_w <- max(vapply(rows, function(z) z$width, numeric(1)), 1)
  content_h <- sum(vapply(rows, function(z) z$height, numeric(1))) + gap_y * max(0, length(rows) - 1L)
  list(
    rects = rects, rows = rows,
    content_width = content_w, content_height = content_h,
    canvas_width = content_w + 2 * outer_margin,
    canvas_height = content_h + 2 * outer_margin,
    outer_margin = outer_margin
  )
}

# Figure-layer overlays never participate in Row slot allocation. Free legends
# and Insets may only enlarge the final Auto canvas outer bbox.
figure_expand_auto_canvas_for_free_legends <- function(geo, source_sizes = list(), overrides = list()) {
  if (!is.list(geo) || !length(geo$rects %||% list())) return(geo)
  min_x <- 0; min_y <- 0
  max_x <- suppressWarnings(as.numeric(geo$content_width %||% geo$canvas_width %||% 1)[1])
  max_y <- suppressWarnings(as.numeric(geo$content_height %||% geo$canvas_height %||% 1)[1])
  if (!is.finite(max_x) || max_x <= 0) max_x <- 1
  if (!is.finite(max_y) || max_y <= 0) max_y <- 1

  for (rect in geo$rects) {
    id <- as.character(rect$id %||% "")[1]
    if (!nzchar(id)) next
    ov <- figure_override_for(id, overrides)
    ss <- source_sizes[[id]] %||% list()
    sc <- suppressWarnings(as.numeric(rect$basis_scale %||% 1)[1]); if (!is.finite(sc) || sc <= 0) sc <- 1
    ssp <- figure_scale_geometry_meta(ss, sc)
    if (is.null(ssp)) next

    if (identical(as.character(ov$legend %||% ""), "free")) {
      pos <- figure_layer_legend_canvas_position(rect, ssp, ov)
      if (!is.null(pos)) {
        min_x <- min(min_x, pos$x); min_y <- min(min_y, pos$y)
        max_x <- max(max_x, pos$x + pos$width); max_y <- max(max_y, pos$y + pos$height)
      }
    }

    inset_pos <- figure_layer_inset_canvas_position(rect, ssp, ov)
    if (!is.null(inset_pos)) {
      min_x <- min(min_x, inset_pos$x); min_y <- min(min_y, inset_pos$y)
      max_x <- max(max_x, inset_pos$x + inset_pos$width)
      max_y <- max(max_y, inset_pos$y + inset_pos$height)
    }
  }

  shift_x <- if (min_x < 0) -min_x else 0
  shift_y <- if (min_y < 0) -min_y else 0
  if (shift_x > 0 || shift_y > 0) {
    geo$rects <- lapply(geo$rects, function(z) { z$x <- z$x + shift_x; z$y <- z$y + shift_y; z })
    if (length(geo$rows %||% list())) geo$rows <- lapply(geo$rows, function(z) { z$y <- z$y + shift_y; z })
  }
  geo$content_width <- max(1, max_x + shift_x)
  geo$content_height <- max(1, max_y + shift_y)
  geo$canvas_width <- geo$content_width
  geo$canvas_height <- geo$content_height
  geo$overlay_canvas_shift_x <- shift_x
  geo$overlay_canvas_shift_y <- shift_y
  geo$legend_canvas_shift_x <- shift_x
  geo$legend_canvas_shift_y <- shift_y
  geo
}
