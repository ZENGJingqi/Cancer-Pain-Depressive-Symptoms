# Human-operated R only. Sourcing defines functions; never launches real analysis.
# Scope: Final Core 2022 symptom endpoint; archived RAND death tracking retained.
fu_runtime <- new.env(parent=emptyenv())
fu_error_code <- function(e) {
  # Exact allowlist only. Never print arbitrary error text, row values or calls.
  known <- c('Earlier interval changed: event'='EARLIER_EVENT_VALUE_CHANGED',
    'FINAL_INTERVIEW_DEATH_CONFLICT_REVIEW_LOCALLY'='FINAL_INTERVIEW_DEATH_CONFLICT',
    'Invalid analytic identifier'='ANALYTIC_ID_FORMAT',
    'Risk-set schema mismatch'='RISK_SET_SCHEMA',
    'Invalid risk-set keys or death status'='RISK_SET_KEY_OR_DEATH_STATUS',
    'Duplicate endpoint key'='DUPLICATE_ENDPOINT_KEY',
    'Final follow-up interval absent'='FINAL_INTERVAL_ABSENT',
    'Invalid CES-D score'='INVALID_CESD_SCORE',
    'Invalid event encoding; expected binary 0/1 or logical'='INVALID_EVENT_ENCODING',
    'Final retention model did not converge'='RETENTION_NOT_CONVERGED',
    'Invalid retention predictions'='RETENTION_PREDICTION_INVALID',
    'Retention model failed'='COMPOSITE_RETENTION_FAILED',
    'Core hash mismatch'='CORE_HASH_MISMATCH',
    'Required input absent'='INPUT_ABSENT')
  message <- conditionMessage(e)
  if(message %in% names(known)) unname(known[[message]]) else 'UNCLASSIFIED_ERROR_PRIVATE_DETAILS_NOT_EXPORTED'
}

fu_functions <- function(path, wanted, env) {
  expressions <- parse(path, encoding='UTF-8')
  found <- character()
  for(e in expressions) {
    if(is.call(e) && identical(e[[1]],as.name('<-')) && is.symbol(e[[2]]) &&
       is.call(e[[3]]) && identical(e[[3]][[1]],as.name('function'))) {
      n <- as.character(e[[2]])
      if(n %in% wanted) {eval(e,env); found <- c(found,n)}
    }
  }
  if(!setequal(found,wanted)||anyDuplicated(found)) stop('Required code function absent or duplicated')
  invisible(env)
}

fu_id <- function(x) {
  z <- sub('[.]0+$','',trimws(as.character(x)))
  if(anyNA(z)||any(!grepl('^[0-9]{1,9}$',z))) stop('Invalid analytic identifier')
  sprintf('%09.0f',as.numeric(z))
}

fu_dependencies <- function(project) {
  e <- new.env(parent=globalenv())
  fu_functions(file.path(project,'scripts/27_construct_retention_weights_and_freeze_v1_0.R'),
    c('category_with_missing','fit_retention_weight'),e)
  p <- new.env(parent=globalenv())
  fu_functions(file.path(project,'scripts/39_build_persistence_intervals_and_weights_v1_1.R'),
    c('category_with_missing','fit_retention_weight'),p)
  list(onset=e,persistence=p)
}

