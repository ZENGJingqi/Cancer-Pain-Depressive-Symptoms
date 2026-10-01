# Code scope

`reproduce_current.R` is the runnable aggregate-only entry: eight main RR syntheses and five figures. It reads CSV summaries only. Required packages: data.table, ggplot2, metafor, pdftools. Run from repository root. Outputs go to current/results and current/figures; preserve a Git checkout if comparing output changes.

`bounded_absolute_risk.R`, `hrs_final_extensions.R` and `rebuild_composite_lineage.R` retain the actual function logic used for the latest local components, with machine paths replaced by portable placeholders. They are selected reference functions, not a complete raw-data-to-paper pipeline. They require separately licensed source layers, project helpers and locally configured paths. Do not use an AI service to read restricted data. Sourcing these files only defines functions; no study models automatically run.

Earlier core, survey, MI and synthetic-test reference code is retained in archive/review_2026-09-07/code. Do not run old pipelines on current sources without reconciling versions. Source hashes and adaptations are listed in root PROVENANCE.json.
