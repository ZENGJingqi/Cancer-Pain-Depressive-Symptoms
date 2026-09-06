# Code scope

## Executable aggregate-only reproduction

Run `Rscript code/reproduce_main_figures.R` and `Rscript code/reproduce_flow_figure.R` from the repository root. These use published CSV summaries only. The plotting logic preserves the reviewed full-confidence-interval display correction. Flow plotting now reads the already-aggregated corrected flow table instead of accessing private records. Outputs are separate from archived figures.

## Selected reference analysis code

`reference_analysis/` contains source snapshots for the primary onset model (28), persistence model (40), logistic standardization (41 and 43), non-HRS direct comparisons (68), non-HRS composite analysis (70), and the independent local HRS extension (`HRS_run.R`). These document statistical implementation but **cannot reproduce the analysis from this public repository alone**. They require the private project's harmonized/frozen records and, in some cases, saved imputation objects. Upstream harmonization and every extension are not included in this selected release.

Machine-specific library paths were removed; the HRS output default was changed to a temporary local directory. A safety guard prevents execution unless an authorised human explicitly sets `CPD_AUTHORIZED_LOCAL_REFERENCE_RUN=YES` in an independent compliant local environment. This variable is not permission from a data provider. Review and adapt paths before any authorised use. Do not execute these modules through AI-connected tools on restricted data. They can write individual-level imputation objects; none of those outputs belong in this repository.

Original model versions are retained for transparency; in particular, SHARE official design sensitivity and full MI validation are still pending. The reference sources are not a new validated pipeline, and historical cache reuse in older modules must not be assumed safe for a new analysis or changed estimand. Module 40's early probability outputs are superseded by logistic standardization in 41/43 for manuscript Table 3.
