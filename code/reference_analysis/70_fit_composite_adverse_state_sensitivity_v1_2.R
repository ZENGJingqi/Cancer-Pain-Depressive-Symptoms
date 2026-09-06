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

# Post-result sensitivity frozen in paper_design/21_复合不良状态敏感性分析方案_v1.0_2026-09-01.md.
# HRS is intentionally excluded while its project AI/LLM policy gate remains open.
study_id <- "cpd_multicohort_01"
root <- "."
v10_dir <- file.path(root, "data/02_analytic", study_id, "v1.0")
v11_dir <- file.path(root, "data/02_analytic", study_id, "v1.1")
model_dir <- file.path(root, "data/03_outputs", study_id, "models")
qa_dir <- file.path(root, "data/03_outputs", study_id, "qa")
dir.create(model_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(qa_dir, recursive = TRUE, showWarnings = FALSE)

cohorts <- c("SHARE", "CHARLS")
estimands <- c("onset", "persistence")
phenotype_levels <- c("neither", "cancer_only", "pain_only", "cancer_and_pain")
seeds <- c(
  SHARE_onset = 700101L,
  CHARLS_onset = 700102L,
  SHARE_persistence = 700103L,
  CHARLS_persistence = 700104L
)

category_with_missing <- function(x) {
  out <- as.character(x)
  out[is.na(out) | out == "NA"] <- "missing"
  factor(out)
}

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
  riv <- if (ubar > 0) ((1 + 1 / m) * between) / ubar else 0
  df <- if (riv > 0) (m - 1) * (1 + 1 / riv)^2 else Inf
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
    relative_increase_variance = riv
  )
}

read_interval_data <- function(cohort_name, estimand) {
  path <- if (estimand == "onset") {
    file.path(v10_dir, paste0(tolower(cohort_name), "_person_intervals_v1.0.rds"))
  } else {
    file.path(v11_dir, paste0(tolower(cohort_name), "_persistence_intervals_v1.1.rds"))
  }
  d <- as.data.table(readRDS(path))[
    primary_interval == TRUE & phenotype %chin% phenotype_levels &
      !is.na(survey_weight) & survey_weight > 0
  ]
  stopifnot(!anyDuplicated(d[, paste(person_id, transition)]))
  d[, `:=`(
    phenotype = factor(phenotype, levels = phenotype_levels),
    composite_event = fifelse(
      follow_death_this_wave %in% TRUE,
      1,
      fifelse(follow_observed %in% TRUE, as.numeric(event), NA_real_)
    ),
    composite_observed = follow_death_this_wave %in% TRUE | follow_observed %in% TRUE,
    survivor_follow_observed = follow_death_this_wave %in% FALSE & follow_observed %in% TRUE
  )]
  d
}

