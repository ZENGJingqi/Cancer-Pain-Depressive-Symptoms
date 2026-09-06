nejm_cols <- c(
  "#BC3C29", "#0072B5", "#E18727", "#20854E",
  "#7876B1", "#6F99AD", "#FFDC91", "#EE4C97"
)

academic_fig_size <- function(width = 7.2, ratio = "4:3") {
  ratios <- c("4:3" = 3 / 4, "16:9" = 9 / 16, "1:1" = 1)
  if (!ratio %in% names(ratios)) stop("ratio must be one of: 4:3, 16:9, 1:1")
  c(width = width, height = unname(width * ratios[[ratio]]))
}

theme_academic <- function(base_size = 16) {
  ggplot2::theme_classic(base_size = base_size, base_family = "Arial") +
    ggplot2::theme(
      plot.title = ggplot2::element_blank(),
      legend.position = "top",
      legend.direction = "horizontal",
      text = ggplot2::element_text(color = "black", family = "Arial"),
      axis.title = ggplot2::element_text(size = base_size + 1, color = "black"),
      axis.text = ggplot2::element_text(size = base_size, color = "black"),
      strip.text = ggplot2::element_text(size = base_size, color = "black"),
      plot.caption = ggplot2::element_text(
        size = base_size - 3, hjust = 0, color = "black", lineheight = 1.05
      ),
      plot.margin = ggplot2::margin(8, 12, 8, 10)
    )
}

save_pdf_png <- function(plot, pdf_file, width = 7.2, height = 5.4, dpi = 220) {
  ggplot2::ggsave(
    pdf_file, plot, width = width, height = height,
    device = grDevices::cairo_pdf
  )
  png_file <- sub("\\.pdf$", "_preview.png", pdf_file)
  render_dir <- file.path(tempdir(), "cpd_figure_render")
  dir.create(render_dir, recursive = TRUE, showWarnings = FALSE)
  temp_pdf <- tempfile(pattern = "figure_", tmpdir = render_dir, fileext = ".pdf")
  temp_png_pattern <- sub("\\.pdf$", "_%d.png", temp_pdf)
  if (!file.copy(pdf_file, temp_pdf, overwrite = TRUE)) {
    stop("Could not stage PDF for preview rendering: ", pdf_file)
  }
  pdftools::pdf_convert(
    temp_pdf, format = "png", pages = 1, dpi = dpi, filenames = temp_png_pattern
  )
  temp_png <- sprintf(temp_png_pattern, 1L)
  if (!file.copy(temp_png, png_file, overwrite = TRUE)) {
    stop("Could not copy rendered preview to: ", png_file)
  }
  unlink(c(temp_pdf, temp_png), force = TRUE)
  if (!file.exists(pdf_file) || !file.exists(png_file) ||
      file.info(pdf_file)$size == 0 || file.info(png_file)$size == 0) {
    stop("Empty figure output: ", pdf_file)
  }
  invisible(c(pdf = pdf_file, png = png_file))
}
