# Test configuration helper
# Provides config for tests that works in both development and R CMD check

get_test_config <- function() {
  # Try to get actual config if available
  cfg <- tryCatch(
    config::get(),
    error = function(e) NULL
  )
  
  # If config.yml found, use it
  if (!is.null(cfg)) {
    return(cfg)
  }
  
  # Otherwise return test defaults matching config.yml
  list(
    screen = list(
      width_px = 1280,
      height_px = 1024,
      width_mm = 338.6,
      height_mm = 318.5,
      viewing_distance_mm = 650
    ),
    clock = list(
      diameter_ratio = 0.333,
      hand_length_ratio = 0.45,
      increment_deg = 3.41,
      line_width_px = 4
    ),
    validation = list(
      response_window_ms = 8000,
      zone_strategy = "average",
      zone_scaling = 1.0
    )
  )
}
