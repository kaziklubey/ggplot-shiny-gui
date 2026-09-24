# R/figure/figure_renderer.R — Figure responsibility module
# v3.3.56: extracted from server.R so Figure state/layout/render logic can evolve
# independently from Shiny orchestration. Functions here are side-effect free unless noted.

figure_svg_viewport_text <- function(svg) {
  svg <- as.character(svg %||% "")
  if (!nzchar(svg) || !grepl("<svg\\b", svg, perl = TRUE)) return(svg)
  if (!grepl("preserveAspectRatio\\s*=", svg, perl = TRUE, ignore.case = TRUE)) {
    svg <- sub("<svg\\b", "<svg preserveAspectRatio=\"xMidYMid meet\"", svg, perl = TRUE)
  }
  svg
}





figure_detached_legend_background_mode <- function(ov) {
  mode <- as.character((ov %||% list())$legend_background %||% "transparent")[1]
  if (!mode %in% c("transparent", "white")) mode <- "transparent"
  mode
}

# Figure-only legend background.  Detached/free legends are separate Figure
# assets, so this must never mutate the source Graph or normal side legends.
figure_apply_detached_legend_background <- function(p, ov) {
  if (is.null(p)) return(p)
  mode <- figure_detached_legend_background_mode(ov)
  fill <- if (identical(mode, "white")) "white" else NA
  p + ggplot2::theme(
    legend.background = ggplot2::element_rect(fill = fill, colour = NA),
    legend.key = ggplot2::element_rect(fill = fill, colour = NA),
    legend.box.background = ggplot2::element_rect(fill = fill, colour = NA)
  )
}

figure_select_guide_box_grob <- function(gt, preferred_origin = NULL) {
  if (is.null(gt) || is.null(gt$layout$name)) return(NULL)
  nm <- as.character(gt$layout$name)
  idx <- grep("^guide-box", nm)
  if (!length(idx)) return(NULL)
  idx <- idx[vapply(idx, function(i) {
    gr <- gt$grobs[[i]]
    !is.null(gr) && !inherits(gr, "zeroGrob") && !inherits(gr, "nullGrob")
  }, logical(1))]
  if (!length(idx)) return(NULL)

  origin <- as.character(preferred_origin %||% "")[1]
  if (origin %in% c("right", "left", "top", "bottom", "inside")) {
    wanted <- paste0("guide-box-", origin)
    hit <- idx[nm[idx] == wanted]
    if (length(hit)) idx <- c(hit, setdiff(idx, hit))
  }

  i <- idx[[1]]
  list(
    grob = gt$grobs[[i]],
    index = i,
    name = nm[[i]],
    candidate_count = length(idx)
  )
}

figure_legend_asset_is_valid <- function(x) {
  if (!is.list(x) || !nzchar(as.character(x$svg %||% "")[1])) return(FALSE)
  ww <- suppressWarnings(as.numeric(x$width %||% NA_real_)[1])
  hh <- suppressWarnings(as.numeric(x$height %||% NA_real_)[1])
  is.finite(ww) && ww > 0 && is.finite(hh) && hh > 0
}

