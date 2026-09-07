options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(splines)
})

study_id <- "cpd_multicohort_01"
root <- "."
input_dir <- file.path(root, "data/02_analytic", study_id, "v0.1")
output_dir <- file.path(root, "data/02_analytic", study_id, "v1.0")
qa_dir <- file.path(root, "data/03_outputs", study_id, "qa")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

cohorts <- c("HRS", "SHARE", "CHARLS")
datasets <- setNames(lapply(cohorts, function(cohort) {
  readRDS(file.path(input_dir, paste0(tolower(cohort), "_person_intervals_v0.1.rds")))
}), cohorts)

category_with_missing <- function(x, labels = NULL) {
  out <- as.character(x)
  if (!is.null(labels)) out <- unname(labels[out])
  out[is.na(out) | out == "NA"] <- "missing"
  factor(out)
}

fit_retention_weight <- function(data, cohort_name, transition_name) {
  d <- copy(data[transition == transition_name & !follow_death_this_wave])
  if (!nrow(d)) stop("No surviving baseline records for ", cohort_name, " ", transition_name)
  d[, education_ret := category_with_missing(education3)]
  d[, partnered_ret := category_with_missing(partnered)]
  d[, smoking_ret := category_with_missing(current_smoking)]
  d[, wealth_ret := category_with_missing(wealth_quintile)]
  d[, comorbidity_missing := is.na(noncancer_comorbidity_count)]
  d[, comorbidity_filled := fifelse(
    is.na(noncancer_comorbidity_count),
    median(noncancer_comorbidity_count, na.rm = TRUE),
    noncancer_comorbidity_count
  )]

  model <- glm(
    follow_observed ~ ns(age, df = 3) + female + education_ret + partnered_ret +
      phenotype + depressive_score + comorbidity_filled + comorbidity_missing +
      smoking_ret + wealth_ret,
    data = d,
    family = binomial()
  )
  d[, retention_probability := as.numeric(predict(model, newdata = d, type = "response"))]
  d[, retention_probability := pmin(0.99, pmax(0.05, retention_probability))]
  d[, retention_ipw_raw := 1 / retention_probability]
  observed_weights <- d[follow_observed == TRUE, retention_ipw_raw]
  limits <- quantile(observed_weights, probs = c(0.01, 0.99), na.rm = TRUE, names = FALSE)
  d[, retention_ipw := pmin(limits[2], pmax(limits[1], retention_ipw_raw))]

  model_terms <- paste(deparse(formula(model)), collapse = " ")
  diagnostics <- data.table(
    cohort = cohort_name,
    transition = transition_name,
    surviving_baseline_n = nrow(d),
    observed_followup_n = sum(d$follow_observed),
    retention_rate = mean(d$follow_observed),
    predicted_probability_min = min(d$retention_probability),
    predicted_probability_p01 = quantile(d$retention_probability, 0.01),
    predicted_probability_median = median(d$retention_probability),
    predicted_probability_p99 = quantile(d$retention_probability, 0.99),
    predicted_probability_max = max(d$retention_probability),
    ipw_truncation_p01 = limits[1],
    ipw_truncation_p99 = limits[2],
    model_terms = model_terms
  )
  list(
    weights = d[, .(person_id, transition, retention_probability, retention_ipw)],
    diagnostics = diagnostics,
    model = model
  )
}

retention_diagnostics <- list()
model_summaries <- list()
final_datasets <- list()