fit_survivor_retention <- function(d, cohort_name, estimand, transition_name) {
  s <- copy(d[transition == transition_name & follow_death_this_wave %in% FALSE])
  if (!nrow(s)) stop("No surviving records for ", cohort_name, " ", estimand, " ", transition_name)
  s[, `:=`(
    education_ret = category_with_missing(education3),
    partnered_ret = category_with_missing(partnered),
    smoking_ret = category_with_missing(current_smoking),
    wealth_ret = category_with_missing(wealth_quintile),
    comorbidity_missing = is.na(noncancer_comorbidity_count)
  )]
  median_comorbidity <- median(s$noncancer_comorbidity_count, na.rm = TRUE)
  if (!is.finite(median_comorbidity)) median_comorbidity <- 0
  s[, comorbidity_filled := fifelse(
    is.na(noncancer_comorbidity_count), median_comorbidity,
    noncancer_comorbidity_count
  )]
  missing_term <- if (uniqueN(s$comorbidity_missing) > 1) " + comorbidity_missing" else ""
  full_formula <- as.formula(paste0(
    "follow_observed ~ ns(age, df = 3) + female + education_ret + ",
    "partnered_ret + phenotype + depressive_score + comorbidity_filled",
    missing_term, " + smoking_ret + wealth_ret"
  ))
  formulas <- list(
    full = full_formula,
    reduced_without_wealth = update(full_formula, . ~ . - wealth_ret),
    reduced_without_wealth_smoking = update(full_formula, . ~ . - wealth_ret - smoking_ret)
  )
  model <- NULL
  status <- NA_character_
  warnings_seen <- character()
  errors_seen <- character()
  for (candidate_name in names(formulas)) {
    candidate_warnings <- character()
    candidate <- tryCatch(
      withCallingHandlers(
        glm(formulas[[candidate_name]], data = s, family = binomial()),
        warning = function(w) {
          candidate_warnings <<- c(candidate_warnings, conditionMessage(w))
          invokeRestart("muffleWarning")
        }
      ),
      error = function(e) {
        errors_seen <<- c(errors_seen, paste(candidate_name, conditionMessage(e), sep = ": "))
        NULL
      }
    )
    predicted <- if (!is.null(candidate)) {
      suppressWarnings(predict(candidate, newdata = s, type = "response"))
    } else {
      NA_real_
    }
    if (!is.null(candidate) && candidate$converged && all(is.finite(predicted))) {
      model <- candidate
      status <- candidate_name
      warnings_seen <- c(warnings_seen, candidate_warnings)
      break
    }
    warnings_seen <- c(warnings_seen, candidate_warnings)
  }
  if (is.null(model)) stop(
    "All survivor retention models failed: ", cohort_name, " ", estimand, " ", transition_name,
    " | ", paste(unique(errors_seen), collapse = " | ")
  )
  s[, probability_raw := as.numeric(predict(model, newdata = s, type = "response"))]
  s[, probability := pmin(0.99, pmax(0.05, probability_raw))]
  s[, ipw_raw := 1 / probability]
  observed_ipw <- s[follow_observed %in% TRUE, ipw_raw]
  limits <- quantile(observed_ipw, c(0.01, 0.99), na.rm = TRUE, names = FALSE)
  s[, ipw := pmin(limits[2], pmax(limits[1], ipw_raw))]
  list(
    weights = s[, .(person_id, transition, composite_survivor_ipw = ipw)],
    diagnostics = data.table(
      cohort = cohort_name,
      estimand = estimand,
      transition = transition_name,
      surviving_baseline_n = nrow(s),
      observed_survivor_n = sum(s$follow_observed %in% TRUE),
      observed_survivor_rate = mean(s$follow_observed %in% TRUE),
      predicted_probability_raw_min = min(s$probability_raw),
      predicted_probability_p01 = quantile(s$probability, 0.01),
      predicted_probability_median = median(s$probability),
      predicted_probability_p99 = quantile(s$probability, 0.99),
      predicted_probability_raw_max = max(s$probability_raw),
      ipw_truncation_p01 = limits[1],
      ipw_truncation_p99 = limits[2],
      model_status = status,
      warning_count = length(unique(warnings_seen)),
      model_terms = paste(deparse(formula(model)), collapse = " ")
    )
  )
}

build_composite_dataset <- function(cohort_name, estimand) {
  d <- read_interval_data(cohort_name, estimand)
  d[, composite_survivor_ipw := NA_real_]
  diagnostic_rows <- list()
  for (transition_name in unique(d$transition)) {
    fitted <- fit_survivor_retention(d, cohort_name, estimand, transition_name)
    d[fitted$weights, on = .(person_id, transition),
      composite_survivor_ipw := i.composite_survivor_ipw]
    diagnostic_rows[[transition_name]] <- fitted$diagnostics
  }
  d[, composite_weight := fifelse(
    follow_death_this_wave %in% TRUE,
    survey_weight,
    fifelse(
      follow_observed %in% TRUE,
      survey_weight * composite_survivor_ipw,
      NA_real_
    )
  )]
  d[, composite_weight := fifelse(
    is.finite(composite_weight) & composite_weight > 0,
    composite_weight,
    NA_real_
  )]
  d[, composite_weight_norm := composite_weight / mean(composite_weight, na.rm = TRUE),
    by = transition]
  d[, composite_analysis_eligible :=
    composite_observed == TRUE & !is.na(composite_event) &
      !is.na(composite_weight_norm)]
  analysis <- d[composite_analysis_eligible == TRUE]
  stopifnot(all(analysis$composite_event %in% c(0, 1)))
  stopifnot(all(analysis$composite_weight_norm > 0))
  list(data = analysis, diagnostics = rbindlist(diagnostic_rows, fill = TRUE), full = d)
}

