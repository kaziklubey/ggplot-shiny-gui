# figure_layout.R — Figure responsibility module
# v3.3.56: extracted from server.R so Figure state/layout/render logic can evolve
# independently from Shiny orchestration. Functions here are side-effect free unless noted.


figure_layout_rects <- function(layout, canvas_w, canvas_h, gap_x = 12, gap_y = 12) {
  if (!length(layout)) return(list())
  canvas_w <- max(1, as.numeric(canvas_w))
  canvas_h <- max(1, as.numeric(canvas_h))
  gap_x <- max(0, as.numeric(gap_x))
  gap_y <- max(0, as.numeric(gap_y))

  row_weights <- vapply(layout, function(row) {
    x <- suppressWarnings(as.numeric(row$height %||% 1))
    if (!is.finite(x) || x <= 0) 1 else x
  }, numeric(1))
  usable_h <- max(1, canvas_h - gap_y * max(0, length(layout) - 1L))
  row_heights <- usable_h * row_weights / sum(row_weights)

  rects <- list()
  y <- 0
  idx <- 0L
  for (r in seq_along(layout)) {
    row <- layout[[r]]
    cells <- row$cells %||% list()
    if (!length(cells)) {
      y <- y + row_heights[r] + gap_y
      next
    }
    col_weights <- vapply(cells, function(cell) {
      x <- suppressWarnings(as.numeric(cell$width %||% 1))
      if (!is.finite(x) || x <= 0) 1 else x
    }, numeric(1))
    usable_w <- max(1, canvas_w - gap_x * max(0, length(cells) - 1L))
    col_widths <- usable_w * col_weights / sum(col_weights)
    x <- 0
    for (c in seq_along(cells)) {
      idx <- idx + 1L
      cell <- cells[[c]]
      rects[[idx]] <- list(
        index = idx,
        key = cell$key %||% paste0("r", r, "_c", c),
        row = r,
        col = c,
        id = as.character(cell$id %||% ""),
        source_type = as.character(cell$source_type %||% "internal_graph"),
        source_id = as.character(cell$source_id %||% cell$id %||% ""),
        panel_label = as.character(cell$panel_label %||% ""),
        label_size = figure_num_or(cell$label_size, 18, 6, 72),
        top_gutter = figure_num_or(cell$top_gutter, 48, 0, 240),
        label_mode = as.character(cell$label_mode %||% "align")[1],
        label_anchor = as.character(cell$label_anchor %||% "plot_axis")[1],
        label_x_offset = figure_num_or(cell$label_x_offset, 0, -300, 300),
        label_y_offset = figure_num_or(cell$label_y_offset, 0, -300, 300),
        label_x = figure_num_or(cell$label_x, 0.06, -0.2, 1.2),
        label_y = figure_num_or(cell$label_y, 0.02, -0.2, 1.2),
        graph_width = suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)[1]),
        graph_height = suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)[1]),
        x = x,
        y = y,
        width = col_widths[c],
        height = row_heights[r]
      )
      x <- x + col_widths[c] + gap_x
    }
    y <- y + row_heights[r] + gap_y
  }
  rects
}


# v3.3.68: content-driven Figure geometry.  Fixed mode keeps the historical
# "fill the canvas" allocator above.  Auto-fit mode instead treats each
# occupied Panel as a natural-size wrapper around its Graph asset.  Empty
# Panels do not contribute to the content bounding box.
figure_auto_outer_margin <- function() 0

figure_size_basis_bbox <- function(source_size = list(), basis = c("plot", "facet", "axis", "axis_legend")) {
  basis <- match.arg(basis)
  bbox_valid <- function(x) {
    if (!is.list(x)) return(NULL)
    v <- suppressWarnings(as.numeric(c(x$left, x$top, x$width, x$height)))
    if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
    list(left=v[1], top=v[2], width=v[3], height=v[4], right=v[1]+v[3], bottom=v[2]+v[4])
  }
  bbox_union <- function(a, b) {
    aa <- bbox_valid(a); bb <- bbox_valid(b)
    if (is.null(aa)) return(b)
    if (is.null(bb)) return(a)
    left <- min(aa$left, bb$left); top <- min(aa$top, bb$top)
    right <- max(aa$right, bb$right); bottom <- max(aa$bottom, bb$bottom)
    list(left=left, top=top, width=right-left, height=bottom-top)
  }
  z <- switch(
    basis,
    facet = source_size$facet_bbox,
    axis = source_size$axis_outer_bbox,
    axis_legend = bbox_union(source_size$axis_outer_bbox, source_size$legend_bbox),
    source_size$panel_bbox
  )
  if (is.list(z)) {
    vals <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
    if (length(vals) == 4L && all(is.finite(vals)) && vals[3] > 0 && vals[4] > 0) {
      return(list(left = vals[1], top = vals[2], width = vals[3], height = vals[4], basis = basis))
    }
  }
  # Backward-compatible cache/project fallback: older previews only know the
  # aggregate panel width/height, which corresponds to the Plot basis.
  pw <- suppressWarnings(as.numeric(source_size$panel_width %||% source_size$panel_width_px %||% 600)[1])
  ph <- suppressWarnings(as.numeric(source_size$panel_height %||% source_size$panel_height_px %||% 600)[1])
  if (!is.finite(pw) || pw <= 0) pw <- 600
  if (!is.finite(ph) || ph <= 0) ph <- 600
  list(left = 0, top = 0, width = pw, height = ph, basis = basis)
}


figure_axis_gutter_metrics <- function(source_size = list(), scale = 1) {
  bb <- function(z) {
    if (!is.list(z)) return(NULL)
    v <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
    if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
    list(left=v[1], top=v[2], width=v[3], height=v[4], right=v[1]+v[3], bottom=v[2]+v[4])
  }
  panel <- bb(source_size$panel_bbox)
  axis <- bb(source_size$axis_outer_bbox)
  bw <- suppressWarnings(as.numeric(source_size$width %||% 600)[1])
  bh <- suppressWarnings(as.numeric(source_size$height %||% 600)[1])
  if (is.null(panel) || is.null(axis) || !is.finite(bw) || !is.finite(bh) || bw <= 0 || bh <= 0) return(NULL)
  sc <- suppressWarnings(as.numeric(scale)[1]); if (!is.finite(sc) || sc <= 0) sc <- 1
  # Axis gutters are measured relative to the data panel. Anything beyond the
  # axis_outer bbox (plot margins / outside legend etc.) remains graph-specific
  # visual overflow and is never used to shrink the data panel.
  # Current Figure preview scales the complete SVG, not just the data panel.
  # Therefore axis/label gutters are rendered at the same scale.  Keep shared
  # reservations in the same *rendered pixel* unit as the preview; mixing
  # source-px gutters with scaled SVGs caused alignment drift in alpha2.
  list(
    axis_left = max(0, panel$left - axis$left) * sc,
    axis_top = max(0, panel$top - axis$top) * sc,
    axis_right = max(0, axis$right - panel$right) * sc,
    axis_bottom = max(0, axis$bottom - panel$bottom) * sc,
    outer_left = max(0, axis$left) * sc,
    outer_top = max(0, axis$top) * sc,
    outer_right = max(0, bw - axis$right) * sc,
    outer_bottom = max(0, bh - axis$bottom) * sc,
    visual_width = bw * sc,
    visual_height = bh * sc
  )
}

figure_legend_slot_metrics <- function(source_size = list(), scale = 1) {
  bb <- function(z) {
    if (!is.list(z)) return(NULL)
    v <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
    if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
    list(left=v[1], top=v[2], width=v[3], height=v[4], right=v[1]+v[3], bottom=v[2]+v[4])
  }
  axis <- bb(source_size$axis_outer_bbox)
  leg <- bb(source_size$legend_bbox)
  if (is.null(axis)) return(NULL)
  sc <- suppressWarnings(as.numeric(scale)[1]); if (!is.finite(sc) || sc <= 0) sc <- 1
  legend_state <- as.character(source_size$legend_state %||% "unknown")[1]
  geometry_source <- as.character(source_size$geometry_source %||% "unknown")[1]
  # Only an explicit measurement result of "none" is allowed to reserve zero
  # legend space.  A gtable origin by itself does not turn missing/invalid bbox
  # metadata into proof that no legend exists; legacy/ambiguous data stays unknown.
  confirmed_none <- identical(legend_state, "none")
  if (is.null(leg)) {
    if (isTRUE(confirmed_none)) return(list(left=0, top=0, right=0, bottom=0, measured=TRUE, state="none"))
    return(NULL)
  }
  # Preview scales the whole SVG, so legend overflow must use rendered pixels.
  list(
    left = max(0, axis$left - leg$left) * sc,
    top = max(0, axis$top - leg$top) * sc,
    right = max(0, leg$right - axis$right) * sc,
    bottom = max(0, leg$bottom - axis$bottom) * sc,
    measured = TRUE, state = "present"
  )
}

figure_title_bbox_metrics <- function(source_size = list(), scale = 1) {
  z <- source_size$title_bbox
  if (!is.list(z)) return(NULL)
  v <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
  if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
  sc <- suppressWarnings(as.numeric(scale)[1])
  if (!is.finite(sc) || sc <= 0) sc <- 1
  list(left=v[1]*sc, top=v[2]*sc, width=v[3]*sc, height=v[4]*sc)
}



