# Pure individual-trajectory semantics shared by Line / Bar / Scatter.
# The key distinction is between:
# * subject identity: the ID column;
# * connection direction: one variable that changes within ID;
# * series boundaries: other within-ID variables that coexist at the same
# connection value and therefore describe parallel trajectories;
# * facet boundary: connections never cross panels.
# Visual aesthetics are not series boundaries merely because they are mapped.
# A Color/Shape/Linetype variable may itself be the repeated-measure direction.

graph_individual_connection_clean_vars <- function(data, vars) {
  vars <- unique(as.character(vars %||% character(0)))
  vars[nzchar(vars) & vars %in% names(data)]
}

graph_individual_connection_group_key <- function(data, vars) {
  vars <- graph_individual_connection_clean_vars(data, vars)
  if (!length(vars)) return(rep("__all__", nrow(data)))

  pieces <- lapply(vars, function(v) {
    z <- as.character(data[[v]])
    z[is.na(z)] <- "__NA__"
    z
  })
  if (length(pieces) == 1L) return(pieces[[1]])
  do.call(paste, c(pieces, list(sep = "\r")))
}

graph_individual_varies_within_id <- function(data, idvar, variable, facetvar = "") {
  vars <- graph_individual_connection_clean_vars(data, c(idvar, variable, facetvar))
  if (!is.data.frame(data) || !nrow(data) ||
      !nzchar(idvar) || !idvar %in% names(data) ||
      !nzchar(variable) || !variable %in% names(data)) return(FALSE)

  boundary <- graph_individual_connection_group_key(
    data,
    c(idvar, if (nzchar(facetvar)) facetvar else "")
  )
  value <- as.character(data[[variable]])

  for (key in unique(boundary)) {
    z <- value[boundary == key]
    z <- unique(z[!is.na(z)])
    if (length(z) > 1L) return(TRUE)
  }
  FALSE
}

# TRUE means that, within every ID/facet trajectory, each connection value maps
# to at most one value of `variable`. Such a variable may change along the path
# (e.g. Phase changing deterministically with Time) without defining a separate
# trajectory. FALSE means parallel values coexist at the same connection point
# and the variable must remain a series boundary.
graph_individual_var_determined_by <- function(data, idvar, connection_var,
                                                variable, facetvar = "") {
  if (!is.data.frame(data) || !nrow(data) ||
      !nzchar(idvar) || !idvar %in% names(data) ||
      !nzchar(connection_var) || !connection_var %in% names(data) ||
      !nzchar(variable) || !variable %in% names(data)) return(FALSE)
  if (identical(connection_var, variable)) return(TRUE)

  boundary <- graph_individual_connection_group_key(
    data,
    c(idvar, if (nzchar(facetvar)) facetvar else "", connection_var)
  )
  value <- as.character(data[[variable]])

  for (key in unique(boundary)) {
    z <- value[boundary == key]
    z <- unique(z[!is.na(z)])
    if (length(z) > 1L) return(FALSE)
  }
  TRUE
}


# Resolve the user-facing manual direction role to the currently mapped column.
# The saved value is a stable semantic role rather than a data-dependent column
# name, so GraphState remains valid when mappings/data are changed.
graph_individual_connection_requested_var <- function(direction = "auto",
                                                        xvar = "", positionvar = "",
                                                        colorvar = "", linetypevar = "",
                                                        shapevar = "") {
  direction <- as.character(direction %||% "auto")[1]
  if (is.na(direction) || !direction %in% c("auto", "x", "color", "position", "linetype", "shape")) {
    direction <- "auto"
  }
  if (identical(direction, "auto")) return("")
  out <- switch(
    direction,
    x = xvar,
    color = colorvar,
    position = positionvar,
    linetype = linetypevar,
    shape = shapevar,
    ""
  )
  out <- as.character(out %||% "")[1]
  if (is.na(out)) "" else out
}

