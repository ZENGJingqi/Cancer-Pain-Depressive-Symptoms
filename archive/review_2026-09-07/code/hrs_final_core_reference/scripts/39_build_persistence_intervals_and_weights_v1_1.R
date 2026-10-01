options(stringsAsFactors = FALSE)

.libPaths(c("C:/CodexWork/tmp/cpd_R_library", .libPaths()))

suppressPackageStartupMessages({
  library(data.table)
  library(splines)
})

study_id <- "cpd_multicohort_01"
root <- "."
output_dir <- file.path(root, "data/02_analytic", study_id, "v1.1")
qa_dir <- file.path(root, "data/03_outputs", study_id, "qa")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

hrs <- fread(file.path(
  root, "data/01_harmonized", study_id, "HRS",
  "hrs_2012_2022_wave_level_v0.1.csv.gz"
))
share <- as.data.table(readRDS(file.path(
  root, "data/01_harmonized", study_id, "SHARE",
  "share_waves_5_6_8_9_wave_level_v0.1.rds"
)))
charls <- fread(file.path(
  root, "data/01_harmonized", study_id, "CHARLS",
  "charls_2011_2018_wave_level_v0.1.csv.gz"
))

education3 <- function(x, cohort) {
  x <- as.numeric(x)
  if (cohort == "HRS") {
    return(fifelse(
      x %in% c(1, 2), 1,
      fifelse(x %in% c(3, 4), 2, fifelse(x == 5, 3, NA_real_))
    ))
  }
  fifelse(x %in% 1:3, x, NA_real_)
}

wealth_quintile <- function(x) {
  nonmissing <- sum(!is.na(x))
  if (nonmissing == 0) return(rep(NA_integer_, length(x)))
  rank <- frank(x, ties.method = "average", na.last = "keep")
  as.integer(pmin(5, pmax(1, ceiling(rank / nonmissing * 5))))
}

category_with_missing <- function(x) {
  out <- as.character(x)
  out[is.na(out) | out == "NA"] <- "missing"
  factor(out)
}

build_persistence_intervals <- function(wave_data, cohort, transitions, threshold) {
  cohort_name <- cohort
  interval_rows <- list()
  flow_rows <- list()

  for (i in seq_len(nrow(transitions))) {
    base_wave_i <- transitions$base_wave[i]
    follow_wave_i <- transitions$follow_wave[i]
    label <- transitions$transition[i]
    primary_i <- transitions$primary_interval[i]

    base <- copy(wave_data[wave == base_wave_i & in_wave %in% TRUE])
    follow <- copy(wave_data[wave == follow_wave_i, .(
      person_id,
      follow_in_wave = in_wave,
      follow_death_this_wave = death_this_wave,
      follow_interview_status = interview_status,
      follow_depressive_score = depressive_score,
      follow_depressive_high = depressive_high
    )])
    stopifnot(!anyDuplicated(base$person_id), !anyDuplicated(follow$person_id))

    flow <- data.table(
      cohort = cohort_name,
      transition = label,
      primary_interval = primary_i,
      step = c(
        "baseline interviewed", "age >= 50", "valid cancer and pain",
        "valid baseline depressive score", "at/above depressive threshold",
        "survived to follow-up", "follow-up depressive outcome observed",
        "positive initial analysis weight"
      ),
      n = NA_integer_
    )
    flow$n[1] <- nrow(base)
    base <- base[!is.na(age) & age >= 50]
    flow$n[2] <- nrow(base)
    base <- base[cancer %in% c(0, 1) & pain %in% c(0, 1)]
    flow$n[3] <- nrow(base)
    base <- base[!is.na(depressive_score)]
    flow$n[4] <- nrow(base)
    base <- base[depressive_score >= threshold]
    flow$n[5] <- nrow(base)

    interval <- merge(base, follow, by = "person_id", all.x = TRUE, sort = FALSE)
    interval[, follow_observed := follow_in_wave %in% TRUE & !is.na(follow_depressive_score)]
    interval[, follow_death_this_wave := follow_death_this_wave %in% TRUE]
    flow$n[6] <- sum(!interval$follow_death_this_wave)
    flow$n[7] <- sum(interval$follow_observed & !interval$follow_death_this_wave)

    interval[, `:=`(
      cohort = cohort_name,
      transition = label,
      base_wave = base_wave_i,
      follow_wave = follow_wave_i,
      primary_interval = primary_i,
      estimand = "persistence",
      event = fifelse(
        follow_observed & !follow_death_this_wave,
        follow_depressive_score >= threshold,
        NA
      ),
      symptom_state = fifelse(
        follow_observed & !follow_death_this_wave,
        fifelse(follow_depressive_score >= threshold, "persistent_high", "remission"),
        NA_character_
      ),
      phenotype = fcase(
        cancer == 0 & pain == 0, "neither",
        cancer == 1 & pain == 0, "cancer_only",
        cancer == 0 & pain == 1, "pain_only",
        cancer == 1 & pain == 1, "cancer_and_pain",
        default = NA_character_
      ),
      education3 = education3(education_raw, cohort_name),
      analysis_weight_initial = survey_weight,
      weight_status = "baseline_response_weight_pending_retention_adjustment"
    )]

    if (cohort_name == "SHARE" && base_wave_i %in% c(5, 8)) {
      interval[, `:=`(
        analysis_weight_initial = longitudinal_pair_weight,
        weight_status = "official_calibrated_longitudinal_weight"
      )]
    }
    if (cohort_name == "CHARLS" && base_wave_i == 1) {
      interval[, `:=`(
        analysis_weight_initial = longitudinal_pair_weight,
        weight_status = "official_individual_longitudinal_weight"
      )]
    }

    interval[, wealth_quintile := wealth_quintile(wealth)]
    interval[, analysis_weight_initial := fifelse(
      !is.na(analysis_weight_initial) & analysis_weight_initial > 0,
      analysis_weight_initial,
      NA_real_
    )]
    interval[, analysis_weight_initial_norm :=
      analysis_weight_initial / mean(analysis_weight_initial, na.rm = TRUE)]
    flow$n[8] <- interval[
      follow_observed == TRUE & !follow_death_this_wave &
        !is.na(analysis_weight_initial_norm), .N
    ]

    interval_rows[[length(interval_rows) + 1L]] <- interval
    flow_rows[[length(flow_rows) + 1L]] <- flow
  }

  list(
    intervals = rbindlist(interval_rows, use.names = TRUE, fill = TRUE),
    flow = rbindlist(flow_rows, use.names = TRUE, fill = TRUE)
  )
}