impute_composite <- function(d, cohort_name, estimand) {
  analysis_vars <- c(
    "composite_event", "phenotype", "age", "female", "education3", "partnered",
    "depressive_score", "noncancer_comorbidity_count", "current_smoking",
    "wealth_quintile", "transition", "composite_weight_norm", "person_id"
  )
  design_vars <- if (cohort_name == "SHARE") c("country", "household_id") else "community_id"
  imp_data <- as.data.frame(d[, c(analysis_vars, design_vars), with = FALSE])
  imp_data$phenotype <- factor(imp_data$phenotype, levels = phenotype_levels)
  imp_data$education3 <- factor(imp_data$education3, levels = 1:3)
  imp_data$partnered <- factor(imp_data$partnered, levels = 0:1)
  imp_data$current_smoking <- factor(imp_data$current_smoking, levels = 0:1)
  imp_data$wealth_quintile <- factor(imp_data$wealth_quintile, levels = 1:5)
  imp_data$transition <- factor(imp_data$transition)
  if (cohort_name == "SHARE") imp_data$country <- factor(imp_data$country)
  setup <- mice(imp_data, maxit = 0, printFlag = FALSE)
  method <- setup$method
  predictor <- setup$predictorMatrix
  fixed <- intersect(c(
    "composite_event", "phenotype", "age", "female", "depressive_score", "transition",
    "composite_weight_norm", "person_id", "country", "household_id", "community_id"
  ), names(imp_data))
  method[fixed] <- ""
  nonpredictors <- intersect(c(
    "composite_weight_norm", "person_id", "household_id", "community_id"
  ), names(imp_data))
  predictor[, nonpredictors] <- 0
  predictor[nonpredictors, ] <- 0
  method["education3"] <- if (anyNA(imp_data$education3)) "polyreg" else ""
  method["partnered"] <- if (anyNA(imp_data$partnered)) "logreg" else ""
  method["current_smoking"] <- if (anyNA(imp_data$current_smoking)) "logreg" else ""
  method["wealth_quintile"] <- if (anyNA(imp_data$wealth_quintile)) "polyreg" else ""
  method["noncancer_comorbidity_count"] <-
    if (anyNA(imp_data$noncancer_comorbidity_count)) "pmm" else ""
  seed_name <- paste(cohort_name, estimand, sep = "_")
  mice(
    imp_data,
    m = 20L,
    maxit = 5L,
    method = method,
    predictorMatrix = predictor,
    seed = seeds[[seed_name]],
    printFlag = FALSE
  )
}

