shinyServer(function(input, output, session) {

  # ------------------------------------------------------------------
  # v3.3.56 diagnostic timeline (Graph + Figure responsibility separation experiment)
  # ------------------------------------------------------------------
  diag_t0 <- proc.time()[["elapsed"]]
  diag_log <- function(tag, ..., id = NULL) {
    elapsed <- proc.time()[["elapsed"]] - diag_t0
    stamp <- format(Sys.time(), "%H:%M:%OS3")
    bits <- c(...)
    bits <- bits[!is.na(bits)]
    msg <- paste(bits, collapse = " ")
    id_txt <- if (!is.null(id) && nzchar(as.character(id))) paste0("[", as.character(id), "]") else ""
    message(sprintf("[DIAG %s +%7.3fs][%s]%s %s", stamp, elapsed, tag, id_txt, msg))
    invisible(NULL)
  }
  diag_log("SESSION", paste0("server start ", app_version()))
  if (identical(as.character(app_font_catalog$backend %||% "fallback"), "systemfonts")) {
    diag_log(
      "FONT-SCAN",
      paste0(
        "backend=systemfonts count=", length(app_font_catalog$families %||% character(0)),
        " japanese_candidates=", paste(app_font_catalog$japanese_candidates %||% character(0), collapse = ","),
        " cairo=", isTRUE(capabilities("cairo"))
      )
    )
  } else {
    diag_log(
      "FONT-SCAN-FALLBACK",
      paste0(
        "backend=fallback count=", length(app_font_catalog$families %||% character(0)),
        " reason=", as.character(app_font_catalog$error %||% "unknown"),
        " cairo=", isTRUE(capabilities("cairo"))
      )
    )
  }
  # v3.57: graphServer is byte-compiled once in global.R during app startup.
  # Reuse the same compiled closure for source Graphs and Figure editors.
  graph_server_runtime <- if (exists("graphServerCompiled", inherits = TRUE) && is.function(graphServerCompiled)) {
    graphServerCompiled
  } else {
    graphServer
  }
  if (exists("graph_server_precompile_info", inherits = TRUE) && is.list(graph_server_precompile_info)) {
    info <- graph_server_precompile_info
    diag_log(
      "PRECOMPILE",
      paste0(
        "ok=", isTRUE(info$ok),
        " elapsed_ms=", sprintf("%.1f", as.numeric(info$elapsed_ms %||% NA_real_)),
        " env_R_ENABLE_JIT=", as.character(info$env_R_ENABLE_JIT %||% "<unknown>"),
        " body_type_before=", as.character(info$body_type_before %||% "<unknown>"),
        " body_type_after=", as.character(info$body_type_after %||% "<unknown>"),
        if (!is.null(info$error)) paste0(" error=", as.character(info$error)) else ""
      )
    )
  } else {
    diag_log("PRECOMPILE", "metadata unavailable; using graphServer fallback")
  }

  diag_svg_viewport_seen <- new.env(parent = emptyenv())
  diag_figure_frame_seen <- new.env(parent = emptyenv())
  diag_figure_autofit_seen <- new.env(parent = emptyenv())
  diag_figure_legend_bbox_seen <- new.env(parent = emptyenv())
  diag_graph_size_meta_seen <- new.env(parent = emptyenv())
  diag_graph_geometry_seen <- new.env(parent = emptyenv())
  diag_figure_size_basis_seen <- new.env(parent = emptyenv())
  diag_svg_colors <- function(svg, n = 8L) {
    svg <- as.character(svg %||% "")
    if (!nzchar(svg)) return("colors=<none>")
    hits <- regmatches(svg, gregexpr("#[0-9A-Fa-f]{6}", svg, perl = TRUE))[[1]]
    if (!length(hits) || identical(hits, "")) return("colors=<no-hex-colors>")
    tab <- sort(table(toupper(hits)), decreasing = TRUE)
    tab <- head(tab, n)
    paste0("colors=", paste0(names(tab), "x", as.integer(tab), collapse = ","))
  }

  # ------------------------------------------------------------------
  # Graph registry
  # ------------------------------------------------------------------
  # Canonical GraphState registry. Normal Graphs are rendered only by the one
  # persistent Graph Editor; dormant Graphs remain pure state until selected.
  graph_state_cache <- reactiveVal(list())
  graph_state_revision <- new.env(parent = emptyenv())

  graph_state_revision_value <- function(id) {
    as.integer(graph_state_revision[[as.character(id %||% "")[1]]] %||% 0L)
  }

  # Graph間・Project間で使う一時的な「書式クリップボード」。
  # Project stateとは独立しているため、同じShiny session内なら
  # Project Aでコピー -> Project Bで貼り付け ができる。
  style_clipboard <- reactiveVal(NULL)

  # v3.73.0: one semantic Shared Label / Style Library per Project. Graph
  # bindings live inside each canonical GraphState; Figure remains snapshot-
  # independent unless its explicit Library sync switch is enabled.
  shared_style_library <- reactiveVal(shared_style_default_library())
  figure_shared_style_sync <- reactiveVal(FALSE)
  shared_style_graph_replay_pending <- reactiveVal(NULL)

  graph_meta <- reactiveVal(data.frame(
    id = "g001", name = "Graph 1", stringsAsFactors = FALSE
  ))
  active_graph <- reactiveVal("g001")
  # v3.73.1 Editor-first workspace: active_graph is the selected target while
  # editing_graph_id is the Graph currently owned by the singleton Editor. They
  # may differ only transiently during an ACK-gated switch or failure fallback.
  editing_graph_id <- reactiveVal("")

  # v3.61.0: Graph workspace owns exactly one reusable editor DOM/module.
  # Graph identity is data (editing_graph_id), never module namespace identity.
  graph_single_editor_id <- "graph_editor_single"
  graph_single_editor_wrapper_id <- "panel_graph_editor_single"
  graph_single_editor_module <- reactiveVal(NULL)
  graph_single_editor_mode <- reactiveVal("IDLE")      # IDLE / REPLAY / RENDERING / READY / STALE
  graph_single_editor_loading <- reactiveVal(FALSE)
  # v3.73.1 Editor-first selection may change while the singleton Editor is
  # still hydrating. Keep only the latest requested target and drain it after
  # the current ACK-gated transaction reaches READY; never interrupt/commit a
  # partially restored owner.
  graph_single_pending_target <- reactiveVal(NULL)
  graph_single_editor_generation <- reactiveVal(0L)
  # v3.72.10: the persistent Editor may publish only while it still owns the
  # canonical GraphState revision it was synchronized from. External canonical
  # updates (for example Figure -> Graph Apply) invalidate this lease so stale
  # browser state cannot overwrite a newer Registry revision on tab switch or
  # a delayed live callback.
  graph_single_editor_lease <- reactiveVal(NULL)
  # v3.66.3: transaction-level render gate for the persistent Editor.  Closed
  # for the entire REPLAY transaction, opened exactly once after the
  # READY editor state has been accepted against the canonical revision. New sessions start closed so the
  # pristine shell does not draw a throw-away default Plot before g001 attach.
  graph_single_render_gate <- reactiveVal(FALSE)
  # v3.73.2.18: normal Graph switches use the permanently mounted live plot.
  # When Plot is visible, keep the transaction loading until the browser reports
  # completion of the new plot output; no cached/live bind or authorize handshake.
  graph_single_live_render_wait <- reactiveVal(NULL)
  graph_single_default_state <- reactiveVal(NULL)
  # v3.73.2.3: the first capture happens before every dynamic browser control
  # has reported its normalized default. Finalize the reusable new-Graph
  # template once the startup Graph reaches READY.
  graph_single_default_state_finalized <- reactiveVal(FALSE)
  # v3.72.7: lightweight per-Graph editor-visit metadata.  This deliberately
  # stores revisions only -- never Graph DOM, Shiny modules, prepared data or
  # ggplot objects -- so revisits can be diagnosed/optimized without memory
  # growing with the number of editor instances.
  graph_single_editor_visit_cache <- new.env(parent = emptyenv())
  # v3.73.2.18: presentation state now belongs to canonical GraphState. This
  # lightweight server store mirrors the latest browser panel-open snapshot so
  # ordinary GraphState commits can include it without keeping per-Graph DOM.
  graph_editor_ui_panel_store <- reactiveVal(list())

  id_counter <- reactiveVal(1L)

  # The static g001 graphUI shell is already present in ui.R. The heavy
  # server-side Editor is scheduled after the first browser flush. Project load
  # is state-first and attaches only its selected Graph to this same Editor.
  diag_log("STARTUP-EDITOR", "eager g001 editor scheduled for first flush", id = "g001")

  # ------------------------------------------------------------------
  # Project file status
  # ------------------------------------------------------------------
  project_file_read <- reactiveVal(FALSE)
  project_save_destination_available <- reactiveVal(FALSE)

  # Project restore lock covers bundle parsing + canonical/Figure state staging.
  # Dormant Graphs have no restore worker; after staging, only the selected Graph
  # is attached to the one persistent Editor.
  project_load_locked <- reactiveVal(FALSE)
  project_load_ids <- reactiveVal(character(0))
  project_load_failure <- reactiveVal(NULL)

  project_graph_label <- function(id) {
    id <- as.character(id %||% "")
    meta <- isolate(graph_meta())
    hit <- match(id, meta$id)
    if (!is.na(hit)) as.character(meta$name[[hit]] %||% id) else id
  }

  send_project_load_overlay <- function(mode = c("loading", "hidden", "failed"), message = "", ready = NULL, total = NULL, current = NULL) {
    mode <- match.arg(mode)
    ready_n <- suppressWarnings(as.integer(ready %||% NA_integer_)[1])
    total_n <- suppressWarnings(as.integer(total %||% NA_integer_)[1])
    current_n <- suppressWarnings(as.integer(current %||% NA_integer_)[1])
    pct <- if (is.finite(ready_n) && is.finite(total_n) && total_n > 0) {
      min(100, max(0, round(100 * ready_n / total_n)))
    } else {
      NA_integer_
    }
    session$sendCustomMessage(
      "project-load-overlay",
      list(
        mode = mode,
        message = as.character(message %||% ""),
        ready = if (is.finite(ready_n)) ready_n else NULL,
        total = if (is.finite(total_n)) total_n else NULL,
        current = if (is.finite(current_n)) current_n else NULL,
        percent = if (is.finite(pct)) pct else NULL
      )
    )
    invisible(NULL)
  }

  project_load_action_blocked <- function(action = "", id = NULL) {
    if (!isTRUE(isolate(project_load_locked()))) return(FALSE)
    diag_log(
      "PROJECT-LOCK",
      paste0("BLOCKED action=", as.character(action %||% "")),
      id = as.character(id %||% "")
    )
    TRUE
  }

  begin_project_load_lock <- function() {
    project_load_locked(TRUE)
    project_load_ids(character(0))
    project_load_failure(NULL)
    diag_log("PROJECT-LOCK", "LOCKED")
    send_project_load_overlay("loading", "Projectファイルを読み込んでいます…", ready = 0L, total = NULL, current = NULL)
    invisible(NULL)
  }

  update_project_load_lock <- function(current_id = NULL) {
    if (!isTRUE(isolate(project_load_locked()))) return(invisible(NULL))
    ids <- as.character(isolate(project_load_ids()) %||% character(0))
    total <- length(ids)
    ready_n <- if (total) {
      sum(vapply(ids, function(id) cache_has(id) && is.list(cache_get(id)), logical(1)))
    } else 0L
    current_id <- as.character(current_id %||% "")
    current_idx <- if (nzchar(current_id) && current_id %in% ids) match(current_id, ids) else NA_integer_
    current_label <- if (nzchar(current_id)) project_graph_label(current_id) else ""
    message <- if (total && is.finite(current_idx)) {
      paste0("Graph ", current_idx, " / ", total, " を準備中", if (nzchar(current_label)) paste0("（", current_label, "）") else "")
    } else if (total) {
      paste0("Graphを準備しています… ", ready_n, " / ", total)
    } else {
      "Projectファイルを読み込んでいます…"
    }
    send_project_load_overlay(
      "loading",
      message,
      ready = ready_n,
      total = total,
      current = current_idx
    )
    invisible(NULL)
  }

  complete_project_load_lock <- function(reason = "all Project Graphs READY") {
    if (!isTRUE(isolate(project_load_locked()))) return(invisible(NULL))
    project_load_locked(FALSE)
    project_load_failure(NULL)
    diag_log("PROJECT-LOCK", paste0("UNLOCKED reason=", as.character(reason %||% "")))
    send_project_load_overlay("hidden", "")
    invisible(NULL)
  }

  fail_project_load_lock <- function(id = NULL, detail = "") {
    if (!isTRUE(isolate(project_load_locked()))) return(invisible(NULL))
    id <- as.character(id %||% "")
    label <- if (nzchar(id)) project_graph_label(id) else "Project"
    detail <- as.character(detail %||% "")
    msg <- if (nzchar(detail)) {
      paste0(label, " の復元に失敗しました。\n", detail, "\nアプリを再読み込みしてProjectを開き直してください。")
    } else {
      paste0(label, " の復元に失敗しました。\nアプリを再読み込みしてProjectを開き直してください。")
    }
    project_load_failure(list(id = id, message = msg))
    diag_log("PROJECT-LOCK", paste0("FAILED id=", id, " detail=", detail))
    send_project_load_overlay("failed", msg)
    invisible(NULL)
  }

  # 保存先記憶は表示名ではなくProject UUIDをキーにする。
  new_project_uuid <- function() {
    b <- sample.int(256L, 16L, replace = TRUE) - 1L
    b[7] <- bitwOr(bitwAnd(b[7], 15L), 64L)
    b[9] <- bitwOr(bitwAnd(b[9], 63L), 128L)
    h <- sprintf("%02x", b)
    paste0(
      paste0(h[1:4], collapse = ""), "-",
      paste0(h[5:6], collapse = ""), "-",
      paste0(h[7:8], collapse = ""), "-",
      paste0(h[9:10], collapse = ""), "-",
      paste0(h[11:16], collapse = "")
    )
  }

  valid_project_uuid <- function(x) {
    x <- as.character(x %||% "")
    length(x) == 1L && grepl(
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      x
    )
  }

  project_uuid <- reactiveVal(new_project_uuid())
  project_uuid_save_override <- reactiveVal(NULL)
  project_remember_pref <- reactiveVal(FALSE)
  project_name_save_override <- reactiveVal(NULL)

  # Export and Figure source generation are canonical GraphState -> value
  # operations. There is no hidden per-Graph materialization lifecycle.

  # Figure PreviewはExportとは独立した準備queueを持つ。
  # v3.3.46: Preview中心Figure Editor試作。Layout state一本化 + click/drag編集。
  # 読み込んだplot/export情報はsnapshotとして保持し、Graph側の編集では自動更新しない。
  figure_queue <- reactiveVal(character(0))
  figure_load_pending <- reactiveVal(FALSE)
  figure_load_target_ids <- reactiveVal(character(0))
  # F1-5b: Inset source refresh is explicit and independent from the main
  # Figure Graph load action.  Store only the currently requested asynchronous
  # Inset source here; the shared Graph materialization machinery remains the
  # single authority for making a dormant Graph READY.
  figure_inset_refresh_target <- reactiveVal(list(owner_id = "", source_id = ""))
  # Explicit Main-Graph refresh for the currently selected Figure panel.  This
  # is intentionally separate from both bulk Figure loading and Inset refresh.
  figure_panel_refresh_target <- reactiveVal(list(id = "", key = ""))
  # Explicit Figure-side Inset snapshots.  Unlike the retired Graph SVG cache, this
  # cache changes only when the user presses the Inset update action.
  figure_inset_preview_cache <- reactiveVal(list())
  figure_requested_ids <- reactiveVal(character(0))
  figure_requested_layout <- reactiveVal(list())
  figure_requested_overrides <- reactiveVal(list())
  figure_override_drafts <- reactiveVal(list())
  # Plot-affecting subset only. Overlay-only edits (e.g. moving A/B labels)
  # must not invalidate ggplot rendering.
  figure_plot_overrides <- reactiveVal(list())
  figure_plot_revisions <- reactiveValues()
  # Panel display revision is independent from ggplot regeneration. Alignment,
  # Crop/Inset and slot-label changes must still invalidate the cell UI while
  # Auto-fit geometry is Manual/Locked/Fixed.
  figure_panel_display_revisions <- reactiveValues()
  # Snapshot invalidation is also per Graph. A newly loaded Graph must not make
  # every other Figure panel rebuild merely because one shared list changed.
  figure_snapshot_revisions <- reactiveValues()
  figure_requested_width <- reactiveVal(1600)
  figure_requested_height <- reactiveVal(1000)
  # v3.3.68: auto-fit derives the effective Figure canvas from occupied Graph content.
  figure_requested_size_mode <- reactiveVal("auto")
  # Measured bbox used as the global Figure alignment basis.
  figure_requested_size_basis <- reactiveVal("plot")
  # Optional Row-level visual alignment for Graph titles. This is independent
  # from the Plot/Facet/Axis sizing basis and never changes GraphState.
  figure_requested_title_align <- reactiveVal("none")
  # v3.4.0-alpha1: Row layout remains the stable default; free layout uses the
  # same cell identities and persists independent free-canvas geometry.
  figure_requested_layout_mode <- reactiveVal("row")
  # v3.4.0-alpha2: auto-fit recomputation policy. live follows every geometry
  # change; manual recomputes only on Refit; lock freezes the last geometry.
  figure_requested_autofit_policy <- reactiveVal("live")
  figure_autofit_revision <- reactiveVal(0L)
  # Increment only when an override can change measured/layout geometry.
  # STYLE_ONLY edits redraw the source but do not force Auto-fit measurement.
  figure_geometry_revision <- reactiveVal(0L)
  # v3.72.9: Project cache-first bootstrap must not synchronously remeasure every
  # Figure source before the persisted Graph/Figure SVGs have reached the browser.
  # While TRUE, figure_source_sizes() uses persisted snapshot metadata only.
  # Exact gtable geometry is promoted lazily when the Figure workspace is opened.
  figure_geometry_bootstrap_deferred <- reactiveVal(FALSE)
  figure_workspace_active <- reactiveVal(FALSE)
  release_figure_geometry_bootstrap <- function(reason = "explicit-demand") {
    if (!isTRUE(isolate(figure_geometry_bootstrap_deferred()))) return(invisible(FALSE))
    figure_geometry_bootstrap_deferred(FALSE)
    figure_geometry_revision(as.integer(isolate(figure_geometry_revision()) %||% 0L) + 1L)
    diag_log("FIGURE-GEOMETRY-DEFER", paste0("released reason=", reason))
    invisible(TRUE)
  }
  figure_reorder_undo <- reactiveVal(NULL)
  figure_requested_free_padding <- reactiveVal(24)
  figure_external_assets <- reactiveVal(list())
  figure_requested_external_assets <- reactiveVal(list())
  figure_requested_gap_x <- reactiveVal(12)
  figure_requested_gap_y <- reactiveVal(12)
  # During Project restore the browser-side numericInputs update one flush later.
  # Keep restored Figure dimensions authoritative until those inputs catch up,
  # otherwise old-Project input values can overwrite the newly restored state.
  figure_control_restore_seed <- reactiveVal(NULL)
  figure_loaded_plots <- reactiveVal(list())
  figure_loaded_exports <- reactiveVal(list())
  # Generic in-session Figure assets. Internal Graphs are the only implemented
  # source today, but the container shape is intentionally source-agnostic so
  # external SVG/raster assets and inset sources can be added without changing
  # the Row/Panel layout schema again.
  figure_loaded_assets <- reactiveVal(list())

  # F1-5p: editable GraphState snapshots owned by Figure. These are copied from
  # the source Graph only on an explicit Figure load/refresh, then diverge
  # independently. Figure editor modules commit here, never to GraphState registry.
  figure_edit_states <- reactiveVal(list())
  figure_editor_modules <- new.env(parent = emptyenv())
  figure_editor_mounted <- new.env(parent = emptyenv())
  figure_editor_activated <- new.env(parent = emptyenv())
  # Epoch prevents callbacks from editor modules belonging to an older Project
  # from touching a newly restored Figure after workspace reset.
  figure_editor_epoch <- reactiveVal(1L)
  figure_editor_mount_generation <- reactiveVal(0L)
  figure_editor_mount_pending <- reactiveVal(list(id = "", editor_id = "", wrapper_id = "", generation = 0L))
  # v3.60.0: Figure owns one reusable controls-only Graph editor. Panel
  # selection and editor ownership are independent; selecting a panel never
  # mounts/loads the heavy editor. The fixed editor is loaded only by explicit
  # Graph-settings edit intent.
  figure_editing_graph <- reactiveVal("")
  figure_single_editor_loading <- reactiveVal(FALSE)
  figure_single_editor_show_when_ready <- reactiveVal(TRUE)
  # State currently being replayed by the one Figure renderer.  This may be a
  # temporary source GraphState (Inset/refresh) that must never be committed to
  # Figure-owned editable state.
  figure_single_editor_target_state <- reactiveVal(NULL)
  figure_single_editor_generation <- reactiveVal(0L)
  # Figure editor load completion is owned by the value-replay browser barrier.
  figure_single_editor_mode <- reactiveVal("IDLE")

  figure_load_progress <- reactiveVal(NULL)
  figure_load_expected_revisions <- reactiveVal(list())
  # Persistent preview assets loaded from a packaged Project. These are display
  # caches only; Graph/Figure state remains authoritative. Keys always use the
  # current session Graph IDs after Project ID remapping.
  figure_persisted_previews <- reactiveVal(list())
  # v3.72: Graphs newly assigned to Figure are explicit source imports.  While
  # a source is hydrating, keep only its id here; READY consumes the request
  # exactly once.  Existing Figure-owned snapshots are never auto-refreshed.
  figure_pending_new_imports <- reactiveVal(character(0))
  # Canonical GraphState revisions and render-state revisions are different.
  # Only the latter wakes preview publication after a canonical commit.
  graph_render_state_revisions <- reactiveValues()

  bump_graph_render_state_revision <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))
    cur <- suppressWarnings(as.integer(isolate(graph_render_state_revisions[[id]] %||% 0L)))
    graph_render_state_revisions[[id]] <- cur + 1L
    invisible(TRUE)
  }

  # v3.72 Figure source lifecycle -------------------------------------------
  # A Figure-owned Graph snapshot exists only while that Graph is referenced
  # by the current Figure (main panel or enabled inset of a current panel).
  # Removing the last reference ends Figure ownership; a later re-add is a
  # fresh import from the current canonical/live Graph.
  figure_referenced_graph_ids <- function(layout = NULL, overrides = NULL) {
    if (is.null(layout)) layout <- isolate(figure_layout_state())
    if (is.null(overrides)) overrides <- isolate(figure_override_drafts())
    meta_ids <- as.character(isolate(graph_meta())$id %||% character(0))

    main_ids <- unique(unlist(lapply(layout %||% list(), function(row) {
      vapply(row$cells %||% list(), function(cell) {
        st <- as.character(cell$source_type %||% "internal_graph")[1]
        id <- as.character(cell$id %||% "")[1]
        if (identical(st, "internal_graph") && nzchar(id)) id else ""
      }, character(1))
    }), use.names = FALSE))
    main_ids <- intersect(main_ids[nzchar(main_ids)], meta_ids)

    inset_ids <- character(0)
    for (owner in main_ids) {
      ov <- overrides[[owner]] %||% list()
      inset <- ov$inset %||% list()
      sid <- as.character(inset$source_id %||% "")[1]
      if (isTRUE(inset$enabled) && nzchar(sid) && sid %in% meta_ids) {
        inset_ids <- c(inset_ids, sid)
      }
    }
    unique(c(main_ids, inset_ids))
  }

  figure_source_cache_ids <- function() {
    unique(c(
      names(isolate(figure_edit_states())),
      names(isolate(figure_loaded_plots())),
      names(isolate(figure_loaded_exports())),
      names(isolate(figure_loaded_assets())),
      names(isolate(figure_persisted_previews())),
      names(isolate(figure_override_drafts())),
      names(isolate(figure_inset_preview_cache()))
    ))
  }

  figure_evict_source_state <- function(id, reason = "unreferenced") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))
    if (exists("cancel_figure_source_snapshot_jobs", mode = "function", inherits = TRUE)) {
      cancel_figure_source_snapshot_jobs(id, reason = reason)
    }

    drop_named <- function(rv) {
      x <- isolate(rv())
      if (id %in% names(x)) {
        x[[id]] <- NULL
        rv(x)
      }
    }
    drop_named(figure_edit_states)
    drop_named(figure_loaded_plots)
    drop_named(figure_loaded_exports)
    drop_named(figure_loaded_assets)
    drop_named(figure_persisted_previews)
    drop_named(figure_inset_preview_cache)
    drop_named(figure_override_drafts)
    drop_named(figure_requested_overrides)

    try(figure_plot_revisions[[id]] <- NULL, silent = TRUE)
    try(figure_snapshot_revisions[[id]] <- NULL, silent = TRUE)
    try(figure_panel_display_revisions[[id]] <- NULL, silent = TRUE)
    commit_revs <- isolate(figure_commit_edit_revisions())
    if (id %in% names(commit_revs)) {
      commit_revs[[id]] <- NULL
      figure_commit_edit_revisions(commit_revs)
    }
    try(clear_figure_geometry_cache(id), silent = TRUE)
    try(clear_figure_geometry_source_state(id), silent = TRUE)
    try(clear_figure_svg_cache(), silent = TRUE)

    pending <- isolate(figure_pending_new_imports())
    figure_pending_new_imports(setdiff(pending, id))

    if (identical(as.character(isolate(figure_editing_graph()) %||% "")[1], id) &&
        exists("reset_figure_editors", mode = "function", inherits = TRUE)) {
      try(reset_figure_editors(clear_states = FALSE), silent = TRUE)
    }
    diag_log("FIGURE-SOURCE-GC", paste0("evicted reason=", reason), id = id)
    invisible(TRUE)
  }

  figure_gc_unreferenced_sources <- function(reason = "layout-change") {
    keep <- figure_referenced_graph_ids()
    stale <- setdiff(figure_source_cache_ids(), keep)
    if (length(stale)) {
      for (id in stale) figure_evict_source_state(id, reason = reason)
    }
    diag_log(
      "FIGURE-SOURCE-GC",
      paste0("keep={", paste(keep, collapse=","), "} evicted={", paste(stale, collapse=","), "} reason=", reason)
    )
    invisible(stale)
  }

  figure_mark_new_import <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))
    figure_pending_new_imports(unique(c(isolate(figure_pending_new_imports()), id)))
    invisible(TRUE)
  }

  figure_clear_new_import <- function(id) {
    id <- as.character(id %||% "")[1]
    figure_pending_new_imports(setdiff(isolate(figure_pending_new_imports()), id))
    invisible(TRUE)
  }

  # v3.73.2.18: the client catalog is metadata-only. Graph SVG is not a
  # workspace authority and is never regenerated merely to populate tabs.
  publish_client_preview_catalog <- function(reason = "update", selected = NULL, enter_browse = FALSE) {
    meta <- isolate(graph_meta())
    if (!nrow(meta)) return(invisible(FALSE))
    entries <- lapply(seq_len(nrow(meta)), function(i) {
      list(
        id = as.character(meta$id[[i]]),
        name = as.character(meta$name[[i]]),
        svg = "",
        width = 600,
        height = 600
      )
    })
    selected_id <- as.character(selected %||% "")[1]
    if (!nzchar(selected_id)) selected_id <- as.character(isolate(input$graph_client_selected %||% ""))[1]
    if (!nzchar(selected_id) || !selected_id %in% meta$id) selected_id <- as.character(isolate(active_graph()) %||% "")[1]
    if (!nzchar(selected_id) || !selected_id %in% meta$id) selected_id <- as.character(meta$id[[1]])

    editing_id <- as.character(isolate(editing_graph_id()) %||% "")[1]
    editing_valid <- nzchar(editing_id) && editing_id %in% meta$id
    editing_ready <- isTRUE(editing_valid) && graph_single_ready(editing_id)
    editing_name <- if (isTRUE(editing_valid)) {
      nm <- meta$name[match(editing_id, meta$id)]
      if (length(nm) && !is.na(nm)) as.character(nm) else editing_id
    } else ""
    payload <- list(
      reason = as.character(reason %||% "update"),
      selected = selected_id,
      editing = if (isTRUE(editing_valid)) editing_id else "",
      editingName = editing_name,
      editingReady = isTRUE(editing_ready),
      # Browse-only preview mode is retired. Keep the field for protocol
      # compatibility but never request entry into it.
      enterBrowse = FALSE,
      entries = entries
    )
    session$onFlushed(function() {
      session$sendCustomMessage("graph-client-preview-catalog", payload)
    }, once = TRUE)
    invisible(TRUE)
  }

  selected_graph_id <- function() {
    meta <- isolate(graph_meta())
    id <- as.character(isolate(input$graph_client_selected %||% ""))[1]
    if (nzchar(id) && id %in% meta$id) return(id)
    as.character(isolate(active_graph()) %||% "")[1]
  }

  observe({
    graph_meta()
    active_graph()
    editing_graph_id()
    publish_client_preview_catalog(reason = "registry-metadata-change")
  })


  # v3.73.2.18: fixed Global Preview cached/live router retired. The one
  # persistent Editor owns the only live Graph plot output.

  project_bundle_pending_previews <- reactiveVal(list())
  project_bundle_pending_inset_previews <- reactiveVal(list())
  project_bundle_pending_graph_previews <- reactiveVal(list())
  project_legacy_graph_previews <- reactiveVal(list())

  # v3.3.49 experimental Figure renderer: vector preview snapshots are an
  # in-session display cache only. They are intentionally NOT reactive and are
  # never serialized into Project files. The logical Figure state remains the
  # source of truth, so a cache miss can always be regenerated from the ggplot.
  figure_svg_cache <- new.env(parent = emptyenv())
  clear_figure_svg_cache <- function(keys = NULL) {
    if (is.null(keys)) {
      rm(list = ls(envir = figure_svg_cache, all.names = TRUE), envir = figure_svg_cache)
    } else {
      keys <- intersect(as.character(keys), ls(envir = figure_svg_cache, all.names = TRUE))
      if (length(keys)) rm(list = keys, envir = figure_svg_cache)
    }
    invisible(NULL)
  }

  # Phase 11: cache only the measured source geometry, never the authored
  # Graph/Figure state.  Layout-only edits can invalidate figure_source_sizes()
  # many times even though the underlying Graph snapshot + geometry-affecting
  # override are unchanged.  Reusing this small immutable metadata avoids
  # repeated figure_plot_for_scale()/ggplotGrob() work while preserving the
  # existing downstream target-box fitting semantics.
  figure_geometry_cache <- new.env(parent = emptyenv())
  # Phase 12 (11.1): geometry cache invalidation is independent from ordinary
  # Figure snapshot refreshes.  A panel click / explicit Figure reload may
  # legitimately take a fresh snapshot without changing the canonical GraphState.
  # Keep a small semantic source-state mirror so only real GraphState changes
  # advance the geometry-source revision.
  figure_geometry_source_states <- new.env(parent = emptyenv())
  figure_geometry_source_revisions <- reactiveValues()
  clear_figure_geometry_cache <- function(id = NULL) {
    keys <- ls(envir = figure_geometry_cache, all.names = TRUE)
    if (!length(keys)) return(invisible(NULL))
    if (is.null(id)) {
      rm(list = keys, envir = figure_geometry_cache)
    } else {
      prefix <- paste0(as.character(id)[1], "::")
      hit <- keys[startsWith(keys, prefix)]
      if (length(hit)) rm(list = hit, envir = figure_geometry_cache)
    }
    invisible(NULL)
  }

  clear_figure_geometry_source_state <- function(id = NULL) {
    keys <- ls(envir = figure_geometry_source_states, all.names = TRUE)
    if (is.null(id)) {
      if (length(keys)) rm(list = keys, envir = figure_geometry_source_states)
      rev_ids <- names(isolate(reactiveValuesToList(figure_geometry_source_revisions)))
      if (length(rev_ids)) {
        for (rid in rev_ids) try(figure_geometry_source_revisions[[rid]] <- NULL, silent = TRUE)
      }
    } else {
      id <- as.character(id %||% "")[1]
      if (nzchar(id) && id %in% keys) rm(list = id, envir = figure_geometry_source_states)
      if (nzchar(id)) try(figure_geometry_source_revisions[[id]] <- NULL, silent = TRUE)
    }
    invisible(NULL)
  }

  # F1-4 removed the transition-time detach snapshot helpers.  Legacy
  # snapshot fields remain loadable, but layer geometry is derived directly
  # from the current source-side plot state.

  figure_geometry_override_signature <- function(ov) {
    z <- modifyList(figure_default_override(), ov %||% list())
    app <- modifyList(figure_default_appearance_override(), z$appearance %||% list())
    # Keep this field set aligned with figure_override_change_class()'s
    # GRAPH_GEOMETRY classification.  Pure layer style / slot geometry must
    # not evict an otherwise reusable source-gtable measurement.
    sig <- list(
      legend = as.character(z$legend %||% "inherit")[1],
      legend_free_origin = figure_legend_source_origin(z),
      legend_title = figure_normalize_legend_title_mode(z$legend_title),
      legend_gap = suppressWarnings(as.numeric(z$legend_gap %||% 8)[1]),
      appearance = app[c(
        "title_mode", "title", "xlab_mode", "xlab", "ylab_mode", "ylab",
        "base_size", "axis_title_size", "axis_text_size", "point_size",
        "line_width", "ymin", "ymax"
      )]
    )
    paste(capture.output(dput(sig)), collapse = "")
  }

  figure_geometry_cache_key <- function(id, geometry_revision, ov, ex) {
    num1 <- function(x, fallback) {
      z <- suppressWarnings(as.numeric(x)[1])
      if (!is.finite(z)) fallback else z
    }
    # figure_plot_for_scale(..., scale=1) depends on the source export/device
    # dimensions, not the Row/Panel target rectangle.  Target fitting stays
    # downstream, so layout structural changes can safely reuse this base
    # geometry measurement.
    source_sig <- paste(
      format(num1(ex$panel_width_px %||% ex$plot_width_px, 600), digits = 15, trim = TRUE),
      format(num1(ex$panel_height_px %||% ex$plot_height_px, 600), digits = 15, trim = TRUE),
      format(num1(ex$plot_width_px %||% ex$width, 600), digits = 15, trim = TRUE),
      format(num1(ex$plot_height_px %||% ex$height, 600), digits = 15, trim = TRUE),
      format(num1(ex$reference_res, 120), digits = 15, trim = TRUE),
      sep = "|"
    )
    paste0(
      as.character(id)[1], "::",
      as.integer(geometry_revision %||% 0L), "::",
      source_sig, "::",
      figure_geometry_override_signature(ov)
    )
  }

  figure_measure_source_geometry_cached <- function(id, geometry_revision, p_raw, ov, ex) {
    if (is.null(p_raw)) return(NULL)
    key <- figure_geometry_cache_key(id, geometry_revision, ov, ex)
    if (exists(key, envir = figure_geometry_cache, inherits = FALSE)) {
      diag_log("FIGURE-GEOMETRY-CACHE", paste0("HIT revision=", as.integer(geometry_revision %||% 0L)), id = id)
      return(get(key, envir = figure_geometry_cache, inherits = FALSE))
    }
    diag_log("FIGURE-GEOMETRY-CACHE", paste0("MISS revision=", as.integer(geometry_revision %||% 0L)), id = id)
    source_ov <- figure_layer_source_override(ov)
    anchor <- tryCatch(figure_plot_for_scale(p_raw, source_ov, ex, 1), error = function(e) NULL)
    if (is.null(anchor)) return(NULL)

    # F1-4g: a free legend is an overlay and must not reserve empty source-side
    # layout space.  Measure the owner Graph from a legend-free body, while
    # retaining a mapped source legend bbox solely for initial detach/AutoCanvas.
    rendered <- anchor
    if (figure_legend_is_detached(ov)) {
      body_ov <- source_ov; body_ov$legend <- "none"
      body <- tryCatch(figure_plot_for_scale(p_raw, body_ov, ex, 1), error = function(e) NULL)
      if (is.list(body)) {
        rendered <- body
        rendered$legend_bbox <- figure_layer_map_bbox_to_body(anchor, body, anchor$legend_bbox)
        rendered$legend_visual_bbox <- figure_layer_map_bbox_to_body(anchor, body, anchor$legend_visual_bbox %||% anchor$legend_bbox)
        rendered$legend_outside_bbox <- figure_layer_map_bbox_to_body(anchor, body, anchor$legend_outside_bbox)
        rendered$legend_outside_visual_bbox <- figure_layer_map_bbox_to_body(anchor, body, anchor$legend_outside_visual_bbox %||% anchor$legend_outside_bbox)
        rendered$legend_state <- anchor$legend_state %||% rendered$legend_state
      }
    }

    # Store geometry metadata only.  Never retain a derived ggplot in this
    # cache: Figure source state and plot ownership remain outside the cache.
    keep <- c(
      "width", "height", "panel_left", "panel_top", "panel_width", "panel_height",
      "panel_bbox", "facet_bbox", "axis_outer_bbox", "content_outer_bbox", "title_bbox",
      "legend_bbox", "legend_visual_bbox", "legend_outside_bbox", "legend_outside_visual_bbox", "legend_state", "geometry_source"
    )
    measured <- rendered[intersect(keep, names(rendered))]
    assign(key, measured, envir = figure_geometry_cache)
    measured
  }

  # v3.3.46: Figure Editor uses an explicit layout state as the single source
  # of truth. Dynamic inputs only edit this state; they no longer determine
  # Row/Panel counts themselves. This avoids renderUI <-> input feedback loops.
  figure_layout_state <- reactiveVal(figure_default_layout_state())
  figure_selected_row <- reactiveVal(1L)
  figure_selected_graph <- reactiveVal("")
  figure_selected_panel_key <- reactiveVal("")
  figure_layout_initialized <- reactiveVal(FALSE)
  figure_drag_syncing <- reactiveVal(FALSE)
  figure_inspector_syncing <- reactiveVal(FALSE)
  figure_inspector_sync_generation <- reactiveVal(0L)
  # Per-source, per-commit-field edit revisions. A value-only comparison cannot
  # distinguish A -> B -> A while a commit is pending, so alpha4 records intent.
  figure_commit_edit_revisions <- reactiveVal(list())
  # Structural UI is regenerated only when rows/panels/graph assignments change.
  # Numeric edits (row height / panel width) update state without rebuilding their
  # own inputs, which prevents dynamic-input value bounce loops.
  figure_layout_ui_version <- reactiveVal(0L)
  figure_inspector_ui_revision <- reactiveVal(0L)

  bump_figure_layout_ui <- function() {
    figure_layout_ui_version(isolate(figure_layout_ui_version()) + 1L)
    invisible(NULL)
  }

  bump_figure_panel_display_revision <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!length(id) || is.na(id) || !nzchar(id)) return(invisible(NULL))
    cur <- isolate(figure_panel_display_revisions[[id]] %||% 0L)
    figure_panel_display_revisions[[id]] <- as.integer(cur) + 1L
    invisible(NULL)
  }

  sync_figure_inspector <- function() {
    # alpha4: synchronization is acknowledged by a hidden generation input that
    # is created with the rebuilt Inspector. Server flush count is not evidence
    # that the browser has registered the new inputs. Old generations can never
    # release a newer synchronization guard.
    gen <- isolate(figure_inspector_sync_generation()) + 1L
    figure_inspector_sync_generation(gen)
    figure_inspector_syncing(TRUE)
    figure_inspector_ui_revision(isolate(figure_inspector_ui_revision()) + 1L)
    invisible(gen)
  }

  observeEvent(input$figure_inspector_sync_generation, {
    got <- suppressWarnings(as.integer(input$figure_inspector_sync_generation)[1])
    want <- isolate(figure_inspector_sync_generation())
    if (length(got) == 1L && is.finite(got) && identical(as.integer(got), as.integer(want))) {
      figure_inspector_syncing(FALSE)
      diag_log("FIGURE-INSPECTOR", paste0("sync-ack generation=", want))
    }
  }, ignoreInit = FALSE)

  figure_commit_field_values <- function(ov) {
    z <- modifyList(figure_default_override(), ov %||% list())
    app <- modifyList(figure_default_appearance_override(), z$appearance %||% list())
    list(
      title = list(mode=app$title_mode, value=app$title),
      xlab = list(mode=app$xlab_mode, value=app$xlab),
      ylab = list(mode=app$ylab_mode, value=app$ylab)
    )
  }

  bump_figure_commit_edit_revisions <- function(id, old, new) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(NULL))
    a <- figure_commit_field_values(old); b <- figure_commit_field_values(new)
    allrev <- isolate(figure_commit_edit_revisions())
    rev <- allrev[[id]] %||% list()
    for (nm in names(b)) {
      if (!isTRUE(all.equal(a[[nm]], b[[nm]], check.attributes=FALSE))) {
        rev[[nm]] <- as.integer(rev[[nm]] %||% 0L) + 1L
      }
    }
    allrev[[id]] <- rev
    figure_commit_edit_revisions(allrev)
    invisible(NULL)
  }

  bump_figure_snapshot_revision <- function(id) {
    id <- as.character(id %||% "")
    if (!nzchar(id)) return(invisible(NULL))
    # Snapshot freshness and source-geometry validity are intentionally separate.
    # Ordinary panel selection / Figure reload may refresh the snapshot while the
    # canonical GraphState is unchanged; geometry cache must survive that case.
    cur <- isolate(figure_snapshot_revisions[[id]] %||% 0L)
    figure_snapshot_revisions[[id]] <- as.integer(cur) + 1L
    invisible(NULL)
  }

  refresh_figure_geometry_source_revision <- function(id, state = NULL) {
    id <- as.character(id %||% "")
    if (!nzchar(id)) return(invisible(FALSE))
    if (is.null(state)) state <- cache_get(id)
    key <- id
    had <- exists(key, envir = figure_geometry_source_states, inherits = FALSE)
    old <- if (had) get(key, envir = figure_geometry_source_states, inherits = FALSE) else NULL
    changed <- !had || !identical(old, state)
    if (changed) {
      assign(key, state, envir = figure_geometry_source_states)
      cur <- isolate(figure_geometry_source_revisions[[id]] %||% 0L)
      figure_geometry_source_revisions[[id]] <- as.integer(cur) + 1L
      clear_figure_geometry_cache(id)
      diag_log(
        "FIGURE-GEOMETRY-SOURCE",
        paste0("CHANGED revision=", as.integer(cur) + 1L),
        id = id
      )
    } else {
      diag_log(
        "FIGURE-GEOMETRY-SOURCE",
        paste0("UNCHANGED revision=", as.integer(isolate(figure_geometry_source_revisions[[id]] %||% 0L))),
        id = id
      )
    }
    invisible(changed)
  }

  close_figure_load_progress <- function() {
    p <- isolate(figure_load_progress())
    if (!is.null(p)) try(p$close(), silent = TRUE)
    figure_load_progress(NULL)
    invisible(NULL)
  }

  session$onSessionEnded(function() {
    close_figure_load_progress()
  })

  safe_name <- function(x, fallback = "Graph") {
    x <- trimws(as.character(x %||% ""))
    if (!nzchar(x)) x <- fallback
    gsub("[\\/:*?\"<>|]+", "_", x)
  }

  next_id <- function() {
    n <- isolate(id_counter()) + 1L
    id_counter(n)
    sprintf("g%03d", n)
  }

  graph_single_mod <- function() isolate(graph_single_editor_module())

  graph_single_owner <- function() {
    as.character(isolate(editing_graph_id()) %||% "")[1]
  }

  graph_single_ready <- function(id = NULL) {
    owner <- graph_single_owner()
    target <- as.character(id %||% owner)[1]
    if (!nzchar(owner) || !identical(owner, target)) return(FALSE)
    mod <- graph_single_mod()
    !is.null(mod) && identical(as.character(isolate(graph_single_editor_mode()) %||% ""), "READY") &&
      isTRUE(tryCatch(isolate(mod$ready()), error = function(e) FALSE))
  }

  cache_has <- function(id) {
    id %in% names(isolate(graph_state_cache()))
  }

  cache_get <- function(id) {
    ca <- isolate(graph_state_cache())
    if (!id %in% names(ca)) return(NULL)
    ca[[id]]$state
  }

  cache_set <- function(id, state, source = "cache-set") {
    ca <- isolate(graph_state_cache())
    if (!identical(ca[[id]]$state, state)) {
      graph_state_revision[[id]] <- graph_state_revision_value(id) + 1L
    }
    ca[[id]] <- list(state = state)
    graph_state_cache(ca)
    invisible(TRUE)
  }

  # v3.4.0 alpha6 GraphState phase 1:
  # `graph_state_cache` is now treated as the canonical current GraphState
  # registry, not merely an eviction/load snapshot.  Existing storage shape
  # is intentionally preserved for .ggplotpack compatibility.
  #
  # A remounted Shiny namespace can briefly report NULL for inputs whose DOM
  # binding has not reappeared yet.  NULL is therefore treated as "not yet
  # observed" during live commits and the last canonical value is retained.
  # Explicit user clears from select/text inputs arrive as "" (or another
  # concrete value), so they are still committed normally.
  registry_merge_nonnull <- function(previous, candidate) {
    if (is.null(candidate)) return(previous)
    if (is.null(previous)) return(candidate)
    if (!is.list(candidate) || !is.list(previous)) return(candidate)

    out <- candidate
    cand_names <- names(candidate) %||% character(0)
    prev_names <- names(previous) %||% character(0)
    if (!length(cand_names)) return(candidate)

    # Only preserve an explicitly present NULL field.  Do not resurrect names
    # that are absent from the candidate: named collections such as statistics
    # recipes/styles must still be able to delete entries intentionally.
    for (nm in cand_names) {
      has_previous <- nm %in% prev_names
      if (is.null(candidate[[nm]])) {
        if (has_previous) out[[nm]] <- previous[[nm]]
        next
      }
      if (has_previous && is.list(candidate[[nm]]) && is.list(previous[[nm]])) {
        out[[nm]] <- registry_merge_nonnull(previous[[nm]], candidate[[nm]])
      }
    }
    out
  }

  registry_commit <- function(id, state, source = "unknown") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || is.null(state) || !is.list(state)) return(invisible(FALSE))

    # Canonical GraphState is the sole dormant-Graph authority. Renderers and
    # exporters consume values from this Registry without creating Graph modules.
    previous <- if (cache_has(id)) cache_get(id) else NULL
    canonical <- registry_merge_nonnull(previous, state)
    if (!is.null(previous) && identical(previous, canonical)) return(invisible(FALSE))

    render_changed <- is.null(previous) || isTRUE(graph_render_state_changed(previous, canonical))
    render_paths <- if (is.null(previous)) character(0) else graph_render_diff_paths(previous, canonical)

    cache_set(id, canonical, source = source)
    if (isTRUE(render_changed)) {
      bump_graph_render_state_revision(id)
    }
    plot_type <- tryCatch(as.character(canonical$plot$type %||% "<NULL>")[1], error = function(e) "<ERR>")
    diag_log(
      "STATE-COMMIT",
      paste0(
        "source=", source,
        " plot_type=", plot_type,
        " render_changed=", isTRUE(render_changed),
        if (length(render_paths)) paste0(" render_paths={", paste(head(render_paths, 16L), collapse=","), if (length(render_paths) > 16L) ",..." else "", "}") else ""
      ),
      id = id
    )
    invisible(TRUE)
  }

  cache_remove <- function(id) {
    ca <- isolate(graph_state_cache())
    ca[[id]] <- NULL
    graph_state_cache(ca)
    invisible(TRUE)
  }

  # v3.70.0 source split: server_figure_controls_runtime
  sys.source(file.path(getwd(), "server_figure_lifecycle_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "server_figure_controls_runtime.R"), envir = environment())

  # ------------------------------------------------------------------
  # Graph-owned SVG preview lifecycle
  # ------------------------------------------------------------------
  graph_preview_record_from_plot <- function(id, state, plot, export_meta, render_revision = NA_integer_, reason = "render") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state) || is.null(plot) || !is.list(export_meta)) return(NULL)

    rendered <- tryCatch(
      figure_plot_for_scale(plot, figure_default_override(id), export_meta, 1),
      error = function(e) {
        diag_log("GRAPH-PREVIEW", paste0("geometry ERROR reason=", reason, ": ", conditionMessage(e)), id = id)
        NULL
      }
    )
    if (is.null(rendered) || is.null(rendered$plot)) return(NULL)

    svg <- tryCatch(
      figure_plot_svg_text(
        rendered$plot, rendered$width, rendered$height,
        export_meta$reference_res %||% 120
      ),
      error = function(e) {
        diag_log("GRAPH-PREVIEW", paste0("SVG ERROR reason=", reason, ": ", conditionMessage(e)), id = id)
        ""
      }
    )
    if (!nzchar(svg %||% "")) return(NULL)

    list(
      svg = svg,
      meta = list(
        width = rendered$width,
        height = rendered$height,
        panel_left = rendered$panel_left,
        panel_top = rendered$panel_top,
        panel_width = rendered$panel_width,
        panel_height = rendered$panel_height,
        panel_bbox = rendered$panel_bbox,
        facet_bbox = rendered$facet_bbox,
        axis_outer_bbox = rendered$axis_outer_bbox,
        content_outer_bbox = rendered$content_outer_bbox,
        title_bbox = rendered$title_bbox,
        legend_bbox = rendered$legend_bbox,
        legend_visual_bbox = rendered$legend_visual_bbox %||% rendered$legend_bbox,
        legend_outside_bbox = rendered$legend_outside_bbox,
        legend_outside_visual_bbox = rendered$legend_outside_visual_bbox %||% rendered$legend_outside_bbox,
        geometry_source = rendered$geometry_source %||% "unknown",
        reference_res = export_meta$reference_res %||% 120
      ),
      state = state,
      render_revision = suppressWarnings(as.integer(render_revision %||% NA_integer_))
    )
  }

  # Graph SVG publication/cache lifecycle retired in v3.73.2.18. Temporary
  # vector consumers (Figure Inset / Statistics) call
  # graph_preview_record_from_plot() directly and retain the result in their
  # own ownership domain only.

  # ------------------------------------------------------------------
  # Lazy module creation
  # ------------------------------------------------------------------
  # v3.67.0 source split: server_graph_editor_runtime
  sys.source(file.path(getwd(), "server_graph_editor_runtime.R"), envir = environment())

  # v3.73.1: selection targets the Graph immediately and then auto-requests the
  # singleton Editor; hydration itself remains owned by the editor runtime.
  sys.source(file.path(getwd(), "server_graph_selection_runtime.R"), envir = environment())

  figure_editor_module_id <- function(id = NULL) {
    paste0("figure_editor_e", isolate(figure_editor_epoch()), "_single")
  }
  figure_editor_wrapper_id <- function(id = NULL) {
    paste0("figure_graph_editor_panel_e", isolate(figure_editor_epoch()), "_single")
  }

  figure_editor_module <- function(id = NULL) {
    editing_id <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    requested <- as.character(id %||% "")[1]
    if (nzchar(requested) && nzchar(editing_id) && !identical(requested, editing_id)) return(NULL)
    if (!exists("single", envir = figure_editor_modules, inherits = FALSE)) return(NULL)
    get("single", envir = figure_editor_modules, inherits = FALSE)
  }

  store_figure_edit_state <- function(id, state, reason = "editor") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state)) return(invisible(FALSE))
    states <- isolate(figure_edit_states())
    states[[id]] <- state
    figure_edit_states(states)
    diag_log("FIGURE-EDIT-STATE", paste0("stored reason=", reason, " plot_type=", as.character(state$plot$type %||% "<NULL>")[1]), id = id)
    invisible(TRUE)
  }

  figure_editor_snapshot_available <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(FALSE)
    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    !is.null(plots[[id]]) && is.list(exports[[id]])
  }

  capture_ready_figure_editor_payload <- function(id) {
    id <- as.character(id %||% "")[1]
    mod <- figure_editor_module(id)
    if (is.null(mod) || !isTRUE(tryCatch(isolate(mod$ready()), error = function(e) FALSE))) return(NULL)

    comp <- tryCatch({
      if (is.function(mod$figure_components)) isolate(mod$figure_components()) else NULL
    }, error = function(e) {
      diag_log("FIGURE-EDIT-SNAPSHOT", paste0("components ERROR: ", conditionMessage(e)), id = id)
      NULL
    })
    p <- tryCatch({
      if (is.list(comp) && !is.null(comp$plot)) comp$plot
      else if (is.function(mod$figure_plot)) isolate(mod$figure_plot())
      else isolate(mod$plot())
    }, error = function(e) NULL)
    ex <- tryCatch({
      if (is.list(comp) && is.list(comp$meta)) comp$meta
      else if (is.function(mod$figure_meta)) isolate(mod$figure_meta())
      else isolate(mod$export())
    }, error = function(e) NULL)
    if (is.null(p) || !is.list(ex)) return(NULL)

    epw <- suppressWarnings(as.numeric(ex$panel_width_px %||% NA_real_)[1])
    eph <- suppressWarnings(as.numeric(ex$panel_height_px %||% NA_real_)[1])
    if (!is.finite(epw) || epw <= 0 || !is.finite(eph) || eph <= 0) return(NULL)
    rr <- if (is.function(mod$render_revision)) {
      tryCatch(isolate(mod$render_revision()), error = function(e) NA_integer_)
    } else NA_integer_
    list(components = comp, plot = p, meta = ex, render_revision = rr)
  }

  preserve_figure_inset_snapshot_before_main_replace <- function(id, persisted_rec) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(persisted_rec) || !nzchar(persisted_rec$svg %||% "")) return(FALSE)
    inset_cache <- isolate(figure_inset_preview_cache())
    existing <- inset_cache[[id]]
    if (is.list(existing) && nzchar(existing$svg %||% "")) return(FALSE)
    # Main and Inset are independent Figure-owned snapshots. If an Inset is
    # currently falling back to the packaged Figure preview, preserve that exact
    # point-in-time asset before a Main edit invalidates the packaged fallback.
    inset_cache[[id]] <- persisted_rec
    figure_inset_preview_cache(inset_cache)
    bump_figure_snapshot_revision(id)
    diag_log("FIGURE-INSET", "preserved persisted fallback before Main snapshot replacement", id = id)
    TRUE
  }

  snapshot_ready_figure_editor <- function(id, state_now = NULL, payload = NULL) {
    id <- as.character(id %||% "")[1]
    if (!is.list(payload)) payload <- capture_ready_figure_editor_payload(id)
    if (!is.list(payload)) return(FALSE)
    mod <- figure_editor_module(id)
    comp <- payload$components
    p <- payload$plot
    ex <- payload$meta

    plots <- isolate(figure_loaded_plots())
    exports <- isolate(figure_loaded_exports())
    assets <- isolate(figure_loaded_assets())
    plots[[id]] <- p
    exports[[id]] <- ex
    assets[[id]] <- figure_make_internal_asset(id, comp = comp, plot = p, meta = ex)
    figure_loaded_plots(plots)
    figure_loaded_exports(exports)
    figure_loaded_assets(assets)

    # Once the editable Figure copy changes, an older packaged Figure SVG must
    # never win as a fallback. It will be regenerated from this live Figure copy
    # on the next Project save.
    persisted <- isolate(figure_persisted_previews())
    old_persisted <- persisted[[id]]
    preserve_figure_inset_snapshot_before_main_replace(id, old_persisted)
    persisted[[id]] <- NULL
    figure_persisted_previews(persisted)

    if (!is.list(state_now)) {
      state_now <- tryCatch(if (is.function(mod$state)) isolate(mod$state()) else NULL, error = function(e) NULL)
    }
    if (is.list(state_now)) refresh_figure_geometry_source_revision(id, state_now)

    # v3.41: Graph appearance now belongs to the editable Figure GraphState.
    # Neutralize the deprecated Appearance override after a valid editable
    # snapshot exists, without touching Figure-owned legend placement/crop/inset.
    drafts_now <- isolate(figure_override_drafts())
    raw_ov_now <- drafts_now[[id]] %||% figure_default_override(id)
    old_app_now <- modifyList(figure_default_appearance_override(), raw_ov_now$appearance %||% list())
    def_app_now <- figure_default_appearance_override()
    if (!identical(old_app_now, def_app_now)) {
      raw_ov_now$appearance <- def_app_now
      drafts_now[[id]] <- raw_ov_now
      figure_override_drafts(drafts_now)
      figure_requested_overrides(drafts_now)
      diag_log("FIGURE-APPEARANCE-MIGRATE", "legacy Figure appearance override cleared; editable GraphState now owns appearance", id=id)
    }

    bump_figure_snapshot_revision(id)
    ov_now <- figure_override_for(id, isolate(figure_requested_overrides()))
    diag_log(
      "FIGURE-EDIT-SNAPSHOT",
      paste0(
        "updated Figure-only plot/export snapshot; source Graph unchanged",
        " legend_scope=", figure_legend_layer_scope(ov_now),
        " legend_mode=", as.character(ov_now$legend %||% "inherit")[1],
        if (figure_legend_is_detached(ov_now)) paste0(
          " free_xy=", round(as.numeric(ov_now$legend_free_x %||% 0.75), 4), ",",
          round(as.numeric(ov_now$legend_free_y %||% 0.08), 4),
          " source_origin=", figure_legend_source_origin(ov_now)
        ) else ""
      ),
      id = id
    )
    TRUE
  }

  invalidate_figure_main_snapshot_for_import <- function(id) {
    persisted <- isolate(figure_persisted_previews())
    preserve_figure_inset_snapshot_before_main_replace(id, persisted[[id]])
    persisted[[id]] <- NULL
    figure_persisted_previews(persisted)
    for (registry in list(figure_loaded_plots, figure_loaded_exports, figure_loaded_assets)) {
      records <- isolate(registry())
      records[[id]] <- NULL
      registry(records)
    }
    bump_figure_snapshot_revision(id)
    invisible(TRUE)
  }

  seed_figure_editor_from_source <- function(id, state, reason = "explicit-source-refresh", reload_editor = TRUE) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state)) return(invisible(FALSE))
    store_figure_edit_state(id, state, reason = reason)

    if (isTRUE(reload_editor)) reload_visible_figure_editor_after_snapshot(id, reason)
    invisible(TRUE)
  }

  reload_visible_figure_editor_after_snapshot <- function(ids, reason = "source-import-complete") {
    owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    if (!nzchar(owner) || !owner %in% ids || !figure_workspace_is_active() ||
        !isTRUE(isolate(figure_single_editor_show_when_ready()))) return(invisible(FALSE))
    state <- isolate(figure_edit_states())[[owner]]
    if (!is.list(state) || is.null(figure_editor_module(owner))) return(invisible(FALSE))
    # Enter replay immediately after the snapshot commit: no deferred callback
    # can switch owners or write the old editor values back before this gate.
    ok <- ensure_figure_editor(owner, force_reload = TRUE, preserve_current = FALSE,
                               show_when_ready = TRUE, state_override = state)
    diag_log("FIGURE-SOURCE-SYNC", paste0("visible editor resync reason=", reason), id = owner)
    invisible(ok)
  }

  reload_selected_figure_editor_after_bulk <- function(ids, reason = "bulk-import-complete") {
    reload_visible_figure_editor_after_snapshot(ids, reason)
  }

  show_figure_editor_wrapper <- function(id = "") {
    id <- as.character(id %||% "")[1]
    wrapper <- if (nzchar(id)) figure_editor_wrapper_id() else ""
    session$sendCustomMessage("figure-editor-select", list(wrapperId = wrapper))
    invisible(NULL)
  }

  reset_figure_editors <- function(clear_states = TRUE) {
    show_figure_editor_wrapper("")
    try(removeUI(selector = "#figure_graph_editor_host .figure-graph-editor-instance", multiple = TRUE, immediate = TRUE), silent = TRUE)
    if (length(ls(envir = figure_editor_modules, all.names = TRUE))) {
      rm(list = ls(envir = figure_editor_modules, all.names = TRUE), envir = figure_editor_modules)
    }
    if (length(ls(envir = figure_editor_mounted, all.names = TRUE))) {
      rm(list = ls(envir = figure_editor_mounted, all.names = TRUE), envir = figure_editor_mounted)
    }
    if (length(ls(envir = figure_editor_activated, all.names = TRUE))) {
      rm(list = ls(envir = figure_editor_activated, all.names = TRUE), envir = figure_editor_activated)
    }
    figure_editor_epoch(as.integer(isolate(figure_editor_epoch()) %||% 0L) + 1L)
    figure_editor_mount_pending(list(id="", editor_id="", wrapper_id="", generation=isolate(figure_editor_mount_generation())))
    figure_editing_graph("")
    figure_single_editor_loading(FALSE)
    figure_single_editor_show_when_ready(TRUE)
    figure_single_editor_target_state(NULL)
    figure_single_editor_mode("IDLE")
    figure_single_editor_generation(as.integer(isolate(figure_single_editor_generation()) %||% 0L) + 1L)
    if (isTRUE(clear_states)) figure_edit_states(list())
    invisible(NULL)
  }

  request_figure_editor_mount_ack <- function(id, editor_id, wrapper_id) {
    gen <- as.integer(isolate(figure_editor_mount_generation()) %||% 0L) + 1L
    figure_editor_mount_generation(gen)
    figure_editor_mount_pending(list(id=id, editor_id=editor_id, wrapper_id=wrapper_id, generation=gen))
    session$onFlushed(function() {
      pending <- isolate(figure_editor_mount_pending())
      if (!identical(as.integer(pending$generation %||% 0L), gen) || !identical(as.character(pending$id %||% ""), id)) return()
      st <- isolate(figure_edit_states())[[id]]
      rs <- if (is.list(st)) st$reshape %||% list() else list()
      fields <- list(
        list(field = "plot_type", id = shiny::NS(editor_id, "plot_type")),
        list(field = "reshape_wide", id = shiny::NS(editor_id, "reshape_wide")),
        list(field = "graph_main_tab", id = shiny::NS(editor_id, "graph_main_tab"))
      )
      if (isTRUE(rs$enabled)) {
        fields <- c(fields, list(
          list(field = "reshape_row_id", id = shiny::NS(editor_id, "reshape_row_id")),
          list(field = "reshape_x_name", id = shiny::NS(editor_id, "reshape_x_name")),
          list(field = "reshape_y_name", id = shiny::NS(editor_id, "reshape_y_name"))
        ))
      }
      session$sendCustomMessage(
        "graph-ui-mount-check",
        list(
          generation = gen,
          graphId = editor_id,
          panelId = wrapper_id,
          fields = fields,
          ackId = "figure_graph_editor_mount_ack"
        )
      )
      diag_log("FIGURE-EDIT-MOUNT", paste0("request generation=", gen), id = id)
    }, once = TRUE)
    invisible(TRUE)
  }

  ensure_figure_editor <- function(id, force_reload = FALSE, preserve_current = TRUE,
                                   show_when_ready = TRUE, state_override = NULL) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) { show_figure_editor_wrapper(""); return(FALSE) }

    loading_owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    if (isTRUE(isolate(figure_single_editor_loading())) && nzchar(loading_owner) && !identical(loading_owner, id)) {
      diag_log("FIGURE-SINGLE-EDITOR", paste0("load-rejected busy=", loading_owner), id = id)
      return(FALSE)
    }

    states <- isolate(figure_edit_states())
    state <- if (is.list(state_override)) state_override else states[[id]]
    if (!is.list(state)) {
      if (isTRUE(show_when_ready)) {
        showNotification("Figure側に編集可能なGraph snapshotがありません。先に『Graphから再読込』してください。", type="warning", duration=4)
      }
      return(FALSE)
    }

    editor_id <- figure_editor_module_id()
    wrapper_id <- figure_editor_wrapper_id()
    mounted <- exists("single", envir = figure_editor_mounted, inherits = FALSE) &&
      isTRUE(get("single", envir = figure_editor_mounted, inherits = FALSE))

    old_id <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    old_mod <- if (nzchar(old_id)) figure_editor_module(old_id) else NULL
    if (!isTRUE(force_reload) && identical(old_id, id) && !is.null(old_mod) &&
        isTRUE(tryCatch(isolate(old_mod$ready()), error = function(e) FALSE)) &&
        !isTRUE(isolate(figure_single_editor_loading()))) {
      figure_single_editor_show_when_ready(isTRUE(show_when_ready))
      if (isTRUE(show_when_ready)) show_figure_editor_wrapper(id) else show_figure_editor_wrapper("")
      diag_log("FIGURE-SINGLE-EDITOR", "reuse-hit", id = id)
      return(TRUE)
    }

    if (isTRUE(preserve_current) && nzchar(old_id) && !identical(old_id, id) && !is.null(old_mod) &&
        isTRUE(tryCatch(isolate(old_mod$ready()), error = function(e) FALSE)) &&
        isTRUE(isolate(figure_single_editor_show_when_ready()))) {
      old_state <- tryCatch(if (is.function(old_mod$state)) isolate(old_mod$state()) else NULL, error = function(e) NULL)
      if (is.list(old_state)) {
        store_figure_edit_state(old_id, old_state, reason = "single-editor-switch")
        snapshot_ready_figure_editor(old_id, old_state)
      }
    }

    figure_editing_graph(id)
    figure_single_editor_loading(TRUE)
    figure_single_editor_show_when_ready(isTRUE(show_when_ready))
    figure_single_editor_target_state(state)
    figure_single_editor_mode("REPLAY")
    next_generation <- as.integer(isolate(figure_single_editor_generation()) %||% 0L) + 1L
    figure_single_editor_generation(next_generation)
    show_figure_editor_wrapper("")
    diag_log(
      "FIGURE-SINGLE-EDITOR",
      paste0("load-request previous=", if (nzchar(old_id)) old_id else "<none>", " mode=REPLAY visible=", isTRUE(show_when_ready)),
      id = id
    )

    if (!mounted) {
      insertUI(
        selector = "#figure_graph_editor_host", where = "beforeEnd",
        ui = div(
          id = wrapper_id,
          class = "figure-graph-editor-instance",
          style = "display:none;",
          graphUI(editor_id, initial_state = state, mode = "controls")
        ),
        immediate = TRUE
      )
      assign("single", TRUE, envir = figure_editor_mounted)
      diag_log("FIGURE-SINGLE-EDITOR", paste0("UI inserted editor_id=", editor_id), id = id)
    }

    mod <- if (exists("single", envir = figure_editor_modules, inherits = FALSE))
      get("single", envir = figure_editor_modules, inherits = FALSE) else NULL
    if (is.null(mod)) {
      epoch0 <- isolate(figure_editor_epoch())
      diag_log("FIGURE-EDIT-INIT-TIMING", "mark=CALLSITE-BEFORE-GRAPHSERVER source=figure-single-editor", id = id)
      mod <- graph_server_runtime(
        editor_id,
        style_clipboard = style_clipboard,
        diag_log = function(tag, ..., id = NULL) {
          owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
          diag_log(paste0("FIGURE-EDIT-", tag), ..., id = if (nzchar(owner)) owner else NULL)
        },
        ui_preseeded = TRUE,
        controls_only = TRUE,
        on_state_change = function(state_now) {
          if (!identical(as.integer(isolate(figure_editor_epoch())), as.integer(epoch0))) return(invisible(NULL))
          if (isTRUE(isolate(figure_single_editor_loading()))) return(invisible(NULL))
          if (!isTRUE(isolate(figure_single_editor_show_when_ready()))) return(invisible(NULL))
          owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
          if (!nzchar(owner)) return(invisible(NULL))
          prev_state <- isolate(figure_edit_states())[[owner]]
          unchanged <- is.list(prev_state) && identical(prev_state, state_now)
          if (isTRUE(unchanged) && isTRUE(figure_editor_snapshot_available(owner))) return(invisible(NULL))
          if (!isTRUE(unchanged)) store_figure_edit_state(owner, state_now, reason = "figure-single-editor")
          snapshot_ready_figure_editor(owner, state_now)
        }
      )
      diag_log("FIGURE-EDIT-INIT-TIMING", "mark=CALLSITE-AFTER-GRAPHSERVER source=figure-single-editor", id = id)
      assign("single", mod, envir = figure_editor_modules)
      request_figure_editor_mount_ack(id, editor_id, wrapper_id)
    } else if (is.function(mod$replay_state)) {
      mod$replay_state(state, transaction = list(id = id, generation = next_generation, figure = TRUE))
    }

    TRUE
  }

  observeEvent(input$figure_graph_editor_mount_ack, {
    ack <- input$figure_graph_editor_mount_ack
    pending <- isolate(figure_editor_mount_pending())
    if (!is.list(ack) || !is.list(pending)) return()
    gen <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
    if (!is.finite(gen) || !identical(gen, as.integer(pending$generation %||% 0L))) return()
    id <- as.character(pending$id %||% "")[1]
    status <- as.character(ack$status %||% "")[1]
    diag_log(
      "FIGURE-EDIT-MOUNT",
      paste0("ack generation=", gen, " status=", status, " missing=", paste(as.character(unlist(ack$missing %||% character(0), use.names=FALSE)), collapse=",")),
      id = id
    )
    figure_editor_mount_pending(list(id="", editor_id="", wrapper_id="", generation=gen))
    if (!identical(status, "ready")) {
      figure_single_editor_loading(FALSE)
      figure_single_editor_mode("IDLE")
      showNotification("Figure Graph EditorのUI bindingを確認できませんでした。", type="warning", duration=4)
      return()
    }

    mod <- figure_editor_module(id)
    latest_state <- isolate(figure_single_editor_target_state())
    if (!is.list(latest_state)) latest_state <- isolate(figure_edit_states())[[id]]
    if (!is.null(mod) && is.list(latest_state) && is.function(mod$replay_state)) {
      replay_generation <- as.integer(isolate(figure_single_editor_generation()) %||% 0L)
      mod$replay_state(latest_state, transaction = list(id = id, generation = replay_generation, figure = TRUE))
      assign("single", TRUE, envir = figure_editor_activated)
    }
  }, ignoreInit = TRUE)

  # Figure owns one persistent controls-only editor. A load is complete when its
  # value replay has crossed the same single browser completion barrier used by
  # the main Graph Editor. No semantic readback/settle loop is required.
  observe({
    gen <- figure_single_editor_generation()
    loading <- figure_single_editor_loading()
    id <- as.character(figure_editing_graph() %||% "")[1]
    if (!isTRUE(loading) || !nzchar(id)) return()
    if (!exists("single", envir = figure_editor_modules, inherits = FALSE)) return()
    mod <- get("single", envir = figure_editor_modules, inherits = FALSE)
    pending_mount <- figure_editor_mount_pending()
    if (identical(as.character(pending_mount$id %||% "")[1], id)) return()
    if (is.function(mod$replay_active) && isTRUE(tryCatch(mod$replay_active(), error = function(e) FALSE))) return()
    if (!isTRUE(tryCatch(mod$ready(), error = function(e) FALSE))) return()

    # Value replay is complete in the browser. Release the requested Figure
    # GraphState as one final semantic render target now, rather than leaving
    # any intermediate controls-only render produced while inputs were being
    # replayed. This is a single post-barrier release, not a compare/retry loop.
    target_state <- isolate(figure_single_editor_target_state())
    render_release <- FALSE
    if (is.list(target_state) && is.function(mod$release_render_state)) {
      render_release <- isTRUE(tryCatch(
        mod$release_render_state(target_state, reason = "figure-replay-ready"),
        error = function(e) {
          diag_log("FIGURE-SINGLE-EDITOR", paste0("final render release ERROR: ", conditionMessage(e)), id = id)
          FALSE
        }
      ))
    }

    figure_single_editor_loading(FALSE)
    figure_single_editor_mode("READY")
    if (isTRUE(figure_single_editor_show_when_ready())) {
      show_figure_editor_wrapper(id)
    } else {
      show_figure_editor_wrapper("")
    }
    diag_log(
      "FIGURE-SINGLE-EDITOR",
      paste0("load-ready generation=", as.integer(gen), " mode=value-replay visible=", isTRUE(figure_single_editor_show_when_ready()),
             " final_render_release=", render_release),
      id = id
    )
  })

  # v3.67.0 source split: server_graph_workspace_runtime
  sys.source(file.path(getwd(), "server_graph_workspace_runtime.R"), envir = environment())

  # v3.73.0: central semantic style Library. Kept outside graphServer so Graphs
  # never synchronize directly with each other.
  sys.source(file.path(getwd(), "server_shared_style_runtime.R"), envir = environment())
  # v3.73.2.29: cross-Graph/Figure settings browser plus focused canonical
  # Graph batch helpers. Figure writes are sourced later after Figure services.
  sys.source(file.path(getwd(), "server_graph_settings_manager_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "server_graph_settings_batch_runtime.R"), envir = environment())

  pending_new_graph_default <- reactiveVal(NULL)

  next_graph_default_name <- function(meta) {
    existing <- if (!is.null(meta) && nrow(meta)) as.character(meta$name) else character(0)
    hits <- regmatches(existing, regexec("^Graph ([0-9]+)$", existing))
    nums <- suppressWarnings(vapply(
      hits,
      function(z) if (length(z) >= 2L) as.integer(z[2]) else NA_integer_,
      integer(1)
    ))
    nums <- nums[is.finite(nums)]
    paste0("Graph ", if (length(nums)) max(nums) + 1L else 1L)
  }

  show_new_graph_modal <- function() {
    meta <- isolate(graph_meta())
    default_nm <- next_graph_default_name(meta)
    pending_new_graph_default(default_nm)

    showModal(modalDialog(
      title = "新しいGraph",
      textInput(
        "new_graph_name",
        "Graph名",
        value = default_nm
      ),
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("create_graph_confirm", "作成", class = "btn-primary")
      ),
      easyClose = TRUE
    ))

    session$onFlushed(function() {
      session$sendCustomMessage(
        "focus-select-input",
        list(id = "new_graph_name")
      )
    }, once = TRUE)
  }

  observeEvent(input$graph_add, {
    if (project_load_action_blocked("graph-add")) return()
    show_new_graph_modal()
  })

  create_new_graph_from_modal <- function() {
    default_nm <- isolate(pending_new_graph_default())
    if (is.null(default_nm) || !nzchar(default_nm)) {
      meta <- isolate(graph_meta())
      default_nm <- next_graph_default_name(meta)
    }

    nm <- trimws(input$new_graph_name %||% "")
    if (!nzchar(nm)) nm <- default_nm

    removeModal()
    pending_new_graph_default(NULL)

    create_graph(
      nm,
      initial_state = NULL,
      select = TRUE
    )
  }

  observeEvent(input$create_graph_confirm, {
    create_new_graph_from_modal()
  })

  observeEvent(input$new_graph_enter, {
    if (isTRUE(input$new_graph_enter)) {
      create_new_graph_from_modal()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$graph_duplicate, {
    req <- input$graph_duplicate
    id <- if (is.list(req) && nzchar(as.character(req$id %||% ""))) as.character(req$id) else selected_graph_id()
    if (project_load_action_blocked("graph-duplicate", id)) return()

    # GraphState Registry is canonical. The ordinary editor is the persistent
    # graph_editor_single module. Before a
    # duplicate of the current editor owner is created, synchronously commit its
    # live state so an immediate Copy cannot lag behind the last UI edit.
    owner <- graph_single_owner()
    if (identical(id, owner) && isTRUE(isolate(graph_single_editor_loading()))) {
      showNotification("Graphの切替が終わってからコピーしてください。", type = "warning")
      return()
    }
    if (identical(id, owner) && graph_single_ready(id)) {
      graph_single_commit("duplicate-source")
    }

    state <- if (cache_has(id)) cache_get(id) else NULL
    if (is.null(state)) {
      showNotification("Graphの状態を取得できませんでした。", type = "error")
      return()
    }

    meta <- isolate(graph_meta())
    nm <- meta$name[match(id, meta$id)]

    # Duplicate only the canonical GraphState. The destination will replay
    # that state into the persistent Editor and render once when selected.
    new_id <- create_graph(
      paste0(nm, " copy"),
      initial_state = state,
      select = TRUE
    )
    diag_log(
      "DUPLICATE",
      paste0("source=", id, " new=", new_id, " state_only=TRUE"),
      id = new_id
    )
  })

  rename_target_graph <- reactiveVal(NULL)

  show_rename_graph_modal <- function(id) {
    meta <- isolate(graph_meta())
    if (is.null(id) || !id %in% meta$id) return(invisible(FALSE))

    nm <- meta$name[match(id, meta$id)]
    rename_target_graph(id)

    showModal(modalDialog(
      title = "Graph名を変更",
      textInput("rename_graph_text", "Graph名", value = nm),
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("rename_graph_confirm", "変更", class = "btn-primary")
      ),
      easyClose = TRUE
    ))

    session$onFlushed(function() {
      session$sendCustomMessage(
        "focus-select-input",
        list(id = "rename_graph_text")
      )
    }, once = TRUE)

    invisible(TRUE)
  }

  observeEvent(input$graph_rename, {
    req <- input$graph_rename
    id <- if (is.list(req) && nzchar(as.character(req$id %||% ""))) as.character(req$id) else selected_graph_id()
    if (project_load_action_blocked("graph-rename", id)) return()
    show_rename_graph_modal(id)
  })

  observeEvent(input$graph_rename_dblclick, {
    id <- as.character(input$graph_rename_dblclick %||% "")
    if (nzchar(id)) show_rename_graph_modal(id)
  }, ignoreInit = TRUE)

  apply_graph_rename <- function() {
    nm <- trimws(input$rename_graph_text %||% "")
    if (!nzchar(nm)) return(invisible(FALSE))

    meta <- isolate(graph_meta())
    id <- isolate(rename_target_graph())
    if (is.null(id) || !id %in% meta$id) {
      id <- isolate(active_graph())
    }
    if (is.null(id) || !id %in% meta$id) return(invisible(FALSE))

    meta$name[match(id, meta$id)] <- nm
    graph_meta(meta)
    refresh_export_choices()
    publish_client_preview_catalog(reason = "graph-renamed", selected = id)
    rename_target_graph(NULL)
    removeModal()
    invisible(TRUE)
  }

  observeEvent(input$rename_graph_confirm, {
    apply_graph_rename()
  })

  observeEvent(input$rename_graph_enter, {
    if (isTRUE(input$rename_graph_enter)) {
      apply_graph_rename()
    }
  }, ignoreInit = TRUE)

  # v3.65.2-activation-layout1: deletion remains structurally identical,
  # but warn when the Graph is currently referenced by Figure content.  This
  # is advisory only; the existing sanitizer is still the final safety net.
  figure_graph_reference_summary <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(list(total = 0L, panels = 0L, insets = 0L))

    panel_refs <- 0L
    st <- isolate(figure_layout_state())
    if (is.list(st) && length(st)) {
      for (row in st) {
        cells <- row$cells %||% list()
        if (!is.list(cells)) next
        for (cell in cells) {
          if (!is.list(cell)) next
          typ <- as.character(cell$source_type %||% "internal_graph")[1]
          sid <- as.character(cell$source_id %||% cell$id %||% "")[1]
          if (identical(typ, "internal_graph") && identical(sid, id)) panel_refs <- panel_refs + 1L
        }
      }
    }

    inset_refs <- 0L
    drafts <- isolate(figure_override_drafts())
    if (is.list(drafts) && length(drafts)) {
      for (ov in drafts) {
        if (!is.list(ov)) next
        inset <- ov$inset %||% list()
        if (!is.list(inset) || !isTRUE(inset$enabled)) next
        typ <- as.character(inset$source_type %||% "internal_graph")[1]
        sid <- as.character(inset$source_id %||% "")[1]
        if (identical(typ, "internal_graph") && identical(sid, id)) inset_refs <- inset_refs + 1L
      }
    }

    list(total = as.integer(panel_refs + inset_refs), panels = as.integer(panel_refs), insets = as.integer(inset_refs))
  }

  delete_target_graph <- reactiveVal(NULL)

  observeEvent(input$graph_delete, {
    meta <- isolate(graph_meta())
    req <- input$graph_delete
    id <- if (is.list(req) && nzchar(as.character(req$id %||% ""))) as.character(req$id) else selected_graph_id()
    if (project_load_action_blocked("graph-delete", id)) return()

    if (nrow(meta) <= 1) {
      showNotification("Projectには最低1つのGraphが必要です。", type = "warning")
      return()
    }

    # Only the one persistent Graph Editor can own an in-flight Graph transaction.
    single_editor_in_flight <- identical(id, graph_single_owner()) &&
      isTRUE(isolate(graph_single_editor_loading()))
    if (isTRUE(single_editor_in_flight)) {
      showNotification("Graphの切替が終わってから削除してください。", type = "warning")
      return()
    }

    nm <- meta$name[match(id, meta$id)]
    refs <- figure_graph_reference_summary(id)
    delete_target_graph(id)
    body <- tagList(
      tags$p(paste0("「", nm, "」を削除しますか？"))
    )
    if (isTRUE(refs$total > 0L)) {
      detail <- if (refs$insets > 0L) {
        paste0("Figure内で ", refs$total, " か所（配置 ", refs$panels, "、Inset ", refs$insets, "）から参照されています。")
      } else {
        paste0("Figure内で ", refs$total, " か所から参照されています。")
      }
      body <- tagList(
        body,
        tags$div(
          class = "alert alert-warning",
          tags$strong("Figureで使用中です。"),
          tags$br(),
          detail,
          tags$br(),
          "削除するとFigureからもこのGraphの参照が削除されます。"
        )
      )
    }
    showModal(modalDialog(
      title = "Graphを削除",
      body,
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("delete_graph_confirm", "削除", class = "btn-danger")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$delete_graph_confirm, {
    meta <- isolate(graph_meta())
    id <- as.character(isolate(delete_target_graph()) %||% selected_graph_id())[1]
    if (nrow(meta) <= 1) return()

    pos <- match(id, meta$id)
    was_editing <- identical(id, as.character(isolate(editing_graph_id()) %||% "")[1])
    cache_remove(id)
    if (exists(id, envir = graph_single_editor_visit_cache, inherits = FALSE)) {
      rm(list = id, envir = graph_single_editor_visit_cache)
    }

    # Remove Figure-owned snapshot references for the deleted Graph. There is
    # no Graph SVG cache to invalidate in the state-replay architecture.
    previews <- isolate(figure_persisted_previews())
    previews[[id]] <- NULL
    figure_persisted_previews(previews)

    plots <- isolate(figure_loaded_plots()); plots[[id]] <- NULL; figure_loaded_plots(plots)
    exports <- isolate(figure_loaded_exports()); exports[[id]] <- NULL; figure_loaded_exports(exports)
    assets <- isolate(figure_loaded_assets()); assets[[id]] <- NULL; figure_loaded_assets(assets)
    drafts <- isolate(figure_override_drafts()); drafts[[id]] <- NULL; figure_override_drafts(drafts)
    try(figure_plot_revisions[[id]] <- NULL, silent = TRUE)
    try(figure_snapshot_revisions[[id]] <- NULL, silent = TRUE)
    commit_revs <- isolate(figure_commit_edit_revisions())
    if (length(commit_revs) && id %in% names(commit_revs)) {
      commit_revs[[id]] <- NULL
      figure_commit_edit_revisions(commit_revs)
    }
    clear_figure_geometry_cache(id)
    clear_figure_geometry_source_state(id)

    figure_requested_ids(setdiff(isolate(figure_requested_ids()), id))
    clear_figure_svg_cache()

    meta <- meta[meta$id != id, , drop = FALSE]
    graph_meta(meta)
    diag_log("DELETE", "removed graph state/cache/preview/figure references", id = id)

    new_pos <- min(pos, nrow(meta))
    new_id <- meta$id[new_pos]

    refresh_export_choices()
    if (isTRUE(was_editing)) {
      editing_graph_id("")
      graph_single_editor_loading(FALSE)
      graph_single_editor_mode("IDLE")
      graph_single_editor_generation(as.integer(isolate(graph_single_editor_generation()) %||% 0L) + 1L)
      if (identical(as.character(isolate(active_graph()) %||% "")[1], id)) active_graph(new_id)
      session$sendCustomMessage("graph-editor-shell-clear", list(reason = "deleted-editing-graph", selected = new_id))
      diag_log("EDITOR-SHELL", "cleared reason=deleted-editing-graph")
    } else if (identical(as.character(isolate(active_graph()) %||% "")[1], id)) {
      # No live editor owned this Graph; keep the legacy active fallback valid.
      active_graph(new_id)
    }
    delete_target_graph(NULL)
    if (nzchar(new_id)) {
      select_graph_preview(new_id, source = "graph-deleted", publish = TRUE)
    } else {
      publish_client_preview_catalog(reason = "graph-deleted-empty", selected = NULL, enter_browse = FALSE)
    }
    removeModal()
  })

  # v3.70.0 source split: server_project_io_runtime
  sys.source(file.path(getwd(), "server_figure_inset_persistence_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "server_project_io_runtime.R"), envir = environment())

  # v3.70.0 source split: server_export_prepare_runtime
  sys.source(file.path(getwd(), "server_export_prepare_runtime.R"), envir = environment())

  # v3.73.2.22: direct GraphState-to-snapshot service; no Figure editor replay.
  sys.source(file.path(getwd(), "server_figure_source_snapshot_runtime.R"), envir = environment())

  # v3.70.0 source split: server_figure_workspace_runtime
  sys.source(file.path(getwd(), "server_figure_workspace_runtime.R"), envir = environment())

  # v3.73.2.29: typed external Settings Manager edits and explicit direct-state
  # Figure refresh. Sourced after Figure snapshot/workspace services exist.
  sys.source(file.path(getwd(), "server_graph_settings_value_runtime.R"), envir = environment())

  # v3.73.2.21: legacy/persisted Figure legend regeneration is an adapter
  # over the same single Figure value-replay renderer used by Main/Inset.
  sys.source(file.path(getwd(), "server_figure_legend_reactivity_runtime.R"), envir = environment())

  # v3.70.0 source split: server_graph_export_runtime
  sys.source(file.path(getwd(), "server_graph_export_runtime.R"), envir = environment())

})
