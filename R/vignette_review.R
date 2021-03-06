#' Review vignettes
#'
#' @param path Path to package
#' @param checks Checks to run
vignette_review <- function(path, checks = get_config()$vignettes) {
  vig_paths <- find_vignettes(path)
  detailed_results <- lapply(vig_paths, analyse_vignette, checks = checks)
  names(detailed_results) <- basename(vig_paths)

  comments <- vignettes_get_comments(detailed_results, checks)

  list(failures = comments$fail, warnings = comments$warn, details = detailed_results)
}

vignettes_get_comments <- function(results, checks = get_config()$vignettes) {
  comments <- list(fail = 0, warn = 0)

  if (checks$`flesch-kincaid`$active) {
    # Count failures and warnings for Flesch Kincaid scores
    fk_scores <- map(results, "flesch_kincaid")
    fk_thresholds <- checks$`flesch-kincaid`$thresholds$poor_readbility

    fk_fails <- length(fk_scores[fk_scores <= fk_thresholds$fail])
    fk_warns <- length(fk_scores[fk_scores > fk_thresholds$fail & fk_scores <= fk_thresholds$warn])

    comments$fail <- comments$fail + fk_fails
    comments$warn <- comments$warn + fk_warns
  }

  if (checks$length$active) {
    # Count failures and warnings for lengths
    length_scores <- map(results, "length")
    long_thresholds <- checks$length$thresholds$too_long
    short_thresholds <- checks$length$thresholds$too_short

    long_fails <- length(length_scores[length_scores >= long_thresholds$fail])
    long_warns <- length(length_scores[length_scores < long_thresholds$fail & length_scores >= long_thresholds$warn])

    short_fails <- length(length_scores[length_scores <= short_thresholds$fail])
    short_warns <- length(length_scores[length_scores > short_thresholds$fail & length_scores <= short_thresholds$warn])

    comments$fail <- comments$fail + long_fails + short_fails
    comments$warn <- comments$warn + long_warns + short_warns
  }

  comments
}

#' Analyse a single vignette
#'
#' @param vig_path Path to directory where vignette is
#' @keywords internal
analyse_vignette <- function(vig_path, checks = get_config()$vignettes) {
  tryCatch(
    {
      vig_sects <- parse_vignette(vig_path)
      cleaned_md <- lapply(vig_sects, clean_chunks)
      # remove empty chunks so we don't get any errors
      cleaned_md <- cleaned_md[cleaned_md != ""]

      out <- list()

      if (checks$`flesch-kincaid`$active) {
        fk <- get_fk_score(cleaned_md)
        out$flesch_kincaid <- fk$overall
      }

      if (checks$`length`$active) {
        lengths <- get_length(cleaned_md)
        out$length <- lengths$overall
      }

      if (checks$`problem_words`$active) {
        pws <- detect_problem_words(cleaned_md)
        out$problem_words <- pws
      }

      out
    },
    error = function(e) {
      rlang::warn(
        c(
          paste("Could not parse vignette at path:", vig_path),
          x = e$message
        )
      )
      list()
    }
  )
}

detect_problem_words <- function(md) {
  problem_words <- c("[Ss]imply", "[Nn]aturally", "[Mm]ere", "[Oo]bvious", "[Tt]rivial")
  problem_regex <- paste0(
    problem_words,
    collapse = "|"
  )
  out <- lapply(md, function(x) {
    stringr::str_detect(x, problem_regex)
  })

  md[out == TRUE]
}

#' Get number of words in a markdown chunk
#'
#' @param md Markdown chunk
#' @keywords internal
get_length <- function(md) {
  token_counts <- lapply(md, function(x) length(tokens(x[[1]])[[1]]))
  list(overall = sum(unlist(token_counts)), sections = token_counts)
}

#' Get Flesch-Kincaid readability score
#'
#' @param code List of code chunks
#' @keywords internal
get_fk_score <- function(code) {
  chunk_scores <- lapply(code, function(x) {
    textstat_readability(x)$Flesch
  })

  # if fk < 0, something's probably gone a bit wrong
  reasonable_scores <- code[chunk_scores > 0]

  one_chunk <- paste(unlist(reasonable_scores), collapse = " ")
  overall_score <- textstat_readability(one_chunk)$Flesch

  list(overall = overall_score, sections = chunk_scores)
}

#' Clean markdown chunks
#'
#' Remove text in links and backticks from chunks
#'
#' @param chunk Code chunk
#'
#' @keywords internal
clean_chunks <- function(chunk) {
  no_links <- remove_links(chunk)
  no_backticks <- remove_backticks(no_links)
  stringr::str_trim(no_backticks)
}

#' Remove links from a chunk
#'
#' Remove any links in markdown format
#'
#' @param chunk Code chunk
#' @keywords internal
remove_links <- function(chunk) {
  stringr::str_remove_all(chunk, "\\[([^\\[]+)\\]\\(.*?\\)")
}

#' Remove any code in backticks from a chunk
#'
#' @param chunk Code chunk
#' @keywords internal
remove_backticks <- function(chunk) {
  stringr::str_remove_all(chunk, "`.*?`")
}

#' Parse a vignette
#'
#' @param vig_path Path to vignette
#' @return List of length 1 character vectors containing contents of each markdown section
#' @keywords internal
parse_vignette <- function(vig_path) {
  vig <- parsermd::parse_rmd(vig_path)

  # Extract all markdown sections
  md_sections <- parsermd::rmd_select(vig, parsermd::has_type("rmd_markdown"))
  lapply(md_sections, extract_md_section)
}

#' Extract markdown section
#'
#' Extract the content from the markdown section and collapse it into one string
#'
#' @param md Markdown
#' @keywords internal
extract_md_section <- function(md) {
  doc <- parsermd::as_document(md)
  paste(doc, collapse = " ")
}
