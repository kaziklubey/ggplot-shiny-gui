# figure_layout_fixed.R — Fixed Canvas layout policy and frozen geometry rebinding
# v3.80.6-refactor1: Fixed layout is orchestration plus focused fit helpers.

figure_fixed_num <- function(x, fallback = NA_real_) {
  z <- suppressWarnings(as.numeric(x %||% fallback)[1])
  if (is.finite(z)) z else fallback
}

figure_fixed_align_offset <- function(extra, mode, start = "left", end = "right") {
  extra <- max(0, suppressWarnings(as.numeric(extra)[1]))
  mode <- as.character(mode %||% "center")[1]
  if (identical(mode, start)) return(0)
  if (identical(mode, end)) return(extra)
  extra / 2
}

figure_fixed_natural_by_key <- function(natural_geo) {
  out <- list()
  for (nr in natural_geo$rects %||% list()) {
    kk <- as.character(nr$key %||% "")[1]
    if (nzchar(kk)) out[[kk]] <- nr
  }
  out
}

figure_fixed_fit_plan <- function(fixed_rects, natural_by_key, layout, overrides = list(), size_basis = "panel_legend") {
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
    nw <- figure_fixed_num(nr$width, NA_real_)
    nh_graph <- figure_fixed_num(nr$height, NA_real_) - band
    aw <- figure_fixed_num(fr$width, NA_real_)
    ah <- figure_fixed_num(fr$height, NA_real_) - band
    gw <- figure_fixed_num(fr$graph_width, NA_real_)
    gh <- figure_fixed_num(fr$graph_height, NA_real_)
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
      nat_content_left <- figure_fixed_num(nr$content_left, 0)
      nat_content_top <- figure_fixed_num(nr$content_top, 0)
      bw <- figure_fixed_num(nr$basis_width, NA_real_)
      bh <- figure_fixed_num(nr$basis_height, NA_real_)
      bl <- nat_content_left + figure_fixed_num(nr$basis_left, 0)
      bt <- nat_content_top + figure_fixed_num(nr$basis_top, 0)

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
    min(max(sc, 0.05), 1)
  })

  list(rect_group = rect_group, group_fits = group_fits)
}

