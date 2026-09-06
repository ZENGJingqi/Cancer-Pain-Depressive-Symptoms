# Source reference only. Requires separately authorised participant data and the private project structure.
# Not part of the aggregate-only reproduction command. Do not run in an AI-connected environment.
if (Sys.getenv("CPD_AUTHORIZED_LOCAL_REFERENCE_RUN") != "YES")
  stop("Reference module: independent authorised local environment and missing private dependencies required.")
# Human-operated local R session only. Sourcing this file defines functions;
# it does not read any research data. Run hrs_run() explicitly to start.

hrs_packages <- function() {
  needed <- c('data.table','mice','survey','splines','digest')
  absent <- needed[!vapply(needed, requireNamespace, logical(1), quietly=TRUE)]
  if(length(absent)) stop('Install missing packages: ', paste(absent, collapse=', '))
  suppressPackageStartupMessages({
    library(data.table); library(mice); library(survey); library(splines)
  })
  options(survey.lonely.psu='adjust')
}

hrs_binary_event <- function(x) {
  # Compare meaning, not storage: logical TRUE/FALSE equals numeric 1/0.
  if(is.logical(x)) return(as.numeric(x))
  y <- as.character(x)
  if(any(!is.na(y) & !y %in% c('0','1'))) stop('Invalid event encoding; expected binary 0/1 or logical')
  as.numeric(y)
}

hrs_prepare <- function(d) {
  d <- as.data.frame(d)
  lev <- list(phenotype=c('neither','cancer_only','pain_only','cancer_and_pain'),
              education3=1:3, partnered=0:1, current_smoking=0:1, wealth_quintile=1:5)
  for(n in names(lev)) d[[n]] <- factor(d[[n]], levels=lev[[n]])
  d$transition <- factor(d$transition)
  d$event <- as.numeric(d$event)
  d
}

hrs_design <- function(d, weight='analysis_weight_norm') {
  required <- c('stratum','half_sample','person_id',weight)
  if(!all(required %in% names(d))) stop('Missing HRS design fields')
  if(anyNA(d[required]) || any(!is.finite(d[[weight]]) | d[[weight]]<=0)) stop('Invalid design/weight fields')
  d$weight_current <- d[[weight]]
  survey::svydesign(ids=~half_sample+person_id, strata=~stratum,
    weights=~weight_current, data=d, nest=TRUE)
}

hrs_formula <- function() event ~ phenotype + ns(age,df=3) + female + education3 +
  partnered + depressive_score + noncancer_comorbidity_count + current_smoking +
  wealth_quintile + transition

hrs_contrasts <- function(fit) {
  b <- coef(fit); v <- vcov(fit)
  required <- c('phenotypepain_only','phenotypecancer_only','phenotypecancer_and_pain')
  if(!all(required %in% names(b)) || any(!is.finite(b)) || any(!is.finite(v))) stop('Invalid fitted coefficients')
  spec <- list(cancer_and_pain_vs_neither=c(phenotypecancer_and_pain=1),
    cancer_and_pain_vs_cancer_only=c(phenotypecancer_and_pain=1,phenotypecancer_only=-1),
    pain_only_vs_neither=c(phenotypepain_only=1),
    cancer_only_vs_neither=c(phenotypecancer_only=1),
    pain_only_vs_cancer_only=c(phenotypepain_only=1,phenotypecancer_only=-1))
  data.table::rbindlist(lapply(names(spec),function(n) {
    a <- setNames(numeric(length(b)),names(b)); a[names(spec[[n]])] <- spec[[n]]
    vv <- as.numeric(t(a)%*%v%*%a)
    if(!is.finite(vv) || vv<=0) stop('Invalid contrast variance')
    data.table::data.table(contrast=n,log_rr=sum(a*b),variance=vv)
  }))
}

