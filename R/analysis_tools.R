# Reusable statistical functions. Supply an authorized, correctly constructed
# survey design; these functions do not acquire or harmonize source records.
cpd_fit_rr <- function(formula, design) {
  fit <- survey::svyglm(formula, design=design, family=quasipoisson('log'))
  if(!isTRUE(fit$converged) || any(!is.finite(coef(fit))) ||
     fit$rank != length(coef(fit)) || fit$df.residual<=0) stop('Invalid RR fit')
  out <- as.data.frame(hrs_contrasts(fit))
  out$dfcom <- fit$df.residual
  out
}

cpd_meta <- function(log_rr, se) {
  if(length(log_rr)<2L || length(log_rr)!=length(se) ||
     any(!is.finite(c(log_rr,se))) || any(se<=0)) stop('Invalid meta-analysis input')
  fit <- metafor::rma.uni(yi=log_rr,sei=se,method='REML',test='knha')
  data.frame(log_rr=as.numeric(fit$b),se=fit$se,rr=exp(as.numeric(fit$b)),
    conf_low=exp(fit$ci.lb),conf_high=exp(fit$ci.ub),tau2=fit$tau2,
    i2=fit$I2,p_value=fit$pval,k=fit$k)
}
