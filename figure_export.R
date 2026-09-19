# figure_export.R — Figure device rendering
# v3.4.0-alpha3: shared Preview/Export rect geometry + slot-owned labels + provisional crop/inset.

figure_draw_plot_grob_cropped <- function(grob, cx, cy, ww, hh,
                                          crop = figure_default_crop(),
                                          clip_box = NULL) {
  cr <- figure_crop_fractions(list(crop = crop))
  if (isTRUE(cr$enabled) && is.list(clip_box)) {
    bx <- suppressWarnings(as.numeric(clip_box$x %||% NA_real_)[1])
    by <- suppressWarnings(as.numeric(clip_box$y %||% NA_real_)[1])
    bw <- suppressWarnings(as.numeric(clip_box$width %||% NA_real_)[1])
    bh <- suppressWarnings(as.numeric(clip_box$height %||% NA_real_)[1])
    if (all(is.finite(c(bx, by, bw, bh))) && bw > 0 && bh > 0) {
      # F1-2/F1-2b: clip the original-scale grob behind the visible Figure
      # footprint. Never enlarge the surviving crop region.
      grid::pushViewport(grid::viewport(
        x = bx, y = by, width = bw, height = bh,
        just = c("center", "center"), clip = "on"
      ))
      grid::pushViewport(grid::viewport(
        x = 0.5 + (cx - bx) / bw,
        y = 0.5 + (cy - by) / bh,
        width = ww / bw, height = hh / bh,
        just = c("center", "center"), clip = "off"
      ))
      grid::grid.draw(grob)
      grid::popViewport(2)
      return(invisible(TRUE))
    }
  }

  grid::pushViewport(grid::viewport(
    x = cx, y = cy, width = ww, height = hh,
    just = c("center", "center"), clip = "on"
  ))
  grid::grid.draw(grob)
  grid::popViewport()
  invisible(TRUE)
}



figure_extract_legend_grob <- function(p, preferred_origin = NULL) {
  gt <- tryCatch(ggplot2::ggplotGrob(p), error = function(e) NULL)
  sel <- figure_select_guide_box_grob(gt, preferred_origin = preferred_origin)
  if (is.list(sel)) sel$grob else NULL
}

# F1-5g legacy/cache-first export fallback. A Project may have a complete
# Figure SVG snapshot without a hydrated ggplot object. Convert only that
# snapshot to a grid raster for device composition. F1-5j deliberately keeps
# Project persistence SVG-only; this helper diagnoses the compatibility raster path.
figure_svg_straight_rgba <- function(svg_text, width, height) {
  txt <- as.character(svg_text %||% "")[1]
  if (!nzchar(txt) || !requireNamespace("rsvg", quietly = TRUE)) return(NULL)
  ww <- suppressWarnings(as.integer(round(as.numeric(width %||% NA_real_)[1])))
  hh <- suppressWarnings(as.integer(round(as.numeric(height %||% NA_real_)[1])))
  if (!is.finite(ww) || ww < 1L || !is.finite(hh) || hh < 1L) return(NULL)

  # librsvg/Cairo bitmap surfaces use premultiplied alpha. rsvg::rsvg() exposes
  # the RGBA bitmap as a standard h*w*4 array, which lets us undo that
  # premultiplication before handing the pixels to grid. This avoids the dark
  # semi-transparent fringe produced when premultiplied RGB values are treated
  # as straight-alpha colours by downstream graphics devices.
  rgba <- tryCatch(
    rsvg::rsvg(charToRaw(enc2utf8(txt)), width = ww, height = hh),
    error = function(e) NULL
  )
  if (is.null(rgba) || length(dim(rgba)) != 3L || dim(rgba)[3] < 4L) return(NULL)

  alpha <- rgba[, , 4]
  partial <- is.finite(alpha) & alpha > 0 & alpha < 1
  premult_candidates <- 0L
  if (any(partial)) {
    mx <- pmax(rgba[, , 1], rgba[, , 2], rgba[, , 3])
    premult_candidates <- sum(partial & mx <= alpha + (1 / 255) + 1e-12, na.rm = TRUE)
    for (ch in 1:3) {
      plane <- rgba[, , ch]
      plane[partial] <- pmin(1, pmax(0, plane[partial] / alpha[partial]))
      rgba[, , ch] <- plane
    }
  }

  list(
    rgba = rgba,
    raster = tryCatch(grDevices::as.raster(rgba), error = function(e) NULL),
    width = ww,
    height = hh,
    partial_pixels = sum(partial, na.rm = TRUE),
    premult_candidates = as.integer(premult_candidates)
  )
}

figure_svg_snapshot_diagnostics <- function(svg_text, width, height, edge_band = 4L) {
  txt <- as.character(svg_text %||% "")[1]
  if (!nzchar(txt)) return(list(ok=FALSE, reason="empty-svg"))
  ww <- suppressWarnings(as.integer(round(as.numeric(width %||% NA_real_)[1])))
  hh <- suppressWarnings(as.integer(round(as.numeric(height %||% NA_real_)[1])))
  if (!is.finite(ww) || ww < 1L || !is.finite(hh) || hh < 1L) {
    return(list(ok=FALSE, reason="invalid-size", width=ww, height=hh))
  }

  image_hits <- gregexpr("<image\\b", txt, perl=TRUE)[[1]]
  embedded_images <- if (length(image_hits) == 1L && identical(image_hits[1], -1L)) 0L else length(image_hits)
  transparent_root <- grepl(
    "<rect[^>]*width=[^ >]*100%[^>]*height=[^ >]*100%[^>]*fill:[[:space:]]*none",
    txt, perl=TRUE, ignore.case=TRUE
  )
  white_bg_rect <- grepl(
    "<rect[^>]*stroke:[[:space:]]*#FFFFFF[^>]*fill:[[:space:]]*#FFFFFF",
    txt, perl=TRUE, ignore.case=TRUE
  )

  conv <- figure_svg_straight_rgba(txt, ww, hh)
  if (is.null(conv) || is.null(conv$rgba)) {
    return(list(
      ok=FALSE, reason="raster-convert-failed", width=ww, height=hh,
      embedded_images=embedded_images, transparent_root=transparent_root,
      white_bg_rect=white_bg_rect
    ))
  }

  rgba <- conv$rgba
  nrw <- dim(rgba)[1]; ncl <- dim(rgba)[2]
  band <- max(1L, min(as.integer(edge_band %||% 4L), nrw, ncl))
  edge_alpha <- c(
    as.vector(rgba[seq_len(band), , 4, drop=FALSE]),
    as.vector(rgba[seq.int(max(1L, nrw-band+1L), nrw), , 4, drop=FALSE]),
    as.vector(rgba[, seq_len(band), 4, drop=FALSE]),
    as.vector(rgba[, seq.int(max(1L, ncl-band+1L), ncl), 4, drop=FALSE])
  )
  alpha <- as.integer(round(pmin(1, pmax(0, edge_alpha)) * 255))
  nz <- alpha[alpha > 0L]
  list(
    ok=TRUE, width=ww, height=hh, edge_band=band,
    embedded_images=embedded_images, transparent_root=transparent_root,
    white_bg_rect=white_bg_rect,
    edge_total=length(alpha), edge_transparent=sum(alpha == 0L),
    edge_partial=sum(alpha > 0L & alpha < 255L), edge_opaque=sum(alpha == 255L),
    edge_min_nonzero=if (length(nz)) min(nz) else NA_integer_,
    edge_max_partial=if (any(alpha > 0L & alpha < 255L)) max(alpha[alpha > 0L & alpha < 255L]) else NA_integer_,
    partial_pixels=conv$partial_pixels,
    premultiplied_candidates=conv$premult_candidates,
    unpremultiplied=TRUE
  )
}

