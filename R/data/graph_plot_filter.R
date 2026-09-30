# Pure Plot Filter contract. Input data and GraphState are never mutated.
GRAPH_PLOT_FILTER_CHECKBOX_LIMIT <- 12L

graph_plot_filter_default <- function() list(enabled = FALSE, rules = list())

graph_plot_filter_normalize <- function(x) {
  if (!is.list(x)) return(graph_plot_filter_default())
  rules <- x$rules
  if (!is.list(rules)) rules <- list()
  rules <- lapply(rules, function(r) {
    if (!is.list(r)) return(NULL)
    column <- as.character(r$column %||% "")[1]
    if (is.na(column) || !nzchar(column)) return(NULL)
    kind <- as.character(r$kind %||% "categorical")[1]
    if (!kind %in% c("numeric", "date", "datetime", "time", "categorical")) kind <- "categorical"
    op <- as.character(r$op %||% "inside")[1]
    if (!op %in% c("gt", "gte", "lt", "lte", "inside", "outside")) op <- "inside"
    mode_raw <- as.character(r$mode %||% "")[1]
    mode <- if (identical(kind, "categorical")) {
      "values"
    } else if (kind %in% c("numeric", "time") && mode_raw %in% c("compare", "values", "combined")) {
      mode_raw
    } else {
      "compare"
    }
    list(column = column, kind = kind, mode = mode, op = op,
         a = as.character(r$a %||% "")[1], b = as.character(r$b %||% "")[1],
         values = unique(as.character(unlist(r$values %||% character(), use.names = FALSE))),
         include_na = isTRUE(r$include_na))
  })
  rules <- Filter(Negate(is.null), rules)
  # One rule per column; each column rule can itself combine range/comparison
  # and discrete-value narrowing. Different columns remain AND conditions.
  if (length(rules)) rules <- rules[!duplicated(vapply(rules, `[[`, "", "column"))]
  list(enabled = isTRUE(x$enabled), rules = unname(rules))
}

graph_plot_filter_kind <- function(x) {
  if (inherits(x, "POSIXt")) return("datetime")
  if (inherits(x, "Date")) return("date")
  if (inherits(x, "difftime")) return("time")
  if (is.numeric(x)) return("numeric")
  if (is.factor(x)) return("categorical")
  z <- as.character(x)
  z <- z[!is.na(z) & nzchar(trimws(z))]
  if (!length(z)) return("categorical")
  if (all(grepl("^\\d{4}-\\d{2}-\\d{2}$", z, perl = TRUE)) &&
      all(!is.na(as.Date(z, format = "%Y-%m-%d"))) &&
      all(format(as.Date(z, format = "%Y-%m-%d"), "%Y-%m-%d") == z)) return("date")
  if (all(grepl("^\\d{4}-\\d{2}-\\d{2}[ T]\\d{2}:\\d{2}(:\\d{2})?(Z|[+-]\\d{2}:\\d{2})?$", z, perl = TRUE))) {
    parsed <- graph_plot_filter_parse(z, "datetime")
    if (all(!is.na(parsed))) return("datetime")
  }
  if (all(grepl("^([01]\\d|2[0-3]):[0-5]\\d(:[0-5]\\d)?$", z, perl = TRUE))) return("time")
  "categorical"
}

