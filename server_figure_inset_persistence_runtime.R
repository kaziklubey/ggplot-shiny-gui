# Inset assets are independent of Main assets, keyed by source Graph ID.
collect_figure_inset_preview_records <- function() {
  refs <- figure_referenced_graph_ids()
  cache <- isolate(figure_inset_preview_cache())
  out <- list()
  for (id in intersect(names(cache), refs)) {
    rec <- cache[[id]]
    if (!valid_graph_preview_record(rec)) stop(paste("Invalid Inset snapshot:", id))
    # Plot objects and GraphState are not needed to reproduce this frozen asset.
    out[[id]] <- list(svg = rec$svg, meta = rec$meta)
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
    entries[[id]] <- list(file = fn, meta = rec$meta)
  }
  entries
}
