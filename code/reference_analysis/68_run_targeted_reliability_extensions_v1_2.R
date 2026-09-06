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

# This targeted script intentionally does not read HRS person-level files.
# The project currently has an explicit policy gate for LLM-assisted access to HRS records.
study_id <- "cpd_multicohort_01"
root <- "."
analytic_v10 <- file.path(root, "data/02_analytic", study_id, "v1.0")
analytic_v11 <- file.path(root, "data/02_analytic", study_id, "v1.1")
model_dir <- file.path(root, "data/03_outputs", study_id, "models")
qa_dir <- file.path(root, "data/03_outputs", study_id, "qa")
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

cohorts <- c("SHARE", "CHARLS")
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
  statistic <- qbar / se
  p_value <- if (is.finite(df)) {
    2 * pt(abs(statistic), df, lower.tail = FALSE)
  } else {
    2 * pnorm(abs(statistic), lower.tail = FALSE)
  }
  data.table(
    log_rr = qbar,
    se = se,
    conf_low_log = qbar - critical * se,
    conf_high_log = qbar + critical * se,
    p_value = p_value,
    df = df,
    m = m,
    within_variance = ubar,
    between_variance = between,
    relative_increase_variance = relative_increase
  )
}

prepare_completed <- function(completed, cohort_name) {
  completed <- as.data.frame(completed)
  completed$phenotype <- factor(completed$phenotype, levels = phenotype_levels)
  completed$transition <- factor(completed$transition)
  completed$education3 <- factor(completed$education3, levels = 1:3)
  completed$partnered <- factor(completed$partnered, levels = 0:1)
  completed$current_smoking <- factor(completed$current_smoking, levels = 0:1)
  completed$wealth_quintile <- factor(completed$wealth_quintile, levels = 1:5)
  completed$event <- as.numeric(completed$event)
  if (cohort_name == "SHARE") completed$country <- factor(completed$country)
  completed
}

