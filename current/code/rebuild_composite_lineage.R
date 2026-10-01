# Defines functions only. Real registered data must be processed by the human locally.
cl_functions <- function(path, wanted, env) {
  found <- character()
  for(x in parse(path,encoding='UTF-8')) {
    if(is.call(x)&&identical(x[[1]],as.name('<-'))&&is.symbol(x[[2]])&&
       is.call(x[[3]])&&identical(x[[3]][[1]],as.name('function'))&&
       as.character(x[[2]]) %in% wanted) {
      eval(x,env);found <- c(found,as.character(x[[2]]))
    }
  }
  if(!setequal(found,wanted)||anyDuplicated(found)) stop('FUNCTION_SET_INVALID')
  invisible(env)
}
cl_key <- function(d) {
  if(!all(c('person_id','transition') %in% names(d))) stop('KEY_SCHEMA')
  if(anyNA(d[c('person_id','transition')])) stop('KEY_MISSING')
  k <- paste(as.character(d$person_id),as.character(d$transition),sep='|')
  if(anyDuplicated(k)) stop('KEY_DUPLICATE')
  k
}
cl_equal <- function(a,b,tol=1e-8) {
  if(length(a)!=length(b)||!identical(is.na(a),is.na(b))) return(FALSE)
  i <- !is.na(a)
  if(is.factor(a))a <- as.character(a)
  if(is.factor(b))b <- as.character(b)
  if(is.numeric(a)&&is.numeric(b)) {
    if(any(!is.finite(a[i]))||any(!is.finite(b[i])))return(identical(a,b))
    return(all(abs(a[i]-b[i])<=tol*(1+pmax(abs(a[i]),abs(b[i])))))
  }
  identical(as.character(a[i]),as.character(b[i]))
}
cl_compare_frames <- function(a,b) {
  a <- as.data.frame(a);b <- as.data.frame(b)
  ka <- cl_key(a);kb <- cl_key(b)
  if(!setequal(ka,kb))return(data.frame(field='KEY_SET',status='MISMATCH'))
  a <- a[match(kb,ka),,drop=FALSE]
  if(!all(names(b) %in% names(a)))stop('MODEL_FRAME_SCHEMA')
  data.frame(field=names(b),status=vapply(names(b),function(v)
    if(cl_equal(a[[v]],b[[v]]))'MATCH' else 'MISMATCH',character(1)))
}
cl_compare_effects <- function(now, archived) {
  if(anyDuplicated(now$contrast)||anyDuplicated(archived$contrast)||
     !setequal(as.character(now$contrast),as.character(archived$contrast)))return(FALSE)
  archived <- archived[match(now$contrast,archived$contrast),]
  cl_equal(now$log_rr,archived$log_rr)&&cl_equal(now$variance,archived$se^2)
}
cl_model_frame <- function(d,cohort) {
  cols <- c('composite_event','phenotype','age','female','education3','partnered',
    'depressive_score','noncancer_comorbidity_count','current_smoking','wealth_quintile',
    'transition','composite_weight_norm','person_id',if(cohort=='CHARLS')'community_id' else c('country','household_id'))
  if(!all(cols %in% names(d)))stop('MODEL_FRAME_SCHEMA')
  a <- as.data.frame(d)[cols]
  a$phenotype <- factor(a$phenotype,levels=c('neither','cancer_only','pain_only','cancer_and_pain'))
  for(v in c('education3','partnered','current_smoking','wealth_quintile'))
    a[[v]] <- factor(a[[v]],levels=switch(v,education3=1:3,wealth_quintile=1:5,0:1))
  a$transition <- factor(a$transition)
  if(cohort=='SHARE')a$country <- factor(a$country)
  a
}
cl_run <- function(project,output_base='local_results/research_closeout') {
  # Configure your R library externally before calling this function.
  suppressPackageStartupMessages({library(data.table);library(survey);library(splines)})
  options(survey.lonely.psu='adjust')
  source_path <- file.path(project,'scripts/70_fit_composite_adverse_state_sensitivity_v1_2.R')
  e <- new.env(parent=globalenv())
  cl_functions(source_path,c('category_with_missing','read_interval_data','fit_survivor_retention',
    'build_composite_dataset','make_design','model_formula','contrast_vectors','fit_complete_case_model'),e)
  e$v10_dir <- file.path(project,'data/02_analytic/cpd_multicohort_01/v1.0')
  e$v11_dir <- file.path(project,'data/02_analytic/cpd_multicohort_01/v1.1')
  e$phenotype_levels <- c('neither','cancer_only','pain_only','cancer_and_pain')
  model_dir <- file.path(project,'data/03_outputs/cpd_multicohort_01/models')
  reference_paths <- file.path(model_dir,c('composite_adverse_state_adjusted_risk_ratios_v1.2.csv',
     'composite_share_weight_trim_sensitivity_v1.2.csv'))
  if(!all(file.exists(reference_paths)))stop('REFERENCE_ABSENT')
  refs <- lapply(reference_paths,function(p)as.data.frame(fread(p)))
  inputs <- c(source_path,reference_paths)
  for(cohort in c('SHARE','CHARLS'))for(es in c('onset','persistence')) {
    inputs <- c(inputs,if(es=='onset')file.path(e$v10_dir,paste0(tolower(cohort),'_person_intervals_v1.0.rds'))
      else file.path(e$v11_dir,paste0(tolower(cohort),'_persistence_intervals_v1.1.rds')))
    if(cohort=='CHARLS')inputs <- c(inputs,file.path(model_dir,paste0('charls_composite_',es,'_mice_m20_v1.2.rds')))
  }
  if(!all(file.exists(inputs)))stop('INPUT_ABSENT')
  hashes <- tools::md5sum(inputs)
  dest <- file.path(output_base,paste0('composite_lineage_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(dest))stop('OUTPUT_EXISTS')
  private <- file.path(dest,'LOCAL_ONLY');out <- file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE);dir.create(out)
  log <- file(file.path(private,'private_log.txt'),'wt')
  sink(log);sink(log,type='message')
  on.exit({sink(type='message');sink();close(log)},add=TRUE)
  write.csv(data.frame(file=basename(inputs),md5=unname(hashes)),file.path(out,'input_fingerprints.csv'),row.names=FALSE)
  statuses <- data.frame(job=character(),status=character(),warning_review=character())
  for(es in c('onset','persistence'))for(cohort in c('SHARE','CHARLS')) {
    tag <- paste(tolower(cohort),es,sep='_');warnings <- character()
    sink();cat('Rebuild saved-data lineage: ',tag,'\n',sep='');flush.console();sink(log)
    success <- tryCatch(withCallingHandlers({
      built <- e$build_composite_dataset(cohort,es)
      if(any(built$diagnostics$warning_count>0))warnings <- c(warnings,'RETENTION_MODEL_WARNINGS_REVIEW_PRIVATE_DIAGNOSTICS')
      cl_key(as.data.frame(built$full));cl_key(as.data.frame(built$data))
      saveRDS(built,file.path(private,paste0(tag,'_full_and_analytic_rebuilt.rds')))
      write.csv(as.data.frame(built$diagnostics),file.path(private,paste0(tag,'_retention_diagnostics.csv')),row.names=FALSE)
      if(cohort=='CHARLS') {
        frame <- cl_model_frame(built$data,cohort)
        old <- readRDS(file.path(model_dir,paste0('charls_composite_',es,'_mice_m20_v1.2.rds')))$data
        cmp <- cl_compare_frames(frame,old)
        saveRDS(frame,file.path(private,paste0(tag,'_pre_model_frame.rds')))
        write.csv(cmp,file.path(private,paste0(tag,'_field_comparison.csv')),row.names=FALSE)
        if(!all(cmp$status=='MATCH'))stop('CHARLS_FRAME_MISMATCH')
      } else {
        fits <- e$fit_complete_case_model(built$data,cohort,es)
        cc <- as.data.table(fits$data)
        archive <- refs[[1]][refs[[1]]$cohort==cohort & refs[[1]]$estimand==es,]
        if(!nrow(archive)||any(archive$n_intervals!=nrow(cc))||
          any(archive$n_persons!=uniqueN(cc$person_id))||any(archive$events!=sum(cc$composite_event))||
          !cl_compare_effects(as.data.frame(fits$results),archive))stop('SHARE_REFERENCE_MISMATCH')
        saveRDS(cl_model_frame(cc,cohort),file.path(private,paste0(tag,'_pre_model_frame.rds')))
        d <- copy(built$data)
        d[,c('trim_low','trim_high'):= {q<-quantile(composite_weight,c(.01,.99),names=FALSE);list(q[1],q[2])},by=transition]
        d[,composite_weight_trim99:=pmin(trim_high,pmax(trim_low,composite_weight))]
        d[,composite_weight_trim99_norm:=composite_weight_trim99/mean(composite_weight_trim99),by=transition]
        trim <- e$fit_complete_case_model(d,cohort,es,'composite_weight_trim99_norm')
        a <- refs[[2]][refs[[2]]$cohort==cohort & refs[[2]]$estimand==es,]
        if(!cl_compare_effects(as.data.frame(trim$results),a))stop('SHARE_TRIM_REFERENCE_MISMATCH')
        saveRDS(d,file.path(private,paste0(tag,'_trimmed_weight_analytic.rds')))
        saveRDS(list(untrimmed=fits$results,trimmed=trim$results),file.path(private,paste0(tag,'_effect_reproduction.rds')))
      }
      TRUE
    },warning=function(w){warnings <<- c(warnings,conditionMessage(w));invokeRestart('muffleWarning')}),
    error=function(err){writeLines(conditionMessage(err),file.path(private,paste0(tag,'_error.txt')));FALSE})
    writeLines(unique(warnings),file.path(private,paste0(tag,'_warnings.txt')))
    statuses <- rbind(statuses,data.frame(job=tag,status=if(success)'REBUILT_AND_REFERENCE_MATCHED' else 'FAILED_REVIEW_LOCALLY',
      warning_review=if(length(warnings))'LOCAL_REVIEW_REQUIRED' else 'NO_CAPTURED_WARNINGS'))
    write.csv(statuses,file.path(out,'job_status.csv'),row.names=FALSE)
  }
  if(!identical(hashes,tools::md5sum(inputs)))stop('INPUT_CHANGED')
  artifacts <- list.files(private,pattern='\\.rds$',full.names=TRUE)
  write.csv(data.frame(file=basename(artifacts),md5=unname(tools::md5sum(artifacts))),file.path(out,'saved_artifact_fingerprints.csv'),row.names=FALSE)
  writeLines(c('REBUILD_FINISHED_REQUIRES_REVIEW','No new imputations; originals unchanged.',
    'CHARLS: key-aligned full model frame compared with archived mids$data.',
    'SHARE: complete-case and trimmed-weight effects/sample reproduced; no claim of historical record-by-record identity.'),
    file.path(out,'RUN_STATUS.txt'))
  sink(type='message');sink();close(log);on.exit(NULL)
  cat('Finished. Return SUMMARY_RETURN only: ',out,'\n',sep='')
  invisible(out)
}