make_design <- function(completed, cohort_name, weight_name = "composite_weight_norm") {
  completed$phenotype <- factor(completed$phenotype, levels = phenotype_levels)
  completed$transition <- factor(completed$transition)
  completed$education3 <- factor(completed$education3, levels = 1:3)
  completed$partnered <- factor(completed$partnered, levels = 0:1)
  completed$current_smoking <- factor(completed$current_smoking, levels = 0:1)
  completed$wealth_quintile <- factor(completed$wealth_quintile, levels = 1:5)
  completed$event <- as.numeric(completed$composite_event)
  completed$weight_current <- completed[[weight_name]]
  if (cohort_name == "SHARE") {
    completed$country <- factor(completed$country)
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

contrast_vectors <- function(names_beta) {
  zero <- setNames(rep(0, length(names_beta)), names_beta)
  make <- function(values) {
    out <- zero
    out[names(values)] <- values
    out
  }
  list(
    cancer_and_pain_vs_neither = make(c(phenotypecancer_and_pain = 1)),
    cancer_and_pain_vs_cancer_only = make(c(
      phenotypecancer_and_pain = 1, phenotypecancer_only = -1
    )),
    pain_only_vs_neither = make(c(phenotypepain_only = 1)),
    cancer_only_vs_neither = make(c(phenotypecancer_only = 1)),
    pain_only_vs_cancer_only = make(c(
      phenotypepain_only = 1, phenotypecancer_only = -1
    ))
  )
}

fit_imputed_models <- function(imp, cohort_name, estimand) {
  rows <- list()
  for (imputation in seq_len(imp$m)) {
    completed <- complete(imp, imputation)
    design <- make_design(completed, cohort_name)
    model <- svyglm(
      model_formula(cohort_name),
      design = design,
      family = quasipoisson(link = "log")
    )
    beta <- coef(model)
    covariance <- vcov(model)
    if (any(!is.finite(beta)) || any(!is.finite(covariance))) {
      stop("Non-finite composite model: ", cohort_name, " ", estimand, " imputation ", imputation)
    }
    vectors <- contrast_vectors(names(beta))
    for (contrast_name in names(vectors)) {
      vector <- vectors[[contrast_name]]
      rows[[length(rows) + 1L]] <- data.table(
        cohort = cohort_name,
        estimand = estimand,
        imputation = imputation,
        contrast = contrast_name,
        log_rr = sum(vector * beta),
        variance = as.numeric(t(vector) %*% covariance %*% vector)
      )
    }
  }
  rbindlist(rows)
}

fit_complete_case_model <- function(
  d, cohort_name, estimand, weight_name = "composite_weight_norm"
) {
  core <- c(
    "age", "female", "education3", "partnered", "depressive_score",
    "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
  )
  complete_d <- as.data.frame(d[complete.cases(d[, ..core])])
  design <- make_design(complete_d, cohort_name, weight_name)
  model <- svyglm(
    model_formula(cohort_name),
    design = design,
    family = quasipoisson(link = "log")
  )
  beta <- coef(model)
  covariance <- vcov(model)
  vectors <- contrast_vectors(names(beta))
  rows <- rbindlist(lapply(names(vectors), function(contrast_name) {
    vector <- vectors[[contrast_name]]
    data.table(
      cohort = cohort_name,
      estimand = estimand,
      imputation = 0L,
      contrast = contrast_name,
      log_rr = sum(vector * beta),
      variance = as.numeric(t(vector) %*% covariance %*% vector)
    )
  }))
  list(data = complete_d, results = rows)
}

all_diagnostics <- list()
all_counts <- list()
all_imputation_results <- list()
all_pooled_results <- list()
all_mi_summary <- list()
all_mi_events <- list()
all_share_trim_results <- list()
all_share_trim_weight_qa <- list()

for (estimand in estimands) {
  for (cohort_name in cohorts) {
    label <- paste(cohort_name, estimand, sep = "_")
    message("Building composite sensitivity: ", label)
    built <- build_composite_dataset(cohort_name, estimand)
    d <- built$data
    all_diagnostics[[label]] <- built$diagnostics
    use_complete_case <- cohort_name == "SHARE"
    model_data_for_counts <- d
    if (use_complete_case) {
      core <- c(
        "age", "female", "education3", "partnered", "depressive_score",
        "noncancer_comorbidity_count", "current_smoking", "wealth_quintile"
      )
      model_data_for_counts <- d[complete.cases(d[, ..core])]
    }
    all_counts[[label]] <- model_data_for_counts[, .(
      n_intervals = .N,
      n_persons = uniqueN(person_id),
      composite_events = sum(composite_event),
      deaths = sum(follow_death_this_wave %in% TRUE),
      high_symptom_survivor_events = sum(
        follow_death_this_wave %in% FALSE & composite_event == 1
      ),
      weight_min = min(composite_weight_norm),
      weight_median = median(composite_weight_norm),
      weight_p99 = quantile(composite_weight_norm, 0.99),
      weight_max = max(composite_weight_norm),
      effective_sample_size = sum(composite_weight_norm)^2 / sum(composite_weight_norm^2)
    ), by = phenotype][, `:=`(cohort = cohort_name, estimand = estimand)]

    if (use_complete_case) {
      fitted_cc <- fit_complete_case_model(d, cohort_name, estimand)
      results <- fitted_cc$results
      all_imputation_results[[label]] <- results
      pooled <- copy(results)
      pooled[, `:=`(
        se = sqrt(variance),
        conf_low_log = log_rr - qnorm(0.975) * sqrt(variance),
        conf_high_log = log_rr + qnorm(0.975) * sqrt(variance),
        p_value = 2 * pnorm(abs(log_rr / sqrt(variance)), lower.tail = FALSE),
        df = Inf,
        m = 0L,
        within_variance = variance,
        between_variance = NA_real_,
        relative_increase_variance = NA_real_
      )]
      d_model <- as.data.table(fitted_cc$data)
      all_mi_summary[[label]] <- data.table(
        cohort = cohort_name,
        estimand = estimand,
        variable = names(d),
        n = nrow(d),
        missing_n = as.integer(colSums(is.na(d))),
        missing_pct = as.numeric(colMeans(is.na(d)) * 100),
        method = "complete_case_not_imputed",
        m = 0L,
        maxit = 0L
      )
      all_mi_events[[label]] <- data.table(
        it = NA_integer_, im = NA_integer_, dep = NA_character_,
        meth = NA_character_, out = NA_character_,
        cohort = cohort_name, estimand = estimand
      )
      analysis_method_current <- "complete_case_low_covariate_missingness"

      # SHARE combined baseline-weight x survivor-IPW has a known long tail.
      # Preserve the untrimmed result and add a separate 1st-99th percentile
      # within-transition trimming sensitivity; never overwrite the main weight.
      d_trim <- copy(d)
      d_trim[, c("trim_low", "trim_high") := {
        limits <- quantile(composite_weight, c(0.01, 0.99), na.rm = TRUE, names = FALSE)
        list(limits[1], limits[2])
      }, by = transition]
      d_trim[, composite_weight_trim99 := pmin(
        trim_high, pmax(trim_low, composite_weight)
      )]
      d_trim[, composite_weight_trim99_norm :=
        composite_weight_trim99 / mean(composite_weight_trim99), by = transition]
      fitted_trim <- fit_complete_case_model(
        d_trim, cohort_name, estimand, "composite_weight_trim99_norm"
      )
      trim_results <- fitted_trim$results
      trim_results[, `:=`(
        se = sqrt(variance),
        conf_low_log = log_rr - qnorm(0.975) * sqrt(variance),
        conf_high_log = log_rr + qnorm(0.975) * sqrt(variance),
        rr = exp(log_rr),
        conf_low = exp(log_rr - qnorm(0.975) * sqrt(variance)),
        conf_high = exp(log_rr + qnorm(0.975) * sqrt(variance)),
        p_value = 2 * pnorm(abs(log_rr / sqrt(variance)), lower.tail = FALSE),
        cohort = cohort_name,
        estimand = estimand,
        sensitivity = "combined_weight_trimmed_within_transition_p01_p99",
        n_intervals = nrow(fitted_trim$data),
        n_persons = uniqueN(fitted_trim$data$person_id),
        events = sum(fitted_trim$data$composite_event)
      )]
      all_share_trim_results[[label]] <- trim_results
      trim_data <- as.data.table(fitted_trim$data)
      all_share_trim_weight_qa[[label]] <- trim_data[, .(
        n_intervals = .N,
        weight_min = min(composite_weight_trim99_norm),
        weight_median = median(composite_weight_trim99_norm),
        weight_p99 = quantile(composite_weight_trim99_norm, 0.99),
        weight_max = max(composite_weight_trim99_norm),
        effective_sample_size =
          sum(composite_weight_trim99_norm)^2 / sum(composite_weight_trim99_norm^2)
      ), by = phenotype][, `:=`(cohort = cohort_name, estimand = estimand)]
    } else {
      mids_path <- file.path(
        model_dir,
        paste0(tolower(cohort_name), "_composite_", estimand, "_mice_m20_v1.2.rds")
      )
      if (file.exists(mids_path)) {
        imp <- readRDS(mids_path)
      } else {
        imp <- impute_composite(d, cohort_name, estimand)
        saveRDS(imp, mids_path, compress = "xz")
      }
      all_mi_summary[[label]] <- data.table(
        cohort = cohort_name,
        estimand = estimand,
        variable = names(imp$data),
        n = nrow(imp$data),
        missing_n = as.integer(colSums(is.na(imp$data))),
        missing_pct = as.numeric(colMeans(is.na(imp$data)) * 100),
        method = unname(imp$method[names(imp$data)]),
        m = imp$m,
        maxit = imp$iteration
      )
      events <- imp$loggedEvents
      if (is.null(events) || !nrow(events)) {
        events <- data.table(
          it = NA_integer_, im = NA_integer_, dep = NA_character_,
          meth = NA_character_, out = NA_character_
        )
      } else {
        events <- as.data.table(events)
      }
      events[, `:=`(cohort = cohort_name, estimand = estimand)]
      all_mi_events[[label]] <- events
      results <- fit_imputed_models(imp, cohort_name, estimand)
      all_imputation_results[[label]] <- results
      pooled <- results[, pool_scalar_manual(log_rr, variance), by = contrast]
      d_model <- d
      analysis_method_current <- paste0("multiple_imputation_m", imp$m)
    }
    pooled[, `:=`(
      cohort = cohort_name,
      estimand = estimand,
      outcome = "high_depressive_symptoms_or_death",
      rr = exp(log_rr),
      conf_low = exp(conf_low_log),
      conf_high = exp(conf_high_log),
      n_intervals = nrow(d_model),
      n_persons = uniqueN(d_model$person_id),
      events = sum(d_model$composite_event),
      analysis_method = analysis_method_current,
      design_status = if (cohort_name == "SHARE")
        "country_strata_household_cluster_pending_official_gv_weights_sensitivity" else
        "community_cluster"
    )]
    all_pooled_results[[label]] <- pooled
    message("Completed composite sensitivity: ", label)
  }
}

diagnostics <- rbindlist(all_diagnostics, fill = TRUE)
counts <- rbindlist(all_counts, fill = TRUE)
imputation_results <- rbindlist(all_imputation_results, fill = TRUE)
pooled_results <- rbindlist(all_pooled_results, fill = TRUE)
mi_summary <- rbindlist(all_mi_summary, fill = TRUE)
mi_events <- rbindlist(all_mi_events, fill = TRUE)
share_trim_results <- rbindlist(all_share_trim_results, fill = TRUE)
share_trim_weight_qa <- rbindlist(all_share_trim_weight_qa, fill = TRUE)

setcolorder(counts, c(
  "cohort", "estimand", "phenotype", "n_intervals", "n_persons",
  "composite_events", "deaths", "high_symptom_survivor_events",
  "weight_min", "weight_median", "weight_p99", "weight_max", "effective_sample_size"
))
setcolorder(pooled_results, c(
  "cohort", "estimand", "outcome", "contrast", "n_intervals", "n_persons",
  "events", "log_rr", "se", "rr", "conf_low", "conf_high", "p_value",
  "df", "m", "analysis_method", "design_status", "within_variance",
  "between_variance", "relative_increase_variance"
))

fwrite(diagnostics, file.path(qa_dir, "composite_survivor_retention_diagnostics_v1.2.csv"), bom = TRUE)
fwrite(counts, file.path(qa_dir, "composite_adverse_state_counts_and_weights_v1.2.csv"), bom = TRUE)
fwrite(mi_summary, file.path(qa_dir, "composite_mi_missingness_methods_v1.2.csv"), bom = TRUE)
fwrite(mi_events, file.path(qa_dir, "composite_mi_logged_events_v1.2.csv"), bom = TRUE)
fwrite(
  share_trim_weight_qa,
  file.path(qa_dir, "composite_share_trimmed_weight_qa_v1.2.csv"),
  bom = TRUE
)
fwrite(
  imputation_results,
  file.path(model_dir, "composite_adverse_state_imputation_specific_contrasts_v1.2.csv"),
  bom = TRUE
)
fwrite(
  pooled_results,
  file.path(model_dir, "composite_adverse_state_adjusted_risk_ratios_v1.2.csv"),
  bom = TRUE
)
fwrite(
  share_trim_results,
  file.path(model_dir, "composite_share_weight_trim_sensitivity_v1.2.csv"),
  bom = TRUE
)
capture.output(
  sessionInfo(),
  file = file.path(qa_dir, "session_info_70_composite_adverse_state_v1.2.txt")
)

print(pooled_results[, .(
  cohort, estimand, contrast, rr, conf_low, conf_high, p_value
)])
cat("Composite adverse-state sensitivity completed without reading HRS records.\n")
