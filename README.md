# Current pain and cancer history in depressive symptom transitions

Content freeze dated 2026-10-01. Coordinated prospective analyses of HRS, SHARE and CHARLS adults aged at least 50 years. Primary outcome: next-wave high depressive symptoms among respondents initially below threshold. Important secondary outcome: persistence among respondents initially above threshold. Each cohort is analysed separately. These are symptom-transition associations among surviving respondents, not clinical depression diagnoses, causal effects or validated prediction performance.

## Current materials

- [Manuscript Word](current/manuscript/Manuscript_content_v1.0.docx) and [readable text](current/manuscript/Manuscript_content_v1.0.md).
- [Chinese research closeout report](current/manuscript/Research_closeout_report_Chinese.docx).
- [Current aggregate results](current/results/) and [five R figures](current/figures/).
- [Selected code](current/code/), [source provenance](PROVENANCE.json) and [file hashes](MANIFEST_SHA256.csv).

HRS follow-up depressive symptoms for 2022 now use Final Core Version 2.0. Baseline and earlier intervals retain the frozen RAND framework; mortality remains from the archived RAND source, not a newly obtained Final Tracker. Current main symptom models contain 141,599 onset intervals and 43,192 persistence intervals. Cancer and pain versus neither has pooled RR 1.42 (95% CI 1.17-1.72) for onset and 1.22 (1.04-1.42) for persistence.

HRS absolute risks and risk differences were corrected using survey-logistic standardization on the same saved imputations after probability QA. This is a disclosed post hoc method correction. Modified Poisson RRs remain the relative-effect estimates. Other cohorts' older absolute-risk tables are historical and are not mixed into the current absolute-risk table.

## Reproduce from aggregates

From repository root, with data.table, ggplot2, metafor and pdftools installed:

```r
source("current/code/reproduce_current.R", encoding = "UTF-8")
```

This rebuilds eight REML/Hartung-Knapp main syntheses and five PDF/PNG figures from safe summaries, not all participant-level processing from raw records. Local reference functions have portable placeholder paths and require separately licensed data plus dependencies; sourcing them does not start analysis. See [code scope](current/code/README.md).

## Important limits

Official SHARE PSU/stratum sensitivity was not performed and was excluded from the analysis scope. Reported SHARE models use country strata and household-first clustering, which may not reproduce official-design variance. Some suppressed MI distributions and original private warnings were not fully reviewed. Final baseline descriptive characteristics and detailed eligibility flow were not regenerated from participant records; current Table 1 reports model counts. Institutional ethics determination and author-level submission fields remain to confirm. This content freeze is not a declaration that all diagnostic gates or submission requirements have passed.

[Historical September materials](archive/review_2026-09-07/) are preserved for traceability and are not current HRS results. No raw data, participant records, imputations, model objects or private logs are distributed. Obtain data separately from [HRS](https://hrsdata.isr.umich.edu/), [SHARE](https://share-eric.eu/data/data-access) and [CHARLS](https://charls.pku.edu.cn/) under their access conditions.
