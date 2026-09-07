# Human-operated local diagnostics only. Sourcing defines functions, reads no data.
# Do not run real records through an AI-connected execution tool.
rel_require <- function() {
  needed <- c('mice','data.table','haven','digest')
  missing <- needed[!vapply(needed,requireNamespace,logical(1),quietly=TRUE)]
  if(length(missing)) stop('Missing packages: ',paste(missing,collapse=', '))
}
rel_vars <- c('education3','partnered','current_smoking','wealth_quintile','noncancer_comorbidity_count')
rel_write <- function(x,path) utils::write.csv(x,path,row.names=FALSE,na='')
rel_hash <- function(p) digest::digest(file=p,algo='sha256')
rel_safe_n <- function(n) ifelse(n>0 & n<20,'<20',as.character(n))
rel_group_safe <- function(d,mask) {
  mask <- mask & !is.na(mask)
  sum(mask)>=20 && 'person_id'%in%names(d) && length(unique(d$person_id[mask]))>=20
}
rel_split_rhat <- function(x) {
  # Classical split-chain variance-ratio diagnostic, not rank-normalised R-hat.
  x<-as.matrix(x);n<-floor(nrow(x)/2)
  if(n<2 || ncol(x)<2 || any(!is.finite(x)))return(NA_real_)
  s<-cbind(x[seq_len(n),,drop=FALSE],x[(nrow(x)-n+1):nrow(x),,drop=FALSE])
  w<-mean(apply(s,2,var));b<-n*var(colMeans(s))
  if(!is.finite(w)||w<=0)return(NA_real_)
  sqrt(((n-1)/n*w+b/n)/w)
}

