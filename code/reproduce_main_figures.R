options(stringsAsFactors = FALSE)

suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
  library(scales)
  library(pdftools)
  library(patchwork)
})

source(file.path("code", "academic_plot_defaults.R"))

study_id <- "cpd_multicohort_01"
model_dir <- "supporting/models"
table_dir <- "supporting/tables"
qa_dir <- "supporting/flow"
figure_dir <- "generated_figures"
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

cohort_levels <- c("HRS", "SHARE", "CHARLS", "Pooled")
estimand_labels <- c(
  onset = "Onset of elevated symptoms",
  persistence = "Persistence of elevated symptoms"
)
contrast_labels <- c(
  cancer_and_pain_vs_neither = "Cancer + pain vs neither",
  cancer_and_pain_vs_cancer_only = "Cancer + pain vs cancer only"
)

# Figure 1: two estimands and the two focal contrasts.
rr <- fread(file.path(table_dir, "Table2_onset_persistence_adjusted_RRs_v1.1.csv"))
rr <- rr[contrast %chin% names(contrast_labels)]
rr[, cohort_plot := fifelse(cohort == "Random-effects meta-analysis", "Pooled", cohort)]
rr[, cohort_plot := factor(cohort_plot, levels = rev(cohort_levels))]
rr[, estimand_plot := factor(estimand_labels[estimand], levels = estimand_labels)]
rr[, contrast_plot := factor(contrast_labels[contrast], levels = contrast_labels)]

figure1 <- ggplot(rr, aes(x = rr, y = cohort_plot, color = contrast_plot)) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.65, color = "grey45") +
  geom_errorbarh(
    aes(xmin = conf_low, xmax = conf_high),
    position = position_dodge(width = 0.48),
    height = 0.16,
    linewidth = 0.85
  ) +
  geom_point(
    aes(shape = cohort_plot == "Pooled"),
    position = position_dodge(width = 0.48),
    size = 3.2,
    stroke = 0.9
  ) +
  facet_wrap(~estimand_plot, nrow = 1) +
  scale_x_log10(
    breaks = c(0.5, 0.75, 1, 1.5, 2, 3, 4),
    labels = label_number(accuracy = 0.01),
    expand = expansion(mult = c(0.04, 0.04))
  ) +
  scale_color_manual(
    values = c(nejm_cols[2], nejm_cols[1]),
    name = NULL
  ) +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 18), guide = "none") +
  labs(
    x = "Adjusted risk ratio (95% CI; log scale)",
    y = NULL,
    caption = paste0(
      "Cohort-specific survey-weighted modified Poisson models; pooled estimates use REML random-effects meta-analysis ",
      "with Hartung-Knapp confidence intervals."
    )
  ) +
  theme_academic(base_size = 14) +
  theme(
    legend.position = "top",
    legend.justification = "center",
    strip.text = element_text(face = "bold", size = 14),
    panel.spacing.x = grid::unit(1.2, "lines"),
    axis.text.y = element_text(size = 13),
    plot.caption = element_text(size = 10.5, lineheight = 1.05, hjust = 0)
  )

save_pdf_png(
  figure1,
  file.path(figure_dir, "Figure1_onset_persistence_adjusted_RRs_v1.1.pdf"),
  width = 12.2, height = 6.7, dpi = 260
)

# Figure 2: adjusted absolute risks and focal risk differences.
absolute <- fread(file.path(table_dir, "Table3_adjusted_absolute_risks_v1.1.csv"))
rd <- fread(file.path(table_dir, "Table3_adjusted_risk_differences_v1.1.csv"))
absolute[, `:=`(
  estimate_pct = 100 * estimate,
  low_pct = 100 * conf_low,
  high_pct = 100 * conf_high,
  phenotype_plot = factor(
    phenotype,
    levels = c("neither", "cancer_only", "pain_only", "cancer_and_pain"),
    labels = c("Neither", "Cancer only", "Pain only", "Cancer + pain")
  ),
  cohort = factor(cohort, levels = c("HRS", "SHARE", "CHARLS")),
  estimand_plot = factor(estimand_labels[estimand], levels = estimand_labels)
)]
absolute[, panel_plot := factor(
  paste(estimand_plot, cohort, sep = ": "),
  levels = as.vector(t(outer(estimand_labels, c("HRS", "SHARE", "CHARLS"), paste, sep = ": ")))
)]

