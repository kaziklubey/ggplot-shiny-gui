# Global application bootstrap.
# Keep ordering explicit: config -> packages -> shared helpers -> Graph/Figure modules.
source("R/bootstrap/app_config.R", local = TRUE)
source("R/bootstrap/app_dependencies.R", local = TRUE)
source("R/bootstrap/app_shared_helpers.R", local = TRUE)
source("R/bootstrap/source_manifest.R", local = TRUE)