figure_svg_snapshot_grob <- function(svg_text, width, height) {
  conv <- figure_svg_straight_rgba(svg_text, width, height)
  if (is.null(conv) || is.null(conv$raster)) return(NULL)
  # The bitmap is rendered at the exact Figure owner-frame size, converted to
  # straight alpha above, then placed pixel-exactly without a second resample.
  grid::rasterGrob(conv$raster, width = grid::unit(1, "npc"), height = grid::unit(1, "npc"), interpolate = FALSE)
}

figure_draw_persisted_svg_panel <- function(preview, ov, rect, canvas_w, canvas_h, draw_legend = FALSE) {
  sp <- tryCatch(figure_persisted_spec_for_rect(preview, rect, ov), error = function(e) NULL)
  if (is.null(sp)) return(NULL)
  body_svg <- as.character(sp$persisted_svg %||% "")[1]
  body_grob <- figure_svg_snapshot_grob(body_svg, sp$width, sp$height)
  if (is.null(body_grob)) return(NULL)

  crop_geo <- figure_crop_render_geometry(rect, sp, ov)
  band <- min(max(0, figure_label_band(ov)), max(0, rect$height - 1))
  # Match Preview's shell + crop-transform nesting exactly. The previous live
  # non-crop export path omitted shell_left/shell_top; F1-5g uses the complete
  # offset contract for both live and persisted sources.
  full_left <- rect$x + crop_geo$shell_left + crop_geo$inner_left
  full_top <- rect$y + crop_geo$shell_top + crop_geo$inner_top
  clip_box <- NULL
  if (isTRUE(crop_geo$enabled)) {
    clip_h <- max(1, rect$height - band)
    clip_box <- list(
      x=(rect$x + rect$width/2)/canvas_w,
      y=1-(rect$y + band + clip_h/2)/canvas_h,
      width=rect$width/canvas_w, height=clip_h/canvas_h
    )
  }
  figure_draw_plot_grob_cropped(
    body_grob,
    (full_left + sp$width/2)/canvas_w,
    1-(full_top + sp$height/2)/canvas_h,
    sp$width/canvas_w, sp$height/canvas_h,
    crop=ov$crop, clip_box=clip_box
  )

  legend_job <- NULL
  if (figure_legend_is_detached(ov) && nzchar(sp$legend_svg_text %||% "")) {
    leg <- figure_layer_legend_bbox(sp)
    pos <- figure_layer_legend_canvas_position(rect, sp, ov)
    if (!is.null(leg) && !is.null(pos)) {
      lg <- figure_svg_snapshot_grob(sp$legend_svg_text, leg$width, leg$height)
      if (!is.null(lg)) {
        legend_job <- list(
          grob=lg, x=pos$x, y=pos$y, width=leg$width, height=leg$height,
          background=figure_detached_legend_background_mode(ov)
        )
      }
    }
  }
  if (isTRUE(draw_legend) && is.list(legend_job)) {
    grid::pushViewport(grid::viewport(
      x=(legend_job$x + legend_job$width/2)/canvas_w,
      y=1-(legend_job$y + legend_job$height/2)/canvas_h,
      width=legend_job$width/canvas_w, height=legend_job$height/canvas_h,
      just=c("center","center"), clip="off"
    ))
    if (identical(legend_job$background, "white")) grid::grid.rect(gp=grid::gpar(fill="white", col=NA))
    grid::grid.draw(legend_job$grob)
    grid::popViewport()
  }
  list(sp=sp, legend_job=legend_job)
}

