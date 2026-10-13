  # The existing Project close/render gate owns this capture boundary.
  # No additional UI lifecycle, input-origin heuristic or delayed release.
  graph_project_capture_owner <- reactiveVal(NULL)
  graph_project_capture_deferred <- function(generation) {
    gate_open <- isTRUE(graph_single_render_gate())
    owner <- graph_project_capture_owner()
    if (gate_open || !is.list(owner)) return(FALSE)
    identical(as.integer(owner$generation), as.integer(generation)) &&
      identical(as.integer(graph_single_editor_generation()), as.integer(generation)) &&
      identical(as.character(graph_single_owner()), as.character(owner$id))
  }
