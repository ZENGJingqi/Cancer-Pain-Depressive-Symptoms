# Cancer history pain and depressive symptom transitions

Research materials for **Current pain and cancer history in depressive symptom transitions across three ageing cohorts**.

**Review update 7 September 2026; complete manuscript retained at v0.9. Not a peer-reviewed publication or submission-ready final analysis.** The study examines any cancer history and current pain in relation to subsequent elevated depressive symptoms in HRS, SHARE and CHARLS. Onset is the primary outcome; persistence is a secondary outcome. Results describe associations among surviving follow-up respondents, not causal effects, predictive superiority, or a general health-risk ranking. This is not a digestive-cancer-specific study.

The new [Chinese progress report](manuscript/Research_progress_report_2026-09-07_ZH.docx), [HRS Final Core endpoint summaries](supporting/hrs_final_core_2026-09-07/README.md) and [source snapshot](code/hrs_final_core_reference/README.md) are separate from the older complete manuscript. See [version guide](manuscript/README.md) and [release notes](RELEASE_2026-09-07.md). New HRS extensions and multicohort figures have not yet been synchronized. New Poisson-standardized risks do not replace the manuscript's logistic-standardized Table 3.

## Materials

- [Full editable manuscript v0.9](manuscript/Manuscript_review_v0.9.docx): retained review text, references, Tables 1–3, Table S3 and five figures; predates the Final Core update.
- [Searchable manuscript text](manuscript/Manuscript_text_v0.9.md): prose and legends; full numerical tables are in the DOCX and CSV files.
- [Supporting results](supporting/README.md): aggregate tables and plot inputs only.
- [Figures](figures): the reviewed vector PDFs and PNG previews.
- [Code guide](code/README.md): aggregate-only reproduction and selected historical analysis source modules.
- [Data access](DATA_ACCESS.md), [outstanding checks](STATUS.md) and [file checksums](MANIFEST_SHA256.csv).

## Reproduce the five figures without participant data

From this repository root, in R 4.5 or a compatible environment with data.table, ggplot2, scales, pdftools and patchwork installed:

```sh
Rscript code/reproduce_main_figures.R
Rscript code/reproduce_flow_figure.R
```

Outputs go to `generated_figures/`, leaving archived figures unchanged. Arial and Cairo PDF support are required for matching typography. These commands read only the published aggregate CSV files. They do not refit participant-level models. Package versions and verification status are recorded in `REPRODUCTION_CHECK.md`.

This is a selected-code and aggregate-results release, **not a complete raw-data-to-results replication package**. See STATUS.md before reusing the findings. Participant-level data, derived person-interval files, imputation objects, model objects, private logs, access statements and credentials are not included. Obtain data independently from each provider under its current terms; do not send restricted records to AI services.

## Citation

For the 7 September report/code/aggregate update, cite this repository with the relevant commit or tag `review-update-2026-09-07`. The manuscript version itself remains v0.9.

ZENGJingqi. Cancer-Pain-Depressive-Symptoms. Prepublication research repository, review release v0.9 (2026). https://github.com/ZENGJingqi/Cancer-Pain-Depressive-Symptoms

For an exact snapshot, also record the commit hash or tag `review-v0.9`. This is a repository citation, not a claim of publication or a finalized paper author list. No DOI has been assigned.

## Rights

No license is asserted over third-party cohort data. A reuse license for original repository materials has not yet been selected by the author. Public access alone is not a grant of unrestricted redistribution rights.
