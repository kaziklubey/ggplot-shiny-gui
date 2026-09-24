# R/figure/figure_interaction.R — Figure interaction state transitions
# v3.3.56: browser events are converted to deterministic state changes here.

figure_apply_layout_edit_state <- function(st, event, valid_graph_ids = character(0), valid_asset_ids = character(0)) {
  typ <- as.character(event$type %||% "")
  r <- suppressWarnings(as.integer(event$row %||% NA_integer_))
  c <- suppressWarnings(as.integer(event$col %||% NA_integer_))
  ans <- list(state = st, changed = FALSE, rebuild_ui = FALSE)

  # v3.80.8: column ratios are Figure-wide state, not Row/Panel state. Handle
  # them before Row validation and update the single shared column contract.
  if (identical(typ, "column_ratio")) {
    x <- suppressWarnings(as.numeric(event$value %||% NA_real_))
    if (!is.finite(c) || c < 1L || !is.finite(x) || x <= 0) return(ans)
    before <- figure_shared_column_ratios(st)
    if (c > length(before)) return(ans)
    x <- min(max(x, 0.1), 10)
    if (isTRUE(all.equal(before[[c]], x))) return(ans)
    st <- figure_set_shared_column_ratio(st, c, x)
    ans$state <- st
    ans$changed <- TRUE
    return(ans)
  }

  if (!is.finite(r) || r < 1L || r > length(st)) return(ans)

  if (identical(typ, "row_basis")) {
    x <- figure_normalize_alignment_basis(event$value %||% "inherit", fallback = "panel_legend", allow_inherit = TRUE)
    old <- as.character(st[[r]]$size_basis %||% "inherit")[1]
    if (!identical(old, x)) {
      st[[r]]$size_basis <- x
      ans$state <- st; ans$changed <- TRUE
    }
    return(ans)
  }

  if (identical(typ, "row_height")) {
    x <- suppressWarnings(as.numeric(event$value %||% NA_real_))
    if (!is.finite(x) || x <= 0) return(ans)
    x <- min(max(x, 0.1), 10)
    if (!isTRUE(all.equal(st[[r]]$height, x))) {
      st[[r]]$height <- x
      ans$state <- st; ans$changed <- TRUE
    }
    return(ans)
  }

  if (!is.finite(c) || c < 1L || c > st[[r]]$ncol) return(ans)

  if (typ %in% c("graph_width", "graph_height")) {
    raw <- as.character(event$value %||% "")[1]
    x <- suppressWarnings(as.numeric(raw))
    if (!nzchar(trimws(raw)) || !is.finite(x) || x <= 0) x <- NA_real_
    if (is.finite(x)) x <- min(max(x, 80), 3000)
    field <- if (identical(typ, "graph_width")) "graph_width" else "graph_height"
    old <- suppressWarnings(as.numeric(st[[r]]$cells[[c]][[field]] %||% NA_real_)[1])
    same <- (is.na(old) && is.na(x)) || (is.finite(old) && is.finite(x) && isTRUE(all.equal(old, x)))
    if (!same) {
      st[[r]]$cells[[c]][[field]] <- x
      ans$state <- st; ans$changed <- TRUE
    }
    return(ans)
  }

  if (typ %in% c("free_x", "free_y", "free_width", "free_height", "z_index")) {
    raw <- suppressWarnings(as.numeric(event$value %||% NA_real_))
    if (!is.finite(raw)) return(ans)
    if (typ %in% c("free_width", "free_height")) raw <- min(max(raw, 20), 10000)
    if (typ %in% c("free_x", "free_y")) raw <- min(max(raw, -10000), 10000)
    if (identical(typ, "z_index")) raw <- min(max(raw, -1000), 1000)
    old <- suppressWarnings(as.numeric(st[[r]]$cells[[c]][[typ]] %||% NA_real_)[1])
    if (!is.finite(old) || !isTRUE(all.equal(old, raw))) {
      st[[r]]$cells[[c]][[typ]] <- raw
      ans$state <- st; ans$changed <- TRUE
    }
    return(ans)
  }

  if (identical(typ, "panel_graph")) {
    id <- as.character(event$value %||% "")
    is_asset <- nzchar(id) && id %in% valid_asset_ids
    if (nzchar(id) && !id %in% c(valid_graph_ids, valid_asset_ids)) id <- ""
    used <- unique(unlist(lapply(seq_along(st), function(r2) {
      vapply(seq_along(st[[r2]]$cells), function(c2) {
        if (r2 == r && c2 == c) "" else as.character(st[[r2]]$cells[[c2]]$id %||% "")
      }, character(1))
    })))
    used <- used[nzchar(used)]
    if (nzchar(id) && id %in% used) id <- ""
    old_id <- as.character(st[[r]]$cells[[c]]$id %||% "")
    if (!identical(old_id, id)) {
      st[[r]]$cells[[c]]$id <- id
      st[[r]]$cells[[c]]$source_id <- id
      st[[r]]$cells[[c]]$source_type <- if (nzchar(id) && isTRUE(is_asset)) "external_asset" else "internal_graph"
      ans$state <- st; ans$changed <- TRUE; ans$rebuild_ui <- TRUE
    }
  }
  ans
}

