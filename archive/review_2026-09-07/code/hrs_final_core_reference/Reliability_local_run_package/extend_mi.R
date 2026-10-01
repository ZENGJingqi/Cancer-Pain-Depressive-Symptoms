# Independent human-operated local run only. Source defines functions, reads no records.
ext_paths <- function(project) {
  base<-file.path(project,'data/03_outputs/cpd_multicohort_01/models')
  names<-c(charls_onset='charls_mice_m20_v1.0.rds',charls_persistence='charls_persistence_mice_m20_v1.1.rds',
    charls_composite_onset='charls_composite_onset_mice_m20_v1.2.rds',
    charls_composite_persistence='charls_composite_persistence_mice_m20_v1.2.rds',
    share_persistence='share_persistence_mice_m20_v1.1.rds',
    hrs_onset='hrs_mice_m20_v1.0.rds',hrs_persistence='hrs_persistence_mice_m20_v1.1.rds')
  p<-setNames(file.path(base,names),names(names))
  hp<-'D:/HRS_local_results/20260905_200545/LOCAL_ONLY'
  c(p,hrs_composite_onset=file.path(hp,'onset_composite_mids.rds'),
    hrs_composite_persistence=file.path(hp,'persistence_composite_mids.rds'))
}
ext_design <- function(d,cohort,weight) {
  fields<-switch(cohort,HRS=c('stratum','half_sample','person_id'),
    SHARE=c('country','household_id','person_id'),CHARLS=c('community_id','person_id'))
  if(!all(c(fields,weight)%in%names(d))||anyNA(d[fields]))stop('Invalid design fields')
  d$weight_current<-d[[weight]]
  if(any(!is.finite(d$weight_current)|d$weight_current<=0))stop('Invalid weights')
  if(cohort=='HRS')return(survey::svydesign(ids=~half_sample+person_id,strata=~stratum,weights=~weight_current,data=d,nest=TRUE))
  if(cohort=='SHARE') {
    d$country<-factor(d$country)
    d$household_cluster<-interaction(d$country,d$household_id,drop=TRUE)
    return(survey::svydesign(ids=~household_cluster+person_id,strata=~country,weights=~weight_current,data=d,nest=TRUE))
  }
  survey::svydesign(ids=~community_id+person_id,weights=~weight_current,data=d,nest=TRUE)
}
ext_fit <- function(imp,cohort,composite=FALSE) {
  weight<-if(composite)'composite_weight_norm'else'analysis_weight_norm'
  outcome<-if(composite&&cohort=='CHARLS')'composite_event'else'event'
  if(!outcome%in%names(imp$data))stop('Outcome absent')
  rows<-list()
  for(j in seq_len(imp$m)) {
    d<-as.data.frame(mice::complete(imp,j))
    d$event<-hrs_binary_event(d[[outcome]])
    d<-hrs_prepare(d)
    formula<-hrs_formula()
    if(cohort=='SHARE')formula<-update(formula,.~.+country)
    design<-ext_design(d,cohort,weight)
    if(anyNA(model.frame(formula,design$variables,na.action=na.pass)))stop('Model fields missing')
    fit<-survey::svyglm(formula,design=design,family=quasipoisson('log'))
    if(!isTRUE(fit$converged)||nobs(fit)!=nrow(d))stop('Model convergence or row count failed')
    x<-hrs_contrasts(fit);x$imputation<-j
    rows[[j]]<-x
  }
  x<-data.table::rbindlist(rows)
  p<-x[,hrs_pool(log_rr,variance),by=contrast]
  p$n_intervals<-nrow(imp$data)
  p$n_persons<-length(unique(imp$data$person_id))
  p$events<-sum(hrs_binary_event(imp$data[[outcome]]))
  list(pooled=as.data.frame(p),draws=as.data.frame(x))
}
ext_invariants <- function(old,new) {
  for(v in c('data','where','method','predictorMatrix','m','blocks','visitSequence'))
    if(!identical(old[[v]],new[[v]]))stop('Fixed MI setting changed')
  for(stat in c('chainMean','chainVar')) {
    a<-old[[stat]];b<-new[[stat]]
    if(!isTRUE(all.equal(unname(a),unname(b[,seq_len(dim(a)[2]),,drop=FALSE]))))stop('Old chain prefix changed')
  }
  invisible(TRUE)
}
ext_continue <- function(old,target=50L) {
  if(old$iteration>=target)stop('Target must exceed current iteration')
  new<-mice::mice.mids(old,maxit=target-old$iteration,printFlag=FALSE)
  ext_invariants(old,new)
  if(new$iteration!=target)stop('Unexpected iteration count')
  new
}
ext_late <- function(imp,tag,out) {
  rows<-list()
  for(stat in c('chainMean','chainVar')) {
    a<-imp[[stat]]
    for(v in intersect(rel_vars,dimnames(a)[[1]])) {
      if(!any(imp$where[,v])||!rel_group_safe(imp$data,is.na(imp$data[[v]])))next
      x<-matrix(a[v,,],nrow=dim(a)[2],ncol=dim(a)[3])
      if(stat=='chainVar')x<-sqrt(x)
      for(n in c(20L,30L)) {
        if(nrow(x)<n)next
        rows[[length(rows)+1]]<-data.frame(variable=v,parameter=stat,last_iterations=n,
          split_rhat_classic=rel_split_rhat(tail(x,n)),
          first_iteration=nrow(x)-n+1,final_iteration=nrow(x))
      }
    }
  }
  if(length(rows))rel_write(do.call(rbind,rows),file.path(out,paste0(tag,'_late_chain_diagnostics.csv')))
}
ext_archive <- function(project,cohort,es,composite) {
  if(cohort=='HRS'&&composite) {
    p<-file.path('D:/HRS_local_results/20260905_200545/SUMMARY_RETURN',paste0(es,'_composite_RR.csv'))
    return(read.csv(p,check.names=FALSE))
  }
  od<-file.path(project,'data/03_outputs/cpd_multicohort_01')
  if(composite) {
    d<-read.csv(file.path(od,'models/composite_adverse_state_adjusted_risk_ratios_v1.2.csv'))
  }else d<-read.csv(file.path(od,'tables/Table2_onset_persistence_adjusted_RRs_v1.1.csv'))
  d[d$cohort==cohort&d$estimand==es,,drop=FALSE]
}
ext_check_archive <- function(baseline,archive) {
  if(nrow(archive)<4||anyDuplicated(archive$contrast))stop('Archive comparison schema invalid')
  k<-match(archive$contrast,baseline$contrast)
  if(anyNA(k))stop('Archive contrast missing')
  for(v in c('rr','conf_low','conf_high')) {
    if(any(!is.finite(archive[[v]]))||any(abs(log(baseline[[v]][k])-log(archive[[v]]))>1e-6))
      stop('Baseline archived estimate mismatch')
  }
  for(v in c('n_intervals','n_persons','events')) {
    if(any(as.numeric(baseline[[v]][k])!=as.numeric(archive[[v]])))stop('Baseline archive counts mismatch')
  }
  TRUE
}
extend_mi_run <- function(project,output_base='D:/Reliability_local_results',target=50L) {
  rel_require();hrs_packages()
  dest<-file.path(output_base,paste0('mi_extension_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(dest))stop('Output exists')
  private<-file.path(dest,'LOCAL_ONLY');out<-file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE);dir.create(out)
  cat('Output: ',dest,'\n',sep='');flush.console()
  codefiles<-file.path(project,c('Reliability_local_run_package/extend_mi.R',
    'Reliability_local_run_package/reliability_checks.R','HRS_local_run_package/HRS_run.R'))
  rel_write(data.frame(file=basename(codefiles),sha256=vapply(codefiles,rel_hash,character(1))),
    file.path(out,'code_hashes.csv'))
  capture.output(sessionInfo(),file=file.path(private,'session_info.txt'))
  paths<-ext_paths(project)
  expected<-read.csv('D:/Reliability_local_results/20260906_165628/SUMMARY_RETURN/input_hashes.csv')
  jobs<-data.frame(job=names(paths),status='NOT_STARTED')
  rel_write(jobs,file.path(out,'job_status.csv'))
  allok<-FALSE
  on.exit(if(!allok)writeLines('STOPPED_OR_PARTIAL_NOT_VALIDATED',file.path(out,'RUN_STATUS.txt')),add=TRUE)
  for(i in seq_along(paths)) {
    tag<-names(paths)[i];p<-paths[[i]]
    cat('Job ',i,'/',length(paths),': ',tag,'\n',sep='');flush.console()
    jobs$status[i]<-'RUNNING';rel_write(jobs,file.path(out,'job_status.csv'))
    log<-file(file.path(private,paste0(tag,'_private_log.txt')),'wt')
    failure<-NULL
    result<-tryCatch({
      sink(log);sink(log,type='message')
      k<-match(tag,expected$tag)
      if(is.na(k)||!file.exists(p)||rel_hash(p)!=expected$sha256[k])stop('Input differs from reviewed diagnostic source')
      old<-readRDS(p)
      cohort<-toupper(strsplit(tag,'_')[[1]][1]);es<-if(grepl('persistence',tag))'persistence'else'onset'
      composite<-grepl('composite',tag)
      baseline<-ext_fit(old,cohort,composite)
      archive<-ext_archive(project,cohort,es,composite)
      ext_check_archive(baseline$pooled,archive)
      new<-ext_continue(old,target)
      saveRDS(new,file.path(private,paste0(tag,'_mids_iter',target,'.rds')))
      extended<-ext_fit(new,cohort,composite)
      rel_write(baseline$pooled,file.path(out,paste0(tag,'_baseline_RR.csv')))
      rel_write(extended$pooled,file.path(out,paste0(tag,'_extended_RR.csv')))
      rel_write(extended$draws,file.path(out,paste0(tag,'_extended_per_imputation.csv')))
      comparison<-merge(baseline$pooled,extended$pooled,by='contrast',suffixes=c('_baseline','_extended'))
      comparison$delta_log_rr<-comparison$log_rr_extended-comparison$log_rr_baseline
      comparison$rr_relative_change_percent<-100*(comparison$rr_extended/comparison$rr_baseline-1)
      rel_write(comparison,file.path(out,paste0(tag,'_effect_comparison.csv')))
      rel_mi_report(new,paste0(tag,'_extended'),private,out)
      ext_late(new,tag,out)
      if(rel_hash(p)!=expected$sha256[k])stop('Original input changed')
      rel_write(data.frame(tag=tag,source_sha256=expected$sha256[k],original_iterations=old$iteration,
        extended_iterations=new$iteration,m=new$m,settings_unchanged=TRUE,baseline_archive_match=TRUE,
        new_object_sha256=rel_hash(file.path(private,paste0(tag,'_mids_iter',target,'.rds')))),
        file.path(out,paste0(tag,'_provenance.csv')))
      TRUE
    },error=function(e){failure<<-conditionMessage(e);writeLines(failure,log);FALSE},finally={
      if(sink.number(type='message')!=2)sink(type='message')
      if(sink.number()>0)sink()
      close(log)
    })
    if(!result) {
      # Canned stage errors only; do not return runtime text that might include records.
      safe<-c('Input differs from reviewed diagnostic source','Baseline archived estimate mismatch',
        'Baseline archive counts mismatch','Fixed MI setting changed','Old chain prefix changed')
      jobs$status[i]<-if(failure%in%safe)failure else'FAILED_PRIVATE_LOG_REVIEW_LOCALLY'
    }else jobs$status[i]<-'EXPORTED_NOT_SCIENTIFICALLY_APPROVED'
    rel_write(jobs,file.path(out,'job_status.csv'));gc()
  }
  allok<-all(jobs$status=='EXPORTED_NOT_SCIENTIFICALLY_APPROVED')
  writeLines(c(if(allok)'EXTENSION_EXPORTED_NOT_CONVERGENCE_PASS'else'PARTIAL_EXTENSION',
    'Only main modified Poisson contrasts compared. No new SHARE official design used.',
    'Do not replace manuscript tables until reviewed. Return SUMMARY_RETURN only.'),file.path(out,'RUN_STATUS.txt'))
  cat('Finished. Return SUMMARY_RETURN only: ',out,'\n',sep='')
  invisible(out)
}
