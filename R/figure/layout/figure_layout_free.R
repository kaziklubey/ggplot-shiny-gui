# R/figure/layout/figure_layout_free.R — Free layout policy
# v3.80.6-refactor1: split from figure_layout.R.

figure_seed_free_geometry <- function(layout, row_rects = list(), min_width = 120, min_height = 120) {
  st <- figure_reindex_layout(layout)
  by_key <- setNames(row_rects, vapply(row_rects, function(z) as.character(z$key %||% ""), character(1)))
  for (r in seq_along(st)) {
    for (c in seq_along(st[[r]]$cells)) {
      cell <- st[[r]]$cells[[c]]
      key <- as.character(cell$key %||% paste0("r", r, "_c", c))
      rr <- by_key[[key]]
      if (!is.finite(cell$free_x) && is.list(rr)) cell$free_x <- rr$x
      if (!is.finite(cell$free_y) && is.list(rr)) cell$free_y <- rr$y
      if (!is.finite(cell$free_width) && is.list(rr)) {
        seed_w <- suppressWarnings(as.numeric(rr$crop_source_width %||% rr$width)[1])
        if (!is.finite(seed_w) || seed_w <= 0) seed_w <- rr$width
        cell$free_width <- max(min_width, seed_w)
      }
      if (!is.finite(cell$free_height) && is.list(rr)) {
        seed_h <- suppressWarnings(as.numeric(rr$crop_source_height %||% rr$height)[1])
        if (!is.finite(seed_h) || seed_h <= 0) seed_h <- rr$height
        cell$free_height <- max(min_height, seed_h)
      }
      if (!is.finite(cell$z_index)) cell$z_index <- c + (r - 1L) * 12L
      st[[r]]$cells[[c]] <- cell
    }
  }
  st
}

figure_free_layout_geometry <- function(layout, source_sizes = list(), overrides = list(),
                                        canvas_w = 1600, canvas_h = 1000, padding = 24,
                                        size_basis = "panel_legend") {
  layout <- figure_reindex_layout(layout)
  size_basis <- figure_normalize_alignment_basis(size_basis)
  padding <- max(0, suppressWarnings(as.numeric(padding)[1]))
  if (!is.finite(padding)) padding <- 24
  rects <- list()
  idx <- 0L
  max_right <- padding
  max_bottom <- padding
  for (r in seq_along(layout)) {
    row_basis <- figure_normalize_alignment_basis(layout[[r]]$size_basis %||% "inherit", fallback = "panel_legend", allow_inherit = TRUE)
    eff_basis <- if (identical(row_basis, "inherit")) size_basis else row_basis
    for (c in seq_along(layout[[r]]$cells)) {
      cell <- layout[[r]]$cells[[c]]
      id <- as.character(cell$id %||% "")
      if (!nzchar(id)) next
      ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
      natural <- figure_natural_graph_size(
        cell, source_sizes[[id]] %||% list(), ov,
        basis = eff_basis
      )
      natural$size_basis <- eff_basis
      x <- suppressWarnings(as.numeric(cell$free_x %||% NA_real_)[1])
      y <- suppressWarnings(as.numeric(cell$free_y %||% NA_real_)[1])
      w <- suppressWarnings(as.numeric(cell$free_width %||% NA_real_)[1])
      h <- suppressWarnings(as.numeric(cell$free_height %||% NA_real_)[1])
      if (!is.finite(x)) x <- padding + (c - 1L) * (natural$width + 12)
      if (!is.finite(y)) y <- padding + (r - 1L) * (natural$height + 12)
      if (!is.finite(w) || w <= 0) w <- natural$width
      if (!is.finite(h) || h <= 0) h <- natural$height
      full_size <- list(width = w, height = h, band = natural$band %||% figure_label_band(ov))
      cropped_size <- figure_apply_crop_footprint(full_size, ov)
      idx <- idx + 1L
      rects[[idx]] <- list(
        index = idx, key = cell$key, row = r, col = c, id = id,
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
        graph_width = cell$graph_width, graph_height = cell$graph_height,
        x = x, y = y, width = cropped_size$width, height = cropped_size$height,
        crop_source_width = cropped_size$crop_source_width %||% NA_real_,
        crop_source_height = cropped_size$crop_source_height %||% NA_real_,
        crop_source_content_width = cropped_size$crop_source_content_width %||% NA_real_,
        crop_source_content_height = cropped_size$crop_source_content_height %||% NA_real_,
        crop_left_px = cropped_size$crop_left_px %||% NA_real_,
        crop_top_px = cropped_size$crop_top_px %||% NA_real_,
        crop_width_frac = cropped_size$crop_width_frac %||% 1,
        crop_height_frac = cropped_size$crop_height_frac %||% 1,
        auto_fit = FALSE, free_layout = TRUE,
        z_index = suppressWarnings(as.numeric(cell$z_index %||% idx)),
        size_basis = eff_basis
      )
      max_right <- max(max_right, x + cropped_size$width)
      max_bottom <- max(max_bottom, y + cropped_size$height)
    }
  }
  cw <- max(as.numeric(canvas_w %||% 1600), max_right + padding)
  ch <- max(as.numeric(canvas_h %||% 1000), max_bottom + padding)
  list(
    rects = rects, rows = list(), content_width = max_right, content_height = max_bottom,
    canvas_width = cw, canvas_height = ch, outer_margin = padding, free_layout = TRUE
  )
}

