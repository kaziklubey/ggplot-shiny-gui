# R/figure/figure_state.R — Figure responsibility module
# v3.4.0-alpha4: differential audit hardening for Figure state ownership / commit / geometry.
# v3.3.78 remains the golden/stable baseline.

figure_make_cell <- function(row, col, id = "", width = 1, source_type = "internal_graph", source_id = NULL,
                             graph_width = NA_real_, graph_height = NA_real_,
                             free_x = NA_real_, free_y = NA_real_, free_width = NA_real_, free_height = NA_real_,
                             z_index = NA_real_, panel_label = "", panel_label_auto = TRUE,
                             label_size = 18, top_gutter = 32,
                             label_mode = "align", label_anchor = "panel",
                             label_x_offset = 0, label_y_offset = 0,
                             label_x = 0.06, label_y = 0.02) {
  sid <- as.character(source_id %||% id %||% "")[1]
  if (!length(sid) || is.na(sid)) sid <- ""
  stype <- as.character(source_type %||% "internal_graph")[1]
  if (!stype %in% c("internal_graph", "external_asset")) stype <- "internal_graph"
  list(
    id = sid,
    source_type = stype,
    source_id = sid,
    width = as.numeric(width %||% 1),
    graph_width = suppressWarnings(as.numeric(graph_width)[1]),
    graph_height = suppressWarnings(as.numeric(graph_height)[1]),
    free_x = suppressWarnings(as.numeric(free_x)[1]),
    free_y = suppressWarnings(as.numeric(free_y)[1]),
    free_width = suppressWarnings(as.numeric(free_width)[1]),
    free_height = suppressWarnings(as.numeric(free_height)[1]),
    z_index = suppressWarnings(as.numeric(z_index)[1]),
    # Panel labels are slot-owned.  Source/content swaps must never move A/B/C/D
    # or their label geometry with the Graph/Asset content.
    panel_label = { z <- as.character(panel_label %||% ""); if (!length(z) || is.na(z[[1]])) "" else z[[1]] },
    panel_label_auto = isTRUE(panel_label_auto),
    label_size = figure_num_or(label_size, 18, 6, 72),
    top_gutter = figure_num_or(top_gutter, 32, 0, 240),
    label_mode = {
      z <- as.character(label_mode %||% "align")
      if (!length(z) || is.na(z[[1]]) || !z[[1]] %in% c("align", "free")) "align" else z[[1]]
    },
    label_anchor = {
      a <- as.character(label_anchor %||% "panel")[1]
      if (identical(a, "plot_axis")) a <- "panel"
      if (a %in% c("panel", "plot_left", "cell_left")) a else "panel"
    },
    label_x_offset = figure_num_or(label_x_offset, 0, -300, 300),
    label_y_offset = figure_num_or(label_y_offset, 0, -300, 300),
    label_x = figure_num_or(label_x, 0.06, -0.2, 1.2),
    label_y = figure_num_or(label_y, 0.02, -0.2, 1.2),
    row = as.integer(row),
    col = as.integer(col),
    key = paste0("r", row, "_c", col)
  )
}

figure_num_or <- function(x, fallback = NA_real_, lo = -Inf, hi = Inf) {
  z <- suppressWarnings(as.numeric(x)[1])
  if (!is.finite(z)) return(fallback)
  min(max(z, lo), hi)
}