figure_export_plot_spec <- function(p_raw, ov, ex, rect) {
  if (is.null(p_raw)) return(NULL)
  render_ov <- figure_layer_source_override(ov)
  anchor_base <- tryCatch(figure_plot_for_scale(p_raw, render_ov, ex, 1), error=function(e) NULL)
  if (is.null(anchor_base)) return(NULL)

  if (figure_legend_is_detached(ov)) {
    legend_plot <- figure_apply_detached_legend_background(anchor_base$plot, ov)
    legend_asset <- tryCatch(
      figure_legend_grob_asset(
        legend_plot,
        reference_res = ex$reference_res %||% 120,
        preferred_origin = figure_legend_source_origin(ov)
      ),
      error = function(e) NULL
    )

    # Fail-safe: a detached legend extraction failure must never erase the
    # legend from exported output.  Fall back to the combined source plot,
    # fitted into the same Figure rect, instead of drawing a legend-free body.
    if (!figure_legend_asset_is_valid(legend_asset)) {
      sp <- tryCatch(figure_fit_cached_geometry(anchor_base, rect, ov), error=function(e) NULL)
      if (is.null(sp)) return(NULL)
      sc <- suppressWarnings(as.numeric(sp$scale %||% 1)[1]); if (!is.finite(sc) || sc <= 0) sc <- 1
      combined_scaled <- tryCatch(figure_plot_for_scale(p_raw, render_ov, ex, sc), error=function(e) NULL)
      if (is.null(combined_scaled) || is.null(combined_scaled$plot)) return(NULL)
      sp$plot <- combined_scaled$plot
      return(list(sp=sp, legend_asset=NULL, detach_fallback=TRUE))
    }

    body_ov <- render_ov; body_ov$legend <- "none"
    body_base <- tryCatch(figure_plot_for_scale(p_raw, body_ov, ex, 1), error=function(e) NULL)
    if (is.null(body_base)) return(NULL)

    # Mirror Preview's contract exactly: fit the legend-free 1x body geometry,
    # then use that fitted geometry as the Figure owner frame.  Export may
    # render a fresh grob, but overlay positions must never be derived from a
    # second independent fit.
    sp <- tryCatch(figure_fit_cached_geometry(body_base, rect, ov), error=function(e) NULL)
    if (is.null(sp)) return(NULL)
    sc <- suppressWarnings(as.numeric(sp$scale %||% 1)[1]); if (!is.finite(sc) || sc <= 0) sc <- 1
    body_scaled <- tryCatch(figure_plot_for_scale(p_raw, body_ov, ex, sc), error=function(e) NULL)
    if (is.null(body_scaled) || is.null(body_scaled$plot)) return(NULL)
    sp$plot <- body_scaled$plot

    mapped_bbox <- figure_layer_map_bbox_to_body(anchor_base, body_base, anchor_base$legend_bbox)
    mapped_visual <- figure_layer_map_bbox_to_body(
      anchor_base, body_base, anchor_base$legend_visual_bbox %||% anchor_base$legend_bbox
    )
    sp$legend_bbox <- figure_layer_scale_bbox(mapped_bbox, sc)
    sp$legend_visual_bbox <- figure_layer_scale_bbox(mapped_visual, sc)
    sp$legend_state <- anchor_base$legend_state %||% sp$legend_state

    lw <- suppressWarnings(as.numeric(legend_asset$width %||% NA_real_)[1])
    lh <- suppressWarnings(as.numeric(legend_asset$height %||% NA_real_)[1])
    if (is.finite(lw) && lw > 0) sp$legend_layer_width <- lw * sc
    if (is.finite(lh) && lh > 0) sp$legend_layer_height <- lh * sc
    return(list(sp=sp, legend_asset=legend_asset))
  }

  # Normal legends use the same Preview rule as SVG mode: fit the 1x measured
  # geometry first.  Avoid figure_plot_spec_for_rect()'s second corrective fit,
  # which can produce a different Figure frame at export time.
  sp <- tryCatch(figure_fit_cached_geometry(anchor_base, rect, ov), error=function(e) NULL)
  if (is.null(sp)) return(NULL)
  sc <- suppressWarnings(as.numeric(sp$scale %||% 1)[1]); if (!is.finite(sc) || sc <= 0) sc <- 1
  rendered <- tryCatch(figure_plot_for_scale(p_raw, render_ov, ex, sc), error=function(e) NULL)
  if (is.null(rendered) || is.null(rendered$plot)) return(NULL)
  sp$plot <- rendered$plot
  list(sp=sp, legend_asset=NULL)
}

figure_draw_detached_legend_plot <- function(p_raw, ov, ex, rect, canvas_w, canvas_h, draw_legend = TRUE) {
  prepared <- figure_export_plot_spec(p_raw, ov, ex, rect)
  if (!is.list(prepared) || !is.list(prepared$sp) || is.null(prepared$sp$plot)) return(NULL)
  sp <- prepared$sp
  asset <- prepared$legend_asset
  lg <- if (is.list(asset) && !is.null(asset$grob)) asset$grob else NULL
  leg <- figure_layer_legend_bbox(sp)
  pos <- figure_layer_legend_canvas_position(rect, sp, ov)
  if (is.null(leg) || is.null(pos) || is.null(lg)) return(NULL)

  off <- figure_plot_offsets(rect, sp, ov)
  ml <- rect$x + off$dx
  mt <- rect$y + off$dy
  band <- min(max(0, figure_label_band(ov)), max(0, rect$height - 1))
  clip_box <- NULL
  cr <- figure_crop_fractions(ov)
  if (isTRUE(cr$enabled)) {
    clip_h <- max(1, rect$height - band)
    clip_box <- list(
      x=(rect$x + rect$width/2)/canvas_w,
      y=1-(rect$y + band + clip_h/2)/canvas_h,
      width=rect$width/canvas_w, height=clip_h/canvas_h
    )
  }
  figure_draw_plot_grob_cropped(
    ggplot2::ggplotGrob(sp$plot),
    (ml + sp$width/2)/canvas_w,
    1-(mt + sp$height/2)/canvas_h,
    sp$width/canvas_w, sp$height/canvas_h,
    crop=ov$crop, clip_box=clip_box
  )

  job <- list(
    grob=lg, x=pos$x, y=pos$y,
    width=leg$width, height=leg$height,
    background=figure_detached_legend_background_mode(ov)
  )
  if (isTRUE(draw_legend)) {
    grid::pushViewport(grid::viewport(
      x=(job$x + job$width/2)/canvas_w, y=1-(job$y + job$height/2)/canvas_h,
      width=job$width/canvas_w, height=job$height/canvas_h,
      just=c("center","center"), clip="off"
    ))
    if (identical(job$background, "white")) {
      grid::grid.rect(gp=grid::gpar(fill="white", col=NA))
    }
    grid::grid.draw(lg)
    grid::popViewport()
  }
  list(sp=sp, legend_job=job)
}

figure_export_inset_record <- function(id, inset_snapshots = list(), persisted_previews = list()) {
  id <- as.character(id %||% "")[1]
  if (!nzchar(id)) return(list())
  rec <- inset_snapshots[[id]]
  if (is.list(rec) && (isTRUE(valid_graph_preview_record(rec)) || !is.null(rec$figure_plot))) return(rec)

  # Legacy Project compatibility mirrors the Viewer: old packs may have only
  # a persisted Figure preview and no dedicated Inset snapshot. New sessions
  # create a dedicated Inset snapshot on first source selection.
  legacy <- persisted_previews[[id]]
  if (is.list(legacy) && nzchar(as.character(legacy$svg %||% "")[1])) return(legacy)
  list()
}

