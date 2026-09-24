# R/figure/layout/figure_layout_alignment_plan.R — Auto/Fixed alignment plan from rendered bboxes
# v3.80.7: one explicit contract controls the alignment anchor (panel vs
# panel+axis) and whether an attached outer legend participates in the shared
# trailing reservation. Physical visual extents are tracked independently so
# excluding a legend from alignment never silently removes its drawing space.

figure_alignment_bbox <- function(x, scale = 1) {
  if (!is.list(x)) return(NULL)
  v <- suppressWarnings(as.numeric(c(x$left, x$top, x$width, x$height)))
  if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
  list(left = v[1] * scale, top = v[2] * scale,
       right = (v[1] + v[3]) * scale, bottom = (v[2] + v[4]) * scale,
       width = v[3] * scale, height = v[4] * scale)
}

figure_alignment_union_extent <- function(boxes) {
  boxes <- Filter(Negate(is.null), boxes)
  if (!length(boxes)) return(NULL)
  list(
    left = min(0, vapply(boxes, `[[`, numeric(1), "left")),
    top = min(0, vapply(boxes, `[[`, numeric(1), "top")),
    right = max(vapply(boxes, `[[`, numeric(1), "right")),
    bottom = max(vapply(boxes, `[[`, numeric(1), "bottom"))
  )
}

figure_alignment_visual_bbox <- function(source_size, scale = 1) {
  w <- suppressWarnings(as.numeric(source_size$width %||% source_size$plot_width_px %||% NA_real_)[1])
  h <- suppressWarnings(as.numeric(source_size$height %||% source_size$plot_height_px %||% NA_real_)[1])
  if (!is.finite(w) || w <= 0 || !is.finite(h) || h <= 0) return(NULL)
  list(left = 0, top = 0, right = w * scale, bottom = h * scale,
       width = w * scale, height = h * scale)
}

figure_alignment_outer_legend_bbox <- function(source_size, scale = 1) {
  # Prefer the true outside guide-box contract. An explicitly present but empty
  # outside bbox means the legend is not outside (for example an inside legend),
  # so do not fall back to legend_bbox in that case. Old saved metadata that has
  # no outside field at all may only carry legend_bbox and is migrated safely.
  if (!is.null(source_size$legend_outside_bbox)) {
    return(figure_alignment_bbox(source_size$legend_outside_bbox, scale))
  }
  figure_alignment_bbox(source_size$legend_bbox, scale)
}

figure_alignment_reservations <- function(source_size, scale, basis = "panel_legend", detached_legend = FALSE) {
  basis <- figure_normalize_alignment_basis(basis)
  panel <- figure_alignment_bbox(source_size$panel_bbox, scale)
  if (is.null(panel)) {
    panel <- figure_alignment_bbox(list(
      left = source_size$panel_left %||% 0,
      top = source_size$panel_top %||% 0,
      width = source_size$panel_width %||% source_size$panel_width_px %||% 600,
      height = source_size$panel_height %||% source_size$panel_height_px %||% 600
    ), scale)
  }
  if (is.null(panel)) return(NULL)

  axis <- figure_alignment_bbox(source_size$axis_outer_bbox, scale)
  text <- figure_alignment_bbox(source_size$content_outer_bbox, scale)
  title <- figure_alignment_bbox(source_size$title_bbox, scale)
  physical_legend <- if (isTRUE(detached_legend)) NULL else figure_alignment_outer_legend_bbox(source_size, scale)
  shared_legend <- if (figure_alignment_includes_outer_legend(basis)) physical_legend else NULL
  visual_box <- figure_alignment_visual_bbox(source_size, scale)

  anchor_kind <- figure_alignment_anchor_kind(basis)
  anchor <- if (identical(anchor_kind, "axis") && !is.null(axis)) axis else panel

  # Shared extent determines the common gutters around the selected anchor.
  # Axis/title/caption are always reservations; outer legend participation is
  # the orthogonal include/exclude part of the public contract.
  shared_extent <- figure_alignment_union_extent(list(panel, axis, text, title, shared_legend))
  if (is.null(shared_extent)) shared_extent <- list(left=panel$left, top=panel$top, right=panel$right, bottom=panel$bottom)

  # Physical extent is never an alignment policy: it is simply the drawing
  # footprint that must remain inside the owning slot. This preserves the old
  # panel_auto behaviour for the recommended *+legend modes while making the
  # legend-excluded modes safe from silent clipping/overlap on the trailing side.
  visual_extent <- figure_alignment_union_extent(list(panel, axis, text, title, physical_legend, visual_box))
  if (is.null(visual_extent)) visual_extent <- shared_extent

  # For include-legend modes the shared contract should be at least the full
  # rendered visual bbox. This keeps panel_legend backward-compatible with the
  # v3.80.6 panel_auto geometry even when older metadata lacks detailed bboxes.
  if (figure_alignment_includes_outer_legend(basis) && !is.null(visual_box)) {
    shared_extent <- figure_alignment_union_extent(list(shared_extent, visual_box))
  }

  list(
    basis = basis,
    anchor_kind = anchor_kind,
    anchor = anchor,
    panel = panel,
    axis = axis,
    legend = shared_legend,
    physical_legend = physical_legend,
    title_caption = text %||% title,
    extent = shared_extent,
    visual_extent = visual_extent
  )
}