figure_crop_fractions <- function(ov = list()) {
  cr <- ov$crop %||% figure_default_crop()
  cr$enabled <- isTRUE(cr$enabled)
  for (nm in c("left", "top", "right", "bottom")) {
    z <- suppressWarnings(as.numeric(cr[[nm]] %||% 0)[1])
    if (!is.finite(z)) z <- 0
    cr[[nm]] <- min(max(z, 0), 0.49)
  }
  if (cr$left + cr$right >= 0.95) cr$right <- max(0, 0.95 - cr$left)
  if (cr$top + cr$bottom >= 0.95) cr$bottom <- max(0, 0.95 - cr$top)
  cr$width_frac <- if (isTRUE(cr$enabled)) max(0.05, 1 - cr$left - cr$right) else 1
  cr$height_frac <- if (isTRUE(cr$enabled)) max(0.05, 1 - cr$top - cr$bottom) else 1
  cr
}

figure_attach_crop_metadata <- function(z, ov = list()) {
  cr <- figure_crop_fractions(ov)
  if (!isTRUE(cr$enabled)) return(z)
  full_w <- max(1, suppressWarnings(as.numeric(z$width %||% 1)[1]))
  full_h <- max(1, suppressWarnings(as.numeric(z$height %||% 1)[1]))
  band <- max(0, suppressWarnings(as.numeric(z$band %||% 0)[1]))
  if (!is.finite(band)) band <- 0
  band <- min(band, max(0, full_h - 1))
  full_content_h <- max(1, full_h - band)
  z$crop_source_width <- full_w
  z$crop_source_height <- full_h
  z$crop_source_content_width <- suppressWarnings(as.numeric(z$content_width %||% NA_real_)[1])
  z$crop_source_content_height <- suppressWarnings(as.numeric(z$content_height %||% NA_real_)[1])
  z$crop_left_px <- full_w * cr$left
  z$crop_top_px <- full_content_h * cr$top
  z$crop_width_frac <- cr$width_frac
  z$crop_height_frac <- cr$height_frac
  z
}

figure_apply_crop_footprint <- function(z, ov = list()) {
  cr <- figure_crop_fractions(ov)
  z <- figure_attach_crop_metadata(z, ov)
  if (!isTRUE(cr$enabled)) return(z)
  full_w <- max(1, suppressWarnings(as.numeric(z$crop_source_width %||% z$width %||% 1)[1]))
  full_h <- max(1, suppressWarnings(as.numeric(z$crop_source_height %||% z$height %||% 1)[1]))
  band <- max(0, suppressWarnings(as.numeric(z$band %||% 0)[1]))
  if (!is.finite(band)) band <- 0
  band <- min(band, max(0, full_h - 1))
  full_content_h <- max(1, full_h - band)
  z$width <- max(1, full_w * cr$width_frac)
  z$height <- band + max(1, full_content_h * cr$height_frac)
  z
}

figure_uncropped_rect <- function(rect, ov = list()) {
  cr <- figure_crop_fractions(ov)
  if (!isTRUE(cr$enabled)) return(rect)
  out <- rect
  sw <- suppressWarnings(as.numeric(rect$crop_source_width %||% NA_real_)[1])
  sh <- suppressWarnings(as.numeric(rect$crop_source_height %||% NA_real_)[1])
  if (is.finite(sw) && sw > 0) out$width <- sw
  if (is.finite(sh) && sh > 0) out$height <- sh
  scw <- suppressWarnings(as.numeric(rect$crop_source_content_width %||% NA_real_)[1])
  sch <- suppressWarnings(as.numeric(rect$crop_source_content_height %||% NA_real_)[1])
  if (is.finite(scw) && scw > 0) out$content_width <- scw
  if (is.finite(sch) && sch > 0) out$content_height <- sch
  out
}

figure_crop_render_geometry <- function(rect, sp, ov = list()) {
  cr <- figure_crop_fractions(ov)
  full_rect <- figure_uncropped_rect(rect, ov)
  full_off <- figure_plot_offsets(full_rect, sp, ov)
  if (!isTRUE(cr$enabled)) {
    return(list(
      enabled = FALSE, full_rect = full_rect, full_off = full_off,
      shell_left = full_off$dx, shell_top = full_off$dy,
      shell_width = sp$width, shell_height = sp$height,
      inner_left = 0, inner_top = 0, inner_width = sp$width, inner_height = sp$height
    ))
  }
  band <- min(max(0, figure_label_band(ov)), max(0, full_rect$height - 1))
  full_content_h <- max(1, full_rect$height - band)
  crop_left_px <- suppressWarnings(as.numeric(rect$crop_left_px %||% (full_rect$width * cr$left))[1])
  crop_top_px <- suppressWarnings(as.numeric(rect$crop_top_px %||% (full_content_h * cr$top))[1])
  if (!is.finite(crop_left_px)) crop_left_px <- full_rect$width * cr$left
  if (!is.finite(crop_top_px)) crop_top_px <- full_content_h * cr$top
  list(
    enabled = TRUE, full_rect = full_rect, full_off = full_off,
    shell_left = 0, shell_top = band,
    shell_width = max(1, rect$width), shell_height = max(1, rect$height - band),
    inner_left = full_off$dx - crop_left_px,
    inner_top = (full_off$dy - band) - crop_top_px,
    inner_width = sp$width, inner_height = sp$height,
    crop_left_px = crop_left_px, crop_top_px = crop_top_px
  )
}

figure_natural_graph_size <- function(cell, source_size = NULL, ov = list(), basis = c("plot", "facet", "axis", "axis_legend")) {
  # v3.3.70 geometry contract:
  # - source_size$panel_width/panel_height are Graph Axes UI Plot横幅/Plot縦幅
  #   (the axis-enclosed ggplot panel; authoritative plot size).
  # - source_size$width/height are the measured outer visual box including
  #   axes/titles/legend/margins. Auto-fit allocates this visual box while
  #   preserving the panel size through a single common scale factor.
  # - cell graph_width/graph_height are optional Figure-side panel targets.
  bw <- suppressWarnings(as.numeric(source_size$width %||% source_size$plot_width_px %||% 600)[1])
  bh <- suppressWarnings(as.numeric(source_size$height %||% source_size$plot_height_px %||% 600)[1])
  pw <- suppressWarnings(as.numeric(source_size$panel_width %||% source_size$panel_width_px %||% 600)[1])
  ph <- suppressWarnings(as.numeric(source_size$panel_height %||% source_size$panel_height_px %||% 600)[1])
  if (!is.finite(bw) || bw <= 0) bw <- 600
  if (!is.finite(bh) || bh <= 0) bh <- 600
  if (!is.finite(pw) || pw <= 0) pw <- 600
  if (!is.finite(ph) || ph <= 0) ph <- 600

  basis <- match.arg(basis)
  basis_box <- figure_size_basis_bbox(source_size %||% list(), basis)
  basis_w <- suppressWarnings(as.numeric(basis_box$width %||% pw)[1])
  basis_h <- suppressWarnings(as.numeric(basis_box$height %||% ph)[1])
  if (!is.finite(basis_w) || basis_w <= 0) basis_w <- pw
  if (!is.finite(basis_h) || basis_h <= 0) basis_h <- ph

  gw <- suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)[1])
  gh <- suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)[1])
  has_w <- is.finite(gw) && gw > 0
  has_h <- is.finite(gh) && gh > 0

  # Auto uses the Graph-side Plot横幅/縦幅 as the default target. The selected
  # basis decides which measured bbox is fitted to that target. Legend is not
  # part of the basis; it stays visual overflow that can enlarge the canvas.
  # Explicit Figure-side Graph width/height override Auto independently.
  # If only one dimension is explicit, the other remains Auto and follows the
  # same aspect-preserving scale.  Do NOT silently constrain an explicit width
  # by the Graph-side default Plot height (or vice versa).
  sc <- 1
  if (has_w && has_h) {
    sc <- min(gw / basis_w, gh / basis_h)
  } else if (has_w) {
    sc <- gw / basis_w
  } else if (has_h) {
    sc <- gh / basis_h
  } else {
    sc <- min(pw / basis_w, ph / basis_h)
  }
  if (!is.finite(sc) || sc <= 0) sc <- 1
  sc <- min(max(sc, 0.05), 4)

  visual_w <- max(1, bw * sc)
  visual_h <- max(1, bh * sc)
  panel_w <- max(1, pw * sc)
  panel_h <- max(1, ph * sc)
  band <- max(0, figure_label_band(ov))
  list(
    graph_width = panel_w,
    graph_height = panel_h,
    visual_width = visual_w,
    visual_height = visual_h,
    width = visual_w,
    height = visual_h + band,
    band = band,
    scale = sc,
    size_basis = basis,
    basis_width = max(1, basis_w * sc),
    basis_height = max(1, basis_h * sc),
    basis_left = suppressWarnings(as.numeric(basis_box$left %||% 0)[1]) * sc,
    basis_top = suppressWarnings(as.numeric(basis_box$top %||% 0)[1]) * sc
  )
}

