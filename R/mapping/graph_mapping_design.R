# ============================================================
# Mapping semantics / visual-design helpers (v3.80)
# ============================================================
# Pure functions only.  These helpers are shared by live Graph rendering,
# direct-state Figure/export rendering, diagnostics and development stress tests.
# They do not own Shiny inputs or canonical state.

graph_mapping_clean_vars <- function(data, vars) {
  vars <- unique(as.character(vars %||% character(0)))
  vars[nzchar(vars) & vars %in% names(data)]
}

graph_mapping_max_levels_within_x <- function(data, xvar, variable, facetvar = "") {
  if (!is.data.frame(data) || !nrow(data) ||
      !nzchar(xvar) || !xvar %in% names(data) ||
      !nzchar(variable) || !variable %in% names(data)) return(0L)
  if (identical(variable, xvar)) return(1L)

  group_vars <- c(xvar, if (nzchar(facetvar) && facetvar %in% names(data)) facetvar else character(0))
  keys <- do.call(
    interaction,
    c(lapply(group_vars, function(v) as.character(data[[v]])), list(drop = TRUE, lex.order = TRUE))
  )
  values <- as.character(data[[variable]])
  counts <- tapply(values, keys, function(z) length(unique(z[!is.na(z)])))
  if (!length(counts)) return(0L)
  max(as.integer(counts), na.rm = TRUE)
}

graph_mapping_is_x_determined <- function(data, xvar, variable, facetvar = "") {
  if (!nzchar(variable) || !variable %in% names(data)) return(TRUE)
  graph_mapping_max_levels_within_x(data, xvar, variable, facetvar) <= 1L
}

# Bar/Box stable tracks: variables that are completely determined by X do not
# consume horizontal slots. Remaining observed combinations define a stable
# track order shared across all X levels within each facet, so a missing cell
# leaves a gap rather than shifting the surviving bars/boxes left or right.
graph_effective_slot_vars <- function(data, xvar, slot_vars, facetvar = "") {
  vars <- graph_mapping_clean_vars(data, slot_vars)
  vars[!vapply(vars, function(v) graph_mapping_is_x_determined(data, xvar, v, facetvar), logical(1))]
}

# Stable ordering primitive for Bar/Box tracks. Only combinations that actually
# occur in the supplied data slice are returned; factor/appearance order
# determines their order. `graph_stable_track_plan()` applies this per facet so
# all X levels in that panel reuse the same track indices.
graph_stable_track_order <- function(data, vars) {
  vars <- graph_mapping_clean_vars(data, vars)
  if (!length(vars)) return("all")
  if (!is.data.frame(data) || !nrow(data)) return(character(0))

  key <- if (length(vars) == 1L) {
    as.character(data[[vars[[1]]]])
  } else {
    as.character(do.call(
      interaction,
      c(lapply(vars, function(v) data[[v]]), list(drop = TRUE, lex.order = TRUE))
    ))
  }

  keep <- !is.na(key) & nzchar(key)
  if (!any(keep)) return("all")
  tab <- data[keep, vars, drop = FALSE]
  tab$.track_key__ <- key[keep]
  tab <- tab[!duplicated(tab$.track_key__), , drop = FALSE]

  rank_cols <- character(0)
  for (i in seq_along(vars)) {
    v <- vars[[i]]
    lv <- levels(data[[v]])
    if (is.null(lv) || !length(lv)) lv <- unique(as.character(data[[v]]))
    lv <- lv[!is.na(lv)]
    rn <- paste0(".track_rank__", i)
    tab[[rn]] <- match(as.character(tab[[v]]), lv)
    miss <- is.na(tab[[rn]])
    if (any(miss)) tab[[rn]][miss] <- length(lv) + seq_len(sum(miss))
    rank_cols <- c(rank_cols, rn)
  }

  ord <- do.call(order, lapply(rank_cols, function(nm) tab[[nm]]))
  unique(as.character(tab$.track_key__[ord]))
}

# Facet-local stable-track plan.  Stable positions are shared across all X
# levels *within the same facet*, while structurally absent tracks from another
# facet do not reserve empty horizontal slots in this panel.  This preserves the
# missing-cell invariant without shifting a whole facet away from its X tick.
graph_stable_track_plan <- function(data, vars, facetvar = "") {
  vars <- graph_mapping_clean_vars(data, vars)
  has_facet <- nzchar(facetvar) && facetvar %in% names(data)

  if (!is.data.frame(data) || !nrow(data)) {
    return(list(
      table = data.frame(
        .facet_key__ = character(0),
        .track_key__ = character(0),
        .slot_i__ = integer(0),
        .slot_n__ = integer(0),
        stringsAsFactors = FALSE
      ),
      max_slots = 1L
    ))
  }

  facet_key <- if (has_facet) as.character(data[[facetvar]]) else rep("__all__", nrow(data))
  facet_key[is.na(facet_key)] <- "__NA__"
  facet_levels <- unique(facet_key)

  rows <- lapply(facet_levels, function(fk) {
    keep <- facet_key == fk
    ord <- graph_stable_track_order(data[keep, , drop = FALSE], vars)
    if (!length(ord)) ord <- "all"
    data.frame(
      .facet_key__ = rep(fk, length(ord)),
      .track_key__ = as.character(ord),
      .slot_i__ = seq_along(ord),
      .slot_n__ = rep(length(ord), length(ord)),
      stringsAsFactors = FALSE
    )
  })

  tab <- do.call(rbind, rows)
  max_slots <- if (nrow(tab)) max(tab$.slot_n__) else 1L
  list(table = tab, max_slots = max(as.integer(max_slots), 1L))
}

