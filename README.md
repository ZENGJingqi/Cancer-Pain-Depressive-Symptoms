# Current pain and cancer history in depressive symptom transitions

Model results frozen on 2026-10-01, manuscript and visual revision on 2026-10-03, and materials packaged on 2026-10-05. Coordinated prospective analyses of HRS, SHARE and CHARLS adults aged at least 50 years. Primary outcome: next-wave high depressive symptoms among respondents initially below threshold. Important secondary outcome: persistence among respondents initially above threshold. Each cohort is analysed separately. These are symptom-transition associations among surviving respondents, not clinical depression diagnoses, causal effects or validated prediction performance.

## Current materials

- [Current manuscript Word](current/manuscript/Manuscript.docx), [PDF](current/manuscript/Manuscript.pdf) and [readable text](current/manuscript/Manuscript.md). The Word/PDF are byte-identical to the reviewed 26-page human manuscript, with three main tables and one supplementary table.
- [Supplementary material](current/manuscript/Supplementary_material.md) and [all figure legends](current/manuscript/Figure_legends.txt).
- [Current aggregate results](current/results/), [exact figure data](current/figure_data/), [table display cells](current/table_data/) and [data inventory](current/data_inventory.csv). See [units and interpretation](current/DATA_DICTIONARY.md).
- [All nine current figures](current/figures/): original PNGs and PDFs, plus native editable Figure1 PowerPoint. Eight statistical PDFs are vector; Figure1 PDF is a raster reading wrapper. Figure1 PNG is 1920 px wide, adequate for 300 effective dpi at 162.56 mm, despite its original ~72 dpi metadata. See [figure inventory](current/figure_inventory.json).
- [Selected code](current/code/), [source provenance](PROVENANCE.json) and [file hashes](MANIFEST_SHA256.csv).
- [Materials status](current/submission/PACKAGE_STATE.json) and [author checks before submission](current/submission/BEFORE_SUBMISSION.md). Packaging is complete within the retained scope; this is not an all-gates-passed or submitted declaration.

HRS follow-up depressive symptoms for 2022 now use Final Core Version 2.0. Baseline and earlier intervals retain the frozen RAND framework; mortality remains from the archived RAND source, not a newly obtained Final Tracker. Current main symptom models contain 141,599 onset intervals and 43,192 persistence intervals. Cancer and pain versus neither has pooled RR 1.42 (95% CI 1.17-1.72) for onset and 1.22 (1.04-1.42) for persistence.

HRS absolute risks and risk differences were corrected using survey-logistic standardization on the same saved imputations after probability QA. This is a disclosed post hoc method correction. Modified Poisson RRs remain the relative-effect estimates. Other cohorts' older absolute-risk tables are historical and are not mixed into the current absolute-risk table.

## Reproduce from aggregates

From repository root, install data.table, ggplot2, patchwork, ggsci, colorspace and pdftools, and make Arial available. To reproduce the eight current quantitative figures without fitting models:

```r
source("current/code/reproduce_publication_figures.R", encoding = "UTF-8")
```

Outputs are isolated in `generated_publication_figures/`; frozen manuscript assets and results are not overwritten. Figure1 is supplied as an editable conceptual diagram and is not reconstructed by these R scripts. The retained `reproduce_current.R` entry requires metafor and rebuilds eight REML/Hartung-Knapp syntheses with the earlier five-figure style into separate generated directories; those old plots are not the manuscript figures. Neither entry reproduces all participant-level processing. Local reference functions have portable placeholder paths and require separately licensed data plus dependencies; sourcing them does not start analysis. See [code scope](current/code/README.md).

## Important limits

Official SHARE PSU/stratum sensitivity was not performed and was excluded from the analysis scope. Reported SHARE models use country strata and household-first clustering, which may not reproduce official-design variance. Some suppressed MI distributions and original private warnings were not fully reviewed. Final baseline descriptive characteristics and detailed eligibility flow were not regenerated from participant records; current Table 1 reports model counts. Institutional ethics determination and author-level submission fields remain to confirm. This content freeze is not a declaration that all diagnostic gates or submission requirements have passed.

[The previous October manuscript and figures](archive/content_freeze_2026-10-01_before_visual_revision/) and [historical September materials](archive/review_2026-09-07/) are preserved for traceability, not mixed with the current manuscript. No raw data, participant records, imputations, model objects or private logs are distributed. Obtain data separately from [HRS](https://hrsdata.isr.umich.edu/), [SHARE](https://share-eric.eu/data/data-access) and [CHARLS](https://charls.pku.edu.cn/) under their access conditions.
