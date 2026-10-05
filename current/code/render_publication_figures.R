# R-plot-requirements revision: publication-sized figures from frozen, aggregate-only results. No model fitting.
# Configure packages in your R library before sourcing.
suppressPackageStartupMessages({library(data.table); library(ggplot2); library(patchwork); library(grid); library(ggsci)})
root <- 'current'
src <- getOption('cpd.figure.results',file.path(root,'results'))
out <- getOption('cpd.figure.output','generated_publication_figures')
dir.create(out,recursive=TRUE,showWarnings=FALSE)
qa <- file.path(out,'source_and_checks'); dir.create(qa,showWarnings=FALSE)
used <- character()
read <- function(n) {used <<- c(used,n); fread(file.path(src,n))}
nejm <- ggsci::pal_nejm()(8)
pal <- setNames(nejm[c(1,2,3,4)],c('HRS','SHARE','CHARLS','Pooled'))
ph <- setNames(nejm[c(5,2,3,1)],c('neither','cancer_only','pain_only','cancer_and_pain'))
plab <- c(neither='Neither',cancer_only='Cancer only',pain_only='Pain only',cancer_and_pain='Cancer and pain')
el <- c(onset='Symptom onset',persistence='Symptom persistence')
body_pt <- 10
text_mm <- body_pt / ggplot2::.pt
pub <- function() theme_classic(base_family='Arial',base_size=body_pt)+theme(
  text=element_text(colour='black'),axis.text=element_text(colour='black',size=body_pt),
  axis.title=element_text(size=body_pt+2),plot.title=element_blank(),
  plot.subtitle=element_blank(),plot.caption=element_blank(),strip.background=element_blank(),
  strip.text=element_text(size=body_pt+2,face='bold'),legend.position='top',
  legend.text=element_text(size=body_pt),legend.title=element_text(size=body_pt),
  plot.margin=margin(7,7,7,7),panel.spacing=unit(.9,'lines'))
# Panel strips identify dimensions; no internal overall titles/subtitles/footnotes.
strip <- function(p,label) {
  p$data$.panel <- label
  p + facet_wrap(~.panel)
}
save_plot <- function(p,folder,name,h,w=6.6) {
  d <- file.path(out,folder); dir.create(d,showWarnings=FALSE)
  path <- file.path(d,paste0(name,'.pdf'))
  ggsave(path,p,width=w,height=h,device=cairo_pdf,bg='white')
  png <- pdftools::pdf_convert(path,format='png',pages=1,dpi=300,
    filenames=file.path(d,paste0(name,'_p%d.%s')),verbose=FALSE)
  stopifnot(file.rename(png,file.path(d,paste0(name,'.png'))))
}
rr <- read('cohort_RR_current.csv'); meta <- read('meta_current.csv')
stopifnot(nrow(rr)==60,nrow(meta)==8)
for(z in list(rr,meta)) stopifnot(all(abs(exp(z$log_rr)-z$rr)<1e-10),
  all(z$conf_low<=z$rr),all(z$conf_high>=z$rr),all(z$conf_low>0))

# Figure 2: native grid forest table, compact column widths; no axis under table text.
ct <- c('cancer_and_pain_vs_neither','pain_only_vs_neither',
        'cancer_only_vs_neither','cancer_and_pain_vs_cancer_only')
ctl <- c('Cancer and pain vs neither','Pain only vs neither',
         'Cancer only vs neither','Cancer and pain vs cancer only')
d <- rbindlist(list(rr[outcome=='symptoms' & contrast %in% ct],meta),fill=TRUE)
stopifnot(nrow(d)==32)
fwrite(d,file.path(qa,'Figure2_display_rows.csv'),bom=TRUE)
dir.create(file.path(out,'Figure2'),showWarnings=FALSE)
pdf <- file.path(out,'Figure2','Figure2_relative_risks.pdf')
cairo_pdf(pdf,width=6.6,height=6.6,family='Arial'); grid.newpage()
gt <- function(x,y,s,size=9.5,bold=FALSE,col='black',just='left') grid.text(s,x=x,y=y,
  just=just,gp=gpar(fontfamily='Arial',fontsize=size,fontface=if(bold) 'bold' else 'plain',col=col))