figure_apply_drag_override_state <- function(ov, type, x, y, width = NULL, height = NULL, legend_scope = NULL) {
  ov <- modifyList(figure_default_override(), ov %||% list())
  typ <- as.character(type %||% "")
  xp <- suppressWarnings(as.numeric(x %||% NA_real_))
  yp <- suppressWarnings(as.numeric(y %||% NA_real_))
  if (!is.finite(xp) || !is.finite(yp) || !typ %in% c("label", "legend", "inset")) return(ov)
  xp <- min(max(xp, -2), 3)
  yp <- min(max(yp, -2), 3)
  if (identical(typ, "label")) {
    ov$label_mode <- "free"
    ov$label_x <- xp
    ov$label_y <- yp
  } else if (identical(typ, "legend")) {
    previous <- as.character(ov$legend %||% "inherit")[1]
    # F1-4g: direct manipulation has one placement mode only.  X/Y are
    # owner-Graph-relative and the visual itself lives on the Figure layer.
    ov$legend <- "free"
    if (!previous %in% c("free", "inside", "panel") && previous %in% c("inherit", "right", "left", "top", "bottom")) {
      ov$legend_free_origin <- previous
      if (previous %in% c("right", "left", "top", "bottom")) ov$legend_last_side <- previous
      if (!as.character(ov$legend_source_origin %||% "inherit")[1] %in% c("right", "left", "top", "bottom", "inside")) {
        ov$legend_source_origin <- if (previous %in% c("right", "left", "top", "bottom")) previous else "inherit"
      }
    }
    ov$legend_free_auto <- FALSE
    ov$legend_free_x <- min(max(xp, -2), 3)
    ov$legend_free_y <- min(max(yp, -2), 3)
    # Legacy mirrors are retained only for project compatibility.
    ov$legend_x <- ov$legend_free_x
    ov$legend_y <- ov$legend_free_y
  } else {
    inset <- ov$inset %||% figure_default_inset()
    inset$enabled <- TRUE
    inset$anchor <- "graph"
    inset$x <- xp
    inset$y <- yp
    ww <- suppressWarnings(as.numeric(width %||% inset$width %||% 0.32))
    hh <- suppressWarnings(as.numeric(height %||% inset$height %||% 0.32))
    if (is.finite(ww)) inset$width <- min(max(ww, 0.05), 1.5)
    if (is.finite(hh)) inset$height <- min(max(hh, 0.05), 1.5)
    ov$inset <- inset
  }
  ov
}

