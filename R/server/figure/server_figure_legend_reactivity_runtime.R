# v3.73.2.21: Figure legend regeneration reuses the one persistent Figure
# value-replay renderer. No second hidden graphServer/UI is created.

figure_legend_materializer_expected <- reactiveVal(list())

reset_figure_legend_materializer <- function() {
  figure_legend_materializer_expected(list())
  invisible(TRUE)
}

figure_legend_materializer_signature <- function(ov) {
  z <- modifyList(figure_default_override(), ov %||% list())
  list(
    legend = as.character(z$legend %||% "inherit")[1],
    source_origin = figure_legend_source_origin(z),
    legend_title = figure_normalize_legend_title_mode(z$legend_title),
    legend_gap = suppressWarnings(as.numeric(z$legend_gap %||% 8)[1]),
    legend_background = figure_detached_legend_background_mode(z)
  )
}

figure_legend_materializer_legacy_seed <- function(id) {
  id <- as.character(id %||% "")[1]
  if (!nzchar(id) || !cache_has(id)) return(NULL)

  figure_rec <- isolate(figure_persisted_previews())[[id]]
  graph_rec <- isolate(project_legacy_graph_previews())[[id]]
  if (!is.list(figure_rec) || !is.list(graph_rec)) return(NULL)
  figure_svg <- as.character(figure_rec$svg %||% "")[1]
  graph_svg <- as.character(graph_rec$svg %||% "")[1]
  if (!nzchar(figure_svg) || !identical(figure_svg, graph_svg)) return(NULL)

  state <- cache_get(id)
  if (!is.list(state)) return(NULL)
  store_figure_edit_state(id, state, reason = "legend-legacy-equal-preview")
  diag_log(
    "FIGURE-LEGEND-MATERIALIZE",
    "legacy editable state seeded because Graph/Figure persisted SVGs are identical",
    id = id
  )
  state
}

figure_legend_materializer_state <- function(id) {
  id <- as.character(id %||% "")[1]
  state <- isolate(figure_edit_states())[[id]]
  if (is.list(state)) return(state)
  figure_legend_materializer_legacy_seed(id)
}

figure_legend_materializer_pending <- function(id) {
  id <- as.character(id %||% "")[1]
  if (!nzchar(id)) return(FALSE)
  expected <- suppressWarnings(as.integer((isolate(figure_legend_materializer_expected())[[id]]) %||% NA_integer_))
  is.finite(expected) && figure_source_snapshot_completed_revision(id) < expected
}

figure_legend_materializer_publish_latest <- function(id, reason = "value-replay-complete") {
  id <- as.character(id %||% "")[1]
  if (!nzchar(id)) return(invisible(FALSE))
  drafts <- isolate(figure_override_drafts())
  latest <- drafts[[id]]
  if (!is.list(latest)) return(invisible(FALSE))

  requested <- isolate(figure_requested_overrides())
  previous <- requested[[id]] %||% figure_default_override(id)
  requested[[id]] <- latest
  figure_requested_overrides(requested)

  cls <- figure_override_change_class(previous, latest)
  if (cls %in% c("GRAPH_GEOMETRY", "FIGURE_GEOMETRY")) {
    figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
  }
  if (!identical(cls, "NONE")) bump_figure_panel_display_revision(id)
  diag_log(
    "FIGURE-LEGEND-MATERIALIZE",
    paste0("display-release reason=", reason, " class=", cls,
           " mode=", as.character(latest$legend %||% "inherit")[1]),
    id = id
  )
  invisible(TRUE)
}

figure_legend_materializer_on_override_change <- function(id, old, new, reason = "figure-override") {
  id <- as.character(id %||% "")[1]
  if (!nzchar(id) || id %in% names(isolate(figure_external_assets()))) return(invisible(FALSE))
  if (identical(figure_legend_materializer_signature(old), figure_legend_materializer_signature(new))) {
    return(invisible(FALSE))
  }

  # A Figure-owned live plot already contains everything needed by the renderer.
  assets <- isolate(figure_loaded_assets())
  plots <- isolate(figure_loaded_plots())
  if (!is.null(assets[[id]]$plot) || !is.null(plots[[id]])) {
    diag_log("FIGURE-LEGEND-MATERIALIZE", paste0("needed=FALSE live_snapshot=TRUE reason=", reason), id = id)
    return(invisible(FALSE))
  }

  state <- figure_legend_materializer_state(id)
  if (!is.list(state)) {
    diag_log("FIGURE-LEGEND-MATERIALIZE", paste0("needed=TRUE queued=FALSE state_available=FALSE reason=", reason), id = id)
    return(invisible(FALSE))
  }

  expected <- request_figure_source_snapshot(
    id,
    reason = paste0("figure-legend-", reason),
    import_editor_state = FALSE,
    state_override = state
  )
  if (!is.finite(suppressWarnings(as.integer(expected)))) return(invisible(FALSE))

  pending <- isolate(figure_legend_materializer_expected())
  pending[[id]] <- as.integer(expected)
  figure_legend_materializer_expected(pending)
  diag_log(
    "FIGURE-LEGEND-MATERIALIZE",
    paste0("needed=TRUE queued=TRUE mode=value-replay reason=", reason,
           " expected_revision=", expected),
    id = id
  )
  invisible(TRUE)
}

observe({
  figure_source_snapshot_generation()
  pending <- isolate(figure_legend_materializer_expected())
  if (!length(pending)) return()

  completed_ids <- character(0)
  for (id in names(pending)) {
    expected <- suppressWarnings(as.integer(pending[[id]] %||% NA_integer_))
    if (!is.finite(expected) || figure_source_snapshot_completed_revision(id) < expected) next
    if (isTRUE(figure_editor_snapshot_available(id))) {
      figure_legend_materializer_publish_latest(id)
    } else {
      diag_log("FIGURE-LEGEND-MATERIALIZE", "value replay completed without snapshot", id = id)
    }
    completed_ids <- c(completed_ids, id)
  }

  if (length(completed_ids)) {
    pending[completed_ids] <- NULL
    figure_legend_materializer_expected(pending)
  }
})
