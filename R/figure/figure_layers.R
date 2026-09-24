# R/figure/figure_layers.R — Figure layer ownership / coordinate-space contract
# v3.4.0 F1-4: separate Graph body, legend, label and interaction responsibilities.
#
# Layer model
#   graph   : Graph/Asset visual. Crop applies here only.
#   inset   : Figure-owned free inset visual, anchored to its owner Graph.
#   legend  : Figure-owned free legend visual, anchored to its owner Graph.
#   label   : Figure-owned panel label visual.
#   ui      : selection / drag affordances.
#
# Important: detached legends are NOT re-laid out by ggplot after entering the
# Figure Legend layer. A stable source-side plot is used only to extract the
# guide-box asset; owner Graph sizing is measured from a legend-free body. The
# overlay then follows the owner Graph display frame without reserving a slot.

figure_layer_z <- function(name) {
  z <- c(graph = 10L, inset = 20L, legend = 30L, label = 40L, ui = 100L)
  out <- unname(z[[as.character(name %||% "graph")[1]]])
  if (is.null(out) || !is.finite(out)) 10L else as.integer(out)
}

figure_legend_layer_scope <- function(ov) {
  mode <- as.character((ov %||% list())$legend %||% "inherit")[1]
  # F1-4g: there is only one detached placement contract. Legacy alpha
  # `inside`/`panel` states are treated as free until normalization migrates them.
  if (mode %in% c("free", "inside", "panel")) return("figure")
  "graph"
}

figure_legend_is_detached <- function(ov) {
  identical(figure_legend_layer_scope(ov), "figure")
}

figure_legend_source_origin <- function(ov) {
  ov <- ov %||% list()
  # Extraction ownership and placement ownership are independent. Once a legend
  # enters the single free mode, the source origin is frozen until the user
  # explicitly selects a normal side mode.
  stable <- as.character(ov$legend_source_origin %||% "inherit")[1]
  if (stable %in% c("right", "left", "top", "bottom", "inside")) return(stable)

  mode <- as.character(ov$legend %||% "inherit")[1]
  if (mode %in% c("right", "left", "top", "bottom", "inside")) return(mode)

  candidates <- c(
    as.character(ov$legend_last_side %||% "")[1],
    as.character(ov$legend_free_origin %||% "")[1]
  )
  candidates <- candidates[candidates %in% c("right", "left", "top", "bottom", "inside")]
  if (length(candidates)) return(candidates[[1]])
  "inherit"
}

# Return an override suitable for rendering/measuring the Graph source asset.
# Detached legend placement is a Figure concern; never convert it to ggplot
# inside-legend geometry. If a side anchor is known, retain that source side.
figure_layer_source_override <- function(ov) {
  z <- ov %||% list()
  if (figure_legend_is_detached(z)) {
    origin <- figure_legend_source_origin(z)
    z$legend <- origin
    if (identical(origin, "inside")) {
      # The source inside legend is a stable extraction anchor. Detached overlay
      # x/y edits must not move this source grob behind the scenes.
      z$legend_x <- suppressWarnings(as.numeric(z$legend_source_x %||% z$legend_x %||% 0.72)[1])
      z$legend_y <- suppressWarnings(as.numeric(z$legend_source_y %||% z$legend_y %||% 0.08)[1])
    }
  }
  z
}

figure_layer_valid_bbox <- function(z) {
  if (!is.list(z)) return(NULL)
  v <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
  if (length(v) != 4L || any(!is.finite(v)) || v[[3]] <= 0 || v[[4]] <= 0) return(NULL)
  list(left=v[[1]], top=v[[2]], width=v[[3]], height=v[[4]], right=v[[1]]+v[[3]], bottom=v[[2]]+v[[4]])
}