figure_legend_grob_asset <- function(p, reference_res = 120, preferred_origin = NULL) {
  if (is.null(p)) return(NULL)
  rr <- suppressWarnings(as.numeric(reference_res)[1])
  if (!is.finite(rr) || rr <= 0) rr <- 120

  gt <- tryCatch(ggplot2::ggplotGrob(p), error = function(e) NULL)
  sel <- figure_select_guide_box_grob(gt, preferred_origin = preferred_origin)
  if (!is.list(sel) || is.null(sel$grob)) return(NULL)

  # The selected guide-box contains every guide assigned to that side. This is
  # important for Graphs with two or more legends: detach the complete guide
  # box as one Figure layer rather than assuming a single child guide.
  gr <- sel$grob
  gi <- suppressWarnings(as.integer(sel$index %||% NA_integer_)[1])

  measure_path <- tempfile(fileext = ".pdf")
  on.exit(unlink(measure_path), add = TRUE)
  dims <- tryCatch({
    if (isTRUE(capabilities("cairo"))) {
      grDevices::cairo_pdf(measure_path, width = 20, height = 20, onefile = FALSE)
    } else {
      grDevices::pdf(measure_path, width = 20, height = 20, onefile = FALSE)
    }
    dev_id <- grDevices::dev.cur()
    closed <- FALSE
    on.exit({
      if (!closed && identical(grDevices::dev.cur(), dev_id)) try(grDevices::dev.off(), silent = TRUE)
    }, add = TRUE)
    grid::grid.newpage()
    grid::grid.draw(gr)
    ww <- tryCatch(grid::convertWidth(grid::grobWidth(gr), "in", valueOnly = TRUE), error = function(e) NA_real_)
    hh <- tryCatch(grid::convertHeight(grid::grobHeight(gr), "in", valueOnly = TRUE), error = function(e) NA_real_)

    # Some compound guide boxes report an unusable grobWidth/grobHeight even
    # though their gtable slot is valid. Fall back to the selected guide-box
    # slot only in that failure case; normal right/left slots are deliberately
    # NOT used when the tight grob dimensions are available.
    if ((!is.finite(ww) || ww <= 0 || !is.finite(hh) || hh <= 0) &&
        is.finite(gi) && gi >= 1L && gi <= nrow(gt$layout)) {
      lr <- gt$layout[gi, , drop = FALSE]
      l <- suppressWarnings(as.integer(lr$l[[1]])); r <- suppressWarnings(as.integer(lr$r[[1]]))
      t <- suppressWarnings(as.integer(lr$t[[1]])); b <- suppressWarnings(as.integer(lr$b[[1]]))
      if (all(is.finite(c(l, r))) && l >= 1L && r >= l && r <= length(gt$widths)) {
        ww <- tryCatch(grid::convertWidth(sum(gt$widths[l:r]), "in", valueOnly = TRUE), error = function(e) ww)
      }
      if (all(is.finite(c(t, b))) && t >= 1L && b >= t && b <= length(gt$heights)) {
        hh <- tryCatch(grid::convertHeight(sum(gt$heights[t:b]), "in", valueOnly = TRUE), error = function(e) hh)
      }
    }
    grDevices::dev.off(); closed <- TRUE
    c(ww, hh)
  }, error = function(e) c(NA_real_, NA_real_))
  if (length(dims) != 2L || any(!is.finite(dims)) || any(dims <= 0)) return(NULL)

  # A very small transparent breathing margin protects antialiased glyph edges
  # without changing the logical legend placement in any meaningful way.
  pad_px <- 2
  ww_px <- max(1, dims[[1]] * rr)
  hh_px <- max(1, dims[[2]] * rr)
  out_w <- ww_px + 2 * pad_px
  out_h <- hh_px + 2 * pad_px

  path <- tempfile(fileext = ".svg")
  on.exit(unlink(path), add = TRUE)
  ok <- tryCatch({
    svglite::svglite(
      path,
      width = max(0.1, out_w / rr),
      height = max(0.1, out_h / rr),
      bg = "transparent",
      standalone = FALSE
    )
    dev_id <- grDevices::dev.cur()
    closed <- FALSE
    on.exit({
      if (!closed && identical(grDevices::dev.cur(), dev_id)) try(grDevices::dev.off(), silent = TRUE)
    }, add = TRUE)
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(
      x = 0.5, y = 0.5,
      width = grid::unit(ww_px / rr, "in"),
      height = grid::unit(hh_px / rr, "in"),
      just = c("center", "center"), clip = "off"
    ))
    grid::grid.draw(gr)
    grid::popViewport()
    grDevices::dev.off(); closed <- TRUE
    TRUE
  }, error = function(e) FALSE)
  if (!isTRUE(ok) || !file.exists(path)) return(NULL)
  txt <- tryCatch(readLines(path, warn = FALSE, encoding = "UTF-8"), error = function(e) character(0))
  if (!length(txt)) return(NULL)
  txt <- paste(txt, collapse = "\n")
  if (!grepl("<svg\\b", txt, perl = TRUE)) return(NULL)

  list(
    svg = txt, width = out_w, height = out_h, pad = pad_px, grob = gr,
    guide_box_name = as.character(sel$name %||% ""),
    guide_box_candidates = as.integer(sel$candidate_count %||% 1L)
  )
}

figure_plot_svg_text <- function(p, width_px, height_px, reference_res = 120) {
  if (is.null(p)) return(NULL)
  rr <- suppressWarnings(as.numeric(reference_res)[1])
  if (!is.finite(rr) || rr <= 0) rr <- 120
  ww <- suppressWarnings(as.numeric(width_px)[1])
  hh <- suppressWarnings(as.numeric(height_px)[1])
  if (!is.finite(ww) || ww <= 0 || !is.finite(hh) || hh <= 0) return(NULL)

  # Use a real temporary SVG file instead of svgstring()/data URI. The latter
  # proved browser-sensitive in v3.3.49 (broken <img> previews on Windows).
  # The generated SVG is then embedded inline into the Shiny DOM, so no temp
  # path needs to be web-accessible and vector scaling stays crisp.
  path <- tempfile(fileext = ".svg")
  on.exit(unlink(path), add = TRUE)
  ok <- tryCatch({
    svglite::svglite(
      path,
      width = max(0.1, ww / rr),
      height = max(0.1, hh / rr),
      bg = "transparent",
      standalone = FALSE
    )
    dev_id <- grDevices::dev.cur()
    closed <- FALSE
    on.exit({
      if (!closed && identical(grDevices::dev.cur(), dev_id)) {
        try(grDevices::dev.off(), silent = TRUE)
      }
    }, add = TRUE)
    print(p)
    grDevices::dev.off()
    closed <- TRUE
    TRUE
  }, error = function(e) FALSE)
  if (!isTRUE(ok) || !file.exists(path)) return(NULL)
  txt <- tryCatch(readLines(path, warn = FALSE, encoding = "UTF-8"), error = function(e) character(0))
  if (!length(txt)) return(NULL)
  txt <- paste(txt, collapse = "\n")
  if (!grepl("<svg\\b", txt, perl = TRUE)) return(NULL)
  txt
}