figure_auto_alignment_plan <- function(sizes) {
  measured <- Filter(function(z) is.list(z) && is.list(z$alignment_measure), sizes)
  if (!length(measured)) return(NULL)

  # Decorations before the anchor (left/top) always need physical reservation;
  # otherwise an excluded left/top legend would force a negative content offset
  # and break the anchor alignment. Trailing reservations follow the selected
  # alignment contract and any excluded trailing visual is kept local per cell.
  left <- max(vapply(measured, function(z) {
    m <- z$alignment_measure
    m$anchor$left - m$visual_extent$left
  }, numeric(1)))
  bottom <- max(vapply(measured, function(z) {
    m <- z$alignment_measure
    z$band + m$anchor$bottom - m$visual_extent$top
  }, numeric(1)))
  right <- max(vapply(measured, function(z) {
    m <- z$alignment_measure
    m$extent$right - m$anchor$right
  }, numeric(1)))
  below <- max(vapply(measured, function(z) {
    m <- z$alignment_measure
    m$extent$bottom - m$anchor$bottom
  }, numeric(1)))
  list(left = left, bottom = bottom, right = right, below = below)
}

figure_auto_apply_alignment_plan <- function(sizes, plan) {
  if (is.null(plan)) return(sizes)
  lapply(sizes, function(z) {
    if (!is.list(z) || !is.list(z$alignment_measure)) return(z)
    m <- z$alignment_measure
    a <- m$anchor
    v <- m$visual_extent %||% m$extent
    z$content_left <- plan$left - a$left
    z$content_top <- plan$bottom - z$band - a$bottom
    z$content_width <- z$visual_width
    z$content_height <- z$visual_height

    shared_width <- plan$left + a$width + plan$right
    shared_height <- plan$bottom + plan$below
    physical_right <- z$content_left + v$right
    physical_bottom <- z$band + z$content_top + v$bottom
    z$width <- max(shared_width, physical_right, 1)
    z$height <- max(shared_height, physical_bottom, 1)

    z$basis_width <- a$width
    z$basis_height <- a$height
    z$basis_left <- a$left
    z$basis_top <- a$top
    z$alignment_anchor_kind <- m$anchor_kind
    z$alignment_common_left <- plan$left
    z$alignment_common_top <- plan$bottom - a$height
    z$alignment_common_right <- plan$right
    z$alignment_common_bottom <- plan$below

    # Preserve named diagnostics for existing consumers without maintaining a
    # second geometry path. They now describe the selected alignment anchor.
    if (identical(m$anchor_kind, "axis")) {
      z$axis_common_left <- plan$left
      z$axis_common_top <- plan$bottom - a$height
      z$axis_common_right <- plan$right
      z$axis_common_bottom <- plan$below
    } else {
      z$panel_common_left <- plan$left
      z$panel_common_top <- plan$bottom - a$height
      z$panel_common_right <- plan$right
      z$panel_common_bottom <- plan$below
    }
    z
  })
}