rel_mi_report <- function(imp,tag,private,out) {
  if(!inherits(imp,'mids') || imp$m<2) stop('Expected mids with at least two imputations')
  d <- imp$data
  if(!all(c('person_id','transition')%in%names(d))) stop('MI keys absent')
  if(anyNA(d[c('person_id','transition')]) || anyDuplicated(d[c('person_id','transition')])) stop('Invalid MI keys')
  variables <- intersect(rel_vars,names(d))
  active <- variables[vapply(variables,function(v) any(imp$where[,v]),logical(1))]
  unexpected <- setdiff(names(imp$method)[nzchar(imp$method)],rel_vars)
  if(length(unexpected)) stop('Unexpected active imputation variable; requires local review')
  missing <- data.frame(variable=variables,missing_n=vapply(d[variables],function(x) sum(is.na(x)),numeric(1)),
                        m=imp$m,iterations=imp$iteration,method=unname(imp$method[variables]))
  missing$missing_n <- rel_safe_n(missing$missing_n)
  rel_write(missing,file.path(out,paste0(tag,'_missingness.csv')))
  rows <- list(); checks <- list()
  for(v in active) {
    if(!all(imp$where[,v]==is.na(d[[v]]))) stop('Nonstandard overimputation requires explicit review')
    obs <- !is.na(d[[v]]); mis <- !obs
    safe <- rel_group_safe(d,obs)&&rel_group_safe(d,mis)
    # Suppress the whole distribution if any category has a small positive cell.
    # Pooling draws would create misleadingly large counts; use each draw separately.
    counts <- lapply(seq_len(imp$m),function(j) {
      z <- mice::complete(imp,j)[[v]]
      if(anyNA(z[mis])) stop('Residual imputed missing values')
      if(any(!is.finite(as.numeric(z[mis])))) stop('Nonfinite imputation')
      if(!identical(as.character(z[obs]),as.character(d[[v]][obs]))) stop('Observed values changed')
      a <- as.character(z[mis]); b <- as.character(d[[v]][obs])
      lev <- sort(unique(c(a,b)))
      ca <- table(factor(a,levels=lev)); cb <- table(factor(b,levels=lev))
      # Unique-person minimum in each displayed category as well as row counts.
      small <- any(c(ca,cb)>0 & c(ca,cb)<20)
      small <- small || any(vapply(lev,function(k) {
        na <- length(unique(d$person_id[mis][a==k])); nb <- length(unique(d$person_id[obs][b==k]))
        (na>0&&na<20)||(nb>0&&nb<20)
      },logical(1)))
      data.frame(variable=v,imputation=j,category=lev,
        observed_percent=100*as.numeric(cb)/sum(cb),imputed_percent=100*as.numeric(ca)/sum(ca),small=small)
    })
    tab <- do.call(rbind,counts)
    # Full distribution remains private even when safe aggregates can be returned.
    rel_write(tab,file.path(private,paste0(tag,'_',v,'_distribution.csv')))
    publish <- safe && !any(tab$small) && length(unique(tab$category))<=20
    if(publish) rows[[v]] <- tab[setdiff(names(tab),'small')]
    checks[[v]] <- data.frame(variable=v,distribution_exported=publish,
      reason=if(publish)'AGGREGATE_ONLY' else 'SUPPRESSED_REVIEW_LOCALLY',observed_values_unchanged=TRUE,
      imputed_values_complete=TRUE)
  }
  if(length(rows)) rel_write(do.call(rbind,rows),file.path(out,paste0(tag,'_distribution_percent.csv')))
  if(length(checks)) rel_write(do.call(rbind,checks),file.path(out,paste0(tag,'_distribution_checks.csv')))
  # Base-R fallback avoids an undeclared rstan dependency in mice::convergence.
  # Never label this classical diagnostic as rank-normalised R-hat or proof of convergence.
  for(parameter in c('mean','sd')) {
    arr<-if(parameter=='mean')imp$chainMean else sqrt(imp$chainVar)
    cr<-list()
    for(v in intersect(active,dimnames(arr)[[1]])) {
      x<-matrix(arr[v,,],nrow=dim(arr)[2],ncol=dim(arr)[3])
      for(it in seq_len(nrow(x))) {
        z<-x[seq_len(it),,drop=FALSE]
        ac<-if(it<3)NA_real_ else mean(vapply(seq_len(ncol(z)),function(j) {
          a<-z[-nrow(z),j];b<-z[-1,j]
          if(any(!is.finite(c(a,b)))||sd(a)==0||sd(b)==0)NA_real_ else cor(a,b)
        },numeric(1)),na.rm=TRUE)
        cr[[length(cr)+1]]<-data.frame(vrb=v,.it=it,ac=ac,split_rhat_classic=rel_split_rhat(z))
      }
    }
    conv<-if(length(cr))do.call(rbind,cr)else data.frame(vrb=character(),.it=integer(),ac=numeric(),split_rhat_classic=numeric())
    rel_write(conv,file.path(private,paste0(tag,'_',parameter,'_convergence.csv')))
    safe_vars <- active[vapply(active,function(v) rel_group_safe(d,is.na(d[[v]])),logical(1))]
    conv <- conv[as.character(conv$vrb)%in%safe_vars,,drop=FALSE]
    rel_write(conv,file.path(out,paste0(tag,'_',parameter,'_convergence.csv')))
  }
  # Chain coordinates for active variables with sufficient missing-person support only.
  for(stat in c('chainMean','chainVar')) {
    a <- imp[[stat]]
    if(is.null(a)) next
    t <- as.data.frame(as.table(a));names(t)<-c('variable','iteration','chain','value')
    safe_vars <- active[vapply(active,function(v) rel_group_safe(d,is.na(d[[v]])),logical(1))]
    t <- t[as.character(t$variable)%in%safe_vars & is.finite(t$value),]
    rel_write(t,file.path(out,paste0(tag,'_',stat,'.csv')))
  }
  events <- if(is.null(imp$loggedEvents))0L else nrow(imp$loggedEvents)
  rel_write(data.frame(tag=tag,m=imp$m,iterations=imp$iteration,logged_event_count=rel_safe_n(events),
    status='DIAGNOSTICS_EXPORTED_NOT_CONVERGENCE_PASS'),file.path(out,paste0(tag,'_status.csv')))
}

