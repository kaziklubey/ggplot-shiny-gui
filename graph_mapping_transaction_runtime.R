# Editor-local choices ownership. Replay seeds these exact producer inputs.
# On release, unchanged producers do not enqueue another update batch.
# A subsequent user edit changes the producer input and resumes ordinary updates.
graph_mapping_choice_sources <- new.env(parent = emptyenv())
graph_mapping_choices_changed <- function(kind, source) {
  if (exists(kind, envir = graph_mapping_choice_sources, inherits = FALSE) &&
      identical(graph_mapping_choice_sources[[kind]], source)) return(FALSE)
  graph_mapping_choice_sources[[kind]] <- source
  TRUE
}
graph_mapping_choices_seed <- function(plan) {
  if (!is.list(plan)) return(invisible(NULL))
  graph_mapping_choice_sources$reshape <- plan$raw
  graph_mapping_choice_sources$mapping <- plan$data
  graph_mapping_choice_sources$group <- list(plan$data, plan$color)
  graph_mapping_choice_sources$external <- list(plan$data, plan$y)
  invisible(NULL)
}
