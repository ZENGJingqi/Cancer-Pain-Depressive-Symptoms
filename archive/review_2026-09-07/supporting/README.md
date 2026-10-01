# Supporting materials

All CSV rows are aggregate estimates, characteristics or flow counts; none are participant records.

## Main tables

- Table1: baseline characteristics for onset and persistence populations. SHARE onset descriptive sample is 62,878 eligible intervals before complete-covariate restriction; the main model uses 62,160. These are intentionally different populations.
- Table2: cohort-specific and pooled adjusted risk ratios for both symptom estimands.
- Table3 absolute risks and risk differences: logistic standardization results. Risks are proportions; multiply by 100 for percent, and differences by 100 for percentage points.
- TableS3: pain-only versus cancer-only direct comparisons for symptom-only and death-or-symptom composite outcomes across all three cohorts. These are distinct outcome analyses, not an isolated test of death selection.

## Plot inputs and additional summaries

- `models/pain_burden_category_risk_ratios_v1.1.csv`: cohort-specific severity/site-count gradient estimates, not a harmonized pooled dose scale.
- `models/onset_persistence_function_and_sensitivity_meta_v1.1.csv`: aggregate functional and sensitivity results. Function adjustment is explanatory, not mediation analysis.
- `models/HRS_returned_RRs_reviewed.csv`: pooled aggregate estimates from the independent local HRS extension run.
- `flow/dual_estimand_aggregated_flow_v1.1.csv`: corrected primary-transition sample counts used for Figure S1. Counts are person-intervals, not unique persons.

Additional model summaries cover complete-case and prespecified sensitivities, continuous symptom scores, sleep-item exclusion, pain trends, age/sex effect modification, cancer-by-pain interaction, and non-HRS composite outcomes with SHARE weight trimming. The v1.2 composite file contains SHARE and CHARLS only; HRS extensions are in the separate reviewed HRS file. These summaries are sensitivity or exploratory evidence as specified in the manuscript, not additional independent primary outcomes. Effect modification and interaction tests are distinct from subgroup-specific significance tests.

`rr`, `conf_low` and `conf_high` denote a risk ratio and its interval where present; `estimate` is on the scale identified by the relevant table. Consult the full Methods and table footnotes before interpreting any field. Machine-readable filenames retain original analysis-version suffixes so their lineage is not lost. The repository version refers to the packaging, not a new model fit.
