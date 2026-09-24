# v4 architecture: profile-owned state overlay.
# A Figure controls editor never reconstructs protected GraphState fields from
# absent browser inputs. It starts from its attached canonical/Figure-owned state
# and replaces only sections explicitly owned by its profile.

graph_state_clone <- function(x) {
  if (!is.list(x)) return(x)
  tryCatch(unserialize(serialize(x, NULL, version = 3)), error = function(e) x)
}

graph_state_overlay_for_profile <- function(base_state, live_state, profile) {
  if (!is.list(live_state)) return(graph_state_clone(base_state))
  if (graph_editor_profile_has(profile, "full_shell")) return(live_state)

  out <- if (is.list(base_state)) graph_state_clone(base_state) else list()
  owned <- as.character(profile$editable_state %||% character(0))
  for (key in owned) {
    if (!is.null(live_state[[key]])) out[[key]] <- live_state[[key]]
  }

  # Shared Library binding metadata belongs to the source Graph/project even
  # though concrete appearance lives inside style. Figure Controls may edit the
  # concrete style but must not synthesize or erase this non-UI binding.
  if (graph_editor_profile_is_figure(profile) && is.list(base_state$style)) {
    if (!is.list(out$style)) out$style <- list()
    out$style$shared_library <- base_state$style$shared_library %||% NULL
  }

  # App/schema metadata may advance without changing field ownership.
  if (!is.null(live_state$version)) out$version <- live_state$version
  if (!is.null(live_state$schema_version)) out$schema_version <- live_state$schema_version
  if (!is.null(live_state$app)) out$app <- live_state$app
  out
}
