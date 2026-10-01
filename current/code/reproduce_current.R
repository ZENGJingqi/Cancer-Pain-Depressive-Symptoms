# Aggregate-only synthesis and plotting; no participant records or model objects.
# Install required packages into your configured R library.
suppressPackageStartupMessages({library(data.table); library(ggplot2); library(metafor)})
args <- commandArgs(trailingOnly=TRUE)
root <- if(length(args)) args[1] else 'current'
td <- file.path(root,'results'); fd <- file.path(root,'figures')
dir.create(fd,recursive=TRUE,showWarnings=FALSE)
rr <- fread(file.path(td,'cohort_RR_current.csv'))
stopifnot(nrow(rr)==60L, all(abs(exp(rr$log_rr)-rr$rr)<1e-10))
meta <- rbindlist(lapply(c('onset','persistence'),function(e) {
  rbindlist(lapply(c('cancer_and_pain_vs_neither','cancer_and_pain_vs_cancer_only',
                    'pain_only_vs_neither','cancer_only_vs_neither'),function(ct) {
    x <- rr[estimand==e & outcome=='symptoms' & contrast==ct]
    stopifnot(nrow(x)==3L,length(unique(x$cohort))==3L)
    m <- rma.uni(yi=x$log_rr,sei=x$se,method='REML',test='knha',slab=x$cohort)
    # Independent check of inverse-variance random-effects mean and HK variance.
    w <- 1/(x$se^2+m$tau2); mu <- sum(w*x$log_rr)/sum(w)
    hkse <- sqrt(sum(w*(x$log_rr-mu)^2)/(nrow(x)-1)/sum(w))
    stopifnot(abs(mu-as.numeric(m$b))<1e-10,abs(hkse-m$se)<1e-10)
    data.table(cohort='Pooled',estimand=e,outcome='symptoms',contrast=ct,
       log_rr=as.numeric(m$b),se=m$se,rr=exp(as.numeric(m$b)),conf_low=exp(m$ci.lb),
       conf_high=exp(m$ci.ub),tau2=m$tau2,i2=m$I2,p_value=m$pval,k=m$k,
       n_intervals=sum(x$n_intervals),events=sum(x$events),method='REML Hartung-Knapp')
  }))
}))
fwrite(meta,file.path(td,'meta_current.csv'),bom=TRUE)
all <- rbindlist(list(rr[outcome=='symptoms'],meta),fill=TRUE)
fwrite(all,file.path(td,'symptom_RR_with_meta_current.csv'),bom=TRUE)
cols <- c(HRS='#BC3C29',SHARE='#0072B5',CHARLS='#E18727',Pooled='#20854E')
tbase <- function() theme_classic(base_size=14,base_family='Arial') +
  theme(text=element_text(colour='black'),axis.text=element_text(colour='black'),
        legend.position='top',strip.text=element_text(colour='black'),
        plot.margin=margin(10,15,10,10))
save <- function(p,name,w=10,h=6.5) {
  file <- file.path(fd,paste0(name,'.pdf'))
  ggsave(file,p,width=w,height=h,device=cairo_pdf)
  suppressWarnings(pdftools::pdf_convert(file,format='png',pages=1,dpi=160,
      filenames=file.path(fd,paste0(name,'.png')),verbose=FALSE))
}
ctlabels <- c(cancer_and_pain_vs_neither='Cancer and pain vs neither',
   cancer_and_pain_vs_cancer_only='Cancer and pain vs cancer only',
   pain_only_vs_neither='Pain only vs neither',cancer_only_vs_neither='Cancer only vs neither')
all[,contrast_label:=factor(ctlabels[contrast],levels=unname(ctlabels))]
all[,cohort:=factor(cohort,levels=c('Pooled','CHARLS','SHARE','HRS'))]
p <- ggplot(all[!is.na(contrast_label)],aes(rr,cohort,colour=cohort))+geom_vline(xintercept=1,linetype=2,colour='grey50')+
  geom_errorbar(aes(xmin=conf_low,xmax=conf_high),orientation='y',width=.18)+geom_point(size=2.6)+
  facet_grid(contrast_label~estimand,switch='y',labeller=label_wrap_gen(width=20))+scale_x_log10()+scale_colour_manual(values=cols)+
  labs(x='Adjusted risk ratio with 95% CI',y=NULL)+tbase()+theme(legend.position='none',strip.text.y.left=element_text(angle=0,size=12))
save(p,'Figure1_RR',11.5,9)
risk <- fread(file.path(td,'HRS_standardized_risks_current.csv'))
risk <- risk[analysis %in% c('onset_symptoms','persistence_symptoms')]
phenos <- c('neither','cancer_only','pain_only','cancer_and_pain')
risk[,phenotype:=factor(phenotype,levels=phenos,labels=c('Neither','Cancer only','Pain only','Cancer and pain'))]
p <- ggplot(risk,aes(phenotype,estimate*100))+geom_errorbar(aes(ymin=conf_low*100,ymax=conf_high*100),width=.15)+
  geom_point(size=3,colour=cols['HRS'])+facet_wrap(~analysis,scales='free_y')+
  labs(x=NULL,y='HRS standardized risk (%) with 95% CI')+tbase()+
  theme(axis.text.x=element_text(angle=20,hjust=1))