figure_auto_layout_geometry <- function(layout, source_sizes = list(), overrides = list(),
                                        gap_x = 12, gap_y = 12, outer_margin = figure_auto_outer_margin(),
                                        size_basis = c("plot", "facet", "axis", "axis_legend"),
                                        title_align = c("none", "row_top")) {
  layout <- figure_reindex_layout(layout)
  size_basis <- match.arg(size_basis)
  title_align <- match.arg(title_align)
  gap_x <- max(0, suppressWarnings(as.numeric(gap_x)[1]))
  gap_y <- max(0, suppressWarnings(as.numeric(gap_y)[1]))
  outer_margin <- max(0, suppressWarnings(as.numeric(outer_margin)[1]))
  if (!is.finite(gap_x)) gap_x <- 12
  if (!is.finite(gap_y)) gap_y <- 12
  if (!is.finite(outer_margin)) outer_margin <- 0

  rows <- list()
  y <- outer_margin
  idx <- 0L
  rects <- list()

  for (r in seq_along(layout)) {
    cells <- layout[[r]]$cells %||% list()
    occupied_idx <- which(vapply(cells, function(cell) nzchar(as.character(cell$id %||% '')), logical(1)))
    if (!length(occupied_idx)) next
    # F1-2d: Auto Canvas preserves intentional interior blank slots. Trim only
    # trailing blanks after the last occupied slot so [A][blank][B] remains a
    # three-column Row while [A][B][blank][blank] does not enlarge Auto Canvas.
    active_cells <- cells[seq_len(max(occupied_idx))]
    occupied <- Filter(function(cell) nzchar(as.character(cell$id %||% '')), active_cells)

    row_basis <- as.character(layout[[r]]$size_basis %||% "inherit")[1]
    if (!row_basis %in% c("inherit", "plot", "facet", "axis", "axis_legend")) row_basis <- "inherit"
    effective_basis <- if (identical(row_basis, "inherit")) size_basis else row_basis

    sizes <- lapply(active_cells, function(cell) {
      id <- as.character(cell$id %||% '')
      if (!nzchar(id)) return(NULL)
      ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
      # Axis mode is alignment-by-gutter, not fit-the-whole-axis-box.  Keep the
      # Graph's plot panel scale authoritative, then reserve a shared axis
      # gutter within this Row. This prevents multiline titles from shrinking
      # only the Graph that owns the larger label.
      base_basis <- if (identical(effective_basis, "axis")) "plot" else effective_basis
      if (identical(base_basis, "axis_legend") && isTRUE(figure_legend_is_detached(ov))) base_basis <- "axis"
      z <- figure_natural_graph_size(cell, source_sizes[[id]] %||% list(), ov, basis = base_basis)
      if (identical(effective_basis, "axis_legend")) z$size_basis <- "axis_legend"
      if (identical(effective_basis, "axis")) {
        z$size_basis <- "axis"
        z$axis_metrics <- figure_axis_gutter_metrics(source_sizes[[id]] %||% list(), z$scale)
      }
      detached_legend <- figure_legend_is_detached(ov)
      z$legend_slot_participates <- !detached_legend
      z$legend_slot_metrics <- if (isTRUE(detached_legend)) {
        # F1-4g/F1-4j: a free legend is a true overlay. It neither contributes
        # to the Row's common legend reservation nor receives padding created by
        # an attached legend on another Graph. Only its final Figure-layer bbox
        # may expand Auto Canvas.
        list(left=0, top=0, right=0, bottom=0, measured=TRUE, state="detached")
      } else {
        figure_legend_slot_metrics(source_sizes[[id]] %||% list(), z$scale)
      }
      z$title_metrics <- figure_title_bbox_metrics(source_sizes[[id]] %||% list(), z$scale)
      z
    })

    if (identical(effective_basis, "axis")) {
      valid_axis <- vapply(sizes, function(z) is.list(z) && is.list(z$axis_metrics), logical(1))
      if (any(valid_axis)) {
        common_left <- max(vapply(sizes[valid_axis], function(z) z$axis_metrics$axis_left, numeric(1)), 0)
        common_top <- max(vapply(sizes[valid_axis], function(z) z$axis_metrics$axis_top, numeric(1)), 0)
        common_right <- max(vapply(sizes[valid_axis], function(z) z$axis_metrics$axis_right, numeric(1)), 0)
        common_bottom <- max(vapply(sizes[valid_axis], function(z) z$axis_metrics$axis_bottom, numeric(1)), 0)
        sizes <- lapply(sizes, function(z) {
          if (!is.list(z)) return(z)
          m <- z$axis_metrics
          if (!is.list(m)) return(z)
          # Put the SVG at a graph-specific offset so every plot panel in the
          # Row shares the same axis gutters. Visual overflow beyond axis_outer
          # (including an outside legend) remains graph-specific.
          pad_l <- max(0, common_left - m$axis_left)
          pad_t <- max(0, common_top - m$axis_top)
          pad_r <- max(0, common_right - m$axis_right)
          pad_b <- max(0, common_bottom - m$axis_bottom)
          z$content_left <- pad_l
          z$content_top <- pad_t
          z$content_width <- z$visual_width
          z$content_height <- z$visual_height
          z$width <- pad_l + z$visual_width + pad_r
          z$height <- z$band + pad_t + z$visual_height + pad_b
          z$basis_width <- z$graph_width + common_left + common_right
          z$basis_height <- z$graph_height + common_top + common_bottom
          z$axis_common_left <- common_left
          z$axis_common_top <- common_top
          z$axis_common_right <- common_right
          z$axis_common_bottom <- common_bottom
          z
        })
      }
    }
    # v3.3.77/F1-4j: keep plot panels aligned when only some Graphs have
    # attached legends. Reserve the maximum real attached-legend overflow on
    # each side within the Row. Legend-less attached Graphs receive the empty
    # alignment slot; detached/free legends are overlays and stay outside this
    # alignment cohort entirely.
    valid_leg <- vapply(sizes, function(z) {
      is.list(z) && isTRUE(z$legend_slot_participates) && is.list(z$legend_slot_metrics)
    }, logical(1))
    if (any(valid_leg)) {
      leg_left <- max(vapply(sizes[valid_leg], function(z) z$legend_slot_metrics$left, numeric(1)), 0)
      leg_top <- max(vapply(sizes[valid_leg], function(z) z$legend_slot_metrics$top, numeric(1)), 0)
      leg_right <- max(vapply(sizes[valid_leg], function(z) z$legend_slot_metrics$right, numeric(1)), 0)
      leg_bottom <- max(vapply(sizes[valid_leg], function(z) z$legend_slot_metrics$bottom, numeric(1)), 0)
      if (any(c(leg_left, leg_top, leg_right, leg_bottom) > 0)) {
        sizes <- lapply(sizes, function(z) {
          if (!is.list(z)) return(z)
          # Detached/free legends are outside the Row legend-slot alignment
          # cohort. They must not inherit empty space from attached legends.
          if (!isTRUE(z$legend_slot_participates)) return(z)
          m <- z$legend_slot_metrics
          if (!is.list(m)) return(z)
          pad_l <- max(0, leg_left - m$left)
          pad_t <- max(0, leg_top - m$top)
          pad_r <- max(0, leg_right - m$right)
          pad_b <- max(0, leg_bottom - m$bottom)
          z$content_left <- suppressWarnings(as.numeric(z$content_left %||% 0)[1]) + pad_l
          z$content_top <- suppressWarnings(as.numeric(z$content_top %||% 0)[1]) + pad_t
          z$content_width <- z$visual_width
          z$content_height <- z$visual_height
          z$width <- z$width + pad_l + pad_r
          z$height <- z$height + pad_t + pad_b
          z$legend_common_left <- leg_left
          z$legend_common_top <- leg_top
          z$legend_common_right <- leg_right
          z$legend_common_bottom <- leg_bottom
          z
        })
      }
    }

    if (identical(title_align, "row_top")) {
      valid_title <- vapply(sizes, function(z) is.list(z) && is.list(z$title_metrics), logical(1))
      if (any(valid_title)) {
        title_tops <- vapply(sizes[valid_title], function(z) {
          suppressWarnings(as.numeric(z$content_top %||% 0)[1]) + z$title_metrics$top
        }, numeric(1))
        common_title_top <- max(title_tops[is.finite(title_tops)], 0)
        sizes <- lapply(sizes, function(z) {
          if (!is.list(z) || !is.list(z$title_metrics)) return(z)
          current_top <- suppressWarnings(as.numeric(z$content_top %||% 0)[1]) + z$title_metrics$top
          if (!is.finite(current_top)) return(z)
          pad_t <- max(0, common_title_top - current_top)
          if (pad_t <= 0) {
            z$title_common_top <- common_title_top
            return(z)
          }
          z$content_top <- suppressWarnings(as.numeric(z$content_top %||% 0)[1]) + pad_t
          z$height <- suppressWarnings(as.numeric(z$height %||% 1)[1]) + pad_t
          z$title_common_top <- common_title_top
          z$title_align_pad_top <- pad_t
          z
        })
      }
    }

    # Row layout owns alignment/slot width. Crop must not change that slot or
    # cause the visible fragment to be re-fitted. Keep the full Row footprint
    # and attach only the non-destructive clip metadata. Free layout applies
    # the cropped visible bbox to its movable Panel footprint separately.
    sizes <- Map(function(z, cell) {
      if (!is.list(z)) return(NULL)
      id <- as.character(cell$id %||% "")
      ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
      figure_attach_crop_metadata(z, ov)
    }, sizes, active_cells)

    real_sizes <- Filter(is.list, sizes)
    row_h <- max(vapply(real_sizes, function(z) z$height, numeric(1)), 1)
    # Interior blanks get a real Auto slot width. Auto Canvas is content-sized,
    # so Fixed-Canvas column ratios must not leak into this calculation. Use the
    # median occupied slot width as the neutral placeholder footprint.
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
    row_w <- sum(vapply(sizes, function(z) z$width, numeric(1))) + gap_x * max(0, length(sizes) - 1L)
    x <- outer_margin

    for (j in seq_along(active_cells)) {
      cell <- active_cells[[j]]
      sz <- sizes[[j]]
      idx <- idx + 1L
      # Keep logical key/row/col for occupied and intentional interior blank slots.
      rects[[idx]] <- list(
        index = idx,
        key = cell$key %||% paste0('r', r, '_c', j),
        row = as.integer(cell$row %||% r),
        col = as.integer(cell$col %||% j),
        id = as.character(cell$id %||% ''),
        source_type = as.character(cell$source_type %||% 'internal_graph'),
        source_id = as.character(cell$source_id %||% cell$id %||% ''),
        panel_label = as.character(cell$panel_label %||% ''),
        label_size = figure_num_or(cell$label_size, 18, 6, 72),
        top_gutter = figure_num_or(cell$top_gutter, 48, 0, 240),
        label_mode = as.character(cell$label_mode %||% 'align')[1],
        label_anchor = as.character(cell$label_anchor %||% 'plot_axis')[1],
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
        axis_common_left = suppressWarnings(as.numeric(sz$axis_common_left %||% NA_real_)[1]),
        axis_common_top = suppressWarnings(as.numeric(sz$axis_common_top %||% NA_real_)[1]),
        axis_common_right = suppressWarnings(as.numeric(sz$axis_common_right %||% NA_real_)[1]),
        axis_common_bottom = suppressWarnings(as.numeric(sz$axis_common_bottom %||% NA_real_)[1]),
        legend_common_left = suppressWarnings(as.numeric(sz$legend_common_left %||% NA_real_)[1]),
        legend_common_top = suppressWarnings(as.numeric(sz$legend_common_top %||% NA_real_)[1]),
        legend_common_right = suppressWarnings(as.numeric(sz$legend_common_right %||% NA_real_)[1]),
        legend_common_bottom = suppressWarnings(as.numeric(sz$legend_common_bottom %||% NA_real_)[1]),
        x = x,
        y = y,
        width = sz$width,
        height = row_h
      )
      x <- x + sz$width + gap_x
    }

    rows[[length(rows) + 1L]] <- list(
      row = r, width = row_w, height = row_h, count = length(active_cells), y = y,
      size_basis = effective_basis, basis_override = row_basis
    )
    y <- y + row_h + gap_y
  }

  if (!length(rows)) {
    return(list(rects = list(), rows = list(), content_width = 1, content_height = 1,
                canvas_width = 1, canvas_height = 1, outer_margin = outer_margin))
  }
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



# F1-5: Figure-layer overlays never participate in Row slot allocation. Free
# legends and Insets may only enlarge the final Auto canvas outer bbox so an
# intentionally detached overlay is not clipped at the Figure boundary.
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
    # Use the exact same placement helpers as Preview rather than maintaining a
    # second AutoCanvas-only interpretation of overlay coordinates.
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
  # Backward-compatible diagnostics fields retained for alpha consumers.
  geo$legend_canvas_shift_x <- shift_x
  geo$legend_canvas_shift_y <- shift_y
  geo
}