figure_reindex_layout <- function(st) {
  if (is.null(st) || !is.list(st) || !length(st)) return(list())
  # v3.80.8: Figure-wide column ratios are canonical layout metadata. Cell
  # `width` values are maintained only as a derived compatibility mirror for
  # older project/state consumers. Preserve the metadata before list slicing.
  saved_column_ratios <- attr(st, "column_ratios", exact = TRUE)
  if (length(st) > 12L) st <- st[seq_len(12L)]
  out <- vector("list", length(st))
  for (r in seq_along(st)) {
    row <- st[[r]]
    if (!is.list(row)) row <- list()
    cells <- row$cells %||% list()
    if (!is.list(cells)) cells <- list()
    nc <- suppressWarnings(as.integer(row$ncol %||% length(cells))[1])
    if (!is.finite(nc) || nc < 1L) nc <- 1L
    nc <- min(nc, 12L)
    hh <- figure_num_or(row$height, 1, 0.1, 10)
    basis_override <- figure_normalize_alignment_basis(row$size_basis %||% "inherit", fallback = "panel_legend", allow_inherit = TRUE)
    if (length(cells) < nc) {
      start <- length(cells) + 1L
      if (start <= nc) for (cc in seq.int(start, nc)) cells[[cc]] <- figure_make_cell(r, cc)
    }
    if (length(cells) > nc) cells <- cells[seq_len(nc)]
    for (cc in seq_len(nc)) {
      cell <- cells[[cc]]
      if (!is.list(cell)) cell <- list()
      stype <- as.character(cell$source_type %||% "internal_graph")[1]
      if (!stype %in% c("internal_graph", "external_asset")) stype <- "internal_graph"
      sid <- as.character(cell$source_id %||% cell$id %||% "")[1]
      if (!length(sid) || is.na(sid)) sid <- ""
      cells[[cc]] <- figure_make_cell(
        r, cc, sid,
        width = figure_num_or(cell$width, 1, 0.1, 10),
        source_type = stype, source_id = sid,
        graph_width = figure_num_or(cell$graph_width, NA_real_, 80, 5000),
        graph_height = figure_num_or(cell$graph_height, NA_real_, 80, 5000),
        free_x = figure_num_or(cell$free_x, NA_real_, -10000, 10000),
        free_y = figure_num_or(cell$free_y, NA_real_, -10000, 10000),
        free_width = figure_num_or(cell$free_width, NA_real_, 20, 10000),
        free_height = figure_num_or(cell$free_height, NA_real_, 20, 10000),
        z_index = figure_num_or(cell$z_index, cc + (r - 1L) * 12L, -1000, 1000),
        panel_label = as.character(cell$panel_label %||% "")[1],
        panel_label_auto = if (is.null(cell$panel_label_auto)) TRUE else isTRUE(cell$panel_label_auto),
        # alpha2 stored these on the source override.  During migration prefer
        # slot values when present; old projects get stable slot defaults.
        label_size = figure_num_or(cell$label_size, 18, 6, 72),
        top_gutter = figure_num_or(cell$top_gutter, 48, 0, 240),
        label_mode = as.character(cell$label_mode %||% "align")[1],
        label_anchor = as.character(cell$label_anchor %||% "panel")[1],
        label_x_offset = figure_num_or(cell$label_x_offset, 0, -300, 300),
        label_y_offset = figure_num_or(cell$label_y_offset, 0, -300, 300),
        label_x = figure_num_or(cell$label_x, 0.06, -0.2, 1.2),
        label_y = figure_num_or(cell$label_y, 0.02, -0.2, 1.2)
      )
    }
    out[[r]] <- list(row = r, height = hh, ncol = nc, size_basis = basis_override, cells = cells)
  }

  # v3.80.8 Fixed Canvas contract: column ratios are one Figure-wide vector.
  # New state stores that vector as layout metadata. Legacy Projects that only
  # have per-cell widths migrate deterministically from the first existing Row.
  # Cell widths remain a derived mirror so old project payloads can still cross
  # the load boundary without creating a second runtime layout path.
  max_col <- max(vapply(out, function(row) length(row$cells %||% list()), integer(1)), 0L)
  if (max_col > 0L) {
    raw_shared <- suppressWarnings(as.numeric(saved_column_ratios))
    shared <- rep(NA_real_, max_col)
    if (length(raw_shared)) {
      take <- seq_len(min(length(raw_shared), max_col))
      ok <- is.finite(raw_shared[take]) & raw_shared[take] > 0
      shared[take[ok]] <- pmin(pmax(raw_shared[take[ok]], 0.1), 10)
    }
    for (cc in seq_len(max_col)) {
      if (!is.finite(shared[[cc]])) {
        vals <- vapply(out, function(row) {
          cells <- row$cells %||% list()
          if (length(cells) < cc) return(NA_real_)
          figure_num_or(cells[[cc]]$width, NA_real_, 0.1, 10)
        }, numeric(1))
        vals <- vals[is.finite(vals)]
        shared[[cc]] <- if (length(vals)) vals[[1]] else 1
      }
      for (rr in seq_along(out)) {
        if (length(out[[rr]]$cells %||% list()) >= cc) out[[rr]]$cells[[cc]]$width <- shared[[cc]]
      }
    }
    attr(out, "column_ratios") <- shared
  }
  out
}

figure_sanitize_layout <- function(st, meta, auto_fill = FALSE, external_assets = list()) {
  st <- figure_reindex_layout(st)
  valid_graph <- as.character(meta$id %||% character(0))
  valid_asset <- names(external_assets %||% list())
  seen_graph <- character(0)
  cursor <- 1L
  for (r in seq_along(st)) {
    for (c in seq_along(st[[r]]$cells)) {
      cell <- st[[r]]$cells[[c]]
      typ <- as.character(cell$source_type %||% "internal_graph")[1]
      sid <- as.character(cell$source_id %||% cell$id %||% "")[1]
      if (identical(typ, "external_asset")) {
        if (!sid %in% valid_asset) sid <- ""
      } else {
        typ <- "internal_graph"
        if (!sid %in% valid_graph || sid %in% seen_graph) sid <- ""
        if (!nzchar(sid) && isTRUE(auto_fill)) {
          while (cursor <= length(valid_graph) && valid_graph[[cursor]] %in% seen_graph) cursor <- cursor + 1L
          if (cursor <= length(valid_graph)) {
            sid <- valid_graph[[cursor]]
            cursor <- cursor + 1L
          }
        }
        if (nzchar(sid)) seen_graph <- c(seen_graph, sid)
      }
      st[[r]]$cells[[c]]$id <- sid
      st[[r]]$cells[[c]]$source_type <- typ
      st[[r]]$cells[[c]]$source_id <- sid
    }
  }
  st
}


