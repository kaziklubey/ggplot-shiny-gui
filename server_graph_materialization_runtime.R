  # ------------------------------------------------------------------
  # Internal source-materialization state
  # ------------------------------------------------------------------
  # This runtime owns all queue/barrier state. Callers outside this file must
  # depend only on the named service API below (`schedule_*`, `request_*`,
  # `graph_materialization_signal`, reset/remove/retry helpers).
  graph_materialization_queue <- reactiveVal(character(0))
  graph_materialization_current <- reactiveVal("")
  graph_materialization_active <- reactiveVal(FALSE)
  graph_materialization_generation <- reactiveVal(0L)

  # Browser-drain barrier between serial materialization jobs.
  graph_materialization_drain_pending <- reactiveVal(FALSE)
  graph_materialization_drain_generation <- reactiveVal(0L)
  graph_materialization_drain_graph <- reactiveVal("")

  # insertUI() completion is not browser binding completion. Keep a
  # browser-confirmed mount registry and generation-scoped ACK state.
  graph_ui_browser_ready <- new.env(parent = emptyenv())
  browser_ui_ready <- function(id) exists(id, envir = graph_ui_browser_ready, inherits = FALSE)
  mark_browser_ui_ready <- function(id, value = TRUE) {
    if (isTRUE(value)) assign(id, TRUE, envir = graph_ui_browser_ready)
    else if (browser_ui_ready(id)) rm(list = id, envir = graph_ui_browser_ready)
    invisible(isTRUE(value))
  }
  graph_materialization_mount_pending <- reactiveVal(FALSE)
  graph_materialization_mount_generation <- reactiveVal(0L)
  graph_materialization_mount_graph <- reactiveVal("")

  # Newly-created background graphServer instances cross one browser drain
  # barrier before canonical GraphState restore begins.
  graph_materialization_init_pending <- reactiveVal(FALSE)
  graph_materialization_init_generation <- reactiveVal(0L)
  graph_materialization_init_graph <- reactiveVal("")
  graph_materialization_init_ready <- new.env(parent = emptyenv())
  init_drain_ready <- function(id) exists(id, envir = graph_materialization_init_ready, inherits = FALSE)
  mark_init_drain_ready <- function(id, value = TRUE) {
    if (isTRUE(value)) assign(id, TRUE, envir = graph_materialization_init_ready)
    else if (init_drain_ready(id)) rm(list = id, envir = graph_materialization_init_ready)
    invisible(isTRUE(value))
  }

  # Public read-only/service boundary for callers. Figure/Export/Project code
  # may request work or depend on this signal, but must not mutate queue/barrier
  # internals directly.
  graph_materialization_signal <- function() {
    graph_materialization_generation()
  }

  graph_materialization_current_is <- function(id) {
    id <- as.character(id %||% "")[1]
    nzchar(id) && identical(as.character(isolate(graph_materialization_current()) %||% "")[1], id)
  }

  graph_materialization_current_id <- function() {
    as.character(isolate(graph_materialization_current()) %||% "")[1]
  }

  graph_materialization_forget_ui_state <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))
    mark_browser_ui_ready(id, FALSE)
    mark_init_drain_ready(id, FALSE)
    invisible(TRUE)
  }

  reset_graph_materialization_service <- function(reason = "reset") {
    graph_materialization_queue(character(0))
    graph_materialization_current("")
    graph_materialization_active(FALSE)

    graph_materialization_drain_pending(FALSE)
    graph_materialization_drain_graph("")
    graph_materialization_drain_generation(as.integer(isolate(graph_materialization_drain_generation()) %||% 0L) + 1L)

    graph_materialization_mount_pending(FALSE)
    graph_materialization_mount_graph("")
    graph_materialization_mount_generation(as.integer(isolate(graph_materialization_mount_generation()) %||% 0L) + 1L)

    graph_materialization_init_pending(FALSE)
    graph_materialization_init_graph("")
    graph_materialization_init_generation(as.integer(isolate(graph_materialization_init_generation()) %||% 0L) + 1L)

    if (length(ls(envir = graph_ui_browser_ready, all.names = TRUE))) {
      rm(list = ls(envir = graph_ui_browser_ready, all.names = TRUE), envir = graph_ui_browser_ready)
    }
    if (length(ls(envir = graph_materialization_init_ready, all.names = TRUE))) {
      rm(list = ls(envir = graph_materialization_init_ready, all.names = TRUE), envir = graph_materialization_init_ready)
    }
    if (length(ls(envir = graph_source_module_lease, all.names = TRUE))) {
      rm(list = ls(envir = graph_source_module_lease, all.names = TRUE), envir = graph_source_module_lease)
    }
    if (length(ls(envir = graph_source_sync_target, all.names = TRUE))) {
      rm(list = ls(envir = graph_source_sync_target, all.names = TRUE), envir = graph_source_sync_target)
    }

    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    diag_log("MATERIALIZE", paste0("SERVICE RESET reason=", reason))
    invisible(TRUE)
  }

  remove_graph_materialization_item <- function(id, reason = "remove") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))

    cancel_graph_materialization_barriers(id)
    mark_browser_ui_ready(id, FALSE)
    mark_init_drain_ready(id, FALSE)
    invalidate_graph_source_module(id, reason)

    q <- isolate(graph_materialization_queue())
    if (length(q)) graph_materialization_queue(q[q != id])
    if (graph_materialization_current_is(id)) graph_materialization_current("")
    graph_materialization_active(length(isolate(graph_materialization_queue())) > 0L)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    diag_log("MATERIALIZE", paste0("ITEM REMOVE reason=", reason), id = id)
    invisible(TRUE)
  }

  reset_graph_materialization_source <- function(id, reason = "retry") {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || !module_exists(id) || !cache_has(id)) return(invisible(FALSE))
    mod <- modules[[id]]
    if (is.null(mod) || !is.function(mod$prepare_restore)) return(invisible(FALSE))

    cancel_graph_materialization_barriers(id)
    mark_browser_ui_ready(id, FALSE)
    mark_init_drain_ready(id, FALSE)
    q <- isolate(graph_materialization_queue())
    if (length(q)) graph_materialization_queue(q[q != id])
    if (graph_materialization_current_is(id)) graph_materialization_current("")
    graph_materialization_active(length(isolate(graph_materialization_queue())) > 0L)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)

    ok <- isTRUE(tryCatch(
      mod$prepare_restore(cache_get(id), source = reason),
      error = function(e) {
        diag_log("MATERIALIZE", paste0("retry prepare_restore ERROR: ", conditionMessage(e)), id = id)
        FALSE
      }
    ))
    if (exists(id, envir = graph_source_sync_target, inherits = FALSE)) {
      rm(list = id, envir = graph_source_sync_target)
    }
    diag_log("MATERIALIZE", paste0("SOURCE RESET reason=", reason, " prepared=", ok), id = id)
    invisible(ok)
  }

  schedule_graph_materialization <- function(ids, reason = "schedule") {
    ids <- unique(as.character(ids %||% character(0)))
    valid <- as.character(isolate(graph_meta())$id %||% character(0))
    ids <- ids[nzchar(ids) & ids %in% valid]
    ids <- ids[!vapply(ids, source_graph_ready, logical(1))]
    existing <- isolate(graph_materialization_queue())
    cur <- as.character(isolate(graph_materialization_current()) %||% "")

    # v3.3.60: the in-flight Graph is authoritative until it reaches ready().
    # A delayed project schedule may append work, but must never clear or move
    # the current Graph.  This prevents two graphServer restores from running
    # concurrently in the same Shiny session.
    waiting_existing <- existing[existing != cur]
    waiting <- unique(c(waiting_existing, ids[ids != cur]))
    waiting <- waiting[!vapply(waiting, source_graph_ready, logical(1))]
    q <- if (nzchar(cur) && !source_graph_ready(cur)) c(cur, waiting) else waiting

    graph_materialization_queue(q)
    graph_materialization_active(length(q) > 0L)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    diag_log(
      "MATERIALIZE",
      paste0("queue=", paste(q, collapse = ","), " current=", cur, " reason=", reason)
    )
    invisible(q)
  }

  cancel_graph_materialization_barriers <- function(id) {
    id <- as.character(id %||% "")
    if (!nzchar(id)) return(invisible(FALSE))

    if (isTRUE(isolate(graph_materialization_mount_pending())) &&
        identical(as.character(isolate(graph_materialization_mount_graph()) %||% ""), id)) {
      session$sendCustomMessage(
        "graph-ui-mount-cancel",
        list(graphId = id, ackId = "graph_ui_mount_ack")
      )
      graph_materialization_mount_pending(FALSE)
      graph_materialization_mount_graph("")
      graph_materialization_mount_generation(as.integer(isolate(graph_materialization_mount_generation()) %||% 0L) + 1L)
    }
    if (isTRUE(isolate(graph_materialization_init_pending())) &&
        identical(as.character(isolate(graph_materialization_init_graph()) %||% ""), id)) {
      graph_materialization_init_pending(FALSE)
      graph_materialization_init_graph("")
      graph_materialization_init_generation(as.integer(isolate(graph_materialization_init_generation()) %||% 0L) + 1L)
    }
    if (isTRUE(isolate(graph_materialization_drain_pending())) &&
        identical(as.character(isolate(graph_materialization_drain_graph()) %||% ""), id)) {
      graph_materialization_drain_pending(FALSE)
      graph_materialization_drain_graph("")
      graph_materialization_drain_generation(as.integer(isolate(graph_materialization_drain_generation()) %||% 0L) + 1L)
    }
    invisible(TRUE)
  }

  cancel_graph_restore_for_canonical_update <- function(id, state, reason = "canonical-update") {
    id <- as.character(id %||% "")
    if (!nzchar(id) || graph_is_ready(id)) return(invisible(FALSE))

    mod <- if (module_exists(id)) modules[[id]] else NULL
    if (!is.null(mod) && is.function(mod$prepare_restore) && is.list(state)) {
      try(mod$prepare_restore(state, source = reason), silent = TRUE)
    } else if (!is.null(mod) && is.function(mod$cancel_restore)) {
      try(mod$cancel_restore(reason = reason), silent = TRUE)
    }

    cancel_graph_materialization_barriers(id)
    mark_init_drain_ready(id, FALSE)
    q <- isolate(graph_materialization_queue())
    q2 <- q[q != id]
    if (identical(as.character(isolate(graph_materialization_current()) %||% ""), id)) {
      graph_materialization_current("")
    }
    graph_materialization_queue(q2)
    graph_materialization_active(length(q2) > 0L)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    if (identical(as.character(isolate(pending_display_graph()) %||% ""), id)) pending_display_graph(NULL)
    if (identical(as.character(isolate(restore_target()) %||% ""), id)) {
      restore_target(NULL)
      restore_status("idle")
    }
    diag_log("RESTORE-CANCEL", paste0("reason=", reason, " canonical_state_held=", is.list(state)), id = id)
    invisible(TRUE)
  }

  materialization_reason_is_user_priority <- function(reason) {
    reason <- as.character(reason %||% "")[1]
    reason %in% c(
      "show-graph", "show-project", "figure-assignment",
      "figure-panel-explicit-refresh", "figure-inset-explicit-refresh"
    )
  }

  preempt_graph_materialization <- function(current_id, requested_id, reason = "user") {
    current_id <- as.character(current_id %||% "")
    requested_id <- as.character(requested_id %||% "")
    if (!nzchar(current_id) || !nzchar(requested_id) || identical(current_id, requested_id)) {
      return(invisible(FALSE))
    }
    if (source_graph_ready(current_id)) return(invisible(FALSE))

    diag_log(
      "MATERIALIZE",
      paste0("PREEMPT current=", current_id, " requested=", requested_id, " reason=", reason),
      id = requested_id
    )

    # Cancel the module restore before removing DOM. Never persist a half-
    # hydrated module: graph_state_cache remains the canonical restart seed.
    mod <- if (module_exists(current_id)) modules[[current_id]] else NULL
    if (!is.null(mod) && is.function(mod$cancel_restore)) {
      try(mod$cancel_restore(reason = paste0("preempt->", requested_id)), silent = TRUE)
    }
    cancel_graph_materialization_barriers(current_id)
    mark_init_drain_ready(current_id, FALSE)
    if (ui_mounted(current_id)) {
      evict_graph_source_ui(
        current_id,
        reason = paste0("preempt->", requested_id),
        force = TRUE
      )
      # removeUI(immediate=TRUE) is normally sufficient, but preemption happens
      # exactly while browser binding traffic is active. Repeat the same scoped
      # removal after the current flush as an idempotent cleanup barrier. The
      # cancelled Graph is dormant and cannot be remounted in this interval.
      cancelled_id <- current_id
      session$onFlushed(function() {
        try(removeUI(selector = paste0("#panel_", cancelled_id), immediate = TRUE), silent = TRUE)
        mark_ui_mounted(cancelled_id, FALSE)
        mark_browser_ui_ready(cancelled_id, FALSE)
        diag_log("MATERIALIZE", "PREEMPT DOM cleanup barrier completed", id = cancelled_id)
      }, once = TRUE)
    }

    # The cancelled Graph leaves the queue entirely. In cache-first mode it is
    # dormant again and will restart only when explicitly selected later.
    q <- isolate(graph_materialization_queue())
    waiting <- q[q != current_id & q != requested_id]
    q2 <- unique(c(requested_id, waiting))
    graph_materialization_current("")
    graph_materialization_queue(q2)
    graph_materialization_active(length(q2) > 0L)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    invisible(TRUE)
  }

  request_graph_materialization <- function(id, reason = "user") {
    id <- as.character(id %||% "")
    if (!nzchar(id) || source_graph_ready(id)) return(invisible(FALSE))
    q <- isolate(graph_materialization_queue())
    cur <- as.character(isolate(graph_materialization_current()) %||% "")
    if (identical(cur, id)) {
      diag_log("MATERIALIZE", paste0("PROMOTE current-inflight reason=", reason), id = id)
      return(invisible(TRUE))
    }

    if (nzchar(cur) && !source_graph_ready(cur) && materialization_reason_is_user_priority(reason)) {
      if (isTRUE(preempt_graph_materialization(cur, id, reason = reason))) {
        diag_log(
          "MATERIALIZE",
          paste0("PREEMPTED previous=", cur, " queue=", paste(isolate(graph_materialization_queue()), collapse = ",")),
          id = id
        )
        return(invisible(TRUE))
      }
    }

    # Non-user/background promotion changes only the WAITING order. It never
    # starts another Graph while `cur` is restoring. The promoted Graph becomes
    # the next serial job.
    waiting <- q[q != cur & q != id]
    q2 <- if (nzchar(cur) && !source_graph_ready(cur)) {
      c(cur, id, waiting)
    } else {
      c(id, waiting)
    }
    q2 <- unique(q2[nzchar(q2)])
    graph_materialization_queue(q2)
    graph_materialization_active(TRUE)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    diag_log(
      "MATERIALIZE",
      paste0("PROMOTE reason=", reason, " current=", cur, " queue=", paste(q2, collapse = ",")),
      id = id
    )
    invisible(TRUE)
  }

  request_graph_materialization_ui_mount <- function(id) {
    id <- as.character(id %||% "")
    if (!nzchar(id) || browser_ui_ready(id)) return(invisible(FALSE))
    if (isTRUE(isolate(graph_materialization_mount_pending())) &&
        identical(as.character(isolate(graph_materialization_mount_graph()) %||% ""), id)) {
      return(invisible(TRUE))
    }

    gen <- as.integer(isolate(graph_materialization_mount_generation()) %||% 0L) + 1L
    graph_materialization_mount_generation(gen)
    graph_materialization_mount_graph(id)
    graph_materialization_mount_pending(TRUE)
    diag_log("UI-MOUNT-ACK", paste0("scheduled generation=", gen), id = id)

    # insertUI() is delivered at flush time.  Send the mount checker only after
    # that flush has completed, preserving message order without a fixed sleep.
    session$onFlushed(function() {
      if (!isTRUE(isolate(graph_materialization_mount_pending()))) return()
      if (!identical(as.integer(isolate(graph_materialization_mount_generation())), gen)) return()
      if (!identical(as.character(isolate(graph_materialization_mount_graph()) %||% ""), id)) return()
      diag_log("UI-MOUNT-ACK", paste0("request generation=", gen), id = id)
      session$sendCustomMessage(
        "graph-ui-mount-check",
        list(
          generation = gen,
          graphId = id,
          panelId = paste0("panel_", id),
          fields = list(
            list(field = "plot_type", id = shiny::NS(id, "plot_type")),
            list(field = "reshape_wide", id = shiny::NS(id, "reshape_wide")),
            list(field = "sticky_plot", id = shiny::NS(id, "sticky_plot")),
            list(field = "graph_main_tab", id = shiny::NS(id, "graph_main_tab"))
          ),
          ackId = "graph_ui_mount_ack"
        )
      )
    }, once = TRUE)

    invisible(TRUE)
  }

  handle_graph_materialization_ui_mount_ack <- function(ack) {
    if (!is.list(ack) || !isTRUE(isolate(graph_materialization_mount_pending()))) return(invisible(FALSE))
    gen <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
    expected <- suppressWarnings(as.integer(isolate(graph_materialization_mount_generation()) %||% 0L))
    id <- as.character(isolate(graph_materialization_mount_graph()) %||% "")
    if (!is.finite(gen) || !identical(gen, expected)) {
      diag_log("UI-MOUNT-ACK", paste0("stale ack ignored generation=", gen, " expected=", expected), id = id)
      return(invisible(FALSE))
    }
    status <- as.character(ack$status %||% "")[1]
    diag_log(
      "UI-MOUNT-ACK",
      paste0(
        "ack generation=", gen,
        " status=", status,
        " elapsed_ms=", ack$elapsedMs %||% "NA",
        " dom_inputs=", ack$domInputCount %||% "NA",
        " bound_inputs=", ack$boundInputCount %||% "NA",
        " missing=", paste(as.character(unlist(ack$missing %||% character(0), use.names = FALSE)), collapse = ",")
      ),
      id = id
    )
    graph_materialization_mount_pending(FALSE)
    graph_materialization_mount_graph("")
    if (identical(status, "ready")) {
      mark_browser_ui_ready(id, TRUE)
      graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
      return(invisible(TRUE))
    }

    graph_materialization_active(FALSE)
    graph_materialization_current("")
    fail_project_load_lock(id, "Graph UIのbrowser mount/bindingを確認できませんでした。")
    invisible(FALSE)
  }

  observeEvent(input$graph_ui_mount_ack, {
    handle_graph_materialization_ui_mount_ack(input$graph_ui_mount_ack)
  }, ignoreInit = TRUE)

  request_graph_materialization_init_drain <- function(id) {
    id <- as.character(id %||% "")
    if (!nzchar(id) || init_drain_ready(id)) return(invisible(FALSE))
    if (isTRUE(isolate(graph_materialization_init_pending())) &&
        identical(as.character(isolate(graph_materialization_init_graph()) %||% ""), id)) {
      return(invisible(TRUE))
    }
    gen <- as.integer(isolate(graph_materialization_init_generation()) %||% 0L) + 1L
    graph_materialization_init_generation(gen)
    graph_materialization_init_graph(id)
    graph_materialization_init_pending(TRUE)
    diag_log("MODULE-INIT-DRAIN", paste0("scheduled generation=", gen), id = id)

    # graphServer() registration can enqueue a large first wave of outputs.
    # Cross a browser paint barrier only after the server flush that registered
    # those outputs, then start Project restore.
    session$onFlushed(function() {
      if (!isTRUE(isolate(graph_materialization_init_pending()))) return()
      if (!identical(as.integer(isolate(graph_materialization_init_generation())), gen)) return()
      if (!identical(as.character(isolate(graph_materialization_init_graph()) %||% ""), id)) return()
      diag_log("MODULE-INIT-DRAIN", paste0("request generation=", gen), id = id)
      session$sendCustomMessage(
        "graph-materialization-browser-drain",
        list(
          generation = gen,
          graphId = id,
          ackId = "graph_materialization_browser_init_ack"
        )
      )
    }, once = TRUE)

    invisible(TRUE)
  }

  handle_graph_materialization_init_ack <- function(ack) {
    if (!is.list(ack) || !isTRUE(isolate(graph_materialization_init_pending()))) return(invisible(FALSE))
    gen <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
    expected <- suppressWarnings(as.integer(isolate(graph_materialization_init_generation()) %||% 0L))
    id <- as.character(isolate(graph_materialization_init_graph()) %||% "")
    if (!is.finite(gen) || !identical(gen, expected)) {
      diag_log("MODULE-INIT-DRAIN", paste0("stale ack ignored generation=", gen, " expected=", expected), id = id)
      return(invisible(FALSE))
    }
    diag_log(
      "MODULE-INIT-DRAIN",
      paste0(
        "ack generation=", gen,
        " elapsed_ms=", ack$elapsedMs %||% "NA",
        " dom_inputs=", ack$domInputCount %||% "NA",
        " bound_inputs=", ack$boundInputCount %||% "NA"
      ),
      id = id
    )
    graph_materialization_init_pending(FALSE)
    graph_materialization_init_graph("")
    mark_init_drain_ready(id, TRUE)
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    invisible(TRUE)
  }

  observeEvent(input$graph_materialization_browser_init_ack, {
    handle_graph_materialization_init_ack(input$graph_materialization_browser_init_ack)
  }, ignoreInit = TRUE)

  request_graph_materialization_browser_drain <- function(id) {
    gen <- as.integer(isolate(graph_materialization_drain_generation()) %||% 0L) + 1L
    graph_materialization_drain_generation(gen)
    graph_materialization_drain_graph(as.character(id %||% ""))
    graph_materialization_drain_pending(TRUE)
    diag_log("MATERIALIZE-DRAIN", paste0("scheduled generation=", gen), id = id)

    # READY can be observed before the final output messages from that reactive
    # flush have reached the browser.  Send the drain request only after the
    # flush boundary so the ack is ordered behind those messages.
    session$onFlushed(function() {
      if (!isTRUE(isolate(graph_materialization_drain_pending()))) return()
      if (!identical(as.integer(isolate(graph_materialization_drain_generation())), gen)) return()
      if (!identical(as.character(isolate(graph_materialization_drain_graph()) %||% ""), as.character(id %||% ""))) return()
      diag_log("MATERIALIZE-DRAIN", paste0("request generation=", gen), id = id)
      session$sendCustomMessage(
        "graph-materialization-browser-drain",
        list(
          generation = gen,
          graphId = as.character(id %||% ""),
          ackId = "graph_materialization_browser_drain_ack"
        )
      )
    }, once = TRUE)

    # Completion is generation-scoped browser ACK only; no timer fallback is used.
    invisible(gen)
  }

  handle_graph_materialization_browser_drain_ack <- function(ack) {
    if (!is.list(ack) || !isTRUE(isolate(graph_materialization_drain_pending()))) return(invisible(FALSE))
    gen <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
    expected <- suppressWarnings(as.integer(isolate(graph_materialization_drain_generation()) %||% 0L))
    if (!is.finite(gen) || !identical(gen, expected)) {
      diag_log(
        "MATERIALIZE-DRAIN",
        paste0("stale ack ignored generation=", gen, " expected=", expected),
        id = isolate(graph_materialization_drain_graph())
      )
      return(invisible(FALSE))
    }
    elapsed <- suppressWarnings(as.numeric(ack$elapsedMs %||% NA_real_))
    dom_n <- suppressWarnings(as.integer(ack$domInputCount %||% NA_integer_))
    bound_n <- suppressWarnings(as.integer(ack$boundInputCount %||% NA_integer_))
    id <- isolate(graph_materialization_drain_graph())
    diag_log(
      "MATERIALIZE-DRAIN",
      paste0(
        "ack generation=", gen,
        " elapsed_ms=", if (is.finite(elapsed)) round(elapsed) else "NA",
        " dom_inputs=", if (is.finite(dom_n)) dom_n else "NA",
        " bound_inputs=", if (is.finite(bound_n)) bound_n else "NA"
      ),
      id = id
    )
    graph_materialization_drain_pending(FALSE)
    graph_materialization_drain_graph("")
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    invisible(TRUE)
  }

  observeEvent(input$graph_materialization_browser_drain_ack, {
    handle_graph_materialization_browser_drain_ack(input$graph_materialization_browser_drain_ack)
  }, ignoreInit = TRUE)

  materialization_import_pending_figure_assignment <- function(id) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(invisible(FALSE))

    pending_new <- id %in% isolate(figure_pending_new_imports())
    still_referenced <- id %in% figure_referenced_graph_ids()
    if (isTRUE(pending_new) && isTRUE(still_referenced)) {
      imported <- isTRUE(tryCatch(
        snapshot_ready_graph_for_figure(
          id,
          import_editor_state = TRUE,
          import_reason = "new-assignment-ready",
          reload_editor = FALSE
        ),
        error = function(err) {
          diag_log("FIGURE-SOURCE-SYNC", paste0("new assignment import ERROR: ", conditionMessage(err)), id = id)
          FALSE
        }
      ))
      if (isTRUE(imported)) {
        figure_clear_new_import(id)
        diag_log("FIGURE-SOURCE-SYNC", "materialization READY consumed pending new assignment", id = id)
      }
      return(invisible(imported))
    }

    if (id %in% isolate(figure_requested_ids())) {
      diag_log(
        "FIGURE-SOURCE-SYNC",
        "materialization READY ignored for existing Figure ownership; explicit refresh required",
        id = id
      )
    }
    invisible(FALSE)
  }

  materialization_should_keep_background_ui <- function(id) {
    id <- as.character(id %||% "")[1]
    pending_id <- as.character(isolate(pending_display_graph()) %||% "")[1]

    # Figure and Export read from the server-side materializer API and do not
    # require its disposable browser DOM after READY. The only compatibility
    # path that still needs the per-Graph DOM is an explicit legacy/project
    # display restore waiting to reveal that panel.
    list(
      keep = identical(id, pending_id),
      pending_id = pending_id
    )
  }

  complete_graph_materialization_item <- function(id, queue, source_kind = c("background", "single-editor")) {
    source_kind <- match.arg(source_kind)
    id <- as.character(id %||% "")[1]
    queue <- as.character(queue %||% character(0))
    if (!nzchar(id)) return(invisible(FALSE))

    diag_log("MATERIALIZE", paste0("READY source=", source_kind), id = id)
    update_project_load_lock(id)
    materialization_import_pending_figure_assignment(id)

    q2 <- queue[queue != id]
    graph_materialization_queue(q2)
    graph_materialization_current("")

    evicted_background_ui <- FALSE
    if (identical(source_kind, "background")) {
      hold <- materialization_should_keep_background_ui(id)
      if (isTRUE(hold$keep)) {
        diag_log(
          "MATERIALIZE",
          paste0("READY keep mounted pending_display=", hold$pending_id),
          id = id
        )
      } else if (isTRUE(ui_mounted(id))) {
        evicted_background_ui <- isTRUE(
          evict_graph_source_ui(id, reason = "materialization-ready", force = TRUE)
        )
      }
    }

    if (!length(q2)) {
      graph_materialization_active(FALSE)
      if (isTRUE(isolate(project_load_locked()))) {
        diag_log("MATERIALIZE", "ALL READY")
      } else {
        diag_log("MATERIALIZE", "QUEUE READY")
      }
      complete_project_load_lock("serial materialization queue complete")
    } else if (isTRUE(evicted_background_ui)) {
      # Browser bindings for a removed hidden source UI must drain before the
      # next background source is inserted.
      request_graph_materialization_browser_drain(id)
    } else {
      # No background DOM was removed (for example the persistent single
      # Editor satisfied the request). Advance the serial queue immediately.
      graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    }

    invisible(TRUE)
  }

  prepare_background_source_for_canonical <- function(id, mod) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || is.null(mod)) return(invisible(FALSE))
    if (source_module_revision_is_current(id)) return(invisible(TRUE))

    target_revision <- graph_state_revision_value(id)
    prepared_revision <- suppressWarnings(as.integer(graph_source_sync_target[[id]] %||% -1L))
    if (!identical(prepared_revision, target_revision)) {
      canonical_state <- if (cache_has(id)) cache_get(id) else NULL
      if (!is.list(canonical_state) || !is.function(mod$prepare_restore)) return(invisible(FALSE))

      ok_prepare <- isTRUE(tryCatch(
        mod$prepare_restore(canonical_state, source = "source-materialization"),
        error = function(e) {
          diag_log("MATERIALIZE", paste0("prepare_restore ERROR: ", conditionMessage(e)), id = id)
          FALSE
        }
      ))
      if (!ok_prepare) return(invisible(FALSE))

      graph_source_sync_target[[id]] <- target_revision
      diag_log("SOURCE-LEASE", paste0("RESTORE target_revision=", target_revision), id = id)
    }

    if (is.function(mod$activate)) mod$activate()
    invisible(TRUE)
  }

  accept_background_source_revision <- function(id, mod) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || is.null(mod) || !isTRUE(tryCatch(isolate(mod$ready()), error = function(e) FALSE))) {
      return(FALSE)
    }

    canonical_now <- if (cache_has(id)) cache_get(id) else NULL
    module_now <- tryCatch(
      if (is.function(mod$state)) isolate(mod$state()) else NULL,
      error = function(e) NULL
    )
    matches <- is.list(canonical_now) && is.list(module_now) &&
      identical(graph_render_state(module_now), graph_render_state(canonical_now))
    if (!isTRUE(matches)) {
      diag_log("MATERIALIZE", "READY rejected: module RenderState != canonical", id = id)
      if (exists(id, envir = graph_source_sync_target, inherits = FALSE)) {
        rm(list = id, envir = graph_source_sync_target)
      }
      return(FALSE)
    }

    source_module_claim_revision(id, reason = "materialization-ready")
    TRUE
  }

  materialization_select_current_item <- function(queue) {
    queue <- as.character(queue %||% character(0))
    if (!length(queue)) return(list(id = "", queue = queue))

    current <- as.character(graph_materialization_current() %||% "")[1]
    if (nzchar(current)) {
      id <- current
      if (!id %in% queue) {
        queue <- c(id, queue)
        graph_materialization_queue(queue)
      }
    } else {
      id <- queue[[1]]
      graph_materialization_current(id)
      diag_log("MATERIALIZE", paste0("START remaining=", paste(queue, collapse = ",")), id = id)
      update_project_load_lock(id)
    }
    list(id = id, queue = queue)
  }

  materialization_skip_item <- function(id, queue, reason) {
    id <- as.character(id %||% "")[1]
    diag_log("MATERIALIZE", paste0(reason, "; skip"), id = id)
    graph_materialization_queue(as.character(queue %||% character(0))[as.character(queue %||% character(0)) != id])
    graph_materialization_current("")
    graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
    invisible(FALSE)
  }

  materialization_ensure_background_runtime <- function(id, queue) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id)) return(list(status = "skip", mod = NULL))

    # Phase 1: mount/bind the disposable source UI. Server bookkeeping alone is
    # insufficient; wait for the generation-scoped browser ACK.
    if (!ui_mounted(id)) ensure_graph_ui(id, visible = FALSE)
    if (!browser_ui_ready(id)) {
      request_graph_materialization_ui_mount(id)
      return(list(status = "waiting", mod = NULL))
    }

    # Phase 2: instantiate the read-only source module once. Its server module
    # survives disposable DOM eviction; only the browser subtree is recycled.
    if (!module_exists(id)) {
      instantiate_graph(id, context = "materialization", activate_initial = FALSE)
      if (!module_exists(id)) {
        materialization_skip_item(id, queue, "module missing after instantiate")
        return(list(status = "skip", mod = NULL))
      }
      request_graph_materialization_init_drain(id)
      return(list(status = "waiting", mod = NULL))
    }

    if (!init_drain_ready(id)) {
      request_graph_materialization_init_drain(id)
      return(list(status = "waiting", mod = NULL))
    }

    mod <- modules[[id]]
    if (is.null(mod)) {
      materialization_skip_item(id, queue, "module missing after instantiate")
      return(list(status = "skip", mod = NULL))
    }
    list(status = "ready", mod = mod)
  }

  materialization_restore_background_runtime <- function(id, mod) {
    id <- as.character(id %||% "")[1]
    if (!nzchar(id) || is.null(mod)) return("failed")

    if (!source_module_revision_is_current(id)) {
      if (!isTRUE(prepare_background_source_for_canonical(id, mod))) {
        graph_materialization_active(FALSE)
        graph_materialization_current("")
        fail_project_load_lock(id, "source materialization prepare_restore failed")
        return("failed")
      }
    }

    # These two reads intentionally remain reactive. They are the completion
    # signals that wake the worker after activate() has begun a staged restore.
    failure <- if (is.function(mod$restore_error)) mod$restore_error() else NULL
    if (!is.null(failure)) {
      diag_log("MATERIALIZE", paste0("FAILED; queue paused: ", failure), id = id)
      graph_materialization_active(FALSE)
      graph_materialization_current("")
      fail_project_load_lock(id, failure)
      return("failed")
    }

    ready <- isTRUE(tryCatch(mod$ready(), error = function(e) FALSE))
    if (!ready) return("waiting")
    if (!isTRUE(accept_background_source_revision(id, mod))) {
      graph_materialization_generation(as.integer(isolate(graph_materialization_generation()) %||% 0L) + 1L)
      return("waiting")
    }
    "ready"
  }

  run_graph_materialization_worker <- function() {
    if (!isTRUE(graph_materialization_active())) return(invisible(FALSE))
    if (isTRUE(graph_materialization_drain_pending())) return(invisible(FALSE))
    if (isTRUE(graph_materialization_mount_pending())) return(invisible(FALSE))
    if (isTRUE(graph_materialization_init_pending())) return(invisible(FALSE))

    queue <- graph_materialization_queue()
    if (!length(queue)) {
      graph_materialization_current("")
      graph_materialization_active(FALSE)
      diag_log("MATERIALIZE", "queue complete")
      return(invisible(TRUE))
    }

    item <- materialization_select_current_item(queue)
    id <- item$id
    queue <- item$queue
    if (!nzchar(id)) return(invisible(FALSE))

    # The persistent Editor may become READY after the id entered the queue.
    if (isTRUE(source_graph_ready(id)) && identical(id, graph_single_owner()) && graph_single_ready(id)) {
      complete_graph_materialization_item(id, queue, source_kind = "single-editor")
      return(invisible(TRUE))
    }

    # A background source is reusable only while its canonical revision lease is current.
    if (isTRUE(source_graph_ready(id))) {
      complete_graph_materialization_item(id, queue, source_kind = "background")
      return(invisible(TRUE))
    }

    runtime <- materialization_ensure_background_runtime(id, queue)
    if (!identical(runtime$status, "ready")) return(invisible(FALSE))

    status <- materialization_restore_background_runtime(id, runtime$mod)
    if (!identical(status, "ready")) return(invisible(FALSE))

    complete_graph_materialization_item(id, queue, source_kind = "background")
    invisible(TRUE)
  }

  # Observer wiring only. All materialization phases live in named functions so
  # later cleanup can replace the backend without changing Figure/Export callers.
  observe({
    graph_materialization_generation()
    run_graph_materialization_worker()
  })

