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
input_dir <- file.path("data/02_analytic", study_id, "v1.0")
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
  df <- if (relative_increase > 0) (m - 1) * (1 + 1 / relative_increase)^2 else Inf
  se <- sqrt(total)
  critical <- if (is.finite(df)) qt(0.975, df) else qnorm(0.975)
  data.table(
    estimate = qbar, se = se,
    conf_low = qbar - critical * se,
    conf_high = qbar + critical * se,
    df = df, m = m,
    within_variance = ubar, between_variance = between
  )
}

prepare_data <- function(cohort_name) {
  d <- as.data.table(readRDS(file.path(
    input_dir, paste0(tolower(cohort_name), "_person_intervals_v1.0.rds")
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

make_design <- function(d, cohort_name) {
  d$analysis_weight_current <- d$analysis_weight_norm
  if (cohort_name == "HRS") {
    svydesign(
      ids = ~half_sample + person_id, strata = ~stratum,
      weights = ~analysis_weight_current, data = d, nest = TRUE
    )
  } else if (cohort_name == "SHARE") {
    d$household_cluster <- interaction(d$country, d$household_id, drop = TRUE)
    svydesign(
      ids = ~household_cluster + person_id, strata = ~country,
      weights = ~analysis_weight_current, data = d, nest = TRUE
    )
  } else {
    svydesign(
      ids = ~community_id + person_id,
      weights = ~analysis_weight_current, data = d, nest = TRUE
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

standardize <- function(model, completed, cohort_name, imputation) {
  beta <- coef(model)
  covariance <- vcov(model)
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
      cohort = cohort_name, imputation = imputation, phenotype = level,
      estimate = sum(weights * predicted),
      variance = as.numeric(t(gradient) %*% covariance %*% gradient),
      predicted_min = min(predicted), predicted_max = max(predicted)
    )
    gradients[[level]] <- gradient
  }
  contrasts <- list(
    cancer_and_pain_vs_neither = c("cancer_and_pain", "neither"),
    cancer_and_pain_vs_cancer_only = c("cancer_and_pain", "cancer_only"),
    pain_only_vs_neither = c("pain_only", "neither"),
    cancer_only_vs_neither = c("cancer_only", "neither")
  )
  risk_values <- setNames(vapply(risk_rows, function(x) x$estimate, numeric(1)), names(risk_rows))
  rd <- rbindlist(lapply(names(contrasts), function(contrast_name) {
    pair <- contrasts[[contrast_name]]
    gradient <- gradients[[pair[1]]] - gradients[[pair[2]]]
    data.table(
      cohort = cohort_name, imputation = imputation, contrast = contrast_name,
      estimate = risk_values[[pair[1]]] - risk_values[[pair[2]]],
      variance = as.numeric(t(gradient) %*% covariance %*% gradient)
    )
  }))
  list(risks = rbindlist(risk_rows), risk_differences = rd)
}

all_risks <- list()
all_rd <- list()
for (cohort_name in cohorts) {
  message("Onset logistic standardization: ", cohort_name)
  d <- prepare_data(cohort_name)
  if (cohort_name == "SHARE") {
    required <- c(
      "age", "female", "education3", "partnered", "depressive_score",
      "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
    )
    completed_sets <- list(as.data.frame(d[complete.cases(d[, ..required])]))
  } else {
    imp <- readRDS(file.path(
      model_dir, paste0(tolower(cohort_name), "_mice_m20_v1.0.rds")
    ))
    completed_sets <- lapply(seq_len(imp$m), function(i) complete(imp, action = i))
  }
  risks_i <- list()
  rd_i <- list()
  for (i in seq_along(completed_sets)) {
    completed <- completed_sets[[i]]
    completed$phenotype <- factor(completed$phenotype, levels = phenotype_levels)
    design <- make_design(completed, cohort_name)
    model <- svyglm(
      model_formula(cohort_name), design = design,
      family = quasibinomial(link = "logit")
    )
    x <- standardize(model, completed, cohort_name, i)
    risks_i[[i]] <- x$risks
    rd_i[[i]] <- x$risk_differences
  }
  all_risks[[cohort_name]] <- rbindlist(risks_i)
  all_rd[[cohort_name]] <- rbindlist(rd_i)
}

risks <- rbindlist(all_risks)
risk_differences <- rbindlist(all_rd)
pooled_risks <- risks[, pool_scalar(estimate, variance), by = .(cohort, phenotype)]
pooled_risks[, `:=`(
  estimand = "onset",
  estimate_type = "marginal_standardized_risk_logistic"
)]
pooled_rd <- risk_differences[, pool_scalar(estimate, variance), by = .(cohort, contrast)]
pooled_rd[, `:=`(
  estimand = "onset",
  estimate_type = "marginal_standardized_risk_difference_logistic"
)]

fwrite(risks, file.path(model_dir, "onset_logistic_standardized_risks_imputation_specific_v1.1.csv"), bom = TRUE)
fwrite(risk_differences, file.path(model_dir, "onset_logistic_risk_differences_imputation_specific_v1.1.csv"), bom = TRUE)
fwrite(pooled_risks, file.path(table_dir, "onset_adjusted_absolute_risks_logistic_v1.1.csv"), bom = TRUE)
fwrite(pooled_rd, file.path(table_dir, "onset_adjusted_risk_differences_logistic_v1.1.csv"), bom = TRUE)
capture.output(sessionInfo(), file = file.path(qa_dir, "session_info_43_onset_logistic_standardization_v1.1.txt"))

print(pooled_risks)
print(pooled_rd)
cat("Onset logistic marginal standardization completed.\n")
