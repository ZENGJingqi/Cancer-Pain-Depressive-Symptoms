# Publication figure revision using only previously exported aggregate rows.
# Configure packages in your R library before sourcing.
suppressPackageStartupMessages({library(data.table);library(ggplot2);library(ggsci)})
base <- getOption('cpd.figure.output','generated_publication_figures')
prior <- getOption('cpd.S4.rows','current/figure_data/FigureS4_display_rows.csv')
out <- file.path(base,'FigureS4')
qa <- file.path(base,'source_and_checks')
dir.create(out,recursive=TRUE,showWarnings=FALSE);dir.create(qa,recursive=TRUE,showWarnings=FALSE)
d <- fread(prior); stopifnot(nrow(d)==15)
nejm <- ggsci::pal_nejm()(8)
settings <- c('Primary\n(MI)','Complete\ncase','First eligible\ninterval','Reduced\ncovariates','Trimmed\nweights')
d[,x:=match(setting,settings)]; d[,y:=4-match(cohort,c('HRS','SHARE','CHARLS'))]
stopifnot(!anyNA(d$x),!anyDuplicated(d[,.(x,y)]),all(d$conf_low<=d$rr),all(d$conf_high>=d$rr))
# Identical mini-forest scale in every cell: RR 0.75 to 1.45, logarithmic.
offset <- function(rr) -.34 + .68*(log(rr)-log(.75))/(log(1.45)-log(.75))
stopifnot(all(d$conf_low>=.75),all(d$conf_high<=1.45))
d[,`:=`(point=x+offset(rr),lo=x+offset(conf_low),hi=x+offset(conf_high),null=x+offset(1))]
p <- ggplot(d,aes(x,y))+
 geom_tile(aes(fill=rr),width=.94,height=.94,colour=NA)+
 geom_segment(aes(x=null,xend=null,y=y-.16,yend=y+.06),colour='#8D969A',linewidth=.3,linetype=2)+
 geom_segment(aes(x=lo,xend=hi,y=y-.04,yend=y-.04),colour=nejm[2],linewidth=.7)+
 geom_segment(aes(x=lo,xend=lo,y=y-.09,yend=y+.01),colour=nejm[2],linewidth=.5)+
 geom_segment(aes(x=hi,xend=hi,y=y-.09,yend=y+.01),colour=nejm[2],linewidth=.5)+
 geom_point(aes(x=point,y=y-.04),colour=nejm[2],size=2.1)+
 geom_text(aes(y=y+.25,label=sprintf('%.2f',rr)),family='Arial',size=12/ggplot2::.pt,fontface='bold',colour='black')+
 geom_text(aes(y=y-.30,label=sprintf('(%.2f-%.2f)',conf_low,conf_high)),family='Arial',size=10/ggplot2::.pt,colour='black')+
 scale_fill_gradient(low='#FCFDFE',high=colorspace::lighten(nejm[2],amount=.85),limits=c(1,1.3),
  breaks=c(1,1.1,1.2,1.3),name='Adjusted RR',na.value='#EEEEEE')+
 scale_x_continuous(breaks=1:5,labels=settings,limits=c(.47,5.53),position='top',expand=c(0,0))+
 scale_y_continuous(breaks=1:3,labels=c('CHARLS','SHARE','HRS'),limits=c(.47,3.53),expand=c(0,0))+
 guides(fill=guide_colourbar(title.position='top',title.hjust=.5,barwidth=unit(2.8,'in'),barheight=unit(.10,'in')))+
 labs(x=NULL,y=NULL)+theme_void(base_family='Arial',base_size=10)+
 theme(text=element_text(colour='black'),axis.text.x=element_text(size=10,colour='black',lineheight=1.1,margin=margin(b=10)),
  axis.text.y=element_text(size=11,colour='black',face='bold',margin=margin(r=9)),
  legend.position='top',legend.title=element_text(size=10),legend.text=element_text(size=10),
  legend.margin=margin(b=9),plot.margin=margin(10,10,10,10),
  plot.title=element_blank(),plot.subtitle=element_blank(),plot.caption=element_blank())
pdf <- file.path(out,'FigureS4_persistence_robustness.pdf')
ggsave(pdf,p,width=6.6,height=4.1,device=cairo_pdf,bg='white')
png <- pdftools::pdf_convert(pdf,format='png',pages=1,dpi=300,
 filenames=file.path(out,'FigureS4_persistence_robustness_p%d.%s'),verbose=FALSE)
stopifnot(file.rename(png,file.path(out,'FigureS4_persistence_robustness.png')))
ff <- pdftools::pdf_fonts(pdf);stopifnot(all(grepl('Arial',ff$name)),all(ff$embedded))
fwrite(data.table(file=basename(pdf),font=ff$name,embedded=ff$embedded),file.path(qa,'S4_font_checks.csv'))
fwrite(data.table(source=prior,md5=unname(tools::md5sum(prior))),file.path(qa,'S4_input_hash.csv'))
capture.output(sessionInfo(),file=file.path(qa,'S4_R_session.txt'))
cat('PASS: same 15 estimates; common mini-forest log scale 0.75-1.45; embedded Arial; 300 dpi PNG.\n')