figure_override_for <- function(id, overrides = list()) {
  raw_override <- overrides[[id]] %||% list()
  ov <- modifyList(figure_default_override(id), raw_override)
  scalar_chr <- function(x, fallback = "") {
    z <- as.character(x %||% fallback)
    if (!length(z) || is.na(z[[1]])) fallback else z[[1]]
  }
  scalar_num <- function(x, fallback) {
    z <- suppressWarnings(as.numeric(x)[1])
    if (!length(z) || !is.finite(z)) fallback else z
  }
  ov$panel_label <- scalar_chr(ov$panel_label, "")
  ov$label_size <- scalar_num(ov$label_size, 18)
  ov$top_gutter <- scalar_num(ov$top_gutter, 48)
  ov$top_gutter <- min(max(ov$top_gutter, 0), 240)
  ov$label_mode <- scalar_chr(ov$label_mode, "align")
  if (!ov$label_mode %in% c("align", "free")) ov$label_mode <- "align"
  ov$label_anchor <- scalar_chr(ov$label_anchor, "plot_axis")
  if (!ov$label_anchor %in% c("plot_axis", "plot_left", "cell_left")) ov$label_anchor <- "plot_axis"
  ov$label_x_offset <- scalar_num(ov$label_x_offset, 0)
  ov$label_y_offset <- scalar_num(ov$label_y_offset, 0)
  ov$label_x <- scalar_num(ov$label_x, 0.06)
  ov$label_y <- scalar_num(ov$label_y, 0.02)
  raw_legend_mode <- scalar_chr(ov$legend, "inherit")
  raw_anchor <- scalar_chr(raw_override$legend_free_anchor, "")
  legacy_detached_coords <- raw_legend_mode %in% c("inside", "panel", "free") && !identical(raw_anchor, "graph")
  # F1-4g migration: alpha Plot/Panel detached modes collapse into the single
  # owner-Graph-relative free mode. Old detached coordinates used incompatible
  # frames, so they seed once from the source legend instead of being misread.
  ov$legend <- if (raw_legend_mode %in% c("inside", "panel")) "free" else raw_legend_mode
  ov$legend_free_anchor <- "graph"
  if (!ov$legend %in% c("inherit", "none", "right", "left", "top", "bottom", "free")) ov$legend <- "inherit"
  ov$legend_title <- figure_normalize_legend_title_mode(ov$legend_title)
  ov$legend_gap <- suppressWarnings(as.numeric(ov$legend_gap %||% 8))
  if (!is.finite(ov$legend_gap)) ov$legend_gap <- 8
  ov$legend_x <- suppressWarnings(as.numeric(ov$legend_x %||% 0.72))
  if (!is.finite(ov$legend_x)) ov$legend_x <- 0.72
  ov$legend_y <- suppressWarnings(as.numeric(ov$legend_y %||% 0.08))
  if (!is.finite(ov$legend_y)) ov$legend_y <- 0.08
  ov$legend_free_x <- suppressWarnings(as.numeric(ov$legend_free_x %||% ov$legend_x))
  if (!is.finite(ov$legend_free_x)) ov$legend_free_x <- ov$legend_x
  ov$legend_free_y <- suppressWarnings(as.numeric(ov$legend_free_y %||% ov$legend_y))
  if (!is.finite(ov$legend_free_y)) ov$legend_free_y <- ov$legend_y
  # Detached free legends use owner-Graph-relative coordinates and may live
  # outside both the Graph and its Row/Panel slot. Keep a generous finite range
  # without forcing them back into [0,1].
  ov$legend_free_x <- min(max(ov$legend_free_x, -2), 3)
  ov$legend_free_y <- min(max(ov$legend_free_y, -2), 3)
  # Legacy detached placement cannot be mapped exactly without its old runtime
  # frame, so seed it from the stable source position once after load. New F1-4g
  # state carries `legend_free_anchor = "graph"` and preserves manual X/Y.
  ov$legend_free_auto <- if (isTRUE(legacy_detached_coords)) TRUE else isTRUE(ov$legend_free_auto)
  ov$legend_free_origin <- as.character(ov$legend_free_origin %||% "inherit")[1]
  if (!ov$legend_free_origin %in% c("inherit", "right", "left", "top", "bottom", "inside")) ov$legend_free_origin <- "inherit"
  ov$legend_source_origin <- as.character(ov$legend_source_origin %||% "inherit")[1]
  if (!ov$legend_source_origin %in% c("inherit", "right", "left", "top", "bottom", "inside")) ov$legend_source_origin <- "inherit"
  ov$legend_source_x <- suppressWarnings(as.numeric(ov$legend_source_x %||% ov$legend_x)[1])
  if (!is.finite(ov$legend_source_x)) ov$legend_source_x <- ov$legend_x
  ov$legend_source_y <- suppressWarnings(as.numeric(ov$legend_source_y %||% ov$legend_y)[1])
  if (!is.finite(ov$legend_source_y)) ov$legend_source_y <- ov$legend_y
  ov$legend_source_x <- min(max(ov$legend_source_x, 0), 1)
  ov$legend_source_y <- min(max(ov$legend_source_y, 0), 1)
  ov$legend_last_side <- as.character(ov$legend_last_side %||% "")[1]
  if (!ov$legend_last_side %in% c("right", "left", "top", "bottom")) ov$legend_last_side <- ""
  if (!is.list(ov$legend_detach_snapshot)) ov$legend_detach_snapshot <- NULL
  ov$align_h <- as.character(ov$align_h %||% "center")
  if (!ov$align_h %in% c("left", "center", "right")) ov$align_h <- "center"
  ov$align_v <- as.character(ov$align_v %||% "center")
  if (!ov$align_v %in% c("top", "center", "bottom")) ov$align_v <- "center"
  crop <- ov$crop %||% figure_default_crop()
  crop$enabled <- isTRUE(crop$enabled)
  for (nm in c("left", "top", "right", "bottom")) {
    crop[[nm]] <- suppressWarnings(as.numeric(crop[[nm]] %||% 0))
    if (!is.finite(crop[[nm]])) crop[[nm]] <- 0
    crop[[nm]] <- min(max(crop[[nm]], 0), 0.49)
  }
  if (crop$left + crop$right >= 0.95) crop$right <- max(0, 0.95 - crop$left)
  if (crop$top + crop$bottom >= 0.95) crop$bottom <- max(0, 0.95 - crop$top)
  ov$crop <- crop

  inset <- ov$inset %||% figure_default_inset()
  inset$enabled <- isTRUE(inset$enabled)
  inset$source_type <- as.character(inset$source_type %||% "internal_graph")[1]
  if (!inset$source_type %in% c("internal_graph", "external_asset")) inset$source_type <- "internal_graph"
  inset$source_id <- as.character(inset$source_id %||% "")[1]
  # F1-5 schema: a single owner-Graph-relative coordinate system, matching the
  # detached legend contract. Legacy alpha coordinates are kept numerically but
  # normalized into this coordinate space on first materialization.
  inset$anchor <- "graph"
  for (nm in c("x", "y", "width", "height")) {
    inset[[nm]] <- suppressWarnings(as.numeric(inset[[nm]] %||% c(x=.62,y=.08,width=.32,height=.32)[[nm]]))
    if (!is.finite(inset[[nm]])) inset[[nm]] <- c(x=.62,y=.08,width=.32,height=.32)[[nm]]
  }
  inset$x <- min(max(inset$x, -2), 3)
  inset$y <- min(max(inset$y, -2), 3)
  inset$width <- min(max(inset$width, 0.05), 1.5)
  inset$height <- min(max(inset$height, 0.05), 1.5)
  inset$border <- isTRUE(inset$border)
  inset$border_width <- min(max(suppressWarnings(as.numeric(inset$border_width %||% 1)), 0), 20)
  # Layer ordering is structural, not a per-Inset style knob.
  inset$z_index <- 20
  ov$inset <- inset

  app <- modifyList(figure_default_appearance_override(), ov$appearance %||% list())
  for (nm in c("title_mode", "xlab_mode", "ylab_mode")) {
    app[[nm]] <- as.character(app[[nm]] %||% "inherit")[1]
    if (!app[[nm]] %in% c("inherit", "override")) app[[nm]] <- "inherit"
  }
  for (nm in c("title", "xlab", "ylab")) app[[nm]] <- as.character(app[[nm]] %||% "")[1]
  for (nm in c("color_mode", "linetype_mode", "shape_mode")) {
    app[[nm]] <- as.character(app[[nm]] %||% "inherit")[1]
    if (!app[[nm]] %in% c("inherit", "override")) app[[nm]] <- "inherit"
  }
  app$color <- as.character(app$color %||% "#000000")[1]
  if (!grepl("^#[0-9A-Fa-f]{6}$", app$color)) app$color <- "#000000"
  app$linetype <- as.character(app$linetype %||% "solid")[1]
  if (!app$linetype %in% c("solid","dashed","dotted","dotdash","longdash","twodash")) app$linetype <- "solid"
  app$shape <- suppressWarnings(as.numeric(app$shape %||% 16)[1])
  if (!is.finite(app$shape)) app$shape <- 16
  app$shape <- min(max(round(app$shape), 0), 25)
  for (nm in c("base_size", "axis_title_size", "axis_text_size", "alpha", "point_size", "line_width", "ymin", "ymax")) {
    z <- suppressWarnings(as.numeric(app[[nm]] %||% NA_real_)[1])
    app[[nm]] <- if (is.finite(z)) z else NA_real_
  }
  if (is.finite(app$base_size)) app$base_size <- min(max(app$base_size, 5), 96)
  if (is.finite(app$axis_title_size)) app$axis_title_size <- min(max(app$axis_title_size, 5), 96)
  if (is.finite(app$axis_text_size)) app$axis_text_size <- min(max(app$axis_text_size, 4), 72)
  if (is.finite(app$alpha)) app$alpha <- min(max(app$alpha, 0), 1)
  if (is.finite(app$point_size)) app$point_size <- min(max(app$point_size, 0), 30)
  if (is.finite(app$line_width)) app$line_width <- min(max(app$line_width, 0), 12)
  ov$appearance <- app

  exleg <- modifyList(figure_default_external_legend(), ov$external_legend %||% list())
  exleg$mode <- as.character(exleg$mode %||% "inherit")[1]
  if (!exleg$mode %in% c("inherit", "included", "separate", "none")) exleg$mode <- "inherit"
  exleg$position <- as.character(exleg$position %||% "right")[1]
  if (!exleg$position %in% c("right", "left", "top", "bottom", "free")) exleg$position <- "right"
  for (nm in c("x","y","width","height","gap","scale")) {
    z <- suppressWarnings(as.numeric(exleg[[nm]] %||% figure_default_external_legend()[[nm]])[1])
    if (!is.finite(z)) z <- figure_default_external_legend()[[nm]]
    exleg[[nm]] <- z
  }
  exleg$x <- min(max(exleg$x, -0.2), 1.2); exleg$y <- min(max(exleg$y, -0.2), 1.2)
  exleg$width <- min(max(exleg$width, 0.03), 1.5); exleg$height <- min(max(exleg$height, 0.03), 1.5)
  exleg$gap <- min(max(exleg$gap, 0), 200); exleg$scale <- min(max(exleg$scale, 0.1), 5)
  ov$external_legend <- exleg
  ov
}

