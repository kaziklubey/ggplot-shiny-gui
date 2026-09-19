# Shared application helpers used by Graph and Figure runtimes.
`%||%` <- function(a, b) if (is.null(a)) b else a

# -----------------------------------------------------------------------------
# Runtime font catalogue / text helpers
# -----------------------------------------------------------------------------
# Do not add a hard dependency only for font discovery. svglite normally brings
# systemfonts with it, but Projects must still start when that package is absent.
scan_app_fonts <- function() {
  jp_priority <- c(
    "Yu Gothic", "Yu Gothic UI", "Meiryo", "MS Gothic", "MS PGothic",
    "Noto Sans CJK JP", "Noto Serif CJK JP", "Noto Sans JP", "Noto Serif JP"
  )
  if (!requireNamespace("systemfonts", quietly = TRUE)) {
    return(list(
      backend = "fallback", families = character(0),
      japanese_candidates = character(0), error = "systemfonts unavailable"
    ))
  }
  z <- tryCatch(systemfonts::system_fonts(), error = function(e) e)
  if (inherits(z, "error") || !is.data.frame(z) || !"family" %in% names(z)) {
    msg <- if (inherits(z, "error")) conditionMessage(z) else "system_fonts() returned no family column"
    return(list(
      backend = "fallback", families = character(0),
      japanese_candidates = character(0), error = msg
    ))
  }
  fam <- unique(trimws(as.character(z$family)))
  fam <- sort(fam[nzchar(fam) & !is.na(fam)], method = "radix")
  fam <- setdiff(fam, c("sans", "serif", "mono", "monospace"))
  jp <- jp_priority[jp_priority %in% fam]
  list(backend = "systemfonts", families = fam, japanese_candidates = jp, error = NULL)
}

app_font_catalog <- scan_app_fonts()
if (isTRUE(capabilities("cairo"))) options(bitmapType = "cairo")

app_font_choices <- function(selected = NULL) {
  fam <- as.character(app_font_catalog$families %||% character(0))
  jp <- as.character(app_font_catalog$japanese_candidates %||% character(0))
  other <- setdiff(fam, jp)
  out <- c(
    "Sans serif（標準）" = "sans",
    "Serif" = "serif",
    "Monospace" = "mono"
  )
  if (length(jp)) {
    vals <- stats::setNames(jp, paste0("★ 日本語候補: ", jp))
    out <- c(out, vals)
  }
  if (length(other)) out <- c(out, stats::setNames(other, other))
  sel <- app_normalize_font_family_mode(selected %||% "sans")
  if (nzchar(sel) && !sel %in% unname(out) && !identical(sel, "custom")) {
    out <- c(out, stats::setNames(sel, paste0("⚠ 現在の設定（未検出）: ", sel)))
  }
  c(out, "任意のフォント名" = "custom")
}

app_font_available <- function(family) {
  fam <- trimws(as.character(family %||% "")[1])
  if (!nzchar(fam) || fam %in% c("sans", "serif", "mono")) return(TRUE)
  fam %in% as.character(app_font_catalog$families %||% character(0))
}

# Canonical font helpers.  The UI stores a selector mode plus an optional
# custom family, while ggplot ultimately needs one effective family string.
# Keep the two concepts separate so Selectize binding/default materialisation
# cannot create a false render-state change.
app_normalize_font_family_mode <- function(x, default = "sans") {
  z <- trimws(as.character(x %||% "")[1])
  if (is.na(z) || !nzchar(z)) z <- as.character(default %||% "sans")[1]
  if (is.na(z) || !nzchar(z)) z <- "sans"

  key <- tolower(gsub("[_-]+", " ", z))
  key <- gsub("\\s+", " ", trimws(key))
  if (key %in% c("sans", "sans serif")) return("sans")
  if (key %in% c("serif")) return("serif")
  if (key %in% c("mono", "monospace", "mono space")) return("mono")
  if (key %in% c("custom")) return("custom")
  z
}

app_normalize_font_family_custom <- function(x) {
  z <- trimws(as.character(x %||% "")[1])
  if (is.na(z)) "" else z
}

app_effective_font_family <- function(mode = NULL, custom = NULL) {
  mode <- app_normalize_font_family_mode(mode, "sans")
  if (identical(mode, "custom")) {
    fam <- app_normalize_font_family_custom(custom)
    if (nzchar(fam)) fam else "sans"
  } else {
    mode
  }
}