make_design <- function(completed, cohort_name, weight_name = "analysis_weight_norm") {
  completed$weight_current <- completed[[weight_name]]
  if (cohort_name == "SHARE") {
    completed$household_cluster <- interaction(
      completed$country, completed$household_id, drop = TRUE
    )
    svydesign(
      ids = ~household_cluster + person_id,
      strata = ~country,
      weights = ~weight_current,
      data = completed,
      nest = TRUE
    )
  } else {
    svydesign(
      ids = ~community_id + person_id,
      weights = ~weight_current,
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

extract_direct_contrast <- function(model, cohort_name, estimand, imputation) {
  beta <- coef(model)
  covariance <- vcov(model)
  required <- c("phenotypepain_only", "phenotypecancer_only")
  if (!all(required %in% names(beta))) {
    stop("Required phenotype coefficients absent for ", cohort_name, " ", estimand)
  }
  contrast <- setNames(rep(0, length(beta)), names(beta))
  contrast["phenotypepain_only"] <- 1
  contrast["phenotypecancer_only"] <- -1
  estimate <- sum(contrast * beta)
  variance <- as.numeric(t(contrast) %*% covariance %*% contrast)
  data.table(
    cohort = cohort_name,
    estimand = estimand,
    imputation = imputation,
    contrast = "pain_only_vs_cancer_only",
    log_rr = estimate,
    variance = variance
  )
}

fit_direct_complete_case <- function(data, cohort_name, estimand) {
  needed <- c(
    "age", "female", "education3", "partnered", "depressive_score",
    "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
  )
  d <- data[complete.cases(data[, ..needed])]
  completed <- prepare_completed(d, cohort_name)
  design <- make_design(completed, cohort_name)
  model <- svyglm(
    model_formula(cohort_name), design = design,
    family = quasipoisson(link = "log")
  )
  row <- extract_direct_contrast(model, cohort_name, estimand, 0L)
  row[, `:=`(
    n_intervals = nrow(completed),
    n_persons = uniqueN(completed$person_id),
    events = sum(completed$event),
    analysis_method = "complete_case"
  )]
  row
}

fit_direct_mids <- function(imp, cohort_name, estimand) {
  rows <- vector("list", imp$m)
  for (imputation in seq_len(imp$m)) {
    completed <- prepare_completed(complete(imp, action = imputation), cohort_name)
    design <- make_design(completed, cohort_name)
    model <- svyglm(
      model_formula(cohort_name), design = design,
      family = quasipoisson(link = "log")
    )
    rows[[imputation]] <- extract_direct_contrast(
      model, cohort_name, estimand, imputation
    )
  }
  rbindlist(rows)
}

direct_imputation_rows <- list()
direct_pooled_rows <- list()
direct_cell_rows <- list()

# Onset: SHARE was prespecified as complete case; CHARLS used m=20 MI.
share_onset <- as.data.table(readRDS(file.path(
  analytic_v10, "share_person_intervals_v1.0.rds"
)))[analysis_eligible == TRUE]
share_onset_complete_vars <- c(
  "age", "female", "education3", "partnered", "depressive_score",
  "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
)
share_onset_model_sample <- share_onset[
  complete.cases(share_onset[, ..share_onset_complete_vars])
]
direct_cell_rows[["SHARE_onset"]] <- share_onset_model_sample[, .(
  n_intervals = .N,
  n_persons = uniqueN(person_id),
  events = sum(as.numeric(event))
), by = phenotype][, `:=`(cohort = "SHARE", estimand = "onset")]
share_onset_cc <- fit_direct_complete_case(share_onset, "SHARE", "onset")
share_onset_pooled <- copy(share_onset_cc)
share_onset_pooled[, `:=`(
  se = sqrt(variance),
  rr = exp(log_rr),
  conf_low = exp(log_rr - qnorm(0.975) * sqrt(variance)),
  conf_high = exp(log_rr + qnorm(0.975) * sqrt(variance)),
  p_value = 2 * pnorm(abs(log_rr / sqrt(variance)), lower.tail = FALSE),
  df = Inf,
  m = 0L,
  within_variance = variance,
  between_variance = NA_real_,
  relative_increase_variance = NA_real_
)]
direct_pooled_rows[["SHARE_onset"]] <- share_onset_pooled

charls_onset_imp <- readRDS(file.path(model_dir, "charls_mice_m20_v1.0.rds"))
charls_onset_first <- as.data.table(complete(charls_onset_imp, 1))
direct_cell_rows[["CHARLS_onset"]] <- charls_onset_first[, .(
  n_intervals = .N,
  n_persons = uniqueN(person_id),
  events = sum(as.numeric(event))
), by = phenotype][, `:=`(cohort = "CHARLS", estimand = "onset")]
charls_onset_rows <- fit_direct_mids(charls_onset_imp, "CHARLS", "onset")
direct_imputation_rows[["CHARLS_onset"]] <- charls_onset_rows
charls_onset_pooled <- charls_onset_rows[, pool_scalar_manual(log_rr, variance)]
charls_onset_pooled[, `:=`(
  cohort = "CHARLS", estimand = "onset",
  contrast = "pain_only_vs_cancer_only",
  rr = exp(log_rr), conf_low = exp(conf_low_log), conf_high = exp(conf_high_log),
  n_intervals = nrow(complete(charls_onset_imp, 1)),
  n_persons = uniqueN(complete(charls_onset_imp, 1)$person_id),
  events = sum(complete(charls_onset_imp, 1)$event),
  analysis_method = paste0("multiple_imputation_m", charls_onset_imp$m)
)]
direct_pooled_rows[["CHARLS_onset"]] <- charls_onset_pooled

# Persistence: both SHARE and CHARLS used m=20 MI.
for (cohort_name in cohorts) {
  imp <- readRDS(file.path(
    model_dir, paste0(tolower(cohort_name), "_persistence_mice_m20_v1.1.rds")
  ))
  rows <- fit_direct_mids(imp, cohort_name, "persistence")
  direct_imputation_rows[[paste0(cohort_name, "_persistence")]] <- rows
  pooled <- rows[, pool_scalar_manual(log_rr, variance)]
  first <- complete(imp, 1)
  first_dt <- as.data.table(first)
  direct_cell_rows[[paste0(cohort_name, "_persistence")]] <- first_dt[, .(
    n_intervals = .N,
    n_persons = uniqueN(person_id),
    events = sum(as.numeric(event))
  ), by = phenotype][, `:=`(cohort = cohort_name, estimand = "persistence")]
  pooled[, `:=`(
    cohort = cohort_name, estimand = "persistence",
    contrast = "pain_only_vs_cancer_only",
    rr = exp(log_rr), conf_low = exp(conf_low_log), conf_high = exp(conf_high_log),
    n_intervals = nrow(first), n_persons = uniqueN(first$person_id),
    events = sum(first$event),
    analysis_method = paste0("multiple_imputation_m", imp$m)
  )]
  direct_pooled_rows[[paste0(cohort_name, "_persistence")]] <- pooled
}

direct_imputation <- rbindlist(direct_imputation_rows, fill = TRUE)
direct_pooled <- rbindlist(direct_pooled_rows, fill = TRUE)
setcolorder(direct_pooled, c(
  "cohort", "estimand", "contrast", "n_intervals", "n_persons", "events",
  "log_rr", "se", "rr", "conf_low", "conf_high", "p_value", "df", "m",
  "analysis_method", "within_variance", "between_variance",
  "relative_increase_variance"
))
fwrite(
  direct_imputation,
  file.path(model_dir, "pain_only_vs_cancer_only_imputation_specific_v1.2.csv"),
  bom = TRUE
)
fwrite(
  direct_pooled,
  file.path(model_dir, "pain_only_vs_cancer_only_direct_comparison_v1.2.csv"),
  bom = TRUE
)
direct_cells <- rbindlist(direct_cell_rows, fill = TRUE)
setcolorder(direct_cells, c(
  "cohort", "estimand", "phenotype", "n_intervals", "n_persons", "events"
))
fwrite(
  direct_cells,
  file.path(qa_dir, "pain_only_vs_cancer_only_cell_counts_v1.2.csv"),
  bom = TRUE
)

# Descriptive interval mortality by phenotype. Baseline survey weights are used,
# because the outcome includes death and longitudinal respondent weights can condition on survival.
mortality_rows <- list()
for (estimand in c("onset", "persistence")) {
  input_dir <- if (estimand == "onset") analytic_v10 else analytic_v11
  suffix <- if (estimand == "onset") "person_intervals_v1.0.rds" else
    "persistence_intervals_v1.1.rds"
  for (cohort_name in cohorts) {
    d <- as.data.table(readRDS(file.path(
      input_dir, paste0(tolower(cohort_name), "_", suffix)
    )))[
      primary_interval == TRUE & !is.na(phenotype) &
        !is.na(survey_weight) & survey_weight > 0
    ]
    d[, `:=`(
      phenotype = factor(phenotype, levels = phenotype_levels),
      death = as.numeric(follow_death_this_wave %in% TRUE),
      baseline_weight_norm = survey_weight / mean(survey_weight)
    )]
    design <- make_design(as.data.frame(d), cohort_name, "baseline_weight_norm")
    estimates <- svyby(
      ~death, ~phenotype, design, svymean,
      vartype = c("se", "ci"), na.rm = TRUE, keep.names = FALSE
    )
    estimates <- as.data.table(estimates)
    count_rows <- d[, .(
      n_intervals = .N,
      n_persons = uniqueN(person_id),
      deaths = sum(death),
      unweighted_death_risk = mean(death)
    ), by = phenotype]
    estimates <- merge(estimates, count_rows, by = "phenotype", all.x = TRUE)
    estimates[, `:=`(
      cohort = cohort_name,
      estimand = estimand,
      weight_basis = "baseline_wave_cross_sectional_survey_weight",
      design_status = if (cohort_name == "SHARE")
        "country_strata_household_cluster_pending_official_gv_weights_sensitivity" else
        "community_cluster"
    )]
    setnames(
      estimates,
      old = intersect(c("death", "se", "ci_l", "ci_u"), names(estimates)),
      new = c("weighted_death_risk", "standard_error", "conf_low", "conf_high")[
        match(intersect(c("death", "se", "ci_l", "ci_u"), names(estimates)),
              c("death", "se", "ci_l", "ci_u"))
      ]
    )
    mortality_rows[[paste(cohort_name, estimand, sep = "_")]] <- estimates
  }
}
mortality <- rbindlist(mortality_rows, fill = TRUE)
setcolorder(mortality, c(
  "cohort", "estimand", "phenotype", "n_intervals", "n_persons", "deaths",
  "unweighted_death_risk", "weighted_death_risk", "standard_error",
  "conf_low", "conf_high", "weight_basis", "design_status"
))
fwrite(
  mortality,
  file.path(qa_dir, "phenotype_specific_interval_mortality_share_charls_v1.2.csv"),
  bom = TRUE
)

# MICE diagnostics for non-HRS imputation objects already used by the formal models.
diagnostic_specs <- list(
  CHARLS_onset = file.path(model_dir, "charls_mice_m20_v1.0.rds"),
  SHARE_persistence = file.path(model_dir, "share_persistence_mice_m20_v1.1.rds"),
  CHARLS_persistence = file.path(model_dir, "charls_persistence_mice_m20_v1.1.rds")
)
mi_summary_rows <- list()
mi_chain_rows <- list()
mi_event_rows <- list()
for (label in names(diagnostic_specs)) {
  imp <- readRDS(diagnostic_specs[[label]])
  missing_n <- colSums(is.na(imp$data))
  mi_summary_rows[[label]] <- data.table(
    analysis = label,
    variable = names(imp$data),
    n = nrow(imp$data),
    missing_n = as.integer(missing_n),
    missing_pct = as.numeric(missing_n / nrow(imp$data) * 100),
    method = unname(imp$method[names(imp$data)]),
    m = imp$m,
    maxit = imp$iteration
  )
  for (statistic in c("chainMean", "chainVar")) {
    array <- imp[[statistic]]
    if (is.null(array) || !length(array)) next
    dims <- dim(array)
    values <- as.data.table(as.table(array))
    setnames(values, c("variable", "iteration", "imputation", "value"))
    values[, `:=`(
      analysis = label,
      statistic = statistic,
      iteration = as.integer(as.character(iteration)),
      imputation = as.integer(sub("^Chain[[:space:]]+", "", as.character(imputation))),
      value = as.numeric(value)
    )]
    mi_chain_rows[[paste(label, statistic, sep = "_")]] <- values
  }
  events <- imp$loggedEvents
  if (is.null(events) || !nrow(events)) {
    events <- data.frame(it = NA_integer_, im = NA_integer_, dep = NA_character_,
                         meth = NA_character_, out = NA_character_)
  }
  events <- as.data.table(events)
  events[, analysis := label]
  mi_event_rows[[label]] <- events
}
mi_summary <- rbindlist(mi_summary_rows, fill = TRUE)
mi_chain <- rbindlist(mi_chain_rows, fill = TRUE)
mi_events <- rbindlist(mi_event_rows, fill = TRUE)
fwrite(mi_summary, file.path(qa_dir, "mi_missingness_methods_share_charls_v1.2.csv"), bom = TRUE)
fwrite(mi_chain, file.path(qa_dir, "mi_chain_statistics_share_charls_v1.2.csv"), bom = TRUE)
fwrite(mi_events, file.path(qa_dir, "mi_logged_events_share_charls_v1.2.csv"), bom = TRUE)

report <- c(
  "# Targeted reliability extensions v1.2",
  "",
  paste0("Run date: ", Sys.Date()),
  "",
  "## Scope",
  "",
  "- Completed the covariance-aware pain-only versus cancer-only contrast for SHARE and CHARLS.",
  "- Computed phenotype-specific interval mortality for SHARE and CHARLS using baseline survey weights.",
  "- Exported MICE missingness, method, chain statistic, and logged-event diagnostics for non-HRS imputed analyses.",
  "- Did not read or rerun HRS person-level data because the project HRS AI/LLM policy gate remains open.",
  "- Did not claim official SHARE sampling-design sensitivity because local gv_weights PSU/stratum files remain unavailable.",
  "",
  "## Direct comparison results",
  "",
  paste(capture.output(print(direct_pooled[, .(
    cohort, estimand, rr, conf_low, conf_high, p_value, analysis_method
  )])), collapse = "\n"),
  "",
  "## Mortality descriptive results",
  "",
  paste(capture.output(print(mortality[, .(
    cohort, estimand, phenotype, n_intervals, deaths,
    weighted_death_risk, conf_low, conf_high
  )])), collapse = "\n"),
  "",
  "## Remaining blockers",
  "",
  "1. Add HRS to the direct comparison and mortality analyses only after the HRS policy gate is closed.",
  "2. Obtain SHARE Release 9 gv_weights modules and rerun official PSU/stratum sensitivity.",
  "3. Specify and freeze the composite high-symptom-or-death sensitivity before modeling it.",
  "4. Add HRS MICE diagnostics after the same policy gate is closed."
)
writeLines(report, file.path(qa_dir, "targeted_reliability_extensions_v1.2.md"), useBytes = TRUE)
capture.output(sessionInfo(), file = file.path(qa_dir, "session_info_68_reliability_extensions_v1.2.txt"))

print(direct_pooled[, .(cohort, estimand, rr, conf_low, conf_high, p_value)])
print(mortality[, .(
  cohort, estimand, phenotype, n_intervals, deaths,
  weighted_death_risk, conf_low, conf_high
)])
cat("Targeted reliability extensions v1.2 completed without reading HRS records.\n")
