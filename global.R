# Global application bootstrap.
# Keep ordering explicit: config -> packages -> shared helpers -> Graph/Figure modules.
source("app_config.R", local = TRUE)
source("app_dependencies.R", local = TRUE)
source("app_shared_helpers.R", local = TRUE)
source("app_module_registry.R", local = TRUE)