rel_design_link <- function(d,modules,tag,private,out) {
  d <- as.data.frame(d)
  needed <- c('person_id','transition','wave','country','analysis_weight_norm','phenotype','age','female')
  if(!all(needed%in%names(d))) stop('SHARE analytic schema mismatch')
  if(anyNA(d[c('person_id','transition')])||anyDuplicated(d[c('person_id','transition')])) stop('Duplicate analytic key')
  if(!all(d$wave%in%c(5,8))) stop('Nonprimary SHARE wave found')
  if(any(!is.finite(d$analysis_weight_norm)|d$analysis_weight_norm<=0))stop('Invalid analytic weights')
  fields <- c('subsample','stratum1','psu')
  for(f in fields)d[[paste0('official_',f)]]<-NA_character_
  d$official_matched<-FALSE
  for(w in unique(d$wave)) {
    mod <- modules[[as.character(w)]]
    if(anyNA(mod$mergeid)||anyDuplicated(mod$mergeid))stop('Invalid official key')
    idx<-which(d$wave==w); k<-match(as.character(d$person_id[idx]),as.character(mod$mergeid))
    matched<-!is.na(k)
    if(any(as.character(d$country[idx][matched])!=as.character(mod$country[k[matched]])))stop('Country mismatch')
    d$official_matched[idx]<-matched
    for(f in fields)d[[paste0('official_',f)]][idx]<-as.character(mod[[f]][k])
  }
  usable<-function(x)!is.na(x)&nzchar(trimws(x))&!grepl('^-|^0+([.]0+)?$',x)
  d$candidate_complete<-d$official_matched
  for(f in fields)d$candidate_complete<-d$candidate_complete&usable(d[[paste0('official_',f)]])
  # Private stable-key evidence, not a national-design decision.
  key<-paste(d$country,d$official_subsample,d$official_stratum1,d$official_psu,sep='|')
  groups<-split(seq_len(nrow(d)),d$person_id)
  conflicting<-vapply(groups,function(i) length(unique(key[i][d$candidate_complete[i]]))>1,logical(1))
  d$cross_interval_conflict<-unname(conflicting[as.character(d$person_id)])
  saveRDS(d,file.path(private,paste0(tag,'_design_linked_candidate.rds')))
  report<-lapply(split(seq_len(nrow(d)),interaction(d$country,d$wave,drop=TRUE)),function(i) {
    z<-d[i,,drop=FALSE]
    if(length(unique(z$person_id))<100)return(NULL)
    # Suppress all coverage counts/rates together if a small cell could be derived.
    state<-ifelse(!z$official_matched,'unmatched',ifelse(z$candidate_complete,'candidate_complete','unresolved'))
    cells<-table(factor(state,levels=c('unmatched','candidate_complete','unresolved')))
    safe<-all(cells==0|cells>=20)
    data.frame(estimand=tag,country=z$country[1],baseline_wave=z$wave[1],
      n_intervals=if(safe)as.character(nrow(z))else'SUPPRESSED',
      matched=if(safe)as.character(sum(z$official_matched))else'SUPPRESSED',
      candidate_complete=if(safe)as.character(sum(z$candidate_complete))else'SUPPRESSED',
      candidate_weight_percent=if(safe)100*sum(z$analysis_weight_norm[z$candidate_complete])/sum(z$analysis_weight_norm)else NA,
      cross_interval_conflicts=rel_safe_n(sum(z$cross_interval_conflict)),
      status='CANDIDATE_COVERAGE_NOT_APPROVED_DESIGN')
  })
  rel_write(do.call(rbind,report),file.path(out,paste0(tag,'_design_coverage.csv')))
  # Country/subsample raw design values stay private; do not return codes.
  private_rules<-unique(d[c('country','wave','official_subsample')])
  private_rules$verified_rule<-'UNRESOLVED';private_rules$source_reference<-''
  rel_write(private_rules,file.path(private,paste0(tag,'_design_rules_to_verify.csv')))
}

