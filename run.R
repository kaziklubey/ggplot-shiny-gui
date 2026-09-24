wd <- commandArgs(trailingOnly = TRUE)
app_dir <- if (length(wd) >= 1 && nzchar(wd[1])) wd[1] else getwd()
root_dir <- dirname(app_dir)
req_file <- file.path(app_dir, "req.txt")
if (!file.exists(req_file)) req_file <- file.path(root_dir, "req.txt")

bootstrap_file <- file.path(app_dir, "R/bootstrap/bootstrap_packages.R")
if (!file.exists(bootstrap_file)) bootstrap_file <- file.path(root_dir, "R/bootstrap/bootstrap_packages.R")
if (!file.exists(bootstrap_file)) stop("R/bootstrap/bootstrap_packages.R was not found.", call. = FALSE)
source(bootstrap_file, local = .GlobalEnv)

req <- trimws(readLines(req_file, warn = FALSE))
req <- req[nzchar(req)]
missing_req <- req[!vapply(req, requireNamespace, logical(1L), quietly = TRUE)]

lib_path <- NULL
if (length(missing_req)) {
  lib_path <- ggplot_gui_resolve_install_library()
  message(sprintf("Package install library: %s", lib_path))
}
for (pkg in req) ensure_package(pkg, lib_path)

# FileSystemHandle/IndexedDBは browser origin(host+port)単位。
# ローカル再起動でportが変わらないよう既定値を固定する。
# 必要なら環境変数 GGPLOT_GUI_PORT で変更可能。
app_port <- suppressWarnings(as.integer(Sys.getenv("GGPLOT_GUI_PORT", "4006")))
if (is.na(app_port) || app_port < 1L || app_port > 65535L) app_port <- 4006L

shiny::runApp(
  appDir = app_dir,
  launch.browser = TRUE,
  port = app_port
)