for (cohort_name in cohorts) {
  d <- copy(datasets[[cohort_name]])
  d[, `:=`(
    retention_probability = NA_real_,
    retention_ipw = NA_real_,
    analysis_weight = NA_real_,
    final_weight_status = NA_character_
  )]

  custom_transitions <- if (cohort_name == "HRS") {
    unique(d$transition)
  } else if (cohort_name == "SHARE") {
    "6-8"
  } else {
    c("2013-2015", "2015-2018")
  }

  for (transition_name in custom_transitions) {
    fit <- fit_retention_weight(d, cohort_name, transition_name)
    d[fit$weights, on = .(person_id, transition), `:=`(
      retention_probability = i.retention_probability,
      retention_ipw = i.retention_ipw
    )]
    d[transition == transition_name, `:=`(
      analysis_weight = survey_weight * retention_ipw,
      final_weight_status = "baseline_response_weight_x_retention_ipw"
    )]
    retention_diagnostics[[length(retention_diagnostics) + 1]] <- fit$diagnostics
    model_summaries[[paste(cohort_name, transition_name, sep = "_")]] <- capture.output(summary(fit$model))
  }

  official <- d$weight_status %chin% c(
    "official_calibrated_longitudinal_weight",
    "official_individual_longitudinal_weight"
  )
  d[official, `:=`(
    analysis_weight = analysis_weight_initial,
    final_weight_status = weight_status
  )]
  d[, analysis_weight := fifelse(
    !is.na(analysis_weight) & analysis_weight > 0,
    analysis_weight,
    NA_real_
  )]
  d[, analysis_weight_norm := analysis_weight / mean(analysis_weight, na.rm = TRUE), by = transition]
  d[, analysis_eligible :=
    primary_interval == TRUE &
      follow_observed == TRUE &
      follow_death_this_wave == FALSE &
      !is.na(analysis_weight_norm)]

  stopifnot(!anyDuplicated(d[, paste(person_id, transition)]))
  saveRDS(
    d,
    file.path(output_dir, paste0(tolower(cohort_name), "_person_intervals_v1.0.rds")),
    compress = "xz"
  )
  final_datasets[[cohort_name]] <- d
}

all_final <- rbindlist(final_datasets, use.names = TRUE, fill = TRUE)
saveRDS(all_final, file.path(output_dir, "all_cohorts_person_intervals_v1.0.rds"), compress = "xz")

retention_qa <- rbindlist(retention_diagnostics, fill = TRUE)
fwrite(retention_qa, file.path(qa_dir, "retention_weight_diagnostics_v1.0.csv"), bom = TRUE)

model_summary_file <- file.path(qa_dir, "retention_model_summaries_v1.0.txt")
con <- file(model_summary_file, open = "wt", encoding = "UTF-8")
for (name in names(model_summaries)) {
  writeLines(c(paste0("===== ", name, " ====="), model_summaries[[name]], ""), con)
}
close(con)

analysis_counts <- all_final[analysis_eligible == TRUE, .(
  n_intervals = .N,
  n_persons = uniqueN(person_id),
  events = sum(event),
  weighted_events = weighted.mean(as.numeric(event), analysis_weight_norm),
  weight_min = min(analysis_weight_norm),
  weight_median = median(analysis_weight_norm),
  weight_max = max(analysis_weight_norm)
), by = .(cohort, transition, phenotype, final_weight_status)]
fwrite(analysis_counts, file.path(qa_dir, "analysis_counts_after_final_weights_v1.0.csv"), bom = TRUE)

core_variables <- c(
  "age", "female", "education3", "partnered", "depressive_score",
  "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
)
missingness <- rbindlist(lapply(names(final_datasets), function(cohort_name) {
  d <- final_datasets[[cohort_name]][analysis_eligible == TRUE]
  rbindlist(lapply(core_variables, function(variable) {
    data.table(
      cohort = cohort_name,
      variable = variable,
      n = nrow(d),
      missing_n = sum(is.na(d[[variable]])),
      missing_pct = mean(is.na(d[[variable]])) * 100
    )
  }))
}))
fwrite(missingness, file.path(qa_dir, "core_covariate_missingness_v1.0.csv"), bom = TRUE)

freeze_manifest <- data.table(
  file = list.files(output_dir, pattern = "\\.rds$", full.names = TRUE),
  bytes = file.info(list.files(output_dir, pattern = "\\.rds$", full.names = TRUE))$size
)
freeze_manifest[, md5 := unname(tools::md5sum(file))]
freeze_manifest[, file := gsub("\\\\", "/", file)]
fwrite(freeze_manifest, file.path(output_dir, "freeze_manifest_v1.0.csv"), bom = TRUE)
capture.output(sessionInfo(), file = file.path(qa_dir, "session_info_27_retention_weights.txt"))

print(retention_qa)
print(missingness)
cat("Frozen analytic v1.0 files written to", output_dir, "\n")

