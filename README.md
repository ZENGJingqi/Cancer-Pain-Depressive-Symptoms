# Cancer history pain and depressive symptom transitions

Research materials for **Current pain and cancer history in depressive symptom transitions across three ageing cohorts**.

**Prepublication review release v0.9, 6 September 2026. Not a peer-reviewed publication or a submission-ready final analysis.** The study examines any cancer history and current pain in relation to subsequent elevated depressive symptoms in HRS, SHARE and CHARLS. Onset is the primary outcome; persistence is a secondary outcome. Results describe associations among surviving follow-up respondents, not causal effects, predictive superiority, or a general health-risk ranking. This is not a digestive-cancer-specific study.

## Materials

- [Full editable manuscript](manuscript/Manuscript_review_v0.9.docx): text, references, Tables 1–3, Table S3 and five figures.
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

ZENGJingqi. Cancer-Pain-Depressive-Symptoms. Prepublication research repository, review release v0.9 (2026). https://github.com/ZENGJingqi/Cancer-Pain-Depressive-Symptoms

For an exact snapshot, also record the commit hash or tag `review-v0.9`. This is a repository citation, not a claim of publication or a finalized paper author list. No DOI has been assigned.

## Rights

No license is asserted over third-party cohort data. A reuse license for original repository materials has not yet been selected by the author. Public access alone is not a grant of unrestricted redistribution rights.