normalize_multiline_label <- function(x) {
  x <- as.character(x %||% "")[1]
  if (is.na(x)) x <- ""
  x <- gsub("\r\n?", "\n", x, perl = TRUE)
  # The two literal characters backslash+n are also accepted for copied styles.
  gsub("\\\\n", "\n", x, perl = TRUE)
}

app_open_png_device <- function(filename, width_px, height_px, res = 120) {
  args <- list(
    filename = filename,
    width = max(1, round(as.numeric(width_px))),
    height = max(1, round(as.numeric(height_px))),
    units = "px",
    res = as.numeric(res)
  )
  if (isTRUE(capabilities("cairo"))) args$type <- "cairo"
  do.call(grDevices::png, args)
}

app_save_plot_png <- function(plot, filename, width_px, height_px, res = 120) {
  app_open_png_device(filename, width_px, height_px, res)
  dev_id <- grDevices::dev.cur()
  closed <- FALSE
  on.exit({
    if (!closed && identical(grDevices::dev.cur(), dev_id)) try(grDevices::dev.off(), silent = TRUE)
  }, add = TRUE)
  print(plot)
  grDevices::dev.off()
  closed <- TRUE
  invisible(TRUE)
}


# -----------------------------------------------------------------------------
# Plot geometry helpers
# -----------------------------------------------------------------------------
# Plot横幅 / 縦幅は「デバイス全体」ではなく、軸に囲まれたpanel領域の
# 大きさとして扱う。凡例や軸タイトルはpanelの外側へ追加されるため、
# 凡例の表示/非表示や位置変更でpanelそのものの幅・高さは変わらない。
apply_fixed_panel_size <- function(p, panel_width_px, panel_height_px, reference_res = 120) {
  pw <- suppressWarnings(as.numeric(panel_width_px)[1])
  ph <- suppressWarnings(as.numeric(panel_height_px)[1])
  rr <- suppressWarnings(as.numeric(reference_res)[1])
  if (!is.finite(pw) || pw <= 0) pw <- 600
  if (!is.finite(ph) || ph <= 0) ph <- 600
  if (!is.finite(rr) || rr <= 0) rr <- 120

  tryCatch(
    p + ggh4x::force_panelsizes(
      rows = 1,
      cols = 1,
      total_width = grid::unit(pw / rr, "in"),
      total_height = grid::unit(ph / rr, "in")
    ),
    error = function(e) p
  )
}