figure_fit_cached_geometry <- function(meta, rect, ov) {
  if (!is.list(meta)) return(NULL)
  target <- figure_graph_target_box(rect, ov)
  band <- target$band
  avail_w <- max(1, target$width)
  avail_h <- max(1, target$height)
  bw <- suppressWarnings(as.numeric(meta$width %||% meta$plot_width_px %||% 600)[1])
  bh <- suppressWarnings(as.numeric(meta$height %||% meta$plot_height_px %||% 600)[1])
  if (!length(bw) || !is.finite(bw) || bw <= 0) bw <- 600
  if (!length(bh) || !is.finite(bh) || bh <= 0) bh <- 600
  max_scale <- if (isTRUE(target$explicit)) 4 else 1
  # Detached/free legends are overlays and never participate in the owner
  # Graph fitting box. Their own visual scale follows this same Graph scale.
  fit_bw <- bw; fit_bh <- bh
  sc <- min(avail_w / fit_bw, avail_h / fit_bh, max_scale)
  if (!is.finite(sc) || sc <= 0) sc <- 1
  val <- function(x, fallback) {
    z <- suppressWarnings(as.numeric(x %||% fallback)[1])
    if (!length(z) || !is.finite(z)) fallback else z
  }
  scale_bbox <- function(z) {
    if (!is.list(z)) return(NULL)
    vals <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
    if (length(vals) != 4L || any(!is.finite(vals)) || vals[3] <= 0 || vals[4] <= 0) return(NULL)
    list(left = vals[1] * sc, top = vals[2] * sc, width = vals[3] * sc, height = vals[4] * sc)
  }
  list(
    plot = NULL,
    width = bw * sc,
    height = bh * sc,
    panel_left = val(meta$panel_left, 0) * sc,
    panel_top = val(meta$panel_top, 0) * sc,
    panel_width = val(meta$panel_width, bw) * sc,
    panel_height = val(meta$panel_height, bh) * sc,
    panel_bbox = scale_bbox(meta$panel_bbox),
    axis_outer_bbox = scale_bbox(meta$axis_outer_bbox),
    title_bbox = scale_bbox(meta$title_bbox),
    legend_bbox = scale_bbox(meta$legend_bbox),
    legend_visual_bbox = scale_bbox(meta$legend_visual_bbox %||% meta$legend_bbox),
    legend_outside_bbox = scale_bbox(meta$legend_outside_bbox),
    legend_outside_visual_bbox = scale_bbox(meta$legend_outside_visual_bbox %||% meta$legend_outside_bbox),
    legend_state = as.character(meta$legend_state %||% "unknown")[1],
    scale = sc,
    band = band
  )
}


figure_scale_geometry_meta <- function(meta, scale = 1) {
  if (!is.list(meta)) return(NULL)
  sc <- suppressWarnings(as.numeric(scale %||% 1)[1])
  if (!is.finite(sc) || sc <= 0) sc <- 1
  val <- function(x, fallback = 0) {
    z <- suppressWarnings(as.numeric(x %||% fallback)[1])
    if (!is.finite(z)) fallback else z
  }
  scale_bbox <- function(z) {
    if (!is.list(z)) return(NULL)
    v <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
    if (length(v) != 4L || any(!is.finite(v))) return(NULL)
    list(left=v[1]*sc, top=v[2]*sc, width=v[3]*sc, height=v[4]*sc)
  }
  list(
    width=val(meta$width, 1)*sc, height=val(meta$height, 1)*sc,
    panel_left=val(meta$panel_left, 0)*sc, panel_top=val(meta$panel_top, 0)*sc,
    panel_width=val(meta$panel_width, meta$width %||% 1)*sc,
    panel_height=val(meta$panel_height, meta$height %||% 1)*sc,
    panel_bbox=scale_bbox(meta$panel_bbox), facet_bbox=scale_bbox(meta$facet_bbox),
    axis_outer_bbox=scale_bbox(meta$axis_outer_bbox), content_outer_bbox=scale_bbox(meta$content_outer_bbox),
    title_bbox=scale_bbox(meta$title_bbox),
    legend_bbox=scale_bbox(meta$legend_bbox), legend_visual_bbox=scale_bbox(meta$legend_visual_bbox %||% meta$legend_bbox),
    legend_outside_bbox=scale_bbox(meta$legend_outside_bbox),
    legend_outside_visual_bbox=scale_bbox(meta$legend_outside_visual_bbox %||% meta$legend_outside_bbox),
    scale=sc
  )
}