graph_individual_connection_plan <- function(data, idvar, facetvar = "",
                                               candidates = character(0),
                                               priority = candidates,
                                               forced_series_vars = character(0),
                                               requested_connection_var = "") {
  empty <- list(
    active = FALSE,
    connection_var = "",
    varying_vars = character(0),
    series_vars = character(0),
    forced_series_vars = character(0),
    requested_connection_var = "",
    connection_source = "none",
    group_vars = character(0),
    repeat_key_vars = character(0)
  )
  if (!is.data.frame(data) || !nrow(data) ||
      !nzchar(idvar) || !idvar %in% names(data)) return(empty)

  candidates <- graph_individual_connection_clean_vars(data, candidates)
  priority <- graph_individual_connection_clean_vars(data, priority)
  priority <- unique(c(priority, candidates))
  forced <- graph_individual_connection_clean_vars(data, forced_series_vars)
  requested <- graph_individual_connection_clean_vars(data, requested_connection_var)
  requested <- if (length(requested)) requested[[1]] else ""

  varying <- candidates[vapply(
    candidates,
    function(v) graph_individual_varies_within_id(data, idvar, v, facetvar),
    logical(1)
  )]

  # Manual direction, when valid, wins even if that variable is normally a
  # forced series boundary (notably Bar's horizontal-position factor). This is
  # the explicit escape hatch for users who intentionally want to connect
  # across that factor. If the selected role is unmapped or does not vary within
  # ID, fall back to the safe automatic rule.
  connection_var <- ""
  connection_source <- "none"
  if (nzchar(requested) && requested %in% varying) {
    connection_var <- requested
    connection_source <- "manual"
  } else {
    # Explicit series boundaries are not eligible as the automatic connection
    # direction. This preserves Line's explicit series modes and Bar slot
    # boundaries while allowing Auto to infer a repeated-measure direction.
    eligible <- setdiff(varying, forced)
    for (v in priority) {
      if (v %in% eligible) {
        connection_var <- v
        connection_source <- "auto"
        break
      }
    }
  }

  auto_series <- character(0)
  if (nzchar(connection_var)) {
    other <- setdiff(varying, connection_var)
    auto_series <- other[!vapply(
      other,
      function(v) graph_individual_var_determined_by(
        data, idvar, connection_var, v, facetvar
      ),
      logical(1)
    )]
  } else {
    auto_series <- varying
  }

  series_vars <- unique(c(forced, auto_series))
  series_vars <- setdiff(series_vars, connection_var)
  facet_boundary <- if (nzchar(facetvar) && facetvar %in% names(data)) facetvar else ""
  group_vars <- unique(c(idvar, facet_boundary, series_vars))
  group_vars <- group_vars[nzchar(group_vars)]

  list(
    active = nzchar(connection_var),
    connection_var = connection_var,
    varying_vars = varying,
    series_vars = series_vars,
    forced_series_vars = forced,
    requested_connection_var = requested,
    connection_source = connection_source,
    group_vars = group_vars,
    repeat_key_vars = unique(c(group_vars, connection_var))
  )
}

# Multiple observations may remain for one ID/series/connection-value cell.
# Pair the first repeat across levels with the first repeat, second with second,
# etc., rather than creating vertical/zig-zag links inside one cell.
graph_individual_repeat_track <- function(data, plan) {
  if (!is.data.frame(data) || !nrow(data)) return(integer(0))
  vars <- graph_individual_connection_clean_vars(data, plan$repeat_key_vars %||% character(0))
  key <- graph_individual_connection_group_key(data, vars)
  out <- integer(nrow(data))
  for (k in unique(key)) {
    idx <- which(key == k)
    out[idx] <- seq_along(idx)
  }
  out
}

# A mapped aesthetic can colour/style one connection layer only when it is
# constant inside each final individual trajectory. If it changes along the
# trajectory, the connector must use the dedicated fixed individual-line style.
graph_individual_group_var_is_constant <- function(data, group_col, variable) {
  if (!is.data.frame(data) || !nrow(data) ||
      !nzchar(group_col) || !group_col %in% names(data) ||
      !nzchar(variable) || !variable %in% names(data)) return(FALSE)
  grp <- as.character(data[[group_col]])
  val <- as.character(data[[variable]])
  for (g in unique(grp[!is.na(grp)])) {
    z <- unique(val[grp == g & !is.na(grp)])
    z <- z[!is.na(z)]
    if (length(z) > 1L) return(FALSE)
  }
  TRUE
}