figure_apply_layer_style_override <- function(p, app) {
  if (is.null(p$layers) || !length(p$layers)) return(p)
  needs_layer_copy <- identical(app$color_mode %||% "inherit", "override") ||
    identical(app$linetype_mode %||% "inherit", "override") ||
    identical(app$shape_mode %||% "inherit", "override") ||
    any(is.finite(c(app$alpha, app$point_size, app$line_width)))
  if (!isTRUE(needs_layer_copy)) return(p)

  # Layers are ggproto/reference-like. Clone *all* layers before the first
  # mutation. If any clone fails, abort the Figure override rather than
  # continuing with an object that could still share Graph-owned references.
  cloned <- lapply(p$layers, function(original_layer) {
    tryCatch(ggplot2::ggproto(NULL, original_layer), error = function(e) NULL)
  })
  if (length(cloned) != length(p$layers) || any(vapply(cloned, is.null, logical(1)))) {
    stop("Figure layer clone failed; source Graph left unchanged")
  }
  p$layers <- cloned

  use_linewidth <- tryCatch(utils::packageVersion("ggplot2") >= "3.4.0", error=function(e) TRUE)
  for (i in seq_along(p$layers)) {
    layer <- p$layers[[i]]
    layer$aes_params <- as.list(layer$aes_params %||% list())
    geom_classes <- class(layer$geom)
    if (identical(app$color_mode, "override")) {
      if (any(grepl("Geom(Point|Line|Path|Step|Errorbar|Segment|Smooth)", geom_classes))) layer$aes_params$colour <- app$color
      if (any(grepl("Geom(Bar|Col|Boxplot|Violin|Area|Ribbon)", geom_classes))) layer$aes_params$fill <- app$color
    }
    if (identical(app$linetype_mode, "override") && any(grepl("Geom(Line|Path|Step|Errorbar|Segment|Smooth)", geom_classes))) layer$aes_params$linetype <- app$linetype
    if (identical(app$shape_mode, "override") && any(grepl("GeomPoint", geom_classes, fixed=TRUE))) layer$aes_params$shape <- app$shape
    if (is.finite(app$alpha)) layer$aes_params$alpha <- app$alpha
    if (is.finite(app$point_size) && any(grepl("GeomPoint", geom_classes, fixed=TRUE))) layer$aes_params$size <- app$point_size
    if (is.finite(app$line_width) && any(grepl("Geom(Line|Path|Step|Errorbar|Segment)", geom_classes))) {
      if (isTRUE(use_linewidth)) layer$aes_params$linewidth <- app$line_width else layer$aes_params$size <- app$line_width
    }
    p$layers[[i]] <- layer
  }
  p
}

figure_apply_y_range_override <- function(p, app) {
  ymin <- suppressWarnings(as.numeric(app$ymin %||% NA_real_)[1])
  ymax <- suppressWarnings(as.numeric(app$ymax %||% NA_real_)[1])
  if (!is.finite(ymin) && !is.finite(ymax)) return(p)
  # Partial range semantics depend on Graph-side auto-range rules.  alpha3 keeps
  # a one-sided override as pending state rather than silently inventing the
  # other side.  Graph commit remains unsupported until Graph-side range
  # semantics can be represented exactly.
  if (!is.finite(ymin) || !is.finite(ymax) || ymin >= ymax) return(p)

  # Do not layer a new coord_cartesian() on top of ggbreak/special coordinates.
  cls <- c(class(p), unlist(lapply(p$scales$scales %||% list(), class), use.names = FALSE))
  if (any(grepl("ggbreak", cls, ignore.case = TRUE))) return(p)
  coord <- p$coordinates
  if (is.null(coord) || !inherits(coord, "CoordCartesian")) return(p)
  coord2 <- tryCatch(ggplot2::ggproto(NULL, coord), error = function(e) NULL)
  if (is.null(coord2)) return(p)
  lim <- coord2$limits %||% list()
  lim$y <- c(ymin, ymax)
  coord2$limits <- lim
  p$coordinates <- coord2
  p
}