fu_rebuild <- function(old, endpoint, estimand, retention, progress=function(label)invisible(NULL)) {
  progress('Rebuild: validate risk-set schema and keys')
  d <- data.table::copy(data.table::as.data.table(old))
  needed <- c('person_id','transition','follow_death_this_wave','follow_observed',
    'event','survey_weight','primary_interval','analysis_eligible','follow_depressive_score')
  if(!all(needed %in% names(d))) stop('Risk-set schema mismatch')
  if(anyNA(d[,.(person_id,transition,follow_death_this_wave)]) ||
     anyDuplicated(d[,.(person_id,transition)])) stop('Invalid risk-set keys or death status')
  if(anyNA(endpoint$id)||anyDuplicated(endpoint$id)) stop('Duplicate endpoint key')
  i <- which(as.character(d$transition)=='2020-2022')
  if(!length(i)) stop('Final follow-up interval absent')
  progress('Rebuild: match final endpoint and check death conflict')
  k <- match(fu_id(d$person_id[i]),endpoint$id)
  score <- endpoint$raw_cesd8[k]
  if(any(!is.na(score)&(!score %in% 0:8))) stop('Invalid CES-D score')
  # A valid 2022 symptom interview cannot silently override archived death status.
  if(any(!is.na(score)&d$follow_death_this_wave[i])) stop('FINAL_INTERVIEW_DEATH_CONFLICT_REVIEW_LOCALLY')
  d$follow_depressive_score[i] <- score
  d$follow_depressive_high[i] <- ifelse(is.na(score),NA,score>=4)
  d$follow_observed[i] <- !is.na(score) & !d$follow_death_this_wave[i]
  # Keep archived interview/death fields for provenance; do not invent Tracker codes.
  d$event <- hrs_binary_event(d$event)
  d$event[i] <- ifelse(d$follow_observed[i],as.numeric(score>=4),NA_real_)
  if('symptom_state' %in% names(d)) {
    d$symptom_state <- as.character(d$symptom_state)
    d$symptom_state[i] <- ifelse(d$follow_death_this_wave[i],'death',
      ifelse(!d$follow_observed[i],'unobserved',ifelse(d$event[i]==1,'persistent_high','remission')))
  }
  # Clear final-interval retention fields, then apply original estimand-specific rule.
  fields <- intersect(c('retention_probability_raw','retention_probability','retention_ipw',
                       'analysis_weight','analysis_weight_norm'),names(d))
  for(v in fields) data.table::set(d,i=i,j=v,value=NA_real_)
  progress('Rebuild: fit final-interval retention model')
  fit <- retention$fit_retention_weight(d,'HRS','2020-2022')
  if(!isTRUE(fit$model$converged)) stop('Final retention model did not converge')
  pr <- fitted(fit$model)
  if(any(!is.finite(pr))) stop('Invalid retention predictions')
  w <- fit$weights
  z <- match(paste(d$person_id[i],d$transition[i]),paste(w$person_id,w$transition))
  for(v in intersect(names(w),fields)) d[[v]][i] <- w[[v]][z]
  d$analysis_weight[i] <- d$survey_weight[i]*d$retention_ipw[i]
  d$analysis_weight[i][!is.finite(d$analysis_weight[i])|d$analysis_weight[i]<=0] <- NA_real_
  d$analysis_weight_norm[i] <- d$analysis_weight[i]/mean(d$analysis_weight[i],na.rm=TRUE)
  d$analysis_eligible[i] <- d$primary_interval[i] & d$follow_observed[i] &
    !d$follow_death_this_wave[i] & is.finite(d$analysis_weight_norm[i]) & !is.na(d$event[i])
  d$endpoint_source <- ifelse(as.character(d$transition)=='2020-2022',
    'HRS_2022_Final_Core_V2.0_SD110_SD117','ARCHIVED_PRE2022_SOURCE')
  d$death_source <- 'ARCHIVED_RAND_IWSTAT_NOT_REFRESHED_BY_CORE'
  # No baseline covariates/eligibility or earlier endpoint changes are allowed.
  changed <- c(fields,'follow_depressive_score','follow_depressive_high','follow_observed',
               'event','analysis_eligible','symptom_state')
  fixed <- setdiff(names(old),changed)
  progress('Rebuild: verify baseline and earlier-interval invariants')
  for(v in fixed) if(!identical(d[[v]],old[[v]])) stop('Baseline/source field changed: ',v)
  for(v in intersect(changed,names(old))) {
    a <- d[[v]][-i]; b <- old[[v]][-i]
    # Compare the meaning of event values; TRUE/FALSE and 1/0 are equivalent.
    # Missingness and genuine event changes remain failures.
    if(v=='event') {a <- hrs_binary_event(a); b <- hrs_binary_event(b)}
    if(!isTRUE(all.equal(as.character(a),as.character(b)))) stop('Earlier interval changed: ',v)
  }
  list(full=d,retention=fit)
}