figure_normalize_legend_title_mode <- function(x) {
  # Backward compatibility: alpha1/alpha2 stored a logical checkbox.
  if (is.logical(x) && length(x)) return(if (isTRUE(x[[1]])) "show" else "hide")
  z <- as.character(x %||% "inherit")[1]
  if (!length(z) || is.na(z) || !z %in% c("inherit", "show", "hide")) z <- "inherit"
  z
}

figure_apply_slot_label_to_override <- function(ov, slot) {
  ov <- modifyList(figure_default_override(), ov %||% list())
  fields <- c(
    "panel_label", "label_size", "top_gutter", "label_mode", "label_anchor",
    "label_x_offset", "label_y_offset", "label_x", "label_y"
  )
  if (is.list(slot)) {
    for (nm in fields) if (!is.null(slot[[nm]])) ov[[nm]] <- slot[[nm]]
  }

  # RC13.4: slot payloads can legitimately arrive from a fresh/default Figure
  # with optional scalars represented as zero-length vectors.  The source
  # override was normalized before the Slot merge, so copying character(0) or
  # numeric(0) here could reintroduce invalid values and make downstream scalar
  # predicates such as `if (nzchar(ov$panel_label))` fail during editable PPTX
  # drawing.  Re-normalize only the Slot-owned label fields at this ownership
  # boundary.  Canonical Figure/Graph state is not mutated.
  normalized <- figure_slot_label_payload(ov)
  for (nm in setdiff(names(normalized), "panel_label_auto")) ov[[nm]] <- normalized[[nm]]
  ov
}

figure_slot_label_payload <- function(cell) {
  cell <- cell %||% list()
  list(
    panel_label = { z <- as.character(cell$panel_label %||% ""); if (!length(z) || is.na(z[[1]])) "" else z[[1]] },
    panel_label_auto = if (is.null(cell$panel_label_auto)) TRUE else isTRUE(cell$panel_label_auto),
    label_size = figure_num_or(cell$label_size, 18, 6, 72),
    top_gutter = figure_num_or(cell$top_gutter, 48, 0, 240),
    label_mode = {
      z <- as.character(cell$label_mode %||% "align")
      if (!length(z) || is.na(z[[1]]) || !z[[1]] %in% c("align", "free")) "align" else z[[1]]
    },
    label_anchor = {
      a <- as.character(cell$label_anchor %||% "panel")[1]
      if (identical(a, "plot_axis")) a <- "panel"
      if (a %in% c("panel", "plot_left", "cell_left")) a else "panel"
    },
    label_x_offset = figure_num_or(cell$label_x_offset, 0, -300, 300),
    label_y_offset = figure_num_or(cell$label_y_offset, 0, -300, 300),
    label_x = figure_num_or(cell$label_x, 0.06, -0.2, 1.2),
    label_y = figure_num_or(cell$label_y, 0.02, -0.2, 1.2)
  )
}

figure_strip_slot_label_fields_from_override <- function(ov) {
  ov <- ov %||% list()
  if (!is.list(ov)) ov <- list()
  # alpha3 contract: Panel label text/style/placement belong to the Slot, never
  # to the Graph/Asset source override.  Remove legacy alpha1/alpha2 copies at
  # persistence and migration boundaries so Swap/Shift cannot carry them.
  ov[c(
    "panel_label", "label_size", "top_gutter", "label_mode", "label_anchor",
    "label_x_offset", "label_y_offset", "label_x", "label_y"
  )] <- NULL
  ov
}


figure_default_appearance_override <- function() {
  list(
    title_mode = "inherit", title = "",
    xlab_mode = "inherit", xlab = "",
    ylab_mode = "inherit", ylab = "",
    base_size = NA_real_,
    axis_title_size = NA_real_,
    axis_text_size = NA_real_,
    color_mode = "inherit", color = "#000000",
    linetype_mode = "inherit", linetype = "solid",
    shape_mode = "inherit", shape = 16,
    alpha = NA_real_,
    point_size = NA_real_,
    line_width = NA_real_,
    ymin = NA_real_,
    ymax = NA_real_
  )
}

