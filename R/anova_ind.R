#' Within-environment analysis of variance
#' @description
#' `r badge('stable')`
#'
#' Performs a within-environment analysis of variance in randomized complete
#' block or alpha-lattice designs and returns values such as Mean Squares,
#' p-values, coefficient of variation, heritability, and accuracy of selection.
#'
#'
#' @param .data The dataset containing the columns related to Environments,
#'   Genotypes, replication/block and response variable(s).
#' @param env The name of the column that contains the levels of the
#'   environments. The analysis of variance is computed for each level of this
#'   factor.
#' @param gen The name of the column that contains the levels of the genotypes.
#' @param rep The name of the column that contains the levels of the
#'   replications/blocks.
#' @param resp The response variable(s). To analyze multiple variables in a
#'   single procedure a vector of variables may be used. For example `resp
#'   = c(var1, var2, var3)`.
#' @param block Defaults to `NULL`. In this case, a randomized complete
#'   block design is considered. If block is informed, then a resolvable
#'   alpha-lattice design (Patterson and Williams, 1976) is employed.
#'   **All effects, except the error, are assumed to be fixed.**
#' @param verbose Logical argument. If `verbose = FALSE` the code will run
#'   silently.
#' @return A list where each element is the result for one variable containing
#'   (1) **individual**: A tidy tbl_df with the results of the individual
#'   analysis of variance with the following column names, and (2) **MSRatio**:
#'   The ratio between the higher and lower residual mean square. The following
#'   columns are returned, depending on the experimental design
#'
#' * **For analysis in alpha-lattice designs**:
#'    - `MEAN`: The grand mean.
#'    - `DFG, DFCR, and DFIB_R, and DFE`: The degree of freedom for genotype,
#'    complete replicates, incomplete blocks within replicates, and error,
#'    respectively.
#'    - `MSG, MSCR, MSIB_R`: The mean squares for genotype, replicates, incomplete
#' blocks within replicates, and error, respectively.
#'    - `FCG, FCR, FCIB_R`: The F-calculated for genotype, replicates and
#' incomplete blocks within replicates, respectively.
#'    - `PFG, PFCR, PFIB_R`: The P-values for genotype, replicates and incomplete
#' blocks within replicates, respectively.
#'    - `CV`: coefficient of variation.
#'    - `h2`: broad-sense heritability.
#'    - `AS`: accuracy of selection (square root of `h2`)
#'
#' * **For analysis in randomized complete block design**:
#'    - `MEAN`: The grand mean.
#'    - `DFG, DFB, and DFE`: The degree of freedom for genotype blocks, and error, respectively.
#'    - `MSG, MSB, and MSE`: The mean squares for genotype blocks, and error, respectively.
#'    - `FCG and FCB`: The F-calculated for genotype and blocks, respectively.
#'    - `PFG and PFB`: The P-values for genotype and blocks, respectively.
#'    - `CV`: coefficient of variation.
#'    - `h2`: broad-sense heritability.
#'    - `AS`: accuracy of selection (square root of `h2`)
#'
#'
#'
#' @references Patterson, H.D., and E.R. Williams. 1976. A new class of
#' resolvable incomplete block designs. Biometrika 63:83-92.
#'
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @md
#' @export
#' @examples
#'\donttest{
#' library(metan)
#' # ANOVA for all variables in data
#' ind_an <- anova_ind(data_ge,
#'                     env = ENV,
#'                     gen = GEN,
#'                     rep = REP,
#'                     resp = everything())
#' # mean for each environment
#'get_model_data(ind_an)
#'
#'# P-value for genotype effect
#'get_model_data(ind_an, "PFG")
#'
#'}
anova_ind <- function(.data,
                      env,
                      gen,
                      rep,
                      resp,
                      block = NULL,
                      verbose = TRUE) {

  if(!missing(block)){
    factors  <- .data %>%
      select({{env}},
             {{gen}},
             {{rep}},
             {{block}}) %>%
      mutate(across(everything(), as.factor))
  } else{
    factors  <- .data %>%
      select({{env}},
             {{gen}},
             {{rep}}) %>%
      mutate(across(everything(), as.factor))
  }
  vars <- .data %>% select({{resp}}, -names(factors))
  vars %<>% select_numeric_cols()
  if(!missing(block)){
    factors %<>% set_names("ENV", "GEN", "REP", "BLOCK")
  } else{
    factors %<>% set_names("ENV", "GEN", "REP")
  }
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
    grouped <- data %>% split(dplyr::pull(., ENV))
    if(missing(block)){
      formula <- as.formula(paste0("Y ~ GEN + REP"))
      individual <- do.call(rbind, lapply(grouped, function(x) {
        anova <-
          aov(formula, data = x) %>%
          anova() %>%
          suppressMessages() %>%
          suppressWarnings()
        DFB <- anova[2, 1]
        MSB <- anova[2, 3]
        DFG <- anova[1, 1]
        MSG <- anova[1, 3]
        DFE <- anova[3, 1]
        MSE <- anova[3, 3]
        h2 <- (MSG - MSE) / MSG
        if (h2 < 0) {
          AS <- 0
        } else {
          AS <- sqrt(h2)
        }
        final <- tibble(MEAN = mean(x$Y),
                        DFG = DFG,
                        MSG = MSG,
                        FCG = anova[1, 4],
                        PFG = anova[1, 5],
                        DFB = DFB,
                        MSB = MSB,
                        FCB = anova[2, 4],
                        PFB = anova[2, 5],
                        DFE = DFE,
                        MSE = MSE,
                        CV = sqrt(MSE) / mean(x$Y) * 100,
                        h2 = h2,
                        AS = AS)
      }))
      if (verbose == TRUE) {
        run_progress(pb,
                     actual = var,
                     text = paste("Evaluating trait", names(vars[var])))
      }
    } else{
      formula <- as.formula(paste0("Y ~ GEN + REP + REP:BLOCK"))
      individual <- do.call(rbind, lapply(grouped, function(x) {
        anova <-
          aov(formula, data = x) %>%
          anova() %>%
          suppressMessages() %>%
          suppressWarnings()
        DFG <- anova[1, 1]
        MSG <- anova[1, 3]
        DFCR <- anova[2, 1]
        MSB <- anova[2, 3]
        DFIB_R <- anova[3, 1]
        MSIB_R <- anova[3, 3]
        DFE <- anova[4, 1]
        MSE <- anova[4, 3]
        h2 <- (MSG - MSE) / MSG
        if (h2 < 0) {
          AS <- 0
        } else {
          AS <- sqrt(h2)
        }
        final <- tibble(MEAN = mean(x$Y),
                        DFG = DFG,
                        MSG = MSG,
                        FCG = anova[1, 4],
                        PFG = anova[1, 5],
                        DFCR = DFCR,
                        MSCR = MSB,
                        FCR = anova[2, 4],
                        PFCR = anova[2, 5],
                        DFIB_R = DFIB_R,
                        MSIB_R = MSIB_R,
                        FCIB_R = anova[3, 4],
                        PFIB_R = anova[3, 5],
                        DFE = DFE,
                        MSE = MSE,
                        CV = sqrt(MSE) / mean(x$Y) * 100,
                        h2 = h2,
                        AS = AS)
      }))
      if (verbose == TRUE) {
        run_progress(pb,
                     actual = var,
                     text = paste("Evaluating trait", names(vars[var])))
      }
    }
    temp <- list(individual = as_tibble(rownames_to_column(individual, "ENV")),
                 MSRratio = max(individual$MSE) / min(individual$MSE))
      listres[[paste(names(vars[var]))]] <- temp
  }
  invisible(structure(listres, class = "anova_ind"))
}







