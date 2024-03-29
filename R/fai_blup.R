#' Multi-trait selection index
#' @description
#' `r badge('stable')`
#'
#' Multitrait index based on factor analysis and ideotype-design proposed by
#' Rocha et al. (2018).
#'
#'
#' @param .data An object of class `waasb` or a two-way table with
#'   genotypes in the rows and traits in columns. In the last case the row names
#'   must contain the genotypes names.
#' @param use_data Define which data to use If `.data` is an object of
#'   class `gamem`. Defaults to `"blup"` (the BLUPs for genotypes).
#'   Use `"pheno"` to use phenotypic means instead BLUPs for computing the
#'   index.
#' @param DI,UI A vector of the same length of `.data` to construct the
#'   desirable (DI) and undesirable (UI) ideotypes. For each element of the
#'   vector, allowed values are `'max'`, `'min'`, `'mean'`, or a
#'   numeric value. Use a comma-separated vector of text. For example, `DI
#'   = c("max, max, min, min")`. By default, DI is set to `"max"` for all
#'   traits and UI is set to `"min"` for all traits.
#' @param SI An integer (0-100). The selection intensity in percentage of the
#'   total number of genotypes. Defaults to 15.
#' @param mineval The minimum value so that an eigenvector is retained in the
#'   factor analysis.
#' @param verbose Logical value. If `TRUE` some results are shown in
#'   console.
#' @return An object of class `fai_blup` with the following items:
#' * **data** The data (BLUPS) used to compute the index.
#' * **eigen** The eigenvalues and explained variance for each axis.
#' * **FA** The results of the factor analysis.
#' * **canonical_loadings** The canonical loadings for each factor retained.
#' * **FAI** A list with the FAI-BLUP index for each ideotype design.
#' * **sel_dif_trait** A list with the selection differential for each ideotype design.
#' * **sel_gen** The selected genotypes.
#' * **ideotype_construction** A list with the construction of the ideotypes.
#' * **total_gain** A list with the total gain for variables to be increased or decreased.
#' @md
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @references
#' Rocha, J.R.A.S.C.R, J.C. Machado, and P.C.S. Carneiro. 2018. Multitrait index
#' based on factor analysis and ideotype-design: proposal and application on
#' elephant grass breeding for bioenergy. GCB Bioenergy 10:52-60.
#' \doi{10.1111/gcbb.12443}
#'
#' @export
#' @examples
#'\donttest{
#' library(metan)
#'
#' mod <- waasb(data_ge,
#'              env = ENV,
#'              gen = GEN,
#'              rep = REP,
#'              resp = c(GY, HM))
#'
#' FAI <- fai_blup(mod,
#'                 SI = 15,
#'                 DI = c('max, max'),
#'                 UI = c('min, min'))
#'}
fai_blup <- function(.data,
                     use_data = "blup",
                     DI = NULL,
                     UI = NULL,
                     SI = 15,
                     mineval = 1,
                     verbose = TRUE) {
  # Adapted from 'Rocha, J.R. do A.S. de C., J.C. Machado, and P.C.S. Carneiro.
  # 2018. Multitrait index based on factor analysis and ideotype-design:
  # proposal and application on elephant grass breeding for bioenergy. GCB
  # Bioenergy 10(1): 52-60. doi: 10.1111/gcbb.12443'
  if(!use_data %in% c("blup", "pheno")){
    stop("Argument 'use_data = ", match.call()["use_data"], "'", "invalid. It must be either 'blup' or 'pheno'.")
  }
  if (!has_class(.data, c("data.frame", "tbl_df", "tbl", "waasb", "gamem"))) {
    stop("The .data must be an object of class 'waasb', 'gamem' or a data.frame/tbl_df.")
  }
  if(!has_class(.data, c("waasb", "gamem")) & any(sapply(.data, is.numeric)) == FALSE){
    stop("All columns in .data must be numeric.")
  }
  nvar <- ifelse(has_class(.data, c("waasb", "gamem")), length(.data), ncol(.data))
  if (nvar == 1) {
    stop("The multitrait stability index cannot be computed with one single variable.")
  }
  ifelse(missing(DI),
         ideotype.D <- rep("max", nvar),
         ifelse(is.character(DI),
                ideotype.D <- unlist(strsplit(DI, split=", ")),
                ideotype.D <- DI))
  ifelse(missing(UI),
         ideotype.U <- rep("min", nvar),
         ifelse(is.character(UI),
                ideotype.U <- unlist(strsplit(UI, split=", ")),
                ideotype.U <- UI))
  if (length(ideotype.D) != nvar || length(ideotype.U) != nvar) {
    stop("The length of DI and UI must be the same length of data.")
  }
  if(has_class(.data, c("gamem", "waasb"))){
    means <-
      gmd(.data, ifelse(use_data == "blup", "blupg", "data"), verbose = FALSE) %>%
      mean_by(GEN) %>%
      column_to_rownames("GEN")
  } else {
    if(has_class(.data, c("data.frame", "matrix")) & !has_rownames(.data)){
      stop("Please, provide rownames (with genotype's code).")
    }
    means <- .data
  }
  if (is.null(SI)) {
    ngs <- NULL
  } else {
    ngs <- round(nrow(means) * (SI/100), 0)
  }
  if (any(apply(means, 2, function(x) sd(x) == 0) == TRUE)) {
    nam <- paste(names(means[, apply(means, 2, function(x) sd(x) == 0)]), collapse = " ")
    stop("The genotype effect was not significant for the variables ",
         nam, ". Please, remove them and try again.")
  }
  normalize.means <- scale(means, center = FALSE, scale = apply(means, 2, sd))
  cor.means <- cor(normalize.means)
  eigen.decomposition <- eigen(cor.means)
  eigen.values <- eigen.decomposition$values
  eigen.vectors <- eigen.decomposition$vectors
  colnames(eigen.vectors) <- paste("PC", 1:ncol(cor.means), sep = "")
  rownames(eigen.vectors) <- colnames(means)
  if (length(eigen.values[eigen.values >= mineval]) == 1) {
    eigen.values.factors <- as.vector(c(as.matrix(sqrt(eigen.values[eigen.values >= mineval]))))
    initial.loadings <- cbind(eigen.vectors[, eigen.values >= mineval] * eigen.values.factors)
    finish.loadings <- initial.loadings
  } else {
    eigen.values.factors <-
      t(replicate(ncol(cor.means), c(as.matrix(sqrt(eigen.values[eigen.values >= mineval])))))
    initial.loadings <- eigen.vectors[, eigen.values >= mineval] * eigen.values.factors
    finish.loadings <- varimax(initial.loadings)[[1]][]
  }
  colnames(finish.loadings) <- paste("FA", 1:ncol(initial.loadings), sep = "")
  rownames(finish.loadings) <- colnames(means)
  comunalits <- rowSums(finish.loadings^2)
  cumulative.var <- cumsum(eigen.values/sum(eigen.values)) * 100
  pca <- cbind(eigen.values, cumulative.var)
  rownames(pca) <- paste("PC", 1:ncol(means), sep = "")
  fa <- cbind(finish.loadings, comunalits)
  canonical.loadings <- t(t(finish.loadings) %*% solve_svd(cor.means))
  rownames(canonical.loadings) <- colnames(means)
  scores <- t(t(canonical.loadings) %*% t(normalize.means))
  colnames(scores) <- paste("SC", 1:ncol(scores), sep = "")
  rownames(scores) <- rownames(means)
  IN <- 2^ncol(finish.loadings)
  pos.var.factor <- which(abs(finish.loadings) == apply(abs(finish.loadings), 1, max), arr.ind = T)
  var.factor <- lapply(1:ncol(finish.loadings), function(i) {
    rownames(pos.var.factor)[pos.var.factor[, 2] == i]
  })
  names(var.factor) <- paste("FA", 1:ncol(finish.loadings), sep = "")
  names.pos.var.factor <- rownames(pos.var.factor)
  names(ideotype.D) <- colnames(means)
  names(ideotype.U) <- colnames(means)
  ideotype.D.test <- as.numeric(gsub("[^0-9]", "", x = ideotype.D))
  ideotype.U.test <- as.numeric(gsub("[^0-9]", "", x = ideotype.U))
  names(ideotype.D.test) <- colnames(means)
  names(ideotype.U.test) <- colnames(means)
  ideotype.D.test <- ideotype.D.test[names.pos.var.factor]
  ideotype.U.test <- ideotype.U.test[names.pos.var.factor]
  canonical.loadings.factor <- canonical.loadings[names.pos.var.factor, ]
  ideotype.factor.D <- ideotype.D[names.pos.var.factor]
  ideotype.factor.U <- ideotype.U[names.pos.var.factor]
  id.D <- rev(paste("D", 1:ncol(finish.loadings), sep = ""))
  id.U <- rev(paste("U", 1:ncol(finish.loadings), sep = ""))
  D.U <- rbind(id.D, id.U)
  groups.factor <- lapply(1:ncol(finish.loadings), function(i) {
    D.U[, i]
  })
  construction.ideotypes <- as.matrix(rev(expand.grid(groups.factor)))
  colnames(construction.ideotypes) <- paste("Factor", 1:ncol(construction.ideotypes), sep = "")
  D <- numeric(0)
  U <- numeric(0)
  normalize.means.factor <- normalize.means[, names.pos.var.factor]
  for (i in 1:ncol(normalize.means)) {
    if (is.na(ideotype.D.test[i])) {
      if (ideotype.factor.D[i] == "max") {
        D <- c(D, max(normalize.means.factor[, i]))
      }
      if (ideotype.factor.D[i] == "min") {
        D <- c(D, min(normalize.means.factor[, i]))
      }
      if (ideotype.factor.D[i] == "mean") {
        D <- c(D, mean(normalize.means.factor[, i]))
      }
    }
    if (!is.na(ideotype.D.test[i])) {
      D <- c(D, as.numeric(ideotype.factor.D[i]))
    }
    if (is.na(ideotype.U.test[i])) {
      if (ideotype.factor.U[i] == "max") {
        U <- c(U, max(normalize.means.factor[, i]))
      }
      if (ideotype.factor.U[i] == "min") {
        U <- c(U, min(normalize.means.factor[, i]))
      }
      if (ideotype.factor.U[i] == "mean") {
        U <- c(U, mean(normalize.means.factor[, i]))
      }
    }
    if (!is.na(ideotype.U.test[i])) {
      U <- c(U, as.numeric(ideotype.factor.U[i]))
    }
  }
  names(D) <- names(ideotype.factor.D)
  names(U) <- names(ideotype.factor.U)
  Di <- lapply(1:ncol(finish.loadings), function(i) {
    D[pos.var.factor[, 2] == i]
  })
  Ui <- lapply(1:ncol(finish.loadings), function(i) {
    U[pos.var.factor[, 2] == i]
  })
  names(Di) <- paste("D", 1:ncol(finish.loadings), sep = "")
  names(Ui) <- paste("U", 1:ncol(finish.loadings), sep = "")
  comb.U.D <- c(Di, Ui)
  ideotypes.matrix <- matrix(0, IN, ncol(means))
  for (i in 1:IN) {
    ideotypes.matrix[i, ] <- unlist(comb.U.D[construction.ideotypes[i, ]])
  }
  rownames(ideotypes.matrix) <- paste("ID", 1:IN, sep = "")
  colnames(ideotypes.matrix) <- colnames(normalize.means.factor)
  ideotypes.scores <- ideotypes.matrix %*% canonical.loadings.factor
  sd.scores <- scale(rbind(scores, ideotypes.scores),
                     center = FALSE,
                     scale = apply(rbind(scores, ideotypes.scores), 2, sd))
  DE <- dist(sd.scores)
  DEM <- as.matrix(sqrt((1/ncol(scores)) * ((DE)^2)))
  GID <- DEM[1:nrow(scores), (nrow(scores) + 1):nrow(sd.scores)]
  spatial.prob <- (1/GID)/(replicate(IN, c(as.numeric(apply((1/GID), 1, sum)))))
  ideotype.rank <- lapply(1:IN, function(i) {
    sort(spatial.prob[, i] %>% replace_na(replace = 0), decreasing = TRUE)
  })
  names(ideotype.rank) <- paste("ID", 1:IN, sep = "")
  means.factor <- means[, names.pos.var.factor]
  if (!is.null(ngs)) {
    selection.diferential <- lapply(1:IN, function(i) {
      data.frame(cbind(Factor = pos.var.factor[, 2],
                       Xo = colMeans(means.factor),
                       Xs = colMeans(means.factor[names(ideotype.rank[[i]])[1:ngs],]),
                       SD = colMeans(means.factor[names(ideotype.rank[[i]])[1:ngs],]) - colMeans(means.factor),
                       SDperc = (colMeans(means.factor[names(ideotype.rank[[i]])[1:ngs], ]) - colMeans(means.factor))/abs(colMeans(means.factor)) * 100)) %>%
        rownames_to_column("VAR")
    })
    names(selection.diferential) <- paste("ID", 1:IN, sep = "")

    if(has_class(.data, "gamem")){
      h2 <- gmd(.data, "h2", verbose = FALSE)
      selection.diferential <-
        lapply(selection.diferential, function(x){
          left_join(x, h2, by = "VAR") %>%
            add_cols(SG = SD * h2,
                     SGperc = SG / Xo * 100)
        })
    }
    if(is.character(DI)){
      vars <-
        tibble(VAR = colnames(means),
               sense = ideotype.D) %>%
        mutate(sense = case_when(sense == "max" ~ "increase",
                                 sense == "min" ~ "decrease",
                                 sense == "mean" ~ "keep",
                                 !sense  %in% c("max", "min", "mean") ~ "none"))
      selection.diferential <-
        lapply(selection.diferential, function(x){
          left_join(x, vars, by = "VAR") %>%
            mutate(goal = case_when(
              sense == "decrease" & SDperc < 0  |  sense == "increase" & SDperc > 0 ~ 100,
              TRUE ~ 0
            ))
        })
      total_gain <-
        lapply(selection.diferential, function(x){
          desc_stat(x,
                    by = sense,
                    any_of(c("SDperc", "SGperc")),
                    stats = c("min, mean, max, sum"))
        })
    } else{
      total_gain <- NULL
    }
  }
  if (is.null(ngs)) {
    selection.diferential <- NULL
  }
  if (verbose == TRUE) {
    cat("\n-----------------------------------------------------------------------------------\n")
    cat("Principal Component Analysis\n")
    cat("-----------------------------------------------------------------------------------\n")
    print(round_cols(pca, digits = 2))
    cat("\n-----------------------------------------------------------------------------------\n")
    cat("Factor Analysis\n")
    cat("-----------------------------------------------------------------------------------\n")
    print(round_cols(fa, digits = 2))
    cat("\n-----------------------------------------------------------------------------------\n")
    cat("Comunalit Mean:", mean(comunalits), "\n")
    if (!is.null(ngs)) {
      cat("Selection differential\n")
      cat("-----------------------------------------------------------------------------------\n")
      print(selection.diferential$ID1)
      cat("\n-----------------------------------------------------------------------------------\n")
      cat("Selected genotypes\n")
      cat(names(ideotype.rank[[1]])[1:ngs])
      cat("\n-----------------------------------------------------------------------------------\n")
    }
  }
  return(structure(list(data = means,
                        cormat = cor.means,
                        eigen = data.frame(pca) %>% rownames_to_column("PC") %>% as_tibble(),
                        FA = data.frame(fa) %>% rownames_to_column("Variable") %>% as_tibble(),
                        canonical_loadings = data.frame(canonical.loadings) %>% rownames_to_column("Variable") %>% as_tibble(),
                        FAI = data.frame(ideotype.rank) %>% rownames_to_column("Genotype") %>% as_tibble(),
                        sel_dif_trait = selection.diferential,
                        sel_gen = names(ideotype.rank[[1]])[1:ngs],
                        construction_ideotypes = construction.ideotypes,
                        total_gain = total_gain),
                   class = "fai_blup"))
}