figure_apply_plot_override <- function(p, ov) {
  legend_title_mode <- figure_normalize_legend_title_mode(ov$legend_title)
  if (identical(legend_title_mode, "hide")) {
    p <- p + ggplot2::theme(legend.title = ggplot2::element_blank())
  } else if (identical(legend_title_mode, "show")) {
    p <- p + ggplot2::theme(legend.title = ggplot2::element_text())
  }
  if (identical(ov$legend, "none")) {
    p <- p + ggplot2::theme(legend.position = "none")
  } else if (ov$legend %in% c("right", "left", "top", "bottom")) {
    p <- p + ggplot2::theme(
      legend.position = ov$legend,
      legend.box.spacing = grid::unit(max(0, ov$legend_gap) / 120, "in")
    )
  } else if (identical(ov$legend, "inside")) {
    # ggplot2 >= 3.5 uses legend.position.inside. Older versions use
    # numeric legend.position. Choose explicitly so an unsupported theme
    # element cannot fail later during ggplot build.
    if (utils::packageVersion("ggplot2") >= "3.5.0") {
      p <- p + ggplot2::theme(
        legend.position = "inside",
        legend.position.inside = c(ov$legend_x, 1 - ov$legend_y),
        legend.justification.inside = c(0, 1),
        legend.background = ggplot2::element_rect(fill = scales::alpha("white", 0.85), colour = NA)
      )
    } else {
      p <- p + ggplot2::theme(
        legend.position = c(ov$legend_x, 1 - ov$legend_y),
        legend.justification = c(0, 1),
        legend.background = ggplot2::element_rect(fill = scales::alpha("white", 0.85), colour = NA)
      )
    }
  }

  app <- ov$appearance %||% figure_default_appearance_override()
  labs_args <- list()
  if (identical(app$title_mode, "override")) labs_args$title <- app$title
  if (identical(app$xlab_mode, "override")) labs_args$x <- app$xlab
  if (identical(app$ylab_mode, "override")) labs_args$y <- app$ylab
  if (length(labs_args)) p <- p + do.call(ggplot2::labs, labs_args)

  theme_bits <- list()
  if (is.finite(app$base_size)) theme_bits$text <- ggplot2::element_text(size = app$base_size)
  if (is.finite(app$axis_title_size)) theme_bits$axis.title <- ggplot2::element_text(size = app$axis_title_size)
  if (is.finite(app$axis_text_size)) theme_bits$axis.text <- ggplot2::element_text(size = app$axis_text_size)
  if (length(theme_bits)) p <- p + do.call(ggplot2::theme, theme_bits)
  p <- figure_apply_layer_style_override(p, app)

  p <- figure_apply_y_range_override(p, app)
  p
}


figure_label_band <- function(ov) {
  lbl <- as.character(ov$panel_label %||% "")
  if (!length(lbl) || is.na(lbl[[1]]) || !nzchar(lbl[[1]])) return(0)
  g <- suppressWarnings(as.numeric(ov$top_gutter)[1])
  if (!length(g) || !is.finite(g)) g <- 48
  g <- min(max(g, 0), 240)
  # A positive gutter is treated as a minimum; keep enough room for the
  # current label font automatically. Setting gutter=0 explicitly enables
  # intentional overlay placement with no reserved top band.
  if (g > 0) {
    fs <- suppressWarnings(as.numeric(ov$label_size)[1])
    if (!length(fs) || !is.finite(fs)) fs <- 18
    g <- max(g, fs + 12)
  }
  min(g, 240)
}

figure_plot_for_scale <- function(p_raw, ov, ex, scale = 1) {
  rr <- suppressWarnings(as.numeric(ex$reference_res %||% 120))
  if (!is.finite(rr) || rr <= 0) rr <- 120
  pw <- suppressWarnings(as.numeric(ex$panel_width_px %||% ex$plot_width_px %||% 600))
  ph <- suppressWarnings(as.numeric(ex$panel_height_px %||% ex$plot_height_px %||% 600))
  if (!is.finite(pw) || pw <= 0) pw <- 600
  if (!is.finite(ph) || ph <= 0) ph <- 600
  scale <- suppressWarnings(as.numeric(scale))
  if (!is.finite(scale) || scale <= 0) scale <- 1

  # Phase 10: do not serialize/unserialize the Graph-owned ggplot here.
  #
  # The previous all-object deep copy recursively duplicated layer/data
  # environments and became catastrophically expensive as a session aged
  # (tens of seconds per Figure geometry measurement on the Windows runtime).
  #
  # Keep p_raw as an immutable source value and rely on the mutation sites below
  # to detach only the reference-like components they actually change:
  #   * figure_apply_layer_style_override() clones every layer with ggproto()
  #     before changing aes_params.
  #   * figure_apply_y_range_override() clones the coordinate ggproto before
  #     changing its limits.
  #   * theme/labs/legend/fixed-panel changes use ggplot `+`, which returns the
  #     derived Figure plot rather than editing GraphState or p_raw in place.
  # Top-level `$<-` assignments in those helpers also trigger ordinary R
  # copy-on-modify before the cloned component is installed.  Therefore the
  # Figure path must never add a new direct mutation of a Graph-owned ggproto
  # without cloning that component first.
  #
  # Start from a ggplot-native no-op addition rather than a raw alias.  ggplot's
  # `+` path creates the derived plot container without recursively serializing
  # the data/layer environments; reference-like components remain shared only
  # until (and unless) the guarded helpers above need to mutate them.
  p <- tryCatch(p_raw + ggplot2::theme(), error = function(e) NULL)
  if (is.null(p)) stop("Figure plot local copy failed; source Graph left unchanged")
  p <- figure_apply_plot_override(p, ov)
  p <- apply_fixed_panel_size(p, pw * scale, ph * scale, reference_res = rr)
  dims <- measure_plot_geometry_px(
    p, reference_res = rr,
    fallback_width = pw * scale,
    fallback_height = ph * scale
  )
  list(
    plot = p,
    width = dims$width,
    height = dims$height,
    panel_left = dims$panel_left,
    panel_top = dims$panel_top,
    panel_width = dims$panel_width,
    panel_height = dims$panel_height,
    panel_bbox = dims$panel_bbox,
    facet_bbox = dims$facet_bbox,
    axis_outer_bbox = dims$axis_outer_bbox,
    content_outer_bbox = dims$content_outer_bbox,
    title_bbox = dims$title_bbox,
    legend_bbox = dims$legend_bbox,
    legend_visual_bbox = dims$legend_visual_bbox %||% dims$legend_bbox,
    legend_outside_bbox = dims$legend_outside_bbox,
    legend_outside_visual_bbox = dims$legend_outside_visual_bbox %||% dims$legend_outside_bbox,
    legend_state = dims$legend_state %||% "unknown",
    geometry_source = dims$geometry_source %||% "unknown",
    scale = scale
  )
}


figure_graph_target_box <- function(rect, ov) {
  # Crop changes only the Figure footprint. Fit/render the Graph against the
  # uncropped source box so its visual scale never changes when margins are cut.
  rect <- figure_uncropped_rect(rect, ov)
  band <- min(max(0, figure_label_band(ov)), max(0, rect$height - 1))
  panel_w <- max(1, suppressWarnings(as.numeric(rect$width)[1]))
  panel_h <- max(1, suppressWarnings(as.numeric(rect$height)[1]) - band)
  gw <- suppressWarnings(as.numeric(rect$graph_width %||% NA_real_)[1])
  gh <- suppressWarnings(as.numeric(rect$graph_height %||% NA_real_)[1])
  explicit_w <- is.finite(gw) && gw > 0
  explicit_h <- is.finite(gh) && gh > 0

  # Auto-fit geometry has already converted the Graph-side panel target into
  # the full visual box.  Do not cap that visual box again by graph_width /
  # graph_height, otherwise a right legend or axis decoration would shrink the
  # data panel a second time.
  if (isTRUE(rect$auto_fit) || isTRUE(rect$basis_fit)) {
    cw <- suppressWarnings(as.numeric(rect$content_width %||% NA_real_)[1])
    ch <- suppressWarnings(as.numeric(rect$content_height %||% NA_real_)[1])
    if (!is.finite(cw) || cw <= 0) cw <- panel_w
    if (!is.finite(ch) || ch <= 0) ch <- panel_h
    return(list(
      width = cw,
      height = ch,
      # v3.3.78: Auto-fit may still have an explicit per-Graph width/height.
      # Keep that fact here so cached/live SVG fitting is allowed to scale
      # above 1x.  v3.3.77 incorrectly forced explicit=FALSE, which made
      # figure_fit_cached_geometry()/figure_plot_spec_for_rect() cap the
      # asset at its natural size even though the layout box grew.
      explicit = explicit_w || explicit_h,
      requested_width = if (explicit_w) gw else NA_real_,
      requested_height = if (explicit_h) gh else NA_real_,
      band = band
    ))
  }

  list(
    width = if (explicit_w) min(panel_w, gw) else panel_w,
    height = if (explicit_h) min(panel_h, gh) else panel_h,
    explicit = explicit_w || explicit_h,
    requested_width = if (explicit_w) gw else NA_real_,
    requested_height = if (explicit_h) gh else NA_real_,
    band = band
  )
}


figure_plot_spec_for_rect <- function(p_raw, ov, ex, rect) {
  target <- figure_graph_target_box(rect, ov)
  band <- target$band
  avail_w <- max(1, target$width)
  avail_h <- max(1, target$height)

  base <- figure_plot_for_scale(p_raw, ov, ex, 1)
  sc <- min(avail_w / base$width, avail_h / base$height)
  if (!is.finite(sc) || sc <= 0) sc <- 1
  # Auto mode keeps the Graph-side size as the authority (legacy behavior).
  # An explicit Figure Graph size may enlarge vector output as well as shrink
  # it, but it still remains bounded by the current Panel frame.
  max_scale <- if (isTRUE(target$explicit)) 4 else 1
  sc <- min(max(sc, 0.05), max_scale)

  cur <- figure_plot_for_scale(p_raw, ov, ex, sc)
  # Legend/textなどはpanel倍率に比例しないので、はみ出す場合だけ再補正。
  corr <- min(avail_w / cur$width, avail_h / cur$height, 1)
  if (is.finite(corr) && corr < 0.999) {
    sc <- max(0.05, sc * corr)
    cur <- figure_plot_for_scale(p_raw, ov, ex, sc)
  }

  cur$band <- band
  cur
}


