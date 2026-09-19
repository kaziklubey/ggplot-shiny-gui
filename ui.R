# UI entry point.
# Keep this file intentionally small; the component tree is in ui_shell.R,
# Graph/Figure controls are in their existing UI modules, and browser assets
# are served from www/.
source("ui_shell.R", local = TRUE)

shinyUI(appUI())
