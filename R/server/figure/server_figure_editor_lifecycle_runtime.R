# ============================================================
# Figure controls-only single Editor lifecycle
# v4.0 RC3: one transaction owner for mount -> replay -> READY.
# Sourced inside the server session environment.
# ============================================================

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
    figure_editor_epoch(as.integer(isolate(figure_editor_epoch()) %||% 0L) + 1L)
    figure_editor_mount_pending(list(id="", editor_id="", wrapper_id="", generation=isolate(figure_editor_mount_generation())))
    figure_editing_graph("")
    figure_single_editor_loading(FALSE)
    figure_single_editor_show_when_ready(TRUE)
    figure_single_editor_target_state(NULL)
    figure_single_editor_pending_request(NULL)
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
      profile_contract <- graph_editor_profile("figure_controls")
      mount_ids <- graph_editor_profile_mount_inputs(profile_contract)
      fields <- lapply(mount_ids, function(field_id) {
        list(field = field_id, id = shiny::NS(editor_id, field_id))
      })
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

  queue_figure_editor_request <- function(id, state, force_reload = FALSE,
                                        preserve_current = TRUE, show_when_ready = TRUE,
                                        reason = "busy") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state)) return(invisible(FALSE))
    figure_single_editor_pending_request(list(
      id = id,
      state = state,
      force_reload = isTRUE(force_reload),
      preserve_current = isTRUE(preserve_current),
      show_when_ready = isTRUE(show_when_ready)
    ))
    diag_log(
      "FIGURE-SINGLE-EDITOR",
      paste0(
        "request-queued reason=", reason,
        " owner=", as.character(isolate(figure_editing_graph()) %||% "<none>")[1],
        " phase=", as.character(isolate(figure_single_editor_mode()) %||% "IDLE")[1]
      ),
      id = id
    )
    invisible(TRUE)
  }

  commit_figure_editor_state <- function(id, state_now, reason = "editor") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !is.list(state_now)) return(invisible(list(changed=FALSE, render_changed=FALSE)))

    states <- isolate(figure_edit_states())
    previous <- states[[id]]
    changed <- !is.list(previous) || !app_state_semantically_equal(previous, state_now)
    if (!isTRUE(changed)) {
      return(invisible(list(changed=FALSE, render_changed=FALSE)))
    }

    # Figure GraphState may contain dormant editor preferences whose values do
    # not affect the currently rendered plot. Persist those values, but do not
    # republish the Figure snapshot unless the semantic RenderState changed.
    # This makes panel selection an editor-ownership change rather than a canvas
    # redraw trigger.
    render_changed <- !is.list(previous) || graph_render_state_changed(previous, state_now)
    store_figure_edit_state(id, state_now, reason = reason)

    if (isTRUE(render_changed)) {
      snapshot_ready_figure_editor(id, state_now)
    } else {
      diag_log(
        "FIGURE-EDIT-STATE",
        paste0("stored without snapshot reason=", reason, " render_changed=FALSE"),
        id = id
      )
    }

    invisible(list(changed=TRUE, render_changed=isTRUE(render_changed)))
  }

  start_figure_editor_replay <- function(id, mod, state, generation, reason = "load") {
    id <- as.character(id %||% "")[1]
    generation <- as.integer(generation %||% -1L)
    if (!nzchar(id) || generation < 0L || is.null(mod) || !is.list(state) ||
        !is.function(mod$replay_state)) return(invisible(FALSE))

    figure_single_editor_mode("REPLAY")
    figure_single_editor_target_state(state)
    ok <- isTRUE(mod$replay_state(
      state,
      transaction = list(id = id, generation = generation, figure = TRUE)
    ))
    if (!isTRUE(ok)) {
      figure_single_editor_loading(FALSE)
      figure_single_editor_pending_request(NULL)
      figure_single_editor_mode("IDLE")
      diag_log("FIGURE-SINGLE-EDITOR", paste0("replay-start failed reason=", reason), id = id)
      return(invisible(FALSE))
    }
    diag_log(
      "FIGURE-SINGLE-EDITOR",
      paste0("replay-start generation=", generation, " reason=", reason),
      id = id
    )
    invisible(TRUE)
  }

  ensure_figure_editor <- function(id, force_reload = FALSE, preserve_current = TRUE,
                                   show_when_ready = TRUE, state_override = NULL) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) { show_figure_editor_wrapper(""); return(FALSE) }

    states <- isolate(figure_edit_states())
    state <- if (is.list(state_override)) state_override else states[[id]]
    if (!is.list(state)) {
      if (isTRUE(show_when_ready)) {
        showNotification("Figure側に編集可能なGraph snapshotがありません。先に『Graphから再読込』してください。", type="warning", duration=4)
      }
      return(FALSE)
    }

    # One Figure Editor owns one transaction at a time. Requests arriving while
    # MOUNTING/REPLAY never start a second replay in parallel. Same-target intent
    # is coalesced; a genuinely newer/different target becomes one latest-wins
    # deferred request and is drained after READY.
    loading <- isTRUE(isolate(figure_single_editor_loading()))
    loading_owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    loading_phase <- as.character(isolate(figure_single_editor_mode()) %||% "IDLE")[1]
    if (isTRUE(loading) && nzchar(loading_owner)) {
      current_target <- isolate(figure_single_editor_target_state())
      same_owner <- identical(loading_owner, id)
      same_target <- same_owner && is.list(current_target) &&
        app_state_semantically_equal(current_target, state)

      if (same_owner && identical(loading_phase, "MOUNTING")) {
        # No replay has begun yet. Let the mount ACK consume the newest state
        # exactly once instead of creating a pre-ACK replay.
        figure_single_editor_target_state(state)
        figure_single_editor_show_when_ready(isTRUE(show_when_ready))
        figure_single_editor_pending_request(NULL)
        diag_log("FIGURE-SINGLE-EDITOR", "request-coalesced phase=MOUNTING", id = id)
        return(TRUE)
      }

      if (same_target && !isTRUE(force_reload)) {
        figure_single_editor_show_when_ready(isTRUE(show_when_ready))
        figure_single_editor_pending_request(NULL)
        diag_log("FIGURE-SINGLE-EDITOR", paste0("request-coalesced phase=", loading_phase), id = id)
        return(TRUE)
      }

      queue_figure_editor_request(
        id, state,
        force_reload = force_reload,
        preserve_current = preserve_current,
        show_when_ready = show_when_ready,
        reason = if (same_owner) "newer-same-owner-state" else paste0("busy-owner-", loading_owner)
      )
      return(TRUE)
    }

    editor_id <- figure_editor_module_id()
    wrapper_id <- figure_editor_wrapper_id()
    mounted <- exists("single", envir = figure_editor_mounted, inherits = FALSE) &&
      isTRUE(get("single", envir = figure_editor_mounted, inherits = FALSE))

    old_id <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    old_mod <- if (nzchar(old_id)) figure_editor_module(old_id) else NULL
    if (!isTRUE(force_reload) && identical(old_id, id) && !is.null(old_mod) &&
        isTRUE(tryCatch(isolate(old_mod$ready()), error = function(e) FALSE))) {
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
        commit_figure_editor_state(old_id, old_state, reason = "single-editor-switch")
      }
    }

    figure_editing_graph(id)
    figure_single_editor_loading(TRUE)
    figure_single_editor_show_when_ready(isTRUE(show_when_ready))
    figure_single_editor_target_state(state)
    next_generation <- as.integer(isolate(figure_single_editor_generation()) %||% 0L) + 1L
    figure_single_editor_generation(next_generation)
    show_figure_editor_wrapper("")

    if (!mounted) {
      figure_single_editor_mode("MOUNTING")
      diag_log(
        "FIGURE-SINGLE-EDITOR",
        paste0("load-request previous=", if (nzchar(old_id)) old_id else "<none>",
               " mode=MOUNTING visible=", isTRUE(show_when_ready),
               " generation=", next_generation),
        id = id
      )
      insertUI(
        selector = "#figure_graph_editor_host", where = "beforeEnd",
        ui = div(
          id = wrapper_id,
          class = "figure-graph-editor-instance",
          style = "display:none;",
          graphUI(editor_id, initial_state = state, profile = "figure_controls")
        ),
        immediate = TRUE
      )
      assign("single", TRUE, envir = figure_editor_mounted)
      fig_profile <- graph_editor_profile("figure_controls")
      diag_log(
        "FIGURE-SINGLE-EDITOR",
        paste0(
          "UI inserted editor_id=", editor_id,
          " profile=", fig_profile$name,
          " editable_data=", graph_editor_profile_has(fig_profile, "editable_data"),
          " statistics=", graph_editor_profile_has(fig_profile, "statistics"),
          " replay_required={", paste(graph_editor_profile_required_inputs(fig_profile), collapse=","), "}"
        ),
        id = id
      )
    } else {
      figure_single_editor_mode("REPLAY")
      diag_log(
        "FIGURE-SINGLE-EDITOR",
        paste0("load-request previous=", if (nzchar(old_id)) old_id else "<none>",
               " mode=REPLAY visible=", isTRUE(show_when_ready),
               " generation=", next_generation),
        id = id
      )
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
        profile = "figure_controls",
        # Figure Controls use the lifecycle itself as the render permission
        # boundary. MOUNTING/REPLAY may update controls and semantic revision,
        # but no preview/dimension render is allowed until READY opens this gate.
        render_gate = reactive({ !isTRUE(figure_single_editor_loading()) }),
        on_state_change = function(state_now) {
          if (!identical(as.integer(isolate(figure_editor_epoch())), as.integer(epoch0))) return(invisible(NULL))
          if (isTRUE(isolate(figure_single_editor_loading()))) return(invisible(NULL))
          if (!isTRUE(isolate(figure_single_editor_show_when_ready()))) return(invisible(NULL))
          owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
          if (!nzchar(owner)) return(invisible(NULL))
          commit_figure_editor_state(owner, state_now, reason = "figure-single-editor")
        }
      )
      diag_log("FIGURE-EDIT-INIT-TIMING", "mark=CALLSITE-AFTER-GRAPHSERVER source=figure-single-editor", id = id)
      assign("single", mod, envir = figure_editor_modules)
      # Initial UI creation is mount-owned. The ACK below is the only owner of
      # the first replay; do not replay from this callsite before bindings exist.
      request_figure_editor_mount_ack(id, editor_id, wrapper_id)
      return(TRUE)
    }

    start_figure_editor_replay(
      id, mod, state, next_generation,
      reason = if (isTRUE(force_reload)) "force-reload" else "load"
    )
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
      figure_single_editor_pending_request(NULL)
      figure_single_editor_mode("IDLE")
      showNotification("Figure Graph EditorのUI bindingを確認できませんでした。", type="warning", duration=4)
      return()
    }

    mod <- figure_editor_module(id)
    latest_state <- isolate(figure_single_editor_target_state())
    if (!is.list(latest_state)) latest_state <- isolate(figure_edit_states())[[id]]
    replay_generation <- as.integer(isolate(figure_single_editor_generation()) %||% 0L)
    start_figure_editor_replay(
      id, mod, latest_state, replay_generation, reason = "mount-ready"
    )
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

    # Latest-selection-wins at a transaction boundary. If a newer Figure-editor
    # request arrived while this replay was in flight, the completed target is
    # already semantically safe but no longer needs a visible plot. Move
    # directly into the queued transaction while the render gate remains
    # effectively closed; no intermediate Figure render/snapshot is published.
    pending_request <- isolate(figure_single_editor_pending_request())
    if (is.list(pending_request) && nzchar(as.character(pending_request$id %||% "")[1])) {
      figure_single_editor_pending_request(NULL)
      figure_single_editor_loading(FALSE)
      figure_single_editor_mode("READY")
      next_id <- as.character(pending_request$id %||% "")[1]
      diag_log(
        "FIGURE-SINGLE-EDITOR",
        paste0("superseded after replay; final render skipped pending=", next_id),
        id = id
      )
      started_next <- isTRUE(ensure_figure_editor(
        next_id,
        force_reload = isTRUE(pending_request$force_reload),
        # The outgoing editor was loading, so no user edit could have occurred
        # after the state was captured at the previous transaction boundary.
        preserve_current = FALSE,
        show_when_ready = isTRUE(pending_request$show_when_ready),
        state_override = pending_request$state
      ))
      if (isTRUE(started_next)) return()
      # If the deferred request became invalid, keep the completed current
      # target usable rather than leaving the editor hidden.
      figure_editing_graph(id)
      figure_single_editor_loading(TRUE)
      figure_single_editor_target_state(isolate(figure_edit_states())[[id]])
      figure_single_editor_mode("REPLAY")
    }

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

