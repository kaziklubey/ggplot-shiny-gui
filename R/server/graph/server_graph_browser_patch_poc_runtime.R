# v4.0 RC11 browser working state.
# Browser = optimistic working copy; R GraphState registry = canonical truth.
# Fixed Full-Editor controls are hydrated locally and user changes travel over
# one revisioned patch input. Figure Controls keep their separate replay path.

  graph_browser_patch_explicit_paths <- c(
    project_name = "project_name",
    reshape_wide = "reshape.enabled", reshape_row_id = "reshape.row_id",
    reshape_columns = "reshape.columns", reshape_x_name = "reshape.x_name",
    reshape_y_name = "reshape.y_name",
    xvar = "mapping.x", yvar = "mapping.y", colorvar = "mapping.color",
    linetypevar = "mapping.linetype", shapevar = "mapping.shape",
    idvar = "mapping.id", facetvar = "mapping.facet",
    groupvar = "mapping.position", line_series_mode = "mapping.line_series_mode",
    line_series_var = "mapping.line_series_var",
    external_error_col = "mapping.external_error",
    external_ymin_col = "mapping.external_ymin",
    external_ymax_col = "mapping.external_ymax",
    plot_type = "plot.type", summary_type = "plot.summary",
    summary_unit = "plot.summary_unit", external_error_mode = "plot.external_error_mode",
    show_raw = "plot.show_raw", connect_id = "plot.connect_id",
    scatter_connect_mode = "plot.scatter_connect_mode", line_breaks = "plot.line_breaks",
    xlab = "labels.xlab", ylab = "labels.ylab", title = "labels.title",
    ymin = "labels.ymin", ymax = "labels.ymax", y_top_to_tick = "labels.y_top_to_tick"
  )

  graph_browser_patch_paths_for_state <- function(state) {
    paths <- graph_browser_patch_explicit_paths
    app <- if (is.list(state) && is.list(state$style) && is.list(state$style$appearance)) state$style$appearance else list()
    default_style_keys <- setdiff(names(graph_snapshot_input_defaults()), names(graph_browser_patch_explicit_paths))
    for (key in unique(c(names(app), default_style_keys))) {
      if (!key %in% names(paths) && !identical(key, "sticky_plot")) paths[[key]] <- paste0("style.appearance.", key)
    }
    if ("plot_width_px" %in% names(app)) paths[["plot_width_px_direct"]] <- "style.appearance.plot_width_px"
    if ("plot_height_px" %in% names(app)) paths[["plot_height_px_direct"]] <- "style.appearance.plot_height_px"
    paths
  }


  # RC13: dependent browser topology only needs a full local re-hydration when
  # choices/visibility topology can change. Ordinary numeric/text/color edits
  # already live in the browser working copy and are ACKed directly; replaying
  # all 134 controls on every spinner step only creates avoidable browser work.
  graph_browser_patch_needs_hydration <- function(key) {
    as.character(key %||% "")[1] %in% c(
      "reshape_wide", "reshape_row_id", "reshape_columns",
      "reshape_x_name", "reshape_y_name",
      "xvar", "yvar", "colorvar", "linetypevar", "shapevar", "idvar",
      "facetvar", "groupvar", "line_series_mode", "line_series_var",
      "external_error_mode", "plot_type", "summary_type", "summary_unit",
      "show_raw", "connect_id", "scatter_connect_mode"
    )
  }

  graph_browser_patch_epoch <- reactiveVal(0L)
  graph_browser_patch_last_seq <- new.env(parent = emptyenv())

  graph_browser_patch_values_from_state <- function(state, owned_only = NULL) {
    values <- utils::modifyList(graph_snapshot_input_defaults(), graph_ui_seed_from_state(state))
    values$project_name <- graph_state_scalar(state$project_name, "")
    values$reshape_wide <- isTRUE((state$reshape %||% list())$enabled)
    values$reshape_row_id <- isTRUE((state$reshape %||% list())$row_id)
    values$reshape_x_name <- graph_state_scalar((state$reshape %||% list())$x_name, "Time")
    values$reshape_y_name <- graph_state_scalar((state$reshape %||% list())$y_name, "Value")
    values$reshape_columns <- as.character((state$reshape %||% list())$columns %||% character(0))
    values$line_breaks <- as.character((state$plot %||% list())$line_breaks %||% character(0))
    paths <- graph_browser_patch_paths_for_state(state)
    keys <- intersect(names(paths), names(values))
    if (!is.null(owned_only)) keys <- intersect(keys, as.character(owned_only))
    out <- list()
    for (key in keys) if (!is.null(values[[key]])) out[[key]] <- values[[key]]
    out
  }

  graph_browser_patch_client_state <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !cache_has(id)) return(NULL)
    state <- cache_get(id)
    list(enabled = TRUE, graphId = id,
         revision = graph_render_state_revision_value(id),
         values = graph_browser_patch_values_from_state(state),
         paths = as.list(graph_browser_patch_paths_for_state(state)))
  }

  graph_browser_patch_override_for_owner <- function(id) {
    graph_browser_patch_epoch()
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !cache_has(id)) return(NULL)
    state <- cache_get(id)
    paths <- graph_browser_patch_paths_for_state(state)
    list(active = TRUE, graphId = id,
         revision = graph_render_state_revision_value(id),
         values = graph_browser_patch_values_from_state(state, owned_only = names(paths)),
         paths = paths)
  }

  graph_browser_patch_normalize <- function(key, path, value, state) {
    key <- as.character(key %||% "")[1]
    if (key %in% c("reshape_columns", "line_breaks")) {
      return(list(ok = TRUE, value = as.character(unlist(value %||% character(0), use.names = FALSE))))
    }
    current <- graph_settings_manager_get_result(state, path)
    old <- if (is.list(current) && isTRUE(current$found)) current$value else NULL
    normalized <- graph_normalize_browser_input_value(key, value, previous = old)
    if (!isTRUE(normalized$ok)) {
      kind <- as.character(normalized$kind %||% "value")[[1]]
      return(list(ok = FALSE, message = paste0(key, " must be ", kind)))
    }
    list(ok = TRUE, value = normalized$value)
  }

  graph_browser_patch_result <- function(id, seq, accepted, path = "", key = "",
                                         revision = NULL, value = NULL,
                                         reason = "", canonical_values = NULL) {
    payload <- list(graphId = as.character(id %||% "")[1],
      seq = suppressWarnings(as.integer(seq %||% 0L)[1]), accepted = isTRUE(accepted),
      path = as.character(path %||% "")[1], key = as.character(key %||% "")[1],
      revision = as.integer(revision %||% graph_render_state_revision_value(id)),
      reason = as.character(reason %||% "")[1])
    if (!is.null(value)) payload$value <- value
    if (is.list(canonical_values)) payload$canonicalValues <- canonical_values
    session$sendCustomMessage("graph-browser-patch-result", app_json_safe_tree(payload))
    invisible(payload)
  }

  observeEvent(input$graph_browser_patch, {
    req <- input$graph_browser_patch
    if (!is.list(req)) return()
    id <- as.character(req$graphId %||% "")[1]
    key <- as.character(req$key %||% "")[1]
    path <- as.character(req$path %||% "")[1]
    seq <- suppressWarnings(as.integer(req$seq %||% 0L)[1])
    base_revision <- suppressWarnings(as.integer(req$baseRevision %||% -1L)[1])
    canonical <- if (nzchar(id) && cache_has(id)) cache_get(id) else NULL
    allowed_paths <- if (is.list(canonical)) graph_browser_patch_paths_for_state(canonical) else character(0)
    expected_path <- if (key %in% names(allowed_paths)) unname(allowed_paths[[key]]) else ""

    reject <- function(reason) {
      current <- if (nzchar(id) && cache_has(id)) cache_get(id) else NULL
      graph_browser_patch_result(id, seq, FALSE, path, key,
        revision = if (nzchar(id)) graph_render_state_revision_value(id) else 0L,
        reason = reason,
        canonical_values = if (is.list(current)) graph_browser_patch_values_from_state(current) else list())
      diag_log("BROWSER-PATCH", paste0("REJECT seq=", seq, " reason=", reason), id = if (nzchar(id)) id else NULL)
      invisible(NULL)
    }

    if (!nzchar(id) || !identical(id, graph_single_owner()) || !graph_single_ready(id)) return(reject("owner-not-ready"))
    if (!nzchar(expected_path) || !identical(path, expected_path)) return(reject("path-not-whitelisted"))
    if (!is.finite(seq) || seq <= 0L) return(reject("invalid-seq"))
    last_seq <- suppressWarnings(as.integer(graph_browser_patch_last_seq[[id]] %||% 0L))
    if (seq <= last_seq) return(reject("stale-seq"))
    current_revision <- graph_render_state_revision_value(id)
    if (!identical(base_revision, current_revision)) return(reject("revision-mismatch"))

    old <- cache_get(id)
    if (!is.list(old)) return(reject("canonical-state-missing"))
    normalized <- graph_browser_patch_normalize(key, path, req$value, old)
    if (!isTRUE(normalized$ok)) return(reject(normalized$message %||% "invalid-value"))
    new <- graph_settings_manager_set_path(old, path, normalized$value)

    # Wide→Long changes can replace the effective X/Y/Color/etc. column
    # universe just like replacing Data text. Commit the reshape recipe and its
    # dependent Mapping reconciliation atomically; otherwise browser choices can
    # show Time/Value while canonical Mapping still points at pre-reshape columns
    # and make_plot exits immediately with an X/Y validation message.
    if (key %in% c("reshape_wide", "reshape_row_id", "reshape_columns",
                   "reshape_x_name", "reshape_y_name")) {
      reconciled <- tryCatch(
        graph_reconcile_mapping_for_schema_change(old, new),
        error = function(e) NULL
      )
      if (is.list(reconciled) && is.list(reconciled$state)) {
        new <- reconciled$state
        changed_mapping <- as.character(reconciled$changed_keys %||% character(0))
        if (length(changed_mapping)) {
          diag_log(
            "RESHAPE-MAPPING-RECONCILE",
            paste0("key=", key, " mapping={", paste(changed_mapping, collapse = ","), "}"),
            id = id
          )
        }
      }
    }

    result <- graph_settings_manager_commit_exact(id, new, source = "browser-working-state")
    graph_browser_patch_last_seq[[id]] <- seq

    # A delayed browser event may still reach this defensive boundary even
    # though the client distinguishes hydration from user edits. A canonical
    # no-op must only ACK the sequence: do not invalidate render reactives,
    # reattach canonical state, republish pools, or claim a new Editor lease.
    if (!isTRUE(result$changed) && !isTRUE(result$render)) {
      revision <- graph_render_state_revision_value(id)
      graph_browser_patch_result(id, seq, TRUE, path, key, revision,
        normalized$value, "no-op")
      diag_log("BROWSER-PATCH",
        paste0("ACCEPT seq=", seq, " key=", key, " base_revision=", base_revision,
               " revision=", revision,
               " changed=FALSE render=FALSE early_return=TRUE update_input_return=FALSE"), id = id)
      return()
    }

    graph_browser_patch_epoch(as.integer(isolate(graph_browser_patch_epoch()) %||% 0L) + 1L)

    mod_now <- graph_single_mod()
    if (!is.null(mod_now) && is.function(mod_now$accept_canonical)) {
      try(mod_now$accept_canonical(cache_get(id), reason = "browser-working-state", seed_render = FALSE), silent = TRUE)
    }
    if (isTRUE(graph_browser_patch_needs_hydration(key)) &&
        !is.null(mod_now) && is.function(mod_now$refresh_browser_hydration)) {
      try(mod_now$refresh_browser_hydration(cache_get(id), graph_id = id), silent = TRUE)
    } else if (key %in% c("plot_type", "colorvar", "linetypevar", "shapevar", "groupvar") &&
               !is.null(mod_now) && is.function(mod_now$refresh_browser_pools)) {
      try(mod_now$refresh_browser_pools(cache_get(id)), silent = TRUE)
    }
    graph_single_claim_revision(id, reason = "browser-working-state")
    graph_single_mark_editor_visit(id)

    revision <- graph_render_state_revision_value(id)
    graph_browser_patch_result(id, seq, TRUE, path, key, revision,
      normalized$value, if (isTRUE(result$changed)) "accepted" else "no-op")
    diag_log("BROWSER-PATCH",
      paste0("ACCEPT seq=", seq, " key=", key, " base_revision=", base_revision,
             " revision=", revision, " changed=", isTRUE(result$changed),
             " render=", isTRUE(result$render), " update_input_return=FALSE"), id = id)
  }, ignoreInit = TRUE, priority = 160)
