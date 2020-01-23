output$missPlot <- renderPlot(
  plotMissings(exposom$exp, set = "exposures")
)
output$exp_normality_graph <- renderPlot({
  exp_index = input$exp_normality_rows_selected
  exp_title = paste0(exposom$nm[[1]][exp_index], " - Histogram")
  plotHistogram(exposom$exp, select = exposom$nm[[1]][exp_index]) + ggtitle(exp_title)
})
output$exp_behaviour <- renderPlot({
  family_selected = input$family
  group_selected = input$group
  group_selected2 = input$group2
  if (group_selected != "None" && group_selected2 != "None") {
    plotFamily(exposom$exp, family = family_selected, group = group_selected,
               group2 = group_selected2)
  }
  else if (group_selected != "None" && group_selected2 == "None") {
    plotFamily(exposom$exp, family = family_selected, group = group_selected)
  }
  else if (group_selected == "None" && group_selected2 != "None") {
    plotFamily(exposom$exp, family = family_selected, group2 = group_selected2)
  }
  else {plotFamily(exposom$exp, family = family_selected)}
})
output$exp_pca <- renderPlot({
  set_pca = input$pca_set
  pheno_pca = input$group_pca
  if (set_pca == "samples" && pheno_pca != "None") {
    plotPCA(exposom$exp_pca, set = set_pca, phenotype = pheno_pca)
  }
  else {plotPCA(exposom$exp_pca, set = set_pca)}
})
output$exp_correlation <- renderPlot({
  type <- input$exp_corr_choice
  exp_cr <- correlation(exposom$exp, use = "pairwise.complete.obs", method.cor = "pearson")
  if (type == "Matrix") {
    plotCorrelation(exp_cr, type = "matrix")
  }
  else {
    plotCorrelation(exp_cr, type = "circos")
  }
})
output$ind_clustering <- renderPlot({
  hclust_data <- function(data, ...) {
    hclust(d = dist(x = data), ...)
  }
  hclust_k3 <- function(result) {
    cutree(result, k = 3)
  }
  exp_c <- clustering(exposom$exp, method = hclust_data, cmethod = hclust_k3)
  plotClassification(exp_c)
})
output$exp_association <- renderPlot({
  if (input$ass_choice == "Exposures to the principal components") {
    plotEXP(exposom$exp_pca) + theme(axis.text.y = element_text(size = 6.5)) + ylab("")
  }
  else {
    plotPHE(exposom$exp_pca)
  }
})
output$exwas_as <- renderPlot({
  outcome <- input$exwas_outcome
  cov <- input$exwas_covariables
  family_out <- input$exwas_output_family
  cfa <- paste0("length(levels(as.factor(exposom$exp$", outcome, 
                ")))!= 2 && family_out == 'binomial'")
  cfa_b <- eval(str2lang(cfa))
  cfb <- paste0("!is(exposom$exp$", outcome, ", 'numeric')")
  cfb_b <- eval(str2lang(cfb))
  if (cfa_b == TRUE) {
    shinyalert("Oops!", "Select the proper distribution for that outcome (outcome not binomial)",
               type = "warning")
  }
 # else if (cfb_b == TRUE) {
  #  shinyalert("Oops!", "Non numeric outcome variable selected",
  #             type = "warning")
#  }
  else {
  formula_plot <- paste(outcome, "~ 1")
  if (length(cov) > 0) {
    for (i in 1:length(cov)) {
      formula_plot <- paste(formula_plot, "+", cov[i])
    }
  }
  formula_plot <- as.formula(formula_plot)
  fl <- exwas(exposom$exp, formula = formula_plot,
              family = family_out)
  exposom$exwas_eff <- 0.05/fl@effective
  clr <- rainbow(length(familyNames(exposom$exp)))
  names(clr) <- familyNames(exposom$exp)
  if (input$exwas_choice == "Manhattan-like plot") {
    plotExwas(fl, color = clr) + 
      ggtitle("Exposome Association Study - Univariate Approach")}
  else {plotEffect(fl)}
  }
})
output$mea <- renderPlot({
  outcome <- input$mexwas_outcome
  family_out <- input$mexwas_output_family
  cfa <- paste0("length(levels(as.factor(exposom$exp$", outcome, 
                ")))!= 2 && family_out == 'binomial'")
  cfa_b <- eval(str2lang(cfa))
  cfb <- paste0("!is(exposom$exp$", outcome, ", 'numeric')")
  cfb_b <- eval(str2lang(cfb))
  if (cfa_b == TRUE) {
    shinyalert("Oops!", "Select the proper distribution for that outcome (outcome not binomial)",
               type = "warning")
  }
  else if (cfb_b == TRUE) {
    shinyalert("Oops!", "Non numeric outcome variable selected",
               type = "warning")
  }
  else {
  if (anyNA(expos(exposom$exp)) == TRUE) {
    shinyalert("Info", "Performing separate imputation using mice to perform the MExWAS", 
               type = "info", timer = 5000, showConfirmButton = FALSE)
    withProgress(message = 'Imputing the missing values', value = 0, {
      dd <- read.csv(files$description, header=TRUE, stringsAsFactors=FALSE)
      ee <- read.csv(files$exposures, header=TRUE)
      pp <- read.csv(files$phenotypes, header=TRUE)
      
      rownames(ee) <- ee$idnum
      rownames(pp) <- pp$idnum
      
      incProgress(0.2)
      
      dta <- cbind(ee[ , -1], pp[ , -1])
      
      for (ii in 1:length(dta)) {
        if (length(levels(as.factor(dta[,ii]))) < 6) {
          dta[ , ii] <- as.factor(dta[ , ii])
        }
        else {
          dta[, ii] <- as.numeric(dta[ , ii])
        }
      }
      
      bd_column_inde <- grep("birthdate", colnames(dta))
      
      incProgress(0.5)
      imp <- mice(dta[ , -bd_column_inde], pred = quickpred(dta[ , -bd_column_inde],
                                                            mincor = 0.2, minpuc = 0.4), 
                  seed = 38788, m = 5, maxit = 10, printFlag = FALSE)
      
      incProgress(0.7)
      
      me <- NULL
      
      for(set in 1:5) {
        im <- mice::complete(imp, action = set)
        im[ , ".imp"] <- set
        im[ , ".id"] <- rownames(im)
        me <- rbind(me, im)
      }
      
      exp_imp <- loadImputed(data = me, description = dd, 
                             description.famCol = "Family", 
                             description.expCol = "Exposure")
      
      ex_1 <- toES(exp_imp, rid = 1)
      fl_m <- mexwas(ex_1, phenotype = outcome, family = family_out)
      browser()
    })
    plotExwas(fl_m) +
      ylab("") +
      ggtitle("Exposome Association Study - Multivariate Approach")
  }
  else {
    outcome <- input$mexwas_outcome
    family_out <- input$mexwas_output_family
    fl_m <- mexwas(exposom$exp, phenotype = outcome, family = family_out)
    plotExwas(fl_m) +
      ylab("") +
      ggtitle("Exposome Association Study - Multivariate Approach")
  }
  }
})
output$qqplot <- renderPlot({
  plotAssociation(omics$gexp, type = "qq") #+ 
    #ggplot2::ggtitle("Transcriptome - Pb Association")
})
output$volcan_plot <- renderPlot({
  browser()
  aux <- getAssociation(omics$gexp)
  pvalues <- aux$P.Value
  logfc <- aux$logFC
  names <- rownames(aux)
  volcano_plot_inter(pvalues, logfc, names)
})