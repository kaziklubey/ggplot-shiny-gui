# ============================================================
# Shared Label / Style Library — pure state helpers
# v3.73.0: project-level semantic style definitions + per-Graph bindings.
# ============================================================

shared_style_scalar_chr <- function(x, default = "") {
  if (is.null(x)) return(default)
  z <- unlist(x, use.names = FALSE)
  if (!length(z) || is.na(z[[1]])) return(default)
  as.character(z[[1]])
}

shared_style_scalar_num <- function(x, default = NA_real_) {
  z <- suppressWarnings(as.numeric(shared_style_scalar_chr(x, as.character(default))))
  if (!length(z) || !is.finite(z[[1]])) default else z[[1]]
}

shared_style_scalar_lgl <- function(x, default = FALSE) {
  if (is.null(x)) return(isTRUE(default))
  z <- unlist(x, use.names = FALSE)
  if (!length(z) || is.na(z[[1]])) return(isTRUE(default))
  isTRUE(as.logical(z[[1]]))
}

shared_style_safe_id <- function(x) {
  x <- trimws(shared_style_scalar_chr(x, ""))
  x <- gsub("[^A-Za-z0-9_.-]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  tolower(x)
}

shared_style_default_item <- function(id = "", display = NULL, kind = "level") {
  id <- shared_style_safe_id(id)
  display <- shared_style_scalar_chr(display, if (nzchar(id)) id else "Shared item")
  kind <- shared_style_scalar_chr(kind, "level")
  if (!kind %in% c("level", "axis_label", "legend_title")) kind <- "level"
  list(
    id = id,
    display = display,
    kind = kind,
    color = "#E69F00",
    fill = "#E69F00",
    shape = 16,
    linetype = "solid",
    manage = list(
      display = TRUE,
      color = identical(kind, "level"),
      fill = identical(kind, "level"),
      shape = identical(kind, "level"),
      linetype = identical(kind, "level")
    )
  )
}

shared_style_normalize_item <- function(x, id = NULL) {
  if (!is.list(x)) x <- list()
  id0 <- shared_style_safe_id(id %||% x$id %||% "")
  out <- shared_style_default_item(id0, x$display %||% id0, x$kind %||% "level")
  out$display <- shared_style_scalar_chr(x$display, out$display)
  out$color <- graph_normalise_colour(shared_style_scalar_chr(x$color, out$color), out$color)
  out$fill <- graph_normalise_colour(shared_style_scalar_chr(x$fill, out$color), out$color)
  out$shape <- shared_style_scalar_num(x$shape, out$shape)
  out$linetype <- shared_style_scalar_chr(x$linetype, out$linetype)
  if (!out$linetype %in% c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash")) out$linetype <- "solid"
  mg <- x$manage %||% list()
  out$manage <- list(
    display = shared_style_scalar_lgl(mg$display, TRUE),
    color = shared_style_scalar_lgl(mg$color, identical(out$kind, "level")),
    fill = shared_style_scalar_lgl(mg$fill, identical(out$kind, "level")),
    shape = shared_style_scalar_lgl(mg$shape, identical(out$kind, "level")),
    linetype = shared_style_scalar_lgl(mg$linetype, identical(out$kind, "level"))
  )
  if (!identical(out$kind, "level")) {
    out$manage$color <- FALSE
    out$manage$fill <- FALSE
    out$manage$shape <- FALSE
    out$manage$linetype <- FALSE
  }
  out
}

shared_style_default_library <- function() {
  list(schema_version = 1L, items = list())
}

shared_style_normalize_library <- function(x) {
  if (!is.list(x)) x <- list()
  src <- x$items %||% list()
  if (!is.list(src)) src <- list()
  ids <- names(src) %||% character(0)
  if (!length(ids) && length(src)) {
    ids <- vapply(src, function(z) shared_style_safe_id(z$id %||% ""), character(1))
  }
  out <- list()
  for (i in seq_along(src)) {
    id <- shared_style_safe_id(ids[[i]] %||% src[[i]]$id %||% "")
    if (!nzchar(id) || id %in% names(out)) next
    out[[id]] <- shared_style_normalize_item(src[[i]], id)
  }
  list(schema_version = 1L, items = out)
}

shared_style_library_items <- function(library, kind = NULL) {
  lib <- shared_style_normalize_library(library)
  items <- lib$items
  if (is.null(kind)) return(items)
  kind <- as.character(kind)
  items[vapply(items, function(z) z$kind %in% kind, logical(1))]
}

shared_style_default_binding <- function() {
  list(
    schema_version = 1L,
    enabled = FALSE,
    attributes = list(display = TRUE, color = TRUE, shape = TRUE, linetype = TRUE),
    levels = list(),
    axis = list(x = "", y = ""),
    legends = list()
  )
}

shared_style_normalize_binding <- function(x) {
  if (!is.list(x)) x <- list()
  out <- shared_style_default_binding()
  out$enabled <- shared_style_scalar_lgl(x$enabled, FALSE)
  at <- x$attributes %||% list()
  out$attributes <- list(
    display = shared_style_scalar_lgl(at$display, TRUE),
    color = shared_style_scalar_lgl(at$color, TRUE),
    shape = shared_style_scalar_lgl(at$shape, TRUE),
    linetype = shared_style_scalar_lgl(at$linetype, TRUE)
  )
  lv <- x$levels %||% list()
  if (is.list(lv)) {
    for (vn in names(lv) %||% character(0)) {
      br <- lv[[vn]]
      if (!is.list(br)) next
      bb <- list()
      for (level in names(br) %||% character(0)) {
        item_id <- shared_style_safe_id(br[[level]])
        if (nzchar(item_id)) bb[[level]] <- item_id
      }
      if (length(bb)) out$levels[[vn]] <- bb
    }
  }
  ax <- x$axis %||% list()
  out$axis <- list(
    x = shared_style_safe_id(ax$x %||% ""),
    y = shared_style_safe_id(ax$y %||% "")
  )
  lg <- x$legends %||% list()
  if (is.list(lg)) {
    for (key in names(lg) %||% character(0)) {
      item_id <- shared_style_safe_id(lg[[key]])
      if (nzchar(item_id)) out$legends[[key]] <- item_id
    }
  }
  out
}

shared_style_binding_has_links <- function(binding) {
  b <- shared_style_normalize_binding(binding)
  any(vapply(b$levels, length, integer(1)) > 0L) ||
    nzchar(b$axis$x) || nzchar(b$axis$y) || length(b$legends) > 0L
}

shared_style_normalize_graph_state <- function(state) {
  if (!is.list(state)) return(state)
  if (!is.list(state$style)) state$style <- list()
  state$style$shared_library <- shared_style_normalize_binding(
    state$style$shared_library %||% NULL
  )
  state
}

shared_style_set_nested <- function(tree, branch, key, value) {
  if (!is.list(tree)) tree <- list()
  br <- tree[[branch]]
  if (!is.list(br)) br <- list()
  br[[key]] <- value
  tree[[branch]] <- br
  tree
}

shared_style_apply_to_graph_state <- function(state, library) {
  if (!is.list(state)) return(state)
  lib <- shared_style_normalize_library(library)
  st <- state$style %||% list()
  binding <- shared_style_normalize_binding(st$shared_library %||% NULL)
  if (!isTRUE(binding$enabled) || !shared_style_binding_has_links(binding)) return(state)
  attrs <- binding$attributes

  for (vn in names(binding$levels) %||% character(0)) {
    for (lv in names(binding$levels[[vn]]) %||% character(0)) {
      item_id <- binding$levels[[vn]][[lv]]
      item <- lib$items[[item_id]]
      if (!is.list(item) || !identical(item$kind, "level")) next
      mg <- item$manage %||% list()
      if (isTRUE(attrs$display) && isTRUE(mg$display)) {
        st$level_labels <- shared_style_set_nested(st$level_labels, vn, lv, item$display)
      }
      # Current Graph rendering uses one categorical colour tree for line/point
      # colour and filled geoms. Keep Library color/fill definitions portable,
      # but bind the render-facing Graph value to item$color for now.
      if (isTRUE(attrs$color) && (isTRUE(mg$color) || isTRUE(mg$fill))) {
        st$color_styles <- shared_style_set_nested(st$color_styles, vn, lv, item$color)
      }
      if (isTRUE(attrs$shape) && isTRUE(mg$shape)) {
        st$shape_styles <- shared_style_set_nested(st$shape_styles, vn, lv, item$shape)
      }
      if (isTRUE(attrs$linetype) && isTRUE(mg$linetype)) {
        st$linetype_styles <- shared_style_set_nested(st$linetype_styles, vn, lv, item$linetype)
      }
    }
  }

  if (isTRUE(attrs$display)) {
    for (axis_nm in c("x", "y")) {
      item_id <- binding$axis[[axis_nm]] %||% ""
      item <- lib$items[[item_id]]
      if (is.list(item) && identical(item$kind, "axis_label") && isTRUE(item$manage$display)) {
        state$labels[[paste0(axis_nm, "lab")]] <- item$display
      }
    }
    for (legend_key in names(binding$legends) %||% character(0)) {
      item_id <- binding$legends[[legend_key]]
      item <- lib$items[[item_id]]
      if (is.list(item) && identical(item$kind, "legend_title") && isTRUE(item$manage$display)) {
        if (!is.list(st$legend_titles)) st$legend_titles <- list()
        st$legend_titles[[legend_key]] <- item$display
      }
    }
  }

  st$shared_library <- binding
  state$style <- st
  state
}

shared_style_resolve_writeback <- function(current, candidates, normalize) {
  if (!length(candidates)) return(normalize(current))
  cur <- normalize(current)
  vals <- unique(vapply(candidates, normalize, character(1)))
  changed <- vals[vals != cur]
  # One semantic item may be bound to several source values in the same Graph.
  # Accept a write-through only when those observations imply exactly one new
  # value relative to the current Library item. Conflicting simultaneous values
  # are ambiguous and therefore leave the Library unchanged.
  if (length(changed) == 1L) changed[[1]] else cur
}

shared_style_update_library_from_graph_state <- function(library, state) {
  lib <- shared_style_normalize_library(library)
  if (!is.list(state)) return(lib)
  st <- state$style %||% list()
  b <- shared_style_normalize_binding(st$shared_library %||% NULL)
  if (!isTRUE(b$enabled)) return(lib)
  attrs <- b$attributes
  pending <- list()

  add_candidate <- function(item_id, field, value) {
    if (is.null(value) || !nzchar(as.character(item_id %||% ""))) return(invisible(NULL))
    rec <- pending[[item_id]] %||% list()
    rec[[field]] <- c(rec[[field]] %||% list(), list(value))
    pending[[item_id]] <<- rec
    invisible(NULL)
  }

  for (vn in names(b$levels) %||% character(0)) {
    for (lv in names(b$levels[[vn]]) %||% character(0)) {
      item_id <- b$levels[[vn]][[lv]]
      item <- lib$items[[item_id]]
      if (!is.list(item) || !identical(item$kind, "level")) next
      mg <- item$manage %||% list()
      if (isTRUE(attrs$display) && isTRUE(mg$display)) {
        add_candidate(item_id, "display", st$level_labels[[vn]][[lv]] %||% lv)
      }
      if (isTRUE(attrs$color) && (isTRUE(mg$color) || isTRUE(mg$fill))) {
        add_candidate(item_id, "color", st$color_styles[[vn]][[lv]])
      }
      if (isTRUE(attrs$shape) && isTRUE(mg$shape)) {
        add_candidate(item_id, "shape", st$shape_styles[[vn]][[lv]])
      }
      if (isTRUE(attrs$linetype) && isTRUE(mg$linetype)) {
        add_candidate(item_id, "linetype", st$linetype_styles[[vn]][[lv]])
      }
    }
  }

  if (isTRUE(attrs$display)) {
    for (axis_nm in c("x", "y")) {
      item_id <- b$axis[[axis_nm]] %||% ""
      item <- lib$items[[item_id]]
      if (!is.list(item) || !identical(item$kind, "axis_label") || !isTRUE(item$manage$display)) next
      add_candidate(item_id, "display", state$labels[[paste0(axis_nm, "lab")]])
    }
    for (legend_key in names(b$legends) %||% character(0)) {
      item_id <- b$legends[[legend_key]]
      item <- lib$items[[item_id]]
      if (!is.list(item) || !identical(item$kind, "legend_title") || !isTRUE(item$manage$display)) next
      add_candidate(item_id, "display", st$legend_titles[[legend_key]])
    }
  }

  for (item_id in names(pending) %||% character(0)) {
    item <- lib$items[[item_id]]
    if (!is.list(item)) next
    rec <- pending[[item_id]]
    if (length(rec$display)) {
      item$display <- shared_style_resolve_writeback(
        item$display, rec$display,
        function(z) shared_style_scalar_chr(z, "")
      )
    }
    if (identical(item$kind, "level")) {
      if (length(rec$color)) {
        item$color <- shared_style_resolve_writeback(
          item$color, rec$color,
          function(z) graph_normalise_colour(shared_style_scalar_chr(z, item$color), item$color)
        )
        if (isTRUE(item$manage$fill)) item$fill <- item$color
      }
      if (length(rec$shape)) {
        shape_chr <- shared_style_resolve_writeback(
          item$shape, rec$shape,
          function(z) as.character(shared_style_scalar_num(z, item$shape))
        )
        item$shape <- shared_style_scalar_num(shape_chr, item$shape)
      }
      if (length(rec$linetype)) {
        item$linetype <- shared_style_resolve_writeback(
          item$linetype, rec$linetype,
          function(z) shared_style_scalar_chr(z, item$linetype)
        )
      }
    }
    lib$items[[item_id]] <- shared_style_normalize_item(item, item_id)
  }
  lib
}

shared_style_item_label <- function(item) {
  if (!is.list(item)) return("")
  paste0(item$display %||% item$id %||% "", "  [", item$id %||% "", "]")
}
