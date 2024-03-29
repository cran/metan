#' Fox's stability function
#' @description
#' `r badge('stable')`
#'
#' Performs a stability analysis based on the criteria of Fox et al. (1990),
#' using the statistical "TOP third" only. A stratified ranking of the genotypes
#' at each environment is done. The proportion of locations at which the
#' genotype occurred in the top third are expressed in the output.
#'
#'
#' @param .data The dataset containing the columns related to Environments,
#'   Genotypes, replication/block and response variable(s).
#' @param env The name of the column that contains the levels of the
#'   environments.
#' @param gen The name of the column that contains the levels of the genotypes.
#' @param resp The response variable(s). To analyze multiple variables in a
#'   single procedure use, for example, `resp = c(var1, var2, var3)`.
#' @param verbose Logical argument. If `verbose = FALSE` the code will run
#'   silently.
#' @return An object of class `Fox`, which is a list containing the results
#'   for each variable used in the argument `resp`. For each variable, a
#'   tibble with the following columns is returned.
#' * **GEN** the genotype's code.
#' * **mean** the mean for the response variable.
#' * **TOP** The proportion of locations at which the
#' @md
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @references Fox, P.N., B. Skovmand, B.K. Thompson, H.J. Braun, and R.
#'   Cormier. 1990. Yield and adaptation of hexaploid spring triticale.
#'   Euphytica 47:57-64.
#'   \doi{10.1007/BF00040364}.
#'
#' @export
#' @examples
#' \donttest{
#' library(metan)
#' out <- Fox(data_ge2, ENV, GEN, PH)
#' print(out)
#'}
#'
Fox <- function(.data, env, gen, resp, verbose = TRUE) {
  factors  <-
    .data %>%
    select({{env}}, {{gen}}) %>%
    mutate(across(everything(), as.factor))
  vars <-
    .data %>%
    select({{resp}}, -names(factors)) %>%
    select_numeric_cols()
  factors %<>% set_names("ENV", "GEN")
  listres <- list()
  nvar <- ncol(vars)
  if (verbose == TRUE) {
      pb <- progress(max = nvar, style = 4)
  }
  for (var in 1:nvar) {
    data <- factors %>%
      mutate(Y = vars[[var]])
    if(has_na(data)){
      data <- remove_rows_na(data)
      has_text_in_num(data)
    }
    temp <- data %>%
      group_by(ENV) %>%
      mutate(grank = rank(-Y)) %>%
      group_by(GEN) %>%
      summarise(Y = mean(Y),
                TOP = sum(grank <= 3)) %>%
      as_tibble()
    if (verbose == TRUE) {
      run_progress(pb,
                   actual = var,
                   text = paste("Evaluating trait", names(vars[var])))
    }
    listres[[paste(names(vars[var]))]] <- temp
  }
  return(structure(listres, class = "Fox"))
}








#' Print an object of class Fox
#'
#' Print the `Fox` object in two ways. By default, the results
#' are shown in the R console. The results can also be exported to the directory
#' into a *.txt file.
#'
#'
#' @param x The `Fox` x
#' @param export A logical argument. If `TRUE`, a *.txt file is exported to
#'   the working directory.
#' @param file.name The name of the file if `export = TRUE`
#' @param digits The significant digits to be shown.
#' @param ... Options used by the tibble package to format the output. See
#'   [`tibble::print()`][tibble::formatting] for more details.
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @method print Fox
#' @export
#' @examples
#' \donttest{
#' library(metan)
#' library(metan)
#' out <- Fox(data_ge2, ENV, GEN, PH)
#' print(out)
#' }
print.Fox <- function(x, export = FALSE, file.name = NULL, digits = 3, ...) {
  opar <- options(pillar.sigfig = digits)
  on.exit(options(opar))
  if (export == TRUE) {
    file.name <- ifelse(is.null(file.name) == TRUE, "Fox print", file.name)
    sink(paste0(file.name, ".txt"))
  }
  for (i in 1:length(x)) {
    var <- x[[i]]
    cat("Variable", names(x)[i], "\n")
    cat("---------------------------------------------------------------------------\n")
    cat("Fox TOP third criteria\n")
    cat("---------------------------------------------------------------------------\n")
    print(var)
  }
  cat("\n\n\n")
  if (export == TRUE) {
    sink()
  }
}
