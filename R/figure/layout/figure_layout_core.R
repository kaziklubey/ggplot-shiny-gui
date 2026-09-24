# R/figure/layout/figure_layout_core.R — Figure geometry primitives and measurements
# v3.80.6-refactor1: split from figure_layout.R without changing state ownership.

figure_layout_rects <- function(layout, canvas_w, canvas_h, gap_x = 12, gap_y = 12) {
  # Public Figure geometry entry point. Fixed/seed/export callers all use the
  # same Figure-wide track allocator; there is no per-Row column fallback.
  figure_shared_track_rects(figure_reindex_layout(layout), canvas_w, canvas_h, gap_x, gap_y)
}


# Content-driven Figure geometry. Fixed Canvas delegates slot allocation to the
# Figure-wide track module above; Auto-fit treats each occupied Panel as a
# natural-size wrapper around its Graph asset. Empty Panels do not contribute
# to the Auto content bounding box.
figure_auto_outer_margin <- function() 0

figure_graph_scale_bbox <- function(source_size = list()) {
  bbox_valid <- function(x) {
    if (!is.list(x)) return(NULL)
    v <- suppressWarnings(as.numeric(c(x$left, x$top, x$width, x$height)))
    if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
    list(left=v[1], top=v[2], width=v[3], height=v[4], right=v[1]+v[3], bottom=v[2]+v[4])
  }

  # Graph scale has one owner: the data panel. Alignment basis is handled later
  # by R/figure/layout/figure_layout_alignment_plan.R and must never silently rescale the Graph.
  zz <- bbox_valid(source_size$panel_bbox)
  if (!is.null(zz)) return(zz)

  # Backward-compatible cache/project fallback when detailed bbox metadata is
  # unavailable. Aggregate panel dimensions are the safest common scale basis.
  pw <- suppressWarnings(as.numeric(source_size$panel_width %||% source_size$panel_width_px %||% 600)[1])
  ph <- suppressWarnings(as.numeric(source_size$panel_height %||% source_size$panel_height_px %||% 600)[1])
  if (!is.finite(pw) || pw <= 0) pw <- 600
  if (!is.finite(ph) || ph <= 0) ph <- 600
  list(left=0, top=0, width=pw, height=ph, right=pw, bottom=ph)
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

figure_natural_graph_size <- function(cell, source_size = NULL, ov = list(), basis = "panel_legend") {
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

  basis <- figure_normalize_alignment_basis(basis)
  scale_box <- figure_graph_scale_bbox(source_size %||% list())
  basis_w <- suppressWarnings(as.numeric(scale_box$width %||% pw)[1])
  basis_h <- suppressWarnings(as.numeric(scale_box$height %||% ph)[1])
  if (!is.finite(basis_w) || basis_w <= 0) basis_w <- pw
  if (!is.finite(basis_h) || basis_h <= 0) basis_h <- ph

  gw <- suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)[1])
  gh <- suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)[1])
  has_w <- is.finite(gw) && gw > 0
  has_h <- is.finite(gh) && gh > 0

  # Auto uses the Graph-side Plot横幅/縦幅 as the default target. Graph scale
  # always follows the data-panel bbox; the selected alignment basis changes
  # only the anchor/reservations used by layout. An included outer legend may
  # enlarge the allocated footprint, but it never changes Graph scale.
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
    basis_left = suppressWarnings(as.numeric(scale_box$left %||% 0)[1]) * sc,
    basis_top = suppressWarnings(as.numeric(scale_box$top %||% 0)[1]) * sc
  )
}

# v3.73.2.51: Auto Figure rows share one horizontal column-track model.
# A wide attached legend (or any other horizontal decoration) in a lower Row
# may enlarge its own column, but it must not move the start of the next column
# relative to Rows above it.  Keep each Graph's natural content placement and
# absorb the difference as empty space at the right edge of the narrower cell.
# This is deliberately a layout-only pass: Graph/Figure snapshot ownership and
# source geometry remain unchanged.
