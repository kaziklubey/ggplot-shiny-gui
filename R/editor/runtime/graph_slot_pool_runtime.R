  # persistent browser-owned slot pools for level-dependent controls.
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
    # One derived owner: this signature represents the last display accepted
    # for this persistent pool, never a second GraphState tree or data cache.
    signature <- serialize(list(kind = kind, entries = entries,
      context_key = as.character(context_key %||% "")[1],
      empty_text = as.character(empty_text %||% "")[1], options = options %||% list()),
      NULL, version = 3)
    old <- isolate(graph_slot_pool_contexts[[pool]])
    unchanged <- is.list(old) && identical(old$display_signature, signature)

    graph_slot_pool_contexts[[pool]] <- list(
      token = token,
      generation = gen,
      context_key = as.character(context_key %||% "")[1],
      display_signature = signature,
      keys = vapply(entries, function(x) as.character((x %||% list())$key %||% "")[1], character(1))
    )

    if (unchanged) return(invisible(FALSE))
    graph_cold_diag_record("slot-pool-publish", detail = pool)

    session$sendCustomMessage(
      "graph-slot-pool-config",
      list(
        id = session$ns(paste0(pool, "_pool")),
        pool = pool,
        kind = kind,
        generation = gen,
        activationGeneration = as.integer(isolate(graph_editor_activation_generation()) %||% 0L),
        contextToken = token,
        entries = entries,
        emptyText = as.character(empty_text %||% "")[1],
        options = options %||% list(),
        chunkSize = 50L
      )
    )
    invisible(TRUE)
  }

  # The existing hydration transaction advances the lease even for content
  # skips. No per-pool ACK/message/DOM rebuild is needed to reject old events.
  graph_slot_pool_replay_contexts <- function() {
    out <- list()
    for (pool in graph_slot_pool_names()) {
      ctx <- isolate(graph_slot_pool_contexts[[pool]])
      if (!is.list(ctx)) next
      ctx$generation <- as.integer(isolate(graph_state_replay_generation()))
      ctx$token <- graph_slot_pool_token(pool, ctx$context_key)
      graph_slot_pool_contexts[[pool]] <- ctx
      out[[pool]] <- list(id = session$ns(paste0(pool, "_pool")),
        generation = ctx$generation, contextToken = ctx$token)
    }
    out
  }

  graph_slot_pool_publish_spec <- function(pool, cfg, data) {
    t0 <- proc.time()[["elapsed"]]
    spec <- graph_slot_pool_spec(pool, cfg, data)
    published <- do.call(graph_slot_pool_publish, c(list(pool = pool), spec))
    if (isTRUE(getOption("ggplot.gui.style_pool_diag", FALSE)) && isTRUE(isolate(graph_state_replay_active()))) {
      diag("STATE-REPLAY-TIMING", paste0("phase=slot-pool name=", pool,
        " action=", if (isTRUE(published)) "publish" else "skip",
        " work_ms=", round((proc.time()[["elapsed"]] - t0) * 1000, 1),
        " reason=", if (isTRUE(published)) "display-changed" else "display-identical"))
    }
    invisible(published)
  }

  graph_slot_pool_live_config <- function() {
    d <- dat()
    # Scalars are browser-accepted Graph/Figure values, not delayed input mirrors.
    cfg <- list(mapping = list(x = graph_mapping_value("x", input$xvar %||% ""),
      color = resolve_color_var(d), linetype = resolve_linetype_var(d),
      shape = resolve_shape_var(d), position = effective_position_var(d)),
      plot = list(type = graph_plot_value("type", input$plot_type %||% "line")))
    list(state = cfg, data = d)
  }

  graph_slot_pool_live_publish <- function(pool) {
    live <- graph_slot_pool_live_config()
    st <- list(orders = order_state())
    if (identical(pool, "color_style")) {
      st$color_styles <- color_styles()
      st$fill_none_styles <- fill_none_styles()
    } else if (identical(pool, "linetype_style")) st$linetype_styles <- linetype_styles()
    else if (identical(pool, "shape_style")) st$shape_styles <- shape_styles()
    else {
      st$color_styles <- color_styles()
      st$series_styles <- series_styles()
      st$appearance <- list(series_style_override = graph_appearance_value("series_style_override", input$series_style_override))
      if (identical(pool, "raw_group_color")) {
        st$raw_group_colors <- raw_group_colors()
        st$level_labels <- level_labels()
      }
    }
    live$state$style <- st
    graph_slot_pool_publish_spec(pool, live$state, live$data)
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
