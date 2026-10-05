# Cancer history, pain and depressive symptoms

R code for survey-weighted risk ratios, finite-df multiple-imputation pooling,
logistic risk standardization, random-effects synthesis and study figure rendering.
The repository also contains the editable study-design Figure 1.

## Run a functional example

Use R 4.5 or later. Install the dependencies in your own R library:

```r
install.packages(c("survey", "mice", "data.table", "metafor"))
```

From the repository root:

```sh
Rscript examples/run_demo.R
```

The example generates synthetic records in memory and writes explicitly labelled
synthetic outputs to `output/demo`. It tests model fitting, contrasts, pooling,
probability bounds, risk-difference coherence and REML/Hartung–Knapp synthesis.
It does not reproduce the study estimates. Choose a new output path on later runs:
`Rscript examples/run_demo.R /new/output/path`.

## Use your own data

Source `R/core_functions.R` and `R/analysis_tools.R`. `hrs_design()` implements
the HRS design used by this project; do not apply it to SHARE or CHARLS.
`cpd_fit_rr()` accepts a correctly constructed `survey` design and a formula.
`fu_pool()` pools estimates and within-imputation variances with finite complete-
data residual degrees of freedom. `br_standardize()` requires a logistic fit and
positive standardization weights. `cpd_meta()` accepts cohort log RRs and SEs.

The original statistical helper functions are extracted from the study code;
the portable wrappers and synthetic demo are adaptations. These files do not
provide raw-file harmonization, eligibility construction, retention-weight
estimation or a complete raw-data-to-manuscript pipeline. Independent access to
the cohort data and cohort-specific preparation is required.

See [data products and access](docs/DATA_ACCESS.md) and
[input definitions](docs/INPUT_SCHEMA.md). The manuscript and study result files
are not distributed in the current repository tree. No participant records,
imputations, fitted study model objects or private logs are included.

## Render the study figure layouts from your own aggregate inputs

```r
install.packages(c("ggplot2", "patchwork", "ggsci", "colorspace", "pdftools"))
```

```sh
Rscript scripts/render_figures.R /path/to/aggregate_csvs /new/figure_output
```

This study-specific renderer requires the filenames, fields and panel dimensions
listed in the input documentation. It is not a general-purpose plotting package.
It produces eight quantitative figure layouts as vector PDFs and 300 dpi PNGs.
Arial must be available and embedded; otherwise font validation fails. Rendering
reads inputs without changing them. Real study aggregate inputs are not bundled.

`figure1/Figure1_study_design_editable.pptx` is editable;
`figure1/Figure1_study_design.png` is its preview. Statistical figures are created
by R, not by the Figure 1 PowerPoint.
