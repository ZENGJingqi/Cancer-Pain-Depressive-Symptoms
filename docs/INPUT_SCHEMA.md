# Input definitions

## Reusable statistical helpers

HRS helpers expect one row per eligible person-interval. `person_id` is a stable
person key, `transition` is an interval category, `event` is binary 0/1.
`phenotype` has levels `neither`, `cancer_only`, `pain_only`, `cancer_and_pain` in
that order. `age`, `depressive_score` and `noncancer_comorbidity_count` are numeric;
`female`, `partnered`, `current_smoking` are coded 0/1; `education3` is 1–3 and
`wealth_quintile` is 1–5. HRS design fields are `stratum`, `half_sample`,
`person_id` and positive finite `analysis_weight_norm`.

Use validated design fields and weights from your own source/preparation, not
synthetic values or these HRS fields for another cohort. The demonstration has
one interval per synthetic person, not a reconstruction of the study panel.

`fu_pool(q,u,dfcom)` requires matching vectors of estimates and within-imputation
variances, m >= 2, and the complete-data model residual degrees of freedom.
RR estimates must be pooled on the log scale. The study used m=20 and 50 MI
iterations; neither imputations nor imputation setup are included here.

`br_standardize(fit,d,weight)` expects a logistic fit with a four-level phenotype
and weights in `d`. It averages counterfactual probabilities over the supplied
covariate distribution and uses conditional delta-method variance; it does not
incorporate uncertainty in the covariate distribution or estimated weights.
`br_pool(...,risk=TRUE)` preserves identity-scale Rubin pooling and applies a
logit-delta CI transformation to the pooled probability. No CI clipping is used.
`cpd_meta()` expects cohort log RRs and their SEs and uses REML/knha.

## Figure renderer CSV schema

The renderer is tailored to the study panel dimensions: 60 cohort RR rows, eight
main meta rows, 12 model-sample rows, 16 standardized-risk rows, 20 RD rows,
18 pain-gradient rows, 18 function-adjustment rows, 12 score-definition rows and
15 persistence-robustness cells. New studies may require changing panel limits,
assertions and labels. RR CIs must be positive; missing values are not zeros.
The S4 miniature forest uses a fixed 0.75–1.45 scale and will reject out-of-range
intervals. Real aggregate CSV files are not distributed in this code-only release.

Required filenames and original exported fields follow. Extra fields are allowed.
Consult the R filters for categorical values; these names describe the input
contract, not downloadable result files.

### cohort_RR_current.csv

`cohort`, `estimand`, `outcome`, `contrast`, `log_rr`, `se`, `rr`, `conf_low`, `conf_high`, `n_intervals`, `n_persons`, `events`, `version`, `method`

### meta_current.csv

`cohort`, `estimand`, `outcome`, `contrast`, `log_rr`, `se`, `rr`, `conf_low`, `conf_high`, `tau2`, `i2`, `p_value`, `k`, `n_intervals`, `events`, `method`

### model_samples_current.csv

`cohort`, `estimand`, `outcome`, `n_intervals`, `n_persons`, `events`, `version`

### HRS_standardized_risks_current.csv

`estimate`, `se`, `conf_low`, `conf_high`, `df`, `dfcom`, `m`, `within_variance`, `between_variance`, `mcse`, `phenotype`, `ci_scale`, `analysis`, `analysis_version`, `method`, `cohort`

### HRS_risk_differences_current.csv

`estimate`, `se`, `conf_low`, `conf_high`, `df`, `dfcom`, `m`, `within_variance`, `between_variance`, `mcse`, `contrast`, `ci_scale`, `analysis`, `analysis_version`, `method`, `cohort`

### HRS_extensions_current.csv

`contrast`, `estimate`, `se`, `conf_low`, `conf_high`, `ratio`, `p_value`, `n_intervals`, `n_persons`, `events`, `cohort`, `estimand`, `model_tag`, `analysis_version`, `variance`

### nonHRS_pain_burden_category_risk_ratios_v1.1.csv

`cohort`, `estimand`, `pain_burden_category`, `reference`, `n_intervals`, `n_persons`, `events`, `log_rr`, `se`, `rr`, `conf_low`, `conf_high`, `p_value`

### nonHRS_onset_persistence_function_and_persistence_sensitivities_v1.1.csv

`cohort`, `estimand`, `scenario`, `adjustment`, `contrast`, `n_intervals`, `n_persons`, `events`, `log_rr`, `se`, `rr`, `conf_low`, `conf_high`, `p_value`

### nonHRS_continuous_depressive_score_sensitivity_v1.0.csv

`cohort`, `contrast`, `n_intervals`, `n_persons`, `estimate_sd`, `se`, `conf_low`, `conf_high`, `p_value`

### nonHRS_persistence_continuous_score_sensitivity_v1.1.csv

`cohort`, `estimand`, `contrast`, `n_intervals`, `n_persons`, `estimate_sd`, `se`, `conf_low`, `conf_high`, `p_value`

### nonHRS_sleep_item_excluded_score_sensitivity_v1.1.csv

`cohort`, `estimand`, `outcome`, `contrast`, `n_intervals`, `n_persons`, `estimate_sd`, `se`, `conf_low`, `conf_high`, `p_value`
