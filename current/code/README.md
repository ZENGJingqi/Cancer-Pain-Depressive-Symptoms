# Code scope

`reproduce_publication_figures.R` is the current eight-figure entry. It calls `render_publication_figures.R` and then applies the current S4 design with `render_robustness_matrix.R`. Required packages: data.table, ggplot2, patchwork, ggsci, colorspace and pdftools, with Arial available. Run from repository root. Outputs go to `generated_publication_figures/`, not frozen `current/figures/`. Figure1 is supplied separately as editable PowerPoint. No participant records, model fitting or new imputations are used.

`reproduce_current.R` retains the earlier aggregate-only eight RR syntheses and five-figure style. Required packages: data.table, ggplot2, metafor, pdftools. Outputs now go to `generated_aggregate_meta/` and `generated_legacy_figures/`; it does not overwrite current results or create the current manuscript figure layout. Frozen source CSVs remain unchanged. Run from repository root.

`bounded_absolute_risk.R`, `hrs_final_extensions.R` and `rebuild_composite_lineage.R` retain the actual function logic used for the latest local components, with machine paths replaced by portable placeholders. They are selected reference functions, not a complete raw-data-to-paper pipeline. They require separately licensed source layers, project helpers and locally configured paths. Do not use an AI service to read restricted data. Sourcing these files only defines functions; no study models automatically run.

Earlier core, survey, MI and synthetic-test reference code is retained in archive/review_2026-09-07/code. Do not run old pipelines on current sources without reconciling versions. Source hashes and adaptations are listed in root PROVENANCE.json.