figure_default_external_legend <- function() {
  list(
    mode = "inherit",
    position = "right",
    x = 0.76, y = 0.08, width = 0.22, height = 0.30,
    gap = 8, scale = 1
  )
}

figure_default_crop <- function() {
  list(enabled = FALSE, left = 0, top = 0, right = 0, bottom = 0)
}

figure_default_inset <- function() {
  list(
    enabled = FALSE, source_type = "internal_graph", source_id = "",
    # F1-5: Inset is a Figure-owned overlay anchored to the owner Graph display
    # frame. X/Y/width/height are Graph-relative and remain independent of Crop.
    anchor = "graph",
    x = 0.62, y = 0.08, width = 0.32, height = 0.32,
    border = TRUE, border_width = 1, z_index = 20
  )
}

figure_default_override <- function(id = NULL) {
  list(
    # Panel label state is Slot-owned in alpha3 and is intentionally absent
    # from source-keyed overrides. Render helpers add normalized label defaults
    # only after the current Slot payload is known.
    legend = "inherit", legend_title = "inherit", legend_gap = 8,
    # Figure-only detached/free legend background. Does not alter the source Graph.
    legend_background = "transparent",
    # Legend placement has one detached mode only: free=Figure-canvas Legend layer.
    # Its X/Y are relative to the owning Graph display frame (not the Row/Panel),
    # while the legend visual itself stays unclipped on the Figure canvas.
    legend_mode = "align", legend_x = 0.72, legend_y = 0.08,
    legend_free_x = 0.75, legend_free_y = 0.08,
    # F1-4g schema marker. Older alpha builds stored these coordinates against
    # Plot/Panel/cell frames and therefore cannot be interpreted as Graph-relative.
    legend_free_anchor = "graph",
    # Detached layer lifecycle. `legend_free_auto` keeps the exact source
    # position until the user moves the detached overlay. Afterwards
    # `legend_free_x/y` are owner-Graph-relative coordinates and may exceed 0..1.
    legend_free_auto = FALSE, legend_free_origin = "inherit",
    # F1-4b: immutable extraction origin while the legend is detached.
    # Placement scope/x/y may change freely without changing this source.
    legend_source_origin = "inherit",
    legend_source_x = 0.72, legend_source_y = 0.08,
    legend_last_side = "",
    # Legacy F1-3b field: load/save compatibility only; never geometry authority.
    legend_detach_snapshot = NULL,
    align_h = "center", align_v = "center",
    crop = figure_default_crop(),
    inset = figure_default_inset(),
    appearance = figure_default_appearance_override(),
    external_legend = figure_default_external_legend()
  )
}


# Reset only Figure-owned free-placement coordinates.  Content, crop, style,
# layout order and mode choices remain untouched.  Detached legends re-arm the
# source-position bootstrap so "reset" means the same position as immediately
# after entering free mode, not a hard-coded canvas coordinate.
figure_reset_slot_free_positions <- function(cell) {
  if (!is.list(cell)) return(cell)
  cell$label_x_offset <- 0
  cell$label_y_offset <- 0
  cell$label_x <- 0.06
  cell$label_y <- 0.02
  cell
}

figure_reset_override_free_positions <- function(ov) {
  out <- modifyList(figure_default_override(), ov %||% list())
  def <- figure_default_override()

  if (identical(as.character(out$legend %||% "inherit")[1], "free")) {
    out$legend_free_x <- def$legend_free_x
    out$legend_free_y <- def$legend_free_y
    out$legend_x <- def$legend_x
    out$legend_y <- def$legend_y
    out$legend_free_auto <- TRUE
  }

  inset <- modifyList(figure_default_inset(), out$inset %||% list())
  inset$x <- def$inset$x
  inset$y <- def$inset$y
  out$inset <- inset

  exleg <- modifyList(figure_default_external_legend(), out$external_legend %||% list())
  exleg$x <- def$external_legend$x
  exleg$y <- def$external_legend$y
  out$external_legend <- exleg
  out
}

figure_default_layout_state <- function() {
  out <- list(
    list(
      row = 1L, height = 1, ncol = 2L, size_basis = "inherit",
      cells = list(figure_make_cell(1, 1), figure_make_cell(1, 2))
    )
  )
  attr(out, "column_ratios") <- c(1, 1)
  out
}

figure_default_workspace_state <- function() {
  list(
    schema_version = "3.80.8-global-column-ui1",
    layout_mode = "row",
    autofit_policy = "live",
    title_align = "none",
    free_canvas_padding = 24,
    external_assets = list(),
    layout = figure_default_layout_state(),
    column_ratios = c(1, 1),
    overrides = list()
  )
}