# Pure geometry helper used by tests and render code.
# For every complete local track lattice, offsets are exactly centered on zero.
graph_centered_slot_offset <- function(slot_i, slot_n, slot_width, spacing = 1) {
  slot_i <- as.numeric(slot_i)
  slot_n <- pmax(as.numeric(slot_n), 1)
  slot_width <- as.numeric(slot_width)
  spacing <- suppressWarnings(as.numeric(spacing))
  if (!is.finite(spacing)) spacing <- 1
  (slot_i - (slot_n + 1) / 2) * slot_width * spacing
}


# Line series grouping is separate from visual aesthetics.  Auto mode uses only
# mappings that distinguish multiple observations at the same X (within facet),
# so a Phase/Color that changes *along* X can change appearance without cutting
# the line.  Legacy mode remains an explicit escape hatch rather than a hidden
# compatibility branch.
graph_line_series_vars <- function(data, xvar, candidates, facetvar = "",
                                   mode = "auto", explicit_var = "") {
  mode <- as.character(mode %||% "auto")[1]
  candidates <- graph_mapping_clean_vars(data, candidates)

  if (identical(mode, "single")) return(character(0))
  if (identical(mode, "column")) {
    return(graph_mapping_clean_vars(data, explicit_var))
  }
  if (identical(mode, "mapped")) return(candidates)

  # Unknown / old values normalize to Auto.
  candidates[!vapply(candidates, function(v) graph_mapping_is_x_determined(data, xvar, v, facetvar), logical(1))]
}

graph_mapping_level_count <- function(data, variable) {
  if (!is.data.frame(data) || !nzchar(variable) || !variable %in% names(data)) return(0L)
  z <- as.character(data[[variable]])
  length(unique(z[!is.na(z)]))
}

graph_mapping_diagnostics <- function(data, plot_type, xvar, position_var = "",
                                      color_var = "", linetype_var = "", shape_var = "",
                                      facet_var = "", line_series_mode = "auto",
                                      line_series_var = "") {
  if (!is.data.frame(data) || !nrow(data) || !nzchar(xvar) || !xvar %in% names(data)) {
    return(list(messages = character(0), severity = character(0)))
  }

  messages <- character(0)
  severity <- character(0)
  add <- function(text, level = "info") {
    messages <<- c(messages, text)
    severity <<- c(severity, level)
  }

  if (plot_type %in% c("bar", "box")) {
    vars <- graph_effective_slot_vars(data, xvar, c(position_var, color_var), facet_var)
    if (length(vars)) {
      key <- if (length(vars) == 1L) as.character(data[[vars]]) else do.call(
        interaction, c(lapply(vars, function(v) data[[v]]), list(drop = TRUE, lex.order = TRUE))
      )
      n_tracks <- length(unique(as.character(key[!is.na(key)])))
      if (n_tracks >= 8L) add(paste0("横並び系列が ", n_tracks, " 本あります。太さ・中心間隔・Plot横幅で調整できます。"), "warn")
    }
    redundant <- graph_mapping_clean_vars(data, c(position_var, color_var))
    redundant <- redundant[vapply(redundant, function(v) graph_mapping_is_x_determined(data, xvar, v, facet_var), logical(1))]
    if (length(redundant)) add(paste0("Xと完全に連動するMapping（", paste(unique(redundant), collapse = ", "), "）は横並びslotを増やしません。"), "info")
  }

  nc <- graph_mapping_level_count(data, color_var)
  nl <- graph_mapping_level_count(data, linetype_var)
  ns <- graph_mapping_level_count(data, shape_var)
  if (nc > 8L) add(paste0("Color / Fill は ", nc, " 水準です。固定パレットの標準8色を超える分は自動拡張されます。識別性を確認し、必要なら個別色も調整してください。"), "info")
  if (plot_type %in% c("line", "scatter") && nl > 6L) add(paste0("Linetype は ", nl, " 水準です。既定の6種類を超えます。"), "warn")
  if (plot_type %in% c("line", "scatter") && ns > 10L) add(paste0("Shape は ", ns, " 水準です。既定の10種類を超えます。"), "warn")

  if (identical(plot_type, "line")) {
    series_mode <- as.character(line_series_mode %||% "auto")[1]
    cand <- graph_mapping_clean_vars(data, c(position_var, color_var, linetype_var, shape_var))

    if (identical(series_mode, "auto")) {
      ignored <- cand[vapply(cand, function(v) graph_mapping_is_x_determined(data, xvar, v, facet_var), logical(1))]
      if (length(ignored)) add(paste0("線の接続=自動: Xに沿ってだけ変化する ", paste(unique(ignored), collapse = ", "), " は線を分断せず、見た目だけ変更します。"), "info")
    }

    if (identical(series_mode, "column") &&
        (!nzchar(line_series_var %||% "") || !line_series_var %in% names(data))) {
      add("線の接続で『列を指定』が選ばれていますが、有効な系列列が未指定です。", "warn")
    }

    if (identical(series_mode, "single")) {
      coexisting <- cand[vapply(cand, function(v) !graph_mapping_is_x_determined(data, xvar, v, facet_var), logical(1))]
      if (length(coexisting)) {
        add(paste0("線の接続=1本: 同じX位置に複数水準を持つ ", paste(unique(coexisting), collapse = ", "), " があります。意図した接続か確認してください。"), "warn")
      }
    }
  }

  list(messages = messages, severity = severity)
}
