# v3.73.2.7: explicit state boundaries for the one persistent Graph Editor.
#
# The outer persistent-Editor transaction owns Graph switching and READY
# arbitration. Once that transaction opens render_gate, the attached canonical
# GraphState has already been accepted. Plot revision therefore releases that
# accepted target directly; it does not perform a second browser-state gate.
# Live project_settings() is used only for ordinary READY user edits.

is_shiny_control_condition <- function(e) {
  inherits(e, "shiny.silent.error") || inherits(e, "validation")
}

graph_live_project_state_snapshot <- function(context = "runtime", log_non_shiny_error = TRUE) {
  snapshot_error <- NULL
  state_now <- tryCatch(
    project_settings(),
    error = function(e) {
      snapshot_error <<- e
      NULL
    }
  )

  if (is.list(state_now)) return(state_now)

  if (!is.null(snapshot_error) &&
      !is_shiny_control_condition(snapshot_error) &&
      isTRUE(log_non_shiny_error)) {
    diag(
      "STATE-SNAPSHOT",
      paste0(
        "context=", context,
        " source=live-browser unavailable error=", conditionMessage(snapshot_error)
      )
    )
  }

  NULL
}

graph_editor_arbitration_state_snapshot <- function(context = "runtime") {
  state_now <- graph_live_project_state_snapshot(
    context = context,
    log_non_shiny_error = TRUE
  )
  if (is.list(state_now)) return(state_now)

  fallback <- isolate(attached_state_seed())
  if (is.list(fallback)) {
    diag(
      "STATE-SNAPSHOT",
      paste0("context=", context, " source=attached-canonical-fallback")
    )
    return(fallback)
  }

  NULL
}

graph_seed_render_target <- function(state, reason = "attach") {
  if (!is.list(state)) return(invisible(FALSE))
  plot_build_render_state(graph_render_state(state))
  plot_build_pending(TRUE)
  diag("PLOT-TARGET", paste0("seed reason=", reason))
  invisible(TRUE)
}

graph_accept_attached_canonical <- function(state, reason = "outer-ready-accept", seed_render = TRUE) {
  if (!is.list(state)) return(invisible(FALSE))
  # The outer transaction is the single canonical acceptance boundary.  Once
  # accepted, update both module-local representations together so the first
  # render cannot use an older pre-acceptance attachment (for example the
  # provisional startup Mapping defaults).
  stable <- tryCatch(unserialize(serialize(state, NULL, version = 3)),
                     error = function(e) state)
  attached_state_seed(stable)
  if (isTRUE(seed_render)) {
    graph_seed_render_target(stable, reason = reason)
  } else {
    diag("PLOT-TARGET", paste0("attach-only reason=", reason, " render=coalesced"))
  }
  invisible(TRUE)
}

graph_release_render_revision <- function(state_now, reason = "live") {
  if (!is.list(state_now)) return(invisible(FALSE))

  rs_now <- graph_render_state(state_now)
  rs_old <- isolate(plot_build_render_state())
  pending <- isTRUE(isolate(plot_build_pending()))
  changed <- is.null(rs_old) || !graph_render_payload_equal(rs_old, rs_now)
  paths <- if (!isTRUE(changed) || is.null(rs_old)) {
    character(0)
  } else {
    app_state_diff_paths(rs_old, rs_now)
  }

  if (isTRUE(changed)) plot_build_render_state(rs_now)
  if (!isTRUE(changed) && !isTRUE(pending)) return(invisible(FALSE))

  target_state <- if (isTRUE(changed)) rs_now else isolate(plot_build_render_state())
  built_state <- isolate(plot_last_built_render_state())
  current_rev <- as.integer(isolate(plot_build_revision()) %||% 0L)
  success_rev <- suppressWarnings(as.integer(isolate(plot_last_success_revision())))
  reusable_current_plot <- !is.null(built_state) && graph_render_payload_equal(built_state, target_state) &&
    is.finite(success_rev) && identical(success_rev, current_rev)

  if (isTRUE(reusable_current_plot)) {
    plot_build_pending(FALSE)
    diag(
      "PLOT-REVISION",
      paste0("READY reuse-hit render_state_unchanged; revision not advanced source=", reason)
    )
    return(invisible(TRUE))
  }

  next_rev <- current_rev + 1L
  plot_build_revision(next_rev)
  plot_build_pending(FALSE)
  diag(
    "PLOT-REVISION",
    paste0(
      "revision=", next_rev,
      " source=", reason,
      if (isTRUE(pending) && !isTRUE(changed)) " release=pending-final" else "",
      if (length(paths)) paste0(
        " paths={", paste(head(paths, 16L), collapse = ","),
        if (length(paths) > 16L) ",..." else "", "}"
      ) else if (is.null(built_state)) " initial=TRUE" else ""
    )
  )
  invisible(TRUE)
}

graph_release_attached_render_target <- function(reason = "accepted-canonical") {
  target <- isolate(attached_state_seed())
  if (!is.list(target)) return(invisible(FALSE))
  graph_release_render_revision(target, reason = reason)
}

install_graph_render_revision_runtime <- function() {
  # Graph attach transaction: release the already accepted canonical target
  # exactly once when the outer gate opens. This observer intentionally does
  # not own ordinary live-edit invalidation.
  observe({
    # The normal persistent Graph Editor owns accepted-canonical auto release
    # through its outer render gate. The controls-only Figure Editor has no
    # equivalent outer gate; its replay completion observer in server.R owns
    # the single post-browser-barrier release instead. Letting both paths own
    # release would consume the pending target before Figure input replay has
    # finished and can render once from the previous owner's browser values.
    if (!graph_editor_profile_has(editor_profile, "full_shell")) return()

    gate_open <- isTRUE(render_gate())
    pending <- isTRUE(plot_build_pending())
    if (!isTRUE(gate_open) || !isTRUE(pending)) return()
    graph_release_attached_render_target("accepted-canonical")
  }, priority = 110)

  # RC13: ordinary live edits are rendered from the already-debounced canonical
  # commit boundary in graph_state_runtime.R.  That boundary updates
  # attached_state_seed() first, then releases one render revision.  Keeping a
  # second immediate project_settings() observer here would rebuild for every
  # numeric spinner/color step and could draw from the pre-commit attachment.
  # Graph/Figure attach transactions remain immediate through the pending-target
  # observer above.

  invisible(TRUE)
}
