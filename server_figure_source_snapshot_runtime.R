# v3.73.2.22: Figure-owned snapshots calculated directly from GraphState.
figure_source_snapshot_queue <- reactiveVal(character(0))
figure_source_snapshot_jobs <- reactiveVal(list())
figure_source_snapshot_active_job <- reactiveVal("")
figure_source_snapshot_generation <- reactiveVal(0L)
figure_source_snapshot_request_counter <- reactiveVal(0L)
figure_source_snapshot_requested <- reactiveValues()
figure_source_snapshot_completed <- reactiveValues()
figure_source_snapshot_succeeded <- reactiveValues()

reset_figure_source_snapshot_service <- function(reason = "reset") {
  figure_source_snapshot_queue(character(0))
  figure_source_snapshot_jobs(list())
  figure_source_snapshot_active_job("")
  requested <- isolate(reactiveValuesToList(figure_source_snapshot_requested))
  completed <- isolate(reactiveValuesToList(figure_source_snapshot_completed))
  for (nm in names(requested)) figure_source_snapshot_requested[[nm]] <- NULL
  for (nm in names(completed)) figure_source_snapshot_completed[[nm]] <- NULL
  for (nm in names(completed)) figure_source_snapshot_succeeded[[nm]] <- NULL
  figure_source_snapshot_generation(as.integer(isolate(figure_source_snapshot_generation()) %||% 0L) + 1L)
  diag_log("FIGURE-SOURCE-QUEUE", paste0("RESET reason=", reason))
  invisible(TRUE)
}

figure_source_snapshot_key <- function(id, target_type = "main", owner_id = NULL) {
  id <- as.character(id %||% "")[1]
  target_type <- as.character(target_type %||% "main")[1]
  if (identical(target_type, "inset")) {
    owner_id <- as.character(owner_id %||% "")[1]
    return(paste("inset", owner_id, id, sep = "|"))
  }
  paste("main", id, sep = "|")
}

figure_source_snapshot_completed_revision <- function(id, target_type = "main", owner_id = NULL) {
  key <- figure_source_snapshot_key(id, target_type, owner_id)
  as.integer(isolate(figure_source_snapshot_completed[[key]] %||% 0L))
}

figure_source_snapshot_success <- function(id, target_type = "main", owner_id = NULL) {
  key <- figure_source_snapshot_key(id, target_type, owner_id)
  isTRUE(isolate(figure_source_snapshot_succeeded[[key]]))
}

figure_source_snapshot_pending <- function(id = NULL) {
  jobs <- isolate(figure_source_snapshot_jobs())
  queued <- isolate(figure_source_snapshot_queue())
  active <- as.character(isolate(figure_source_snapshot_active_job()) %||% "")[1]
  job_ids <- unique(c(active[nzchar(active)], queued))
  if (!length(job_ids)) return(FALSE)
  if (is.null(id)) return(TRUE)
  id <- as.character(id %||% "")[1]
  any(vapply(job_ids, function(job_id) {
    identical(as.character((jobs[[job_id]] %||% list())$id %||% "")[1], id)
  }, logical(1)))
}

figure_source_snapshot_busy <- function(id = NULL) {
  active <- as.character(isolate(figure_source_snapshot_active_job()) %||% "")[1]
  if (!nzchar(active)) return(FALSE)
  if (is.null(id)) return(TRUE)
  job <- isolate(figure_source_snapshot_jobs())[[active]] %||% list()
  identical(as.character(job$id %||% "")[1], as.character(id %||% "")[1])
}

figure_source_snapshot_target_pending <- function(id, target_type = "main", owner_id = NULL) {
  id <- as.character(id %||% "")[1]
  target_type <- as.character(target_type %||% "main")[1]
  owner_id <- as.character(owner_id %||% "")[1]
  if (!nzchar(id)) return(FALSE)

  jobs <- isolate(figure_source_snapshot_jobs())
  queued <- isolate(figure_source_snapshot_queue())
  active <- as.character(isolate(figure_source_snapshot_active_job()) %||% "")[1]
  job_ids <- unique(c(active[nzchar(active)], queued))
  if (!length(job_ids)) return(FALSE)

  any(vapply(job_ids, function(job_id) {
    job <- jobs[[job_id]] %||% list()
    same_owner <- if (identical(target_type, "inset")) {
      identical(as.character(job$owner_id %||% "")[1], owner_id)
    } else TRUE
    identical(as.character(job$id %||% "")[1], id) &&
      identical(as.character(job$target_type %||% "main")[1], target_type) &&
      isTRUE(same_owner)
  }, logical(1)))
}