figure_plot_spec_for_rect_whole_scale <- function(p_raw, ov, ex, rect) {
  render_ov <- figure_layer_source_override(ov)
  anchor <- figure_plot_for_scale(p_raw, render_ov, ex, 1)
  if (figure_legend_is_detached(ov)) {
    body_ov <- render_ov; body_ov$legend <- "none"
    body_base <- figure_plot_for_scale(p_raw, body_ov, ex, 1)
    # Match the SVG path: free legend space never participates in owner-Graph fit.
    sp <- figure_fit_cached_geometry(body_base, rect, ov)
    if (is.null(sp)) return(NULL)
    sc <- sp$scale %||% 1
    body <- figure_plot_for_scale(p_raw, body_ov, ex, sc)
    sp$plot <- body$plot
    sp$raster_natural_width <- body$width
    sp$raster_natural_height <- body$height
    sp$raster_scale <- 1
    sp$body_geometry <- body
    sp$body_left <- 0
    sp$body_top <- 0
    sp$legend_bbox <- figure_layer_scale_bbox(
      figure_layer_map_bbox_to_body(anchor, body_base, anchor$legend_bbox), sc
    )
    sp$legend_visual_bbox <- figure_layer_scale_bbox(
      figure_layer_map_bbox_to_body(anchor, body_base, anchor$legend_visual_bbox %||% anchor$legend_bbox), sc
    )
    sp$layer_body_mode <- "separate-raster"
  } else {
    sp <- figure_fit_cached_geometry(anchor, rect, ov)
    if (is.null(sp)) return(NULL)
    sp$plot <- anchor$plot
    sp$raster_natural_width <- anchor$width
    sp$raster_natural_height <- anchor$height
    sp$raster_scale <- sp$scale %||% 1
    sp$layer_body_mode <- "combined-raster"
  }
  sp$geometry_source <- anchor$geometry_source %||% "unknown"
  sp$legend_state <- anchor$legend_state %||% "unknown"
  sp
}


figure_persisted_spec_for_rect <- function(preview, rect, ov) {
  if (!is.list(preview) || !nzchar(preview$svg %||% "")) return(NULL)

  detached <- figure_legend_is_detached(ov)
  has_body <- isTRUE(detached) && nzchar(preview$body_svg %||% "") && is.list(preview$body_meta)
  anchor_meta <- preview$meta %||% list()
  fit_meta <- if (has_body) preview$body_meta else anchor_meta
  sp <- figure_fit_cached_geometry(fit_meta, rect, ov)
  if (is.null(sp)) return(NULL)

  # F1-5e: packaged Figure snapshots may carry the same separated body/legend
  # assets used by the live renderer. Prefer them during cache-first restore so
  # owner geometry and free-legend dimensions are final before Graph hydration.
  if (has_body) {
    sc <- suppressWarnings(as.numeric(sp$scale %||% 1)[1])
    if (!is.finite(sc) || sc <= 0) sc <- 1
    sp$legend_bbox <- figure_layer_scale_bbox(
      figure_layer_map_bbox_to_body(anchor_meta, preview$body_meta, anchor_meta$legend_bbox), sc
    )
    sp$legend_visual_bbox <- figure_layer_scale_bbox(
      figure_layer_map_bbox_to_body(anchor_meta, preview$body_meta, anchor_meta$legend_visual_bbox %||% anchor_meta$legend_bbox), sc
    )
    sp$legend_outside_bbox <- figure_layer_scale_bbox(
      figure_layer_map_bbox_to_body(anchor_meta, preview$body_meta, anchor_meta$legend_outside_bbox), sc
    )
    sp$legend_outside_visual_bbox <- figure_layer_scale_bbox(
      figure_layer_map_bbox_to_body(anchor_meta, preview$body_meta, anchor_meta$legend_outside_visual_bbox %||% anchor_meta$legend_outside_bbox), sc
    )
    sp$legend_state <- as.character(anchor_meta$legend_state %||% sp$legend_state %||% "unknown")[1]
    sp$body_svg_text <- preview$body_svg
    sp$body_geometry <- figure_scale_geometry_meta(preview$body_meta, sc)
    sp$body_left <- 0
    sp$body_top <- 0
    sp$layer_body_mode <- "persisted-separated-svg"
    # figure_build_cell_ui() uses persisted_svg as the selected cache-first SVG
    # source; point it at the legend-free body so the old side strip never
    # appears while the Figure is still dormant.
    sp$persisted_svg <- preview$body_svg
  } else {
    sp$persisted_svg <- preview$svg
    sp$layer_body_mode <- if (isTRUE(detached)) "persisted-strip-fallback" else "combined-svg"
  }

  if (isTRUE(detached) && nzchar(preview$legend_svg %||% "")) {
    sc <- suppressWarnings(as.numeric(sp$scale %||% 1)[1])
    if (!is.finite(sc) || sc <= 0) sc <- 1
    sp$legend_svg_text <- preview$legend_svg
    lw <- suppressWarnings(as.numeric(preview$legend_width %||% NA_real_)[1])
    lh <- suppressWarnings(as.numeric(preview$legend_height %||% NA_real_)[1])
    if (is.finite(lw) && lw > 0) sp$legend_layer_width <- lw * sc
    if (is.finite(lh) && lh > 0) sp$legend_layer_height <- lh * sc
  }

  sp$persisted <- TRUE
  sp
}