for(e in names(el)) {
  l <- if(e=='onset') .025 else .53
  gt(l,.972,el[e],11.5,TRUE)
  x0 <- l+.085; x1 <- l+.255; xv <- l+.270
  xp <- function(z) x0+(log(z)-log(.35))/(log(4.5)-log(.35))*(x1-x0)
  gt(xv,.928,'RR (95% CI)',9.5,TRUE)
  for(b in 1:4) {
    ytop <- .892-(b-1)*.189
    gt(l,ytop,ctl[b],9.5,TRUE)
    grid.lines(x=rep(xp(1),2),y=c(ytop-.16,ytop-.052),gp=gpar(col='#8C969A',lty=2,lwd=.7))
    for(i in 1:4) {
      co <- c('HRS','SHARE','CHARLS','Pooled')[i]
      z <- d[estimand==e & contrast==ct[b] & cohort==co]
      stopifnot(nrow(z)==1)
      y <- ytop-.035-i*.030
      if(co=='Pooled') grid.rect(x=l+.22,y=y,width=.45,height=.027,
        gp=gpar(fill='#F0F5F2',col=NA))
      gt(l+.004,y,co,9.5,col='black')
      grid.lines(x=c(xp(z$conf_low),xp(z$conf_high)),y=rep(y,2),gp=gpar(col=pal[co],lwd=1.1))
      grid.points(x=xp(z$rr),y=y,pch=c(HRS=16,SHARE=17,CHARLS=15,Pooled=18)[co],
        size=unit(1.6,'mm'),default.units='npc',gp=gpar(col=pal[co]))
      gt(xv,y,sprintf('%.2f (%.2f-%.2f)',z$rr,z$conf_low,z$conf_high),9.5)
    }
  }
  grid.lines(x=c(x0,x1),y=rep(.095,2),gp=gpar(lwd=.7))
  for(v in c(.5,1,2,4)) {
    grid.lines(x=rep(xp(v),2),y=c(.095,.09),gp=gpar(lwd=.7))
    gt(xp(v),.078,as.character(v),9.5,just='centre')
  }
  gt((x0+x1)/2,.048,'Adjusted RR (log scale)',9.5,just='centre')
}
dev.off()
png <- pdftools::pdf_convert(pdf,format='png',dpi=300,pages=1,
  filenames=file.path(out,'Figure2','Figure2_relative_risks_p%d.%s'),verbose=FALSE)
stopifnot(file.rename(png,file.path(out,'Figure2','Figure2_relative_risks.png')))

# Figure 3: same population in each row, risks beside their directly estimated differences.
risk <- read('HRS_standardized_risks_current.csv')[analysis %in% c('onset_symptoms','persistence_symptoms')]
rd <- read('HRS_risk_differences_current.csv')[analysis %in% c('onset_symptoms','persistence_symptoms')]
ctr <- c('cancer_and_pain_vs_neither','pain_only_vs_neither','cancer_only_vs_neither','pain_only_vs_cancer_only')
rd <- rd[contrast %in% ctr]
stopifnot(nrow(risk)==8,nrow(rd)==8)
for(a in unique(rd$analysis)) for(cn in ctr) {
  lhs <- sub('_vs_.*$','',cn); rhs <- sub('^.*_vs_','',cn)
  diff <- risk[analysis==a & phenotype==lhs,estimate]-risk[analysis==a & phenotype==rhs,estimate]
  stopifnot(abs(diff-rd[analysis==a & contrast==cn,estimate])<1e-10)
}
fwrite(risk,file.path(qa,'Figure3_risk_rows.csv'),bom=TRUE)
fwrite(rd,file.path(qa,'Figure3_RD_rows.csv'),bom=TRUE)
risk[,phenotype:=factor(phenotype,levels=rev(names(ph)))]
rd[,contrast:=factor(contrast,levels=rev(ctr),labels=rev(c(
 'Cancer and pain\nvs neither','Pain only\nvs neither','Cancer only\nvs neither','Pain only\nvs cancer only')))]
