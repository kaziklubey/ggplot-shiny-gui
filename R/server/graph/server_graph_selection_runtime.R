  # One activation owner for startup, creation, switching, and Project restore.

  graph_selection_valid_id <- function(id) {
    id <- as.character(id %||% "")[1]
    nzchar(id) && id %in% isolate(graph_meta())$id
  }

  editor_activation_current <- function(generation, id = NULL) {
    current <- identical(as.integer(isolate(graph_single_editor_generation())), as.integer(generation))
    if (is.null(id)) return(current)
    current && identical(graph_single_owner(), as.character(id)[1])
  }

  editor_activation_supersede <- function(source, target = "") {
    previous <- as.integer(isolate(graph_single_editor_generation()) %||% 0L)
    generation <- previous + 1L
    graph_single_editor_generation(generation)
    graph_single_render_gate(FALSE)
    graph_single_editor_lease(NULL)
    session$sendCustomMessage("graph-editor-activation-owner", list(
      generation = generation, target = as.character(target %||% "")[1]
    ))
    diag_log("EDITOR-ACTIVATION-SUPERSEDE", paste0("old=", previous, " new=", generation,
      " source=", source), id = if (nzchar(target)) target else NULL)
    generation
  }

  request_editor_activation <- function(id, source = "graph-select", new_graph = FALSE,
                                        section_key = "", mode = "replay") {
    id <- as.character(id %||% "")[1]
    if (!graph_selection_valid_id(id)) return(invisible(FALSE))
    owner <- graph_single_owner()
    if (identical(id, owner) && graph_single_ready(id)) {
      show_graph_single_editor(id)
      return(invisible(TRUE))
    }
    if (identical(id, owner) && isTRUE(isolate(graph_single_editor_loading()))) {
      return(invisible(TRUE))
    }
    superseded_inflight <- isTRUE(isolate(graph_single_editor_loading()))
    if (!identical(source, "project-load-state-first") && nzchar(owner) &&
        !identical(owner, id) && graph_single_ready(owner)) {
      # Browser patch and Data Document queues are flushed before the selection
      # event. Commit the accepted working copy while the old lease is valid.
      if (!isTRUE(graph_single_commit("before-supersede"))) {
        diag_log("EDITOR-ACTIVATION-COMMIT-PREVIOUS", "commit failed; activation retained", id = owner)
        return(invisible(FALSE))
      }
      diag_log("EDITOR-ACTIVATION-COMMIT-PREVIOUS", paste0("source=", source), id = owner)
    }
    generation <- editor_activation_supersede(source, id)
    active_graph(id)
    diag_log("EDITOR-ACTIVATION-REQUEST", paste0("generation=", generation,
      " source=", source, " mode=", mode,
      if (nzchar(section_key)) paste0(" section=", section_key) else ""), id = id)
    updateTabsetPanel(session, "workspace_main_tab", selected = "graph_workspace")
    started <- if (identical(mode, "pristine")) {
      isTRUE(graph_single_adopt_pristine_startup(id, generation = generation))
    } else {
      isTRUE(graph_single_load(id, new_graph = isTRUE(new_graph), generation = generation,
        full_replay = isTRUE(new_graph) || superseded_inflight))
    }
    invisible(started)
  }

  activate_graph_editor_target <- request_editor_activation

  request_graph_editor <- function(id, source = "graph-select", new_graph = FALSE, section_key = "") {
    id <- as.character(id %||% "")[1]
    if (!graph_selection_valid_id(id)) return(invisible(FALSE))
    if (project_load_action_blocked("graph-edit", id)) return(invisible(FALSE))
    request_editor_activation(id, source = source, new_graph = new_graph, section_key = section_key)
  }

  resume_graph_workspace <- function() {
    id <- selected_graph_id()
    if (!graph_selection_valid_id(id)) return(invisible(FALSE))

    owner <- graph_single_owner()
    stale_owner <- identical(owner, id) &&
      identical(as.character(isolate(graph_single_editor_mode()) %||% ""), "STALE")

    # Figure -> Graph Apply intentionally invalidates the current Editor owner.
    # Reconcile only that same stale owner. Merely returning to Graph must not
    # replay a different selected Graph.
    if (isTRUE(stale_owner)) {
      diag_log("EDITOR-ACTIVATION", "Graph workspace resumed with stale current owner; canonical resync", id = id)
      request_editor_activation(id, source = "workspace-stale", new_graph = FALSE)
      return(invisible(TRUE))
    }

    if (identical(owner, id) && graph_single_ready(id)) {
      # Figure is a view lifecycle, not a Graph replay. The hidden persistent
      # Editor can still have its dynamic Shared Style checkbox rebound by the
      # browser while Figure is active. Rehydrate only that focused UI from the
      # existing Graph-owned state before showing the Editor again.
      mod <- graph_single_mod()
      if (!is.null(mod) && is.function(mod$refresh_shared_style_binding_ui)) {
        try(mod$refresh_shared_style_binding_ui("workspace-resume"), silent = TRUE)
      }
      show_graph_single_editor(id)
      return(invisible(TRUE))
    }

    # returning to Graph always exposes the selected canonical Graph in
    # the one persistent live Editor.
    request_graph_editor(id, source = "workspace-resume", new_graph = FALSE)
    invisible(TRUE)
  }