figure_plot_offsets <- function(rect, fit, ov) {
  band <- min(max(0, figure_label_band(ov)), max(0, rect$height - 1))
  total_w <- suppressWarnings(as.numeric(fit$width %||% 1))
  total_h <- suppressWarnings(as.numeric(fit$height %||% 1))
  if (!is.finite(total_w) || total_w <= 0) total_w <- 1
  if (!is.finite(total_h) || total_h <= 0) total_h <- 1
  panel_left <- suppressWarnings(as.numeric(fit$panel_left %||% 0))
  panel_top <- suppressWarnings(as.numeric(fit$panel_top %||% 0))
  panel_w <- suppressWarnings(as.numeric(fit$panel_width %||% total_w))
  panel_h <- suppressWarnings(as.numeric(fit$panel_height %||% total_h))
  if (!is.finite(panel_left)) panel_left <- 0
  if (!is.finite(panel_top)) panel_top <- 0
  if (!is.finite(panel_w) || panel_w <= 0) panel_w <- total_w
  if (!is.finite(panel_h) || panel_h <= 0) panel_h <- total_h

  # Axis-basis auto layout can provide an explicit SVG offset.  This is the
  # shared-gutter contract: the plot panel stays at its Graph-side scale while
  # multiline axis titles only add reserved space around it.
  content_left <- suppressWarnings(as.numeric(rect$content_left %||% NA_real_)[1])
  content_top <- suppressWarnings(as.numeric(rect$content_top %||% NA_real_)[1])
  if ((isTRUE(rect$auto_fit) || isTRUE(rect$basis_fit)) && is.finite(content_left) && is.finite(content_top)) {
    return(list(dx = max(0, content_left), dy = band + max(0, content_top)))
  }

  # Center alignment is panel-aware: the data panel, not the asymmetric full
  # ggplot box (e.g. right legend), is centered in the Figure cell.
  dx <- switch(
    ov$align_h,
    left = 0,
    right = rect$width - total_w,
    rect$width / 2 - (panel_left + panel_w / 2)
  )
  usable_h <- max(1, rect$height - band)
  inner_dy <- switch(
    ov$align_v,
    top = 0,
    bottom = usable_h - total_h,
    usable_h / 2 - (panel_top + panel_h / 2)
  )

  # figure_plot_spec_for_rect already scales total plot to fit the cell; clamp
  # for rounding and unusual grobs so outside legends/titles are not clipped.
  dx <- min(max(0, dx), max(0, rect$width - total_w))
  inner_dy <- min(max(0, inner_dy), max(0, usable_h - total_h))
  list(dx = dx, dy = band + inner_dy)
}

figure_label_position <- function(rect, sp, ov) {
  if (identical(ov$label_mode %||% "align", "free")) {
    return(list(
      x = rect$width * (ov$label_x %||% 0.06),
      y = rect$height * (ov$label_y %||% 0.02)
    ))
  }

  off <- figure_plot_offsets(rect, sp, ov)
  if (identical(ov$label_anchor, "cell_left")) {
    x <- 8
    y <- max(2, (figure_label_band(ov) - ov$label_size) / 2)
  } else if (identical(ov$label_anchor, "plot_left")) {
    x <- off$dx + 4
    y <- max(2, off$dy - ov$label_size - 6)
  } else {
    panel_left <- suppressWarnings(as.numeric(sp$panel_left %||% 0))
    if (!is.finite(panel_left)) panel_left <- 0
    x <- off$dx + panel_left
    y <- max(2, off$dy - ov$label_size - 6)
  }
  x <- x + ov$label_x_offset
  y <- y + ov$label_y_offset
  list(x = x, y = y)
}


figure_plot_panel_zone <- function(rect, sp, ov) {
  off <- figure_plot_offsets(rect, sp, ov)
  pl <- suppressWarnings(as.numeric(sp$panel_left %||% 0))
  pt <- suppressWarnings(as.numeric(sp$panel_top %||% 0))
  pw <- suppressWarnings(as.numeric(sp$panel_width %||% sp$width %||% 1))
  ph <- suppressWarnings(as.numeric(sp$panel_height %||% sp$height %||% 1))
  if (!is.finite(pl)) pl <- 0
  if (!is.finite(pt)) pt <- 0
  if (!is.finite(pw) || pw <= 0) pw <- max(1, sp$width %||% 1)
  if (!is.finite(ph) || ph <= 0) ph <- max(1, sp$height %||% 1)
  list(
    x = off$dx + pl,
    y = off$dy + pt,
    width = pw,
    height = ph
  )
}


figure_legend_handle_position <- function(rect, sp, ov) {
  z <- figure_plot_panel_zone(rect, sp, ov)
  list(
    x = z$x + z$width * (ov$legend_x %||% 0.72),
    y = z$y + z$height * (ov$legend_y %||% 0.08)
  )
}