reliability_run <- function(project,output_base='D:/Reliability_local_results') {
  rel_require()
  dest<-file.path(output_base,format(Sys.time(),'%Y%m%d_%H%M%S'))
  if(dir.exists(dest))stop('Output already exists')
  private<-file.path(dest,'LOCAL_ONLY');out<-file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE);dir.create(out)
  cat('Output folder: ',dest,'\n',sep='')
  finished<-FALSE
  on.exit(if(!finished)writeLines(c('STOPPED_NOT_COMPLETE','Return only job_status.csv or RUN_STATUS.txt if present; never private logs.'),file.path(out,'RUN_STATUS.txt')),add=TRUE)
  log<-file(file.path(private,'private_log.txt'),'wt')
  sink(log);sink(log,type='message')
  on.exit({sink(type='message');sink();close(log)},add=TRUE)
  modeldir<-file.path(project,'data/03_outputs/cpd_multicohort_01/models')
  mapping<-c(hrs_onset='hrs_mice_m20_v1.0.rds',hrs_persistence='hrs_persistence_mice_m20_v1.1.rds',
    share_persistence='share_persistence_mice_m20_v1.1.rds',charls_onset='charls_mice_m20_v1.0.rds',
    charls_persistence='charls_persistence_mice_m20_v1.1.rds',
    charls_composite_onset='charls_composite_onset_mice_m20_v1.2.rds',
    charls_composite_persistence='charls_composite_persistence_mice_m20_v1.2.rds')
  paths<-setNames(file.path(modeldir,mapping),names(mapping))
  hrs_private<-'D:/HRS_local_results/20260905_200545/LOCAL_ONLY'
  paths<-c(paths,hrs_composite_onset=file.path(hrs_private,'onset_composite_mids.rds'),
    hrs_composite_persistence=file.path(hrs_private,'persistence_composite_mids.rds'))
  if(!all(file.exists(paths)))stop('Required saved MI object missing; see private log')
  manifest<-data.frame(tag=names(paths),file=basename(paths),sha256=vapply(paths,rel_hash,character(1)))
  jobs<-list()
  for(tag in names(paths)) {
    message('Diagnostics: ',tag)
    result<-tryCatch({rel_mi_report(readRDS(paths[[tag]]),tag,private,out);'EXPORTED'},
      error=function(e){message(conditionMessage(e));'FAILED_REVIEW_PRIVATE_LOG_LOCALLY'})
    jobs[[tag]]<-data.frame(job=tag,status=result)
    gc()
  }
  # Reuse the already extracted official modules from successful V2 preflight.
  module_root<-'D:/SHARE_local_results/design_preflight_20260905_212750/LOCAL_ONLY'
  modules<-list()
  for(w in c(5,8)) {
    p<-list.files(file.path(module_root,paste0('wave',w)),pattern='gv_weights[.]dta$',recursive=TRUE,full.names=TRUE)
    if(length(p)!=1)stop('Expected one previously extracted weight module')
    modules[[as.character(w)]]<-as.data.frame(haven::read_dta(p,col_select=c('mergeid','country','subsample','stratum1','psu')))
    manifest<-rbind(manifest,data.frame(tag=paste0('official_wave',w),file=basename(p),sha256=rel_hash(p)))
  }
  for(es in c('onset','persistence')) {
    ver<-if(es=='onset')'v1.0'else'v1.1'
    file<-if(es=='onset')'share_person_intervals_v1.0.rds'else'share_persistence_intervals_v1.1.rds'
    p<-file.path(project,'data/02_analytic/cpd_multicohort_01',ver,file)
    manifest<-rbind(manifest,data.frame(tag=paste0('share_',es,'_analytic'),file=file,sha256=rel_hash(p)))
    d<-as.data.frame(readRDS(p));d<-d[d$analysis_eligible%in%TRUE,,drop=FALSE]
    if(es=='onset') {
      vars<-c('age','female','education3','partnered','depressive_score','noncancer_comorbidity_count','current_smoking','wealth_quintile')
      d<-d[complete.cases(d[vars]),,drop=FALSE]
    } else {
      imp<-readRDS(paths[['share_persistence']])
      key<-function(z)paste(z$person_id,z$transition,sep='|')
      k<-match(key(imp$data),key(d))
      if(anyNA(k)||anyDuplicated(k)||nrow(d)!=nrow(imp$data))stop('SHARE MI sample mismatch')
      d<-d[k,,drop=FALSE]
      for(v in c('event','phenotype','analysis_weight_norm')) {
        a<-d[[v]];b<-imp$data[[v]]
        if(v=='event') {a<-as.numeric(a);b<-as.numeric(b)}
        if(!isTRUE(all.equal(as.character(a),as.character(b))))stop('SHARE MI fixed field mismatch')
      }
    }
    rel_design_link(d,modules,es,private,out)
    jobs[[paste0('share_',es,'_coverage')]]<-data.frame(job=paste0('share_',es,'_coverage'),status='EXPORTED_NOT_MODELLED')
  }
  # The saved CHARLS composite mids$data is its exact pre-imputation model frame.
  # Preserve it privately without claiming an independently reconstructed risk set.
  for(es in c('onset','persistence')) {
    imp<-readRDS(paths[[paste0('charls_composite_',es)]])
    saveRDS(imp$data,file.path(private,paste0('charls_composite_',es,'_saved_model_frame.rds')))
  }
  stopifnot(identical(unname(vapply(paths,rel_hash,character(1))),unname(manifest$sha256[seq_along(paths)])))
  rel_write(manifest,file.path(out,'input_hashes.csv'))
  rel_write(do.call(rbind,jobs),file.path(out,'job_status.csv'))
  capture.output(sessionInfo(),file=file.path(private,'session_info.txt'))
  status<-if(any(vapply(jobs,function(x)grepl('FAILED',x$status),logical(1))))'PARTIAL_DIAGNOSTICS'else'DIAGNOSTICS_EXPORTED'
  writeLines(c(status,'NOT_CONVERGENCE_PASS; NOT_OFFICIAL_DESIGN_MODEL',
    'No source object overwritten. No new imputations or model fitting.',
    'Some distributions may be suppressed and require independent local review.',
    'Only return SUMMARY_RETURN. Never send LOCAL_ONLY or private logs.'),file.path(out,'RUN_STATUS.txt'))
  finished<-TRUE
  invisible(out)
}