figure_draw_to_device <- function(layout, canvas_w, canvas_h, overrides, plots, exports,
                                  gap_x = 12, gap_y = 12, rects = NULL,
                                  external_assets = list(), inset_snapshots = list(),
                                  persisted_previews = list()) {
  if (is.null(rects)) rects <- figure_layout_rects(layout, canvas_w, canvas_h, gap_x, gap_y)
  grid::grid.newpage()
  # F1-4 export follows the same visual layer order as Preview. Graph/Inset
  # bodies are emitted first; detached legends then labels are drawn in later
  # passes so a neighbour Graph can never cover a Figure-layer legend/label.
  inset_jobs <- list()
  legend_jobs <- list()
  label_jobs <- list()
  drawn_ids <- character(0)
  persisted_svg_ids <- character(0)
  missing_ids <- character(0)

  for (rect in rects) {
    id <- as.character(rect$id %||% "")
    if (!nzchar(id)) next
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), rect)

    # External asset export is intentionally conservative in alpha1. SVG/raster
    # preview is supported without adding image-decoder dependencies; export
    # emits a placeholder frame until Work audit selects a dependency-free
    # raster/SVG import path.
    if (id %in% names(external_assets)) {
      x <- (rect$x + rect$width / 2) / canvas_w
      y <- 1 - (rect$y + rect$height / 2) / canvas_h
      grid::grid.rect(
        x = grid::unit(x, "npc"), y = grid::unit(y, "npc"),
        width = grid::unit(rect$width / canvas_w, "npc"),
        height = grid::unit(rect$height / canvas_h, "npc"),
        gp = grid::gpar(fill = NA, col = "grey70", lty = 2)
      )
      grid::grid.text(
        paste0("Asset: ", external_assets[[id]]$name %||% id),
        x = grid::unit(x, "npc"), y = grid::unit(y, "npc"),
        gp = grid::gpar(fontsize = 8)
      )
      drawn_ids <- c(drawn_ids, id)
      next
    }

    p_loaded <- plots[[id]]
    ex <- exports[[id]] %||% list(
      plot_width_px = 600, plot_height_px = 600,
      panel_width_px = 600, panel_height_px = 600, reference_res = 120
    )
    sp <- NULL
    if (is.null(p_loaded)) {
      # Cache-first / legacy Project: use the exact Figure-owned SVG snapshot.
      # This branch is export-only and never mutates Figure or Graph state.
      persisted_export <- tryCatch(
        figure_draw_persisted_svg_panel(
          persisted_previews[[id]], ov, rect, canvas_w, canvas_h, draw_legend=FALSE
        ),
        error=function(e) NULL
      )
      if (!is.list(persisted_export) || !is.list(persisted_export$sp)) {
        missing_ids <- c(missing_ids, id)
        next
      }
      sp <- persisted_export$sp
      if (is.list(persisted_export$legend_job)) legend_jobs[[length(legend_jobs)+1L]] <- persisted_export$legend_job
      persisted_svg_ids <- c(persisted_svg_ids, id)
    } else {
      detached_export <- NULL
      if (figure_legend_is_detached(ov)) {
        detached_export <- tryCatch(
          figure_draw_detached_legend_plot(p_loaded, ov, ex, rect, canvas_w, canvas_h, draw_legend=FALSE),
          error=function(e) NULL
        )
      }
      if (is.list(detached_export)) {
        sp <- detached_export$sp
        if (is.list(detached_export$legend_job)) legend_jobs[[length(legend_jobs)+1L]] <- detached_export$legend_job
      } else {
        prepared <- figure_export_plot_spec(p_loaded, ov, ex, rect)
        sp <- if (is.list(prepared)) prepared$sp else NULL
        if (is.null(sp) || is.null(sp$plot)) {
          missing_ids <- c(missing_ids, id)
          next
        }
        crop_geo <- figure_crop_render_geometry(rect, sp, ov)
        band <- min(max(0, figure_label_band(ov)), max(0, rect$height - 1))
        full_left <- rect$x + crop_geo$shell_left + crop_geo$inner_left
        full_top <- rect$y + crop_geo$shell_top + crop_geo$inner_top
        cx <- (full_left + sp$width / 2) / canvas_w
        cy <- 1 - (full_top + sp$height / 2) / canvas_h
        clip_box <- NULL
        if (isTRUE(crop_geo$enabled)) {
          clip_h <- max(1, rect$height - band)
          clip_box <- list(
            x = (rect$x + rect$width / 2) / canvas_w,
            y = 1 - (rect$y + band + clip_h / 2) / canvas_h,
            width = rect$width / canvas_w,
            height = clip_h / canvas_h
          )
        }
        figure_draw_plot_grob_cropped(
          ggplot2::ggplotGrob(sp$plot), cx, cy,
          sp$width / canvas_w, sp$height / canvas_h,
          crop = ov$crop, clip_box = clip_box
        )
      }
    }
    drawn_ids <- c(drawn_ids, id)

    # F1-5 Inset layer: placement/size use the owner Graph display frame,
    # matching Preview. Queue after Graph bodies so neighbouring Graphs cannot
    # cover an Inset. External assets retain the alpha placeholder export path.
    inset <- ov$inset %||% figure_default_inset()
    inset_pos <- figure_layer_inset_canvas_position(rect, sp, ov)
    if (!is.null(inset_pos)) {
      iid <- as.character(inset$source_id %||% "")[1]
      inset_rec <- figure_export_inset_record(iid, inset_snapshots, persisted_previews)
      ibox <- figure_inset_export_content_box(inset_pos, inset)
      ip <- inset_rec$figure_plot
      iex <- inset_rec$figure_export %||% exports[[iid]] %||% list(
        plot_width_px = 600, plot_height_px = 600,
        panel_width_px = 600, panel_height_px = 600, reference_res = 120
      )
      if (nzchar(iid) && !is.null(ibox) && nzchar(inset_rec$svg %||% "")) {
        # WYSIWYG contract: Preview displays the frozen Figure-owned Inset SVG,
        # so export must consume that same SVG rather than rebuilding ggplot at
        # a new device size (which changes margins, axes and typography).
        ig <- figure_svg_snapshot_grob(inset_rec$svg, ibox$width, ibox$height)
        if (!is.null(ig)) {
          inset_jobs[[length(inset_jobs)+1L]] <- list(
            kind = "snapshot", grob = ig,
            x = inset_pos$x, y = inset_pos$y,
            width = inset_pos$width, height = inset_pos$height,
            content_x = ibox$x, content_y = ibox$y,
            content_width = ibox$width, content_height = ibox$height,
            border = isTRUE(inset$border), border_width = ibox$border_width
          )
        }
      } else if (nzchar(iid) && !is.null(ibox) && !is.null(ip)) {
        # Legacy/in-memory compatibility only: modern Inset snapshots always
        # carry SVG. Keep a plot fallback for unusual pre-snapshot records.
        iov <- figure_default_override(iid)
        fake_rect <- list(
          x = 0, y = 0, width = ibox$width, height = ibox$height,
          graph_width = NA_real_, graph_height = NA_real_, auto_fit = FALSE
        )
        prepared_inset <- tryCatch(figure_export_plot_spec(ip, iov, iex, fake_rect), error = function(e) NULL)
        isp <- if (is.list(prepared_inset)) prepared_inset$sp else NULL
        if (!is.null(isp) && !is.null(isp$plot)) {
          inset_jobs[[length(inset_jobs)+1L]] <- list(
            kind = "plot", grob = ggplot2::ggplotGrob(isp$plot),
            x = inset_pos$x, y = inset_pos$y,
            width = inset_pos$width, height = inset_pos$height,
            content_x = ibox$x, content_y = ibox$y,
            content_width = ibox$width, content_height = ibox$height,
            border = isTRUE(inset$border), border_width = ibox$border_width
          )
        }
      } else if (nzchar(iid) && iid %in% names(external_assets)) {
        inset_jobs[[length(inset_jobs)+1L]] <- list(
          kind = "asset-placeholder", name = external_assets[[iid]]$name %||% iid,
          x = inset_pos$x, y = inset_pos$y,
          width = inset_pos$width, height = inset_pos$height,
          border = isTRUE(inset$border), border_width = inset$border_width %||% 1
        )
      }
    }

    if (nzchar(ov$panel_label)) {
      label_pos <- figure_label_position(rect, sp, ov)
      label_jobs[[length(label_jobs)+1L]] <- list(
        text=ov$panel_label, x=rect$x + label_pos$x, y=rect$y + label_pos$y,
        size=ov$label_size
      )
    }
  }

  # Inset layer (above every Graph body, below legends/labels).
  for (job in inset_jobs) {
    grid::pushViewport(grid::viewport(
      x=(job$x + job$width/2)/canvas_w, y=1-(job$y + job$height/2)/canvas_h,
      width=job$width/canvas_w, height=job$height/canvas_h,
      just=c("center","center"), clip="on"
    ))

    # Match the Viewer box model: white background belongs to the outer Inset
    # box, content is confined inside the border, and the border is painted last.
    if (isTRUE(job$border)) {
      grid::grid.rect(gp = grid::gpar(fill = "white", col = NA))
    }

    if ((job$kind %||% "") %in% c("snapshot", "plot") && !is.null(job$grob)) {
      cw <- suppressWarnings(as.numeric(job$content_width %||% job$width)[1])
      ch <- suppressWarnings(as.numeric(job$content_height %||% job$height)[1])
      cx <- suppressWarnings(as.numeric(job$content_x %||% job$x)[1])
      cy <- suppressWarnings(as.numeric(job$content_y %||% job$y)[1])
      if (!all(is.finite(c(cw, ch, cx, cy))) || cw <= 0 || ch <= 0) {
        cw <- job$width; ch <- job$height; cx <- job$x; cy <- job$y
      }
      grid::pushViewport(grid::viewport(
        x=(cx - job$x + cw/2)/job$width,
        y=1-(cy - job$y + ch/2)/job$height,
        width=cw/job$width, height=ch/job$height,
        just=c("center","center"), clip="on"
      ))
      grid::grid.draw(job$grob)
      grid::popViewport()
    } else if (identical(job$kind %||% "", "asset-placeholder")) {
      grid::grid.rect(gp = grid::gpar(fill = NA, col = "grey70", lty = 2))
      grid::grid.text(paste0("Asset: ", job$name %||% ""), gp = grid::gpar(fontsize = 8))
    }

    if (isTRUE(job$border)) {
      grid::grid.rect(gp = grid::gpar(fill = NA, col = "grey30", lwd = job$border_width %||% 1))
    }
    grid::popViewport()
  }

  # Legend layer (above every Graph/Inset).
  for (job in legend_jobs) {
    grid::pushViewport(grid::viewport(
      x=(job$x + job$width/2)/canvas_w, y=1-(job$y + job$height/2)/canvas_h,
      width=job$width/canvas_w, height=job$height/canvas_h,
      just=c("center","center"), clip="off"
    ))
    if (identical(job$background %||% "transparent", "white")) {
      grid::grid.rect(gp=grid::gpar(fill="white", col=NA))
    }
    grid::grid.draw(job$grob)
    grid::popViewport()
  }

  # Label layer (above legends, matching Preview z-order).
  for (job in label_jobs) {
    grid::grid.text(
      job$text,
      x=grid::unit(job$x/canvas_w, "npc"),
      y=grid::unit(1-job$y/canvas_h, "npc"),
      just=c("left","top"),
      gp=grid::gpar(fontsize=job$size * 72 / 120, fontface="bold")
    )
  }
  list(
    drawn_ids = unique(drawn_ids),
    persisted_svg_ids = unique(persisted_svg_ids),
    missing_ids = unique(missing_ids)
  )
}

