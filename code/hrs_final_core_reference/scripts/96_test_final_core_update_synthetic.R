# Entirely synthetic: no real HRS data, old mids, or private logs are opened.
source('HRS_local_run_package/HRS_run.R',encoding='UTF-8')
source('HRS_local_run_package/final_core_compare.R',encoding='UTF-8')
source('Reliability_local_run_package/reliability_checks.R',encoding='UTF-8')
source('Reliability_local_run_package/extend_mi.R',encoding='UTF-8')
source('HRS_local_run_package/final_core_update.R',encoding='UTF-8')
hrs_packages()
set.seed(960907)
root <- tempfile('hrs_final_synthetic_'); dir.create(root)
private <- file.path(root,'LOCAL_ONLY'); out <- file.path(root,'SUMMARY_RETURN')
dir.create(private); dir.create(out)
deps <- fu_dependencies(getwd())
stopifnot(identical(fu_id(c('1.0','000000001','999999999')),c('000000001','000000001','999999999')))
fail <- function(expr) inherits(tryCatch({force(expr);NULL},error=function(e)e),'error')
stopifnot(fail(fu_id(c('1','1e3'))))
stopifnot(fu_error_code(simpleError('Earlier interval changed: event'))=='EARLIER_EVENT_VALUE_CHANGED',
  fu_error_code(simpleError('private person row 123'))=='UNCLASSIFIED_ERROR_PRIVATE_DETAILS_NOT_EXPORTED')
