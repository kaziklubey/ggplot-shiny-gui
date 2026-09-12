library(shiny)
library(shinyAce)
library(ggplot2)
library(dplyr)
library(tidyr)
library(shinyjs)
library(scales)
library(svglite)
library(colourpicker)
library(jsonlite)
library(ggbeeswarm)
library(ggbreak)

`%||%` <- function(a, b) if (is.null(a)) b else a

source("graph_module.R", local = TRUE)
