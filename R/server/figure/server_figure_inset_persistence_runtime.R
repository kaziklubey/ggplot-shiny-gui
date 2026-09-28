# Inset assets are independent of Main assets and of other Inset owners.
# Each Main Figure Graph owns at most one Inset, so owner Graph ID is the key.
collect_figure_inset_preview_records <- function() {
  cache <- isolate(figure_inset_preview_cache())
  valid_owners <- as.character(isolate(graph_meta())$id %||% character(0))
  out <- list()
  for (owner_id in intersect(names(cache), valid_owners)) {
    rec <- cache[[owner_id]]
    if (!valid_graph_preview_record(rec)) stop(paste("Invalid Inset snapshot:", owner_id))
    # Plot objects and GraphState are not needed to reproduce this frozen asset.
    out[[owner_id]] <- list(
      svg = rec$svg, meta = rec$meta,
      owner_id = owner_id,
      source_id = as.character(rec$source_id %||% "")[1]
    )
  }
  out
}

write_figure_inset_preview_entries <- function(root, records) {
  entries <- list()
  for (id in names(records)) {
    rec <- records[[id]]
    if (!valid_graph_preview_record(rec)) stop(paste("Invalid Inset snapshot:", id))
    fn <- paste0("figure_inset_", safe_name(id, id), ".svg")
    writeLines(rec$svg, file.path(root, "preview", fn), useBytes = TRUE)
    entries[[id]] <- list(
      file = fn, meta = rec$meta,
      source_id = as.character(rec$source_id %||% "")[1]
    )
  }
  entries
}