figure_fixed_fit_rect <- function(fr, nr, gkey, fit_scale, layout, source_sizes, overrides, size_basis, alignment_targets = list()) {
  id <- as.character(fr$id %||% "")
  if (!nzchar(id) || !is.list(nr) || is.null(gkey)) return(fr)

  cell <- layout[[fr$row]]$cells[[fr$col]]
  ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)
  band <- max(0, figure_label_band(ov))
  src <- source_sizes[[id]] %||% list()
  nat_scale <- figure_fixed_num(nr$basis_scale, 1)
  if (!is.finite(nat_scale) || nat_scale <= 0) nat_scale <- 1
  src_w <- figure_fixed_num(src$width %||% src$plot_width_px, 600)
  src_h <- figure_fixed_num(src$height %||% src$plot_height_px, 600)
  visual_w <- figure_fixed_num(nr$content_width, src_w * nat_scale)
  visual_h <- figure_fixed_num(nr$content_height, src_h * nat_scale)
  if (!is.finite(visual_w) || visual_w <= 0) visual_w <- max(1, figure_fixed_num(nr$width, 1))
  if (!is.finite(visual_h) || visual_h <= 0) visual_h <- max(1, figure_fixed_num(nr$height, 1) - band)

  footprint_w <- max(1, figure_fixed_num(nr$width, visual_w) * fit_scale)
  footprint_h <- max(1, (figure_fixed_num(nr$height, visual_h + band) - band) * fit_scale)
  usable_h <- max(1, figure_fixed_num(fr$height, 1) - band)
  nat_content_left <- figure_fixed_num(nr$content_left, 0)
  nat_content_top <- figure_fixed_num(nr$content_top, 0)

  if (identical(as.character(ov$align_h %||% "center")[1], "center")) {
    shared_left <- figure_fixed_num((alignment_targets$column_left %||% list())[[as.character(fr$col)]], NA_real_)
    anchor_left <- nat_content_left + figure_fixed_num(nr$basis_left, NA_real_)
    if (is.finite(shared_left) && is.finite(anchor_left)) {
      base_x <- shared_left - anchor_left * fit_scale
    } else {
      bw0 <- figure_fixed_num(nr$basis_width, NA_real_)
      bc0 <- nat_content_left + figure_fixed_num(nr$basis_left, 0) + bw0 / 2
      base_x <- if (is.finite(bc0) && is.finite(bw0) && bw0 > 0) {
        figure_fixed_num(fr$width, footprint_w) / 2 - bc0 * fit_scale
      } else {
        figure_fixed_align_offset(figure_fixed_num(fr$width, footprint_w) - footprint_w, ov$align_h, "left", "right")
      }
    }
  } else {
    base_x <- figure_fixed_align_offset(figure_fixed_num(fr$width, footprint_w) - footprint_w, ov$align_h, "left", "right")
  }

  if (identical(as.character(ov$align_v %||% "center")[1], "center")) {
    shared_bottom <- figure_fixed_num((alignment_targets$row_bottom %||% list())[[as.character(fr$row)]], NA_real_)
    anchor_bottom_body <- nat_content_top + figure_fixed_num(nr$basis_top, NA_real_) + figure_fixed_num(nr$basis_height, NA_real_)
    if (is.finite(shared_bottom) && is.finite(anchor_bottom_body)) {
      base_y <- shared_bottom - band - anchor_bottom_body * fit_scale
    } else {
      bh0 <- figure_fixed_num(nr$basis_height, NA_real_)
      bc0 <- nat_content_top + figure_fixed_num(nr$basis_top, 0) + bh0 / 2
      base_y <- if (is.finite(bc0) && is.finite(bh0) && bh0 > 0) {
        usable_h / 2 - bc0 * fit_scale
      } else {
        figure_fixed_align_offset(usable_h - footprint_h, ov$align_v, "top", "bottom")
      }
    }
  } else {
    base_y <- figure_fixed_align_offset(usable_h - footprint_h, ov$align_v, "top", "bottom")
  }

  base_x <- min(max(0, base_x), max(0, figure_fixed_num(fr$width, footprint_w) - footprint_w))
  base_y <- min(max(0, base_y), max(0, usable_h - footprint_h))

  fr$basis_fit <- TRUE
  fr$size_basis <- as.character(nr$size_basis %||% size_basis)[1]
  fr$basis_scale <- nat_scale * fit_scale
  fr$basis_width <- figure_fixed_num(nr$basis_width, NA_real_) * fit_scale
  fr$basis_height <- figure_fixed_num(nr$basis_height, NA_real_) * fit_scale
  fr$basis_left <- figure_fixed_num(nr$basis_left, NA_real_) * fit_scale
  fr$basis_top <- figure_fixed_num(nr$basis_top, NA_real_) * fit_scale
  fr$content_left <- base_x + nat_content_left * fit_scale
  fr$content_top <- base_y + nat_content_top * fit_scale
  fr$content_width <- max(1, visual_w * fit_scale)
  fr$content_height <- max(1, visual_h * fit_scale)
  fr$fixed_basis_fit_scale <- fit_scale
  fr$fixed_basis_fit_group <- gkey
  for (nm in c("panel_common_left","panel_common_top","panel_common_right","panel_common_bottom",
               "axis_common_left","axis_common_top","axis_common_right","axis_common_bottom",
               "legend_common_left","legend_common_top","legend_common_right","legend_common_bottom")) {
    vv <- figure_fixed_num(nr[[nm]], NA_real_)
    if (is.finite(vv)) fr[[nm]] <- vv * fit_scale
  }
  fr
}

figure_fixed_basis_layout_geometry <- function(layout, source_sizes = list(), overrides = list(),
                                               canvas_w = 1600, canvas_h = 1000,
                                               gap_x = 12, gap_y = 12,
                                               size_basis = "panel_legend",
                                               title_align = c("none", "row_top")) {
  layout <- figure_reindex_layout(layout)
  size_basis <- figure_normalize_alignment_basis(size_basis)
  title_align <- match.arg(title_align)
  fixed_rects <- figure_layout_rects(layout, canvas_w, canvas_h, gap_x, gap_y)
  if (!length(fixed_rects)) {
    return(list(rects=list(), rows=list(), content_width=canvas_w, content_height=canvas_h,
                canvas_width=canvas_w, canvas_height=canvas_h, outer_margin=0, fixed_basis_fit=TRUE))
  }

  natural_geo <- figure_auto_layout_geometry(
    layout, source_sizes, overrides,
    gap_x = 0, gap_y = 0, outer_margin = 0, size_basis = size_basis,
    title_align = title_align
  )
  natural_by_key <- figure_fixed_natural_by_key(natural_geo)
  fit_plan <- figure_fixed_fit_plan(fixed_rects, natural_by_key, layout, overrides, size_basis)
  alignment_targets <- figure_fixed_alignment_targets(fixed_rects, natural_by_key, fit_plan, layout, overrides)

  for (ii in seq_along(fixed_rects)) {
    fr <- fixed_rects[[ii]]
    id <- as.character(fr$id %||% "")
    if (!nzchar(id)) next
    nr <- natural_by_key[[as.character(fr$key %||% "")]]
    gkey <- fit_plan$rect_group[[as.character(ii)]]
    if (!is.list(nr) || is.null(gkey)) next
    fit_scale <- figure_fixed_num(fit_plan$group_fits[[gkey]], 1)
    fixed_rects[[ii]] <- figure_fixed_fit_rect(
      fr, nr, gkey, fit_scale, layout, source_sizes, overrides, size_basis,
      alignment_targets = alignment_targets
    )
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
