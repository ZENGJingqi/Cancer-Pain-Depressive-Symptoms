# Aggregate-only current figure entry. No models, new imputations or frozen file overwrites.
publication_output <- getOption('cpd.figure.output','generated_publication_figures')
options(cpd.figure.output=publication_output)
source('current/code/render_publication_figures.R',encoding='UTF-8')
source('current/code/render_robustness_matrix.R',encoding='UTF-8')
fonts <- data.table::rbindlist(list(
 data.table::fread(file.path(publication_output,'source_and_checks','font_checks.csv'))[!startsWith(file,'FigureS4_')],
 data.table::fread(file.path(publication_output,'source_and_checks','S4_font_checks.csv'))))
data.table::fwrite(fonts,file.path(publication_output,'source_and_checks','font_checks.csv'))
cat('Eight current quantitative figures generated; Figure1 uses separately supplied editable PPTX.\n')
