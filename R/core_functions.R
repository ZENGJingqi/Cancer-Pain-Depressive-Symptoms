# Extracted study helpers; source defines functions only.

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

hrs_formula <- function() event ~ phenotype + splines::ns(age,df=3) + female + education3 +
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