figure_apply_free_panel_drag_state <- function(st, event) {
  typ <- as.character(event$type %||% "")
  r <- suppressWarnings(as.integer(event$row %||% NA_integer_))
  c <- suppressWarnings(as.integer(event$col %||% NA_integer_))
  ans <- list(state = st, changed = FALSE)
  if (!typ %in% c("panel_move", "panel_resize") ||
      !is.finite(r) || !is.finite(c) || r < 1L || r > length(st) ||
      c < 1L || c > length(st[[r]]$cells)) return(ans)
  cell <- st[[r]]$cells[[c]]
  if (identical(typ, "panel_move")) {
    x <- suppressWarnings(as.numeric(event$x %||% NA_real_))
    y <- suppressWarnings(as.numeric(event$y %||% NA_real_))
    if (is.finite(x) && is.finite(y)) {
      cell$free_x <- min(max(x, -10000), 10000)
      cell$free_y <- min(max(y, -10000), 10000)
      ans$changed <- TRUE
    }
  } else {
    w <- suppressWarnings(as.numeric(event$width %||% NA_real_))
    h <- suppressWarnings(as.numeric(event$height %||% NA_real_))
    if (is.finite(w) && is.finite(h)) {
      cell$free_width <- min(max(w, 20), 10000)
      cell$free_height <- min(max(h, 20), 10000)
      ans$changed <- TRUE
    }
  }
  if (isTRUE(ans$changed)) {
    st[[r]]$cells[[c]] <- cell
    ans$state <- st
  }
  ans
}

# -----------------------------------------------------------------------------
# v3.4.0-alpha2 Row/Grid content reordering
# Slot-owned fields (key/row/col/panel_label/width/free geometry/z-index) stay in
# place. Content-owned fields move as a package so a Graph keeps its Figure size.
# Source-specific overrides are keyed by source id and therefore follow it.
# -----------------------------------------------------------------------------
figure_content_package <- function(cell) {
  list(
    id = as.character(cell$id %||% ""),
    source_type = as.character(cell$source_type %||% "internal_graph"),
    source_id = as.character(cell$source_id %||% cell$id %||% ""),
    graph_width = suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)[1]),
    graph_height = suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)[1])
  )
}

figure_assign_content_package <- function(cell, pkg) {
  cell$id <- as.character(pkg$id %||% "")
  cell$source_type <- as.character(pkg$source_type %||% "internal_graph")
  cell$source_id <- as.character(pkg$source_id %||% cell$id %||% "")
  cell$graph_width <- suppressWarnings(as.numeric(pkg$graph_width %||% NA_real_)[1])
  cell$graph_height <- suppressWarnings(as.numeric(pkg$graph_height %||% NA_real_)[1])
  cell
}

figure_layout_slot_index <- function(st) {
  st <- figure_reindex_layout(st)
  out <- list(); k <- 0L
  for (r in seq_along(st)) for (c in seq_along(st[[r]]$cells)) {
    k <- k + 1L
    out[[k]] <- list(index=k, row=r, col=c, key=as.character(st[[r]]$cells[[c]]$key %||% paste0("r",r,"_c",c)))
  }
  out
}

figure_layout_source_at_key <- function(st, key) {
  st <- figure_reindex_layout(st)
  key <- as.character(key %||% "")[1]
  if (!nzchar(key)) return("")
  for (row in st) for (cell in row$cells %||% list()) {
    if (identical(as.character(cell$key %||% ""), key)) return(as.character(cell$id %||% ""))
  }
  ""
}

figure_layout_key_for_source <- function(st, source_id) {
  st <- figure_reindex_layout(st)
  source_id <- as.character(source_id %||% "")[1]
  if (!nzchar(source_id)) return("")
  for (row in st) for (cell in row$cells %||% list()) {
    if (identical(as.character(cell$id %||% ""), source_id)) return(as.character(cell$key %||% ""))
  }
  ""
}

figure_layout_key_position <- function(st, key) {
  st <- figure_reindex_layout(st)
  key <- as.character(key %||% "")[1]
  if (!nzchar(key)) return(list(row=NA_integer_, col=NA_integer_))
  for (r in seq_along(st)) for (c in seq_along(st[[r]]$cells %||% list())) {
    if (identical(as.character(st[[r]]$cells[[c]]$key %||% ""), key)) return(list(row=as.integer(r), col=as.integer(c)))
  }
  list(row=NA_integer_, col=NA_integer_)
}

figure_content_package_signature <- function(pkg) {
  num <- function(x) {
    z <- suppressWarnings(as.numeric(x)[1])
    if (is.finite(z)) format(z, digits=15, scientific=FALSE, trim=TRUE) else "NA"
  }
  paste(
    as.character(pkg$id %||% ""),
    as.character(pkg$source_type %||% "internal_graph"),
    as.character(pkg$source_id %||% pkg$id %||% ""),
    num(pkg$graph_width), num(pkg$graph_height), sep="|"
  )
}