# -----------------------------------------------------------------------------
# v3.4.0-alpha1 experimental free-canvas geometry
# -----------------------------------------------------------------------------
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
                                        size_basis = c("plot", "facet", "axis", "axis_legend")) {
  layout <- figure_reindex_layout(layout)
  size_basis <- match.arg(size_basis)
  padding <- max(0, suppressWarnings(as.numeric(padding)[1]))
  if (!is.finite(padding)) padding <- 24
  rects <- list()
  idx <- 0L
  max_right <- padding
  max_bottom <- padding
  for (r in seq_along(layout)) {
    row_basis <- as.character(layout[[r]]$size_basis %||% "inherit")[1]
    eff_basis <- if (row_basis %in% c("plot", "facet", "axis", "axis_legend")) row_basis else size_basis
    for (c in seq_along(layout[[r]]$cells)) {
      cell <- layout[[r]]$cells[[c]]
      id <- as.character(cell$id %||% "")
      if (!nzchar(id)) next
      ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
      natural_basis <- if (identical(eff_basis, "axis")) "plot" else eff_basis
      if (identical(natural_basis, "axis_legend") && isTRUE(figure_legend_is_detached(ov))) natural_basis <- "axis"
      natural <- figure_natural_graph_size(
        cell, source_sizes[[id]] %||% list(), ov,
        basis = natural_basis
      )
      if (identical(eff_basis, "axis_legend")) natural$size_basis <- "axis_legend"
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
        label_anchor = as.character(cell$label_anchor %||% "plot_axis")[1],
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

figure_crop_css <- function(ov) {
  cr <- figure_crop_fractions(ov)
  if (!isTRUE(cr$enabled)) return(list(outer = "", inner = ""))
  # F1-2: Crop never rescales the source. Exact pixel offsets are supplied by
  # figure_crop_render_geometry(); this helper only keeps the clipping contract.
  list(outer = "overflow:hidden;", inner = "position:absolute;")
}



# F1-4h: basis-aware Fixed Canvas geometry.
#
# Fixed Canvas keeps the canvas and Row/column slot rectangles fixed, but it
# must not independently contain each Graph's complete visual bbox. Doing so
# makes a Graph with a right/left/top/bottom legend use a smaller data-panel
# scale than a legend-free Graph in the same Row.
#
# Build the Row's natural, basis-normalised footprints first (the same contract
# used by Auto Canvas), then apply one secondary fit factor to every occupied
# Graph in that Row so those footprints fit their fixed slots. The selected
# Plot/Facet/Axis basis therefore remains comparable across Graphs; outside
# decorations only consume/reserve footprint around that basis.
figure_fixed_basis_layout_geometry <- function(layout, source_sizes = list(), overrides = list(),
                                               canvas_w = 1600, canvas_h = 1000,
                                               gap_x = 12, gap_y = 12,
                                               size_basis = c("plot", "facet", "axis", "axis_legend"),
                                               title_align = c("none", "row_top")) {
  layout <- figure_reindex_layout(layout)
  size_basis <- match.arg(size_basis)
  title_align <- match.arg(title_align)
  fixed_rects <- figure_layout_rects(layout, canvas_w, canvas_h, gap_x, gap_y)
  if (!length(fixed_rects)) {
    return(list(rects=list(), rows=list(), content_width=canvas_w, content_height=canvas_h,
                canvas_width=canvas_w, canvas_height=canvas_h, outer_margin=0, fixed_basis_fit=TRUE))
  }

  # Auto geometry is used only as a side-effect-free normalizer: it converts
  # Plot/Facet/Axis basis, axis gutters, and side-legend reservations into one
  # natural footprint for every occupied slot. Fixed Canvas keeps its own slot
  # rectangles and only borrows these normalized dimensions.
  natural_geo <- figure_auto_layout_geometry(
    layout, source_sizes, overrides,
    gap_x = 0, gap_y = 0, outer_margin = 0, size_basis = size_basis,
    title_align = title_align
  )
  natural_by_key <- list()
  for (nr in natural_geo$rects %||% list()) {
    kk <- as.character(nr$key %||% "")[1]
    if (nzchar(kk)) natural_by_key[[kk]] <- nr
  }

  align_offset <- function(extra, mode, start = "left", end = "right") {
    extra <- max(0, suppressWarnings(as.numeric(extra)[1]))
    mode <- as.character(mode %||% "center")[1]
    if (identical(mode, start)) return(0)
    if (identical(mode, end)) return(extra)
    extra / 2
  }
  num <- function(x, fallback = NA_real_) {
    z <- suppressWarnings(as.numeric(x %||% fallback)[1])
    if (is.finite(z)) z else fallback
  }

  # Equal fixed slots with the same basis/Graph target form one sizing cohort,
  # even when they live in different Rows. This is the key F1-4h invariant:
  # a right-side legend may lower the common fit scale for that cohort, but it
  # cannot make only its own Plot/Facet/Axis basis smaller than its peers.
  rect_group <- list()
  fit_candidates <- list()
  for (ii in seq_along(fixed_rects)) {
    fr <- fixed_rects[[ii]]
    id <- as.character(fr$id %||% "")
    if (!nzchar(id)) next
    nr <- natural_by_key[[as.character(fr$key %||% "")]]
    if (!is.list(nr)) next
    cell <- layout[[fr$row]]$cells[[fr$col]]
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
    band <- max(0, figure_label_band(ov))
    nw <- num(nr$width, NA_real_)
    nh_graph <- num(nr$height, NA_real_) - band
    aw <- num(fr$width, NA_real_)
    ah <- num(fr$height, NA_real_) - band
    gw <- num(fr$graph_width, NA_real_)
    gh <- num(fr$graph_height, NA_real_)
    eff_basis <- as.character(nr$size_basis %||% size_basis)[1]
    gkey <- paste(
      eff_basis,
      round(aw, 4), round(ah, 4),
      if (is.finite(gw)) round(gw, 4) else "auto",
      if (is.finite(gh)) round(gh, 4) else "auto",
      sep = "|"
    )
    rect_group[[as.character(ii)]] <- gkey
    cc <- numeric(0)
    if (all(is.finite(c(nw, nh_graph, aw, ah))) && nw > 0 && nh_graph > 0 && aw > 0 && ah > 0) {
      cc <- c(aw / nw, ah / nh_graph)

      # F1-4i: when a fixed slot requests centered alignment, fit against the
      # selected size-basis center rather than only the asymmetric visual box.
      # This prevents a right legend from shifting the data panel/vertical axis
      # even though Plot/Facet/Axis basis sizes are already equal.  The extra
      # candidate also guarantees the whole decorated footprint still fits.
      nat_content_left <- num(nr$content_left, 0)
      nat_content_top <- num(nr$content_top, 0)
      bw <- num(nr$basis_width, NA_real_)
      bh <- num(nr$basis_height, NA_real_)
      bl <- nat_content_left + num(nr$basis_left, 0)
      bt <- nat_content_top + num(nr$basis_top, 0)
      if (identical(as.character(ov$align_h %||% "center")[1], "center") &&
          all(is.finite(c(bw, bl))) && bw > 0) {
        bc <- bl + bw / 2
        span <- 2 * max(bc, nw - bc)
        if (is.finite(span) && span > 0) cc <- c(cc, aw / span)
      }
      if (identical(as.character(ov$align_v %||% "center")[1], "center") &&
          all(is.finite(c(bh, bt))) && bh > 0) {
        bc <- bt + bh / 2
        span <- 2 * max(bc, nh_graph - bc)
        if (is.finite(span) && span > 0) cc <- c(cc, ah / span)
      }
    }
    fit_candidates[[gkey]] <- c(fit_candidates[[gkey]] %||% numeric(0), cc)
  }
  group_fits <- lapply(fit_candidates, function(v) {
    sc <- if (length(v)) min(v, na.rm=TRUE) else 1
    if (!is.finite(sc) || sc <= 0) sc <- 1
    # Natural geometry already honours an explicit Graph width/height. Fixed
    # Canvas may shrink it to fit, but does not silently enlarge Auto targets.
    min(max(sc, 0.05), 1)
  })

  for (ii in seq_along(fixed_rects)) {
    fr <- fixed_rects[[ii]]
    id <- as.character(fr$id %||% "")
    if (!nzchar(id)) next
    nr <- natural_by_key[[as.character(fr$key %||% "")]]
    gkey <- rect_group[[as.character(ii)]]
    if (!is.list(nr) || is.null(gkey)) next
    fit_scale <- num(group_fits[[gkey]], 1)
    cell <- layout[[fr$row]]$cells[[fr$col]]
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
    band <- max(0, figure_label_band(ov))
    src <- source_sizes[[id]] %||% list()
    nat_scale <- num(nr$basis_scale, 1)
    if (!is.finite(nat_scale) || nat_scale <= 0) nat_scale <- 1
    src_w <- num(src$width %||% src$plot_width_px, 600)
    src_h <- num(src$height %||% src$plot_height_px, 600)
    visual_w <- num(nr$content_width, src_w * nat_scale)
    visual_h <- num(nr$content_height, src_h * nat_scale)
    if (!is.finite(visual_w) || visual_w <= 0) visual_w <- max(1, num(nr$width, 1))
    if (!is.finite(visual_h) || visual_h <= 0) visual_h <- max(1, num(nr$height, 1) - band)

    footprint_w <- max(1, num(nr$width, visual_w) * fit_scale)
    footprint_h <- max(1, (num(nr$height, visual_h + band) - band) * fit_scale)
    usable_h <- max(1, num(fr$height, 1) - band)
    nat_content_left <- num(nr$content_left, 0)
    nat_content_top <- num(nr$content_top, 0)

    # Edge modes continue to keep the complete decorated footprint inside the
    # slot.  Center mode is basis-aware: center the Plot/Facet/Axis bbox itself,
    # not the full visual box.  The cohort fit above has already reserved enough
    # room for asymmetric axes/titles/outside legends, so this needs no clipping.
    if (identical(as.character(ov$align_h %||% "center")[1], "center")) {
      bw0 <- num(nr$basis_width, NA_real_)
      bc0 <- nat_content_left + num(nr$basis_left, 0) + bw0 / 2
      base_x <- if (is.finite(bc0) && is.finite(bw0) && bw0 > 0) {
        num(fr$width, footprint_w) / 2 - bc0 * fit_scale
      } else {
        align_offset(num(fr$width, footprint_w) - footprint_w, ov$align_h, "left", "right")
      }
    } else {
      base_x <- align_offset(num(fr$width, footprint_w) - footprint_w, ov$align_h, "left", "right")
    }
    if (identical(as.character(ov$align_v %||% "center")[1], "center")) {
      bh0 <- num(nr$basis_height, NA_real_)
      bc0 <- nat_content_top + num(nr$basis_top, 0) + bh0 / 2
      base_y <- if (is.finite(bc0) && is.finite(bh0) && bh0 > 0) {
        usable_h / 2 - bc0 * fit_scale
      } else {
        align_offset(usable_h - footprint_h, ov$align_v, "top", "bottom")
      }
    } else {
      base_y <- align_offset(usable_h - footprint_h, ov$align_v, "top", "bottom")
    }
    # Floating point / unusual gtable geometry safety only. The fit candidate
    # should make these no-ops in normal centered cases.
    base_x <- min(max(0, base_x), max(0, num(fr$width, footprint_w) - footprint_w))
    base_y <- min(max(0, base_y), max(0, usable_h - footprint_h))

    fr$basis_fit <- TRUE
    fr$size_basis <- as.character(nr$size_basis %||% size_basis)[1]
    fr$basis_scale <- nat_scale * fit_scale
    fr$basis_width <- num(nr$basis_width, NA_real_) * fit_scale
    fr$basis_height <- num(nr$basis_height, NA_real_) * fit_scale
    fr$basis_left <- num(nr$basis_left, NA_real_) * fit_scale
    fr$basis_top <- num(nr$basis_top, NA_real_) * fit_scale
    fr$content_left <- base_x + nat_content_left * fit_scale
    fr$content_top <- base_y + nat_content_top * fit_scale
    fr$content_width <- max(1, visual_w * fit_scale)
    fr$content_height <- max(1, visual_h * fit_scale)
    fr$fixed_basis_fit_scale <- fit_scale
    fr$fixed_basis_fit_group <- gkey
    for (nm in c("axis_common_left","axis_common_top","axis_common_right","axis_common_bottom",
                 "legend_common_left","legend_common_top","legend_common_right","legend_common_bottom")) {
      vv <- num(nr[[nm]], NA_real_)
      if (is.finite(vv)) fr[[nm]] <- vv * fit_scale
    }
    fixed_rects[[ii]] <- fr
  }

  list(
    rects = fixed_rects, rows = list(),
    content_width = as.numeric(canvas_w), content_height = as.numeric(canvas_h),
    canvas_width = as.numeric(canvas_w), canvas_height = as.numeric(canvas_h),
    outer_margin = 0, fixed_basis_fit = TRUE
  )
}


# v3.4.0-alpha2: when Auto-fit is Manual/Lock, freeze rectangle geometry but
# rebind current slot content so Swap/Shift/source replacement still appears.
figure_rebind_frozen_geometry <- function(geo, layout) {
  if (!is.list(geo) || !is.list(geo$rects)) return(geo)
  layout <- figure_reindex_layout(layout)
  cells <- list()
  for (row in layout) for (cell in row$cells %||% list()) {
    k <- as.character(cell$key %||% "")
    if (nzchar(k)) cells[[k]] <- cell
  }
  rebound <- list()
  for (r in geo$rects) {
    c <- cells[[as.character(r$key %||% "")]]
    # Deleted slots must disappear even while Manual/Lock geometry is frozen.
    if (is.null(c)) next
    r$id <- as.character(c$id %||% "")
    r$source_id <- as.character(c$source_id %||% c$id %||% "")
    r$source_type <- as.character(c$source_type %||% "internal_graph")
    r$graph_width <- suppressWarnings(as.numeric(c$graph_width %||% NA_real_)[1])
    r$graph_height <- suppressWarnings(as.numeric(c$graph_height %||% NA_real_)[1])
    lab <- figure_slot_label_payload(c)
    for (nm in setdiff(names(lab), "panel_label_auto")) r[[nm]] <- lab[[nm]]
    rebound[[length(rebound) + 1L]] <- r
  }
  geo$rects <- rebound
  geo
}
