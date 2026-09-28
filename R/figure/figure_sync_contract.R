# ============================================================
# Figure <-> source Graph ownership contract
# ============================================================
# Figure keeps an editable GraphState copy, but does not auto-write it to the
# source Graph.  Source write-back happens only through the explicit
# "元Graphへ反映" action. Figure layout/placement/crop/inset state lives outside
# GraphState and is therefore never part of that source commit.

figure_state_ownership_contract <- function() {
  list(
    source_graph = c(
      "project_name", "data_text", "reshape", "export", "ui_snapshot",
      "statistics_recipes", "statistics_selected_id",
      "source Shared Library binding metadata (preserved on Figure -> Graph apply)"
    ),
    figure_editable_graph = c("mapping", "plot", "labels", "style"),
    figure_only = c(
      "layout rows/cells", "free panel geometry", "panel labels",
      "Figure legend placement/background", "crop", "inset",
      "Figure semantic binding metadata",
      "external assets", "Figure export geometry"
    ),
    synchronization = list(
      automatic = FALSE,
      source_to_figure = "explicit Graph Sources import / refresh",
      figure_to_source = "explicit 元Graphへ反映"
    )
  )
}

figure_source_snapshot_copy <- function(source_graph_state) {
  if (!is.list(source_graph_state)) return(NULL)
  unserialize(serialize(source_graph_state, NULL, version = 3))
}

figure_remove_graph_references <- function(layout, overrides, graph_id) {
  graph_id <- as.character(graph_id %||% "")[1]
  if (!nzchar(graph_id)) {
    return(list(layout = layout %||% list(), overrides = overrides %||% list(),
                removed_main = 0L, removed_insets = 0L))
  }

  layout_out <- if (is.list(layout)) layout else list()
  removed_main <- 0L
  for (r in seq_along(layout_out)) {
    cells <- layout_out[[r]]$cells %||% list()
    for (cc in seq_along(cells)) {
      cell <- cells[[cc]] %||% list()
      source_type <- as.character(cell$source_type %||% "internal_graph")[1]
      source_id <- as.character(cell$source_id %||% cell$id %||% "")[1]
      if (identical(source_type, "internal_graph") && identical(source_id, graph_id)) {
        cell$id <- ""
        cell$source_id <- ""
        cell$source_type <- "internal_graph"
        cells[[cc]] <- cell
        removed_main <- removed_main + 1L
      }
    }
    layout_out[[r]]$cells <- cells
  }

  overrides_out <- if (is.list(overrides)) overrides else list()
  overrides_out[[graph_id]] <- NULL
  removed_insets <- 0L
  for (owner_id in names(overrides_out)) {
    ov <- overrides_out[[owner_id]]
    if (!is.list(ov)) next
    inset <- ov$inset %||% list()
    source_type <- as.character(inset$source_type %||% "internal_graph")[1]
    source_id <- as.character(inset$source_id %||% "")[1]
    if (identical(source_type, "internal_graph") && identical(source_id, graph_id)) {
      inset$enabled <- FALSE
      inset$source_type <- "internal_graph"
      inset$source_id <- ""
      ov$inset <- inset
      overrides_out[[owner_id]] <- ov
      removed_insets <- removed_insets + 1L
    }
  }

  list(
    layout = layout_out,
    overrides = overrides_out,
    removed_main = removed_main,
    removed_insets = removed_insets
  )
}

figure_materialize_persisted_inset_fallbacks <- function(inset_cache, overrides,
                                                          source_id, persisted_rec) {
  source_id <- as.character(source_id %||% "")[1]
  cache_out <- if (is.list(inset_cache)) inset_cache else list()
  overrides <- if (is.list(overrides)) overrides else list()
  if (!nzchar(source_id) || !is.list(persisted_rec) ||
      !nzchar(as.character(persisted_rec$svg %||% "")[1])) {
    return(list(cache = cache_out, materialized = character(0)))
  }

  materialized <- character(0)
  for (owner_id in names(overrides)) {
    ov <- overrides[[owner_id]]
    if (!is.list(ov)) next
    inset <- ov$inset %||% list()
    inset_type <- as.character(inset$source_type %||% "internal_graph")[1]
    inset_source <- as.character(inset$source_id %||% "")[1]
    if (!isTRUE(inset$enabled) || !identical(inset_type, "internal_graph") ||
        !identical(inset_source, source_id)) next

    existing <- cache_out[[owner_id]]
    if (is.list(existing) &&
        identical(as.character(existing$source_id %||% "")[1], source_id) &&
        nzchar(as.character(existing$svg %||% "")[1])) next

    rec <- figure_source_snapshot_copy(persisted_rec)
    rec$owner_id <- owner_id
    rec$source_id <- source_id
    cache_out[[owner_id]] <- rec
    materialized <- c(materialized, owner_id)
  }

  list(cache = cache_out, materialized = unique(materialized))
}

