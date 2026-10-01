options(stringsAsFactors = FALSE)
suppressPackageStartupMessages({library(data.table); library(ggplot2); library(scales); library(pdftools); library(patchwork)})
source("code/academic_plot_defaults.R")
figure_dir <- "generated_figures"
dir.create(figure_dir, recursive=TRUE, showWarnings=FALSE)
d <- fread("supporting/flow/dual_estimand_aggregated_flow_v1.1.csv")
d[, cohort := factor(cohort, levels=c("HRS", "SHARE", "CHARLS"))]
onset_agg <- d[estimand == "Onset estimand"]
persistence_agg <- d[estimand == "Persistence estimand"]
common_start <- c("Baseline interview", "Age >=50 years", "Valid cancer and pain", "Valid baseline symptom score")
common_end <- c("Survived to follow-up", "Follow-up outcome observed", "Positive analysis weight", "Core model sample")
onset_agg[, step_plot := factor(step_plot, levels=rev(c(common_start, "Below symptom threshold", common_end)))]
persistence_agg[, step_plot := factor(step_plot, levels=rev(c(common_start, "At/above symptom threshold", common_end)))]
make_flow_plot <- function(dt, title) {
  ggplot(dt, aes(x = n, y = step_plot, color = cohort)) +
    geom_segment(aes(x = 0, xend = n, yend = step_plot), linewidth = 0.7, color = "grey78") +
    geom_point(size = 2.8) +
    geom_text(
      aes(label = paste0(comma(n), " (", percent(retention, accuracy = 0.1), ")")),
      hjust = -0.08,
      size = 3.2,
      family = "Arial",
      color = "black"
    ) +
    facet_wrap(~cohort, nrow = 1, scales = "free_x") +
    scale_color_manual(values = nejm_cols[c(2, 1, 4)], guide = "none") +
    scale_x_continuous(
      labels = label_number(scale_cut = cut_short_scale()),
      expand = expansion(mult = c(0, 0.52))
    ) +
    labs(
      title = title,
      x = "Person-intervals retained",
      y = NULL
    ) +
    theme_academic(base_size = 12.5) +
    theme(
      plot.title = element_text(face = "bold", size = 13.5, hjust = 0),
      strip.text = element_text(face = "bold", size = 12),
      axis.text.y = element_text(size = 10.5),
      panel.spacing.x = grid::unit(0.9, "lines"),
      plot.margin = margin(8, 12, 8, 8)
    )
}

figure_s1 <- make_flow_plot(onset_agg, "A  Onset of elevated depressive symptoms") /
  make_flow_plot(persistence_agg, "B  Persistence of elevated depressive symptoms") +
  plot_layout(heights = c(1, 1.08)) +
  plot_annotation(
    caption = "Counts sum person-intervals across prespecified primary transitions; percentages are relative to baseline interviewed person-intervals. The core-model step reflects estimand-specific covariate handling."
  ) &
  theme(plot.caption = element_text(family = "Arial", size = 10.2, hjust = 0))

save_pdf_png(
  figure_s1,
  file.path(figure_dir, "FigureS1_dual_estimand_flow_v1.1.pdf"),
  width = 13.2,
  height = 10.5,
  dpi = 260
)