# Map a source-legend bbox into the legend-free Graph-body coordinate system by
# aligning the data-panel origins. This preserves the source-side placement for
# the initial detach without reserving the source legend's blank layout space.
figure_layer_map_bbox_to_body <- function(anchor_meta, body_meta, bbox) {
  z <- figure_layer_valid_bbox(bbox)
  if (is.null(z) || !is.list(anchor_meta) || !is.list(body_meta)) return(NULL)
  num <- function(x, fallback = 0) {
    v <- suppressWarnings(as.numeric(x %||% fallback)[1])
    if (!is.finite(v)) fallback else v
  }
  dx <- num(body_meta$panel_left, 0) - num(anchor_meta$panel_left, 0)
  dy <- num(body_meta$panel_top, 0) - num(anchor_meta$panel_top, 0)
  list(left=z$left + dx, top=z$top + dy, width=z$width, height=z$height)
}

# Resolve the owner-Graph geometry from a persisted Figure preview. When a
# detached/free legend has a saved legend-free body, use that body for the
# owner's footprint even while Figure gtable measurement is deferred. Retain
# the source legend bboxes only as mapped overlay anchors.
figure_layer_persisted_owner_meta <- function(preview, ov = list()) {
  if (!is.list(preview)) return(NULL)
  anchor <- preview$meta %||% list()
  if (!figure_legend_is_detached(ov) || !is.list(preview$body_meta)) return(anchor)

  body <- preview$body_meta
  out <- body
  for (nm in c("legend_bbox", "legend_visual_bbox", "legend_outside_bbox", "legend_outside_visual_bbox")) {
    src <- anchor[[nm]]
    if (is.null(src) && identical(nm, "legend_visual_bbox")) src <- anchor$legend_bbox
    if (is.null(src) && identical(nm, "legend_outside_visual_bbox")) src <- anchor$legend_outside_bbox
    out[[nm]] <- figure_layer_map_bbox_to_body(anchor, body, src)
  }
  out$legend_state <- anchor$legend_state %||% "unknown"
  out$geometry_source <- paste0(as.character(anchor$geometry_source %||% "persisted")[1], "+detached-body")
  out$reference_res <- anchor$reference_res %||% body$reference_res
  out
}

figure_layer_scale_bbox <- function(bbox, scale = 1) {
  z <- figure_layer_valid_bbox(bbox)
  sc <- suppressWarnings(as.numeric(scale %||% 1)[1])
  if (is.null(z) || !is.finite(sc) || sc <= 0) return(NULL)
  list(left=z$left*sc, top=z$top*sc, width=z$width*sc, height=z$height*sc)
}

# Crop-independent owner Graph display frame, local to the Row/Free-layout cell.
# Free legends persist their position relative to this frame; Graph resizing
# therefore moves the legend proportionally, while Crop never shifts it.
figure_graph_display_frame <- function(rect, sp, ov) {
  off <- figure_plot_offsets(rect, sp, ov)
  ww <- suppressWarnings(as.numeric((sp %||% list())$width %||% 1)[1])
  hh <- suppressWarnings(as.numeric((sp %||% list())$height %||% 1)[1])
  if (!is.finite(ww) || ww <= 0) ww <- 1
  if (!is.finite(hh) || hh <= 0) hh <- 1
  list(x=off$dx, y=off$dy, width=ww, height=hh)
}

# F1-5 Inset placement uses the exact same owner Graph frame as detached
# legends. The overlay lives on the Figure canvas, so it is not clipped by the
# Panel and Crop never changes its anchor. Width/height are owner-relative.
figure_layer_inset_local_position <- function(rect, sp, ov) {
  inset <- (ov %||% list())$inset %||% figure_default_inset()
  if (!isTRUE(inset$enabled) || !nzchar(as.character(inset$source_id %||% "")[1])) return(NULL)
  frame <- figure_graph_display_frame(rect, sp, ov)
  num <- function(x, fallback) {
    z <- suppressWarnings(as.numeric(x %||% fallback)[1])
    if (!is.finite(z)) fallback else z
  }
  x <- min(max(num(inset$x, 0.62), -2), 3)
  y <- min(max(num(inset$y, 0.08), -2), 3)
  w <- min(max(num(inset$width, 0.32), 0.05), 1.5)
  h <- min(max(num(inset$height, 0.32), 0.05), 1.5)
  list(
    x = frame$x + frame$width * x,
    y = frame$y + frame$height * y,
    width = max(1, frame$width * w),
    height = max(1, frame$height * h),
    rel_x = x, rel_y = y, rel_width = w, rel_height = h,
    owner_frame = frame
  )
}