hrs_pool <- function(q,u) {
  if(length(q)!=length(u) || !length(q) || any(!is.finite(c(q,u))) || any(u<=0)) stop('Invalid pooling inputs')
  m <- length(q); wb <- mean(u); bb <- if(m>1) var(q) else 0
  total <- wb+(1+1/m)*bb; riv <- (1+1/m)*bb/wb
  df <- if(riv>0 && m>1) (m-1)*(1+1/riv)^2 else Inf
  se <- sqrt(total); crit <- qt(.975,df); mu <- mean(q)
  data.table::data.table(log_rr=mu,se=se,rr=exp(mu),conf_low=exp(mu-crit*se),
    conf_high=exp(mu+crit*se),p_value=2*pt(-abs(mu/se),df),df=df,m=m,
    within_variance=wb,between_variance=bb,mcse_log_rr=sqrt(bb/m))
}

hrs_fit_mids <- function(imp, weight, output, tag) {
  rows <- list()
  for(j in seq_len(imp$m)) {
    cat(tag, ': model ',j,'/',imp$m,'\n',sep=''); flush.console()
    d <- hrs_prepare(mice::complete(imp,j))
    fit <- survey::svyglm(hrs_formula(),design=hrs_design(d,weight),family=quasipoisson('log'))
    x <- hrs_contrasts(fit); x[,imputation:=j]; rows[[j]] <- x
  }
  x <- data.table::rbindlist(rows)
  data.table::fwrite(x,file.path(output,paste0(tag,'_per_imputation.csv')))
  p <- x[,hrs_pool(log_rr,variance),by=contrast]
  p[,`:=`(cohort='HRS',analysis=tag,n_intervals=nrow(imp$data),
    n_persons=data.table::uniqueN(imp$data$person_id),events=sum(imp$data$event))]
  data.table::fwrite(p,file.path(output,paste0(tag,'_RR.csv')))
  p
}

hrs_diagnostics <- function(imp,out,tag) {
  # Aggregate diagnostics only; individual imputations stay in LOCAL_ONLY.
  x <- data.table::data.table(variable=names(imp$data),
    missing_n=colSums(is.na(imp$data)),method=unname(imp$method),m=imp$m,iterations=imp$iteration)
  data.table::fwrite(x,file.path(out,paste0(tag,'_missingness.csv')))
  for(stat in c('chainMean','chainVar')) {
    a <- imp[[stat]]
    if(!is.null(a)) {
      t <- as.data.frame(as.table(a)); names(t)<-c('variable','iteration','chain','value')
      t <- t[is.finite(t$value),]
      data.table::fwrite(t,file.path(out,paste0(tag,'_',stat,'.csv')))
    }
  }
  writeLines(paste('Final logged events:',if(is.null(imp$loggedEvents)) 0 else nrow(imp$loggedEvents)),
    file.path(out,paste0(tag,'_logged_event_count.txt')))
  # Detailed event strings are local only; convergence is not inferred from zero events.
}

hrs_composite <- function(d) {
  d <- data.table::copy(d)
  d[,death:=as.numeric(follow_death_this_wave %in% TRUE)]
  if(anyNA(d$follow_death_this_wave)) stop('Unknown death status requires review')
  d[,survivor_ipw:=NA_real_]; diagnostic <- list()
  for(tr in unique(d$transition)) {
    s <- data.table::copy(d[transition==tr & death==0])
    if(!nrow(s)) stop('Empty survivor risk set')
    for(n in c('education3','partnered','current_smoking','wealth_quintile')) {
      a <- as.character(s[[n]]); a[is.na(a)]<-'missing'; s[[paste0(n,'_ret')]]<-factor(a)
    }
    s[,cm_missing:=as.integer(is.na(noncancer_comorbidity_count))]
    med <- median(s$noncancer_comorbidity_count,na.rm=TRUE)
    if(!is.finite(med)) stop('Comorbidity entirely missing')
    s[,cm:=data.table::fifelse(is.na(noncancer_comorbidity_count),med,noncancer_comorbidity_count)]
    form <- follow_observed ~ ns(age,df=3)+female+phenotype+depressive_score+
      education3_ret+partnered_ret+current_smoking_ret+wealth_quintile_ret+cm
    if(length(unique(s$cm_missing))>1) form<-update(form,.~.+cm_missing)
    mod <- glm(form,data=s,family=binomial())
    pr <- predict(mod,newdata=s,type='response')
    if(!mod$converged || any(!is.finite(pr))) stop('Retention model failed')
    ipw <- 1/pmax(.05,pmin(.99,pr))
    lim <- quantile(ipw[s$follow_observed %in% TRUE],c(.01,.99),names=FALSE)
    s[,ipw:=pmax(lim[1],pmin(lim[2],ipw))]
    d[s,on=.(person_id,transition),survivor_ipw:=i.ipw]
    diagnostic[[tr]]<-data.table::data.table(transition=tr,n_survivors=nrow(s),
      observation_rate=mean(s$follow_observed),min_probability=min(pr),
      n_probability_below_005=sum(pr<.05),ipw_p01=lim[1],ipw_p99=lim[2])
  }
  d[,symptom_event:=as.numeric(event)]
  d[,event:=data.table::fifelse(death==1,1,
    data.table::fifelse(follow_observed %in% TRUE,symptom_event,NA_real_))]
  d[,composite_weight:=data.table::fifelse(death==1,survey_weight,
    data.table::fifelse(follow_observed %in% TRUE,survey_weight*survivor_ipw,NA_real_))]
  d[,composite_weight_norm:=composite_weight/mean(composite_weight,na.rm=TRUE),by=transition]
  list(full=d,analysis=d[!is.na(event)&is.finite(composite_weight_norm)&composite_weight_norm>0],
    retention=data.table::rbindlist(diagnostic))
}