risks <- function(a,e) {
  z <- risk[analysis==a]
  ggplot(z,aes(estimate*100,phenotype,colour=phenotype))+
    geom_errorbar(aes(xmin=conf_low*100,xmax=conf_high*100),orientation='y',width=.15,linewidth=.55)+
    geom_point(size=2.3)+geom_text(aes(x=conf_high*100,label=sprintf('%.1f%%',estimate*100)),
      nudge_x=if(e=='onset') .4 else 1.0,hjust=0,size=text_mm,family='Arial',colour='black')+
    scale_colour_manual(values=ph)+scale_y_discrete(labels=plab)+
    scale_x_continuous(limits=c(0,if(e=='onset') 15 else 80),expand=expansion(mult=c(0,.01)))+
    labs(x='Standardized risk (%)',y=NULL)+pub()+theme(legend.position='none')
}
diffs <- function(a,e) {
  z <- rd[analysis==a]
  ggplot(z,aes(estimate*100,contrast))+geom_vline(xintercept=0,linetype=2,colour='#8C969A',linewidth=.4)+
    geom_errorbar(aes(xmin=conf_low*100,xmax=conf_high*100),orientation='y',width=.13,linewidth=.55,colour=pal['HRS'])+
    geom_point(size=2.1,colour=pal['HRS'])+
    geom_text(aes(x=if(e=='onset') 2 else 7.5,y=as.numeric(contrast)+.27,label=sprintf('%+.1f (%+.1f, %+.1f)',100*estimate,100*conf_low,100*conf_high)),
      size=text_mm,family='Arial')+
    scale_y_discrete(expand=expansion(add=c(.45,.65)))+
    labs(x='Percentage points (95% CI)',y=NULL)+pub()
}
p <- (strip(risks('onset_symptoms','onset'),'Symptom onset')+strip(diffs('onset_symptoms','onset'),'Risk differences')) /
     (strip(risks('persistence_symptoms','persistence'),'Symptom persistence')+strip(diffs('persistence_symptoms','persistence'),'Risk differences'))
save_plot(p,'Figure3','Figure3_HRS_risks_and_differences',6.6)

# Figure 4: existing direct contrasts under two distinct outcome definitions.
direct <- rr[contrast=='pain_only_vs_cancer_only']
stopifnot(nrow(direct)==12)
fwrite(direct,file.path(qa,'Figure4_display_rows.csv'),bom=TRUE)
dp <- function(e) {
  z <- direct[estimand==e]
  z[,pos:=4-match(cohort,c('HRS','SHARE','CHARLS'))+ifelse(outcome=='symptoms',.16,-.16)]
  z[,outcome:=factor(outcome,levels=c('symptoms','symptoms_or_death'),
    labels=c('High symptoms','High symptoms or death'))]
  ggplot(z,aes(rr,pos,colour=cohort,shape=outcome))+
    geom_vline(xintercept=1,linetype=2,colour='#8C969A',linewidth=.4)+
    geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.06,linewidth=.55)+
    geom_point(size=2.3,fill='white')+
    geom_text(aes(x=1.64,y=pos+.11,label=sprintf('%.2f (%.2f-%.2f)',rr,conf_low,conf_high)),
      size=text_mm,family='Arial',colour='black')+
    scale_colour_manual(values=pal,guide='none')+scale_shape_manual(values=c(16,1))+
    scale_y_continuous(breaks=1:3,labels=c('CHARLS','SHARE','HRS'),limits=c(.65,3.45))+
    scale_x_log10(limits=c(.75,3.6),breaks=c(1,1.5,2,3))+
    labs(x='Pain only vs cancer only: RR',y=NULL,shape=NULL)+pub()
}
p <- strip(dp('onset'),'Symptom onset')+strip(dp('persistence'),'Symptom persistence')+plot_layout(guides='collect') & theme(legend.position='top')
save_plot(p,'Figure4','Figure4_direct_contrasts_by_outcome',4.4)

# Figure 5 and S2: three cohort columns, two estimand rows; native categories retained.
ext <- read('HRS_extensions_current.csv')
bur <- read('nonHRS_pain_burden_category_risk_ratios_v1.1.csv')
h <- ext[grepl('_pain_gradient$',model_tag)]
g <- rbindlist(list(bur[,.(cohort,estimand,category=pain_burden_category,rr,conf_low,conf_high)],
  h[,.(cohort,estimand,category=contrast,rr=ratio,conf_low,conf_high)]))
