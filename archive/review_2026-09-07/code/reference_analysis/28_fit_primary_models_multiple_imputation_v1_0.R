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
input_dir <- file.path(root, "data/02_analytic", study_id, "v1.0")
model_dir <- file.path(root, "data/03_outputs", study_id, "models")
qa_dir <- file.path(root, "data/03_outputs", study_id, "qa")
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

m_imputations <- 20L
max_iterations <- c(HRS = 10L, SHARE = 0L, CHARLS = 5L)
cohorts <- c("HRS", "SHARE", "CHARLS")
seeds <- c(HRS = 180811L, SHARE = 180812L, CHARLS = 180813L)

contrast_vectors <- function(coefficient_names) {
  zero <- setNames(rep(0, length(coefficient_names)), coefficient_names)
  make <- function(values) {
    out <- zero
    out[names(values)] <- values
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

pool_scalar_manual <- function(q, u) {
  m <- length(q)
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
  statistic <- qbar / se
  p_value <- if (is.finite(df)) 2 * pt(abs(statistic), df, lower.tail = FALSE) else
    2 * pnorm(abs(statistic), lower.tail = FALSE)
  data.table(
    log_rr = qbar,
    se = se,
    conf_low_log = qbar - critical * se,
    conf_high_log = qbar + critical * se,
    df = df,
    p_value = p_value,
    within_variance = ubar,
    between_variance = between,
    relative_increase_variance = relative_increase,
    m = m
  )
}

prepare_data <- function(cohort_name) {
  file <- file.path(input_dir, paste0(tolower(cohort_name), "_person_intervals_v1.0.rds"))
  d <- as.data.table(readRDS(file))[analysis_eligible == TRUE]
  d[, phenotype := factor(
    phenotype,
    levels = c("neither", "cancer_only", "pain_only", "cancer_and_pain")
  )]
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

  nonpredictors <- c(
    "analysis_weight_norm", "person_id", "stratum", "half_sample",
    "household_id", "community_id"
  )
  nonpredictors <- intersect(nonpredictors, names(imp_data))
  method[nonpredictors] <- ""
  predictor[, nonpredictors] <- 0
  predictor[nonpredictors, ] <- 0
  method["event"] <- ""
  method["phenotype"] <- ""
  method["age"] <- ""
  method["female"] <- ""
  method["depressive_score"] <- ""
  method["transition"] <- ""
  if ("country" %in% names(method)) method["country"] <- ""

  if (anyNA(imp_data$education3)) method["education3"] <- "polyreg" else method["education3"] <- ""
  if (anyNA(imp_data$partnered)) method["partnered"] <- "logreg" else method["partnered"] <- ""
  if (anyNA(imp_data$current_smoking)) method["current_smoking"] <- "logreg" else method["current_smoking"] <- ""
  if (anyNA(imp_data$wealth_quintile)) method["wealth_quintile"] <- "polyreg" else method["wealth_quintile"] <- ""
  if (anyNA(imp_data$noncancer_comorbidity_count)) {
    method["noncancer_comorbidity_count"] <- "pmm"
  } else {
    method["noncancer_comorbidity_count"] <- ""
  }

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

make_design <- function(completed, cohort_name) {
  if (cohort_name == "HRS") {
    svydesign(
      ids = ~half_sample + person_id,
      strata = ~stratum,
      weights = ~analysis_weight_norm,
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
      weights = ~analysis_weight_norm,
      data = completed,
      nest = TRUE
    )
  } else {
    svydesign(
      ids = ~community_id + person_id,
      weights = ~analysis_weight_norm,
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

fit_imputed_models <- function(imp, cohort_name) {
  contrast_values <- list()
  coefficients <- list()
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
    contrasts <- contrast_vectors(names(beta))
    for (contrast_name in names(contrasts)) {
      vector <- contrasts[[contrast_name]]
      contrast_values[[length(contrast_values) + 1]] <- data.table(
        cohort = cohort_name,
        imputation = imputation,
        contrast = contrast_name,
        estimate = sum(vector * beta),
        variance = as.numeric(t(vector) %*% covariance %*% vector)
      )
    }
    coefficients[[imputation]] <- data.table(
      cohort = cohort_name,
      imputation = imputation,
      term = names(beta),
      estimate = as.numeric(beta),
      standard_error = sqrt(diag(covariance))
    )
  }
  list(
    contrasts = rbindlist(contrast_values),
    coefficients = rbindlist(coefficients)
  )
}

fit_complete_case <- function(d, cohort_name) {
  vars <- c(
    "age", "female", "education3", "partnered", "depressive_score",
    "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
  )
  complete_d <- as.data.frame(d[complete.cases(d[, ..vars])])
  design <- make_design(complete_d, cohort_name)
  model <- svyglm(
    model_formula(cohort_name), design = design, family = quasipoisson(link = "log")
  )
  beta <- coef(model)
  covariance <- vcov(model)
  contrasts <- contrast_vectors(names(beta))
  rows <- rbindlist(lapply(names(contrasts), function(contrast_name) {
    vector <- contrasts[[contrast_name]]
    estimate <- sum(vector * beta)
    variance <- as.numeric(t(vector) %*% covariance %*% vector)
    data.table(
      cohort = cohort_name,
      contrast = contrast_name,
      n_intervals = nrow(complete_d),
      n_persons = uniqueN(complete_d$person_id),
      events = sum(complete_d$event),
      log_rr = estimate,
      se = sqrt(variance),
      rr = exp(estimate),
      conf_low = exp(estimate - qnorm(0.975) * sqrt(variance)),
      conf_high = exp(estimate + qnorm(0.975) * sqrt(variance)),
      p_value = 2 * pnorm(abs(estimate / sqrt(variance)), lower.tail = FALSE)
    )
  }))
  rows
}

all_imputation_contrasts <- list()
all_coefficients <- list()
all_primary_results <- list()
all_complete_case <- list()

for (cohort_name in cohorts) {
  message("Preparing ", cohort_name)
  d <- prepare_data(cohort_name)
  complete_case <- fit_complete_case(d, cohort_name)
  all_complete_case[[cohort_name]] <- complete_case

  if (cohort_name == "SHARE") {
    pooled <- copy(complete_case)
    pooled[, `:=`(
      df = Inf,
      m = 0L,
      within_variance = se^2,
      between_variance = NA_real_,
      relative_increase_variance = NA_real_,
      analysis_method = "complete_case_max_covariate_missingness_below_1pct"
    )]
    all_primary_results[[cohort_name]] <- pooled
  } else {
    mids_file <- file.path(model_dir, paste0(tolower(cohort_name), "_mice_m20_v1.0.rds"))
    if (file.exists(mids_file)) {
      message("Loading completed ", cohort_name, " imputation object")
      imp <- readRDS(mids_file)
    } else {
      message("Running ", m_imputations, " imputations x ", max_iterations[[cohort_name]], " iterations for ", cohort_name)
      imp <- impute_data(d, cohort_name)
      saveRDS(imp, mids_file, compress = "xz")
    }
    fitted <- fit_imputed_models(imp, cohort_name)
    all_imputation_contrasts[[cohort_name]] <- fitted$contrasts
    all_coefficients[[cohort_name]] <- fitted$coefficients

    pooled <- fitted$contrasts[, pool_scalar_manual(estimate, variance), by = contrast]
    pooled[, `:=`(
      cohort = cohort_name,
      rr = exp(log_rr),
      conf_low = exp(conf_low_log),
      conf_high = exp(conf_high_log),
      n_intervals = nrow(d),
      n_persons = uniqueN(d$person_id),
      events = sum(d$event),
      analysis_method = paste0("multiple_imputation_m", m_imputations)
    )]
    setcolorder(pooled, c(
      "cohort", "contrast", "n_intervals", "n_persons", "events",
      "log_rr", "se", "rr", "conf_low", "conf_high", "p_value", "df", "m",
      "analysis_method", "within_variance", "between_variance", "relative_increase_variance"
    ))
    all_primary_results[[cohort_name]] <- pooled
  }
  message("Completed ", cohort_name)
}

imputation_contrasts <- rbindlist(all_imputation_contrasts, fill = TRUE)
coefficients <- rbindlist(all_coefficients, fill = TRUE)
primary_results <- rbindlist(all_primary_results, fill = TRUE)
complete_case_results <- rbindlist(all_complete_case)

fwrite(imputation_contrasts, file.path(model_dir, "imputation_specific_contrasts_v1.0.csv"), bom = TRUE)
fwrite(coefficients, file.path(model_dir, "imputation_specific_coefficients_v1.0.csv"), bom = TRUE)
fwrite(primary_results, file.path(model_dir, "primary_adjusted_risk_ratios_mi_v1.0.csv"), bom = TRUE)
fwrite(complete_case_results, file.path(model_dir, "complete_case_adjusted_risk_ratios_v1.0.csv"), bom = TRUE)

meta_rows <- list()
for (contrast_name in unique(primary_results$contrast)) {
  d <- primary_results[contrast == contrast_name]
  model <- rma.uni(
    yi = d$log_rr,
    sei = d$se,
    method = "REML",
    test = "knha",
    slab = d$cohort
  )
  meta_rows[[length(meta_rows) + 1]] <- data.table(
    cohort = "Random-effects meta-analysis",
    contrast = contrast_name,
    n_intervals = sum(d$n_intervals),
    n_persons = NA_integer_,
    events = sum(d$events),
    log_rr = as.numeric(model$b),
    se = model$se,
    rr = exp(as.numeric(model$b)),
    conf_low = exp(model$ci.lb),
    conf_high = exp(model$ci.ub),
    p_value = model$pval,
    tau2 = model$tau2,
    i2 = model$I2,
    q_p_value = model$QEp,
    k = model$k
  )
}
meta_results <- rbindlist(meta_rows, fill = TRUE)
fwrite(meta_results, file.path(model_dir, "random_effects_meta_analysis_v1.0.csv"), bom = TRUE)

model_counts <- rbindlist(lapply(cohorts, function(cohort_name) {
  d <- prepare_data(cohort_name)
  data.table(
    cohort = cohort_name,
    n_intervals = nrow(d),
    n_persons = uniqueN(d$person_id),
    events = sum(d$event),
    cancer_and_pain_intervals = sum(d$phenotype == "cancer_and_pain"),
    cancer_and_pain_events = sum(d$event[d$phenotype == "cancer_and_pain"])
  )
}))
fwrite(model_counts, file.path(model_dir, "primary_model_counts_v1.0.csv"), bom = TRUE)
capture.output(sessionInfo(), file = file.path(qa_dir, "session_info_28_primary_models.txt"))

print(primary_results)
print(meta_results)
cat("Primary model outputs written to", model_dir, "\n")
