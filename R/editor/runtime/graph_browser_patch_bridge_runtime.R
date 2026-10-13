  # PoC — bridge between browser-owned working values and the existing
  # graphServer runtime. Browser values are never canonical here: the outer
  # server owns the canonical GraphState and exposes only accepted overrides.

  if (is.null(browser_patch_override) || !is.function(browser_patch_override)) {
    browser_patch_override <- function() NULL
  }

  graph_browser_patch_override_snapshot <- function() {
    out <- tryCatch(browser_patch_override(), error = function(e) NULL)
    if (!is.list(out) || !isTRUE(out$active) || !is.list(out$values)) return(NULL)
    out
  }

  graph_apply_browser_patch_overlay <- function(state, sections = NULL) {
    if (!is.list(state)) return(state)
    ov <- graph_browser_patch_override_snapshot()
    if (is.null(ov)) return(state)

    set_path <- function(node, path, value) {
      parts <- strsplit(as.character(path %||% "")[1], ".", fixed = TRUE)[[1]]
      if (!length(parts) || any(!nzchar(parts))) return(node)
      put <- function(x, rest) {
        if (!is.list(x)) x <- list()
        key <- rest[[1]]
        if (length(rest) == 1L) { x[key] <- list(value); return(x) }
        x[key] <- list(put(x[[key]] %||% list(), rest[-1]))
        x
      }
      put(node, parts)
    }
    paths <- ov$paths %||% list()
    keys <- intersect(names(ov$values), names(paths))
    # Scope by GraphState ownership, not startup state. The shared builder must
    # not materialize Data/reshape/UI sections owned by the final full capture.
    if (!is.null(sections)) {
      keys <- keys[vapply(keys, function(nm)
        strsplit(as.character(paths[[nm]]), ".", fixed=TRUE)[[1]][[1]] %in% sections,
        logical(1))]
    }
    for (nm in keys) {
      state <- set_path(state, paths[[nm]], ov$values[[nm]])
    }
    state
  }


  graph_apply_browser_patch_style_overlay <- function(style) {
    if (!is.list(style)) return(style)
    ov <- graph_browser_patch_override_snapshot()
    if (is.null(ov)) return(style)
    if (!is.list(style$appearance)) style$appearance <- list()
    paths <- ov$paths %||% list()
    for (nm in intersect(names(ov$values), names(paths))) {
      path <- as.character(paths[[nm]] %||% "")[1]
      if (!startsWith(path, "style.appearance.")) next
      key <- sub("^style\\.appearance\\.", "", path)
      if (nzchar(key) && !grepl("\\.", key)) style$appearance[[key]] <- ov$values[[nm]]
    }
    style
  }


  graph_browser_owned_state <- function() {
    state <- tryCatch(attached_state_seed(), error = function(e) NULL)
    if (!is.list(state)) return(NULL)
    if (graph_editor_profile_is_figure(editor_profile)) {
      state <- graph_apply_browser_patch_overlay(state)
    }
    state
  }

  graph_state_path_value <- function(state, path, fallback = NULL) {
    if (!is.list(state)) return(fallback)
    parts <- strsplit(as.character(path %||% "")[1], ".", fixed = TRUE)[[1]]
    if (!length(parts) || any(!nzchar(parts))) return(fallback)
    cur <- state
    for (key in parts) {
      if (!is.list(cur) || !key %in% (names(cur) %||% character(0))) return(fallback)
      cur <- cur[[key]]
    }
    if (is.null(cur)) fallback else cur
  }

  # Browser-direct controls deliberately do not update the server-side Shiny
  # input mirror. Any R-side derived UI/action/runtime read therefore has to
  # resolve the accepted canonical GraphState (or Figure-owned working overlay)
  # first. `input$...` is only a startup/non-browser fallback here.
  # One context per accepted working state, rather than rebuilding the entire
  # control/path catalog for each scalar read. Shiny owns invalidation through
  # the existing canonical and Figure-overlay dependencies; no manual cache.
  graph_browser_owned_read_context <- reactive({
    state <- graph_browser_owned_state()
    list(state = state,
      paths = if (is.list(state)) graph_browser_input_paths(state) else character())
  })

  graph_browser_owned_value <- function(key, fallback = NULL) {
    key <- as.character(key %||% "")[1]
    if (!nzchar(key)) return(fallback)
    if (!graph_editor_profile_has(editor_profile, "full_shell") &&
        !graph_editor_profile_is_figure(editor_profile)) return(fallback)
    context <- graph_browser_owned_read_context()
    state <- context$state
    if (!is.list(state)) return(fallback)
    paths <- context$paths
    if (!key %in% names(paths)) return(fallback)
    graph_state_path_value(state, paths[[key]], fallback)
  }

  graph_browser_owned_scalar <- function(key, fallback = NULL) {
    value <- graph_browser_owned_value(key, fallback)
    if (is.null(value) || !length(value)) return(fallback)
    value[[1]]
  }