figure_external_asset_node <- function(asset, css_class = "figure-external-asset") {
  if (is.null(asset)) return(NULL)
  if (identical(asset$type %||% "", "svg") && nzchar(asset$svg %||% "")) {
    return(div(class = paste(css_class, "figure-svg-snapshot svg-preview-viewport"), HTML(figure_svg_viewport_text(asset$svg))))
  }
  if (nzchar(asset$data_uri %||% "")) {
    return(tags$img(class = paste(css_class, "figure-raster-asset"), src = asset$data_uri,
                    style = "width:100%;height:100%;object-fit:contain;display:block;"))
  }
  div(class = "figure-cell-unloaded", "Asset preview unavailable")
}


figure_valid_bbox <- function(z) {
  if (!is.list(z)) return(NULL)
  v <- suppressWarnings(as.numeric(c(z$left, z$top, z$width, z$height)))
  if (length(v) != 4L || any(!is.finite(v)) || v[3] <= 0 || v[4] <= 0) return(NULL)
  list(left=v[1], top=v[2], width=v[3], height=v[4], right=v[1]+v[3], bottom=v[2]+v[4])
}

figure_detached_legend_side <- function(sp, ov) {
  figure_layer_legend_side(sp, ov)
}


figure_detached_svg_parts <- function(svg_text, sp, ov, rect, plot_off) {
  if (!figure_legend_is_detached(ov) || !nzchar(svg_text %||% "")) return(NULL)
  leg <- figure_layer_legend_bbox(sp)
  if (is.null(leg)) return(NULL)
  side <- figure_detached_legend_side(sp, ov)
  if (!side %in% c("right", "left", "top", "bottom")) return(NULL)
  sw <- max(1, suppressWarnings(as.numeric(sp$width)[1]))
  sh <- max(1, suppressWarnings(as.numeric(sp$height)[1]))
  clip_left <- 0; clip_top <- 0; clip_w <- sw; clip_h <- sh
  if (identical(side, "right")) clip_w <- max(1, min(sw, leg$left))
  if (identical(side, "left")) { clip_left <- min(sw - 1, max(0, leg$right)); clip_w <- max(1, sw - clip_left) }
  if (identical(side, "bottom")) clip_h <- max(1, min(sh, leg$top))
  if (identical(side, "top")) { clip_top <- min(sh - 1, max(0, leg$bottom)); clip_h <- max(1, sh - clip_top) }

  svg_node <- function() div(class = "figure-svg-snapshot svg-preview-viewport", HTML(figure_svg_viewport_text(svg_text)))
  main <- div(
    class = "figure-layer-graph-body figure-detached-main-svg",
    style = sprintf("position:relative;width:%.2fpx;height:%.2fpx;overflow:visible;", sw, sh),
    div(
      style = sprintf("position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;overflow:hidden;", clip_left, clip_top, clip_w, clip_h),
      div(style = sprintf("position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;", -clip_left, -clip_top, sw, sh), svg_node())
    )
  )
  list(main=main, side=side, bbox=leg)
}

