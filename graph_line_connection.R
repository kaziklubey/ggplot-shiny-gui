# ============================================================
# Line connection / break helpers
# ============================================================
# Pure helpers shared by the live Graph Editor, GraphState replay and
# synchronous Figure/export rendering. A break changes only line grouping;
# points, error bars and source data remain untouched.

graph_line_break_key <- function(left, right) {
  enc <- function(x) utils::URLencode(as.character(x), reserved = TRUE)
  pair <- sort(c(enc(left), enc(right)))
  paste(pair, collapse = "||")
}

graph_line_break_choices <- function(levels_now, labels_now = NULL) {
  levels_now <- as.character(levels_now %||% character(0))
  levels_now <- levels_now[!is.na(levels_now)]
  if (length(levels_now) < 2L) return(character(0))

  if (is.null(labels_now) || length(labels_now) != length(levels_now)) {
    labels_now <- levels_now
  }
  labels_now <- as.character(labels_now)

  left <- levels_now[-length(levels_now)]
  right <- levels_now[-1L]
  keys <- vapply(seq_along(left), function(i) {
    graph_line_break_key(left[[i]], right[[i]])
  }, character(1))
  labs <- paste0(labels_now[-length(labels_now)], " — ", labels_now[-1L])
  stats::setNames(keys, labs)
}

graph_line_break_normalize <- function(selected, levels_now) {
  selected <- unique(as.character(unlist(selected %||% character(0), use.names = FALSE)))
  selected <- selected[!is.na(selected) & nzchar(selected)]
  valid <- unname(graph_line_break_choices(levels_now))
  valid[valid %in% selected]
}

graph_line_break_segment_ids <- function(values, levels_now, selected) {
  levels_now <- as.character(levels_now %||% character(0))
  if (!length(levels_now)) return(rep(1L, length(values)))

  selected <- graph_line_break_normalize(selected, levels_now)
  if (!length(selected)) return(rep(1L, length(values)))

  boundary_keys <- unname(graph_line_break_choices(levels_now))
  break_after <- which(boundary_keys %in% selected)
  idx <- match(as.character(values), levels_now)

  out <- rep(NA_integer_, length(idx))
  ok <- !is.na(idx)
  if (any(ok)) {
    out[ok] <- 1L + vapply(idx[ok], function(i) as.integer(sum(break_after < i)), integer(1))
  }
  out
}

graph_line_break_apply_group <- function(data, x_col, levels_now, selected,
                                         group_col, output_col = group_col) {
  if (!is.data.frame(data) || !nrow(data) ||
      !x_col %in% names(data) || !group_col %in% names(data)) {
    return(data)
  }

  selected <- graph_line_break_normalize(selected, levels_now)
  if (!length(selected)) return(data)

  segment <- graph_line_break_segment_ids(data[[x_col]], levels_now, selected)
  base_group <- as.character(data[[group_col]])
  data[[output_col]] <- interaction(
    factor(base_group), factor(segment),
    drop = TRUE, lex.order = TRUE
  )
  data
}

graph_line_break_plan <- function(cfg, mapping_plan = NULL) {
  if (!is.list(cfg)) {
    return(list(levels = character(0), choices = character(0), selected = character(0)))
  }

  plan <- mapping_plan
  if (is.null(plan)) plan <- tryCatch(graph_replay_mapping_plan(cfg), error = function(e) NULL)
  if (!is.list(plan) || !is.data.frame(plan$data)) {
    return(list(levels = character(0), choices = character(0), selected = character(0)))
  }

  x_var <- as.character(plan$x %||% "")[1]
  if (!nzchar(x_var) || !x_var %in% names(plan$data)) {
    return(list(levels = character(0), choices = character(0), selected = character(0)))
  }

  observed <- unique(as.character(plan$data[[x_var]]))
  observed <- observed[!is.na(observed)]
  saved <- character(0)
  orders <- (cfg$style %||% list())$orders
  if (is.list(orders) && is.list(orders$x)) {
    saved <- as.character(orders$x[[x_var]] %||% character(0))
  }
  levels_now <- graph_complete_order(saved, observed)

  labels_now <- levels_now
  level_labels <- (cfg$style %||% list())$level_labels
  branch <- if (is.list(level_labels)) level_labels[[x_var]] else NULL
  if (is.list(branch)) {
    labels_now <- vapply(levels_now, function(lv) {
      z <- branch[[lv]]
      if (is.null(z) || !length(z) || !nzchar(trimws(as.character(z)[1]))) lv else as.character(z)[1]
    }, character(1))
  }

  choices <- graph_line_break_choices(levels_now, labels_now)
  selected <- graph_line_break_normalize((cfg$plot %||% list())$line_breaks, levels_now)
  list(levels = levels_now, choices = choices, selected = selected)
}