risk_plot <- ggplot(absolute, aes(x = phenotype_plot, y = estimate_pct, color = phenotype_plot)) +
  geom_errorbar(aes(ymin = low_pct, ymax = high_pct), width = 0.14, linewidth = 0.75) +
  geom_point(size = 2.8) +
  facet_wrap(~panel_plot, ncol = 3, scales = "free_y") +
  scale_color_manual(values = nejm_cols[c(6, 4, 3, 1)], guide = "none") +
  scale_y_continuous(labels = label_number(suffix = "%", accuracy = 1), expand = expansion(mult = c(0.08, 0.12))) +
  labs(x = NULL, y = "Adjusted absolute risk (95% CI)") +
  theme_academic(base_size = 12.5) +
  theme(
    strip.text = element_text(face = "bold", size = 10.8),
    axis.text.x = element_text(angle = 25, hjust = 1, vjust = 1, size = 10.5),
    panel.spacing = grid::unit(0.8, "lines"),
    plot.margin = margin(6, 10, 4, 8)
  )

rd <- rd[contrast %chin% names(contrast_labels)]
rd[, `:=`(
  estimate_pp = 100 * estimate,
  low_pp = 100 * conf_low,
  high_pp = 100 * conf_high,
  contrast_plot = factor(contrast_labels[contrast], levels = rev(contrast_labels)),
  cohort = factor(cohort, levels = c("HRS", "SHARE", "CHARLS")),
  estimand_plot = factor(estimand_labels[estimand], levels = estimand_labels)
)]
rd[, panel_plot := factor(
  paste(estimand_plot, cohort, sep = ": "),
  levels = as.vector(t(outer(estimand_labels, c("HRS", "SHARE", "CHARLS"), paste, sep = ": ")))
)]

rd_plot <- ggplot(rd, aes(x = estimate_pp, y = contrast_plot, color = contrast_plot)) +
  geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.6, color = "grey45") +
  geom_errorbarh(aes(xmin = low_pp, xmax = high_pp), height = 0.16, linewidth = 0.75) +
  geom_point(size = 2.8) +
  facet_wrap(~panel_plot, ncol = 3, scales = "free_x") +
  scale_color_manual(values = c(nejm_cols[1], nejm_cols[2]), guide = "none") +
  scale_x_continuous(labels = label_number(suffix = " pp", accuracy = 1), expand = expansion(mult = c(0.14, 0.14))) +
  labs(x = "Adjusted risk difference (95% CI)", y = NULL) +
  theme_academic(base_size = 12.5) +
  theme(
    strip.text = element_text(face = "bold", size = 10.8),
    axis.text.y = element_text(size = 10.2),
    panel.spacing = grid::unit(0.8, "lines"),
    plot.margin = margin(4, 10, 6, 8)
  )

figure2 <- risk_plot / rd_plot +
  plot_layout(heights = c(1.1, 1)) +
  plot_annotation(tag_levels = "A") &
  theme(plot.tag = element_text(family = "Arial", face = "bold", size = 15))

save_pdf_png(
  figure2,
  file.path(figure_dir, "Figure2_adjusted_absolute_risks_and_differences_v1.1.pdf"),
  width = 13.2, height = 11.2, dpi = 260
)

# Figure 3: cohort-specific pain-burden gradients.
gradient <- fread(file.path(model_dir, "pain_burden_category_risk_ratios_v1.1.csv"))
reference_rows <- unique(gradient[, .(cohort, estimand)])[, .(
  cohort, estimand,
  pain_burden_category = "none",
  rr = 1,
  conf_low = 1,
  conf_high = 1
)]
gradient <- rbindlist(list(gradient, reference_rows), use.names = TRUE, fill = TRUE)
gradient[, burden_plot := factor(
  pain_burden_category,
  levels = c("none", "mild_or_1_site", "moderate_or_2_sites", "severe_or_3plus_sites"),
  labels = c("No pain", "Mild / 1 site", "Moderate / 2 sites", "Severe / >=3 sites")
)]
gradient[, `:=`(
  cohort = factor(cohort, levels = c("HRS", "SHARE", "CHARLS")),
  estimand_plot = factor(estimand_labels[estimand], levels = estimand_labels)
)]
gradient[, panel_plot := factor(
  paste(estimand_plot, cohort, sep = ": "),
  levels = as.vector(t(outer(estimand_labels, c("HRS", "SHARE", "CHARLS"), paste, sep = ": ")))
)]

