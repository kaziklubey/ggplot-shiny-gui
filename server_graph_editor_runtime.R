  # ------------------------------------------------------------------
  # v3.61.0 Graph single editor
  # ------------------------------------------------------------------
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
    store <- isolate(graph_editor_ui_panel_store())
    if (nzchar(id) && is.list(store[[id]])) return(store[[id]])
    if (!is.list(state) && nzchar(id) && cache_has(id)) state <- cache_get(id)
    snap <- if (is.list(state)) graph_ui_snapshot_normalize(state$ui_snapshot) else graph_ui_snapshot_normalize(NULL)
    snap$panels %||% list()
  }

  graph_store_ui_panels <- function(id, panels) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(panels)) return(invisible(FALSE))
    clean <- graph_ui_snapshot_normalize(list(panels = panels))$panels
    store <- isolate(graph_editor_ui_panel_store())
    store[[id]] <- clean
    graph_editor_ui_panel_store(store)
    invisible(TRUE)
  }

  observeEvent(input$graph_editor_ui_state, {
    msg <- input$graph_editor_ui_state
    if (!is.list(msg)) return()
    id <- as.character(msg$id %||% "")[1]
    panels <- msg$panels
    if (!nzchar(id) || !is.list(panels)) return()
    graph_store_ui_panels(id, panels)
    if (!cache_has(id)) return()
    st <- cache_get(id)
    st <- graph_state_with_ui_snapshot(st, list(panels = panels))
    changed <- registry_commit(id, st, source = paste0("graph-ui-panels:", as.character(msg$source %||% "browser")[1]))
    if (identical(id, graph_single_owner())) graph_single_claim_revision(id, reason = "ui-panels")
    diag_log("GRAPH-UI-SNAPSHOT", paste0("panels stored changed=", isTRUE(changed)), id = id)
  }, ignoreInit = TRUE, priority = 120)

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
    graph_single_claim_revision(id, reason = paste0("publish:", source))
    graph_single_mark_editor_visit(id)
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
    canonical <- if (cache_has(id)) cache_get(id) else NULL
    if (!is.list(canonical)) {
      diag_log("GRAPH-SINGLE-EDITOR", "canonical GraphState missing at replay completion", id = id)
      return("failed")
    }

    # Normal Graph loading is value replay only. Do not read the browser back
    # and compare it with canonical state: invalid/legacy parameter combinations
    # are allowed to exist and the ordinary Plot error surface owns draw errors.
    # UI-only panel state is captured separately and never blocks activation.

    canonical_ready <- graph_state_with_ui_snapshot(
      canonical,
      list(panels = graph_ui_panels_for_id(id, canonical))
    )
    if (!identical(canonical_ready, canonical)) {
      registry_commit(id, canonical_ready, source = "graph-ui-panels-replay")
      canonical <- canonical_ready
    }

    finalize_graph_single_default_state(id, canonical, generation, reason = "startup-ready-value-replay")
    graph_single_claim_revision(id, reason = "load-ready-value-replay")
    "accepted"
  }

  graph_single_abort_activation <- function(id, reason = "activation-failed") {
    id <- as.character(id %||% "")[1]
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("IDLE")
    graph_single_editor_lease(NULL)
    graph_single_live_render_wait(NULL)
    graph_single_render_gate(TRUE)
    editing_graph_id("")
    session$sendCustomMessage(
      "graph-editor-shell-clear",
      list(selected = id, reason = as.character(reason %||% "activation-abort")[1])
    )
    if (nzchar(id)) {
      # Failure-safe only: ordinary workflow has no browse/edit mode. Keep the
      # selected Graph metadata current, clear the stale shell, and require an
      # explicit reselection rather than exposing an older cached SVG.
      active_graph(id)
      publish_client_preview_catalog(
        reason = "editor-activation-abort", selected = id, enter_browse = FALSE
      )
    }
    diag_log(
      "GRAPH-SINGLE-EDITOR",
      paste0("activation aborted; render-gate reopened reason=", as.character(reason %||% "activation-abort")[1]),
      id = if (nzchar(id)) id else NULL
    )
    showNotification(
      "Graph設定の反映を完了できなかったため、Editor表示をクリアしました。Graphタブを選び直してください。",
      type = "warning"
    )
    invisible(FALSE)
  }

  capture_graph_single_default_state <- function(reason = "unspecified") {
    existing <- isolate(graph_single_default_state())
    if (is.list(existing)) return(invisible(TRUE))
    mod <- graph_single_mod()
    if (is.null(mod) || !is.function(mod$state)) return(invisible(FALSE))
    st <- tryCatch(isolate(mod$state()), error = function(e) NULL)
    if (!is.list(st) || !is.list(st$plot) || !is.list(st$style)) return(invisible(FALSE))
    st <- graph_sample_graph_state(st)
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

  seed_new_graph_default_state <- function(id, reason = "graph-created-default") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))
    st <- graph_single_default_state_snapshot(reason)
    if (!is.list(st)) {
      diag_log("GRAPH-SINGLE-DEFAULT", "default GraphState unavailable; seed skipped", id = id)
      return(invisible(FALSE))
    }
    registry_commit(id, st, source = reason)
    diag_log(
      "GRAPH-SINGLE-DEFAULT",
      paste0(
        "seeded canonical sample before editor attach plot_type=",
        as.character(st$plot$type %||% "<NULL>"),
        " mapping=", as.character((st$mapping %||% list())$x %||% "<NULL>"),
        "/", as.character((st$mapping %||% list())$y %||% "<NULL>")
      ),
      id = id
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
      controls_only = FALSE,
      render_gate = graph_single_render_gate,
      persistent_shell = TRUE,
      shared_style_library = shared_style_library,
      statistics_plot_preview = function() {
        # Read-only Statistics Plot: create a temporary vector snapshot from
        # the one persistent Editor. It is intentionally NOT published into a
        # Graph preview cache; GraphState remains the only Graph authority.
        meta <- graph_meta()
        selected <- as.character(input$graph_client_selected %||% "")[1]
        if (!nzchar(selected) || !selected %in% meta$id) {
          selected <- as.character(active_graph() %||% "")[1]
        }
        if (!nzchar(selected) || !selected %in% meta$id) return(NULL)

        nm <- meta$name[match(selected, meta$id)]
        if (!length(nm) || is.na(nm)) nm <- selected
        mod_now <- graph_single_mod()
        owner_now <- graph_single_owner()
        if (is.null(mod_now) || !identical(selected, owner_now) ||
            !isTRUE(tryCatch(isolate(mod_now$ready()), error = function(e) FALSE))) {
          return(list(id = selected, name = as.character(nm), svg = "", width = 600, height = 600))
        }

        comp <- tryCatch(
          if (is.function(mod_now$figure_components)) isolate(mod_now$figure_components()) else NULL,
          error = function(e) NULL
        )
        p_now <- comp$plot %||% tryCatch(
          if (is.function(mod_now$figure_plot)) isolate(mod_now$figure_plot()) else isolate(mod_now$plot()),
          error = function(e) NULL
        )
        ex_now <- comp$meta %||% tryCatch(
          if (is.function(mod_now$figure_meta)) isolate(mod_now$figure_meta()) else isolate(mod_now$export()),
          error = function(e) NULL
        )
        state_now <- if (cache_has(selected)) cache_get(selected) else NULL
        rec <- tryCatch(
          graph_preview_record_from_plot(
            id = selected,
            state = state_now,
            plot = p_now,
            export_meta = ex_now,
            render_revision = if (is.function(mod_now$render_revision)) isolate(mod_now$render_revision()) else NA_integer_,
            reason = "statistics-temporary"
          ),
          error = function(e) NULL
        )
        if (!is.list(rec) || !nzchar(rec$svg %||% "")) {
          return(list(id = selected, name = as.character(nm), svg = "", width = 600, height = 600))
        }
        vm <- rec$meta %||% list()
        w <- suppressWarnings(as.numeric(vm$width %||% vm$plot_width_px %||% 600))
        h <- suppressWarnings(as.numeric(vm$height %||% vm$plot_height_px %||% 600))
        if (!is.finite(w) || w <= 0) w <- 600
        if (!is.finite(h) || h <= 0) h <- 600
        list(
          id = selected,
          name = as.character(nm),
          svg = graph_svg_viewport_text(rec$svg %||% ""),
          width = w,
          height = h
        )
      },
      on_shared_style_library_change = function(library_now) {
        owner <- graph_single_owner()
        if (!nzchar(owner)) return(invisible(FALSE))
        shared_style_commit_library(library_now, source = "graph-editor", skip_graph_id = owner)
      },
      on_state_change = function(state_now) {
        if (isTRUE(isolate(graph_single_editor_loading()))) return(invisible(NULL))
        owner <- graph_single_owner()
        if (!nzchar(owner) || !is.list(state_now)) return(invisible(NULL))

        canonical_before <- if (cache_has(owner)) cache_get(owner) else NULL
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
    # Do not capture the reusable new-Graph default here.  At moduleServer return
    # the persistent controls exist on the server, but their data-dependent
    # Mapping defaults (X/Y/ID etc.) have not completed the first Shiny flush.
    # server_graph_workspace_runtime.R performs the one authoritative capture
    # on startup-post-bind.  Capturing here used to make that later capture a
    # no-op because capture_graph_single_default_state() is intentionally
    # write-once.
    mod
  }

  graph_single_commit <- function(reason = "switch") {
    owner <- graph_single_owner()
    mod <- graph_single_mod()
    if (!nzchar(owner) || is.null(mod) || isTRUE(isolate(graph_single_editor_loading()))) return(invisible(FALSE))
    st <- tryCatch(if (is.function(mod$state)) isolate(mod$state()) else NULL, error = function(e) NULL)
    if (!is.list(st)) return(invisible(FALSE))
    changed <- graph_single_publish_state(owner, st, source = paste0("graph-single-editor-", reason))
    diag_log("GRAPH-SINGLE-EDITOR", paste0("commit previous=", owner, " changed=", isTRUE(changed)), id = owner)
    invisible(TRUE)
  }

  graph_single_begin_live_target <- function(id, generation) {
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation %||% -1L)
    if (!nzchar(id) || generation < 0L) return(invisible(FALSE))
    session$sendCustomMessage(
      "graph-live-preview-target",
      list(
        graphId = id,
        generation = generation,
        anchorId = shiny::NS(graph_single_editor_id, "preview_anchor"),
        plotId = shiny::NS(graph_single_editor_id, "plot")
      )
    )
    invisible(TRUE)
  }

  show_graph_single_editor <- function(id) {
    canonical <- if (cache_has(id)) cache_get(id) else NULL
    session$sendCustomMessage(
      "graph-client-edit-ready",
      list(id = id, single = TRUE, uiPanels = graph_ui_panels_for_id(id, canonical))
    )
    session$onFlushed(function() {
      session$sendCustomMessage("refresh-visible-graph-ui", list(id = graph_single_editor_id))
    }, once = TRUE)
    invisible(TRUE)
  }

  graph_single_finish_live_transaction <- function(id, generation, status = "plot-ready") {
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation %||% -1L)
    wait <- isolate(graph_single_live_render_wait())
    if (!is.list(wait) ||
        !identical(as.character(wait$id %||% "")[1], id) ||
        !identical(as.integer(wait$generation %||% -1L), generation) ||
        !identical(id, graph_single_owner()) ||
        !identical(generation, as.integer(isolate(graph_single_editor_generation()) %||% -1L))) {
      return(invisible(FALSE))
    }

    attempts <- as.integer(wait$settle_attempts %||% 0L)
    completed_path <- as.character(wait$completed_path %||% "REPLAY")[1]
    graph_single_live_render_wait(NULL)
    graph_single_editor_loading(FALSE)
    graph_single_editor_mode("READY")
    graph_single_mark_editor_visit(id, generation = generation)
    show_graph_single_editor(id)
    diag_log(
      "GRAPH-SINGLE-EDITOR",
      paste0(
        "load-ready attempts=", attempts,
        " path=", completed_path,
        " live_output=", status,
        " generation=", generation
      ),
      id = id
    )
    invisible(TRUE)
  }

  graph_single_release_live_render <- function(id, generation, completed_path, settle_attempts, mod) {
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation %||% -1L)

    # v3.74.3: latest-selection-wins without interrupting the transactional
    # value replay.  A newer Graph click may arrive while this target is still
    # replaying.  Once canonical acceptance has completed, the current target
    # is safe to leave, so do not spend another browser image-complete cycle
    # rendering an intermediate Graph the user no longer selected.  Keep the
    # render gate closed, release the loading flag, and let the existing
    # pending-target observer immediately start the latest queued Graph.
    pending <- isolate(graph_single_pending_target())
    pending_id <- if (is.list(pending)) as.character(pending$id %||% "")[1] else ""
    if (nzchar(pending_id) && !identical(pending_id, id)) {
      graph_single_live_render_wait(NULL)
      graph_single_editor_loading(FALSE)
      graph_single_editor_mode("READY")
      graph_single_mark_editor_visit(id, generation = generation)
      diag_log(
        "GRAPH-SINGLE-EDITOR",
        paste0(
          "superseded after canonical acceptance; final live render skipped pending=",
          pending_id, " generation=", generation
        ),
        id = id
      )
      return(invisible(TRUE))
    }

    tab <- tryCatch(
      if (is.function(mod$main_tab)) as.character(isolate(mod$main_tab()) %||% "Plot")[1] else "Plot",
      error = function(e) "Plot"
    )
    workspace_visible <- identical(
      as.character(isolate(input$workspace_main_tab) %||% "graph_workspace")[1],
      "graph_workspace"
    )
    wait_for_plot <- identical(tab, "Plot") && isTRUE(workspace_visible)
    graph_single_live_render_wait(list(
      id = id,
      generation = generation,
      completed_path = completed_path,
      settle_attempts = as.integer(settle_attempts %||% 0L),
      wait_for_plot = wait_for_plot,
      workspace_visible = workspace_visible
    ))
    graph_single_editor_mode(if (wait_for_plot) "RENDERING" else "READY")

    if (isTRUE(wait_for_plot)) {
      # Arm the browser completion listener only after canonical acceptance.
      # The target message is flushed before the render gate opens, so replay-
      # time invalidations can never consume the one completion ACK intended
      # for the final live plot.
      graph_single_begin_live_target(id, generation)
      session$onFlushed(function() {
        wait_now <- isolate(graph_single_live_render_wait())
        if (!is.list(wait_now) ||
            !identical(as.character(wait_now$id %||% "")[1], id) ||
            !identical(as.integer(wait_now$generation %||% -1L), generation) ||
            !identical(id, graph_single_owner()) ||
            !identical(generation, as.integer(isolate(graph_single_editor_generation()) %||% -1L))) {
          return(invisible(NULL))
        }
        graph_single_render_gate(TRUE)
        diag_log("GRAPH-SINGLE-EDITOR", "render-gate OPEN final persistent-live render", id = id)
        invisible(NULL)
      }, once = TRUE)
    } else {
      graph_single_render_gate(TRUE)
      diag_log("GRAPH-SINGLE-EDITOR", "render-gate OPEN plot-hidden", id = id)
      graph_single_finish_live_transaction(id, generation, status = "plot-hidden")
    }
    invisible(TRUE)
  }

  observeEvent(input$graph_live_preview_ready, {
    ack <- input$graph_live_preview_ready
    if (!is.list(ack)) return()
    id <- as.character(ack$graphId %||% "")[1]
    generation <- suppressWarnings(as.integer(ack$generation %||% -1L))
    status <- as.character(ack$status %||% "browser-output-ready")[1]
    graph_single_finish_live_transaction(id, generation, status = status)
  }, ignoreInit = TRUE, priority = 200)

  # v3.73.2.18: normal Graph switches no longer test structural
  # compatibility. Every canonical state with a UI snapshot uses state replay.

  graph_single_load <- function(id, new_graph = FALSE) {
    id <- as.character(id %||% "")[1]
    meta <- isolate(graph_meta())
    if (!nzchar(id) || !id %in% meta$id) return(invisible(FALSE))

    old_id <- graph_single_owner()
    mod <- ensure_graph_single_editor_module()

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
      show_graph_single_editor(id)
      return(invisible(TRUE))
    }

    # v3.63.1-editor-shell2: switch editor ownership before publishing the
    # previous Graph commit. registry_commit() can trigger a preview-catalog
    # update; if editing_graph_id still points at the old Graph, that catalog
    # can arrive after graph-client-edit-begin and visually snap the shell back
    # to the previous owner. Capture the old editor state first, then make the
    # new owner canonical, then commit the captured old state explicitly.
    target_had_cache <- cache_has(id)
    target_state_early <- if (isTRUE(target_had_cache)) cache_get(id) else NULL

    previous_editor_state <- NULL
    if (nzchar(old_id) && !identical(old_id, id)) {
      previous_editor_state <- tryCatch(
        if (is.function(mod$state)) isolate(mod$state()) else NULL,
        error = function(e) NULL
      )

    }

    editing_graph_id(id)
    active_graph(id)
    # Close before any update* / reshape / Mapping synchronization can invalidate
    # plot reactives. The gate reopens only after READY + canonical acceptance.
    graph_single_render_gate(FALSE)
    graph_single_editor_loading(TRUE)
    graph_single_editor_mode("REPLAY")
    diag_log("GRAPH-SINGLE-EDITOR", "render-gate CLOSED for Graph switch transaction", id = id)

    if (nzchar(old_id) && !identical(old_id, id) && is.list(previous_editor_state)) {
      changed <- graph_single_publish_state(old_id, previous_editor_state, source = "graph-single-editor-switch")
      diag_log(
        "GRAPH-SINGLE-EDITOR",
        paste0("commit previous=", old_id, " changed=", isTRUE(changed), " owner_now=", id),
        id = old_id
      )
    }
    gen <- as.integer(isolate(graph_single_editor_generation()) %||% 0L) + 1L
    graph_single_editor_generation(gen)
    graph_single_live_render_wait(NULL)
    session$sendCustomMessage("graph-client-edit-begin", list(id = id, newGraph = isTRUE(new_graph), single = TRUE))
    diag_log("GRAPH-SINGLE-EDITOR", paste0("load-request previous=", if (nzchar(old_id)) old_id else "<none>", " mode=REPLAY"), id = id)

    # v3.64.0-lazyui1: "pristine" is defined by missing canonical GraphState,
    # not by the caller's new_graph flag.  This includes the startup g001, which
    # already exists in graph_meta() but has never owned the Editor.  Never fall
    # through to an incidental shell-state commit for such a Graph.
    st <- target_state_early
    if (!is.list(st)) {
      # Only snapshot defaults while no Graph owns the shell. Once an owner
      # exists, mod$state() is that Graph and must never become the default.
      if (!nzchar(old_id)) capture_graph_single_default_state("load-pristine")
      st <- isolate(graph_single_default_state())
    }
    # On the very first activation, the shell is still pristine.  If the earlier
    # post-bind capture did not fire, this is the last safe moment to snapshot
    # defaults before any Graph owns the editor.
    if (!is.list(st) && !nzchar(old_id)) {
      candidate <- tryCatch(if (is.function(mod$state)) isolate(mod$state()) else NULL, error = function(e) NULL)
      candidate <- graph_sample_graph_state(candidate)
      if (is.list(candidate)) {
        graph_single_default_state(candidate)
        st <- candidate
        diag_log(
          "GRAPH-SINGLE-EDITOR",
          paste0(
            "built sample template at first activation mapping=",
            as.character((candidate$mapping %||% list())$x %||% "<NULL>"),
            "/", as.character((candidate$mapping %||% list())$y %||% "<NULL>")
          ),
          id = id
        )
      }
    }

    if (!is.list(st)) {
      graph_single_editor_loading(FALSE)
      graph_single_editor_mode("IDLE")
      graph_single_live_render_wait(NULL)
      graph_single_render_gate(TRUE)
      editing_graph_id("")
      diag_log("GRAPH-SINGLE-EDITOR", "default-state-missing; activation aborted; render-gate reopened", id = id)
      showNotification("新規Graphの初期状態を取得できませんでした。再度Graphを選択してください。", type = "error")
      publish_client_preview_catalog(reason = "editor-default-state-missing", selected = id, enter_browse = FALSE)
      return(invisible(FALSE))
    }

    # The Editor DOM is already bootstrapped.  Legacy/current GraphState is
    # normalized into a replayable UI snapshot in R before touching browser
    # controls; Project load never hydrates the Editor to discover choices.
    prepared_st <- graph_state_prepare_replay_snapshot(st)
    if (is.list(prepared_st) && !identical(prepared_st, st)) {
      st <- prepared_st
      registry_commit(id, st, source = "graph-ui-snapshot-preflight")
      diag_log("GRAPH-STATE-REPLAY", "prepared canonical replay state (UI/style migration)", id = id)
    } else if (is.list(prepared_st)) {
      st <- prepared_st
    }

    pristine_target <- !isTRUE(target_had_cache)
    if (isTRUE(pristine_target)) {
      graph_single_default_state(st)
      registry_commit(id, st, source = "graph-single-editor-pristine-seed")
      diag_log(
        "GRAPH-SINGLE-EDITOR",
        "seeded pristine GraphState before editor attach",
        id = id
      )
    }

    replay_started <- FALSE
    if (is.function(mod$replay_state)) {
      graph_single_editor_mode("REPLAY")
      replay_started <- isTRUE(mod$replay_state(st, transaction = list(
        id = id, generation = gen, new_graph = isTRUE(new_graph), revisit_fresh = isTRUE(visit_fresh)
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
      # value-only.  Do not rebuild/hydrate the DOM for Project load or legacy
      # state; a failed replay is an activation error, not a restore request.
      graph_single_editor_loading(FALSE)
      graph_single_editor_mode("IDLE")
      graph_single_live_render_wait(NULL)
      graph_single_render_gate(TRUE)
      editing_graph_id("")
      diag_log("GRAPH-SINGLE-EDITOR", "value replay unavailable; activation aborted", id = id)
      session$sendCustomMessage("graph-editor-shell-clear", list(selected = id, reason = "replay-unavailable"))
      return(invisible(FALSE))
    }
    invisible(TRUE)
  }

  observe({
    gen <- graph_single_editor_generation()
    if (!isTRUE(graph_single_editor_loading())) return()
    id <- graph_single_owner()
    mod <- graph_single_mod()
    if (!nzchar(id) || is.null(mod)) return()

    # State replay already owns the one browser completion barrier. Once it is
    # inactive, do not read the UI back, compare it with canonical state, retry,
    # or reconcile. The loaded GraphState is authoritative; any invalid plot
    # combination is handled by the ordinary Plot error surface.
    if (is.function(mod$replay_active) && isTRUE(tryCatch(mod$replay_active(), error = function(e) FALSE))) return()
    if (!isTRUE(tryCatch(mod$ready(), error = function(e) FALSE))) return()

    completed_path <- as.character(isolate(graph_single_editor_mode()) %||% "REPLAY")[1]
    acceptance <- graph_single_accept_loaded_state(id, mod, NULL, gen)
    if (identical(acceptance, "failed")) {
      graph_single_abort_activation(id, reason = "canonical-state-missing")
      return()
    }

    accepted_state <- if (cache_has(id)) cache_get(id) else NULL
    attached_ok <- tryCatch(
      is.list(accepted_state) && is.function(mod$accept_canonical) &&
        isTRUE(mod$accept_canonical(accepted_state, reason = "outer-ready-accept")),
      error = function(e) {
        diag_log("GRAPH-SINGLE-EDITOR", paste0("accepted canonical attach failed: ", conditionMessage(e)), id = id)
        FALSE
      }
    )
    if (!isTRUE(attached_ok)) {
      graph_single_abort_activation(id, reason = "accepted-canonical-attach-failed")
      return()
    }

    graph_single_release_live_render(
      id = id,
      generation = as.integer(gen),
      completed_path = completed_path,
      settle_attempts = 0L,
      mod = mod
    )
  }, priority = 100)


  # v3.73.2.18: normal Graph renders are live-only. Do not generate or
  # publish a Graph SVG after every successful render. Figure/Inset/Project
  # compatibility paths materialize vector snapshots explicitly when requested.

  # ------------------------------------------------------------------
  # F1-5p Figure-owned editable Graph snapshots
  # ------------------------------------------------------------------
