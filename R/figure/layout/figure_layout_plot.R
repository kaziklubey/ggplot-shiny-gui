# R/figure/layout/figure_layout_plot.R — Figure plot overrides and rendered plot geometry helpers
# v3.80.6-refactor1: split from figure_layout.R.

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
  ov$label_anchor <- scalar_chr(ov$label_anchor, "panel")
  if (identical(ov$label_anchor, "plot_axis")) ov$label_anchor <- "panel"
  if (!ov$label_anchor %in% c("panel", "plot_left", "cell_left")) ov$label_anchor <- "panel"
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
    y <- max(2, (figure_label_band(ov) - ov$label_size) / 2)
  } else {
    # Figure panel labels belong to the Figure slot, not to ggplot title/facet
    # geometry. Anchor X to the aligned data-panel left edge, but keep Y in the
    # dedicated label band so A/B/C remain level even when only some Graphs
    # have facets or plot titles.
    panel_left <- suppressWarnings(as.numeric(sp$panel_left %||% 0))
    if (!is.finite(panel_left)) panel_left <- 0
    x <- off$dx + panel_left
    y <- max(2, (figure_label_band(ov) - ov$label_size) / 2)
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
# panel/basis contract therefore remains comparable across Graphs; outside
# decorations only consume/reserve footprint around that basis.
