# Source reference only. Requires separately authorised participant data and the private project structure.
# Not part of the aggregate-only reproduction command. Do not run in an AI-connected environment.
if (Sys.getenv("CPD_AUTHORIZED_LOCAL_REFERENCE_RUN") != "YES")
  stop("Reference module: independent authorised local environment and missing private dependencies required.")
options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(mice)
  library(survey)
  library(splines)
})

options(survey.lonely.psu = "adjust")

study_id <- "cpd_multicohort_01"
input_dir <- file.path("data/02_analytic", study_id, "v1.1")
model_dir <- file.path("data/03_outputs", study_id, "models")
table_dir <- file.path("data/03_outputs", study_id, "tables")
qa_dir <- file.path("data/03_outputs", study_id, "qa")
cohorts <- c("HRS", "SHARE", "CHARLS")
phenotype_levels <- c("neither", "cancer_only", "pain_only", "cancer_and_pain")

pool_scalar <- function(q, u) {
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
  data.table(
    estimate = qbar,
    se = se,
    conf_low = qbar - critical * se,
    conf_high = qbar + critical * se,
    df = df,
    m = m,
    within_variance = ubar,
    between_variance = between
  )
}

make_design <- function(completed, cohort_name) {
  completed$analysis_weight_current <- completed$analysis_weight_norm
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

standardize_logistic <- function(model, completed, cohort_name, imputation) {
  beta <- coef(model)
  covariance <- vcov(model)
  if (any(!is.finite(beta)) || any(!is.finite(covariance))) {
    stop("Non-finite logistic standardization model: ", cohort_name, " ", imputation)
  }
  weights <- completed$analysis_weight_norm / sum(completed$analysis_weight_norm)
  terms_no_response <- delete.response(terms(model))
  risk_rows <- list()
  gradients <- list()

  for (level in phenotype_levels) {
    newdata <- completed
    newdata$phenotype <- factor(level, levels = phenotype_levels)
    matrix <- model.matrix(terms_no_response, data = newdata)
    matrix <- matrix[, names(beta), drop = FALSE]
    predicted <- plogis(as.numeric(matrix %*% beta))
    gradient <- colSums(matrix * as.numeric(weights * predicted * (1 - predicted)))
    risk_rows[[level]] <- data.table(
      cohort = cohort_name,
      imputation = imputation,
      phenotype = level,
      estimate = sum(weights * predicted),
      variance = as.numeric(t(gradient) %*% covariance %*% gradient),
      predicted_min = min(predicted),
      predicted_max = max(predicted)
    )
    gradients[[level]] <- gradient
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
      estimate = risk_values[[pair[1]]] - risk_values[[pair[2]]],
      variance = as.numeric(t(gradient) %*% covariance %*% gradient)
    )
  }))
  list(risks = rbindlist(risk_rows), risk_differences = rd_rows)
}

all_risks <- list()
all_risk_differences <- list()

for (cohort_name in cohorts) {
  message("Logistic standardization: ", cohort_name)
  imp <- readRDS(file.path(
    model_dir,
    paste0(tolower(cohort_name), "_persistence_mice_m20_v1.1.rds")
  ))
  cohort_risks <- list()
  cohort_rd <- list()
  for (imputation in seq_len(imp$m)) {
    completed <- complete(imp, action = imputation)
    completed$phenotype <- factor(completed$phenotype, levels = phenotype_levels)
    design <- make_design(completed, cohort_name)
    model <- svyglm(
      model_formula(cohort_name),
      design = design,
      family = quasibinomial(link = "logit")
    )
    standardized <- standardize_logistic(model, completed, cohort_name, imputation)
    cohort_risks[[imputation]] <- standardized$risks
    cohort_rd[[imputation]] <- standardized$risk_differences
  }
  all_risks[[cohort_name]] <- rbindlist(cohort_risks)
  all_risk_differences[[cohort_name]] <- rbindlist(cohort_rd)
}

risks <- rbindlist(all_risks)
risk_differences <- rbindlist(all_risk_differences)
pooled_risks <- risks[, pool_scalar(estimate, variance), by = .(cohort, phenotype)]
pooled_risks[, `:=`(
  estimand = "persistence",
  estimate_type = "marginal_standardized_risk_logistic"
)]
pooled_rd <- risk_differences[, pool_scalar(estimate, variance), by = .(cohort, contrast)]
pooled_rd[, `:=`(
  estimand = "persistence",
  estimate_type = "marginal_standardized_risk_difference_logistic"
)]

fwrite(
  risks,
  file.path(model_dir, "persistence_logistic_standardized_risks_imputation_specific_v1.1.csv"),
  bom = TRUE
)
fwrite(
  risk_differences,
  file.path(model_dir, "persistence_logistic_risk_differences_imputation_specific_v1.1.csv"),
  bom = TRUE
)
fwrite(
  pooled_risks,
  file.path(table_dir, "persistence_adjusted_absolute_risks_logistic_v1.1.csv"),
  bom = TRUE
)
fwrite(
  pooled_rd,
  file.path(table_dir, "persistence_adjusted_risk_differences_logistic_v1.1.csv"),
  bom = TRUE
)

decision_note <- c(
  "Absolute-risk model decision, SAP v1.1",
  "",
  "The modified-Poisson RR models remain the core relative-effect models.",
  "Poisson individual predictions exceeded 1 in up to approximately 2% of records in some standardized phenotype scenarios.",
  "Therefore, in accordance with the prespecified prediction-range gate, manuscript absolute risks and risk differences use survey-weighted logistic marginal standardization, which constrains individual predicted probabilities to 0-1.",
  "Poisson-standardized results are retained as diagnostics and are not deleted."
)
writeLines(
  decision_note,
  file.path(qa_dir, "persistence_absolute_risk_model_decision_v1.1.txt"),
  useBytes = TRUE
)
capture.output(
  sessionInfo(),
  file = file.path(qa_dir, "session_info_41_persistence_logistic_standardization_v1.1.txt")
)

print(pooled_risks)
print(pooled_rd)
cat("Logistic marginal standardization completed.\n")
