# Safe aggregate-only audit: no individual files, LOCAL_ONLY, or models opened.
src <- 'supporting/hrs_final_core_2026-09-07'
prior <- 'supporting/hrs_prior_mi50'
dest <- 'generated_audit/hrs_final_core_2026-09-07'
dir.create(dest,recursive=TRUE,showWarnings=FALSE)
files <- character()
read_safe <- function(name,root=src) {
  stopifnot(root %in% c(src,prior),basename(name)==name,grepl('[.]csv$',name))
  path <- file.path(root,name);files <<- unique(c(files,path))
  read.csv(path,check.names=FALSE,stringsAsFactors=FALSE)
}
near <- function(a,b) stopifnot(length(a)==length(b),all(is.finite(c(a,b))),
  all(abs(a-b)<=1e-9+1e-8*abs(b)))
split_rhat <- function(x) {
  h <- floor(nrow(x)/2)
  s <- cbind(x[seq_len(h),,drop=FALSE],x[(nrow(x)-h+1):nrow(x),,drop=FALSE])
  w <- mean(apply(s,2,var));b <- h*var(colMeans(s))
  if(!is.finite(w)||w<=0)return(NA_real_)
  sqrt(((h-1)/h*w+b/h)/w)
}
jobs <- read_safe('job_status.csv')
stopifnot(nrow(jobs)==4,!anyDuplicated(jobs$job),all(jobs$status=='COMPLETED_REQUIRES_REVIEW'))
checks <- list(); comparisons <- list(); samples <- list(); diagnostics <- list(); issues <- list()
for(tag in jobs$job) {
  df <- read_safe(paste0(tag,'_model_df.csv'))
  stopifnot(nrow(df)==20,setequal(df$imputation,1:20),!anyDuplicated(df$imputation),
    length(unique(df$dfcom))==1)
  near(df$design_df-df$rank+1,df$dfcom)
  sample <- read_safe(paste0(tag,'_sample.csv'));samples[[tag]] <- sample
  stopifnot(sample$n_intervals>=sample$n_persons,sample$events<=sample$n_intervals)
  for(kind in c('RR','risks','risk_differences')) {
    draw_file <- switch(kind,RR='_per_imputation.csv',risks='_risk_per_imputation.csv',
      risk_differences='_RD_per_imputation.csv')
    group <- if(kind=='risks')'phenotype'else'contrast'
    draws <- read_safe(paste0(tag,draw_file));pooled <- read_safe(paste0(tag,'_',kind,'.csv'))
    stopifnot(nrow(pooled)==if(kind=='risks')4L else 5L,!anyDuplicated(pooled[[group]]),
      setequal(draws[[group]],pooled[[group]]))
    for(i in seq_len(nrow(pooled))) {
      r <- pooled[i,];a <- draws[draws[[group]]==r[[group]],]
      stopifnot(nrow(a)==20,!anyDuplicated(a$imputation),setequal(a$imputation,1:20))
      q <- if(kind=='RR')a$log_rr else a$estimate;u <- a$variance
      stopifnot(all(is.finite(c(q,u))),all(u>0))
      mu <- mean(q);w <- mean(u);b <- var(q);t <- w+1.05*b;se <- sqrt(t)
      lambda <- 1.05*b/t;obsdf <- (df$dfcom[1]+1)/(df$dfcom[1]+3)*df$dfcom[1]*(1-lambda)
      pooled_df <- 19*obsdf/(19+lambda^2*obsdf)
      limits <- mu+c(-1,1)*qt(.975,pooled_df)*se
      if(kind=='RR') {near(exp(mu),r$rr);limits <- exp(limits)}
      near(c(mu,se,w,b,sqrt(b/20),pooled_df,df$dfcom[1],20,limits),
        c(r$estimate,r$se,r$within_variance,r$between_variance,r$mcse,r$df,r$dfcom,r$m,r$conf_low,r$conf_high))
      checks[[length(checks)+1L]] <- data.frame(job=tag,type=kind,term=r[[group]],
        mcse_se=r$mcse/r$se,arithmetic='PASS')
    }
  }
  new <- read_safe(paste0(tag,'_RR.csv'))
  oldtag <- switch(tag,onset_symptoms='hrs_onset',persistence_symptoms='hrs_persistence',
    onset_composite='hrs_composite_onset',persistence_composite='hrs_composite_persistence')
  old <- read_safe(paste0(oldtag,'_extended_RR.csv'),prior)
  stopifnot(!anyDuplicated(old$contrast),setequal(new$contrast,old$contrast))
  old <- old[match(new$contrast,old$contrast),]
  comparisons[[tag]] <- data.frame(job=tag,contrast=new$contrast,old_rr=old$rr,new_rr=new$rr,
    new_low=new$conf_low,new_high=new$conf_high,relative_change_pct=100*(new$rr/old$rr-1),
    old_ci_contains_one=old$conf_low<=1&old$conf_high>=1,
    new_ci_contains_one=new$conf_low<=1&new$conf_high>=1)
  # Do not release small differences between old/new sample counts.
  sample$matches_prior_intervals <- all(sample$n_intervals==old$n_intervals)
  sample$matches_prior_persons <- all(sample$n_persons==old$n_persons)
  sample$matches_prior_events <- all(sample$events==old$events)
  samples[[tag]] <- sample
  status <- read_safe(paste0(tag,'_status.csv'))
  stopifnot(status$m==20,status$iterations==50)
  distribution <- read_safe(paste0(tag,'_distribution_checks.csv'))
  stopifnot(all(distribution$observed_values_unchanged),all(distribution$imputed_values_complete))
  issues[[tag]] <- data.frame(job=tag,logged_event_count=status$logged_event_count,
    suppressed_distributions=paste(distribution$variable[!distribution$distribution_exported],collapse=';'))
  late <- read_safe(paste0(tag,'_late_chain_diagnostics.csv'))
  for(parameter in c('chainMean','chainVar')) {
    a <- read_safe(paste0(tag,'_',parameter,'.csv'))
    for(v in unique(a$variable)) {
      z <- a[a$variable==v,];z$iteration<-as.integer(z$iteration)
      stopifnot(nrow(z)==1000,!anyDuplicated(z[c('iteration','chain')]),
        setequal(z$iteration,1:50),length(unique(z$chain))==20)
      x <- sapply(sort(unique(z$chain)),function(ch) {
        zz <- z[z$chain==ch,];zz$value[order(zz$iteration)]
      })
      if(parameter=='chainVar')x <- sqrt(x)
      for(n in c(20L,30L,50L)) {
        rh <- split_rhat(tail(x,n))
        if(n<50) {
          r <- late[late$variable==v&late$parameter==parameter&late$last_iterations==n,]
          stopifnot(nrow(r)==1)
          if(is.finite(rh))near(rh,r$split_rhat_classic)else stopifnot(is.na(r$split_rhat_classic))
        }
        diagnostics[[length(diagnostics)+1L]] <- data.frame(job=tag,variable=v,parameter=parameter,
          last_iterations=n,split_rhat_classic=rh)
      }
    }
  }
  name <- paste0(tag,'_distribution_percent.csv')
  if(file.exists(file.path(src,name))) {
    d <- read_safe(name)
    sums <- aggregate(d[c('observed_percent','imputed_percent')],d[c('variable','imputation')],sum)
    near(sums$observed_percent,rep(100,nrow(sums)));near(sums$imputed_percent,rep(100,nrow(sums)))
  }
}
input <- read_safe('input_hashes.csv')
stopifnot(input$sha256[input$source=='core']=='9048917506a4143ac53c11ccee2a6929e6885bb0df48ec2e81a446e919c816ff')
read_safe('code_hashes.csv')
checks <- do.call(rbind,checks);comparison <- do.call(rbind,comparisons)
diag <- do.call(rbind,diagnostics);sample <- do.call(rbind,samples);issue <- do.call(rbind,issues)
write.csv(checks,file.path(dest,'pooling_checks.csv'),row.names=FALSE)
write.csv(comparison,file.path(dest,'old_new_RR_comparison.csv'),row.names=FALSE)
write.csv(diag,file.path(dest,'independent_chain_diagnostics.csv'),row.names=FALSE)
write.csv(sample,file.path(dest,'sample_review.csv'),row.names=FALSE)
write.csv(issue,file.path(dest,'remaining_local_diagnostics.csv'),row.names=FALSE)
write.csv(data.frame(path=files,md5=unname(tools::md5sum(files))),file.path(dest,'summary_input_manifest.csv'),row.names=FALSE)
text <- c('SAFE AGGREGATE ARITHMETIC AUDIT PASS; NOT WHOLE-PAPER CLOSURE',
  paste('Pooled RR/risk/RD rows independently verified:',nrow(checks)),
  paste('Classic split R-hat rows:',nrow(diag)),
  paste('Maximum MCSE/SE:',max(checks$mcse_se)),
  paste('Maximum classic split R-hat:',max(diag$split_rhat_classic,na.rm=TRUE)),
  paste('Maximum absolute RR relative change, percent:',max(abs(comparison$relative_change_pct))),
  paste('CI inclusion changes:',sum(comparison$old_ci_contains_one!=comparison$new_ci_contains_one)),
  'Old/new contrast includes rerandomized MI and finite-df change, not isolated source-version effect.',
  'Suppressed distributions, private prediction QA and warnings not reviewed here.',
  'No individual records or LOCAL_ONLY objects read. No manuscript/GitHub update.')
writeLines(text,file.path(dest,'AUDIT_STATUS.txt'));cat(paste(text,collapse='\n'),'\n')
print(sample);print(issue)
print(comparison[comparison$contrast=='pain_only_vs_cancer_only',])
