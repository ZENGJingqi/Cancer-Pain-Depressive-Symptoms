# Usage: Rscript scripts/render_figures.R /path/to/authorized_aggregate_results /new/output
args <- commandArgs(trailingOnly=TRUE)
if(length(args)!=2L) stop('Supply aggregate input directory and a NEW output directory')
script <- sub('^--file=','',grep('^--file=',commandArgs(FALSE),value=TRUE)[1])
root <- dirname(dirname(normalizePath(script,mustWork=TRUE)))
src <- normalizePath(args[1],mustWork=TRUE)
out <- args[2]
if(dir.exists(out)) stop('Output exists; choose a new directory')
needed <- c('data.table','ggplot2','patchwork','ggsci','colorspace','pdftools')
missing <- needed[!vapply(needed,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop('Install packages first: ',paste(missing,collapse=', '))
paths <- list.files(src,pattern='[.]csv$',full.names=TRUE)
before <- tools::md5sum(paths)
options(cpd.figure.results=src,cpd.figure.output=out)
source(file.path(root,'R/render_publication_figures.R'),encoding='UTF-8',local=new.env(parent=globalenv()))
options(cpd.S4.rows=file.path(out,'source_and_checks/FigureS4_display_rows.csv'))
source(file.path(root,'R/render_robustness_matrix.R'),encoding='UTF-8',local=new.env(parent=globalenv()))
stopifnot(identical(before,tools::md5sum(paths)))
cat('PASS: input CSV files unchanged. Generated figures are not source data.\n')