figure_slot_owned_signature <- function(cell) {
  z <- cell
  for (nm in c("id", "source_type", "source_id", "graph_width", "graph_height")) z[[nm]] <- NULL
  paste(capture.output(dput(z)), collapse="")
}

figure_validate_reorder_state <- function(before, after) {
  b <- figure_reindex_layout(before)
  a <- figure_reindex_layout(after)
  bs <- figure_layout_slot_index(b)
  as <- figure_layout_slot_index(a)
  bkeys <- vapply(bs, `[[`, character(1), "key")
  akeys <- vapply(as, `[[`, character(1), "key")
  if (!identical(bkeys, akeys)) return(list(ok=FALSE, reason="slot-keys-changed"))

  for (i in seq_along(bs)) {
    bz <- bs[[i]]; az <- as[[i]]
    bc <- b[[bz$row]]$cells[[bz$col]]
    ac <- a[[az$row]]$cells[[az$col]]
    if (!identical(figure_slot_owned_signature(bc), figure_slot_owned_signature(ac))) {
      return(list(ok=FALSE, reason=paste0("slot-owned-changed:", bz$key)))
    }
  }

  bp <- sort(vapply(bs, function(z) figure_content_package_signature(figure_content_package(b[[z$row]]$cells[[z$col]])), character(1)))
  ap <- sort(vapply(as, function(z) figure_content_package_signature(figure_content_package(a[[z$row]]$cells[[z$col]])), character(1)))
  if (!identical(bp, ap)) return(list(ok=FALSE, reason="content-set-changed"))
  list(ok=TRUE, reason="ok")
}

figure_reset_content_order_state <- function(st, source_order = character(0)) {
  st <- figure_reindex_layout(st)
  slots <- figure_layout_slot_index(st)
  ans <- list(state=st, changed=FALSE, mode="reset", from="", to="", validation=list(ok=TRUE, reason="unchanged"))
  if (!length(slots)) return(ans)

  pkgs <- lapply(slots, function(z) figure_content_package(st[[z$row]]$cells[[z$col]]))
  occupied <- which(vapply(pkgs, function(pkg) nzchar(as.character(pkg$id %||% pkg$source_id %||% "")), logical(1)))
  if (!length(occupied)) return(ans)
  source_order_norm <- unique(as.character(source_order %||% character(0)))
  source_order_norm <- source_order_norm[nzchar(source_order_norm)]
  rank_for <- function(pkg, fallback) {
    sid <- as.character(pkg$source_id %||% pkg$id %||% "")[1]
    hit <- match(sid, source_order_norm)
    if (is.na(hit)) length(source_order_norm) + fallback else hit
  }
  ord <- order(vapply(seq_along(occupied), function(j) rank_for(pkgs[[occupied[[j]]]], j), numeric(1)), seq_along(occupied))
  sorted_occ <- pkgs[occupied[ord]]
  blanks <- pkgs[-occupied]
  target_pkgs <- c(sorted_occ, blanks)
  before_sig <- vapply(pkgs, figure_content_package_signature, character(1))
  after_sig <- vapply(target_pkgs, figure_content_package_signature, character(1))
  if (identical(before_sig, after_sig)) return(ans)

  out <- st
  for (i in seq_along(slots)) {
    z <- slots[[i]]
    out[[z$row]]$cells[[z$col]] <- figure_assign_content_package(out[[z$row]]$cells[[z$col]], target_pkgs[[i]])
  }
  out <- figure_reindex_layout(out)
  validation <- figure_validate_reorder_state(st, out)
  ans$validation <- validation
  if (!isTRUE(validation$ok)) return(ans)
  ans$state <- out
  ans$changed <- TRUE
  ans
}