#' Print an object of class anova_ind
#'
#' Print the `anova_ind` object in two ways. By default, the results are shown
#' in the R console. The results can also be exported to the directory into a
#' *.txt file.
#'
#' @param x An object of class `anova_ind`.
#' @param export A logical argument. If `TRUE`, a *.txt file is exported to
#'   the working directory.
#' @param file.name The name of the file if `export = TRUE`
#' @param digits The significant digits to be shown.
#' @param ... Options used by the tibble package to format the output. See
#'   [`tibble::print()`][tibble::formatting] for more details.
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @method print anova_ind
#' @export
#' @examples
#' \donttest{
#' library(metan)
#' model <- data_ge %>% anova_ind(ENV, GEN, REP, c(GY, HM))
#' print(model)
#' }
print.anova_ind <- function(x, export = FALSE, file.name = NULL, digits = 3, ...) {
  opar <- options(pillar.sigfig = digits)
  on.exit(options(opar))
  if (export == TRUE) {
    file.name <- ifelse(is.null(file.name) == TRUE, "anova_ind print", file.name)
    sink(paste0(file.name, ".txt"))
  }
  for (i in 1:length(x)) {
    var <- x[[i]]
    cat("Variable", names(x)[i], "\n")
    cat("---------------------------------------------------------------------------\n")
    cat("Within-environment ANOVA results\n")
    cat("---------------------------------------------------------------------------\n")
    print(var[[1]])
    cat("---------------------------------------------------------------------------\n")
    cat("\n\n\n")
  }
  if (export == TRUE) {
    sink()
  }
}
