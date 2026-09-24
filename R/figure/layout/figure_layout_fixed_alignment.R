# R/figure/layout/figure_layout_fixed_alignment.R — shared-anchor placement inside Fixed tracks
# v3.80.7: Fixed Canvas keeps per-Graph fit scales, then uses the spare space in
# each shared track to align the selected rendered anchor (panel or panel+axis).

figure_fixed_alignment_num <- function(x, fallback = NA_real_) {
  z <- suppressWarnings(as.numeric(x %||% fallback)[1])
  if (is.finite(z)) z else fallback
}

figure_fixed_alignment_interval <- function(fr, nr, fit_scale, ov, axis = c("x", "y")) {
  axis <- match.arg(axis)
  sc <- figure_fixed_alignment_num(fit_scale, 1)
  if (!is.finite(sc) || sc <= 0) sc <- 1
  band <- max(0, figure_label_band(ov))

  if (identical(axis, "x")) {
    avail <- figure_fixed_alignment_num(fr$width, NA_real_)
    footprint <- figure_fixed_alignment_num(nr$width, NA_real_) * sc
    anchor <- (figure_fixed_alignment_num(nr$content_left, 0) +
               figure_fixed_alignment_num(nr$basis_left, NA_real_)) * sc
    if (any(!is.finite(c(avail, footprint, anchor))) || avail <= 0 || footprint <= 0) return(NULL)
    spare <- max(0, avail - footprint)
    return(c(lower = anchor, upper = anchor + spare))
  }

  avail <- figure_fixed_alignment_num(fr$height, NA_real_) - band
  footprint <- (figure_fixed_alignment_num(nr$height, NA_real_) - band) * sc
  anchor_body <- (figure_fixed_alignment_num(nr$content_top, 0) +
                  figure_fixed_alignment_num(nr$basis_top, NA_real_) +
                  figure_fixed_alignment_num(nr$basis_height, NA_real_)) * sc
  if (any(!is.finite(c(avail, footprint, anchor_body))) || avail <= 0 || footprint <= 0) return(NULL)
  spare <- max(0, avail - footprint)
  lower <- band + anchor_body
  c(lower = lower, upper = lower + spare)
}

figure_fixed_common_target <- function(intervals, tolerance = 1e-7) {
  intervals <- Filter(function(z) is.numeric(z) && length(z) == 2L && all(is.finite(z)), intervals)
  if (!length(intervals)) return(NA_real_)
  lower <- max(vapply(intervals, `[[`, numeric(1), "lower"))
  upper <- min(vapply(intervals, `[[`, numeric(1), "upper"))
  if (lower > upper + tolerance) return(NA_real_)
  lower
}

figure_fixed_alignment_targets <- function(fixed_rects, natural_by_key, fit_plan, layout, overrides = list()) {
  col_intervals <- list(); row_intervals <- list()
  for (ii in seq_along(fixed_rects)) {
    fr <- fixed_rects[[ii]]
    id <- as.character(fr$id %||% "")
    if (!nzchar(id)) next
    nr <- natural_by_key[[as.character(fr$key %||% "")]]
    gkey <- fit_plan$rect_group[[as.character(ii)]]
    if (!is.list(nr) || is.null(gkey)) next
    sc <- figure_fixed_alignment_num(fit_plan$group_fits[[gkey]], 1)
    cell <- layout[[fr$row]]$cells[[fr$col]]
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), cell)

    if (identical(as.character(ov$align_h %||% "center")[1], "center")) {
      z <- figure_fixed_alignment_interval(fr, nr, sc, ov, "x")
      if (!is.null(z)) col_intervals[[as.character(fr$col)]] <- c(col_intervals[[as.character(fr$col)]] %||% list(), list(z))
    }
    if (identical(as.character(ov$align_v %||% "center")[1], "center")) {
      z <- figure_fixed_alignment_interval(fr, nr, sc, ov, "y")
      if (!is.null(z)) row_intervals[[as.character(fr$row)]] <- c(row_intervals[[as.character(fr$row)]] %||% list(), list(z))
    }
  }

  list(
    column_left = lapply(col_intervals, figure_fixed_common_target),
    row_bottom = lapply(row_intervals, figure_fixed_common_target)
  )
}
