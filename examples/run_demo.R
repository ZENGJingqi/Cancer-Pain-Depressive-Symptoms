# Synthetic example only. No study participants or study estimates are used.
args <- commandArgs(trailingOnly=FALSE)
script <- grep('^--file=',args,value=TRUE)
root <- if(length(script)) dirname(dirname(normalizePath(sub('^--file=','',script[1])))) else normalizePath('.')
source(file.path(root,'R/core_functions.R'))
source(file.path(root,'R/analysis_tools.R'))
needed <- c('survey','mice','data.table','metafor')
missing <- needed[!vapply(needed,requireNamespace,logical(1),quietly=TRUE)]
if(length(missing)) stop('Install packages first: ',paste(missing,collapse=', '))
set.seed(20261005)
n <- 2400L
d <- data.frame(person_id=seq_len(n),stratum=rep(1:60,each=40),
 half_sample=rep(rep(1:2,each=20),60),analysis_weight_norm=runif(n,.7,1.3),
 phenotype=sample(c('neither','cancer_only','pain_only','cancer_and_pain'),n,TRUE),
 age=runif(n,50,90),female=rbinom(n,1,.5),education3=sample(1:3,n,TRUE),
 partnered=rbinom(n,1,.6),depressive_score=sample(0:3,n,TRUE),
 noncancer_comorbidity_count=sample(0:5,n,TRUE),current_smoking=rbinom(n,1,.2),
 wealth_quintile=sample(1:5,n,TRUE),transition=sample(c('t1','t2'),n,TRUE))
d$event <- rbinom(n,1,plogis(-2+.5*(d$phenotype=='pain_only')+
 .65*(d$phenotype=='cancer_and_pain')+.01*(d$age-65)))
d <- hrs_prepare(d)
before <- unserialize(serialize(d,NULL))
options(survey.lonely.psu='adjust')
design <- hrs_design(d)
rr <- cpd_fit_rr(hrs_formula(),design)
stopifnot(nrow(rr)==5L,all(rr$variance>0))
# Demonstrate Rubin finite-df pooling with simulated estimates, NOT actual MI.
q <- rnorm(20,rr$log_rr[1],.015)
pooled <- fu_pool(q,rep(rr$variance[1],20),rr$dfcom[1],TRUE)
stopifnot(is.finite(pooled$df),pooled$df>0,pooled$conf_low<pooled$rr)
logistic <- survey::svyglm(hrs_formula(),design=design,family=quasibinomial('logit'))
risk <- br_standardize(logistic,d,'analysis_weight_norm')
stopifnot(all(risk$risks$estimate>0 & risk$risks$estimate<1),
 all(risk$risks$variance>0),all(risk$RD$variance>0))
for(ct in names(br_pairs())) {
 pair <- br_pairs()[[ct]]
 stopifnot(abs(risk$RD$estimate[risk$RD$contrast==ct]-
  (risk$risks$estimate[pair[1]]-risk$risks$estimate[pair[2]]))<1e-12)
}
# Exercise the bounded pooled-risk CI using identical synthetic aggregate
# estimates across 20 slots. These slots are not generated imputations.
risk_slots <- do.call(rbind,rep(list(risk$risks),20))
rd_slots <- do.call(rbind,rep(list(risk$RD),20))
pooled_risks <- br_pool(risk_slots,'phenotype',logistic$df.residual,TRUE)
pooled_rd <- br_pool(rd_slots,'contrast',logistic$df.residual)
stopifnot(all(pooled_risks$conf_low>0 & pooled_risks$conf_high<1),
 max(abs(pooled_risks$estimate-risk$risks$estimate))<1e-12,
 max(abs(pooled_rd$estimate-risk$RD$estimate))<1e-12)
meta <- cpd_meta(log(c(1.35,1.48,1.29)),c(.08,.1,.09))
stopifnot(meta$k==3L,meta$conf_low>0,meta$conf_high>meta$rr,
 isTRUE(all.equal(before,d,check.attributes=TRUE)))
out_arg <- commandArgs(trailingOnly=TRUE)
out <- if(length(out_arg)) out_arg[1] else file.path(root,'output/demo')
if(dir.exists(out)) stop('Choose a new output directory; existing output is not overwritten')
dir.create(out,recursive=TRUE)
write.csv(rr,file.path(out,'SYNTHETIC_rr.csv'),row.names=FALSE)
write.csv(pooled,file.path(out,'SYNTHETIC_pooling.csv'),row.names=FALSE)
write.csv(risk$risks,file.path(out,'SYNTHETIC_risks.csv'),row.names=FALSE)
write.csv(risk$RD,file.path(out,'SYNTHETIC_risk_differences.csv'),row.names=FALSE)
write.csv(meta,file.path(out,'SYNTHETIC_meta.csv'),row.names=FALSE)
capture.output(sessionInfo(),file=file.path(out,'sessionInfo.txt'))
cat('PASS: synthetic RR, finite-df pooling, standardization, RD coherence and REML/HK.\n')