fu_impute <- function(a, weight, seed, private, tag, progress, m=20L, iterations=50L) {
  vars <- c('event','phenotype','age','female','education3','partnered','depressive_score',
    'noncancer_comorbidity_count','current_smoking','wealth_quintile','transition',
    weight,'person_id','stratum','half_sample')
  ad <- hrs_prepare(as.data.frame(a)[vars])
  fixed <- setdiff(vars,rel_vars)
  if(anyNA(ad[fixed])) stop('Missing nonimputable model field')
  setup <- mice::mice(ad,maxit=0,printFlag=FALSE)
  meth <- setNames(rep('',length(vars)),vars); pred <- setup$predictorMatrix
  for(v in c('education3','wealth_quintile')) if(anyNA(ad[[v]])) meth[v] <- 'polyreg'
  for(v in c('partnered','current_smoking')) if(anyNA(ad[[v]])) meth[v] <- 'logreg'
  if(anyNA(ad$noncancer_comorbidity_count)) meth['noncancer_comorbidity_count'] <- 'pmm'
  excluded <- c(weight,'person_id','stratum','half_sample')
  pred[,excluded] <- 0; pred[excluded,] <- 0
  saveRDS(list(data=ad,method=meth,predictorMatrix=pred,seed=seed,m=m,iterations=iterations),
    file.path(private,paste0(tag,'_pre_imputation_frozen.rds')))
  # Rebuild from new endpoint/weights. Never recycle previous completed imputations.
  imp <- mice::mice(ad,m=m,maxit=0,method=meth,predictorMatrix=pred,seed=seed,printFlag=FALSE)
  saveRDS(imp,file.path(private,paste0(tag,'_mids_checkpoint.rds')))
  while(imp$iteration<iterations) {
    target <- min(iterations,imp$iteration+10L)
    progress(paste0(tag,': imputation ',imp$iteration+1L,'-',target,' / ',iterations))
    imp <- mice::mice.mids(imp,maxit=target-imp$iteration,printFlag=FALSE)
    saveRDS(imp,file.path(private,paste0(tag,'_mids_checkpoint.rds')))
  }
  for(v in fixed) if(!identical(imp$data[[v]],ad[[v]])) stop('Fixed MI input changed')
  saveRDS(imp,file.path(private,paste0(tag,'_mids.rds')))
  imp
}

fu_pool <- function(q,u,dfcom,exponentiate=FALSE) {
  if(length(q)<2||length(q)!=length(u)||any(!is.finite(c(q,u)))||any(u<=0)||
     !is.finite(dfcom)||dfcom<=0) stop('Invalid pooling input')
  z <- mice::pool.scalar(q,u,n=dfcom+1,k=1)
  se <- sqrt(z$t); c <- qt(.975,z$df)
  x <- data.frame(estimate=z$qbar,se=se,conf_low=z$qbar-c*se,conf_high=z$qbar+c*se,
    df=z$df,dfcom=dfcom,m=length(q),within_variance=mean(u),between_variance=var(q),
    mcse=sqrt(var(q)/length(q)))
  if(exponentiate) {
    x$rr <- exp(x$estimate); x$conf_low <- exp(x$conf_low); x$conf_high <- exp(x$conf_high)
  }
  x
}

fu_supported <- function(d) {
  # Whole-panel protection, including event/non-event unique-person support.
  if(length(unique(d$person_id))<100) return(FALSE)
  all(vapply(split(d,d$phenotype,drop=TRUE),function(z) {
    length(unique(z$person_id))>=20 && all(vapply(0:1,function(e) {
      n <- length(unique(z$person_id[z$event==e])); n==0||n>=20
    },logical(1)))
  },logical(1)))
}