raw <- data.frame(id=sprintf('%09d',1:3))
for(v in paste0('SD',110:117)) raw[[v]] <- c('5','1','5')
raw$SD110[3] <- '-8'
endpoint <- hc_cesd(raw)
stopifnot(identical(endpoint$raw_cesd8,c(2,6,NA_real_)))
# Loader only evaluates named function assignments, never top-level data reads.
stopifnot(!exists('datasets',envir=deps$onset,inherits=FALSE))
for(es in c('onset','persistence')) {
  n <- 1000L
  d <- data.table(person_id=as.character(rep(seq_len(n),2)),
    transition=rep(c('2018-2020','2020-2022'),each=n),primary_interval=TRUE,
    age=runif(2*n,50,90),female=rbinom(2*n,1,.55),education3=sample(1:3,2*n,TRUE),
    partnered=sample(0:1,2*n,TRUE),depressive_score=sample(if(es=='onset')0:3 else 4:8,2*n,TRUE),
    noncancer_comorbidity_count=sample(0:5,2*n,TRUE),current_smoking=sample(0:1,2*n,TRUE),
    wealth_quintile=sample(1:5,2*n,TRUE),phenotype=rep(c('neither','cancer_only','pain_only','cancer_and_pain'),length.out=2*n),
    survey_weight=runif(2*n,.5,3),stratum=rep(rep(1:50,each=20),2),
    half_sample=rep(rep(rep(1:2,each=10),50),2),follow_death_this_wave=FALSE,
    follow_observed=TRUE,follow_depressive_score=sample(0:8,2*n,TRUE),analysis_eligible=TRUE,
    retention_probability=.8,retention_ipw=1.25,analysis_weight=1,analysis_weight_norm=1)
  d$education3[sample(2*n,150)] <- NA
  d$noncancer_comorbidity_count[sample(2*n,150)] <- NA
  # Match the original interval builder: onset event is logical, not numeric.
  d$event <- if(es=='onset')d$follow_depressive_score>=4 else as.numeric(d$follow_depressive_score>=4)
  d$follow_death_this_wave[c(10,1010)] <- TRUE
  d$follow_observed[c(10,1010)] <- FALSE; d$analysis_eligible[c(10,1010)] <- FALSE
  d$follow_depressive_score[c(10,1010)] <- NA;d$event[c(10,1010)] <- NA
  absent <- sample(setdiff(1:n,10),200)
  d$follow_observed[absent] <- FALSE;d$analysis_eligible[absent] <- FALSE
  d$event[absent] <- NA;d$follow_depressive_score[absent] <- NA
  ep <- data.frame(id=sprintf('%09d',1:n),raw_cesd8=sample(0:8,n,TRUE))
  ep$raw_cesd8[c(10,sample(setdiff(1:n,10),200))] <- NA
  old <- copy(d)
  built <- fu_rebuild(d,ep,es,deps[[es]])
  z <- built$full
  # Numeric and logical event inputs must produce the same rebuilt endpoints.
  numeric_copy <- copy(d); numeric_copy$event <- as.numeric(numeric_copy$event)
  numeric_result <- fu_rebuild(numeric_copy,ep,es,deps[[es]])$full
  stopifnot(identical(z$event,numeric_result$event))
  bad_retention <- list(fit_retention_weight=function(data,cohort,transition) {
    result <- deps[[es]]$fit_retention_weight(data,cohort,transition)
    j <- which(data$transition=='2018-2020' & !is.na(data$event))[1]
    data.table::set(data,i=j,j='event',value=1-data$event[j])
    result
  })
  violation <- tryCatch(fu_rebuild(d,ep,es,bad_retention),error=function(e)conditionMessage(e))
  stopifnot(identical(violation,'Earlier interval changed: event'))
  stopifnot(identical(d,old),nrow(z)==nrow(d),
    identical(z$follow_death_this_wave,d$follow_death_this_wave),
    is.na(z$event[1010]),z$event[1001]==as.numeric(ep$raw_cesd8[1]>=4) || is.na(z$event[1001]))
  broken <- ep;broken$raw_cesd8[10]<-5
  stopifnot(fail(fu_rebuild(d,broken,es,deps[[es]])))
  stopifnot(fail(fu_rebuild(d,rbind(ep,ep[1,]),es,deps[[es]])))
  removed <- ep[-1,]; zz <- fu_rebuild(d,removed,es,deps[[es]])$full
  stopifnot(is.na(zz$event[1001]),!zz$follow_observed[1001],!zz$follow_death_this_wave[1001])
  fu_flow(z,es,private,out)
  comp <- hrs_composite(z)
  stopifnot(all(comp$analysis$event[comp$analysis$death==1]==1),
    all(comp$full$composite_weight[comp$full$death==1]==comp$full$survey_weight[comp$full$death==1]))
  for(kind in c('symptoms','composite')) {
    a <- if(kind=='symptoms')z[analysis_eligible==TRUE]else comp$analysis
    weight <- if(kind=='symptoms')'analysis_weight_norm'else'composite_weight_norm'
    tag <- paste(es,kind,sep='_')
    imp <- fu_impute(a,weight,967L,private,tag,function(x)cat(x,'\n'),m=2L,iterations=50L)
    ans <- fu_fit(imp,weight,tag,private,out,function(x)cat(x,'\n'))
    stopifnot(nrow(ans$RR)==5,nrow(ans$risks)==4,nrow(ans$risk_differences)==5,
      all(ans$RR$conf_high>ans$RR$conf_low),all(ans$RR$dfcom>0),imp$iteration==50L)
    rel_mi_report(imp,tag,private,out)
    ext_late(imp,tag,out)
  }
}
q <- c(.1,.12,.08); u <- c(.01,.011,.009)
z <- fu_pool(q,u,59,TRUE)
lambda <- (1+1/3)*var(q)/(mean(u)+(1+1/3)*var(q))
tmp <- (1-lambda)*60*59
df <- 2*tmp/(62*2+lambda^2*tmp)
stopifnot(abs(z$df-df)<1e-10,abs(z$rr-exp(mean(q)))<1e-12)
writeLines('PASS: synthetic only; four core pipelines, joins, missing endpoint, death conflict, invariants, MI, finite df and absolute risks.',
  'HRS_local_run_package/FINAL_CORE_UPDATE_SYNTHETIC_TEST.txt')
cat('PASS. Synthetic outputs:',root,'\n')