figure_existing_state_target_ids <- function(target_ids, main_ids, edit_states) {
  requested <- intersect(
    unique(as.character(target_ids %||% character(0))),
    unique(as.character(main_ids %||% character(0)))
  )
  requested <- requested[nzchar(requested)]
  states <- if (is.list(edit_states)) edit_states else list()
  requested[vapply(requested, function(id) is.list(states[[id]]), logical(1))]
}

figure_snapshot_key_references_graph <- function(key, graph_id) {
  graph_id <- as.character(graph_id %||% "")[1]
  parts <- strsplit(as.character(key %||% "")[1], "|", fixed = TRUE)[[1]]
  if (!nzchar(graph_id) || !length(parts)) return(FALSE)
  if (identical(parts[[1]], "main")) {
    return(length(parts) >= 2L && identical(parts[[2]], graph_id))
  }
  if (identical(parts[[1]], "inset")) {
    return(length(parts) >= 3L && any(parts[2:3] == graph_id))
  }
  FALSE
}

figure_source_apply_payload <- function(figure_graph_state, source_graph_state = NULL) {
  if (!is.list(figure_graph_state)) return(NULL)

  # Statistics is Graph-linked analysis state, not Figure-editable Plot state.
  # Start from the canonical source so metadata/analysis recipes survive, then
  # replace only fields owned by the Figure Graph editor.
  out <- if (is.list(source_graph_state)) source_graph_state else list()
  owned <- c("mapping", "plot", "labels", "style")
  for (nm in owned) {
    if (nm %in% names(figure_graph_state)) out[[nm]] <- figure_graph_state[[nm]]
  }

  # Figure may edit its own semantic binding metadata for Common Settings, but
  # that binding is Figure-local ownership. Figure -> Graph Apply must never
  # replace a newer source Graph binding; only concrete Figure-owned appearance
  # values are merged back.
  if (!is.list(out$style)) out$style <- list()
  source_binding <- if (is.list(source_graph_state)) {
    source_graph_state$style$shared_library %||% NULL
  } else {
    NULL
  }
  if (is.null(source_binding)) out$style$shared_library <- NULL
  else out$style$shared_library <- shared_style_normalize_binding(source_binding)
  out
}

figure_source_apply_diff <- function(source_graph_state, figure_graph_state) {
  payload <- figure_source_apply_payload(figure_graph_state, source_graph_state)
  if (!is.list(payload)) return(character(0))
  app_state_diff_paths(source_graph_state, payload)
}

figure_graphstate_style_summary <- function(z) {
  if (!is.list(z)) return("<none>")
  mp <- z$mapping %||% list()
  st0 <- z$style %||% list()
  scalar_chr <- function(x, default = "") {
    if (is.null(x)) return(default)
    v <- as.character(unlist(x, use.names = FALSE))
    if (!length(v)) default else v[[1]]
  }
  tree_txt <- function(x) {
    if (is.null(x) || !length(x)) return("<none>")
    paste(vapply(names(x), function(nm) {
      br <- x[[nm]]
      vals <- if (is.list(br)) {
        paste(vapply(names(br), function(k) paste0(k, "=", scalar_chr(br[[k]])), character(1)), collapse = "|")
      } else scalar_chr(br)
      paste0(nm, ":[", vals, "]")
    }, character(1)), collapse = ";")
  }
  paste0(
    "color_mapping=", scalar_chr(mp$color),
    " shape_mapping=", scalar_chr(mp$shape, "__color__"),
    " color={", tree_txt(st0$color_styles), "}",
    " shape={", tree_txt(st0$shape_styles), "}",
    " series={", tree_txt(st0$series_styles), "}",
    " palette=", scalar_chr((st0$appearance %||% list())$palette_preset)
  )
}
