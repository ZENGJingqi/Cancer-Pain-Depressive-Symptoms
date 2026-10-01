# Human-operated only. Source defines functions and never starts study analysis.
# Reuses frozen Final2022 mids; does not call mice()/mice.mids(), RR or extensions.
br_pairs <- function() list(cancer_and_pain_vs_neither=c(4L,1L),
  cancer_and_pain_vs_cancer_only=c(4L,2L),pain_only_vs_neither=c(3L,1L),
  cancer_only_vs_neither=c(2L,1L),pain_only_vs_cancer_only=c(3L,2L))

br_standardize <- function(fit,d,weight) {
  b <- coef(fit); v <- vcov(fit)
  if(any(!is.finite(b))||any(!is.finite(v)))stop('COEFFICIENT_INVALID')
  lev <- c('neither','cancer_only','pain_only','cancer_and_pain')
  w <- d[[weight]]/sum(d[[weight]])
  if(any(!is.finite(w))||any(w<=0))stop('WEIGHT_INVALID')
  q <- numeric(4); gradients <- vector('list',4); risk <- list(); rd <- list()
  for(k in seq_along(lev)) {
    nd <- d; nd$phenotype <- factor(lev[k],levels=lev)
    x <- model.matrix(delete.response(terms(fit)),nd,contrasts.arg=fit$contrasts)[,names(b),drop=FALSE]
    p <- plogis(drop(x%*%b))
    if(any(!is.finite(p))||any(p<0|p>1))stop('PROBABILITY_BOUNDARY')
    q[k] <- sum(w*p); gradients[[k]] <- colSums(x*(w*p*(1-p)))
    if(q[k]<=0||q[k]>=1)stop('STANDARDIZED_RISK_DEGENERATE')
    u <- drop(t(gradients[[k]])%*%v%*%gradients[[k]])
    if(!is.finite(u)||u<=0)stop('VARIANCE_INVALID')
    risk[[k]] <- data.frame(phenotype=lev[k],estimate=q[k],variance=u)
  }
  for(n in names(br_pairs())) {
    ij <- br_pairs()[[n]]; g <- gradients[[ij[1]]]-gradients[[ij[2]]]
    u <- drop(t(g)%*%v%*%g)
    if(!is.finite(u)||u<=0)stop('VARIANCE_INVALID')
    rd[[n]] <- data.frame(contrast=n,estimate=q[ij[1]]-q[ij[2]],variance=u)
  }
  # No participant predictions, extrema or counts in this return value.
  list(risks=do.call(rbind,risk),RD=do.call(rbind,rd),boundary_pass=TRUE)
}

br_pool <- function(d,key,dfcom,risk=FALSE) {
  ans <- lapply(unique(d[[key]]),function(k) {
    z <- d[d[[key]]==k,,drop=FALSE]
    p <- fu_pool(z$estimate,z$variance,dfcom)
    p[[key]] <- k; p$ci_scale <- 'identity_Rubin_finite_df'
    if(risk) {
      # Preserve arithmetic pooled risk and RD coherence. Bounded CI is a
      # delta transformation of the pooled risk, not clipping or logit pooling.
      if(p$estimate<=0||p$estimate>=1)stop('POOLED_RISK_INVALID')
      h <- qt(.975,p$df)*p$se/(p$estimate*(1-p$estimate))
      p$conf_low <- plogis(qlogis(p$estimate)-h)
      p$conf_high <- plogis(qlogis(p$estimate)+h)
      p$ci_scale <- 'logit_delta_after_identity_Rubin_finite_df'
    }
    p
  })
  do.call(rbind,ans)
}

br_fit_saved <- function(imp,weight,tag,private,progress=function(x)NULL) {
  if(!inherits(imp,'mids')||imp$m!=20L||imp$iteration!=50L)stop('MI_VERSION_INVALID')
  risk <- list(); rd <- list(); metadata <- list(); ref <- imp$data
  for(j in seq_len(imp$m)) {
    progress(paste(tag,'absolute-risk logistic',j,'/',imp$m))
    d <- hrs_prepare(mice::complete(imp,j))
    fixed <- c('person_id','transition','event','phenotype','stratum','half_sample',weight)
    for(n in fixed) if(!identical(as.character(d[[n]]),as.character(ref[[n]])))stop('FIXED_MI_FIELD_CHANGED')
    if(anyNA(d)||!all(d$event %in% 0:1))stop('COMPLETED_DATA_INVALID')
    des <- hrs_design(d,weight)
    fit <- survey::svyglm(hrs_formula(),design=des,family=quasibinomial('logit'))
    if(!isTRUE(fit$converged)||nobs(fit)!=nrow(d)||fit$rank!=length(coef(fit))||
       !is.finite(fit$df.residual)||fit$df.residual<=0)stop('LOGISTIC_MODEL_INVALID')
    z <- br_standardize(fit,d,weight)
    z$risks$imputation <- j; z$RD$imputation <- j
    risk[[j]] <- z$risks; rd[[j]] <- z$RD
    metadata[[j]] <- data.frame(imputation=j,design_df=survey::degf(des),
      rank=fit$rank,dfcom=fit$df.residual,boundary_pass=z$boundary_pass)
    saveRDS(fit,file.path(private,paste0(tag,'_logistic_fit_',j,'.rds')))
  }
  risk <- do.call(rbind,risk); rd <- do.call(rbind,rd); meta <- do.call(rbind,metadata)
  if(length(unique(meta$dfcom))!=1L)stop('MI_DF_CHANGED')
  result <- list(risks=br_pool(risk,'phenotype',meta$dfcom[1],TRUE),
    risk_differences=br_pool(rd,'contrast',meta$dfcom[1]),
    risk_per_imputation=risk,RD_per_imputation=rd,model_df=meta)
  for(n in names(result)) {
    result[[n]]$analysis <- tag
    result[[n]]$analysis_version <- 'Final2022_savedMI_logistic_absolute_risk_QA_correction'
    result[[n]]$method <- 'survey_logistic_weighted_standardization_conditional_covariate_distribution'
  }
  saveRDS(result,file.path(private,paste0(tag,'_bounded_risk_aggregates.rds')))
  result
}