fu_fit <- function(imp,weight,tag,private,out,progress) {
  rr <- list(); risks <- list(); rds <- list(); metadata <- list()
  levels <- c('neither','cancer_only','pain_only','cancer_and_pain')
  pairs <- list(cancer_and_pain_vs_neither=c(4,1),cancer_and_pain_vs_cancer_only=c(4,2),
    pain_only_vs_neither=c(3,1),cancer_only_vs_neither=c(2,1),pain_only_vs_cancer_only=c(3,2))
  for(j in seq_len(imp$m)) {
    progress(paste0(tag,': model ',j,' / ',imp$m))
    d <- hrs_prepare(mice::complete(imp,j)); design <- hrs_design(d,weight)
    fit <- survey::svyglm(hrs_formula(),design=design,family=quasipoisson('log'))
    if(!isTRUE(fit$converged)||nobs(fit)!=nrow(d)||fit$rank!=length(coef(fit))) stop('Model failed')
    if(!is.finite(fit$df.residual)||fit$df.residual<=0) stop('Invalid residual degrees of freedom')
    x <- hrs_contrasts(fit); x$imputation <- j; rr[[j]] <- x
    metadata[[j]] <- data.frame(imputation=j,design_df=survey::degf(design),
      rank=fit$rank,dfcom=fit$df.residual)
    b <- coef(fit); v <- vcov(fit); w <- d[[weight]]/sum(d[[weight]])
    gradients <- list(); values <- numeric(4)
    for(k in seq_along(levels)) {
      nd <- d; nd$phenotype <- factor(levels[k],levels=levels)
      mat <- model.matrix(delete.response(terms(fit)),nd)[,names(b),drop=FALSE]
      prediction <- exp(drop(mat%*%b)); gradient <- colSums(mat*(w*prediction))
      values[k] <- sum(w*prediction); gradients[[k]] <- gradient
      risks[[length(risks)+1L]] <- data.frame(imputation=j,phenotype=levels[k],
        estimate=values[k],variance=drop(t(gradient)%*%v%*%gradient))
      # Individual predictions/ranges remain private; no extrema released.
      saveRDS(list(above_one=sum(prediction>1),range=range(prediction)),
        file.path(private,paste0(tag,'_prediction_QA_',j,'_',k,'.rds')))
    }
    for(n in names(pairs)) {
      k <- pairs[[n]]; g <- gradients[[k[1]]]-gradients[[k[2]]]
      rds[[length(rds)+1L]] <- data.frame(imputation=j,contrast=n,
        estimate=values[k[1]]-values[k[2]],variance=drop(t(g)%*%v%*%g))
    }
  }
  x <- data.table::rbindlist(rr); risk <- data.table::rbindlist(risks)
  rd <- data.table::rbindlist(rds); meta <- data.table::rbindlist(metadata)
  if(length(unique(meta$dfcom))!=1) stop('Residual df changed across imputations')
  dfcom <- meta$dfcom[1]
  pooled <- x[,fu_pool(log_rr,variance,dfcom,TRUE),by=contrast]
  pooled_risk <- risk[,fu_pool(estimate,variance,dfcom),by=phenotype]
  pooled_rd <- rd[,fu_pool(estimate,variance,dfcom),by=contrast]
  payload <- list(per_imputation=x,RR=pooled,risks=pooled_risk,risk_differences=pooled_rd,
                  risk_per_imputation=risk,RD_per_imputation=rd,model_df=meta)
  saveRDS(payload,file.path(private,paste0(tag,'_model_aggregates.rds')))
  safe <- fu_supported(imp$data)
  if(safe) for(n in names(payload)) rel_write(payload[[n]],file.path(out,paste0(tag,'_',n,'.csv')))
  if(safe) rel_write(data.frame(analysis=tag,n_intervals=nrow(imp$data),
    n_persons=length(unique(imp$data$person_id)),events=sum(imp$data$event)),
    file.path(out,paste0(tag,'_sample.csv')))
  rel_write(data.frame(analysis=tag,status=if(safe)'EXPORTED_REQUIRES_REVIEW'else'SUPPRESSED_LOCAL_REVIEW'),
    file.path(out,paste0(tag,'_model_status.csv')))
  invisible(payload)
}

