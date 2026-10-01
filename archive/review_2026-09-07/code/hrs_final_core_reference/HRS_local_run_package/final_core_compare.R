# Functions only. Real data are handled by the researcher in a separate local run.
hc_id <- function(hhid,pn) {
  if(anyNA(hhid)||anyNA(pn)||any(!grepl('^[0-9]{1,6}$',hhid))||any(!grepl('^[0-9]{1,3}$',pn)))stop('Invalid identifier')
  paste0(sprintf('%06d',as.integer(hhid)),sprintf('%03d',as.integer(pn)))
}
hc_values <- function(x) {
  if(inherits(x,'haven_labelled'))x<-haven::zap_labels(x)
  y<-trimws(as.character(x));y[y%in%c('', '.', 'NA')]<-NA_character_
  # Preserve special missing codes as distinct strings; never coerce them to zero.
  numeric<-!is.na(y)&grepl('^-?[0-9]+([.][0-9]+)?$',y)
  y[numeric]<-vapply(as.numeric(y[numeric]),function(v)format(v,scientific=FALSE,trim=TRUE,digits=15),character(1))
  y
}
hc_compare <- function(old,new,vars) {
  if(anyNA(old$id)||anyNA(new$id)||anyDuplicated(old$id)||anyDuplicated(new$id))stop('Invalid unique key')
  common<-intersect(old$id,new$id);a<-match(common,old$id);b<-match(common,new$id)
  if(!length(common))stop('No common identifiers')
  rows<-lapply(vars,function(v) {
    if(!v%in%names(old)||!v%in%names(new))stop('Required field absent')
    x<-hc_values(old[[v]][a]);y<-hc_values(new[[v]][b])
    equal<-(is.na(x)&is.na(y))|(!is.na(x)&!is.na(y)&x==y)
    cells<-c(same=sum(equal),changed=sum(!equal),old_only=sum(!old$id%in%new$id),new_only=sum(!new$id%in%old$id))
    safe<-all(cells==0|cells>=20)&&length(common)>=100
    data.frame(variable=v,counts_released=safe,
      common=if(safe)as.character(length(common))else'SUPPRESSED',
      same=if(safe)as.character(cells['same'])else'SUPPRESSED',
      changed=if(safe)as.character(cells['changed'])else'SUPPRESSED',
      old_only=if(safe)as.character(cells['old_only'])else'SUPPRESSED',
      new_only=if(safe)as.character(cells['new_only'])else'SUPPRESSED',
      status='RAW_FIELD_COMPARISON_NOT_UPGRADE_APPROVAL',row.names=NULL)
  })
  do.call(rbind,rows)
}
hc_read_module <- function(path,vars) {
  d<-read.csv(path,colClasses='character',check.names=FALSE,na.strings=c('','NA'))
  names(d)<-toupper(names(d))
  if(anyDuplicated(names(d))||!all(c('HHID','PN',vars)%in%names(d)))stop('Final schema requires mapping review')
  d$id<-hc_id(d$HHID,d$PN)
  if(anyDuplicated(d$id))stop('Duplicate module ID')
  d[c('id',vars)]
}
hc_cesd <- function(d) {
  neg<-paste0('SD',c(110,111,112,114,116,117));pos<-paste0('SD',c(113,115))
  x<-as.data.frame(lapply(d[c(neg,pos)],hc_values),stringsAsFactors=FALSE)
  valid<-Reduce(`&`,lapply(x,function(z)!is.na(z)&z%in%c('1','5')))
  score<-rowSums(x[neg]=='1',na.rm=TRUE)+rowSums(x[pos]=='5',na.rm=TRUE)
  score[!valid]<-NA_real_
  data.frame(id=d$id,raw_cesd8=score,raw_cesd8_ge4=ifelse(is.na(score),NA,as.integer(score>=4)))
}
hc_run <- function(project,output_base='D:/HRS_local_results') {
  for(pkg in c('haven','digest'))if(!requireNamespace(pkg,quietly=TRUE))stop('Required package absent')
  dest<-file.path(output_base,paste0('final_core_compare_',format(Sys.time(),'%Y%m%d_%H%M%S')))
  if(dir.exists(dest))stop('Output exists')
  private<-file.path(dest,'LOCAL_ONLY');out<-file.path(dest,'SUMMARY_RETURN')
  dir.create(private,recursive=TRUE);dir.create(out)
  cat('Output: ',dest,'\n',sep='');flush.console()
  writeLines('RUNNING',file.path(out,'RUN_STATUS.txt'))
  log<-file(file.path(private,'private_log.txt'),'wt');success<-FALSE
  on.exit({
    if(sink.number(type='message')!=2)sink(type='message')
    if(sink.number()>0)sink()
    close(log)
    if(!success)writeLines('FAILED_REVIEW_LOCALLY_NO_PRIVATE_LOG_UPLOAD',file.path(out,'RUN_STATUS.txt'))
  },add=TRUE)
  sink(log);sink(log,type='message')
  stage<-'VERIFY_ARCHIVE'
  progress<-function(label) {
    writeLines(label,file.path(out,'CURRENT_STAGE.txt'))
  }
  progress(stage)
  zip<-file.path(project,'原始数据总库/HRS_2022/官方更新_2022_Core_Final_V2.0/h22core.zip')
  expected<-'9048917506a4143ac53c11ccee2a6929e6885bb0df48ec2e81a446e919c816ff'
  if(digest::digest(file=zip,algo='sha256')!=expected)stop('Core ZIP differs from archived source')
  # Explicit member allowlist; no arbitrary archive path extraction.
  unzip(zip,files='H22csv.zip',exdir=private)
  nested<-file.path(private,'H22csv.zip')
  files<-c('h22a_r.csv','h22c_r.csv','h22d_r.csv')
  unzip(nested,files=files,exdir=private)
  mapping<-list(h22a_r.csv=c('SA009','SA019'),h22c_r.csv=c('SC018','SC104'),
    h22d_r.csv=paste0('SD',110:117))
  tables<-list()
  for(f in files) {
    progress(paste0('READ_FINAL_',f))
    tables[[f]]<-hc_read_module(file.path(private,f),mapping[[f]])
  }
  oldpath<-file.path(project,'原始数据总库/HRS_2022/raw/fat2022/h22e3a.sas7bdat')
  vars<-unlist(mapping,use.names=FALSE)
  progress('READ_OLD_CORE')
  oldhash<-digest::digest(file=oldpath,algo='sha256')
  old<-as.data.frame(haven::read_sas(oldpath,col_select=tidyselect::all_of(c('RAHHIDPN',vars))))
  rid<-as.numeric(old$RAHHIDPN)
  if(anyNA(rid)||any(rid!=floor(rid))||any(rid<0|rid>999999999))stop('Old identifier invalid')
  old$id<-sprintf('%09.0f',rid)
  progress('COMPARE_COMMON_IDENTIFIERS_AND_RAW_FIELDS')
  answer<-do.call(rbind,lapply(files,function(f)hc_compare(old,tables[[f]],mapping[[f]])))
  write.csv(answer,file.path(out,'raw_core_field_comparison.csv'),row.names=FALSE)
  oldscore<-hc_cesd(old);newscore<-hc_cesd(tables[['h22d_r.csv']])
  write.csv(hc_compare(oldscore,newscore,c('raw_cesd8','raw_cesd8_ge4')),
    file.path(out,'raw_cesd_comparison.csv'),row.names=FALSE)
  saveRDS(newscore,file.path(private,'final_raw_cesd_candidate.rds'))
  # Keep raw module subsets private; not a full standardized analysis product.
  saveRDS(tables,file.path(private,'final_raw_core_subsets.rds'))
  paths<-c(zip,oldpath,file.path(project,'HRS_local_run_package/final_core_compare.R'))
  write.csv(data.frame(file=basename(paths),sha256=vapply(paths,function(p)digest::digest(file=p,algo='sha256'),character(1))),
    file.path(out,'input_code_hashes.csv'),row.names=FALSE)
  capture.output(sessionInfo(),file=file.path(private,'session_info.txt'))
  if(digest::digest(file=zip,algo='sha256')!=expected||digest::digest(file=oldpath,algo='sha256')!=oldhash)stop('Source changed during run')
  writeLines(c('CORE_FIELD_COMPARISON_EXPORTED_NOT_UPGRADE_APPROVED',
    'No effect models, no old files overwritten. Counts may be suppressed.',
    'RAND-derived cancer/CESD, weights, death tracking and all downstream analyses remain separate.'),file.path(out,'RUN_STATUS.txt'))
  success<-TRUE;sink(type='message');sink()
  progress('COMPLETE_REVIEW_REQUIRED')
  cat('Finished. Return SUMMARY_RETURN only: ',out,'\n',sep='')
}