br_run <- function(project,output_base='local_results/research_closeout',
  saved='local_results/HRS/final_core_update_20260907_125344/LOCAL_ONLY') {
  source(file.path(project,'HRS_local_run_package/HRS_run.R'),encoding='UTF-8');hrs_packages()
  source(file.path(project,'HRS_local_run_package/final_core_update.R'),encoding='UTF-8')
  dest <- file.path(output_base,paste0('bounded_risk_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(dest))stop('OUTPUT_EXISTS')
  private <- file.path(dest,'LOCAL_ONLY'); out <- file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE);dir.create(out)
  tags <- c('onset_symptoms','onset_composite','persistence_symptoms','persistence_composite')
  jobs <- data.frame(job=tags,status='NOT_STARTED',warning_status='NOT_STARTED')
  emit <- function()write.csv(jobs,file.path(out,'job_status.csv'),row.names=FALSE)
  emit(); paths <- file.path(saved,paste0(tags,'_mids.rds'))
  warnings_private <- character()
  tryCatch({
    manifest_path <- file.path(dirname(saved),'SUMMARY_RETURN/private_artifact_hashes.csv')
    if(!all(file.exists(c(paths,manifest_path))))stop('FROZEN_INPUT_ABSENT')
    manifest <- read.csv(manifest_path,colClasses='character')
    if(anyDuplicated(manifest$file))stop('MANIFEST_DUPLICATE')
    hash <- vapply(paths,function(p)digest::digest(file=p,algo='sha256'),character(1))
    expected <- manifest$sha256[match(basename(paths),manifest$file)]
    if(anyNA(expected)||!identical(unname(hash),expected))stop('FROZEN_HASH_MISMATCH')
    write.csv(data.frame(file=basename(paths),sha256=unname(hash)),file.path(out,'input_hashes.csv'),row.names=FALSE)
    code <- file.path(project,c('Research_local_closeout/bounded_absolute_risk.R',
      'HRS_local_run_package/HRS_run.R','HRS_local_run_package/final_core_update.R'))
    codehash <- vapply(code,function(p)digest::digest(file=p,algo='sha256'),character(1))
    write.csv(data.frame(file=basename(code),sha256=unname(codehash)),file.path(out,'code_hashes.csv'),row.names=FALSE)
    for(i in seq_along(tags)) {
      jobs$status[i] <- 'RUNNING';emit();warn_before <- length(warnings_private)
      imp <- readRDS(paths[i]);weight <- if(grepl('symptoms$',tags[i]))'analysis_weight_norm'else'composite_weight_norm'
      result <- withCallingHandlers(br_fit_saved(imp,weight,tags[i],private,
        function(x)cat(format(Sys.time(),'%H:%M:%S'),x,'\n')),
        warning=function(w){warnings_private <<- c(warnings_private,conditionMessage(w));invokeRestart('muffleWarning')})
      # Match prior whole-panel support gate, additionally require all 4 groups.
      safe <- fu_supported(imp$data)&&setequal(unique(as.character(imp$data$phenotype)),
        c('neither','cancer_only','pain_only','cancer_and_pain'))
      if(safe)for(n in names(result))write.csv(result[[n]],file.path(out,paste0(tags[i],'_',n,'.csv')),row.names=FALSE)
      jobs$status[i] <- if(safe)'EXPORTED_REQUIRES_REVIEW'else'SUPPRESSED_LOCAL_REVIEW'
      jobs$warning_status[i] <- if(length(warnings_private)>warn_before)'CAPTURED_REVIEW_LOCALLY'else'NONE_CAPTURED'
      emit();rm(imp,result);gc()
    }
    if(!identical(hash,vapply(paths,function(p)digest::digest(file=p,algo='sha256'),character(1)))||
      !identical(codehash,vapply(code,function(p)digest::digest(file=p,algo='sha256'),character(1))))stop('INPUT_OR_CODE_CHANGED')
    writeLines(warnings_private,file.path(private,'warnings_LOCAL_ONLY.txt'))
    writeLines(c('COMPLETED_REQUIRES_REVIEW','Saved m20/50 imputations reused unchanged.',
      'Only logistic absolute-risk outcome models fitted. No primary RR or extension models rerun.',
      'No odds-ratio export. Conditional standardization variance; weights/covariate distribution treated fixed.',
      'Risk CIs: logit delta after identity Rubin pooling. RD CIs: finite-df identity, not clipped.'),file.path(out,'RUN_STATUS.txt'))
    cat('Completed. Return SUMMARY_RETURN only: ',out,'\n',sep='')
    invisible(out)
  },error=function(e){
    writeLines(conditionMessage(e),file.path(private,'error_LOCAL_ONLY.txt'))
    writeLines(warnings_private,file.path(private,'warnings_LOCAL_ONLY.txt'))
    jobs$status[jobs$status=='RUNNING'] <- 'FAILED_REVIEW_LOCALLY';emit()
    writeLines('STOPPED_PRIVATE_REVIEW_REQUIRED',file.path(out,'RUN_STATUS.txt'))
    cat('Stopped. Return SUMMARY_RETURN only: ',out,'\n',sep='');invisible(out)
  })
}