cancel_figure_source_snapshot_jobs <- function(id, reason = "cancel") {
  id <- as.character(id %||% "")[1]
  if (!nzchar(id)) return(invisible(FALSE))
  jobs <- isolate(figure_source_snapshot_jobs())
  active <- as.character(isolate(figure_source_snapshot_active_job()) %||% "")[1]
  q <- isolate(figure_source_snapshot_queue())
  removed <- character(0)
  for (job_id in names(jobs)) {
    job <- jobs[[job_id]] %||% list()
    if (!identical(as.character(job$id %||% "")[1], id)) next
    if (identical(job_id, active)) {
      job$cancelled <- TRUE
      jobs[[job_id]] <- job
    } else {
      key <- as.character(job$completion_key %||% "")[1]
      rev <- as.integer(job$revision %||% 0L)
      if (nzchar(key)) figure_source_snapshot_completed[[key]] <- rev
      if (nzchar(key)) figure_source_snapshot_succeeded[[key]] <- FALSE
      jobs[[job_id]] <- NULL
      removed <- c(removed, job_id)
    }
  }
  if (length(removed)) q <- setdiff(q, removed)
  figure_source_snapshot_jobs(jobs)
  figure_source_snapshot_queue(q)
  if (length(removed) || (nzchar(active) && isTRUE((jobs[[active]] %||% list())$cancelled))) {
    figure_source_snapshot_generation(as.integer(isolate(figure_source_snapshot_generation()) %||% 0L) + 1L)
    diag_log("FIGURE-SOURCE-QUEUE", paste0("cancel source reason=", reason, " queued=", length(removed)), id = id)
  }
  invisible(TRUE)
}

figure_source_snapshot_next_revision <- function(key) {
  next_rev <- as.integer(isolate(figure_source_snapshot_requested[[key]] %||% 0L)) + 1L
  figure_source_snapshot_requested[[key]] <- next_rev
  next_rev
}

request_figure_source_snapshot <- function(id, reason = "figure-source",
                                           import_editor_state = TRUE,
                                           state_override = NULL,
                                           target_type = "main",
                                           owner_id = NULL) {
  id <- as.character(id %||% "")[1]
  target_type <- match.arg(as.character(target_type %||% "main")[1], c("main", "inset"))
  owner_id <- as.character(owner_id %||% "")[1]
  if (!nzchar(id) || (identical(target_type, "inset") && !nzchar(owner_id))) return(invisible(FALSE))

  # Canonical GraphState is the only source authority. If this id currently owns
  # the persistent Graph Editor, synchronously publish its latest stable state
  # before freezing the direct-state snapshot request.
  if (!is.list(state_override) && identical(id, graph_single_owner()) &&
      !isTRUE(isolate(graph_single_editor_loading())) && graph_single_ready(id)) {
    graph_single_commit(paste0("figure-source:", as.character(reason %||% "snapshot")[1]))
  }

  state <- if (is.list(state_override)) state_override else if (cache_has(id)) cache_get(id) else NULL
  if (!is.list(state)) return(invisible(FALSE))

  if (identical(target_type, "main") && isTRUE(import_editor_state)) {
    invalidate_figure_main_snapshot_for_import(id)
  }

  key <- figure_source_snapshot_key(id, target_type, owner_id)
  revision <- figure_source_snapshot_next_revision(key)
  serial <- as.integer(isolate(figure_source_snapshot_request_counter()) %||% 0L) + 1L
  figure_source_snapshot_request_counter(serial)
  job_id <- paste0("fs", serial)
  jobs <- isolate(figure_source_snapshot_jobs())
  jobs[[job_id]] <- list(
    id = id,
    owner_id = owner_id,
    target_type = target_type,
    import_editor_state = isTRUE(import_editor_state),
    reason = as.character(reason %||% "figure-source")[1],
    state = unserialize(serialize(state, NULL)),
    revision = revision,
    completion_key = key
  )
  figure_source_snapshot_jobs(jobs)
  figure_source_snapshot_queue(c(isolate(figure_source_snapshot_queue()), job_id))
  figure_source_snapshot_generation(as.integer(isolate(figure_source_snapshot_generation()) %||% 0L) + 1L)
  diag_log(
    "FIGURE-SOURCE-QUEUE",
    paste0("queued target=", target_type, " reason=", reason, " revision=", revision),
    id = id
  )
  invisible(revision)
}