figure_reorder_content_state <- function(st, from_key, to_key, mode = c("swap", "shift")) {
  mode <- match.arg(mode)
  st <- figure_reindex_layout(st)
  slots <- figure_layout_slot_index(st)
  keys <- vapply(slots, `[[`, character(1), "key")
  from_i <- match(as.character(from_key %||% ""), keys)
  to_i <- match(as.character(to_key %||% ""), keys)
  ans <- list(state=st, changed=FALSE, mode=mode, from=from_key, to=to_key)
  if (is.na(from_i) || is.na(to_i) || from_i == to_i) return(ans)
  before <- st

  pkgs <- lapply(slots, function(z) figure_content_package(st[[z$row]]$cells[[z$col]]))
  if (identical(mode, "swap")) {
    tmp <- pkgs[[from_i]]; pkgs[[from_i]] <- pkgs[[to_i]]; pkgs[[to_i]] <- tmp
  } else {
    moving <- pkgs[[from_i]]
    if (from_i < to_i) {
      for (i in seq.int(from_i, to_i - 1L)) pkgs[[i]] <- pkgs[[i + 1L]]
    } else {
      for (i in seq.int(from_i, to_i + 1L, by=-1L)) pkgs[[i]] <- pkgs[[i - 1L]]
    }
    pkgs[[to_i]] <- moving
  }
  for (i in seq_along(slots)) {
    z <- slots[[i]]
    st[[z$row]]$cells[[z$col]] <- figure_assign_content_package(st[[z$row]]$cells[[z$col]], pkgs[[i]])
  }
  out <- figure_reindex_layout(st)
  validation <- figure_validate_reorder_state(before, out)
  ans$validation <- validation
  if (!isTRUE(validation$ok)) return(ans)
  ans$state <- out
  ans$changed <- TRUE
  ans
}

figure_shift_adjacent_state <- function(st, key, direction = c("left","right","up","down")) {
  direction <- match.arg(direction)
  st <- figure_reindex_layout(st)
  slots <- figure_layout_slot_index(st)
  keys <- vapply(slots, `[[`, character(1), "key")
  i <- match(as.character(key %||% ""), keys)
  if (is.na(i)) return(list(state=st, changed=FALSE, from=key, to=""))
  z <- slots[[i]]
  target <- NULL
  if (direction == "left" && z$col > 1L) target <- st[[z$row]]$cells[[z$col - 1L]]$key
  if (direction == "right" && z$col < length(st[[z$row]]$cells)) target <- st[[z$row]]$cells[[z$col + 1L]]$key
  if (direction %in% c("up","down")) {
    rr <- z$row + if (direction == "up") -1L else 1L
    if (rr >= 1L && rr <= length(st)) {
      cc <- min(z$col, length(st[[rr]]$cells))
      if (cc >= 1L) target <- st[[rr]]$cells[[cc]]$key
    }
  }
  if (is.null(target) || !nzchar(target)) return(list(state=st, changed=FALSE, from=key, to=""))
  figure_reorder_content_state(st, key, target, mode="swap")
}

figure_override_change_class <- function(old, new) {
  old <- modifyList(figure_default_override(), old %||% list())
  new <- modifyList(figure_default_override(), new %||% list())
  if (identical(old, new)) return("NONE")

  # Graph geometry: changes that can alter measured gtable bounds.
  if (any(vapply(c("legend", "legend_title", "legend_gap", "legend_free_origin"),
                 function(nm) !identical(old[[nm]], new[[nm]]), logical(1)))) return("GRAPH_GEOMETRY")
  oa <- modifyList(figure_default_appearance_override(), old$appearance %||% list())
  na <- modifyList(figure_default_appearance_override(), new$appearance %||% list())
  app_geom <- c("title_mode","title","xlab_mode","xlab","ylab_mode","ylab",
                "base_size","axis_title_size","axis_text_size","point_size","line_width","ymin","ymax")
  if (any(vapply(app_geom, function(nm) !identical(oa[[nm]], na[[nm]]), logical(1)))) return("GRAPH_GEOMETRY")

  # Figure geometry: viewport/overlay allocation without rebuilding Graph grob.
  # Owner-Graph-relative free legend coordinates affect only the overlay/canvas bbox; they
  # must not be treated as a Graph re-measure.
  figure_fields <- c(
    "crop", "inset", "align_h", "align_v", "external_legend",
    "legend_free_x", "legend_free_y", "legend_free_auto"
  )
  if (any(vapply(figure_fields, function(nm) !identical(old[[nm]], new[[nm]]), logical(1)))) return("FIGURE_GEOMETRY")

  # Slot-owned labels are no longer part of source overrides. Remaining pure
  # layer aesthetics can redraw the Graph without changing the Figure rect.
  "STYLE_ONLY"
}
