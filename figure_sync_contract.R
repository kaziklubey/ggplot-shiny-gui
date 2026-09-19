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
      "data_text", "reshape", "mapping", "plot", "labels", "style",
      "Shared Library binding metadata (source-preserved; not Figure-editable)"
    ),
    figure_only = c(
      "layout rows/cells", "free panel geometry", "panel labels",
      "Figure legend placement/background", "crop", "inset",
      "external assets", "Figure export geometry"
    ),
    synchronization = list(
      automatic = FALSE,
      source_to_figure = "explicit Graphから再読込 / bulk import",
      figure_to_source = "explicit 元Graphへ反映"
    )
  )
}

figure_source_apply_payload <- function(figure_graph_state, source_graph_state = NULL) {
  if (!is.list(figure_graph_state)) return(NULL)

  # Statistics is Graph-linked analysis state, not Figure-editable Plot state.
  # Start from the canonical source so metadata/analysis recipes survive, then
  # replace only fields owned by the Figure Graph editor.
  out <- if (is.list(source_graph_state)) source_graph_state else list()
  owned <- c("data_text", "reshape", "mapping", "plot", "labels", "style")
  for (nm in owned) {
    if (nm %in% names(figure_graph_state)) out[[nm]] <- figure_graph_state[[nm]]
  }

  # Shared Library binding is Project/Graph metadata, not a Figure-editable
  # appearance field. A Figure snapshot may carry the binding that existed at
  # import time (or the metadata resolved by an explicit Shared Style apply),
  # but Figure -> Graph Apply must never replace a newer source binding.
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