request_figure_inset_snapshot <- function(owner_id, source_id, reason = "figure-inset") {
  request_figure_source_snapshot(
    source_id,
    reason = reason,
    import_editor_state = FALSE,
    target_type = "inset",
    owner_id = owner_id
  )
}

figure_source_snapshot_store_inset <- function(job, payload) {
  source_id <- as.character(job$id %||% "")[1]
  owner_id <- as.character(job$owner_id %||% "")[1]
  if (!nzchar(source_id) || !nzchar(owner_id) || !is.list(payload)) return(FALSE)
  rec <- tryCatch(
    graph_preview_record_from_plot(
      id = source_id,
      state = job$state,
      plot = payload$plot,
      export_meta = payload$meta,
      render_revision = payload$render_revision %||% NA_integer_,
      reason = "figure-inset-explicit-refresh"
    ),
    error = function(e) NULL
  )
  if (is.null(rec) || !isTRUE(valid_graph_preview_record(rec))) return(FALSE)
  rec$figure_plot <- payload$plot
  rec$figure_export <- payload$meta
  rec$figure_components <- payload$components
  cache <- isolate(figure_inset_preview_cache())
  cache[[source_id]] <- rec
  figure_inset_preview_cache(cache)
  bump_figure_snapshot_revision(source_id)
  diag_log(
    "FIGURE-INSET",
    paste0("direct state snapshot owner=", owner_id, " source=", source_id,
           " chars=", nchar(rec$svg %||% "")),
    id = owner_id
  )
  TRUE
}

figure_source_snapshot_finish_job <- function(job_id, ok) {
  jobs <- isolate(figure_source_snapshot_jobs())
  job <- jobs[[job_id]] %||% list()
  key <- as.character(job$completion_key %||% "")[1]
  rev <- as.integer(job$revision %||% 0L)
  if (nzchar(key)) figure_source_snapshot_completed[[key]] <- rev
  if (nzchar(key)) figure_source_snapshot_succeeded[[key]] <- isTRUE(ok)
  jobs[[job_id]] <- NULL
  figure_source_snapshot_jobs(jobs)
  figure_source_snapshot_active_job("")
  figure_source_snapshot_generation(as.integer(isolate(figure_source_snapshot_generation()) %||% 0L) + 1L)
  invisible(ok)
}

figure_source_snapshot_run_job <- function(job) {
  if (isTRUE(job$cancelled)) return(FALSE)
  payload <- graph_state_figure_snapshot(job$state)
  if (identical(job$target_type, "inset")) {
    return(isTRUE(figure_source_snapshot_store_inset(job, payload)))
  }
  ok <- isTRUE(snapshot_ready_figure_editor(job$id, job$state, payload = payload))
  if (ok) {
    if (isTRUE(job$import_editor_state)) {
      seed_figure_editor_from_source(job$id, job$state, reason = job$reason, reload_editor = TRUE)
    }
    figure_clear_new_import(job$id)
  }
  ok
}

figure_source_snapshot_start_next <- function() {
  active <- as.character(isolate(figure_source_snapshot_active_job()) %||% "")[1]
  if (nzchar(active)) return(invisible(FALSE))
  q <- isolate(figure_source_snapshot_queue())
  if (!length(q)) return(invisible(FALSE))
  job_id <- q[[1]]
  figure_source_snapshot_queue(q[-1])
  job <- isolate(figure_source_snapshot_jobs())[[job_id]]
  figure_source_snapshot_active_job(job_id)
  ok <- FALSE
  on.exit(figure_source_snapshot_finish_job(job_id, ok), add = TRUE)
  ok <- tryCatch(isTRUE(figure_source_snapshot_run_job(job)), error = function(e) {
    diag_log("FIGURE-SOURCE-SNAPSHOT", paste0("ERROR: ", conditionMessage(e)), id = job$id)
    FALSE
  })
  diag_log("FIGURE-SOURCE-SNAPSHOT",
    paste0(if (ok) "READY" else "FAILED", " path=DIRECT-STATE target=", job$target_type,
           " reason=", job$reason, " revision=", job$revision), id = job$id)
  invisible(ok)
}

observe({
  figure_source_snapshot_generation()
  figure_source_snapshot_start_next()
})
