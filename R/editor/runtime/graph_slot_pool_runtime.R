# v4.0-rc8: persistent browser-owned slot pools for level-dependent controls.
#
# The browser owns a stable pool DOM (50 slots by default, growing in chunks of
# 50 and never shrinking during the session). R sends semantic entries only.
# Pool controls are deliberately *not* Shiny input bindings: user changes travel
# through one namespaced event input, so Graph replay never has to bind/flush a
# variable number of per-level inputs.

  graph_slot_pool_contexts <- reactiveValues()

  graph_slot_pool_token <- function(pool, context_key = "") {
    # Pool publication is an imperative replay operation and can run from the
    # startup onFlushed callback, where no reactive consumer is active.
    gen <- suppressWarnings(as.integer(isolate(graph_state_replay_generation()) %||% 0L)[1])
    if (!is.finite(gen)) gen <- 0L
    paste0(gen, "::", as.character(pool %||% "")[1], "::", as.character(context_key %||% "")[1])
  }

  graph_slot_pool_publish <- function(pool, kind, entries = list(), context_key = "", empty_text = "", options = list()) {
    pool <- as.character(pool %||% "")[1]
    kind <- as.character(kind %||% "")[1]
    if (!nzchar(pool) || !nzchar(kind)) return(invisible(FALSE))

    gen <- suppressWarnings(as.integer(isolate(graph_state_replay_generation()) %||% 0L)[1])
    if (!is.finite(gen)) gen <- 0L
    token <- graph_slot_pool_token(pool, context_key)
    entries <- if (is.list(entries)) unname(entries) else list()

    graph_slot_pool_contexts[[pool]] <- list(
      token = token,
      generation = gen,
      context_key = as.character(context_key %||% "")[1],
      keys = vapply(entries, function(x) as.character((x %||% list())$key %||% "")[1], character(1))
    )

    session$sendCustomMessage(
      "graph-slot-pool-config",
      list(
        id = session$ns(paste0(pool, "_pool")),
        pool = pool,
        kind = kind,
        generation = gen,
        contextToken = token,
        entries = entries,
        emptyText = as.character(empty_text %||% "")[1],
        options = options %||% list(),
        chunkSize = 50L
      )
    )
    invisible(TRUE)
  }

  graph_slot_pool_event_valid <- function(evt, pool) {
    if (!is.list(evt)) return(FALSE)
    if (!identical(as.character(evt$pool %||% "")[1], as.character(pool)[1])) return(FALSE)
    ctx <- isolate(graph_slot_pool_contexts[[pool]])
    if (!is.list(ctx)) return(FALSE)
    gen <- suppressWarnings(as.integer(evt$generation %||% NA_integer_)[1])
    current_gen <- suppressWarnings(as.integer(isolate(graph_state_replay_generation()) %||% 0L)[1])
    if (!is.finite(gen) || !is.finite(current_gen) || gen != current_gen) return(FALSE)
    identical(as.character(evt$contextToken %||% "")[1], as.character(ctx$token %||% "")[1])
  }

  graph_slot_pool_event_key_active <- function(evt, pool) {
    ctx <- isolate(graph_slot_pool_contexts[[pool]])
    if (!is.list(ctx)) return(FALSE)
    key <- as.character(evt$key %||% "")[1]
    nzchar(key) && key %in% as.character(ctx$keys %||% character(0))
  }