fit_retention_weight <- function(data, cohort_name, transition_name) {
  d <- copy(data[transition == transition_name & !follow_death_this_wave])
  if (!nrow(d)) stop("No surviving persistence-eligible records for ", cohort_name, " ", transition_name)

  d[, education_ret := category_with_missing(education3)]
  d[, partnered_ret := category_with_missing(partnered)]
  d[, smoking_ret := category_with_missing(current_smoking)]
  d[, wealth_ret := category_with_missing(wealth_quintile)]
  d[, comorbidity_missing := is.na(noncancer_comorbidity_count)]
  median_comorbidity <- median(d$noncancer_comorbidity_count, na.rm = TRUE)
  if (!is.finite(median_comorbidity)) median_comorbidity <- 0
  d[, comorbidity_filled := fifelse(
    is.na(noncancer_comorbidity_count), median_comorbidity,
    noncancer_comorbidity_count
  )]

  missing_indicator_term <- if (uniqueN(d$comorbidity_missing) > 1) {
    " + comorbidity_missing"
  } else {
    ""
  }
  full_formula <- as.formula(paste0(
    "follow_observed ~ ns(age, df = 3) + female + education_ret + ",
    "partnered_ret + phenotype + depressive_score + comorbidity_filled",
    missing_indicator_term, " + smoking_ret + wealth_ret"
  ))
  reduced_wealth_formula <- update(full_formula, . ~ . - wealth_ret)
  reduced_smoking_formula <- update(reduced_wealth_formula, . ~ . - smoking_ret)
  formulas <- list(
    full = full_formula,
    reduced_without_wealth = reduced_wealth_formula,
    reduced_without_wealth_smoking = reduced_smoking_formula
  )

  model <- NULL
  model_status <- NA_character_
  warnings_seen <- character()
  errors_seen <- character()
  for (status in names(formulas)) {
    candidate_warnings <- character()
    candidate <- tryCatch(
      withCallingHandlers(
        glm(formulas[[status]], data = d, family = binomial()),
        warning = function(w) {
          candidate_warnings <<- c(candidate_warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        errors_seen <<- c(errors_seen, paste0(status, ": ", conditionMessage(e)))
        NULL
      }
    )
    predicted_candidate <- if (!is.null(candidate)) {
      suppressWarnings(predict(candidate, newdata = d, type = "response"))
    } else {
      NA_real_
    }
    stable <- !is.null(candidate) && candidate$converged &&
      all(is.finite(predicted_candidate))
    warnings_seen <- c(warnings_seen, candidate_warnings)
    if (stable) {
      model <- candidate
      model_status <- paste0(
        status,
        if (any(!is.finite(coef(candidate)))) "_rank_deficient" else ""
      )
      break
    }
  }
  if (is.null(model)) stop(
    "All persistence retention models failed for ", cohort_name, " ", transition_name,
    ". Errors: ", paste(unique(errors_seen), collapse = " | "),
    ". Warnings: ", paste(unique(warnings_seen), collapse = " | ")
  )

  d[, retention_probability_raw := as.numeric(predict(model, newdata = d, type = "response"))]
  d[, retention_probability := pmin(0.99, pmax(0.05, retention_probability_raw))]
  d[, retention_ipw_raw := 1 / retention_probability]
  observed_weights <- d[follow_observed == TRUE, retention_ipw_raw]
  if (!length(observed_weights)) stop("No observed follow-up in ", cohort_name, " ", transition_name)
  limits <- quantile(observed_weights, probs = c(0.01, 0.99), na.rm = TRUE, names = FALSE)
  d[, retention_ipw := pmin(limits[2], pmax(limits[1], retention_ipw_raw))]

  diagnostics <- data.table(
    cohort = cohort_name,
    estimand = "persistence",
    transition = transition_name,
    surviving_baseline_n = nrow(d),
    observed_followup_n = sum(d$follow_observed),
    retention_rate = mean(d$follow_observed),
    predicted_probability_raw_min = min(d$retention_probability_raw),
    predicted_probability_bounded_min = min(d$retention_probability),
    predicted_probability_p01 = quantile(d$retention_probability, 0.01),
    predicted_probability_median = median(d$retention_probability),
    predicted_probability_p99 = quantile(d$retention_probability, 0.99),
    predicted_probability_bounded_max = max(d$retention_probability),
    ipw_truncation_p01 = limits[1],
    ipw_truncation_p99 = limits[2],
    retention_model_status = model_status,
    warning_count = length(unique(warnings_seen)),
    model_terms = paste(deparse(formula(model)), collapse = " ")
  )

  list(
    weights = d[, .(
      person_id, transition, retention_probability_raw,
      retention_probability, retention_ipw
    )],
    diagnostics = diagnostics,
    model = model
  )
}

hrs_transitions <- data.table(
  base_wave = 11:15,
  follow_wave = 12:16,
  transition = c("2012-2014", "2014-2016", "2016-2018", "2018-2020", "2020-2022"),
  primary_interval = TRUE
)
share_transitions <- data.table(
  base_wave = c(5, 6, 8),
  follow_wave = c(6, 8, 9),
  transition = c("5-6", "6-8", "8-9"),
  primary_interval = c(TRUE, FALSE, TRUE)
)
charls_transitions <- data.table(
  base_wave = 1:3,
  follow_wave = 2:4,
  transition = c("2011-2013", "2013-2015", "2015-2018"),
  primary_interval = TRUE
)

built <- list(
  HRS = build_persistence_intervals(hrs, "HRS", hrs_transitions, 4),
  SHARE = build_persistence_intervals(share, "SHARE", share_transitions, 4),
  CHARLS = build_persistence_intervals(charls, "CHARLS", charls_transitions, 10)
)

retention_diagnostics <- list()
retention_model_summaries <- list()
final_datasets <- list()

for (cohort_name in names(built)) {
  d <- copy(built[[cohort_name]]$intervals)
  d[, `:=`(
    retention_probability_raw = NA_real_,
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
      retention_probability_raw = i.retention_probability_raw,
      retention_probability = i.retention_probability,
      retention_ipw = i.retention_ipw
    )]
    d[transition == transition_name, `:=`(
      analysis_weight = survey_weight * retention_ipw,
      final_weight_status = paste0(
        "baseline_response_weight_x_persistence_retention_ipw_",
        fit$diagnostics$retention_model_status
      )
    )]
    retention_diagnostics[[length(retention_diagnostics) + 1L]] <- fit$diagnostics
    retention_model_summaries[[paste(cohort_name, transition_name, sep = "_")]] <-
      capture.output(summary(fit$model))
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
  d[, analysis_weight_norm := analysis_weight / mean(analysis_weight, na.rm = TRUE),
    by = transition]
  d[, analysis_eligible :=
    primary_interval == TRUE & follow_observed == TRUE &
      follow_death_this_wave == FALSE & !is.na(event) &
      !is.na(analysis_weight_norm)]

  stopifnot(!anyDuplicated(d[, paste(person_id, transition)]))
  stopifnot(all(d[analysis_eligible == TRUE, analysis_weight_norm] > 0))
  stopifnot(all(d[analysis_eligible == TRUE, event] %in% c(0, 1)))

  saveRDS(
    d,
    file.path(output_dir, paste0(tolower(cohort_name), "_persistence_intervals_v1.1.rds")),
    compress = "xz"
  )
  final_datasets[[cohort_name]] <- d
}

all_final <- rbindlist(final_datasets, use.names = TRUE, fill = TRUE)
saveRDS(
  all_final,
  file.path(output_dir, "all_cohorts_persistence_intervals_v1.1.rds"),
  compress = "xz"
)

flow <- rbindlist(lapply(built, `[[`, "flow"), use.names = TRUE, fill = TRUE)
fwrite(flow, file.path(qa_dir, "persistence_person_interval_flow_v1.1.csv"), bom = TRUE)

retention_qa <- rbindlist(retention_diagnostics, fill = TRUE)
fwrite(
  retention_qa,
  file.path(qa_dir, "persistence_retention_weight_diagnostics_v1.1.csv"),
  bom = TRUE
)

summary_connection <- file(
  file.path(qa_dir, "persistence_retention_model_summaries_v1.1.txt"),
  open = "wt", encoding = "UTF-8"
)
for (name in names(retention_model_summaries)) {
  writeLines(c(
    paste0("===== ", name, " ====="),
    retention_model_summaries[[name]], ""
  ), summary_connection)
}
close(summary_connection)

analysis_counts <- all_final[analysis_eligible == TRUE, .(
  n_intervals = .N,
  n_persons = uniqueN(person_id),
  persistent_high_events = sum(event),
  remission_events = sum(event == 0),
  weighted_persistence_risk = weighted.mean(as.numeric(event), analysis_weight_norm),
  weight_min = min(analysis_weight_norm),
  weight_median = median(analysis_weight_norm),
  weight_p99 = quantile(analysis_weight_norm, 0.99),
  weight_max = max(analysis_weight_norm),
  effective_sample_size = sum(analysis_weight_norm)^2 / sum(analysis_weight_norm^2),
  effective_sample_size_fraction =
    (sum(analysis_weight_norm)^2 / sum(analysis_weight_norm^2)) / .N
), by = .(cohort, transition, phenotype, final_weight_status)]
fwrite(
  analysis_counts,
  file.path(qa_dir, "persistence_analysis_counts_and_weight_qa_v1.1.csv"),
  bom = TRUE
)

positivity <- all_final[
  primary_interval == TRUE & !follow_death_this_wave,
  .(
    surviving_baseline_n = .N,
    observed_followup_n = sum(follow_observed),
    observed_rate = mean(follow_observed),
    events_if_observed = sum(event, na.rm = TRUE)
  ),
  by = .(cohort, transition, phenotype)
]
fwrite(
  positivity,
  file.path(qa_dir, "persistence_phenotype_retention_positivity_v1.1.csv"),
  bom = TRUE
)

core_variables <- c(
  "age", "female", "education3", "partnered", "depressive_score",
  "noncancer_comorbidity_count", "current_smoking", "wealth_quintile",
  "mobility_count", "adl_count", "iadl_count"
)
missingness <- rbindlist(lapply(names(final_datasets), function(cohort_name) {
  d <- final_datasets[[cohort_name]][analysis_eligible == TRUE]
  rbindlist(lapply(core_variables, function(variable) {
    data.table(
      cohort = cohort_name,
      estimand = "persistence",
      variable = variable,
      n = nrow(d),
      missing_n = sum(is.na(d[[variable]])),
      missing_pct = mean(is.na(d[[variable]])) * 100,
      unique_observed = uniqueN(d[[variable]][!is.na(d[[variable]])])
    )
  }))
}))
fwrite(
  missingness,
  file.path(qa_dir, "persistence_covariate_missingness_v1.1.csv"),
  bom = TRUE
)

failure_gates <- rbindlist(list(
  retention_qa[, .(
    cohort, transition,
    gate = "raw predicted observation probability below 0.10",
    failed = predicted_probability_raw_min < 0.10,
    value = predicted_probability_raw_min,
    threshold = 0.10
  )],
  analysis_counts[, .(
    gate = "normalized weight maximum above 20",
    failed = max(weight_max) > 20,
    value = max(weight_max),
    threshold = 20
  ), by = .(cohort, transition)],
  analysis_counts[, .(
    gate = "effective sample size below 25 percent",
    failed = min(effective_sample_size_fraction) < 0.25,
    value = min(effective_sample_size_fraction),
    threshold = 0.25
  ), by = .(cohort, transition)]
), use.names = TRUE, fill = TRUE)
fwrite(
  failure_gates,
  file.path(qa_dir, "persistence_pre_model_failure_gates_v1.1.csv"),
  bom = TRUE
)

freeze_files <- list.files(output_dir, pattern = "v1\\.1\\.rds$", full.names = TRUE)
freeze_manifest <- data.table(
  file = gsub("\\\\", "/", freeze_files),
  bytes = file.info(freeze_files)$size,
  md5 = unname(tools::md5sum(freeze_files))
)
fwrite(
  freeze_manifest,
  file.path(output_dir, "freeze_manifest_persistence_v1.1.csv"),
  bom = TRUE
)
capture.output(
  sessionInfo(),
  file = file.path(qa_dir, "session_info_39_persistence_intervals_weights_v1.1.txt")
)

print(retention_qa)
print(analysis_counts)
print(failure_gates)
cat("Persistence analytic v1.1 files written to", output_dir, "\n")