g[,step:=match(category,c('mild_or_1_site','moderate_or_2_sites','severe_or_3plus_sites'))]
g[is.na(step),step:=match(category,c('mild_vs_none','moderate_vs_none','severe_vs_none'))]
stopifnot(nrow(g)==18,!anyNA(g$step)); fwrite(g,file.path(qa,'Figure5_display_rows.csv'),bom=TRUE)
f <- read('nonHRS_onset_persistence_function_and_persistence_sensitivities_v1.1.csv')
f <- f[scenario=='function_adjustment_sequence' & contrast=='cancer_and_pain_vs_neither']
hh <- ext[grepl('_function_',model_tag) & contrast=='cancer_and_pain_vs_neither']
hh[,adjustment:=sub('^(onset|persistence)_function_','',model_tag)]
f <- rbindlist(list(f[,.(cohort,estimand,adjustment,rr,conf_low,conf_high)],
  hh[,.(cohort,estimand,adjustment,rr=ratio,conf_low,conf_high)]))
f[,adjustment:=gsub('plus_','',gsub('core_plus_','',adjustment))]
f[,step:=match(adjustment,c('core','mobility','mobility_adl'))]
stopifnot(nrow(f)==18,!anyNA(f$step)); fwrite(f,file.path(qa,'FigureS2_display_rows.csv'),bom=TRUE)
small <- function(data,co,e,kind) {
  z <- data[cohort==co & estimand==e]
  labels <- if(kind=='burden') if(co=='CHARLS') c('1 site','2 sites','3+ sites') else c('Mild','Moderate','Severe') else c('Core','Mobility','Mobility\n+ ADL')
  subtitle <- if(e=='onset') if(kind=='burden') if(co=='CHARLS') 'Painful-site count' else 'Pain severity' else NULL else NULL
  ggplot(z,aes(step,rr))+geom_hline(yintercept=1,linetype=2,colour='#8C969A',linewidth=.4)+
    geom_line(colour=pal[co],linewidth=.45)+
    geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.1,colour=pal[co],linewidth=.55)+
    geom_point(shape=c(HRS=16,SHARE=17,CHARLS=15)[co],size=2.2,colour=pal[co])+
    geom_text(aes(y=conf_high,label=sprintf('%.2f',rr)),nudge_y=.10,size=text_mm,family='Arial')+
    scale_x_continuous(breaks=1:3,labels=labels,expand=expansion(add=.16))+
    scale_y_continuous(limits=c(.7,max(data$conf_high)+.30),breaks=c(1,1.5,2,2.5))+
    facet_wrap(~cohort,labeller=labeller(cohort=setNames(co,co)))+
    labs(x=if(kind=='burden') if(co=='CHARLS') 'Painful sites' else 'Pain severity' else NULL,
      y=if(co=='HRS') paste0(if(e=='onset') 'Onset' else 'Persistence',' RR (95% CI)') else NULL)+pub()+
    theme(axis.text.x=element_text(size=body_pt),axis.title.y=element_text(size=body_pt+2))
}
make6 <- function(data,kind) wrap_plots(lapply(names(el),function(e)
  wrap_plots(lapply(c('HRS','SHARE','CHARLS'),function(co) small(data,co,e,kind)),nrow=1)),ncol=1)
save_plot(make6(g,'burden'),'Figure5','Figure5_pain_burden',5.6)
save_plot(make6(f,'function'),'FigureS2','FigureS2_function_adjustment',5.6)

# S1: three genuinely different counts; not a fabricated eligibility flow.
s <- read('model_samples_current.csv')[outcome=='symptoms']
stopifnot(nrow(s)==6,all(s$events<=s$n_intervals)); fwrite(s,file.path(qa,'FigureS1_display_rows.csv'),bom=TRUE)
s[,cohort:=factor(cohort,levels=c('CHARLS','SHARE','HRS'))]
s[,estimand:=factor(estimand,levels=names(el),labels=c('Onset','Persistence'))]
metrics <- list(c('n_intervals','Person-intervals'),c('n_persons','Unique persons'),c('events','High-symptom events'))
pp <- lapply(seq_along(metrics),function(i) {
  z <- metrics[[i]]; d <- copy(s); d[,value:=get(z[1])]
  metric_label <- c('Person-\nintervals','Unique\npersons','High-symptom\nevents')[i]
  d[,panel:=paste0(metric_label,'\n',estimand)]
  ggplot(d,aes(value,cohort,fill=cohort))+geom_col(width=.5)+
    geom_text(aes(label=format(value,big.mark=',',trim=TRUE)),hjust=-.12,size=text_mm,family='Arial')+
    facet_wrap(~panel,ncol=1)+scale_fill_manual(values=pal)+
    scale_x_continuous(limits=c(0,max(d$value)*1.70),breaks=scales::breaks_pretty(3),labels=scales::label_number(scale=1/1000,suffix='k'))+
    labs(x='Count',y=NULL)+pub()+
    theme(legend.position='none',strip.text=element_text(size=body_pt+2))
})
save_plot(wrap_plots(pp,nrow=1),'FigureS1','FigureS1_model_populations',4.3)