figure3 <- ggplot(gradient, aes(x = burden_plot, y = rr, color = cohort, group = 1)) +
  geom_hline(yintercept = 1, linetype = "dashed", linewidth = 0.6, color = "grey45") +
  geom_line(linewidth = 0.7) +
  geom_errorbar(aes(ymin = conf_low, ymax = conf_high), width = 0.12, linewidth = 0.7) +
  geom_point(size = 2.8) +
  facet_wrap(~panel_plot, ncol = 3) +
  scale_color_manual(values = nejm_cols[c(2, 1, 4)], guide = "none") +
  scale_y_continuous(labels = label_number(accuracy = 0.1), expand = expansion(mult = c(0.04, 0.04)), breaks = seq(1, 2, 0.2)) +
  labs(
    x = "Pain burden (severity in HRS/SHARE; number of painful sites in CHARLS)",
    y = "Adjusted risk ratio (95% CI) vs no pain",
    caption = "Gradient models adjust for cancer history and the common covariate set; burden categories are not pooled across cohorts."
  ) +
  theme_academic(base_size = 12.5) +
  theme(
    strip.text = element_text(face = "bold", size = 10.8),
    axis.text.x = element_text(angle = 25, hjust = 1, vjust = 1, size = 10.2),
    panel.spacing = grid::unit(0.8, "lines"),
    plot.caption = element_text(size = 10.2, hjust = 0),
    plot.margin = margin(8, 12, 8, 10)
  )

save_pdf_png(
  figure3,
  file.path(figure_dir, "Figure3_pain_burden_gradients_v1.1.pdf"),
  width = 13.2, height = 8.4, dpi = 260
)

# Supplementary Figure S2: attenuation after functional adjustment.
function_meta <- fread(file.path(
  model_dir, "onset_persistence_function_and_sensitivity_meta_v1.1.csv"
))[
  scenario == "function_adjustment_sequence" &
    contrast %chin% c("cancer_and_pain_vs_neither", "pain_only_vs_neither")
]
function_meta[, adjustment_plot := factor(
  adjustment,
  levels = c("core", "mobility", "mobility_adl"),
  labels = c("Core model", "+ Mobility limitations", "+ Mobility and ADL limitations")
)]
function_meta[, `:=`(
  estimand_plot = factor(estimand_labels[estimand], levels = estimand_labels),
  contrast_plot = factor(
    c(
      cancer_and_pain_vs_neither = "Cancer + pain vs neither",
      pain_only_vs_neither = "Pain only vs neither"
    )[contrast]
  )
)]

figure_s2 <- ggplot(
  function_meta,
  aes(x = rr, y = adjustment_plot, color = contrast_plot)
) +
  geom_vline(xintercept = 1, linetype = "dashed", linewidth = 0.6, color = "grey45") +
  geom_errorbarh(
    aes(xmin = conf_low, xmax = conf_high),
    position = position_dodge(width = 0.44),
    height = 0.16,
    linewidth = 0.75
  ) +
  geom_point(position = position_dodge(width = 0.44), size = 2.9) +
  facet_wrap(~estimand_plot, nrow = 1) +
  scale_color_manual(values = c(nejm_cols[2], nejm_cols[1]), name = NULL) +
  scale_x_continuous(expand = expansion(mult = c(0.04, 0.04)), breaks = scales::breaks_pretty(n=5)) +
  labs(
    x = "Adjusted risk ratio (95% CI)",
    y = NULL,
    caption = "Functional models are explanatory adjustments and are not causal mediation analyses."
  ) +
  theme_academic(base_size = 13.5) +
  theme(
    strip.text = element_text(face = "bold", size = 13),
    axis.text.y = element_text(size = 11.5),
    plot.caption = element_text(size = 10.5, hjust = 0)
  )

save_pdf_png(
  figure_s2,
  file.path(figure_dir, "FigureS2_function_adjustment_sequence_v1.1.pdf"),
  width = 11.8, height = 6.5, dpi = 260
)

writeLines(
  capture.output(sessionInfo()),
  file.path(figure_dir, "figure_session_info_v1.1.txt"),
  useBytes = TRUE
)

cat("Expanded manuscript figures exported.\n")