hrs_run <- function(project=getwd(),
                    output_base=file.path(tempdir(), 'HRS_local_results')) {
  hrs_packages()
  tag <- format(Sys.time(),'%Y%m%d_%H%M%S')
  dest <- file.path(output_base,tag)
  if(dir.exists(dest)) stop('Output directory exists')
  dir.create(dest,recursive=TRUE)
  local <- file.path(dest,'LOCAL_ONLY'); out <- file.path(dest,'SUMMARY_RETURN')
  dir.create(local); dir.create(out)
  logcon <- file(file.path(local,'run_log.txt'),'wt')
  sink(logcon,split=TRUE); sink(logcon,type='message')
  on.exit({sink(type='message');sink();close(logcon)},add=TRUE)
  cat('HRS human-operated local analysis. Results are provisional until reviewed.\n')
  base <- file.path(project,'data'); models<-file.path(base,'03_outputs/cpd_multicohort_01/models')
  inputs <- c(
    onset=file.path(base,'02_analytic/cpd_multicohort_01/v1.0/hrs_person_intervals_v1.0.rds'),
    persistence=file.path(base,'02_analytic/cpd_multicohort_01/v1.1/hrs_persistence_intervals_v1.1.rds'))
  imps <- c(onset=file.path(models,'hrs_mice_m20_v1.0.rds'),
    persistence=file.path(models,'hrs_persistence_mice_m20_v1.1.rds'))
  if(!all(file.exists(c(inputs,imps)))) stop('Required local HRS analytic/imputation files absent')
  manifest <- data.table::data.table(file=basename(c(inputs,imps)),
    sha256=vapply(c(inputs,imps),digest::digest,character(1),file=TRUE,algo='sha256'))
  data.table::fwrite(manifest,file.path(out,'input_hashes.csv'))
  for(es in names(inputs)) {
    cat('\nProcessing ',es,'\n',sep=''); flush.console()
    d <- data.table::as.data.table(readRDS(inputs[[es]]))
    if(anyDuplicated(d[,paste(person_id,transition,sep=':')])) stop('Duplicate person-interval key')
    imp <- readRDS(imps[[es]])
    if(imp$m!=20) stop('Expected original m=20')
    eligible <- d[analysis_eligible %in% TRUE]
    if(nrow(eligible)!=nrow(imp$data)) stop('Cached MI sample count mismatch')
    key<-function(z) paste(as.character(z$person_id),as.character(z$transition),sep=':')
    k<-match(key(imp$data),key(eligible))
    if(anyNA(k)||anyDuplicated(k)) stop('Cached MI keys mismatch')
    for(n in c('event','phenotype','analysis_weight_norm','stratum','half_sample')) {
      left <- imp$data[[n]]; right <- eligible[[n]][k]
      if(n=='event') {
        left <- hrs_binary_event(left); right <- hrs_binary_event(right)
      }
      if(!isTRUE(all.equal(as.character(left),as.character(right))))
        stop('Cached MI fixed-field mismatch: ',n)
    }
    hrs_fit_mids(imp,'analysis_weight_norm',out,paste0(es,'_symptoms'))
    hrs_diagnostics(imp,out,paste0(es,'_symptoms'))
    d<-d[primary_interval %in% TRUE & !is.na(phenotype)&is.finite(survey_weight)&survey_weight>0]
    d[,death:=as.numeric(follow_death_this_wave %in% TRUE)]
    # Descriptive risks within each interval; normal CI not used for rare mortality.
    mortality <- d[,.(n_intervals=.N,deaths=sum(death),unweighted_risk=mean(death),
      weighted_risk=weighted.mean(death,survey_weight)),by=.(transition,phenotype)]
    data.table::fwrite(mortality,file.path(out,paste0(es,'_mortality.csv')))
    built<-hrs_composite(d)
    saveRDS(built$full,file.path(local,paste0(es,'_composite_risk_set.rds')))
    saveRDS(built$analysis,file.path(local,paste0(es,'_composite_analytic.rds')))
    data.table::fwrite(built$retention,file.path(out,paste0(es,'_retention.csv')))
    a<-built$analysis
    counts<-a[,.(n_intervals=.N,events=sum(event),deaths=sum(death),
      symptom_events=sum(event[death==0]),weight_max=max(composite_weight_norm),
      ess=sum(composite_weight_norm)^2/sum(composite_weight_norm^2)),by=phenotype]
    stopifnot(all(counts$events==counts$deaths+counts$symptom_events))
    data.table::fwrite(counts,file.path(out,paste0(es,'_composite_counts.csv')))
    vars<-c('event','phenotype','age','female','education3','partnered','depressive_score',
      'noncancer_comorbidity_count','current_smoking','wealth_quintile','transition',
      'composite_weight_norm','person_id','stratum','half_sample')
    ad<-hrs_prepare(a[,..vars])
    setup<-mice::mice(ad,maxit=0,printFlag=FALSE)
    saveRDS(setup$loggedEvents,file.path(local,paste0(es,'_initialization_events.rds')))
    meth<-setNames(rep('',ncol(ad)),names(ad)); pred<-setup$predictorMatrix
    for(n in c('education3','wealth_quintile')) if(anyNA(ad[[n]])) meth[n]<-'polyreg'
    for(n in c('partnered','current_smoking')) if(anyNA(ad[[n]])) meth[n]<-'logreg'
    if(anyNA(ad$noncancer_comorbidity_count)) meth['noncancer_comorbidity_count']<-'pmm'
    excluded<-c('person_id','stratum','half_sample','composite_weight_norm')
    pred[,excluded]<-0;pred[excluded,]<-0
    cat('Composite imputation m=20, iterations=10. This may take time.\n')
    ci<-mice::mice(ad,m=20,maxit=10,method=meth,predictorMatrix=pred,
      seed=if(es=='onset') 905101L else 905102L,printFlag=TRUE)
    saveRDS(ci,file.path(local,paste0(es,'_composite_mids.rds')))
    hrs_fit_mids(ci,'composite_weight_norm',out,paste0(es,'_composite'))
    hrs_diagnostics(ci,out,paste0(es,'_composite'))
    capture.output(str(ci$loggedEvents),file=file.path(local,paste0(es,'_final_events.txt')))
  }
  capture.output(sessionInfo(),file=file.path(out,'session_info.txt'))
  writeLines(c('RUN_COMPLETED; requires scientific review.',
    'Composite is high symptoms OR death, not depression incidence.',
    'Weights/sample differ from symptom models; differences do not isolate survival bias.',
    'MI chain exports are diagnostics for review, not proof of convergence.',
    'Return SUMMARY_RETURN only. Never return LOCAL_ONLY or source data.'),file.path(out,'RUN_COMPLETED.txt'))
  cat('\nCompleted. Return only: ',out,'\n',sep='')
  invisible(out)
}