graph_plot_filter_parse <- function(x, kind) {
  z <- as.character(x)
  if (identical(kind, "numeric")) {
    valid <- !is.na(z) & grepl("^[+-]?(\\d+\\.?\\d*|\\.\\d+)([eE][+-]?\\d+)?$", z, perl = TRUE)
    out <- rep(NA_real_, length(z))
    out[valid] <- as.numeric(z[valid])
    return(out)
  }
  if (identical(kind, "date")) {
    y <- as.Date(z, format = "%Y-%m-%d")
    bad <- is.na(z) | is.na(y) | (!is.na(y) & format(y, "%Y-%m-%d") != z)
    y[bad] <- as.Date(NA)
    return(as.numeric(y))
  }
  if (identical(kind, "time")) {
    valid <- grepl("^([01]\\d|2[0-3]):[0-5]\\d(:[0-5]\\d)?$", z, perl = TRUE)
    out <- rep(NA_real_, length(z))
    parts <- strsplit(z[valid & !is.na(z)], ":", fixed = TRUE)
    out[valid & !is.na(z)] <- vapply(parts, function(p) sum(as.numeric(p) * c(3600, 60, 1)[seq_along(p)]), numeric(1))
    return(out)
  }
  if (identical(kind, "datetime")) {
    # ISO values only. Explicit offset/Z is converted to UTC; naive values use UTC.
    z <- sub("T", " ", z, fixed = TRUE)
    z <- sub("Z$", "+00:00", z)
    has_offset <- grepl("[+-]\\d{2}:\\d{2}$", z, perl = TRUE)
    offset <- rep(0, length(z))
    offset[has_offset] <- vapply(substring(z[has_offset], nchar(z[has_offset]) - 5L), function(s) {
      sign <- if (substr(s, 1, 1) == "+") 1 else -1
      sign * (as.numeric(substr(s, 2, 3)) * 3600 + as.numeric(substr(s, 5, 6)) * 60)
    }, numeric(1))
    z <- sub("[+-]\\d{2}:\\d{2}$", "", z, perl = TRUE)
    z <- trimws(z)
    valid <- grepl("^\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}(:\\d{2})?$", z, perl = TRUE)
    out <- rep(NA_real_, length(z))
    if (any(valid & !is.na(z))) {
      ix <- which(valid & !is.na(z))
      normalized <- ifelse(nchar(z[ix]) == 16L, paste0(z[ix], ":00"), z[ix])
      parsed <- as.POSIXct(normalized, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")
      ok <- !is.na(parsed) & format(parsed, "%Y-%m-%d %H:%M:%S", tz = "UTC") == normalized
      out[ix[ok]] <- as.numeric(parsed[ok]) - offset[ix[ok]]
    }
    return(out)
  }
  rep(NA_real_, length(z))
}

graph_plot_filter_compare_pass <- function(x, r) {
  # A newly added comparison is inactive until the user enters its bounds.
  if (!nzchar(trimws(r$a)) || (r$op %in% c("inside", "outside") && !nzchar(trimws(r$b)))) return(NULL)
  values <- graph_plot_filter_parse(if (inherits(x, "POSIXt")) format(x, "%Y-%m-%d %H:%M:%S", tz = "UTC") else x, r$kind)
  a <- graph_plot_filter_parse(r$a, r$kind)[1]
  b <- graph_plot_filter_parse(r$b, r$kind)[1]
  pass <- rep(FALSE, length(values))
  if (!is.na(a)) {
    pass <- switch(r$op,
      gt = values > a, gte = values >= a, lt = values < a, lte = values <= a,
      inside = if (!is.na(b)) {
        if (r$kind == "time" && a > b) values >= a | values <= b else values >= a & values <= b
      } else pass,
      outside = if (!is.na(b)) {
        if (r$kind == "time" && a > b) values < a & values > b else values < a | values > b
      } else pass, pass)
  }
  pass[is.na(pass)] <- FALSE
  pass
}

graph_plot_filter_apply <- function(data, filter) {
  stopifnot(is.data.frame(data))
  filter <- graph_plot_filter_normalize(filter)
  if (!filter$enabled || !length(filter$rules)) return(data)
  keep <- rep(TRUE, nrow(data))
  for (r in filter$rules) {
    if (!r$column %in% names(data)) next
    x <- data[[r$column]]
    missing <- is.na(x)

    pass <- rep(TRUE, length(x))
    active <- FALSE

    if (r$mode %in% c("values", "combined")) {
      # Empty values is an intentional "select none" state once the value
      # constraint is active. This is distinct from a comparison-only legacy rule.
      pass <- pass & (!missing & as.character(x) %in% r$values)
      active <- TRUE
    }

    if (r$mode %in% c("compare", "combined")) {
      cmp <- graph_plot_filter_compare_pass(x, r)
      if (!is.null(cmp)) {
        pass <- pass & cmp
        active <- TRUE
      }
    }

    if (!active) next
    pass[missing] <- r$include_na
    keep <- keep & pass
  }
  droplevels(data[keep, , drop = FALSE])
}

graph_plot_filter_transition <- function(filter, event, data) {
  f <- graph_plot_filter_normalize(filter)
  action <- as.character(event$action %||% "")[1]
  column <- as.character(event$column %||% "")[1]
  if (action == "enabled") f$enabled <- isTRUE(event$value)
  if (action == "add" && column %in% names(data) &&
      !column %in% vapply(f$rules, `[[`, "", "column")) {
    kind <- graph_plot_filter_kind(data[[column]])
    values <- unique(as.character(data[[column]][!is.na(data[[column]])]))
    mode <- if (identical(kind, "categorical")) "values" else if (kind %in% c("numeric", "time")) "combined" else "compare"
    f$rules[[length(f$rules) + 1L]] <- list(column = column, kind = kind, mode = mode, op = "inside",
      a = "", b = "", values = values, include_na = FALSE)
  }
  idx <- match(column, vapply(f$rules, `[[`, "", "column"))
  if (!is.na(idx) && action == "remove") f$rules[[idx]] <- NULL
  if (!is.na(idx) && action == "set") {
    field <- as.character(event$field %||% "")[1]
    if (field %in% c("mode", "op", "a", "b", "values", "include_na")) {
      r <- f$rules[[idx]]
      r[[field]] <- if (field == "include_na") isTRUE(event$value) else
        if (field == "values") as.character(unlist(event$value %||% character(), use.names = FALSE)) else
          as.character(event$value %||% "")[1]
      # Numeric/time rules can combine exact-value narrowing with a range in one
      # card. Preserve old compare/value-only saved rules until the user edits the
      # other side; new rules already start in combined mode.
      if (r$kind %in% c("numeric", "time")) {
        if (identical(field, "values") && !identical(r$mode, "combined")) r$mode <- "combined"
        if (field %in% c("op", "a", "b") && identical(r$mode, "values")) r$mode <- "combined"
      }
      f$rules[[idx]] <- r
    }
  }
  graph_plot_filter_normalize(f)
}
