#' Shukla's stability variance parameter
#' @description
#' `r badge('stable')`
#'
#' The function computes the Shukla's stability variance parameter (1972) and
#' uses the Kang's nonparametric stability (rank sum) to imcorporate the mean
#' performance and stability into a single selection criteria.
#'
#'
#' @param .data The dataset containing the columns related to Environments,
#'   Genotypes, replication/block and response variable(s).
#' @param env The name of the column that contains the levels of the
#'   environments.
#' @param gen The name of the column that contains the levels of the genotypes.
#' @param rep The name of the column that contains the levels of the
#'   replications/blocks.
#' @param resp The response variable(s). To analyze multiple variables in a
#'   single procedure use, for example, `resp = c(var1, var2, var3)`.
#' @param verbose Logical argument. If `verbose = FALSE` the code will run
#'   silently.
#' @return An object of class `Shukla`, which is a list containing the results for each
#'   variable used in the argument `resp`. For each variable, a tibble with the following
#'   columns is returned.
#' * **GEN** the genotype's code.
#' * **Y** the mean for the response variable.
#' * **ShuklaVar** The Shukla's stability variance parameter.
#' * **rMean** The rank for **Y** (decreasing).
#' * **rShukaVar** The rank for **ShukaVar**.
#' * **ssiShukaVar** The simultaneous selection index (\eqn{ssiShukaVar = rMean + rShukaVar}).
#' @md
#' @export
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @references
#' Shukla, G.K. 1972. Some statistical aspects of partitioning
#' genotype-environmental components of variability. Heredity. 29:238-245.
#' \doi{10.1038/hdy.1972.87}
#'
#' Kang, M.S., and H.N. Pham. 1991. Simultaneous Selection for High Yielding and
#' Stable Crop Genotypes. Agron. J. 83:161.
#' \doi{10.2134/agronj1991.00021962008300010037x}
#'
#' @examples
#' \donttest{
#' library(metan)
#'out <- Shukla(data_ge2,
#'              env = ENV,
#'              gen = GEN,
#'              rep = REP,
#'              resp = PH)
#'}
Shukla <- function(.data, env, gen, rep, resp, verbose = TRUE) {
  factors  <-
    .data %>%
    select({{env}}, {{gen}}, {{rep}}) %>%
    mutate(across(everything(), as.factor))
  vars <-
    .data %>%
    select({{resp}}, -names(factors)) %>%
    select_numeric_cols()
  factors %<>% set_names("ENV", "GEN", "REP")
  g <- nlevels(factors$GEN)
  e <- nlevels(factors$ENV)
  r <- nlevels(factors$REP)
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
    g_means <- mean_by(data, GEN)
    ge_means <- mean_by(data, GEN, ENV)
    ge_effect <- ge_means %>%
      mutate(ge = residuals(lm(Y ~ ENV + GEN, data = .))) %>%
      make_mat(GEN, ENV, ge) %>%
      as.matrix()
    Wi <- rowSums(ge_effect^2, na.rm = TRUE)
    ShuklaVar <- (g * (g - 1) * Wi - sum(Wi, na.rm = TRUE)) / ((e - 1) * (g - 1) * ( g - 2))
    temp <- as_tibble(cbind(g_means, ShuklaVar)) %>%
      mutate(rMean = rank(-Y),
             rShukaVar = rank(ShuklaVar),
             ssiShukaVar = rMean + rShukaVar)
    if (verbose == TRUE) {
      run_progress(pb,
                   actual = var,
                   text = paste("Evaluating trait", names(vars[var])))
    }
    listres[[paste(names(vars[var]))]] <- temp
  }
  return(structure(listres, class = "Shukla"))
}






#' Print an object of class Shukla
#'
#' Print the `Shukla` object in two ways. By default, the results
#' are shown in the R console. The results can also be exported to the directory
#' into a *.txt file.
#'
#'
#' @param x The `Shukla` x
#' @param export A logical argument. If `TRUE`, a *.txt file is exported to
#'   the working directory.
#' @param file.name The name of the file if `export = TRUE`
#' @param digits The significant digits to be shown.
#' @param ... Options used by the tibble package to format the output. See
#'   [`tibble::print()`][tibble::formatting] for more details.
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @method print Shukla
#' @export
#' @examples
#' \donttest{
#' library(metan)
#' eco <- Shukla(data_ge2,
#'   env = ENV,
#'   gen = GEN,
#'   rep = REP,
#'   resp = PH
#' )
#' print(eco)
#' }
print.Shukla <- function(x, export = FALSE, file.name = NULL, digits = 3, ...) {
  opar <- options(pillar.sigfig = digits)
  on.exit(options(opar))
  if (export == TRUE) {
    file.name <- ifelse(is.null(file.name) == TRUE, "Shukla print", file.name)
    sink(paste0(file.name, ".txt"))
  }
  for (i in 1:length(x)) {
    var <- x[[i]]
    cat("Variable", names(x)[i], "\n")
    cat("---------------------------------------------------------------------------\n")
    cat("Shukla stability variance\n")
    cat("---------------------------------------------------------------------------\n")
    print(var)
  }
  cat("\n\n\n")
  if (export == TRUE) {
    sink()
  }
}
