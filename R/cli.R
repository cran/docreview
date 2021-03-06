#' Parse Vignette Results
#'
#' @param vignette_results Output of calling vignette analysis function
#' @param error_on_failure Raise an error on any negative reviews
#'
#' @keywords internal
vignette_results_display <- function(results, config = get_config()$vignettes) {
  cli({
    cli_h2("Vignettes")

    if (length(results) == 0) {
      cli_h3("No vignettes detected")
    } else {
      if (config$`flesch-kincaid`$active) {
        cli_h3("Flesch Kincaid reading complexity scores:")

        fk_thresholds <- config$`flesch-kincaid`$thresholds$poor_readbility
        fk_scores <- map_dbl(results, "flesch_kincaid")

        bullet_vals <- paste0(names(fk_scores), ": ", round(fk_scores, 2))

        bullet_names <- rep(" ", length(fk_scores))
        bullet_names[fk_scores <= fk_thresholds$fail] <- "x"
        bullet_names[fk_scores > fk_thresholds$fail & fk_scores <= fk_thresholds$warn] <- "!"
        bullet_names[fk_scores > fk_thresholds$warn] <- "v"

        names(bullet_vals) <- bullet_names

        cli_bullets(bullet_vals)
      }

      if (config$length$active) {
        cli_h3("Length scores")

        length_thresholds <- config$length$thresholds
        length_scores <- map_dbl(results, "length")

        bullet_vals <- paste0(names(length_scores), ": ", length_scores, " words.")

        bullet_names <- rep(" ", length(length_scores))
        bullet_names[length_scores >= length_thresholds$too_long$fail | length_scores <= length_thresholds$too_short$fail] <- "x"

        bullet_names[(length_scores < length_thresholds$too_long$fail & length_scores >= length_thresholds$too_long$warn) |
          (length_scores > length_thresholds$too_short$fail & length_scores <= length_thresholds$too_short$warn)] <- "!"

        bullet_names[length_scores < length_thresholds$too_long$warn | length_scores > length_thresholds$too_short$warn] <- "v"

        names(bullet_vals) <- bullet_names

        cli_bullets(bullet_vals)
      }
    }
  })
}

#' Parse function documentation analysis results
#'
#' @param results Results of function documentation analysis
#' @keywords internal
function_results_display <- function(results, config) {
  examples <- as.character(results$exports_examples)
  names(examples) <- names(results$exports_examples)

  if (config$active) {
    cli({
      cli_h2("Function Documentation")

      if (config$exports_without_examples$active) {
        cli_h3("Exported functions containing examples in their documentation: ")

        examples[examples == "FALSE"] <- "x"
        examples[examples == "TRUE"] <- "v"

        exports <- names(examples)
        names(exports) <- examples

        cli_bullets(exports)
      }
    })
  }
}