#' Multi-trait selection index
#'
#' Plot the multitrait index based on factor analysis and ideotype-design
#' proposed by Rocha et al. (2018).
#'
#'
#' @param x An object of class `waasb`
#' @param ideotype The ideotype to be plotted. Default is 1.
#' @param SI An integer (0-100). The selection intensity in percentage of the
#'   total number of genotypes.
#' @param radar Logical argument. If true (default) a radar plot is generated
#'   after using `coord_polar()`.
#' @param arrange.label Logical argument. If `TRUE`, the labels are
#'   arranged to avoid text overlapping. This becomes useful when the number of
#'   genotypes is large, say, more than 30.
#' @param size.point The size of the point in graphic. Defaults to 2.5.
#' @param size.line The size of the line in graphic. Defaults to 0.7.
#' @param size.text The size for the text in the plot. Defaults to 10.
#' @param col.sel The colour for selected genotypes. Defaults to `"red"`.
#' @param col.nonsel The colour for nonselected genotypes. Defaults to `"black"`.
#' @param ... Other arguments to be passed from ggplot2::theme().
#' @author Tiago Olivoto \email{tiagoolivoto@@gmail.com}
#' @references
#' Rocha, J.R.A.S.C.R, J.C. Machado, and P.C.S. Carneiro. 2018. Multitrait index
#' based on factor analysis and ideotype-design: proposal and application on
#' elephant grass breeding for bioenergy. GCB Bioenergy 10:52-60.
#' \doi{10.1111/gcbb.12443}
#'
#' @method plot fai_blup
#' @export
#' @return An object of class `gg, ggplot`.
#' @examples
#' \donttest{
#' library(metan)
#'
#' mod <- waasb(data_ge,
#'              env = ENV,
#'              gen = GEN,
#'              rep = REP,
#'              resp = c(GY, HM))
#'
#' FAI <- fai_blup(mod,
#'                 DI = c('max, max'),
#'                 UI = c('min, min'))
#' plot(FAI)
#' }
#'
plot.fai_blup <- function(x,
                          ideotype = 1,
                          SI = 15,
                          radar = TRUE,
                          arrange.label = FALSE,
                          size.point = 2.5,
                          size.line = 0.7,
                          size.text = 10,
                          col.sel = "red",
                          col.nonsel = "black",
                          ...) {

  data <- x$FAI %>%
    select_cols(Genotype, paste("ID", ideotype, sep = "")) %>%
  add_cols(sel = "Selected") %>%
    set_names("Genotype", "FAI", "sel")
  data[["sel"]][(round(nrow(data) * (SI/100), 0) + 1):nrow(data)] <- "Nonselected"
  cutpoint <- min(subset(data, sel == "Selected")$FAI)
  p <- ggplot(data = data, aes(x = reorder(Genotype, FAI), y = FAI)) +
    geom_hline(yintercept = cutpoint, col = col.sel, size = size.line) +
    geom_path(colour = "black", group = 1, size = size.line) +
    geom_point(size = size.point, aes(fill = sel), shape = 21, colour = "black", stroke  = size.point / 10) +
    scale_x_discrete() +
    theme_minimal() +
    theme(legend.position = "bottom",
          legend.title = element_blank(),
          axis.title.x = element_blank(),
          panel.border = element_blank(),
          axis.text = element_text(colour = "black"),
          text = element_text(size = size.text),
          ...) +
    labs(x = "", y = "FAI-BLUP") +
    scale_fill_manual(values = c(col.nonsel, col.sel))
  if (radar == TRUE) {
    if(arrange.label == TRUE){
      tot_gen <- length(unique(data$Genotype))
      fseq <- c(1:(tot_gen/2))
      sseq <- c((tot_gen/2 + 1):tot_gen)
      fang <- c(90 - 180/length(fseq) * fseq)
      sang <- c(-90 - 180/length(sseq) * sseq)
      p <- p +
        coord_polar() +
        theme(axis.text.x = element_text(angle = c(fang, sang)),
              legend.margin = margin(-120, 0, 0, 0), ...)
    } else{
      p <- p + coord_polar()
    }
  }
  return(p)
}
