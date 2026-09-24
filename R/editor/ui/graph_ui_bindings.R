# ============================================================
# Graph UI binding factory
# ============================================================
# One place owns namespacing + saved-state pre-seeding for Graph controls.

graph_ui_seeded_args <- function(ui_seed, input_id, args, key, pos) {
  sv <- ui_seed[[input_id]]
  if (is.null(sv)) return(args)
  nms <- names(args)
  if (is.null(nms)) nms <- rep("", length(args))
  if (key %in% nms) {
    args[[which(nms == key)[1]]] <- sv
  } else if (length(args) >= pos && !nzchar(nms[pos])) {
    args[[pos]] <- sv
  } else {
    args[[key]] <- sv
  }
  args
}

graph_ui_seeded_bindings <- function(ns, ui_seed) {
  call_seeded <- function(fun, id0, args, key, pos) {
    args <- graph_ui_seeded_args(ui_seed, id0, args, key, pos)
    do.call(fun, c(list(inputId = ns(id0)), args))
  }

  list(
    textInput = function(inputId, ...) call_seeded(shiny::textInput, inputId, list(...), "value", 2L),
    textAreaInput = function(inputId, ...) call_seeded(shiny::textAreaInput, inputId, list(...), "value", 2L),
    selectInput = function(inputId, ...) call_seeded(shiny::selectInput, inputId, list(...), "selected", 3L),
    selectizeInput = function(inputId, ...) call_seeded(shiny::selectizeInput, inputId, list(...), "selected", 3L),
    checkboxInput = function(inputId, ...) call_seeded(shiny::checkboxInput, inputId, list(...), "value", 2L),
    checkboxGroupInput = function(inputId, ...) call_seeded(shiny::checkboxGroupInput, inputId, list(...), "selected", 3L),
    radioButtons = function(inputId, ...) call_seeded(shiny::radioButtons, inputId, list(...), "selected", 3L),
    sliderInput = function(inputId, ...) call_seeded(shiny::sliderInput, inputId, list(...), "value", 4L),
    numericInput = function(inputId, ...) call_seeded(shiny::numericInput, inputId, list(...), "value", 2L),
    actionButton = function(inputId, ...) shiny::actionButton(ns(inputId), ...),
    downloadButton = function(outputId, ...) shiny::downloadButton(ns(outputId), ...),
    fileInput = function(inputId, ...) shiny::fileInput(ns(inputId), ...),
    uiOutput = function(outputId, ...) shiny::uiOutput(ns(outputId), ...),
    plotOutput = function(outputId, ...) shiny::plotOutput(ns(outputId), ...),
    tableOutput = function(outputId, ...) shiny::tableOutput(ns(outputId), ...),
    verbatimTextOutput = function(outputId, ...) shiny::verbatimTextOutput(ns(outputId), ...),
    colourInput = function(inputId, ...) call_seeded(colourpicker::colourInput, inputId, list(...), "value", 2L),
    aceEditor = function(outputId, ...) {
      args <- graph_ui_seeded_args(ui_seed, outputId, list(...), "value", 1L)
      do.call(shinyAce::aceEditor, c(list(outputId = ns(outputId)), args))
    },
    conditionalPanel = function(condition, ..., ns_unused = NULL) {
      shiny::conditionalPanel(condition = condition, ..., ns = ns)
    }
  )
}
