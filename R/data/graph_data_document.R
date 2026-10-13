# Canonical Data Document helpers.
#
# The persistent Ace editor is only a view onto one Graph-owned document lease.
# Browser events carry graph_id / generation / seq explicitly; server code never
# infers Data ownership from whichever Graph happens to be selected when an
# event arrives.
#
# `data_text` remains the last successfully parsed canonical data source used by
# Plot/reshape/Statistics for backward compatibility. `data_document$source_text`
# is the user's latest draft and may temporarily be invalid without being lost.

graph_data_document_default <- function(data_text = "") {
  txt <- as.character(data_text %||% "")[1]
  if (is.na(txt)) txt <- ""
  list(
    schema_version = 1L,
    source_text = txt,
    source_revision = 0L,
    parsed_revision = 0L,
    parse_status = "valid",
    parse_error = ""
  )
}

graph_data_document_normalize <- function(x = NULL, data_text = "") {
  fallback <- as.character(data_text %||% "")[1]
  if (is.na(fallback)) fallback <- ""
  if (!is.list(x)) x <- list()

  source_text <- as.character(graph_state_scalar(x$source_text, fallback) %||% fallback)[1]
  if (is.na(source_text)) source_text <- fallback

  source_revision <- suppressWarnings(as.integer(graph_state_scalar(x$source_revision, 0L)))
  if (!is.finite(source_revision) || source_revision < 0L) source_revision <- 0L
  parsed_revision <- suppressWarnings(as.integer(graph_state_scalar(x$parsed_revision, 0L)))
  if (!is.finite(parsed_revision) || parsed_revision < 0L) parsed_revision <- 0L
  if (parsed_revision > source_revision) parsed_revision <- source_revision

  status <- as.character(graph_state_scalar(x$parse_status, "valid") %||% "valid")[1]
  if (!status %in% c("valid", "invalid")) status <- "valid"
  parse_error <- as.character(graph_state_scalar(x$parse_error, "") %||% "")[1]
  if (is.na(parse_error)) parse_error <- ""

  list(
    schema_version = 1L,
    source_text = source_text,
    source_revision = as.integer(source_revision),
    parsed_revision = as.integer(parsed_revision),
    parse_status = status,
    parse_error = parse_error
  )
}

graph_data_document_from_state <- function(state) {
  if (!is.list(state)) return(graph_data_document_default(""))
  graph_data_document_normalize(state$data_document, graph_state_scalar(state$data_text, ""))
}

graph_data_document_source_text <- function(state) {
  graph_data_document_from_state(state)$source_text
}

graph_data_document_with_source <- function(state, source_text, source_revision,
                                            parsed = NULL, parse_error = "") {
  if (!is.list(state)) return(state)
  source_text <- as.character(source_text %||% "")[1]
  if (is.na(source_text)) source_text <- ""
  source_revision <- suppressWarnings(as.integer(source_revision %||% 0L))
  if (!is.finite(source_revision) || source_revision < 0L) source_revision <- 0L

  doc <- graph_data_document_from_state(state)
  doc$source_text <- source_text
  doc$source_revision <- as.integer(max(doc$source_revision, source_revision))

  if (is.data.frame(parsed) && ncol(parsed) >= 1L &&
      isTRUE(graph_data_column_name_status(parsed)$valid)) {
    doc$parse_status <- "valid"
    doc$parse_error <- ""
    doc$parsed_revision <- doc$source_revision
    state$data_text <- source_text
  } else {
    doc$parse_status <- "invalid"
    err <- as.character(parse_error %||% "")[1]
    if (is.na(err) || !nzchar(err)) {
      err <- "データを読み込めませんでした。列名と区切りを確認してください。"
    }
    doc$parse_error <- err
  }

  state$data_document <- graph_data_document_normalize(doc, graph_state_scalar(state$data_text, ""))
  old_schema <- suppressWarnings(as.integer(graph_state_scalar(state$schema_version, 0L)))
  if (!is.finite(old_schema)) old_schema <- 0L
  state$schema_version <- max(6L, old_schema)
  state
}
