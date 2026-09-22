# ============================================================
# Structured category-order contract + UI helper
# ============================================================
# Category values are never serialized into comma-delimited editor text.
# Canonical order branches are character vectors, so category labels may
# contain commas without ambiguity.

graph_normalize_order_state <- function(orders = NULL) {
  out <- list(x = list(), group = list(), display = list(), facet = list())
  if (!is.list(orders)) return(out)
  for (kind in names(out)) {
    branch <- orders[[kind]]
    if (!is.list(branch)) next
    clean <- list()
    for (var_name in names(branch)) {
      raw_vals <- branch[[var_name]]
      if (is.null(raw_vals)) raw_vals <- character(0)
      vals <- as.character(unlist(raw_vals, use.names = FALSE))
      vals <- vals[!is.na(vals)]
      clean[[var_name]] <- unique(vals)
    }
    out[[kind]] <- clean
  }
  out
}

graph_category_order_move <- function(values, index, direction) {
  values <- as.character(values)
  n <- length(values)
  i <- suppressWarnings(as.integer(index)[1])
  d <- suppressWarnings(as.integer(direction)[1])
  if (!n || !is.finite(i) || !is.finite(d) || !d %in% c(-1L, 1L)) return(values)
  j <- i + d
  if (i < 1L || i > n || j < 1L || j > n) return(values)
  tmp <- values[[i]]
  values[[i]] <- values[[j]]
  values[[j]] <- tmp
  values
}

graph_category_order_control <- function(input_id, kind, variable, label, values, help = NULL) {
  values <- as.character(values)
  rows <- lapply(seq_along(values), function(i) {
    tags$div(
      class = "category-order-row",
      tags$span(class = "category-order-index", paste0(i, ".")),
      tags$span(class = "category-order-label", values[[i]], title = values[[i]]),
      tags$button(
        type = "button",
        class = "btn btn-default btn-xs category-order-move",
        `data-index` = i,
        `data-direction` = -1L,
        disabled = if (i <= 1L) "disabled" else NULL,
        title = "1つ上へ",
        `aria-label` = paste0(values[[i]], " を1つ上へ"),
        "↑"
      ),
      tags$button(
        type = "button",
        class = "btn btn-default btn-xs category-order-move",
        `data-index` = i,
        `data-direction` = 1L,
        disabled = if (i >= length(values)) "disabled" else NULL,
        title = "1つ下へ",
        `aria-label` = paste0(values[[i]], " を1つ下へ"),
        "↓"
      )
    )
  })
  tags$div(
    class = "order-box graph-category-order-control",
    `data-input-id` = input_id,
    `data-kind` = as.character(kind)[1],
    `data-variable` = as.character(variable)[1],
    tags$b(label),
    if (!is.null(help) && nzchar(as.character(help)[1])) tags$p(class = "help-block", help),
    tags$div(class = "category-order-list", tagList(rows))
  )
}