fu_flow <- function(d,tag,private,out) {
  x <- d[,.(baseline_intervals=.N,persons=data.table::uniqueN(person_id),
    deaths=sum(follow_death_this_wave),observed=sum(follow_observed),
    survivor_unobserved=sum(!follow_death_this_wave&!follow_observed),
    model_intervals=sum(analysis_eligible),events=sum(event[analysis_eligible],na.rm=TRUE)),
    by=.(transition,phenotype)]
  rel_write(x,file.path(private,paste0(tag,'_flow.csv')))
  # Avoid releasing small cells or complements across a linked panel.
  safe <- all(vapply(split(d,interaction(d$transition,d$phenotype,drop=TRUE)),function(z) {
    state <- ifelse(z$follow_death_this_wave,'death',ifelse(!z$follow_observed,'unobserved',
      ifelse(!z$analysis_eligible,'weight_excluded',ifelse(z$event==1,'event','nonevent'))))
    all(vapply(split(z$person_id,state),function(a)length(unique(a))>=20,logical(1)))
  },logical(1)))
  if(safe) rel_write(x,file.path(out,paste0(tag,'_flow.csv')))
  rel_write(data.frame(analysis=tag,flow_exported=safe),file.path(out,paste0(tag,'_flow_status.csv')))
}

fu_run <- function(project,output_base='D:/HRS_local_results') {
  hrs_packages(); rel_require()
  dependencies <- fu_dependencies(project)
  dest <- file.path(output_base,paste0('final_core_update_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(dest)) stop('Output exists')
  private <- file.path(dest,'LOCAL_ONLY'); out <- file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE); dir.create(out)
  fu_runtime$out <- out
  cat('Output: ',dest,'\n',sep=''); flush.console()
  log <- file(file.path(private,'private_log.txt'),'wt'); ok <- FALSE
  sink(log); sink(log,type='message')
  on.exit({sink(type='message');sink();close(log)
    if(!ok) writeLines('STOPPED_OR_PARTIAL_RETURN_SAFE_STATUS_ONLY',file.path(out,'RUN_STATUS.txt'))
  },add=TRUE)
  progress <- function(label) {
    writeLines(label,file.path(out,'CURRENT_STAGE.txt'))
    sink()
    cat(format(Sys.time(),'%H:%M:%S'),' ',label,'\n'); flush.console()
    sink(log)
  }
  zip <- file.path(project,'原始数据总库/HRS_2022/官方更新_2022_Core_Final_V2.0/h22core.zip')
  inputs <- c(core=zip,
    onset=file.path(project,'data/02_analytic/cpd_multicohort_01/v1.0/hrs_person_intervals_v1.0.rds'),
    persistence=file.path(project,'data/02_analytic/cpd_multicohort_01/v1.1/hrs_persistence_intervals_v1.1.rds'))
  if(!all(file.exists(inputs))) stop('Required input absent')
  hashes <- vapply(inputs,rel_hash,character(1))
  if(hashes['core']!='9048917506a4143ac53c11ccee2a6929e6885bb0df48ec2e81a446e919c816ff') stop('Core hash mismatch')
  rel_write(data.frame(source=names(inputs),file=basename(inputs),sha256=hashes),file.path(out,'input_hashes.csv'))
  code <- file.path(project,c('HRS_local_run_package/final_core_update.R',
    'HRS_local_run_package/final_core_compare.R','HRS_local_run_package/HRS_run.R',
    'Reliability_local_run_package/reliability_checks.R','Reliability_local_run_package/extend_mi.R',
    'scripts/27_construct_retention_weights_and_freeze_v1_0.R',
    'scripts/39_build_persistence_intervals_and_weights_v1_1.R'))
  rel_write(data.frame(file=basename(code),sha256=vapply(code,rel_hash,character(1))),file.path(out,'code_hashes.csv'))
  progress('Read Final Core 2022 endpoint')
  unzip(zip,files='H22csv.zip',exdir=private)
  unzip(file.path(private,'H22csv.zip'),files='h22d_r.csv',exdir=private)
  endpoint <- hc_cesd(hc_read_module(file.path(private,'h22d_r.csv'),paste0('SD',110:117)))
  saveRDS(endpoint,file.path(private,'final_core_2022_endpoint.rds'))
  jobs <- data.frame(job=c('onset_symptoms','onset_composite','persistence_symptoms','persistence_composite'),status='NOT_STARTED')
  for(es in c('onset','persistence')) {
    progress(paste('Rebuild',es,'2020-2022 risk set and retention weights'))
    old <- readRDS(inputs[es]); rebuilt <- fu_rebuild(old,endpoint,es,dependencies[[es]],progress)
    d <- rebuilt$full
    saveRDS(d,file.path(private,paste0(es,'_full_risk_set.rds')))
    saveRDS(rebuilt$retention,file.path(private,paste0(es,'_retention_model.rds')))
    fu_flow(d,es,private,out)
    base <- d[primary_interval %in% TRUE & !is.na(phenotype) & is.finite(survey_weight)&survey_weight>0]
    composite <- hrs_composite(base)
    saveRDS(composite,file.path(private,paste0(es,'_composite_rebuilt.rds')))
    for(kind in c('symptoms','composite')) {
      tag <- paste(es,kind,sep='_'); row <- match(tag,jobs$job)
      jobs$status[row] <- 'RUNNING'; rel_write(jobs,file.path(out,'job_status.csv'))
      a <- if(kind=='symptoms')d[analysis_eligible %in% TRUE]else composite$analysis
      weight <- if(kind=='symptoms')'analysis_weight_norm'else'composite_weight_norm'
      saveRDS(a,file.path(private,paste0(tag,'_analytic.rds')))
      imp <- fu_impute(a,weight,907200L+row,private,tag,progress)
      fu_fit(imp,weight,tag,private,out,progress)
      rel_mi_report(imp,tag,private,out); ext_late(imp,tag,out)
      jobs$status[row] <- 'COMPLETED_REQUIRES_REVIEW'; rel_write(jobs,file.path(out,'job_status.csv'))
      rm(imp); gc()
    }
  }
  if(!identical(hashes,vapply(inputs,rel_hash,character(1)))) stop('Input changed during run')
  freeze <- list.files(private,pattern='[.]rds$',full.names=TRUE)
  rel_write(data.frame(file=basename(freeze),sha256=vapply(freeze,rel_hash,character(1))),file.path(out,'private_artifact_hashes.csv'))
  writeLines(c('HRS 2022 symptoms: Final Core V2.0, SD110-SD117, all eight items valid, threshold >=4.',
    '2012-2020 baseline variables, baseline weights, and prior intervals: archived sources unchanged.',
    'Death tracking and original interview codes: archived RAND, NOT a new Final Tracker refresh.',
    'No Core record / missing CES-D means unobserved symptoms, NOT death.',
    'New MI: m20, 50 iterations; original completed imputations not reused.',
    'Four core models, five contrasts each; finite-df pooling and absolute risks/differences.',
    'Other HRS extended/sensitivity models, combined-cohort tables and manuscript NOT updated by this run.',
    'No claim of whole-paper closure or convergence until summaries reviewed.'),file.path(out,'SOURCE_AND_SCOPE.txt'))
  capture.output(sessionInfo(),file=file.path(out,'session_info.txt'))
  writeLines('FOUR_CORE_MODELS_COMPLETED_REQUIRES_REVIEW',file.path(out,'RUN_STATUS.txt'))
  ok <- TRUE
  sink(type='message'); sink(); close(log)
  on.exit(NULL)
  cat('Finished. Return SUMMARY_RETURN only: ',out,'\n',sep='')
  invisible(out)
}
