source("renv/activate.R")

#### -- Repository Configuration -- ####
# Include R-universe for polars/tidypolars and other packages
options(
  repos = c(
    CRAN = "https://cloud.r-project.org",
    "R-multiverse" = "https://community.r-multiverse.org"
  )
)

#### -- Consistent File Downloads -- ####
if(.Platform$OS.type == "windows") {
  options(
    download.file.method = "wininet"
  )
} else {
  options(
    download.file.method = "libcurl"
  )
}

#### -- Factors Are Not Strings -- ####
options(
  stringsAsFactors=FALSE
)

#### -- Display -- ####
options(
  digits = 12, # number of significant digits to show by default
  width = 80 # console width
)

#### -- Time Zone -- ####
if (Sys.getenv("TZ") == "") Sys.setenv("TZ" = Sys.timezone())
if (Sys.getenv("TZ") == "") Sys.setenv("TZ" = "America/Denver")
if (interactive()) {
  message("Session Time: ", format(Sys.time(), tz = Sys.getenv("TZ"), usetz = TRUE))
}

#### -- Session -- ####
.First <- function() {
  if (interactive()) {
    cat("\n")
    utils::timestamp("", prefix = paste("##------ [", getwd(), "] ", sep = ""))
    cat("\nSuccessfully loaded .Rprofile at", base::date(), "\n")
  }
}

if (interactive()) {
  message("Session Info: ", utils::sessionInfo()[[4]])
  message("Session User: ", Sys.info()["user"])
}

options(
  prompt = "R > ",
  continue = "... "
)

if (interactive()) {
  # Command: Sys.getenv("R_CONFIG_ACTIVE") to get user value
  Sys.setenv(R_CONFIG_ACTIVE = Sys.info()["user"])
}

#### -- Dev Tools -- ####
if (interactive()) {
  # Load dev tools only if installed (graceful degradation)
  if (requireNamespace("fs", quietly = TRUE)) {
    suppressPackageStartupMessages(library(fs))
  }
  if (requireNamespace("devtools", quietly = TRUE)) {
    suppressPackageStartupMessages(library(devtools))
  }
}