figure_layer_inset_canvas_position <- function(rect, sp, ov) {
  z <- figure_layer_inset_local_position(rect, sp, ov)
  if (is.null(z)) return(NULL)
  z$x <- suppressWarnings(as.numeric(rect$x %||% 0)[1]) + z$x
  z$y <- suppressWarnings(as.numeric(rect$y %||% 0)[1]) + z$y
  z
}


# Source position comes from the measured guide-box geometry, while the visual
# dimensions may come from a standalone guide-box SVG asset.  Keeping those two
# concerns separate prevents legend title/label glyphs from being cropped by a
# bbox that was inferred from the full plot SVG.
figure_layer_legend_bbox <- function(sp) {
  z <- figure_layer_valid_bbox((sp %||% list())$legend_visual_bbox %||% (sp %||% list())$legend_bbox)
  if (is.null(z)) return(NULL)
  ww <- suppressWarnings(as.numeric((sp %||% list())$legend_layer_width %||% NA_real_)[1])
  hh <- suppressWarnings(as.numeric((sp %||% list())$legend_layer_height %||% NA_real_)[1])
  if (is.finite(ww) && ww > 0) z$width <- ww
  if (is.finite(hh) && hh > 0) z$height <- hh
  z$right <- z$left + z$width
  z$bottom <- z$top + z$height
  z
}

figure_layer_legend_side <- function(sp, ov) {
  origin <- figure_legend_source_origin(ov)
  if (origin %in% c("right", "left", "top", "bottom", "inside")) return(origin)
  leg <- figure_layer_legend_bbox(sp)
  axis <- figure_layer_valid_bbox(sp$axis_outer_bbox)
  if (is.null(leg) || is.null(axis)) return(NA_character_)
  eps <- 1
  if (leg$left >= axis$right - eps) return("right")
  if (leg$right <= axis$left + eps) return("left")
  if (leg$top >= axis$bottom - eps) return("bottom")
  if (leg$bottom <= axis$top + eps) return("top")
  # A guide box overlapping the axis/content envelope is a Plot-inside source.
  if (leg$right > axis$left && leg$left < axis$right && leg$bottom > axis$top && leg$top < axis$bottom) return("inside")
  NA_character_
}

# Local top-left for the single detached/free legend mode.  The persisted X/Y
# are relative to the owner Graph display frame, not the Plot panel or Row slot.
# Values may exceed 0..1 so a legend can sit anywhere on the Figure canvas.
figure_layer_legend_local_position <- function(rect, sp, ov) {
  leg <- figure_layer_legend_bbox(sp)
  if (is.null(leg)) return(NULL)
  frame <- figure_graph_display_frame(rect, sp, ov)
  if (isTRUE(ov$legend_free_auto)) {
    return(list(x=frame$x + leg$left, y=frame$y + leg$top, width=leg$width, height=leg$height))
  }
  rx <- suppressWarnings(as.numeric(ov$legend_free_x %||% ov$legend_x %||% 0.75)[1])
  ry <- suppressWarnings(as.numeric(ov$legend_free_y %||% ov$legend_y %||% 0.08)[1])
  if (!is.finite(rx)) rx <- 0.75
  if (!is.finite(ry)) ry <- 0.08
  list(
    x=frame$x + frame$width * rx,
    y=frame$y + frame$height * ry,
    width=leg$width, height=leg$height
  )
}

figure_layer_legend_canvas_position <- function(rect, sp, ov) {
  p <- figure_layer_legend_local_position(rect, sp, ov)
  if (is.null(p)) return(NULL)
  p$x <- rect$x + p$x
  p$y <- rect$y + p$y
  p
}