# S3: standardized continuous symptom scores; no pooling or paired equivalence claim.
cc <- read('nonHRS_continuous_depressive_score_sensitivity_v1.0.csv'); cc[,estimand:='onset']
pc <- read('nonHRS_persistence_continuous_score_sensitivity_v1.1.csv'); pc[,estimand:='persistence']
ns <- read('nonHRS_sleep_item_excluded_score_sensitivity_v1.1.csv')
score <- rbindlist(list(
 cc[contrast=='cancer_and_pain_vs_neither',.(cohort,estimand,definition='Full score',estimate=estimate_sd,conf_low,conf_high,n_intervals,n_persons)],
 pc[contrast=='cancer_and_pain_vs_neither',.(cohort,estimand,definition='Full score',estimate=estimate_sd,conf_low,conf_high,n_intervals,n_persons)],
 ns[contrast=='cancer_and_pain_vs_neither',.(cohort,estimand,definition='Without sleep item',estimate=estimate_sd,conf_low,conf_high,n_intervals,n_persons)],
 ext[contrast=='cancer_and_pain_vs_neither' & (endsWith(model_tag,'_continuous_score') | endsWith(model_tag,'_no_sleep_score')),
  .(cohort,estimand,definition=ifelse(endsWith(model_tag,'_no_sleep_score'),'Without sleep item','Full score'),estimate,conf_low,conf_high,n_intervals,n_persons)]))
stopifnot(nrow(score)==12,!anyDuplicated(score[,.(cohort,estimand,definition)]),
 all(score$conf_low<=score$estimate),all(score$conf_high>=score$estimate))
fwrite(score,file.path(qa,'FigureS3_display_rows.csv'),bom=TRUE)
score[,cohort:=factor(cohort,levels=c('HRS','SHARE','CHARLS'))]
score[,definition:=factor(definition,levels=c('Full score','Without sleep item'))]
score[,population:=factor(estimand,levels=c('onset','persistence'),
 labels=c('Baseline-low symptom population','Baseline-high symptom population'))]
definition_palette <- setNames(nejm[c(5,6)],levels(score$definition))
p <- ggplot(score,aes(cohort,estimate,colour=definition,shape=definition))+
 geom_hline(yintercept=0,linetype=2,colour='#8C969A',linewidth=.4)+
 geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.12,position=position_dodge(width=.48),linewidth=.7)+
 geom_point(position=position_dodge(width=.48),size=2.7)+
 geom_text(aes(y=conf_high,label=sprintf('%.2f',estimate)),position=position_dodge(width=.48),vjust=-.7,size=text_mm,family='Arial',colour='black')+
 facet_wrap(~population,ncol=1)+scale_colour_manual(values=definition_palette)+scale_shape_manual(values=c(16,17))+
 scale_y_continuous(limits=c(min(0,min(score$conf_low))-.025,max(score$conf_high)+.15),breaks=seq(-.4,.8,.2))+
 labs(x=NULL,y='Adjusted symptom-score difference (SD)',colour=NULL,shape=NULL)+pub()+
 theme(panel.grid.major.y=element_line(colour='#EEEEEE',linewidth=.25),strip.text=element_text(size=12,face='bold'))
save_plot(p,'FigureS3','FigureS3_score_definition',5.0)

# S4: existing persistence scenarios. Primary MI and CC sensitivities are not the same samples.
scenarios <- c('Primary\n(MI)','Complete\ncase','First eligible\ninterval','Reduced\ncovariates','Trimmed\nweights')
nh <- read('nonHRS_onset_persistence_function_and_persistence_sensitivities_v1.1.csv')
nh <- nh[estimand=='persistence' & contrast=='cancer_and_pain_vs_neither' &
 scenario %in% c('complete_case','first_eligible_interval','reduced_covariate','final_weight_trimmed_1st_99th_percentile')]
