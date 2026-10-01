# Human-operated only. Sourcing defines functions and never reads study records.
he_prepare <- function(d) {
  d <- hrs_prepare(as.data.frame(d))
  if(anyDuplicated(paste(d$person_id,d$transition)))stop('DUPLICATE_INTERVAL')
  d$event <- hrs_binary_event(d$event)
  d
}
he_support <- function(d,group='phenotype') {
  if(!nrow(d)||length(unique(d$person_id))<100||anyNA(d[c('event','person_id',group)]))return(FALSE)
  g <- split(d,d[[group]],drop=TRUE)
  if(!length(g))return(FALSE)
  all(vapply(g,function(z)length(unique(z$person_id))>=20&&all(vapply(0:1,function(k){
    n <- length(unique(z$person_id[z$event==k]));n==0||n>=20
  },logical(1))),logical(1)))
}
he_estimates <- function(model,spec,exponentiate=TRUE) {
  b <- coef(model);v <- vcov(model)
  if(any(!is.finite(b))||any(!is.finite(v))||!isTRUE(model$converged))stop('MODEL_INVALID')
  do.call(rbind,lapply(names(spec),function(name){
    if(!all(names(spec[[name]]) %in% names(b)))stop('CONTRAST_ABSENT')
    a <- setNames(numeric(length(b)),names(b));a[names(spec[[name]])] <- spec[[name]]
    estimate <- sum(a*b);se <- sqrt(drop(t(a)%*%v%*%a))
    if(!is.finite(se)||se<=0)stop('VARIANCE_INVALID')
    data.frame(contrast=name,estimate=estimate,se=se,
      conf_low=if(exponentiate)exp(estimate-qnorm(.975)*se)else estimate-qnorm(.975)*se,
      conf_high=if(exponentiate)exp(estimate+qnorm(.975)*se)else estimate+qnorm(.975)*se,
      ratio=if(exponentiate)exp(estimate)else NA_real_,p_value=2*pnorm(-abs(estimate/se)))
  }))
}
he_specs <- function()list(cancer_and_pain_vs_neither=c(phenotypecancer_and_pain=1),
  cancer_and_pain_vs_cancer_only=c(phenotypecancer_and_pain=1,phenotypecancer_only=-1),
  pain_only_vs_neither=c(phenotypepain_only=1),cancer_only_vs_neither=c(phenotypecancer_only=1),
  pain_only_vs_cancer_only=c(phenotypepain_only=1,phenotypecancer_only=-1))
he_job_names <- function() {
  suffix <- c('function_core','function_mobility','function_mobility_adl','first_interval',
    'reduced','trim_final_weight','continuous_score','no_sleep_score',
    'pain_gradient','pain_trend','interaction_sex','interaction_age')
  unlist(lapply(c('onset','persistence'),function(es)paste(es,suffix,sep='_')),use.names=FALSE)
}
he_reused_jobs <- function()data.frame(job=c('onset_prepandemic','onset_exclude_latest',
  'persistence_prepandemic','persistence_exclude_latest'),
  status=c(rep('REUSE_ARCHIVED_NOT_REFITTED',3),'NOT_REQUIRED_NOT_IN_ARCHIVED_PLAN'),
  reason=c(rep('No 2020-2022 interval; earlier fields preserved by Final Core rebuild',3),
    'Persistence exclude-latest-only was not an archived prespecified analysis; do not add it'))