# -----------------------------------------------------------------------------
# F1-5m: vector-preserving SVG Figure compositor
# -----------------------------------------------------------------------------
figure_svg_escape_text <- function(x) {
  x <- as.character(x %||% "")[1]
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

figure_svg_fragment_parts <- function(svg_text, prefix = "fig") {
  txt <- as.character(svg_text %||% "")[1]
  if (!nzchar(txt) || !grepl("<svg\\b", txt, perl = TRUE)) return(NULL)
  root <- regmatches(txt, regexpr("<svg\\b[^>]*>", txt, perl = TRUE))
  if (!length(root) || !nzchar(root)) return(NULL)

  attr_value <- function(nm) {
    hit <- regmatches(root, regexpr(paste0(nm, '="[^"]+"'), root, perl=TRUE, ignore.case=TRUE))
    if (length(hit) && nzchar(hit)) return(sub('^[^=]+="([^"]+)"$', '\\1', hit, perl=TRUE))
    hit <- regmatches(root, regexpr(paste0(nm, "='[^']+'"), root, perl=TRUE, ignore.case=TRUE))
    if (length(hit) && nzchar(hit)) return(sub("^[^=]+='([^']+)'$", '\\1', hit, perl=TRUE))
    ""
  }
  vb_txt <- attr_value("viewBox")
  nums <- if (nzchar(vb_txt)) suppressWarnings(as.numeric(strsplit(trimws(vb_txt), "[ ,]+", perl=TRUE)[[1]])) else numeric(0)
  if (length(nums) != 4L || any(!is.finite(nums)) || nums[3] <= 0 || nums[4] <= 0) {
    ww <- suppressWarnings(as.numeric(sub("[^0-9.+-eE].*$", "", attr_value("width"), perl=TRUE)))
    hh <- suppressWarnings(as.numeric(sub("[^0-9.+-eE].*$", "", attr_value("height"), perl=TRUE)))
    if (!is.finite(ww) || ww <= 0 || !is.finite(hh) || hh <= 0) return(NULL)
    nums <- c(0, 0, ww, hh)
  }

  inner <- sub("^[\\s\\S]*?<svg\\b[^>]*>", "", txt, perl = TRUE)
  inner <- sub("</svg>\\s*$", "", inner, perl = TRUE, ignore.case = TRUE)

  # F1-5n: svglite fixes every text run to an R-side font metric using
  # textLength + lengthAdjust=spacingAndGlyphs. Browsers generally honour this,
  # but Illustrator may create an undersized editable text box when its local
  # font metrics differ, which can clip the final glyph (e.g. CTL -> CT).
  # For Figure SVG export, prefer native editable point text: keep x/y/anchor,
  # font family/size/style, but let the SVG consumer calculate glyph advances.
  textlength_hits <- regmatches(inner, gregexpr("\\s+textLength=(\"[^\"]*\"|'[^']*')", inner, perl=TRUE))[[1]]
  textlength_n <- if (length(textlength_hits) == 1L && identical(textlength_hits[1], "")) 0L else length(textlength_hits)
  inner <- gsub("\\s+textLength=(\"[^\"]*\"|'[^']*')", "", inner, perl=TRUE)
  inner <- gsub("\\s+lengthAdjust=(\"[^\"]*\"|'[^']*')", "", inner, perl=TRUE)

  # Multiple svglite fragments often reuse clipPath IDs. Namespace IDs before
  # merging them into one document so references cannot leak across Panels.
  ids_d <- regmatches(inner, gregexpr('\\bid="[^"]+"', inner, perl=TRUE))[[1]]
  ids_s <- regmatches(inner, gregexpr("\\bid='[^']+'", inner, perl=TRUE))[[1]]
  ids_d <- if (length(ids_d) == 1L && identical(ids_d[1], "")) character(0) else ids_d
  ids_s <- if (length(ids_s) == 1L && identical(ids_s[1], "")) character(0) else ids_s
  old_ids <- unique(c(
    if (length(ids_d)) sub('^id="([^"]+)"$', '\\1', ids_d, perl=TRUE) else character(0),
    if (length(ids_s)) sub("^id='([^']+)'$", '\\1', ids_s, perl=TRUE) else character(0)
  ))
  for (oid in old_ids[nzchar(old_ids)]) {
    nid <- paste0(prefix, "_", gsub("[^A-Za-z0-9_.:-]", "_", oid))
    inner <- gsub(paste0('id="', oid, '"'), paste0('id="', nid, '"'), inner, fixed=TRUE)
    inner <- gsub(paste0("id='", oid, "'"), paste0('id="', nid, '"'), inner, fixed=TRUE)
    inner <- gsub(paste0('url(#', oid, ')'), paste0('url(#', nid, ')'), inner, fixed=TRUE)
    inner <- gsub(paste0('href="#', oid, '"'), paste0('href="#', nid, '"'), inner, fixed=TRUE)
    inner <- gsub(paste0("href='#", oid, "'"), paste0('href="#', nid, '"'), inner, fixed=TRUE)
    inner <- gsub(paste0('xlink:href="#', oid, '"'), paste0('xlink:href="#', nid, '"'), inner, fixed=TRUE)
    inner <- gsub(paste0("xlink:href='#", oid, "'"), paste0('xlink:href="#', nid, '"'), inner, fixed=TRUE)
  }
  list(inner = inner, viewbox = nums, textlength_removed = as.integer(textlength_n))
}

figure_svg_place_fragment <- function(svg_text, x, y, width, height, prefix,
                                      clip_id = NULL, opacity = 1,
                                      fit = c("stretch", "meet")) {
  z <- figure_svg_fragment_parts(svg_text, prefix = prefix)
  if (is.null(z)) return(NULL)
  fit <- match.arg(fit)
  vb <- z$viewbox

  if (identical(fit, "meet")) {
    # Match the Viewer contract (`preserveAspectRatio="xMidYMid meet"`): keep
    # the snapshot aspect ratio and centre it inside the requested box.
    sc <- min(width / vb[3], height / vb[4])
    draw_w <- vb[3] * sc
    draw_h <- vb[4] * sc
    tx <- x + (width - draw_w) / 2
    ty <- y + (height - draw_h) / 2
    tr <- sprintf(
      "translate(%.6f %.6f) scale(%.9f %.9f) translate(%.6f %.6f)",
      tx, ty, sc, sc, -vb[1], -vb[2]
    )
  } else {
    sx <- width / vb[3]; sy <- height / vb[4]
    tr <- sprintf(
      "translate(%.6f %.6f) scale(%.9f %.9f) translate(%.6f %.6f)",
      x, y, sx, sy, -vb[1], -vb[2]
    )
  }

  attrs <- c(sprintf('transform="%s"', tr))
  if (is.finite(opacity) && opacity < 1) attrs <- c(attrs, sprintf('opacity="%.6f"', opacity))
  fragment <- paste0("<g ", paste(attrs, collapse=" "), ">", z$inner, "</g>")

  # clipPathUnits=userSpaceOnUse is expressed in the root Figure coordinate
  # system. Apply that clip outside the translated/scaled fragment so the clip
  # rectangle is not transformed a second time.
  out <- if (!is.null(clip_id) && nzchar(clip_id)) {
    paste0('<g clip-path="url(#', clip_id, ')">', fragment, '</g>')
  } else {
    fragment
  }
  attr(out, "textlength_removed") <- as.integer(z$textlength_removed %||% 0L)
  out
}

figure_inset_export_content_box <- function(inset_pos, inset) {
  if (!is.list(inset_pos)) return(NULL)
  x <- suppressWarnings(as.numeric(inset_pos$x %||% NA_real_)[1])
  y <- suppressWarnings(as.numeric(inset_pos$y %||% NA_real_)[1])
  w <- suppressWarnings(as.numeric(inset_pos$width %||% NA_real_)[1])
  h <- suppressWarnings(as.numeric(inset_pos$height %||% NA_real_)[1])
  if (any(!is.finite(c(x, y, w, h))) || w <= 0 || h <= 0) return(NULL)

  bw <- 0
  if (isTRUE((inset %||% list())$border)) {
    bw <- suppressWarnings(as.numeric((inset %||% list())$border_width %||% 1)[1])
    if (!is.finite(bw) || bw < 0) bw <- 0
    bw <- min(bw, max(0, min(w, h) / 2 - 0.5))
  }

  list(
    x = x + bw,
    y = y + bw,
    width = max(1, w - 2 * bw),
    height = max(1, h - 2 * bw),
    border_width = bw,
    outer_x = x,
    outer_y = y,
    outer_width = w,
    outer_height = h
  )
}

figure_write_svg_vector <- function(path, layout, canvas_w, canvas_h, overrides, plots, exports,
                                    gap_x = 12, gap_y = 12, rects = NULL,
                                    external_assets = list(), inset_snapshots = list(),
                                    persisted_previews = list(), reference_res = 120) {
  if (is.null(rects)) rects <- figure_layout_rects(layout, canvas_w, canvas_h, gap_x, gap_y)
  defs <- character(0); body_jobs <- character(0); inset_jobs <- character(0)
  legend_jobs <- character(0); label_jobs <- character(0)
  drawn_ids <- character(0); persisted_svg_ids <- character(0); missing_ids <- character(0)
  textlength_removed_n <- 0L
  clip_n <- 0L; frag_n <- 0L
  next_prefix <- function(tag="f") { frag_n <<- frag_n + 1L; paste0("f15m_", tag, "_", frag_n) }
  make_clip <- function(x, y, w, h) {
    clip_n <<- clip_n + 1L; cid <- paste0("f15m_clip_", clip_n)
    defs <<- c(defs, sprintf('<clipPath id="%s" clipPathUnits="userSpaceOnUse"><rect x="%.6f" y="%.6f" width="%.6f" height="%.6f"/></clipPath>', cid, x, y, w, h))
    cid
  }

  for (rect in rects) {
    id <- as.character(rect$id %||% "")
    if (!nzchar(id)) next
    ov <- figure_apply_slot_label_to_override(figure_override_for(id, overrides), rect)

    if (id %in% names(external_assets)) {
      # Preserve the existing alpha placeholder semantics; SVG file assets can
      # already be rendered inline by the Preview but external export remains
      # intentionally conservative until its own export contract is promoted.
      body_jobs <- c(body_jobs, sprintf('<rect x="%.6f" y="%.6f" width="%.6f" height="%.6f" fill="none" stroke="#B3B3B3" stroke-dasharray="4,4"/>', rect$x, rect$y, rect$width, rect$height))
      body_jobs <- c(body_jobs, sprintf('<text x="%.6f" y="%.6f" text-anchor="middle" font-family="sans-serif" font-size="8">%s</text>', rect$x+rect$width/2, rect$y+rect$height/2, figure_svg_escape_text(paste0("Asset: ", external_assets[[id]]$name %||% id))))
      drawn_ids <- c(drawn_ids, id)
      next
    }

    p_loaded <- plots[[id]]
    ex <- exports[[id]] %||% list(plot_width_px=600, plot_height_px=600, panel_width_px=600, panel_height_px=600, reference_res=reference_res)
    sp <- NULL; body_svg <- ""; legend_svg <- ""; legend_job <- NULL

    if (is.null(p_loaded)) {
      preview <- persisted_previews[[id]]
      sp <- tryCatch(figure_persisted_spec_for_rect(preview, rect, ov), error=function(e) NULL)
      if (is.null(sp) || !nzchar(sp$persisted_svg %||% "")) { missing_ids <- c(missing_ids,id); next }
      body_svg <- as.character(sp$persisted_svg %||% "")[1]
      if (figure_legend_is_detached(ov)) legend_svg <- as.character(sp$legend_svg_text %||% "")[1]
      persisted_svg_ids <- c(persisted_svg_ids, id)
    } else {
      prepared <- tryCatch(figure_export_plot_spec(p_loaded, ov, ex, rect), error=function(e) NULL)
      if (!is.list(prepared) || !is.list(prepared$sp) || is.null(prepared$sp$plot)) { missing_ids <- c(missing_ids,id); next }
      sp <- prepared$sp
      body_svg <- figure_plot_svg_text(sp$plot, sp$width, sp$height, ex$reference_res %||% reference_res) %||% ""
      if (!nzchar(body_svg)) { missing_ids <- c(missing_ids,id); next }
      if (figure_legend_is_detached(ov) && is.list(prepared$legend_asset)) {
        legend_svg <- as.character(prepared$legend_asset$svg %||% "")[1]
      }
    }

    crop_geo <- figure_crop_render_geometry(rect, sp, ov)
    band <- min(max(0, figure_label_band(ov)), max(0, rect$height - 1))
    full_left <- rect$x + crop_geo$shell_left + crop_geo$inner_left
    full_top <- rect$y + crop_geo$shell_top + crop_geo$inner_top
    clip_id <- NULL
    if (isTRUE(crop_geo$enabled)) clip_id <- make_clip(rect$x, rect$y + band, rect$width, max(1, rect$height-band))
    placed <- figure_svg_place_fragment(body_svg, full_left, full_top, sp$width, sp$height, next_prefix("body"), clip_id=clip_id)
    if (is.null(placed)) { missing_ids <- c(missing_ids,id); next }
    textlength_removed_n <- textlength_removed_n + as.integer(attr(placed, "textlength_removed") %||% 0L)
    body_jobs <- c(body_jobs, placed)
    drawn_ids <- c(drawn_ids,id)

    if (figure_legend_is_detached(ov) && nzchar(legend_svg)) {
      leg <- figure_layer_legend_bbox(sp); pos <- figure_layer_legend_canvas_position(rect, sp, ov)
      if (!is.null(leg) && !is.null(pos)) {
        if (identical(figure_detached_legend_background_mode(ov), "white")) {
          legend_jobs <- c(legend_jobs, sprintf('<rect x="%.6f" y="%.6f" width="%.6f" height="%.6f" fill="#FFFFFF" stroke="none"/>', pos$x, pos$y, leg$width, leg$height))
        }
        z <- figure_svg_place_fragment(legend_svg, pos$x, pos$y, leg$width, leg$height, next_prefix("legend"))
        if (!is.null(z)) {
          textlength_removed_n <- textlength_removed_n + as.integer(attr(z, "textlength_removed") %||% 0L)
          legend_jobs <- c(legend_jobs,z)
        }
      }
    }

    inset <- ov$inset %||% figure_default_inset()
    inset_pos <- figure_layer_inset_canvas_position(rect, sp, ov)
    if (!is.null(inset_pos)) {
      iid <- as.character(inset$source_id %||% "")[1]
      inset_rec <- figure_export_inset_record(iid, inset_snapshots, persisted_previews)
      ibox <- figure_inset_export_content_box(inset_pos, inset)
      ip <- inset_rec$figure_plot
      iex <- inset_rec$figure_export %||% exports[[iid]] %||% list(plot_width_px=600,plot_height_px=600,panel_width_px=600,panel_height_px=600,reference_res=reference_res)
      isvg <- ""

      # Viewer and vector export must consume the exact same frozen Inset SVG.
      # Re-rendering `figure_plot` at the small Inset box changes ggplot layout,
      # margins and text metrics and therefore cannot be WYSIWYG.
      if (nzchar(iid) && nzchar(inset_rec$svg %||% "")) {
        isvg <- as.character(inset_rec$svg)[1]
      } else if (nzchar(iid) && !is.null(ibox) && !is.null(ip)) {
        # Compatibility fallback for unusual legacy/in-memory records lacking SVG.
        iov <- figure_default_override(iid)
        fake_rect <- list(x=0,y=0,width=ibox$width,height=ibox$height,graph_width=NA_real_,graph_height=NA_real_,auto_fit=FALSE)
        pi <- tryCatch(figure_export_plot_spec(ip,iov,iex,fake_rect), error=function(e) NULL)
        isp <- if (is.list(pi)) pi$sp else NULL
        if (!is.null(isp) && !is.null(isp$plot)) isvg <- figure_plot_svg_text(isp$plot, ibox$width, ibox$height, iex$reference_res %||% reference_res) %||% ""
      }

      if (nzchar(isvg) && !is.null(ibox)) {
        if (isTRUE(inset$border)) {
          inset_jobs <- c(inset_jobs, sprintf(
            '<rect x="%.6f" y="%.6f" width="%.6f" height="%.6f" fill="#FFFFFF" stroke="none"/>',
            inset_pos$x, inset_pos$y, inset_pos$width, inset_pos$height
          ))
        }
        iclip <- make_clip(ibox$x, ibox$y, ibox$width, ibox$height)
        z <- figure_svg_place_fragment(
          isvg, ibox$x, ibox$y, ibox$width, ibox$height,
          next_prefix("inset"), clip_id=iclip, fit="meet"
        )
        if (!is.null(z)) {
          textlength_removed_n <- textlength_removed_n + as.integer(attr(z, "textlength_removed") %||% 0L)
          inset_jobs <- c(inset_jobs,z)
        }
        if (isTRUE(inset$border)) {
          inset_jobs <- c(inset_jobs, sprintf(
            '<rect x="%.6f" y="%.6f" width="%.6f" height="%.6f" fill="none" stroke="#4D4D4D" stroke-width="%.6f"/>',
            inset_pos$x, inset_pos$y, inset_pos$width, inset_pos$height,
            ibox$border_width
          ))
        }
      }
    }

    if (nzchar(ov$panel_label)) {
      lp <- figure_label_position(rect, sp, ov)
      label_jobs <- c(label_jobs, sprintf('<text x="%.6f" y="%.6f" font-family="sans-serif" font-size="%.6f" font-weight="bold" text-anchor="start" dominant-baseline="hanging">%s</text>', rect$x+lp$x, rect$y+lp$y, as.numeric(ov$label_size %||% 18), figure_svg_escape_text(ov$panel_label)))
    }
  }

  if (length(missing_ids)) return(list(drawn_ids=unique(drawn_ids), persisted_svg_ids=unique(persisted_svg_ids), missing_ids=unique(missing_ids)))
  width_in <- canvas_w / reference_res; height_in <- canvas_h / reference_res
  doc <- c(
    '<?xml version="1.0" encoding="UTF-8"?>',
    sprintf('<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="%.6fin" height="%.6fin" viewBox="0 0 %.6f %.6f">', width_in,height_in,canvas_w,canvas_h),
    if (length(defs)) paste0('<defs>', paste(defs,collapse="\n"), '</defs>') else '',
    body_jobs, inset_jobs, legend_jobs, label_jobs, '</svg>'
  )
  writeLines(doc, path, useBytes=TRUE)
  list(drawn_ids=unique(drawn_ids), persisted_svg_ids=unique(persisted_svg_ids), missing_ids=character(0), vector_svg=TRUE, textlength_removed=as.integer(textlength_removed_n))
}