figure_build_inset_layer_ui <- function(rect, sp, ov, inset_svg = NULL, inset_asset = NULL) {
  inset <- (ov %||% list())$inset %||% figure_default_inset()
  if (!isTRUE(inset$enabled) || !nzchar(as.character(inset$source_id %||% "")[1])) return(NULL)
  pos <- figure_layer_inset_canvas_position(rect, sp, ov)
  if (is.null(pos)) return(NULL)

  inset_content <- if (!is.null(inset_asset)) {
    figure_external_asset_node(inset_asset, "figure-inset-source-asset")
  } else if (nzchar(inset_svg %||% "")) {
    div(
      class = "figure-svg-snapshot svg-preview-viewport figure-inset-source-svg",
      style = "position:absolute;inset:0;width:100%;height:100%;pointer-events:none;",
      HTML(figure_svg_viewport_text(inset_svg))
    )
  } else {
    div(class = "figure-inset-placeholder", paste0("Inset: ", inset$source_id))
  }

  div(
    class = "figure-layer-inset-item figure-inset-overlay figure-draggable free",
    `data-drag-type` = "inset", `data-coordinate-space` = "canvas",
    `data-inset-anchor` = "graph",
    `data-figure-key` = rect$key, `data-figure-id` = as.character(rect$id %||% ""),
    style = sprintf(
      paste0(
        "position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;",
        "z-index:%d;overflow:hidden;pointer-events:auto;touch-action:none;user-select:none;",
        "%s"
      ),
      pos$x, pos$y, pos$width, pos$height, figure_layer_z("inset"),
      if (isTRUE(inset$border)) sprintf("border:%.1fpx solid #444;background:white;", inset$border_width %||% 1) else ""
    ),
    inset_content,
    div(
      class = "figure-inset-resize-handle",
      `aria-label` = "Resize inset",
      style = "position:absolute;right:0;bottom:0;width:14px;height:14px;z-index:3;pointer-events:auto;touch-action:none;cursor:nwse-resize;"
    )
  )
}

figure_build_detached_legend_layer_ui <- function(rect, sp, ov, svg_text = NULL) {
  if (!figure_legend_is_detached(ov) || !nzchar(svg_text %||% "")) return(NULL)
  leg <- figure_layer_legend_bbox(sp)
  if (is.null(leg)) return(NULL)
  side <- figure_detached_legend_side(sp, ov)
  if (!side %in% c("right", "left", "top", "bottom", "inside")) return(NULL)
  # Persisted cache-first SVGs do not yet have a separate legend-free body.
  # An inside legend cannot be removed with a safe side-strip clip, so keep the
  # original Graph-only view until hydration prepares the true body layer.
  if (identical(side, "inside") && !identical(as.character(sp$layer_body_mode %||% ""), "separate-svg") && is.null(sp$body_geometry)) return(NULL)
  pos <- figure_layer_legend_canvas_position(rect, sp, ov)
  if (is.null(pos)) return(NULL)
  sw <- max(1, suppressWarnings(as.numeric(sp$width)[1]))
  sh <- max(1, suppressWarnings(as.numeric(sp$height)[1]))
  scope <- figure_legend_layer_scope(ov)
  legend_svg <- as.character(sp$legend_svg_text %||% "")[1]
  standalone_legend <- nzchar(legend_svg)
  # F1-5d: a Figure-free legend must be backed by the dedicated detached
  # legend asset.  During cache-first restore the persisted combined Graph SVG
  # may still expose the old full-height guide strip (e.g. 152x600); using that
  # strip as a temporary legend creates the tall placeholder seen before Graph
  # hydration.  Keep geometry metadata for positioning/diagnostics, but render
  # no detached legend until the tight legend asset is available.
  if (!standalone_legend) return(NULL)
  svg_node <- if (standalone_legend) {
    div(
      class = "figure-svg-snapshot svg-preview-viewport figure-legend-standalone-svg",
      style = "position:absolute;inset:0;width:100%;height:100%;pointer-events:none;",
      HTML(figure_svg_viewport_text(legend_svg))
    )
  } else {
    div(class = "figure-svg-snapshot svg-preview-viewport", HTML(figure_svg_viewport_text(svg_text)))
  }
  div(
    class = paste("figure-layer-legend-item figure-detached-legend figure-draggable free", paste0("scope-", scope)),
    `data-drag-type` = "legend",
    `data-legend-mode` = "free",
    `data-legend-scope` = "figure", `data-coordinate-space` = "canvas",
    `data-figure-key` = rect$key, `data-figure-id` = as.character(rect$id %||% ""),
    style = sprintf(
      "position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;z-index:%d;overflow:hidden;pointer-events:auto;touch-action:none;user-select:none;",
      pos$x, pos$y, leg$width, leg$height, figure_layer_z("legend")
    ),
    div(
      class = "figure-legend-visual",
      style = if (standalone_legend) {
        "position:absolute;inset:0;width:100%;height:100%;pointer-events:none;overflow:visible;"
      } else {
        sprintf("position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;pointer-events:none;", -leg$left, -leg$top, sw, sh)
      },
      svg_node
    ),
    div(
      class = "figure-legend-drag-hitbox",
      `aria-label` = "Drag legend",
      style = "position:absolute;inset:0;z-index:2;background:transparent;pointer-events:auto;touch-action:none;cursor:move;"
    )
  )
}

