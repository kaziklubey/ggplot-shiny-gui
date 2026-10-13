  # ------------------------------------------------------------------
  # Graph single editor
  # ------------------------------------------------------------------
  # Data Document lease registry. A delayed browser edit is routed by the
  # Graph/lease identity carried in the payload itself, never by current Editor
  # selection. Re-visiting a Graph supersedes all older generations.
  graph_data_document_lease_generation <- new.env(parent = emptyenv())
  graph_data_document_last_seq <- new.env(parent = emptyenv())

  # One persistent Editor means there can be only one activation transaction at
  # a time. Keep a lightweight monotonic start timestamp solely for diagnostics;
  # it does not participate in synchronization or ownership.
  graph_single_activation_started_at <- reactiveVal(NA_real_)
  source("R/server/graph/server_graph_capture_boundary_runtime.R", local = TRUE)

  # Outer-runtime half of the bounded cold replay diagnostic.  This is plain
  # bookkeeping: it neither creates reactive dependencies nor changes the
  # persistent Editor transaction.  It is enabled only for the selected Graph
  # while the Project-load lock is held.
  graph_single_cold_diag <- new.env(parent = emptyenv())
  graph_single_cold_diag$active <- FALSE
  graph_single_cold_diag$id <- ""
  graph_single_cold_diag$generation <- 0L
  graph_single_cold_diag$started_at <- NA_real_
  graph_single_cold_diag$last_at <- NA_real_
  graph_single_cold_diag_mark <- function(phase, detail = "") {
    if (!isTRUE(graph_single_cold_diag$active)) return(invisible(FALSE))
    now <- proc.time()[["elapsed"]]
    diag_log("COLD-REPLAY-OUTER", paste0(
      "phase=", phase,
      " generation=", graph_single_cold_diag$generation,
      " elapsed_ms=", round((now - graph_single_cold_diag$started_at) * 1000, 1),
      " delta_prev_ms=", round((now - graph_single_cold_diag$last_at) * 1000, 1),
      if (nzchar(detail)) paste0(" ", detail) else ""
    ), id = graph_single_cold_diag$id)
    graph_single_cold_diag$last_at <- now
    invisible(TRUE)
  }
  graph_single_cold_diag_measure <- function(phase, fn) {
    if (!isTRUE(graph_single_cold_diag$active)) return(fn())
    t0 <- proc.time()[["elapsed"]]
    on.exit(graph_single_cold_diag_mark(phase, paste0("work_ms=", round((proc.time()[["elapsed"]] - t0) * 1000, 1))), add = TRUE)
    fn()
  }

  graph_data_document_register_lease <- function(id, generation) {
    id <- as.character(id %||% "")[[1]]
    generation <- suppressWarnings(as.integer(generation %||% 0L))
    if (!nzchar(id) || !is.finite(generation) || generation < 1L) return(invisible(FALSE))
    assign(id, generation, envir = graph_data_document_lease_generation)
    assign(paste0(id, "@", generation), 0L, envir = graph_data_document_last_seq)
    invisible(TRUE)
  }

  graph_data_document_lease_matches <- function(id, generation) {
    id <- as.character(id %||% "")[[1]]
    generation <- suppressWarnings(as.integer(generation %||% 0L))
    if (!nzchar(id) || !exists(id, envir = graph_data_document_lease_generation, inherits = FALSE)) return(FALSE)
    identical(as.integer(get(id, envir = graph_data_document_lease_generation, inherits = FALSE)), generation)
  }

  graph_single_mark_editor_visit <- function(id, generation = NULL) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))
    gen <- suppressWarnings(as.integer(generation %||% isolate(graph_single_editor_generation()) %||% 0L))
    graph_single_editor_visit_cache[[id]] <- list(
      state_revision = as.integer(graph_state_revision_value(id) %||% 0L),
      render_state_revision = suppressWarnings(as.integer(isolate(graph_render_state_revisions[[id]] %||% 0L))),
      generation = gen
    )
    invisible(TRUE)
  }

  graph_single_claim_revision <- function(id, reason = "sync") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !cache_has(id)) return(invisible(FALSE))
    lease <- list(
      id = id,
      revision = as.integer(graph_state_revision_value(id) %||% 0L),
      generation = as.integer(isolate(graph_single_editor_generation()) %||% 0L),
      reason = as.character(reason %||% "sync")[1]
    )
    graph_single_editor_lease(lease)
    diag_log(
      "GRAPH-SINGLE-LEASE",
      paste0("CLAIM revision=", lease$revision, " generation=", lease$generation, " reason=", lease$reason),
      id = id
    )
    if (identical(as.character(reason %||% "")[[1]], "load-ready-value-replay")) {
      graph_single_cold_diag_mark("lease-claim", paste0("revision=", lease$revision))
    }
    invisible(TRUE)
  }

  graph_single_revision_is_current <- function(id) {
    id <- as.character(id %||% "")[1]
    lease <- isolate(graph_single_editor_lease())
    is.list(lease) && nzchar(id) &&
      identical(as.character(lease$id %||% "")[1], id) &&
      identical(as.integer(lease$revision %||% -1L), as.integer(graph_state_revision_value(id) %||% 0L))
  }

  graph_single_mark_stale <- function(id, reason = "external-canonical-update") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !identical(id, graph_single_owner())) return(invisible(FALSE))
    graph_single_editor_lease(NULL)
    graph_single_editor_mode("STALE")
    if (exists(id, envir = graph_single_editor_visit_cache, inherits = FALSE)) {
      rm(list = id, envir = graph_single_editor_visit_cache)
    }
    diag_log(
      "GRAPH-SINGLE-LEASE",
      paste0("INVALIDATE reason=", reason, " canonical_revision=", as.integer(graph_state_revision_value(id) %||% 0L)),
      id = id
    )
    invisible(TRUE)
  }

  graph_ui_panels_for_id <- function(id, state = NULL) {
    id <- as.character(id %||% "")[1]
    if (!is.list(state) && nzchar(id) && cache_has(id)) state <- cache_get(id)
    snap <- if (is.list(state)) graph_ui_snapshot_normalize(state$ui_snapshot) else graph_ui_snapshot_normalize(NULL)
    snap$panels %||% list()
  }

  graph_single_publish_state <- function(id, state, source) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state)) return(invisible(FALSE))
    state <- graph_state_with_ui_snapshot(state, list(panels = graph_ui_panels_for_id(id, state)))
    if (!graph_single_revision_is_current(id)) {
      lease <- isolate(graph_single_editor_lease())
      diag_log(
        "GRAPH-SINGLE-PUBLISH-SKIP",
        paste0(
          "source=", source,
          " lease_revision=", as.integer(lease$revision %||% -1L),
          " canonical_revision=", as.integer(graph_state_revision_value(id) %||% 0L)
        ),
        id = id
      )
      return(invisible(FALSE))
    }
    changed <- registry_commit(id, state, source = source)
    if (isTRUE(changed)) {
      graph_single_claim_revision(id, reason = paste0("publish:", source))
      graph_single_mark_editor_visit(id)
    }
    invisible(isTRUE(changed))
  }


  finalize_graph_single_default_state <- function(id, state, generation, reason = "startup-ready") {
    if (isTRUE(isolate(graph_single_default_state_finalized()))) return(invisible(FALSE))
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation %||% -1L)
    if (!nzchar(id) || generation != 1L || !is.list(state)) return(invisible(FALSE))

    meta <- isolate(graph_meta())
    first_id <- if (is.data.frame(meta) && nrow(meta) && "id" %in% names(meta)) {
      as.character(meta$id[[1]] %||% "")[1]
    } else ""
    if (!nzchar(first_id) || !identical(id, first_id)) return(invisible(FALSE))

    stable <- tryCatch(unserialize(serialize(state, NULL, version = 3)), error = function(e) state)
    graph_single_default_state(stable)
    graph_single_default_state_finalized(TRUE)
    diag_log(
      "GRAPH-SINGLE-DEFAULT",
      paste0(
        "finalized default reason=", reason,
        " generation=", generation,
        " plot_type=", as.character((stable$plot %||% list())$type %||% "<NULL>"),
        " mapping=", as.character((stable$mapping %||% list())$x %||% "<NULL>"),
        "/", as.character((stable$mapping %||% list())$y %||% "<NULL>")
      ),
      id = id
    )
    invisible(TRUE)
  }

  graph_single_accept_loaded_state <- function(id, mod, now, generation) {
    graph_single_cold_diag_mark("canonical-accept-enter")
    canonical <- if (cache_has(id)) cache_get(id) else NULL
    if (!is.list(canonical)) {
      diag_log("GRAPH-SINGLE-EDITOR", "canonical GraphState missing at replay completion", id = id)
      return("failed")
    }

    # Normal Graph loading is value replay only. Do not read the browser back
    # and compare it with canonical state: invalid/legacy parameter combinations
    # are allowed to exist and the ordinary Plot error surface owns draw errors.
    # UI-only panel state is captured separately and never blocks activation.

    graph_single_cold_diag_measure("load_ready_value", function() {
      graph_single_claim_revision(id, reason = "load-ready-value-replay")
    })
    started_at <- suppressWarnings(as.numeric(isolate(graph_single_activation_started_at()) %||% NA_real_))
    if (is.finite(started_at)) {
      diag_log(
        "GRAPH-SINGLE-REPLAY-TIMING",
        paste0("phase=lease-claim elapsed_ms=", round((proc.time()[["elapsed"]] - started_at) * 1000, 1)),
        id = id
      )
    }
    "accepted"
  }

  graph_single_abort_activation <- function(id, reason = "activation-failed", message = NULL,
                                            type = "warning", generation = isolate(graph_single_editor_generation())) {
    id <- as.character(id %||% "")[1]
    if (!editor_activation_current(generation)) return(invisible(FALSE))
    reason <- as.character(reason %||% "activation-failed")[1]
    if (identical(as.integer(generation), 1L)) {
      session$sendCustomMessage("startup-load-failed", list(message = reason))
    }
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("IDLE")
    graph_single_editor_lease(NULL)
    graph_single_render_gate(FALSE)
    editing_graph_id("")
    session$sendCustomMessage(
      "graph-editor-shell-clear",
      list(selected = id, reason = reason, generation = as.integer(generation))
    )
    if (nzchar(id)) {
      # Failure-safe only: release the singleton and keep the last live plot
      # visible. No cached-preview fallback exists.
      active_graph(id)
      publish_client_graph_catalog(reason = "editor-activation-abort", selected = id)
    }
    diag_log(
      "GRAPH-SINGLE-EDITOR",
      paste0("activation aborted; Editor unready reason=", reason),
      id = if (nzchar(id)) id else NULL
    )
    if (isTRUE(isolate(project_load_locked())) && identical(id, isolate(active_graph()))) {
      fail_project_load_lock(id, reason)
    }
    if (is.null(message) || !nzchar(as.character(message %||% "")[1])) {
      message <- "Graph Editorへの反映を完了できませんでした。GraphStateは保持されています。"
    }
    showNotification(as.character(message)[1], type = as.character(type %||% "warning")[1])
    invisible(FALSE)
  }

  capture_graph_single_default_state <- function(reason = "unspecified") {
    existing <- isolate(graph_single_default_state())
    if (is.list(existing)) return(invisible(TRUE))
    mod <- graph_single_mod()
    if (is.null(mod) || !is.function(mod$state)) return(invisible(FALSE))
    st <- tryCatch(isolate(mod$state()), error = function(e) NULL)
    if (!is.list(st) || !is.list(st$plot) || !is.list(st$style)) return(invisible(FALSE))
    st <- graph_state_prepare_replay_snapshot(graph_sample_graph_state(st))
    if (!is.list(st)) return(invisible(FALSE))
    graph_single_default_state(st)
    diag_log(
      "GRAPH-SINGLE-EDITOR",
      paste0(
        "captured pristine default state reason=", reason,
        " plot_type=", as.character(st$plot$type %||% "<NULL>"),
        " mapping=", as.character((st$mapping %||% list())$x %||% "<NULL>"),
        "/", as.character((st$mapping %||% list())$y %||% "<NULL>"),
        " size=",
        as.character(st$style$appearance$plot_width_px %||% "<NULL>"), "x",
        as.character(st$style$appearance$plot_height_px %||% "<NULL>")
      )
    )
    invisible(TRUE)
  }

  graph_single_default_state_snapshot <- function(reason = "new-graph") {
    st <- isolate(graph_single_default_state())
    if (!is.list(st)) {
      capture_graph_single_default_state(reason)
      st <- isolate(graph_single_default_state())
    }
    if (!is.list(st)) return(NULL)
    # The registry/editor treat GraphState as immutable input. A genuinely new
    # Graph receives the canonical built-in sample template directly. The
    # browser displays that template; it does not infer its initial Mapping.
    # Make the new
    # Graph's ownership explicit so later nested list updates can never share a
    # mutable reference with the session default template.
    tryCatch(unserialize(serialize(st, NULL, version = 3)), error = function(e) st)
  }

  graph_single_send_client_edit_begin <- function(id, generation, new_graph = FALSE) {
    session$sendCustomMessage(
      "graph-client-edit-begin",
      list(id = as.character(id %||% "")[[1]], generation = as.integer(generation),
        newGraph = isTRUE(new_graph), single = TRUE)
    )
    invisible(TRUE)
  }

  graph_single_adopt_pristine_startup <- function(id, generation, reason = "startup-pristine-adopt") {
    id <- as.character(id %||% "")[[1]]
    meta <- isolate(graph_meta())
    if (!nzchar(id) || !id %in% meta$id) return(invisible(FALSE))
    if (isTRUE(isolate(project_load_locked()))) return(invisible(FALSE))

    mod <- ensure_graph_single_editor_module()
    st <- graph_single_default_state_snapshot(reason)
    if (is.null(mod) || !is.list(st)) return(invisible(FALSE))
    if (is.function(mod$set_activation_generation)) mod$set_activation_generation(generation)

    # Adoption is valid only while the one persistent browser DOM is still the
    # pristine shell that produced `st`.  A canonical state already present for
    # this Graph means another owner (for example Project restore) won the race
    # and must use the ordinary replay path instead.
    if (cache_has(id) || nzchar(graph_single_owner())) return(invisible(FALSE))

    t0 <- proc.time()[["elapsed"]]
    graph_single_activation_started_at(t0)
    graph_single_render_gate(FALSE)
    graph_single_editor_loading(TRUE)
    graph_single_editor_mode("PRISTINE-ADOPT")
    editing_graph_id(id)
    active_graph(id)

    generation <- as.integer(generation)
    if (!editor_activation_current(generation)) return(invisible(FALSE))
    graph_data_document_register_lease(id, generation)

    # Normal replay establishes the browser editing owner before sending any
    # canonical hydration. PRISTINE-ADOPT must do the same: otherwise the
    # graph-state-browser-hydrate handler correctly rejects g001 because
    # ggplotGuiClientEditingGraph is still empty even though generation 1 is
    # current. This is an owner transition, not an ACK/barrier or extra replay.
    graph_single_send_client_edit_begin(id, generation, new_graph = TRUE)

    registry_commit(id, st, source = "graph-single-editor-pristine-adopt")
    canonical <- if (cache_has(id)) cache_get(id) else NULL
    if (!is.list(canonical)) {
      graph_single_abort_activation(id, reason = "pristine-adopt-canonical-missing", generation = generation)
      return(invisible(FALSE))
    }

    attached_ok <- tryCatch(
      is.function(mod$accept_canonical) &&
        isTRUE(mod$accept_canonical(canonical, reason = reason)),
      error = function(e) {
        diag_log("GRAPH-SINGLE-EDITOR", paste0("pristine adopt attach failed: ", conditionMessage(e)), id = id)
        FALSE
      }
    )
    if (!isTRUE(attached_ok)) {
      graph_single_abort_activation(id, reason = "pristine-adopt-attach-failed", generation = generation)
      return(invisible(FALSE))
    }

    # The Ace DOM is already displaying the captured pristine text, but the
    # explicit Data Document transport still needs a Graph/generation lease.
    # Reuse that one transport without hydrating the remaining controls.
    if (is.function(mod$hydrate_data_document)) {
      try(mod$hydrate_data_document(canonical, id, generation), silent = TRUE)
    }
    if (is.function(mod$hydrate_startup_data_context)) {
      ok_context <- tryCatch(
        isTRUE(mod$hydrate_startup_data_context(canonical, id, generation)),
        error = function(e) {
          diag_log("GRAPH-SINGLE-EDITOR", paste0("startup data-context hydrate failed: ", conditionMessage(e)), id = id)
          FALSE
        }
      )
      if (!isTRUE(ok_context)) {
        graph_single_abort_activation(id, reason = "pristine-adopt-data-context-hydrate-failed", generation = generation)
        return(invisible(FALSE))
      }
    }

    finalize_graph_single_default_state(id, canonical, generation, reason = reason)
    graph_single_claim_revision(id, reason = reason)
    diag_log(
      "GRAPH-SINGLE-STARTUP-ADOPT",
      paste0(
        "generation=", generation,
        " replay=DATA-CONTEXT",
        " elapsed_ms=", round((proc.time()[["elapsed"]] - t0) * 1000, 1)
      ),
      id = id
    )
    graph_single_release_live_render(
      id = id, generation = generation, completed_path = "PRISTINE-ADOPT",
      settle_attempts = 0L, mod = mod
    )
    invisible(TRUE)
  }

  ensure_graph_single_editor_module <- function() {
    mod <- graph_single_mod()
    if (!is.null(mod)) return(mod)
    diag_log("GRAPH-SINGLE-EDITOR", "instantiate fixed module")
    mod <- graph_server_runtime(
      graph_single_editor_id,
      style_clipboard = style_clipboard,
      diag_log = function(tag, ..., id = NULL) {
        owner <- graph_single_owner()
        diag_log(paste0("GRAPH-EDIT-", tag), ..., id = if (nzchar(owner)) owner else NULL)
      },
      ui_preseeded = FALSE,
      profile = "full",
      render_gate = graph_single_render_gate,
      activation_is_current = function(generation) editor_activation_current(generation),
      state_capture_deferred = graph_project_capture_deferred,
      persistent_shell = TRUE,
      shared_style_library = shared_style_library,
      browser_patch_override = function() {
        if (exists("graph_browser_patch_override_for_owner", mode = "function", inherits = TRUE)) {
          return(graph_browser_patch_override_for_owner(graph_single_owner()))
        }
        NULL
      },
      on_plot_filter_commit = function(event, generation) {
        if (isTRUE(isolate(graph_single_editor_loading()))) return(invisible(FALSE))
        owner <- as.character(graph_single_owner() %||% "")[1]
        if (!nzchar(owner) || !cache_has(owner) || !graph_single_ready(owner) ||
            !graph_single_revision_is_current(owner)) return(invisible(FALSE))
        mod_now <- graph_single_mod()
        if (is.null(mod_now) || !is.function(mod_now$filter_generation) ||
            !identical(as.integer(generation), as.integer(mod_now$filter_generation()))) return(invisible(FALSE))
        old <- cache_get(owner)
        if (!is.list(old)) return(invisible(FALSE))
        d <- tryCatch(graph_snapshot_reshaped_data(old), error = function(e) NULL)
        if (!is.data.frame(d)) return(invisible(FALSE))
        next_filter <- graph_plot_filter_transition(old$plot_filter, event, d)
        if (identical(next_filter, graph_plot_filter_normalize(old$plot_filter))) return(invisible(TRUE))
        candidate <- old
        candidate$plot_filter <- next_filter
        result <- graph_settings_manager_commit_exact(owner, candidate, source = "plot-filter")
        if (isTRUE(result$changed)) {
          canonical_now <- cache_get(owner)
          if (!is.list(canonical_now)) return(invisible(FALSE))
          if (is.function(mod_now$accept_canonical))
            mod_now$accept_canonical(canonical_now, reason = "plot-filter", seed_render = FALSE)
          if (is.function(mod_now$refresh_browser_pools))
            mod_now$refresh_browser_pools(canonical_now)
          graph_single_claim_revision(owner, reason = "plot-filter")
          graph_single_mark_editor_visit(owner)
          session$sendCustomMessage("graph-browser-patch-rebase", app_json_safe_tree(list(
            graphId = owner, revision = graph_render_state_revision_value(owner),
            activationGeneration = as.integer(isolate(graph_single_editor_generation())))))
          if (isTRUE(result$render) && is.function(mod_now$release_render_state))
            mod_now$release_render_state(canonical_now, reason = "plot-filter")
        }
        invisible(isTRUE(result$changed))
      },
      on_data_document_patch = function(evt) {
        if (!is.list(evt)) return(invisible(FALSE))
        id <- as.character(evt$graphId %||% "")[[1]]
        generation <- suppressWarnings(as.integer(evt$generation %||% 0L))
        seq <- suppressWarnings(as.integer(evt$seq %||% 0L))
        text_now <- as.character(evt$text %||% "")[[1]]
        if (is.na(text_now)) text_now <- ""

        if (!nzchar(id) || !is.finite(generation) || !is.finite(seq) || seq < 1L ||
            !cache_has(id) || !graph_data_document_lease_matches(id, generation)) {
          diag_log(
            "DATA-DOCUMENT-PATCH",
            paste0("rejected owner/lease generation=", generation, " seq=", seq),
            id = if (nzchar(id)) id else NULL
          )
          return(invisible(FALSE))
        }

        seq_key <- paste0(id, "@", generation)
        last_seq <- if (exists(seq_key, envir = graph_data_document_last_seq, inherits = FALSE)) {
          as.integer(get(seq_key, envir = graph_data_document_last_seq, inherits = FALSE))
        } else 0L
        if (seq <= last_seq) {
          diag_log("DATA-DOCUMENT-PATCH", paste0("ignored duplicate/out-of-order seq=", seq, " last_seq=", last_seq), id = id)
          return(invisible(FALSE))
        }

        old <- cache_get(id)
        if (!is.list(old)) return(invisible(FALSE))
        old_doc <- graph_data_document_from_state(old)
        if (identical(text_now, old_doc$source_text)) {
          assign(seq_key, seq, envir = graph_data_document_last_seq)
          return(invisible(TRUE))
        }

        parsed <- tryCatch(graph_parse_pasted_data(text_now), error = function(e) NULL)
        valid <- is.data.frame(parsed) && ncol(parsed) >= 1L &&
          isTRUE(graph_data_column_name_status(parsed)$valid)
        parse_error <- if (isTRUE(valid)) "" else
          "データを読み込めませんでした。列名と区切りを確認してください。"
        source_revision <- as.integer(old_doc$source_revision %||% 0L) + 1L
        data_changed <- isTRUE(valid) && !identical(text_now, graph_state_scalar(old$data_text, ""))

        candidate <- graph_data_document_with_source(
          old, text_now, source_revision,
          parsed = if (isTRUE(valid)) parsed else NULL,
          parse_error = parse_error
        )
        if (isTRUE(data_changed)) {
          candidate$plot_filter <- graph_plot_filter_default()
          candidate <- graph_reconcile_mapping_after_data_change(old, candidate)$state
        }

        result <- graph_settings_manager_commit_exact(id, candidate, source = "data-document")
        assign(seq_key, seq, envir = graph_data_document_last_seq)
        if (!isTRUE(result$changed)) return(invisible(TRUE))

        # Canonical state may be updated after the user has already switched to
        # another Graph. Only the owner named by the payload is changed; dormant
        # Graphs are never materialized in hidden editors.
        current_owner <- as.character(graph_single_owner() %||% "")[[1]]
        if (exists(id, envir = graph_single_editor_visit_cache, inherits = FALSE)) {
          rm(list = id, envir = graph_single_editor_visit_cache)
        }
        if (identical(current_owner, id) &&
            identical(as.integer(isolate(graph_single_editor_generation()) %||% -1L), generation)) {
          # A valid Data schema change can invalidate Mapping/control topology.
          # Advance the existing browser working-copy epoch before publishing the
          # reconciled canonical state, just as other topology-changing browser
          # patches do. This is not a second Data transport path.
          if (isTRUE(data_changed) && exists("graph_browser_patch_epoch", mode = "function", inherits = TRUE)) {
            graph_browser_patch_epoch(as.integer(isolate(graph_browser_patch_epoch()) %||% 0L) + 1L)
          }
          canonical_now <- cache_get(id)
          mod_now <- graph_single_mod()
          if (is.list(canonical_now) && !is.null(mod_now)) {
            if (is.function(mod_now$accept_canonical))
              try(mod_now$accept_canonical(canonical_now, reason = "data-document", seed_render = FALSE), silent = TRUE)
            if (isTRUE(data_changed) && is.function(mod_now$refresh_browser_hydration))
              try(mod_now$refresh_browser_hydration(canonical_now, graph_id = id), silent = TRUE)
            graph_single_claim_revision(id, reason = "data-document")
            graph_single_mark_editor_visit(id)
            session$sendCustomMessage(
              "graph-browser-patch-rebase",
              app_json_safe_tree(list(graphId = id, revision = graph_render_state_revision_value(id),
                activationGeneration = generation))
            )
            if (isTRUE(result$render) && is.function(mod_now$release_render_state))
              mod_now$release_render_state(canonical_now, reason = "data-document")
          }
        }

        diag_log(
          "DATA-DOCUMENT-COMMIT",
          paste0(
            "generation=", generation, " seq=", seq,
            " source_revision=", source_revision,
            " valid=", isTRUE(valid),
            " chars=", nchar(text_now, type = "chars"),
            if (isTRUE(valid)) paste0(" rows=", nrow(parsed), " cols=", ncol(parsed)) else " draft-only=TRUE",
            " render=", isTRUE(result$render)
          ),
          id = id
        )
        invisible(TRUE)
      },
      on_shared_style_library_change = function(library_now) {
        owner <- graph_single_owner()
        if (!nzchar(owner)) return(invisible(FALSE))

        # Graph -> Shared Library write-through is valid only while the
        # persistent Editor still owns the current canonical revision.
        # Library -> Graph application advances/invalidate that revision first;
        # any delayed observer from the stale Editor must therefore be rejected
        # exactly like ordinary stale GraphState publication.
        if (!graph_single_revision_is_current(owner)) {
          lease <- isolate(graph_single_editor_lease())
          diag_log(
            "SHARED-STYLE-LIBRARY-SKIP",
            paste0(
              "source=graph-editor stale-lease lease_revision=",
              as.integer(lease$revision %||% -1L),
              " canonical_revision=",
              as.integer(graph_state_revision_value(owner) %||% 0L)
            ),
            id = owner
          )
          return(invisible(FALSE))
        }

        shared_style_commit_library(library_now, source = "graph-editor", skip_graph_id = owner)
      },
      on_state_change = function(state_now) {
        if (isTRUE(isolate(graph_single_editor_loading()))) return(invisible(NULL))
        owner <- graph_single_owner()
        if (!nzchar(owner) || !is.list(state_now)) return(invisible(NULL))

        canonical_before <- if (cache_has(owner)) cache_get(owner) else NULL
        # ui_snapshot.panels has a revisioned browser patch owner.
        # Ordinary live GraphState publication must carry the canonical panel
        # record, never a transient transport container from the module state.
        state_now <- graph_state_with_ui_snapshot(
          state_now,
          list(panels = graph_ui_panels_for_id(owner, canonical_before))
        )
        diff_paths <- app_state_diff_paths(canonical_before, state_now)
        if (length(diff_paths)) {
          diag_log(
            "GRAPH-SINGLE-STATE-DIFF",
            paste0("source=live paths=", app_state_diff_summary(canonical_before, state_now)),
            id = owner
          )
        }
        graph_single_publish_state(owner, state_now, source = "graph-single-editor")
      }
    )
    graph_single_editor_module(mod)
    # The caller captures the reusable default as soon as this API returns.
    # graph_sample_graph_state() deterministically supplies data-dependent
    # Data / reshape / Mapping values; Style / Label remain module-owned.
    mod
  }

  graph_single_commit <- function(reason = "switch") {
    owner <- graph_single_owner()
    mod <- graph_single_mod()
    if (!nzchar(owner) || is.null(mod) || isTRUE(isolate(graph_single_editor_loading()))) return(invisible(FALSE))
    if (is.function(mod$flush_display_label_inputs)) {
      mod$flush_display_label_inputs()
    }
    st <- tryCatch(if (is.function(mod$state)) isolate(mod$state()) else NULL, error = function(e) NULL)
    if (!is.list(st)) return(invisible(FALSE))
    changed <- graph_single_publish_state(owner, st, source = paste0("graph-single-editor-", reason))
    diag_log("GRAPH-SINGLE-EDITOR", paste0("commit previous=", owner, " changed=", isTRUE(changed)), id = owner)
    invisible(TRUE)
  }

  show_graph_single_editor <- function(id, generation = isolate(graph_single_editor_generation())) {
    if (!editor_activation_current(generation, id)) return(invisible(FALSE))
    canonical <- if (cache_has(id)) cache_get(id) else NULL
    patch_seed <- if (exists("graph_browser_patch_client_state", mode = "function", inherits = TRUE)) {
      tryCatch(graph_browser_patch_client_state(id), error = function(e) NULL)
    } else NULL
    session$sendCustomMessage(
      "graph-client-edit-ready",
      app_json_safe_tree(list(
        id = id,
        generation = as.integer(generation),
        single = TRUE,
        uiPanels = graph_ui_panels_for_id(id, canonical),
        browserPatch = patch_seed
      ))
    )
    session$onFlushed(function() {
      if (!editor_activation_current(generation, id)) return(invisible(NULL))
      session$sendCustomMessage("refresh-visible-graph-ui", list(id = graph_single_editor_id))
    }, once = TRUE)
    invisible(TRUE)
  }

  graph_single_release_live_render <- function(id, generation, completed_path, settle_attempts, mod) {
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation %||% -1L)
    if (!editor_activation_current(generation, id)) {
      diag_log("EDITOR-ACTIVATION-STALE-DROP", paste0("generation=", generation,
        " phase=release"), id = id)
      return(invisible(FALSE))
    }
    # Project displaying phase retains the existing post-flush render boundary.
    project_ready <- isTRUE(isolate(project_load_locked())) && identical(id, isolate(active_graph()))
    if (project_ready) graph_project_capture_owner(list(id = id, generation = generation))
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("READY")
    graph_single_mark_editor_visit(id, generation = generation)
    show_graph_single_editor(id, generation)
    if (isTRUE(project_ready)) {
      # Finish server restore and publish the displaying phase. The next flush
      # opens rendering while the browser remains inert until the new plot image
      # loads. Overlay visibility no longer owns the render gate.
      complete_project_load_lock("selected Graph READY in persistent Editor")
      session$onFlushed(function() {
        if (editor_activation_current(generation, id) &&
            !isTRUE(isolate(graph_single_editor_loading()))) {
          graph_single_render_gate(TRUE)
          diag_log("PROJECT-PROGRESS", "display-phase render-gate OPEN", id = id)
        }
      }, once = TRUE)
    } else {
      graph_single_render_gate(TRUE)
    }
    diag_log(
      "EDITOR-ACTIVATION-READY",
      paste0("READY live-only generation=", generation, " path=", completed_path,
             " render-gate=", if (isTRUE(project_ready)) "DEFERRED-AFTER-DISPLAY-PHASE" else
               "OPEN",
             " browser-image-ack=NONE"),
      id = id
    )
    started_at <- suppressWarnings(as.numeric(isolate(graph_single_activation_started_at()) %||% NA_real_))
    if (is.finite(started_at)) {
      diag_log(
        "GRAPH-SINGLE-REPLAY-TIMING",
        paste0("phase=ready elapsed_ms=", round((proc.time()[["elapsed"]] - started_at) * 1000, 1)),
        id = id
      )
    }
    invisible(TRUE)
  }

  # normal Graph switches no longer test structural
  # compatibility. Every canonical state with a UI snapshot uses state replay.

  graph_single_load <- function(id, new_graph = FALSE, generation, full_replay = FALSE) {
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation)
    if (!editor_activation_current(generation)) return(invisible(FALSE))
    meta <- isolate(graph_meta())
    if (!nzchar(id) || !id %in% meta$id) return(invisible(FALSE))

    old_id <- graph_single_owner()
    mod <- ensure_graph_single_editor_module()
    if (is.function(mod$set_activation_generation)) mod$set_activation_generation(generation)

    visit <- graph_single_editor_visit_cache[[id]]
    target_state_revision <- as.integer(graph_state_revision_value(id) %||% 0L)
    visit_fresh <- is.list(visit) && identical(
      as.integer(visit$state_revision %||% -1L), target_state_revision
    )
    diag_log(
      "GRAPH-SINGLE-EDITOR-VISIT",
      paste0(
        "revisit=", is.list(visit),
        " fresh=", isTRUE(visit_fresh),
        " target_revision=", target_state_revision,
        if (is.list(visit)) paste0(" cached_revision=", as.integer(visit$state_revision %||% -1L)) else ""
      ),
      id = id
    )

    if (identical(old_id, id) && graph_single_ready(id) && !isTRUE(isolate(graph_single_editor_loading()))) {
      diag_log("GRAPH-SINGLE-EDITOR", "reuse-hit", id = id)
      active_graph(id)
      show_graph_single_editor(id, generation)
      if (isTRUE(isolate(project_load_locked())) && identical(id, isolate(active_graph()))) {
        complete_project_load_lock("selected Graph already READY in persistent Editor")
      }
      return(invisible(TRUE))
    }

    # Browser patch/Data leases are flushed before selection. Ordinary native
    # edits commit at their own immediate boundary, never from switch readback.
    target_state_early <- if (cache_has(id)) cache_get(id) else NULL
    if (nzchar(old_id) && !identical(old_id, id)) {
      diag_log("GRAPH-SINGLE-EDITOR",
        paste0("commit previous=", old_id, " changed=FALSE canonical_current=",
               graph_single_revision_is_current(old_id)), id = old_id)
    }

    editing_graph_id(id)
    active_graph(id)
    # Close before any update* / reshape / Mapping synchronization can invalidate
    # plot reactives. The gate reopens only after READY + canonical acceptance.
    graph_single_render_gate(FALSE)
    graph_single_editor_loading(TRUE)
    graph_single_editor_mode("REPLAY")
    diag_log("GRAPH-SINGLE-EDITOR", "render-gate CLOSED for Graph switch transaction", id = id)

    gen <- generation
    graph_single_activation_started_at(proc.time()[["elapsed"]])
    graph_single_cold_diag$active <- isTRUE(isolate(project_load_locked())) && identical(id, isolate(active_graph()))
    graph_single_cold_diag$id <- id
    graph_single_cold_diag$generation <- gen
    graph_single_cold_diag$started_at <- proc.time()[["elapsed"]]
    graph_single_cold_diag$last_at <- graph_single_cold_diag$started_at
    graph_single_cold_diag_mark("activation-start")
    graph_data_document_register_lease(id, gen)
    graph_single_send_client_edit_begin(id, gen, new_graph = isTRUE(new_graph))
    diag_log("GRAPH-SINGLE-EDITOR", paste0("load-request previous=", if (nzchar(old_id)) old_id else "<none>", " mode=REPLAY"), id = id)

    # Every normal activation is canonical-state first. Startup adoption owns
    # the one pristine browser shell, create_graph() seeds new Graphs before
    # selection, and Project restore stages all GraphStates before activation.
    # A missing canonical state is therefore an error, not a reason to infer or
    # seed state from the current browser DOM.
    st <- target_state_early
    if (!is.list(st)) {
      graph_single_abort_activation(
        id,
        reason = "canonical-state-missing",
        message = "GraphStateが見つからないためEditorへ反映できませんでした。",
        type = "error", generation = gen
      )
      return(invisible(FALSE))
    }

    replay_started <- FALSE
    if (is.function(mod$replay_state)) {
      graph_single_editor_mode("REPLAY")
      replay_started <- isTRUE(mod$replay_state(st, transaction = list(
        id = id, generation = gen, new_graph = isTRUE(new_graph), revisit_fresh = isTRUE(visit_fresh),
        full_replay = isTRUE(full_replay) || isTRUE(isolate(project_load_locked())),
        cold_replay_diag = isTRUE(isolate(project_load_locked())),
        on_complete = function(completed_generation) {
          graph_single_complete_replay(id, mod, gen, completed_generation)
        }
      )))
    }

    if (isTRUE(replay_started)) {
      diag_log(
        "GRAPH-STATE-REPLAY",
        paste0("begin old=", if (nzchar(old_id)) old_id else "<none>",
               " new=", id, " generation=", gen,
               " revisit_fresh=", isTRUE(visit_fresh)),
        id = id
      )
    } else {
      # After the one persistent Editor has been created, Graph ownership is
      # value-only. Do not rebuild/hydrate the DOM for Project load or legacy
      # state; a failed replay is an activation error, not a restore request.
      graph_single_abort_activation(id, reason = "replay-unavailable", generation = gen)
      return(invisible(FALSE))
    }
    invisible(TRUE)
  }

  # The replay transport owns completion as well as dispatch. Direct completion
  # removes the second reactive/flush turn between release and lease claim;
  # there is deliberately no observer, timeout, or reconciliation fallback.
  graph_single_complete_replay <- function(id, mod, gen, completed_generation) {
    if (!editor_activation_current(gen, id)) {
      diag_log("EDITOR-ACTIVATION-STALE-DROP", paste0("generation=", gen,
        " phase=transport-complete"), id = id)
      return(invisible(FALSE))
    }
    if (!isTRUE(isolate(graph_single_editor_loading()))) return(invisible(FALSE))
    graph_single_cold_diag_mark(
      "transport-complete-enter",
      paste0("completed_generation=", completed_generation)
    )
    ready_now <- graph_single_cold_diag_measure("load_ready_value-read", function() {
      # Project restore now starts from an onFlushed callback so its phase can
      # reach the browser before synchronous registry work. That callback has
      # no reactive consumer; evaluate the module's reactive READY value in an
      # isolated context rather than treating a missing context as not ready.
      isTRUE(tryCatch(isolate(mod$ready()), error = function(e) FALSE))
    })
    if (!isTRUE(ready_now)) {
      graph_single_abort_activation(id, reason = "state-replay-transport-not-ready", generation = gen)
      return(invisible(FALSE))
    }
    graph_single_cold_diag_mark("load_ready_value-true")

    completed_path <- as.character(isolate(graph_single_editor_mode()) %||% "REPLAY")[1]
    acceptance <- graph_single_accept_loaded_state(id, mod, NULL, gen)
    if (identical(acceptance, "failed")) {
      graph_single_abort_activation(id, reason = "canonical-state-missing", generation = gen)
      return(invisible(FALSE))
    }

    accepted_state <- if (cache_has(id)) cache_get(id) else NULL
    attached_ok <- graph_single_cold_diag_measure("canonical-attach", function() tryCatch(
      is.list(accepted_state) && is.function(mod$accept_canonical) &&
        isTRUE(mod$accept_canonical(accepted_state, reason = "outer-ready-accept")),
      error = function(e) {
        diag_log("GRAPH-SINGLE-EDITOR", paste0("accepted canonical attach failed: ", conditionMessage(e)), id = id)
        FALSE
      }
    ))
    if (!isTRUE(attached_ok)) {
      graph_single_abort_activation(id, reason = "accepted-canonical-attach-failed", generation = gen)
      return(invisible(FALSE))
    }

    graph_single_release_live_render(
      id = id,
      generation = as.integer(gen),
      completed_path = completed_path,
      settle_attempts = 0L,
      mod = mod
    )
    graph_single_cold_diag_mark("transport-complete-exit")
    invisible(TRUE)
  }


  # normal Graph renders are live-only. Do not generate or
  # publish a Graph SVG after every successful render. Figure/Inset/Project
  # compatibility paths materialize vector snapshots explicitly when requested.

  # ------------------------------------------------------------------
  # F1-5p Figure-owned editable Graph snapshots
  # ------------------------------------------------------------------