nh[,setting:=scenarios[match(scenario,c('complete_case','first_eligible_interval','reduced_covariate','final_weight_trimmed_1st_99th_percentile'))+1L]]
hx <- ext[estimand=='persistence' & contrast=='cancer_and_pain_vs_neither' &
 model_tag %in% paste0('persistence_',c('function_core','first_interval','reduced','trim_final_weight'))]
hx[,setting:=scenarios[match(model_tag,paste0('persistence_',c('function_core','first_interval','reduced','trim_final_weight')))+1L]]
rob <- rbindlist(list(
 rr[estimand=='persistence' & outcome=='symptoms' & contrast=='cancer_and_pain_vs_neither',.(cohort,setting=scenarios[1],rr,conf_low,conf_high,n_intervals,n_persons)],
 nh[,.(cohort,setting,rr,conf_low,conf_high,n_intervals,n_persons)],
 hx[,.(cohort,setting,rr=ratio,conf_low,conf_high,n_intervals,n_persons)]))
stopifnot(nrow(rob)==15,!anyDuplicated(rob[,.(cohort,setting)]),!anyNA(rob$setting),
 all(rob$conf_low<=rob$rr),all(rob$conf_high>=rob$rr))
fwrite(rob,file.path(qa,'FigureS4_display_rows.csv'),bom=TRUE)
rob[,setting:=factor(setting,levels=scenarios)]
rob[,cohort:=factor(cohort,levels=c('CHARLS','SHARE','HRS'))]
rob[,label:=sprintf('%.2f\n(%.2f-%.2f)',rr,conf_low,conf_high)]
p <- ggplot(rob,aes(setting,cohort,fill=rr))+
 geom_tile(width=.95,height=.94,colour='white',linewidth=.8)+
 geom_text(aes(label=label),size=text_mm,lineheight=1.1,family='Arial',colour='black')+
 scale_fill_gradient(low='white',high=colorspace::lighten(nejm[2],amount=.58),
 limits=c(min(1,min(rob$rr)),max(rob$rr)+.01),name='Adjusted RR',breaks=c(1,1.1,1.2),na.value='#EEEEEE')+
 scale_x_discrete(position='top',expand=expansion(add=.02))+scale_y_discrete(expand=expansion(add=.02))+
 labs(x=NULL,y=NULL)+pub()+theme(axis.line=element_blank(),axis.ticks=element_blank(),
 axis.text.x=element_text(size=10,lineheight=1),axis.text.y=element_text(size=11,face='bold'),
 legend.key.width=unit(1.1,'cm'),legend.key.height=unit(.28,'cm'))+
 guides(fill=guide_colourbar(title.position='top',title.hjust=.5,barwidth=unit(2.4,'in'),barheight=unit(.12,'in')))
save_plot(p,'FigureS4','FigureS4_persistence_robustness',3.3)

for(z in list(risk,rd,g,f,direct)) stopifnot(all(z$conf_low<=if('rr'%in%names(z)) z$rr else z$estimate),
 all(z$conf_high>=if('rr'%in%names(z)) z$rr else z$estimate))
fwrite(data.table(file=unique(used),md5=unname(tools::md5sum(file.path(src,unique(used))))),file.path(qa,'source_hashes.csv'))
pdfs <- list.files(out,pattern='[.]pdf$',recursive=TRUE,full.names=TRUE)
pdfs <- setdiff(pdfs,file.path(out,'Figure1','Figure1_study_design.pdf'))
stopifnot(length(pdfs)==8)
fonts <- rbindlist(lapply(pdfs,function(path) {
 stopifnot(pdftools::pdf_info(path)$pages==1)
 ff <- pdftools::pdf_fonts(path); stopifnot(all(grepl('Arial',ff$name)),all(ff$embedded))
 data.table(file=basename(path),font=ff$name,embedded=ff$embedded)
}))
fwrite(fonts,file.path(qa,'font_checks.csv')); capture.output(sessionInfo(),file=file.path(qa,'R_session.txt'))
cat('PASS: 8 vector PDFs, 12 score rows and 15 robustness cells; aggregate-only display.\n')
