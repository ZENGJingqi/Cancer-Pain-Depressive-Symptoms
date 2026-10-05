# Aggregate data dictionary

Each row is a model-level estimate, model-population count or display cell, not a participant.
The files contain no participant IDs or individual survey answers. Obtain raw data separately
from https://hrsdata.isr.umich.edu/, https://share-eric.eu/data/data-access and https://charls.pku.edu.cn/.
HRS and SHARE source access and analysis remain subject to their individual agreements.

`estimand`: onset uses a baseline-low symptom population; persistence uses a baseline-high population.
`outcome`: symptoms denotes next-wave high depressive symptoms; symptoms_or_death is a distinct composite.
`contrast`: exposure phenotype comparison, not a causal contrast or clinical depression diagnosis.
`rr` and `ratio`: multiplicative effect scale where specified by model_tag, not interchangeable with absolute risks.
`log_rr`: log risk ratio; `se`: standard error on the file's stated model scale.
`estimate_sd`: standardized symptom-score difference, not RR.
`estimate` in HRS_extensions mixes model scales: continuous_score and no_sleep_score are additive differences;
inspect model_tag before interpreting. In HRS_standardized_risks_current.csv, estimate and limits
are probabilities on the 0–1 scale. Multiply by 100 for percentages displayed in the manuscript.
In HRS_risk_differences_current.csv, estimate and limits are differences of probabilities;
multiply by 100 for percentage points. ci_scale describes interval/pooling construction,
not the reporting unit. Never infer an RD confidence interval by subtracting marginal risk limits.
`conf_low` and `conf_high`: 95% confidence limits on the stated effect scale.
`n_intervals`: person-interval count; `n_persons`: unique persons in that model; `events`: outcome count.
Do not add unique persons across onset/persistence or overlapping contrasts.
`m`, `df`, `dfcom`, variance and `mcse`: saved multiple-imputation pooling summaries.
`k`, `tau2`, `i2`: number of cohort estimates and heterogeneity in the main synthesis.
HRS/CHARLS symptom scales and SHARE EURO-D thresholds differ. Neither is a clinical diagnosis.
Only HRS current absolute risks are distributed. Different outcome definitions can use different samples and weights.
Main cohort RRs are survey modified-Poisson estimates; current HRS absolute risks use a disclosed post-hoc logistic correction.
Frozen model results have not been refit for this package.