save(p,'Figure2_HRS_risks',10.5,5.7)
ext <- fread(file.path(td,'HRS_extensions_current.csv'))
burden <- fread(file.path(td,'nonHRS_pain_burden_category_risk_ratios_v1.1.csv'))
h <- ext[grepl('_pain_gradient$',model_tag)]
# The extension contrasts preserve the burden factor levels.
fwrite(h,file.path(td,'HRS_pain_gradient_plot_source.csv'),bom=TRUE)
print(unique(h$contrast))
grad <- rbindlist(list(burden[,.(cohort,estimand,category=pain_burden_category,rr,conf_low,conf_high)],
    h[,.(cohort,estimand,category=contrast,rr=ratio,conf_low,conf_high)]),fill=TRUE)
grad[,category:=gsub('_vs_none','',category)]
grad[,category:=gsub('^pain_burden','',category)]
grad[category=='mild',category:='mild_or_1_site']
grad[category=='moderate',category:='moderate_or_2_sites']
grad[category=='severe',category:='severe_or_3plus_sites']
grad[,category:=factor(category,levels=c('mild_or_1_site','moderate_or_2_sites','severe_or_3plus_sites'),
    labels=c('Mild or 1 site','Moderate or 2 sites','Severe or 3+ sites'))]
stopifnot(!anyNA(grad$category),nrow(grad)==18L)
p <- ggplot(grad,aes(category,rr,colour=cohort,group=cohort))+
  geom_hline(yintercept=1,linetype=2,colour='grey50')+
  geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.15,position=position_dodge(.4))+
  geom_point(position=position_dodge(.4),size=2.5)+facet_wrap(~estimand)+scale_colour_manual(values=cols)+
  labs(x='Pain severity in HRS and SHARE; painful-site count in CHARLS',y='Adjusted risk ratio with 95% CI')+tbase()+
  theme(axis.text.x=element_text(angle=20,hjust=1))
save(p,'Figure3_pain_gradient',11,6)
samples <- fread(file.path(td,'model_samples_current.csv'))[outcome=='symptoms']
p <- ggplot(samples,aes(cohort,n_intervals,fill=cohort))+geom_col(width=.6)+
  geom_text(aes(label=format(n_intervals,big.mark=',')),vjust=-.4,size=4,family='Arial')+
  facet_wrap(~estimand,scales='free_y')+scale_fill_manual(values=cols)+scale_y_continuous(expand=expansion(mult=c(0,.15)))+
  labs(x=NULL,y='Analysed person-intervals')+tbase()+theme(legend.position='none')
save(p,'FigureS1_model_samples',9,5.5)
fun <- fread(file.path(td,'nonHRS_onset_persistence_function_and_persistence_sensitivities_v1.1.csv'))
fun <- fun[scenario=='function_adjustment_sequence' & contrast=='cancer_and_pain_vs_neither']
hh <- ext[grepl('_function_',model_tag) & contrast=='cancer_and_pain_vs_neither']
hh[,adjustment:=sub('^(onset|persistence)_function_','',model_tag)]
fun <- rbindlist(list(fun[,.(cohort,estimand,adjustment,rr,conf_low,conf_high)],
   hh[,.(cohort,estimand,adjustment,rr=ratio,conf_low,conf_high)]),fill=TRUE)
fun[,adjustment:=gsub('core_plus_','',adjustment)]
fun[,adjustment:=gsub('plus_','',adjustment)]
print(unique(fun$adjustment))
fun[,adjustment:=factor(adjustment,levels=c('core','mobility','mobility_adl'),
   labels=c('Core','Plus mobility','Plus mobility and ADL'))]
stopifnot(!anyNA(fun$adjustment),nrow(fun)==18L)
p <- ggplot(fun,aes(adjustment,rr,colour=cohort,group=cohort))+
  geom_hline(yintercept=1,linetype=2,colour='grey50')+
  geom_errorbar(aes(ymin=conf_low,ymax=conf_high),width=.15,position=position_dodge(.4))+
  geom_point(position=position_dodge(.4),size=2.5)+facet_wrap(~estimand)+scale_colour_manual(values=cols)+
  labs(x=NULL,y='Cancer and pain vs neither risk ratio with 95% CI')+tbase()+
  theme(axis.text.x=element_text(angle=20,hjust=1))
save(p,'FigureS2_function',11,6)
capture.output(sessionInfo(),file=file.path(root,'R_session.txt'))
cat('Eight aggregate meta-analyses checked; five figures rendered. No participant models.\n')