figure_build_label_layer_ui <- function(rect, sp, ov) {
  ov <- figure_apply_slot_label_to_override(ov, rect)
  lbl <- as.character(ov$panel_label %||% "")[1]
  if (!nzchar(lbl)) return(NULL)
  pos <- figure_label_position(rect, sp, ov)
  div(
    class = paste("figure-layer-label-item figure-panel-label", if (identical(ov$label_mode %||% "align", "free")) "figure-draggable free" else "aligned"),
    `data-drag-type` = "label", `data-coordinate-space` = "canvas",
    `data-figure-key` = rect$key, `data-figure-id` = as.character(rect$id %||% ""),
    style = sprintf(
      "position:absolute;font-size:%.1fpx;left:%.2fpx;top:%.2fpx;z-index:%d;pointer-events:%s;",
      ov$label_size, rect$x + pos$x, rect$y + pos$y, figure_layer_z("label"),
      if (identical(ov$label_mode %||% "align", "free")) "auto" else "none"
    ),
    lbl
  )
}

figure_build_cell_ui <- function(rect, sp, ov, svg_text = NULL, use_svg = TRUE,
                                 external_asset = NULL,
                                 external_legend_asset = NULL) {
  if (is.null(sp) || (is.null(sp$plot) && !nzchar(svg_text %||% "") && is.null(external_asset))) {
    return(div(class = "figure-cell-unloaded", "未読み込み"))
  }

  id <- as.character(sp$id %||% rect$id %||% "")
  ov <- figure_apply_slot_label_to_override(ov, rect)
  fit <- list(width = sp$width, height = sp$height)
  crop_geo <- figure_crop_render_geometry(rect, sp, ov)
  plot_off <- crop_geo$full_off
  panel_zone <- figure_plot_panel_zone(crop_geo$full_rect, sp, ov)
  if (isTRUE(crop_geo$enabled)) {
    panel_zone$x <- panel_zone$x - crop_geo$crop_left_px
    panel_zone$y <- panel_zone$y - crop_geo$crop_top_px
  }
  crop_css <- figure_crop_css(ov)

  main_content <- NULL
  detached_parts <- NULL
  if (!is.null(external_asset)) {
    main_content <- figure_external_asset_node(external_asset, "figure-main-external-asset")
  } else if (isTRUE(use_svg) && nzchar(svg_text %||% "")) {
    # Preferred F1-4g path: the live Figure source prepared a true legend-free
    # owner Graph body. Free legend space is not reserved in Row/Panel geometry.
    if (figure_legend_is_detached(ov) && nzchar(sp$body_svg_text %||% "") && is.list(sp$body_geometry)) {
      bg <- sp$body_geometry
      bl <- suppressWarnings(as.numeric(sp$body_left %||% 0)[1]); if (!is.finite(bl)) bl <- 0
      bt <- suppressWarnings(as.numeric(sp$body_top %||% 0)[1]); if (!is.finite(bt)) bt <- 0
      main_content <- div(
        class = "figure-layer-graph-body figure-separated-body-svg",
        `data-layer-body-mode` = "separate-svg",
        style = sprintf("position:relative;width:%.2fpx;height:%.2fpx;overflow:hidden;", fit$width, fit$height),
        div(
          style = sprintf("position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;", bl, bt, bg$width, bg$height),
          div(class = "figure-svg-snapshot svg-preview-viewport", HTML(figure_svg_viewport_text(sp$body_svg_text)))
        )
      )
    } else {
      # Cache-first packages can be previewed before the Graph is hydrated. In
      # that narrow fallback we only have the persisted combined SVG, so retain
      # the side-strip clip used by F1-3. Once live source preparation completes
      # the renderer automatically switches to `separate-svg` above.
      detached_parts <- figure_detached_svg_parts(svg_text, sp, ov, rect, plot_off)
      if (is.list(detached_parts)) {
        main_content <- detached_parts$main
      } else {
        main_content <- div(class = "figure-svg-snapshot svg-preview-viewport", HTML(figure_svg_viewport_text(svg_text)))
      }
    }
  } else if (!is.null(sp$plot)) {
    natural_w <- suppressWarnings(as.numeric(sp$raster_natural_width %||% fit$width)[1])
    natural_h <- suppressWarnings(as.numeric(sp$raster_natural_height %||% fit$height)[1])
    raster_scale <- suppressWarnings(as.numeric(sp$raster_scale %||% 1)[1])
    if (!is.finite(natural_w) || natural_w <= 0) natural_w <- fit$width
    if (!is.finite(natural_h) || natural_h <= 0) natural_h <- fit$height
    if (!is.finite(raster_scale) || raster_scale <= 0) raster_scale <- 1
    # Keep the layout box at scaled geometry, but render the ggplot at its 1x
    # natural dimensions and scale that complete raster as a single visual asset.
    body_left <- suppressWarnings(as.numeric(sp$body_left %||% 0)[1]); if (!is.finite(body_left)) body_left <- 0
    body_top <- suppressWarnings(as.numeric(sp$body_top %||% 0)[1]); if (!is.finite(body_top)) body_top <- 0
    main_content <- div(
      class = "figure-raster-whole-scale figure-layer-graph-body",
      `data-layer-body-mode` = as.character(sp$layer_body_mode %||% "combined-raster")[1],
      style = sprintf("position:relative;width:%.2fpx;height:%.2fpx;overflow:hidden;", fit$width, fit$height),
      div(
        style = sprintf(
          "position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;transform:scale(%.8f);transform-origin:0 0;",
          body_left, body_top, natural_w, natural_h, raster_scale
        ),
        plotOutput(
          paste0("figure_cell_plot_", rect$key),
          width = paste0(round(natural_w), "px"),
          height = paste0(round(natural_h), "px")
        )
      )
    )
  }

  external_legend_node <- NULL
  if (!is.null(external_asset)) {
    exleg <- ov$external_legend %||% figure_default_external_legend()
    asset_mode <- as.character(external_asset$legend_mode %||% "included")[1]
    mode <- as.character(exleg$mode %||% "inherit")[1]
    if (identical(mode, "inherit")) mode <- asset_mode
    if (identical(mode, "separate") && !is.null(external_legend_asset)) {
      pos <- as.character(exleg$position %||% "right")[1]
      x <- exleg$x; y <- exleg$y; w <- exleg$width; h <- exleg$height
      if (identical(pos, "right"))  { x <- 0.76; y <- 0.10; w <- 0.22; h <- 0.34 }
      if (identical(pos, "left"))   { x <- 0.02; y <- 0.10; w <- 0.22; h <- 0.34 }
      if (identical(pos, "top"))    { x <- 0.25; y <- 0.01; w <- 0.50; h <- 0.18 }
      if (identical(pos, "bottom")) { x <- 0.25; y <- 0.80; w <- 0.50; h <- 0.18 }
      external_legend_node <- div(
        class = "figure-external-legend-overlay",
        `data-figure-key` = rect$key, `data-figure-id` = id,
        style = sprintf("position:absolute;left:%.3f%%;top:%.3f%%;width:%.3f%%;height:%.3f%%;z-index:70;overflow:visible;",
                        x*100, y*100, w*100, h*100),
        figure_external_asset_node(external_legend_asset, "figure-external-legend-asset")
      )
    }
  }

  div(
    class = "figure-panel-frame",
    `data-figure-key` = rect$key,
    `data-figure-id` = id,
    style = sprintf("z-index:%d;", as.integer(rect$z_index %||% rect$index %||% 1)),
    div(
      class = "figure-cell-plot-shell figure-plot-frame",
      style = sprintf(
        "position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;%s",
        crop_geo$shell_left, crop_geo$shell_top,
        crop_geo$shell_width, crop_geo$shell_height, crop_css$outer %||% ""
      ),
      div(
        class = "figure-crop-transform",
        style = sprintf(
          "%sleft:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;",
          crop_css$inner %||% "", crop_geo$inner_left, crop_geo$inner_top,
          crop_geo$inner_width, crop_geo$inner_height
        ),
        main_content
      )
    ),
    div(
      class = "figure-graph-anchor-zone",
      style = {
        gf <- figure_graph_display_frame(rect, sp, ov)
        sprintf(
          "position:absolute;left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;pointer-events:none;visibility:hidden;",
          gf$x, gf$y, gf$width, gf$height
        )
      }
    ),
    div(
      class = "figure-plot-panel-zone",
      style = sprintf(
        "left:%.2fpx;top:%.2fpx;width:%.2fpx;height:%.2fpx;",
        panel_zone$x, panel_zone$y, panel_zone$width, panel_zone$height
      )
    ),
    div(
      class = "figure-panel-overlay-layer",
      # External-asset legacy legend remains cell-owned for now. Figure Inset
      # and free ggplot legends are canvas-layer overlays.
      external_legend_node
    )
  )
}

