# Source reference only. Requires separately authorised participant data and the private project structure.
# Not part of the aggregate-only reproduction command. Do not run in an AI-connected environment.
if (Sys.getenv("CPD_AUTHORIZED_LOCAL_REFERENCE_RUN") != "YES")
  stop("Reference module: independent authorised local environment and missing private dependencies required.")
options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(mice)
  library(survey)
  library(metafor)
  library(splines)
})

options(survey.lonely.psu = "adjust")

study_id <- "cpd_multicohort_01"
root <- "."
input_dir <- file.path(root, "data/02_analytic", study_id, "v1.1")
model_dir <- file.path(root, "data/03_outputs", study_id, "models")
table_dir <- file.path(root, "data/03_outputs", study_id, "tables")
qa_dir <- file.path(root, "data/03_outputs", study_id, "qa")
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(table_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

cohorts <- c("HRS", "SHARE", "CHARLS")
m_imputations <- 20L
max_iterations <- c(HRS = 10L, SHARE = 5L, CHARLS = 5L)
seeds <- c(HRS = 200811L, SHARE = 200812L, CHARLS = 200813L)
phenotype_levels <- c("neither", "cancer_only", "pain_only", "cancer_and_pain")

pool_scalar_manual <- function(q, u) {
  keep <- is.finite(q) & is.finite(u) & u >= 0
  q <- q[keep]
  u <- u[keep]
  m <- length(q)
  if (!m) stop("No finite estimates available for pooling")
  qbar <- mean(q)
  ubar <- mean(u)
  between <- if (m > 1) var(q) else 0
  total <- ubar + (1 + 1 / m) * between
  relative_increase <- if (ubar > 0) ((1 + 1 / m) * between) / ubar else 0
  df <- if (relative_increase > 0) {
    (m - 1) * (1 + 1 / relative_increase)^2
  } else {
    Inf
  }
  se <- sqrt(total)
  critical <- if (is.finite(df)) qt(0.975, df) else qnorm(0.975)
  statistic <- if (se > 0) qbar / se else NA_real_
  p_value <- if (!is.finite(statistic)) {
    NA_real_
  } else if (is.finite(df)) {
    2 * pt(abs(statistic), df, lower.tail = FALSE)
  } else {
    2 * pnorm(abs(statistic), lower.tail = FALSE)
  }
  data.table(
    estimate = qbar,
    se = se,
    conf_low = qbar - critical * se,
    conf_high = qbar + critical * se,
    df = df,
    p_value = p_value,
    within_variance = ubar,
    between_variance = between,
    relative_increase_variance = relative_increase,
    m = m
  )
}

contrast_vectors <- function(coefficient_names) {
  zero <- setNames(rep(0, length(coefficient_names)), coefficient_names)
  make <- function(values) {
    out <- zero
    valid <- intersect(names(values), names(out))
    out[valid] <- values[valid]
    out
  }
  list(
    cancer_and_pain_vs_neither = make(c(phenotypecancer_and_pain = 1)),
    cancer_and_pain_vs_cancer_only = make(c(
      phenotypecancer_and_pain = 1,
      phenotypecancer_only = -1
    )),
    pain_only_vs_neither = make(c(phenotypepain_only = 1)),
    cancer_only_vs_neither = make(c(phenotypecancer_only = 1))
  )
}

prepare_data <- function(cohort_name) {
  d <- as.data.table(readRDS(file.path(
    input_dir,
    paste0(tolower(cohort_name), "_persistence_intervals_v1.1.rds")
  )))[analysis_eligible == TRUE]
  d[, phenotype := factor(phenotype, levels = phenotype_levels)]
  d[, transition := factor(transition)]
  d[, education3 := factor(education3, levels = 1:3)]
  d[, partnered := factor(partnered, levels = 0:1)]
  d[, current_smoking := factor(current_smoking, levels = 0:1)]
  d[, wealth_quintile := factor(wealth_quintile, levels = 1:5)]
  d[, event := as.numeric(event)]
  if (cohort_name == "SHARE") d[, country := factor(country)]
  d
}

impute_data <- function(d, cohort_name) {
  analysis_vars <- c(
    "event", "phenotype", "age", "female", "education3", "partnered",
    "depressive_score", "noncancer_comorbidity_count", "current_smoking",
    "wealth_quintile", "transition", "analysis_weight_norm", "person_id"
  )
  design_vars <- if (cohort_name == "HRS") {
    c("stratum", "half_sample")
  } else if (cohort_name == "SHARE") {
    c("country", "household_id")
  } else {
    c("community_id")
  }
  imp_data <- as.data.frame(d[, c(analysis_vars, design_vars), with = FALSE])
  setup <- mice(imp_data, maxit = 0, printFlag = FALSE)
  method <- setup$method
  predictor <- setup$predictorMatrix

  fixed <- intersect(c(
    "event", "phenotype", "age", "female", "depressive_score", "transition",
    "analysis_weight_norm", "person_id", "stratum", "half_sample",
    "household_id", "community_id", "country"
  ), names(imp_data))
  method[fixed] <- ""
  nonpredictors <- intersect(c(
    "analysis_weight_norm", "person_id", "stratum", "half_sample",
    "household_id", "community_id"
  ), names(imp_data))
  predictor[, nonpredictors] <- 0
  predictor[nonpredictors, ] <- 0

  method["education3"] <- if (anyNA(imp_data$education3)) "polyreg" else ""
  method["partnered"] <- if (anyNA(imp_data$partnered)) "logreg" else ""
  method["current_smoking"] <- if (anyNA(imp_data$current_smoking)) "logreg" else ""
  method["wealth_quintile"] <- if (anyNA(imp_data$wealth_quintile)) "polyreg" else ""
  method["noncancer_comorbidity_count"] <-
    if (anyNA(imp_data$noncancer_comorbidity_count)) "pmm" else ""

  mice(
    imp_data,
    m = m_imputations,
    maxit = max_iterations[[cohort_name]],
    method = method,
    predictorMatrix = predictor,
    seed = seeds[[cohort_name]],
    printFlag = FALSE
  )
}

make_design <- function(completed, cohort_name, weight_variable = "analysis_weight_norm") {
  completed$analysis_weight_current <- completed[[weight_variable]]
  if (cohort_name == "HRS") {
    svydesign(
      ids = ~half_sample + person_id,
      strata = ~stratum,
      weights = ~analysis_weight_current,
      data = completed,
      nest = TRUE
    )
  } else if (cohort_name == "SHARE") {
    completed$household_cluster <- interaction(
      completed$country, completed$household_id, drop = TRUE
    )
    svydesign(
      ids = ~household_cluster + person_id,
      strata = ~country,
      weights = ~analysis_weight_current,
      data = completed,
      nest = TRUE
    )
  } else {
    svydesign(
      ids = ~community_id + person_id,
      weights = ~analysis_weight_current,
      data = completed,
      nest = TRUE
    )
  }
}

model_formula <- function(cohort_name) {
  rhs <- paste(
    "phenotype + ns(age, df = 3) + female + education3 + partnered +",
    "depressive_score + noncancer_comorbidity_count + current_smoking +",
    "wealth_quintile + transition"
  )
  if (cohort_name == "SHARE") rhs <- paste(rhs, "+ country")
  as.formula(paste("event ~", rhs))
}

standardized_estimates <- function(model, completed, cohort_name, imputation) {
  beta <- coef(model)
  covariance <- vcov(model)
  if (any(!is.finite(beta)) || any(!is.finite(covariance))) {
    stop("Non-finite coefficient or covariance in standardized estimate")
  }
  weights <- completed$analysis_weight_norm
  weights <- weights / sum(weights)
  terms_no_response <- delete.response(terms(model))

  risk_rows <- list()
  gradients <- list()
  prediction_qa <- list()
  for (level in phenotype_levels) {
    newdata <- completed
    newdata$phenotype <- factor(level, levels = phenotype_levels)
    matrix <- model.matrix(terms_no_response, data = newdata)
    matrix <- matrix[, names(beta), drop = FALSE]
    linear <- as.numeric(matrix %*% beta)
    predicted <- exp(linear)
    risk <- sum(weights * predicted)
    gradient <- colSums(matrix * as.numeric(weights * predicted))
    variance <- as.numeric(t(gradient) %*% covariance %*% gradient)
    risk_rows[[level]] <- data.table(
      cohort = cohort_name,
      imputation = imputation,
      phenotype = level,
      estimate_type = "standardized_risk_poisson",
      estimate = risk,
      variance = variance
    )
    gradients[[level]] <- gradient
    prediction_qa[[level]] <- data.table(
      cohort = cohort_name,
      imputation = imputation,
      phenotype = level,
      predicted_min = min(predicted),
      predicted_median = median(predicted),
      predicted_max = max(predicted),
      predicted_above_one_n = sum(predicted > 1),
      predicted_above_one_pct = mean(predicted > 1) * 100
    )
  }

  contrasts <- list(
    cancer_and_pain_vs_neither = c("cancer_and_pain", "neither"),
    cancer_and_pain_vs_cancer_only = c("cancer_and_pain", "cancer_only"),
    pain_only_vs_neither = c("pain_only", "neither"),
    cancer_only_vs_neither = c("cancer_only", "neither")
  )
  risk_values <- setNames(
    vapply(risk_rows, function(x) x$estimate, numeric(1)),
    names(risk_rows)
  )
  rd_rows <- rbindlist(lapply(names(contrasts), function(contrast_name) {
    pair <- contrasts[[contrast_name]]
    gradient <- gradients[[pair[1]]] - gradients[[pair[2]]]
    data.table(
      cohort = cohort_name,
      imputation = imputation,
      contrast = contrast_name,
      estimate_type = "standardized_risk_difference_poisson",
      estimate = risk_values[[pair[1]]] - risk_values[[pair[2]]],
      variance = as.numeric(t(gradient) %*% covariance %*% gradient)
    )
  }))

  list(
    risks = rbindlist(risk_rows),
    risk_differences = rd_rows,
    prediction_qa = rbindlist(prediction_qa)
  )
}

fit_models <- function(imp, cohort_name) {
  contrast_rows <- list()
  coefficient_rows <- list()
  risk_rows <- list()
  risk_difference_rows <- list()
  prediction_qa_rows <- list()

  for (imputation in seq_len(imp$m)) {
    completed <- complete(imp, action = imputation)
    design <- make_design(completed, cohort_name)
    model <- svyglm(
      model_formula(cohort_name),
      design = design,
      family = quasipoisson(link = "log")
    )
    beta <- coef(model)
    covariance <- vcov(model)
    if (any(!is.finite(beta)) || any(!is.finite(covariance))) {
      stop("Non-finite persistence outcome model for ", cohort_name, " imputation ", imputation)
    }

    contrasts <- contrast_vectors(names(beta))
    for (contrast_name in names(contrasts)) {
      vector <- contrasts[[contrast_name]]
      contrast_rows[[length(contrast_rows) + 1L]] <- data.table(
        cohort = cohort_name,
        imputation = imputation,
        contrast = contrast_name,
        log_rr = sum(vector * beta),
        variance = as.numeric(t(vector) %*% covariance %*% vector)
      )
    }
    coefficient_rows[[length(coefficient_rows) + 1L]] <- data.table(
      cohort = cohort_name,
      imputation = imputation,
      term = names(beta),
      estimate = as.numeric(beta),
      standard_error = sqrt(diag(covariance))
    )

    standardized <- standardized_estimates(model, completed, cohort_name, imputation)
    risk_rows[[length(risk_rows) + 1L]] <- standardized$risks
    risk_difference_rows[[length(risk_difference_rows) + 1L]] <-
      standardized$risk_differences
    prediction_qa_rows[[length(prediction_qa_rows) + 1L]] <-
      standardized$prediction_qa
  }

  list(
    contrasts = rbindlist(contrast_rows),
    coefficients = rbindlist(coefficient_rows),
    risks = rbindlist(risk_rows),
    risk_differences = rbindlist(risk_difference_rows),
    prediction_qa = rbindlist(prediction_qa_rows)
  )
}

pool_rr <- function(d) {
  pooled <- pool_scalar_manual(d$log_rr, d$variance)
  pooled[, `:=`(
    log_rr = estimate,
    rr = exp(estimate),
    conf_low_rr = exp(conf_low),
    conf_high_rr = exp(conf_high)
  )]
  pooled
}

pool_identity <- function(d) pool_scalar_manual(d$estimate, d$variance)

all_contrasts <- list()
all_coefficients <- list()
all_risks <- list()
all_risk_differences <- list()
all_prediction_qa <- list()
all_pooled_rr <- list()
all_pooled_risks <- list()
all_pooled_risk_differences <- list()
model_counts <- list()

for (cohort_name in cohorts) {
  message("Preparing persistence model: ", cohort_name)
  d <- prepare_data(cohort_name)
  mids_file <- file.path(
    model_dir,
    paste0(tolower(cohort_name), "_persistence_mice_m20_v1.1.rds")
  )
  if (file.exists(mids_file)) {
    imp <- readRDS(mids_file)
  } else {
    imp <- impute_data(d, cohort_name)
    saveRDS(imp, mids_file, compress = "xz")
  }
  fitted <- fit_models(imp, cohort_name)

  all_contrasts[[cohort_name]] <- fitted$contrasts
  all_coefficients[[cohort_name]] <- fitted$coefficients
  all_risks[[cohort_name]] <- fitted$risks
  all_risk_differences[[cohort_name]] <- fitted$risk_differences
  all_prediction_qa[[cohort_name]] <- fitted$prediction_qa

  pooled_rr <- fitted$contrasts[, pool_rr(.SD), by = contrast]
  pooled_rr[, `:=`(
    cohort = cohort_name,
    estimand = "persistence",
    n_intervals = nrow(d),
    n_persons = uniqueN(d$person_id),
    events = sum(d$event),
    analysis_method = paste0("multiple_imputation_m", m_imputations)
  )]
  all_pooled_rr[[cohort_name]] <- pooled_rr

  pooled_risks <- fitted$risks[, pool_identity(.SD), by = phenotype]
  pooled_risks[, `:=`(
    cohort = cohort_name,
    estimand = "persistence",
    estimate_type = "standardized_risk_poisson"
  )]
  all_pooled_risks[[cohort_name]] <- pooled_risks

  pooled_rd <- fitted$risk_differences[, pool_identity(.SD), by = contrast]
  pooled_rd[, `:=`(
    cohort = cohort_name,
    estimand = "persistence",
    estimate_type = "standardized_risk_difference_poisson"
  )]
  all_pooled_risk_differences[[cohort_name]] <- pooled_rd

  model_counts[[cohort_name]] <- d[, .(
    n_intervals = .N,
    n_persons = uniqueN(person_id),
    events = sum(event),
    remissions = sum(event == 0)
  ), by = .(cohort, phenotype)]
  message("Completed persistence model: ", cohort_name)
}

contrasts <- rbindlist(all_contrasts)
coefficients <- rbindlist(all_coefficients)
risks <- rbindlist(all_risks)
risk_differences <- rbindlist(all_risk_differences)
prediction_qa <- rbindlist(all_prediction_qa)
pooled_rr <- rbindlist(all_pooled_rr, fill = TRUE)
pooled_risks <- rbindlist(all_pooled_risks, fill = TRUE)
pooled_risk_differences <- rbindlist(all_pooled_risk_differences, fill = TRUE)
counts <- rbindlist(model_counts)

meta_rows <- list()
for (contrast_name in unique(pooled_rr$contrast)) {
  d <- pooled_rr[contrast == contrast_name]
  fit <- rma.uni(
    yi = d$log_rr,
    sei = d$se,
    method = "REML",
    test = "knha",
    slab = d$cohort
  )
  prediction <- predict(fit)
  meta_rows[[contrast_name]] <- data.table(
    cohort = "Random-effects meta-analysis",
    estimand = "persistence",
    contrast = contrast_name,
    n_intervals = sum(d$n_intervals),
    n_persons = NA_integer_,
    events = sum(d$events),
    log_rr = as.numeric(fit$b),
    se = fit$se,
    rr = exp(as.numeric(fit$b)),
    conf_low_rr = exp(fit$ci.lb),
    conf_high_rr = exp(fit$ci.ub),
    p_value = fit$pval,
    prediction_low_rr = exp(prediction$pi.lb),
    prediction_high_rr = exp(prediction$pi.ub),
    tau2 = fit$tau2,
    i2 = fit$I2,
    q_p_value = fit$QEp,
    k = fit$k
  )
}
meta_results <- rbindlist(meta_rows, fill = TRUE)

fwrite(contrasts, file.path(model_dir, "persistence_imputation_specific_contrasts_v1.1.csv"), bom = TRUE)
fwrite(coefficients, file.path(model_dir, "persistence_imputation_specific_coefficients_v1.1.csv"), bom = TRUE)
fwrite(pooled_rr, file.path(model_dir, "persistence_adjusted_risk_ratios_mi_v1.1.csv"), bom = TRUE)
fwrite(meta_results, file.path(model_dir, "persistence_random_effects_meta_v1.1.csv"), bom = TRUE)
fwrite(risks, file.path(model_dir, "persistence_imputation_specific_standardized_risks_v1.1.csv"), bom = TRUE)
fwrite(risk_differences, file.path(model_dir, "persistence_imputation_specific_risk_differences_v1.1.csv"), bom = TRUE)
fwrite(pooled_risks, file.path(table_dir, "persistence_adjusted_absolute_risks_v1.1.csv"), bom = TRUE)
fwrite(pooled_risk_differences, file.path(table_dir, "persistence_adjusted_risk_differences_v1.1.csv"), bom = TRUE)
fwrite(prediction_qa, file.path(qa_dir, "persistence_poisson_prediction_range_qa_v1.1.csv"), bom = TRUE)
fwrite(counts, file.path(model_dir, "persistence_model_counts_v1.1.csv"), bom = TRUE)
capture.output(sessionInfo(), file = file.path(qa_dir, "session_info_40_persistence_core_absolute_risks_v1.1.txt"))

print(pooled_rr[, .(cohort, contrast, rr, conf_low_rr, conf_high_rr, p_value)])
print(meta_results[, .(
  contrast, rr, conf_low_rr, conf_high_rr,
  prediction_low_rr, prediction_high_rr, i2
)])
print(pooled_risks[, .(cohort, phenotype, estimate, conf_low, conf_high)])
cat("Persistence core and absolute-risk models completed.\n")
