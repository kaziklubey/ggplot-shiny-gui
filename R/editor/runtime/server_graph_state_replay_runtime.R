  # normal Graph state replay for the one persistent Editor.
  # Sourced inside graphServer after data/style/statistics runtimes are installed.
  # This runtime is the only GraphState-to-Editor hydration path. It uses one
  # browser-direct value batch and server flush—no staged restore, semantic
  # comparison, retry, or per-Graph DOM/module instances.

  graph_capture_editor_ui_snapshot <- function() {
    if (!graph_editor_profile_has(editor_profile, "full_shell")) {
      base <- isolate(attached_state_seed())
      return(graph_ui_snapshot_normalize(if (is.list(base)) base$ui_snapshot else NULL))
    }
    graph_ui_snapshot_normalize(list(
      schema_version = 2L,
      selections = list(
        sticky_plot = isTRUE(input$sticky_plot)
      ),
      panels = graph_ui_snapshot_normalize(isolate(attached_state_seed())$ui_snapshot)$panels
    ))
  }

  graph_replay_apply_statistics <- function(cfg) {
    if (!graph_editor_profile_has(editor_profile, "statistics")) return(invisible(TRUE))
    restored <- cfg$statistics_recipes
    if (!is.list(restored)) restored <- list()

    # Statistics exists only in the Full Editor profile. Figure Controls keep
    # the source GraphState recipes untouched through profile state overlay.
    stats_replace_graph_context(
      restored = restored,
      preferred_id = cfg$statistics_selected_id %||% NULL
    )
    invisible(TRUE)
  }

  # Data text uses one explicit Graph-owned document transport rather than
  # shinyAce's implicit input$text ownership. Every hydrate carries the target
  # Graph id and outer Editor lease generation; browser edits echo those exact
  # identifiers back with a monotonically increasing sequence number.
  graph_replay_hydrate_data_document <- function(cfg, transaction, replay_generation) {
    if (!graph_editor_profile_has(editor_profile, "full_shell")) return(invisible(FALSE))
    tx <- transaction %||% list()
    graph_id <- as.character(tx$id %||% "")[[1]]
    lease_generation <- suppressWarnings(as.integer(tx$generation %||% replay_generation %||% 0L))
    if (!nzchar(graph_id) || !is.finite(lease_generation)) return(invisible(FALSE))

    text_value <- graph_data_document_source_text(cfg)
    doc <- graph_data_document_from_state(cfg)
    session$sendCustomMessage(
      "graph-data-document-hydrate",
      app_json_safe_tree(list(
        graphId = graph_id,
        generation = lease_generation,
        activationGeneration = lease_generation,
        replayGeneration = as.integer(replay_generation %||% 0L),
        inputId = session$ns("text"),
        patchInputId = session$ns("data_document_patch"),
        text = text_value,
        sourceRevision = as.integer(doc$source_revision %||% 0L),
        parseStatus = as.character(doc$parse_status %||% "valid")[[1]]
      ))
    )
    diag(
      "DATA-DOCUMENT-HYDRATE",
      paste0(
        "queued graph=", graph_id,
        " lease_generation=", lease_generation,
        " replay_generation=", as.integer(replay_generation %||% 0L),
        " source_revision=", as.integer(doc$source_revision %||% 0L),
        " chars=", nchar(text_value, type = "chars")
      )
    )
    invisible(TRUE)
  }

  sys.source(file.path(getwd(), "R/editor/runtime/graph_browser_direct_payload_runtime.R"), envir = environment())


  graph_browser_direct_publish_pools <- function(cfg, mapping_plan = NULL, pools = graph_slot_pool_names()) {
    if (!is.list(cfg) || !graph_editor_profile_has(editor_profile, "full_shell")) return(invisible(FALSE))
    plan <- mapping_plan
    if (!is.list(plan)) plan <- tryCatch(graph_replay_mapping_plan(cfg), error = function(e) NULL)
    d <- if (is.list(plan) && is.data.frame(plan$data)) plan$data else NULL
    if (!is.data.frame(d)) return(invisible(FALSE))
    # Use the validity-checked effective mappings shown by browser hydration.
    display_cfg <- cfg
    for (key in c("x", "color", "linetype", "shape", "position")) display_cfg$mapping[[key]] <- plan[[key]]
    for (pool in pools) graph_slot_pool_publish_spec(pool, display_cfg, d)
    invisible(TRUE)
  }

  graph_replay_finish <- function(generation, token) {
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!identical(as.integer(generation), pending_generation)) return(invisible(FALSE))
    cfg <- isolate(graph_state_replay_target())
    if (!is.list(cfg)) return(invisible(FALSE))

    # Release after the canonical hydration messages have crossed the server
    # flush. Data Document owns Ace; no native input ACK is read back.
    attached_state_seed(cfg)
    graph_state_replay_completed_generation(as.integer(generation))
    graph_state_replay_active(FALSE)
    graph_state_replay_target(NULL)
    graph_state_replay_error(NULL)
    restoring_style_state(FALSE)
    diag("STATE-REPLAY", paste0("READY generation=", generation, " token=", token, " mode=mapping-transaction"))
    graph_cold_diag_end("replay-finish")
    invisible(TRUE)
  }

  graph_apply_state_replay <- function(cfg, transaction = NULL) {
    if (!is.list(cfg)) return(invisible(FALSE))
    if (graph_editor_profile_has(editor_profile, "full_shell")) {
      graph_editor_activation_generation(as.integer((transaction %||% list())$generation %||% 0L))
    }
    replay_t0 <- proc.time()[["elapsed"]]
    replay_timing <- function(phase, extra = "") {
      diag(
        "STATE-REPLAY-TIMING",
        paste0(
          "phase=", phase,
          " elapsed_ms=", round((proc.time()[["elapsed"]] - replay_t0) * 1000, 1),
          if (nzchar(extra)) paste0(" ", extra) else ""
        )
      )
      invisible(TRUE)
    }
    snapshot <- graph_ui_snapshot_normalize(cfg$ui_snapshot)

    transaction_new_graph <- isTRUE((transaction %||% list())$new_graph)
    transaction_full_replay <- isTRUE((transaction %||% list())$full_replay)
    # A genuinely new Graph owns a pristine canonical template. The persistent
    # Editor DOM may still display the previous Graph, so delta replay against
    # attached_state_seed() is the wrong optimization boundary here: any stale
    # browser control omitted from the delta can visually inherit the old Graph.
    # New Graph creation therefore performs one full canonical hydration.
    # Ordinary Graph switches and Duplicate keep the delta replay path.
    previous_state <- if (isTRUE(transaction_new_graph) || isTRUE(transaction_full_replay)) NULL else isolate(attached_state_seed())
    plan_t0 <- proc.time()[["elapsed"]]
    replay_plan <- graph_editor_replay_plan(previous_state, cfg, editor_profile)
    if (!is.list(replay_plan)) return(invisible(FALSE))
    if (isTRUE(getOption("ggplot.gui.style_pool_diag", FALSE))) {
      replay_timing("replay-plan", paste0("work_ms=", round((proc.time()[["elapsed"]] - plan_t0) * 1000, 1)))
    }

    generation <- as.integer(isolate(graph_state_replay_generation()) %||% 0L) + 1L
    graph_state_replay_generation(generation)
    graph_state_replay_error(NULL)
    graph_state_replay_target(cfg)
    graph_cold_diag_begin(generation, enabled = isTRUE((transaction %||% list())$cold_replay_diag))
    # Keep one target-derived mapping/data plan available during replay. When
    # Data/reshape/Mapping/Plot semantics are unchanged, the plan already held
    # by the persistent Editor is semantically identical and can be reused.
    # This avoids reparsing the same Data Document and rerunning reshape/filter
    # merely because labels/style/UI differ between Graphs.
    mapping_plan_needed <- isTRUE(replay_plan$full) || isTRUE(replay_plan$data_changed) ||
      isTRUE(replay_plan$reshape_changed) || isTRUE(replay_plan$filter_changed) || isTRUE(replay_plan$mapping_changed) ||
      isTRUE(replay_plan$plot_changed) || !is.list(isolate(graph_mapping_replay_plan()))
    if (isTRUE(mapping_plan_needed)) {
      mapping_t0 <- proc.time()[["elapsed"]]
      graph_mapping_replay_plan(graph_replay_mapping_plan(cfg))
      replay_timing("mapping-plan", paste0("mode=rebuild work_ms=", round((proc.time()[["elapsed"]] - mapping_t0) * 1000, 1)))
    } else {
      replay_timing("mapping-plan", "mode=reuse")
    }
    graph_state_replay_active(TRUE)
    restoring_style_state(TRUE)
    graph_seed_render_target(cfg, reason = "state-replay")
    replay_timing("prepare-target")

    diag(
      "STATE-REPLAY",
      paste0(
        "BEGIN generation=", generation,
        " profile=", editor_profile$name,
        " sections={", paste(replay_plan$sections, collapse=","), "}"
      )
    )

    apply_ok <- tryCatch({
      if (isTRUE(replay_plan$mapping_transport) || isTRUE(replay_plan$plot_changed) || isTRUE(replay_plan$full)) {
        line_break_restore_from_cfg(
          cfg, isolate(graph_mapping_replay_plan())
        )
      }
      if (isTRUE(replay_plan$statistics_changed)) {
        graph_replay_apply_statistics(cfg)
        replay_timing("statistics-canonical", "ui=dormant")
      }
      if (isTRUE(replay_plan$style_changed) && is.list(cfg$style)) {
        style_t0 <- proc.time()[["elapsed"]]
        apply_style_config(
          cfg$style, success_message = NULL, release_guard = FALSE, notify = FALSE,
          hydrate_bound_controls = FALSE, canonical_style = TRUE,
          changed_branches = replay_plan$style_branches
        )
        replay_timing("style-canonical", paste0("work_ms=", round((proc.time()[["elapsed"]] - style_t0) * 1000, 1)))
      }
      # Pool hydration shares the same target-derived transformed/filtered data
      # plan as Mapping and the Plot pipeline. Preserve the existing persistent
      # pool DOM when neither its topology nor its per-level values changed.
      # Unrelated Style changes (font/axes/legend layout etc.) must not force a
      # five-pool rebuild.
      if (isTRUE(replay_plan$pool_transport)) {
        pool_t0 <- proc.time()[["elapsed"]]
        graph_browser_direct_publish_pools(cfg, isolate(graph_mapping_replay_plan()), replay_plan$pool_names)
        replay_timing("slot-pools", paste0("work_ms=", round((proc.time()[["elapsed"]] - pool_t0) * 1000, 1)))
      } else {
        replay_timing("slot-pools", "skipped=unchanged")
      }
      if (isTRUE(getOption("ggplot.gui.style_pool_diag", FALSE))) {
        for (pool in setdiff(graph_slot_pool_names(), replay_plan$pool_names)) {
          diag("STATE-REPLAY-TIMING", paste0("phase=slot-pool name=", pool,
            " action=skip work_ms=0 reason=dependencies-unchanged"))
        }
      }
      replay_timing("server-prepare-complete")
      graph_cold_diag_boundary("server-prepare-complete")
      TRUE
    }, error = function(e) {
      graph_state_replay_error(conditionMessage(e))
      diag("STATE-REPLAY", paste0("APPLY-ERROR generation=", generation, " error=", conditionMessage(e)))
      FALSE
    })
    if (!isTRUE(apply_ok)) {
      graph_state_replay_active(FALSE)
      graph_state_replay_target(NULL)
      graph_state_replay_error(NULL)
      restoring_style_state(FALSE)
      graph_cold_diag_end("apply-error")
      return(invisible(FALSE))
    }

    token <- paste0("replay:", generation, ":", as.character((transaction %||% list())$id %||% "graph"))
    # The Full Editor is one persistent DOM. Apply its target-derived values
    # and choices locally in the browser and release the canonical render on
    # the same server flush. There is no per-input transport, binding scan,
    # ACK or READY retry. Figure Controls use the same transport in RC12, but
    # retain their separate Figure-owned base state and lifecycle gate.
    payload <- graph_browser_direct_hydration_payload(cfg, replay_plan, transaction)
    if (graph_editor_profile_is_figure(editor_profile)) {
      # Browser hydration may intentionally show only the subset of saved
      # line-break boundaries representable by the current choice universe.
      # Figure-owned canonical state must still retain the exact saved value;
      # otherwise the UI-only subset is overlaid back as a fake user edit just
      # after replay (RC13.1: live-edit-coalesced plot.line_breaks).
      figure_profile_values <- payload$values
      figure_profile_values$line_breaks <- as.character(unlist(
        (cfg$plot %||% list())$line_breaks %||% character(0),
        use.names = FALSE
      ))
      profile_browser_values(figure_profile_values)
      profile_browser_paths(as.list(graph_browser_input_paths(cfg)))
    }
    # Custom messages are serialized in call order at the end of this flush.
    # Waiting for onFlushed created an otherwise empty server/browser turn.
    if (isTRUE(isolate(graph_state_replay_active())) &&
        identical(as.integer(isolate(graph_state_replay_generation()) %||% -1L), generation)) {
      if (isTRUE(replay_plan$full) || isTRUE(replay_plan$data_changed)) {
      graph_replay_hydrate_data_document(cfg, transaction, generation)
      replay_timing("data-document-hydrate")
      }
      session$sendCustomMessage("graph-state-browser-hydrate", app_json_safe_tree(payload))
      replay_timing("browser-direct-send", paste0("mode=", payload$replayMode, " browser_ack=NONE"))
      diag(
        "STATE-REPLAY",
        paste0(
          "apply mode=browser-direct generation=", generation,
          " replay_mode=", payload$replayMode,
          " scalar_count=", length(payload$values),
          " choice_sets=", length(payload$choices),
          " browser_barrier=NONE",
          if (graph_editor_profile_is_figure(editor_profile)) " figure_owner=preserved" else ""
        )
      )
      finished <- isTRUE(graph_replay_finish(generation, token))
      replay_timing("replay-release")
      completion <- (transaction %||% list())$on_complete
      if (isTRUE(finished) && is.function(completion)) completion(generation)
    }
    invisible(TRUE)
  }