# force_panelsizes() 適用後のplot全体（panel + axes + title + legend）と、
# その中のpanel領域の実寸を測る。Figureのドラッグ座標では、このpanel bbox
# を基準にすることで、axis/legend/marginを含むplot全体座標との混同を防ぐ。
measure_plot_geometry_px <- function(p, reference_res = 120, fallback_width = 600, fallback_height = 600) {
  rr <- suppressWarnings(as.numeric(reference_res)[1])
  if (!is.finite(rr) || rr <= 0) rr <- 120

  fw <- suppressWarnings(as.numeric(fallback_width)[1])
  fh <- suppressWarnings(as.numeric(fallback_height)[1])
  if (!is.finite(fw) || fw <= 0) fw <- 600
  if (!is.finite(fh) || fh <= 0) fh <- 600

  empty_bbox <- function() list(left = NA_real_, top = NA_real_, width = 0, height = 0)
  fallback_bbox <- list(left = 0, top = 0, width = fw, height = fh)
  fallback <- list(
    width = fw,
    height = fh,
    panel_left = 0,
    panel_top = 0,
    panel_width = fw,
    panel_height = fh,
    panel_bbox = fallback_bbox,
    facet_bbox = fallback_bbox,
    axis_outer_bbox = fallback_bbox,
    content_outer_bbox = fallback_bbox,
    title_bbox = empty_bbox(),
    legend_bbox = empty_bbox(),
    legend_visual_bbox = empty_bbox(),
    legend_outside_bbox = empty_bbox(),
    legend_outside_visual_bbox = empty_bbox(),
    legend_state = "unknown",
    geometry_source = "fallback"
  )

  out <- tryCatch({
    tf <- tempfile(fileext = ".pdf")
    if (isTRUE(capabilities("cairo"))) {
      grDevices::cairo_pdf(tf, width = 20, height = 20, onefile = FALSE)
    } else {
      grDevices::pdf(tf, width = 20, height = 20, onefile = FALSE)
    }
    dev_id <- grDevices::dev.cur()
    on.exit({
      if (identical(grDevices::dev.cur(), dev_id)) try(grDevices::dev.off(), silent = TRUE)
      unlink(tf)
    }, add = TRUE)

    g <- ggplot2::ggplotGrob(p)
    grid::grid.newpage()
    grid::grid.draw(g)

    widths_in <- grid::convertWidth(g$widths, "in", valueOnly = TRUE)
    heights_in <- grid::convertHeight(g$heights, "in", valueOnly = TRUE)
    total_w_in <- sum(widths_in)
    total_h_in <- sum(heights_in)

    bbox_for_idx <- function(idx) {
      idx <- unique(as.integer(idx))
      idx <- idx[is.finite(idx) & idx >= 1L & idx <= nrow(g$layout)]
      if (!length(idx)) return(empty_bbox())
      l <- min(g$layout$l[idx])
      r <- max(g$layout$r[idx])
      t <- min(g$layout$t[idx])
      b <- max(g$layout$b[idx])
      left_in <- if (l > 1L) sum(widths_in[seq_len(l - 1L)]) else 0
      top_in <- if (t > 1L) sum(heights_in[seq_len(t - 1L)]) else 0
      list(
        left = max(0, left_in * rr),
        top = max(0, top_in * rr),
        width = max(0, sum(widths_in[l:r]) * rr),
        height = max(0, sum(heights_in[t:b]) * rr)
      )
    }

    nm <- as.character(g$layout$name %||% character(0))
    panel_idx <- which(grepl("^panel", nm))
    strip_idx <- which(grepl("^strip", nm))
    axis_idx <- which(grepl("^axis-[lrtb]", nm))
    axis_title_idx <- which(grepl("^(xlab|ylab)-", nm))
    plot_title_idx <- which(nm == "title")
    title_idx <- which(nm %in% c("title", "subtitle", "caption"))
    legend_idx <- which(grepl("^guide-box", nm))
    legend_outside_idx <- which(grepl("^guide-box-(right|left|top|bottom)$", nm))
    # ggplot2 can leave empty guide-box slots in the gtable.  Their layout cells
    # must not be interpreted as a real legend bbox.  Keep only non-zero grobs.
    guide_is_visible <- function(i) {
      if (!is.finite(i) || i < 1L || i > length(g$grobs)) return(FALSE)
      gr <- g$grobs[[i]]
      !(inherits(gr, "zeroGrob") || inherits(gr, "nullGrob"))
    }
    if (length(legend_idx)) legend_idx <- legend_idx[vapply(legend_idx, guide_is_visible, logical(1))]
    if (length(legend_outside_idx)) legend_outside_idx <- legend_outside_idx[vapply(legend_outside_idx, guide_is_visible, logical(1))]
    legend_state <- if (length(legend_idx)) "present" else "none"

    panel_bbox <- bbox_for_idx(panel_idx)
    facet_bbox <- bbox_for_idx(c(panel_idx, strip_idx))
    axis_outer_bbox <- bbox_for_idx(c(panel_idx, strip_idx, axis_idx, axis_title_idx))
    content_outer_bbox <- bbox_for_idx(c(panel_idx, strip_idx, axis_idx, axis_title_idx, title_idx))
    title_bbox <- bbox_for_idx(plot_title_idx)
    legend_bbox <- bbox_for_idx(legend_idx)
    legend_outside_bbox <- bbox_for_idx(legend_outside_idx)

    # F1-4: distinguish the guide-box layout slot from the actual visible guide
    # grob. A right/left guide-box often spans the full panel height even though
    # the legend itself is small and vertically centred. Figure overlay dragging
    # must use the tight visual bbox; Row alignment continues to use legend_bbox.
    legend_visual_bbox_for_idx <- function(idx) {
      idx <- unique(as.integer(idx))
      idx <- idx[is.finite(idx) & idx >= 1L & idx <= nrow(g$layout)]
      if (!length(idx)) return(empty_bbox())
      boxes <- lapply(idx, function(i) {
        slot <- bbox_for_idx(i)
        gr <- g$grobs[[i]]
        ww <- tryCatch(grid::convertWidth(grid::grobWidth(gr), "in", valueOnly=TRUE) * rr, error=function(e) NA_real_)
        hh <- tryCatch(grid::convertHeight(grid::grobHeight(gr), "in", valueOnly=TRUE) * rr, error=function(e) NA_real_)
        if (!is.finite(ww) || ww <= 0 || !is.finite(hh) || hh <= 0) return(slot)
        ww <- min(slot$width, ww); hh <- min(slot$height, hh)
        # gtable guide boxes are centred within their allocated slot unless a
        # custom viewport says otherwise. Centring is exact for the ordinary
        # right/left/top/bottom guide-boxes produced by ggplot2.
        list(
          left = slot$left + max(0, slot$width - ww) / 2,
          top = slot$top + max(0, slot$height - hh) / 2,
          width = ww, height = hh
        )
      })
      if (!length(boxes)) return(empty_bbox())
      left <- min(vapply(boxes, `[[`, numeric(1), "left"))
      top <- min(vapply(boxes, `[[`, numeric(1), "top"))
      right <- max(vapply(boxes, function(z) z$left + z$width, numeric(1)))
      bottom <- max(vapply(boxes, function(z) z$top + z$height, numeric(1)))
      list(left=left, top=top, width=max(0,right-left), height=max(0,bottom-top))
    }
    legend_visual_bbox <- legend_visual_bbox_for_idx(legend_idx)
    legend_outside_visual_bbox <- legend_visual_bbox_for_idx(legend_outside_idx)

    # Old ggplot2 can expose one generic guide-box name rather than side-specific
    # guide-box-* names. Keep it measurable, but do not guess that it is outside.
    if (!is.finite(legend_outside_bbox$width) || legend_outside_bbox$width <= 0 ||
        !is.finite(legend_outside_bbox$height) || legend_outside_bbox$height <= 0) {
      legend_outside_bbox <- empty_bbox()
    }

    list(
      width = max(fw, ceiling(total_w_in * rr)),
      height = max(fh, ceiling(total_h_in * rr)),
      panel_left = panel_bbox$left,
      panel_top = panel_bbox$top,
      panel_width = panel_bbox$width,
      panel_height = panel_bbox$height,
      panel_bbox = panel_bbox,
      facet_bbox = facet_bbox,
      axis_outer_bbox = axis_outer_bbox,
      content_outer_bbox = content_outer_bbox,
      title_bbox = title_bbox,
      legend_bbox = legend_bbox,
      legend_visual_bbox = legend_visual_bbox,
      legend_outside_bbox = legend_outside_bbox,
      legend_outside_visual_bbox = legend_outside_visual_bbox,
      legend_state = legend_state,
      geometry_source = "gtable"
    )
  }, error = function(e) NULL)

  if (is.null(out) ||
      !is.finite(out$width) || out$width <= 0 ||
      !is.finite(out$height) || out$height <= 0 ||
      !is.finite(out$panel_width) || out$panel_width <= 0 ||
      !is.finite(out$panel_height) || out$panel_height <= 0) {
    return(fallback)
  }

  # Numerical conversion on some devices can overshoot by fractions of a px.
  clamp_bbox <- function(z) {
    if (!is.list(z)) return(empty_bbox())
    left <- suppressWarnings(as.numeric(z$left %||% NA_real_)[1])
    top <- suppressWarnings(as.numeric(z$top %||% NA_real_)[1])
    width <- suppressWarnings(as.numeric(z$width %||% 0)[1])
    height <- suppressWarnings(as.numeric(z$height %||% 0)[1])
    if (!is.finite(width) || width <= 0 || !is.finite(height) || height <= 0) return(empty_bbox())
    if (!is.finite(left)) left <- 0
    if (!is.finite(top)) top <- 0
    left <- min(max(0, left), max(0, out$width - 1))
    top <- min(max(0, top), max(0, out$height - 1))
    width <- min(max(1, width), max(1, out$width - left))
    height <- min(max(1, height), max(1, out$height - top))
    list(left = left, top = top, width = width, height = height)
  }

  out$panel_bbox <- clamp_bbox(out$panel_bbox)
  out$facet_bbox <- clamp_bbox(out$facet_bbox)
  out$axis_outer_bbox <- clamp_bbox(out$axis_outer_bbox)
  out$content_outer_bbox <- clamp_bbox(out$content_outer_bbox)
  out$title_bbox <- clamp_bbox(out$title_bbox)
  out$legend_bbox <- clamp_bbox(out$legend_bbox)
  out$legend_visual_bbox <- clamp_bbox(out$legend_visual_bbox)
  out$legend_outside_bbox <- clamp_bbox(out$legend_outside_bbox)
  out$legend_outside_visual_bbox <- clamp_bbox(out$legend_outside_visual_bbox)

  out$panel_left <- out$panel_bbox$left
  out$panel_top <- out$panel_bbox$top
  out$panel_width <- out$panel_bbox$width
  out$panel_height <- out$panel_bbox$height
  out
}

measure_plot_size_px <- function(p, reference_res = 120, fallback_width = 600, fallback_height = 600) {
  z <- measure_plot_geometry_px(
    p,
    reference_res = reference_res,
    fallback_width = fallback_width,
    fallback_height = fallback_height
  )
  list(width = z$width, height = z$height)
}