he_formula <- function(adjustment='core',estimand='onset') {
  rhs <- paste('phenotype + ns(age,df=3) + female + education3 + partnered +',
    'depressive_score + noncancer_comorbidity_count + current_smoking + wealth_quintile + transition')
  if(adjustment=='reduced')rhs <- if(estimand=='onset')
    'phenotype + ns(age,df=3) + female + education3 + partnered + depressive_score + noncancer_comorbidity_count + transition'
    else 'phenotype + ns(age,df=3) + female + depressive_score + noncancer_comorbidity_count + transition'
  if(adjustment %in% c('mobility','mobility_adl'))rhs <- paste(rhs,'+ mobility_count')
  if(adjustment=='mobility_adl')rhs <- paste(rhs,'+ adl_count')
  as.formula(paste('event ~',rhs))
}
he_fit <- function(d,formula,spec=he_specs(),family=quasipoisson('log'),
                   group='phenotype',exponentiate=TRUE) {
  vars <- unique(c(all.vars(formula),'person_id','stratum','half_sample','analysis_weight_norm','event','phenotype',group))
  if(!all(vars %in% names(d)))stop('EXTENSION_FIELD_ABSENT')
  cc <- d[complete.cases(d[vars]),,drop=FALSE]
  if(!he_support(cc,group))return(list(status='SUPPRESSED_PANEL',results=NULL,data=cc))
  fit <- survey::svyglm(formula,design=hrs_design(cc),family=family)
  ans <- he_estimates(fit,spec,exponentiate)
  ans$n_intervals <- nrow(cc);ans$n_persons <- length(unique(cc$person_id));ans$events <- sum(cc$event)
  list(status='COMPLETED_REQUIRES_REVIEW',results=ans,data=cc,model=fit)
}
he_z <- function(x,w) {
  i <- is.finite(x)&is.finite(w)&w>0
  if(sum(i)<2)stop('SCORE_UNSUPPORTED')
  m <- weighted.mean(x[i],w[i]);s <- sqrt(weighted.mean((x[i]-m)^2,w[i]))
  if(!is.finite(s)||s<=0)stop('SCORE_VARIANCE')
  (x-m)/s
}
he_no_sleep_2022 <- function(module) {
  full <- hc_cesd(module)
  sleep <- hc_values(module$SD112)
  contribution <- ifelse(sleep %in% c('1','5'),as.numeric(sleep=='1'),NA_real_)
  no <- full$raw_cesd8-contribution
  if(any(!is.na(no)&!no %in% 0:7))stop('NO_SLEEP_SCORE_INVALID')
  data.frame(person_id=full$id,wave=16L,item_full_score=full$raw_cesd8,
    item_no_sleep_score=no,sleep_item_contribution=contribution)
}
he_run <- function(project,output_base='local_results/research_closeout',
  saved='local_results/HRS/final_core_update_20260907_125344/LOCAL_ONLY') {
  source(file.path(project,'HRS_local_run_package/HRS_run.R'),encoding='UTF-8');hrs_packages()
  source(file.path(project,'HRS_local_run_package/final_core_compare.R'),encoding='UTF-8')
  source(file.path(project,'HRS_local_run_package/final_core_update.R'),encoding='UTF-8')
  wave <- file.path(project,'data/01_harmonized/cpd_multicohort_01/HRS/v1.1')
  inputs <- c(file.path(saved,paste0(c('onset','persistence'),'_symptoms_analytic.rds')),
    file.path(wave,'hrs_pain_burden_wave_level_v1.1.csv.gz'),
    file.path(wave,'hrs_depressive_items_no_sleep_wave_level_v1.1.csv.gz'),file.path(saved,'h22d_r.csv'))
  if(!all(file.exists(inputs)))stop('INPUT_ABSENT')
  endpoint_path <- file.path(saved,'final_core_2022_endpoint.rds')
  manifest_path <- file.path(dirname(saved),'SUMMARY_RETURN/private_artifact_hashes.csv')
  if(!all(file.exists(c(endpoint_path,manifest_path))))stop('FROZEN_MANIFEST_ABSENT')
  frozen <- read.csv(manifest_path,colClasses='character')
  for(p in c(inputs[1:2],endpoint_path)) {
    h <- frozen$sha256[match(basename(p),frozen$file)]
    if(length(h)!=1L||is.na(h)||digest::digest(file=p,algo='sha256')!=h)stop('FROZEN_ARTIFACT_HASH_MISMATCH')
  }
  inputs <- c(inputs,endpoint_path,manifest_path)
  code <- file.path(project,c('Research_local_closeout/hrs_final_extensions.R',
    'HRS_local_run_package/HRS_run.R','HRS_local_run_package/final_core_compare.R'))
  hashes <- tools::md5sum(c(inputs,code))
  dest <- file.path(output_base,paste0('hrs_extensions_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(dest))stop('OUTPUT_EXISTS')
  private <- file.path(dest,'LOCAL_ONLY');out <- file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE);dir.create(out)
  log <- file(file.path(private,'private_log.txt'),'wt');sink(log);sink(log,type='message')
  on.exit({sink(type='message');sink();close(log)},add=TRUE)
  write.csv(data.frame(file=basename(c(inputs,code)),md5=unname(hashes)),file.path(out,'input_code_fingerprints.csv'),row.names=FALSE)
  write.csv(data.frame(job=he_job_names(),purpose='Final2022 dependent extension update; not new scientific hypothesis'),
    file.path(out,'planned_jobs.csv'),row.names=FALSE)
  write.csv(he_reused_jobs(),file.path(out,'reused_jobs.csv'),row.names=FALSE)
  burden <- as.data.frame(data.table::fread(inputs[3],colClasses=c(person_id='character')))
  burden$person_id <- fu_id(burden$person_id)
  items <- as.data.frame(data.table::fread(inputs[4],colClasses=c(person_id='character')))
  items$person_id <- fu_id(items$person_id)
  names(items)[match(c('depressive_score_full_reconstructed','depressive_score_no_sleep'),names(items))] <-
    c('item_full_score','item_no_sleep_score')
  final <- he_no_sleep_2022(hc_read_module(inputs[5],paste0('SD',110:117)))
  endpoint <- readRDS(endpoint_path)
  j <- match(final$person_id,endpoint$id)
  if(length(j)!=nrow(endpoint)||anyNA(j)||anyDuplicated(j)||
    !cl_equal(final$item_full_score,endpoint$raw_cesd8[j]))stop('FINAL_ENDPOINT_MISMATCH')
  items <- rbind(items[items$wave!=16,c('person_id','wave','item_full_score','item_no_sleep_score','sleep_item_contribution')],final)
  if(anyDuplicated(paste(items$person_id,items$wave))||anyDuplicated(paste(burden$person_id,burden$wave)))stop('WAVE_KEY_DUPLICATE')
  saveRDS(items,file.path(private,'items_2022_final_updated.rds'))
  status <- data.frame(job=character(),status=character(),warnings=character())
  run_job <- function(tag,fun) {
    sink();cat('Extension: ',tag,'\n',sep='');flush.console();sink(log)
    warn <- character()
    ans <- tryCatch(withCallingHandlers(fun(),warning=function(w){warn <<- c(warn,conditionMessage(w));invokeRestart('muffleWarning')}),
      error=function(e){writeLines(conditionMessage(e),file.path(private,paste0(tag,'_error.txt')));list(status='FAILED_REVIEW_LOCALLY')})
    if(!is.null(ans$data))saveRDS(ans$data,file.path(private,paste0(tag,'_pre_model_frame.rds')))
    if(!is.null(ans$model))saveRDS(ans$model,file.path(private,paste0(tag,'_model.rds')))
    if(!is.null(ans$results)) {
      ans$results$cohort <- 'HRS'
      ans$results$estimand <- sub('_.*','',tag)
      ans$results$model_tag <- tag
      ans$results$analysis_version <- 'HRS_Final2022_extensions_2026-10-01'
      ans$results$variance <- ans$results$se^2
      write.csv(ans$results,file.path(out,paste0(tag,'_results.csv')),row.names=FALSE)
    }
    if(!is.null(ans$joint))write.csv(ans$joint,file.path(out,paste0(tag,'_joint_test.csv')),row.names=FALSE)
    writeLines(unique(warn),file.path(private,paste0(tag,'_warnings.txt')))
    status <<- rbind(status,data.frame(job=tag,status=ans$status,warnings=if(length(warn))'LOCAL_REVIEW_REQUIRED' else 'NONE_CAPTURED'))
    write.csv(status,file.path(out,'job_status.csv'),row.names=FALSE)
  }
  for(es in c('onset','persistence')) {
    d <- he_prepare(readRDS(file.path(saved,paste0(es,'_symptoms_analytic.rds'))))
    d$person_id <- fu_id(d$person_id)
    if(anyNA(d$follow_depressive_score)||any((d$follow_depressive_score>=4)!=as.logical(d$event)))stop('FINAL_SCORE_EVENT_INCONSISTENT')
    for(adjustment in c('core','mobility','mobility_adl'))run_job(paste(es,'function',adjustment,sep='_'),
      function()he_fit(d,he_formula(adjustment,es)))
    first <- d[order(d$base_wave,d$person_id),];first <- first[!duplicated(first$person_id),]
    run_job(paste0(es,'_first_interval'),function()he_fit(first,he_formula('core',es)))
    run_job(paste0(es,'_reduced'),function()he_fit(d,he_formula('reduced',es)))
    # Earlier-only sensitivities were already fitted and their inputs are unchanged.
    # They are listed in reused_jobs.csv, never refitted for this endpoint update.
    trimmed <- d
    for(t in unique(d$transition)) {i <- which(d$transition==t);q <- quantile(d$analysis_weight_norm[i],c(.01,.99))
      w <- pmin(q[2],pmax(q[1],d$analysis_weight_norm[i]));trimmed$analysis_weight_norm[i] <- w/mean(w)}
    run_job(paste0(es,'_trim_final_weight'),function()he_fit(trimmed,he_formula('core',es)))
    # Same complete-case standardized-score sensitivity as the archived analysis.
    continuous <- d
    continuous$follow_score_z <- he_z(d$follow_depressive_score,d$analysis_weight_norm)
    continuous$baseline_score_z <- he_z(d$depressive_score,d$analysis_weight_norm)
    form <- update(he_formula(),follow_score_z ~ . - depressive_score + baseline_score_z)
    run_job(paste0(es,'_continuous_score'),function()he_fit(continuous,form,family=gaussian(),exponentiate=FALSE))
    a <- match(paste(d$person_id,d$base_wave),paste(items$person_id,items$wave))
    b <- match(paste(d$person_id,d$follow_wave),paste(items$person_id,items$wave))
    if(any(!is.na(items$item_full_score[a]) & items$item_full_score[a]!=d$depressive_score)||
       any(!is.na(items$item_full_score[b]) & items$item_full_score[b]!=d$follow_depressive_score))stop('ITEM_FULL_SCORE_MISMATCH')
    no <- d;no$baseline_no_sleep_z <- he_z(items$item_no_sleep_score[a],d$analysis_weight_norm)
    no$follow_no_sleep_z <- he_z(items$item_no_sleep_score[b],d$analysis_weight_norm)
    noform <- update(he_formula(),follow_no_sleep_z ~ . - depressive_score + baseline_no_sleep_z)
    run_job(paste0(es,'_no_sleep_score'),function()he_fit(no,noform,family=gaussian(),exponentiate=FALSE))
    k <- match(paste(d$person_id,d$base_wave),paste(burden$person_id,burden$wave))
    bd <- d;bd$pain_burden_numeric <- as.numeric(burden$pain_burden_level[k])
    bd$pain_burden_factor <- factor(bd$pain_burden_numeric,levels=0:3,
      labels=c('none','mild_or_1_site','moderate_or_2_sites','severe_or_3plus_sites'))
    bd$cancer_factor <- factor(bd$cancer,levels=0:1)
    gform <- update(he_formula(),. ~ . - phenotype + pain_burden_factor + cancer_factor)
    gspec <- list(mild_vs_none=c(pain_burden_factormild_or_1_site=1),
      moderate_vs_none=c(pain_burden_factormoderate_or_2_sites=1),severe_vs_none=c(pain_burden_factorsevere_or_3plus_sites=1))
    run_job(paste0(es,'_pain_gradient'),function()he_fit(bd,gform,gspec,group='pain_burden_factor'))
    run_job(paste0(es,'_pain_trend'),function()he_fit(bd,update(gform,. ~ . - pain_burden_factor + pain_burden_numeric),
      list(per_level=c(pain_burden_numeric=1)),group='pain_burden_factor'))
    for(modifier in c('sex','age')) {
      md <- d;md$modifier <- if(modifier=='sex')factor(d$female,levels=0:1,labels=c('male','female')) else
        factor(as.integer(d$age>=65),levels=0:1,labels=c('age50_64','age65plus'))
      md$privacy_group <- interaction(md$phenotype,md$modifier,drop=TRUE)
      mf <- if(modifier=='sex')update(he_formula(),. ~ . - female + phenotype*modifier)
        else update(he_formula(),. ~ . + phenotype*modifier)
      suffix <- if(modifier=='sex')'female' else 'age65plus'
      specs <- lapply(he_specs(),function(x){names(x) <- paste0(names(x),':modifier',suffix);x})
      run_job(paste(es,'interaction',modifier,sep='_'),function(){
        ans <- he_fit(md,mf,specs,group='privacy_group')
        if(!is.null(ans$model)) {
          b <- coef(ans$model);v <- vcov(ans$model)
          terms <- grep('^phenotype.*:modifier',names(b),value=TRUE)
          if(length(terms)!=3L)stop('JOINT_INTERACTION_TERMS')
          q <- drop(t(b[terms])%*%solve(v[terms,terms,drop=FALSE],b[terms]))
          ans$joint <- data.frame(wald_chisq=q,df=3L,p_value=pchisq(q,3,lower.tail=FALSE))
        }
        ans
      })
    }
  }
  if(!identical(hashes,tools::md5sum(c(inputs,code))))stop('INPUT_CHANGED')
  if(!setequal(status$job,he_job_names())||anyDuplicated(status$job))stop('JOB_PLAN_MISMATCH')
  overall <- if(any(status$status!='COMPLETED_REQUIRES_REVIEW'))
    'HRS_FINAL_EXTENSIONS_EXPORTED_WITH_UNRESOLVED_PANELS' else 'HRS_FINAL_EXTENSIONS_COMPLETED_REQUIRES_REVIEW'
  writeLines(c(overall,
    '24 planned updates. Four earlier-only sensitivities reused, not refitted.',
    'No core models/imputations rerun. Extensions follow archived complete-case methods and normal intervals.',
    '2022 sleep-item scores rebuilt from saved Final Core SD110-SD117 with SD112 excluded.',
    'Each model has its own complete-case population; attenuation does not identify mediation.',
    'Suppressed/failed panels and local warning review remain unresolved until inspected.'),file.path(out,'RUN_STATUS.txt'))
  sink(type='message');sink();close(log);on.exit(NULL)
  cat('Finished. Return SUMMARY_RETURN only: ',out,'\n',sep='');invisible(out)
}
