###################################
### Family relationship check
### date: 09-04-2019
### version: 0.01
### authors: EL - RAG
###################################
### New
# 16-04-2018
# Added file.exists checks 
# changed king input parameters to include -fam, -bed and -bim files to allow different names and not have to duplicate files. 
###################################

library(data.table)
library(tidyverse)
library(optparse)
library(gridExtra)
library(reshape)

##cluster test
## opt<-list()
## opt$code<-"/groups/umcg-aad/tmp04/umcg-elopera/ugli_blood_gsa/pairing.dat"
## opt$info<-"/groups/umcg-aad/tmp04/umcg-elopera/ugli_blood_gsa/LifeLines_families_info_withspouse.dat"
## opt$plink<-"/groups/umcg-aad/tmp04/umcg-elopera/merged_general_QC_err/5_Relatedness/proc/full_data"
## opt$out<-"/groups/umcg-aad/tmp04/umcg-elopera/merged_general_QC_err/plots/"
## opt$workdir<-"/groups/umcg-aad/tmp04/umcg-elopera/merged_general_QC_err/5_Relatedness/proc2/"
## opt$king<-"/groups/umcg-aad/tmp04/umcg-elopera/tools/KING/king"
## opt$dummy<-"/groups/umcg-aad/tmp04/umcg-elopera/ugli_blood_gsa/dummy_allped"
## opt$crane<-"/groups/umcg-aad/tmp04/umcg-elopera/tools/Cranefoot/example/cranefoot"
## opt$makeped<- TRUE


#########################################################################################################
option_list = list(
  make_option(c("-p", "--plink"), type="character", default=NULL, 
              help="Path to plink files index, it assumes a bed, bim and fam file with the same file name", metavar="character"),
  
  make_option(c("-c", "--code"), type="character", default=NULL, 
              help="Path to pairing ID's file", metavar="character"),
  
  make_option(c("-i", "--info"), type="character", default=NULL, 
              help="Phenotype and pedigree information file", metavar="character"),
  
  make_option(c("-k", "--king"), type="character", default=NULL, 
              help="Path to excecutable king", metavar="character"),
  
  make_option(c("-d", "--dummy"), type="character", default=NULL, 
              help="Path to dummyfiles index", metavar="character"),
  
  make_option(c("-o", "--out"), type="character", default="./famCheck_genotypeQC", 
              help="Output path to save report", metavar="character"),
  
  make_option(c("-C", "--cranepath"), type="character", 
              default="/groups/umcg-aad/tmp04/umcg-elopera/tools/Cranefoot/example/cranefoot", 
              help="path to cranefoot executable file", metavar="character"),
  
  make_option(c("-M", "--makeped"), type="logical", 
              default=FALSE, 
              help="TRUE if familial data is complete to create", metavar="character"),
  
  make_option(c("-w", "--workdir"), type="character", 
              default="opt$out", help="processing directory", metavar="character")
); 

opt_parser  <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)



#########################################################################################################
### Main
#########################################################################################################

# routine check if files exists 
if(file.exists(opt$code) == FALSE){
  stop(paste0("[ERROR]\t Pairing file does not exist, input file:\n", opt$code, "\n"))
} else if (all(file.exists(paste0(opt$plink, c(".bim", ".fam", ".bed")))) == FALSE){
  stop(paste0("[ERROR]\t At least one of the plink files (.bim .fam .bed) does not exist:\n", opt$plink, "\n"))
}else if (file.exists(opt$info) == FALSE){
  stop(paste0("[ERROR]\t Info/Phenotype files does not exist, input file:\n", opt$info, "\n"))
} else if(file.exists(opt$king) == FALSE){
  stop(paste0("[ERROR]\t Path to KING does not exist, input file:\n", opt$king, "\n"))
} else{
  cat("[INFO]\t All files from arguments exists \n")
}


cat("[INFO]\t Reading input files")
pairing.table <- fread(opt$code, data.table=F)
info.table <- fread(opt$info, data.table=F)
fam.table <- fread(file = paste0(opt$plink,".fam"))

##function to substract the unique part of the sample ID
codextract <- function(x) {
  x <- as.character(x)
  return(substr(x,nchar(x)-9,nchar(x)))
}

# Matching sample IDs from ".fam" file and "opt$code"  file. 
fam.table$sust <- sapply(fam.table$V1, FUN=codextract)  
pairing.table$sust <- sapply(pairing.table$SAMPLE_IDENTIFIER_Rotterdam, FUN=codextract) 

fam.table$PSEUDOIDEXT <- as.character(pairing.table$PSEUDOIDEXT
                                      [match(fam.table$sust, pairing.table$sust)])
# merge infor table with .fam file. 
fam.table <- left_join(fam.table, info.table, by="PSEUDOIDEXT")

#create dir for outpue
dir.create(path = opt$workdir, recursive = TRUE, showWarnings = FALSE)

## If there are samples in the plink for which a "PSEUDOIDEXT" is not assigned. Then we add complete this info in the fam file
n.na.pseudoID <- sum(is.na(fam.table$PSEUDOIDEXT))
if(n.na.pseudoID>=1){
  cat("[WARNING] a total of", n.na.pseudoID, 
      "samples from the .fam file are not present in the pairing.table, fake pedigree info will be introduce to assess this/these sample/s")
  
  na.pseudoID.index <- which(is.na(fam.table$PSEUDOIDEXT))
  fam.table[na.pseudoID.index,c("FATHER_PSEUDOID", "MOTHER_PSEUDOID", "GENDER1M2F", "PARTNEREXT")] <- matrix(0, ncol= 4, nrow= n.na.pseudoID)
  fam.table[na.pseudoID.index,c("PSEUDOIDEXT", "FAM_ID")] <- cbind(fam.table[na.pseudoID.index,"V1"],fam.table[na.pseudoID.index,"V1"])
}

## If there are persons with a PSEUDOIDEXT but no pedrigree info.
n.na.pedigree <- sum(is.na(fam.table$FAM_ID))
if(n.na.pedigree>=1){
  cat("[WARNING] a total of", n.na.pedigree, 
      "samples from the .fam file do not have pedigree information present in the pairing file")
  
  na.pedigree.index <- which(is.na(fam.table$FAM_ID))
  
  fam.table[na.pedigree.index,"FAM_ID"] <- fam.table[na.pedigree.index,"PSEUDOIDEXT"]
  fam.table[na.pedigree.index,c("FATHER_PSEUDOID", "MOTHER_PSEUDOID", "GENDER1M2F", "PARTNEREXT")] <- matrix(0, ncol= 4, nrow= n.na.pedigree)
}

cols.for.new.fam <- c(9,8,10:12,6) ### order -> "FAM_ID", "PSEUDOIDEXT", "FATHER_PSEUDOID", "MOTHER_PSEUDOID", "GENDER1M2F", "V6"
new.fam <- fam.table[,cols.for.new.fam]

## If there are any duplicated "PSEUDOIDEXT" 
n.duplicated.PSEUDOIDEXT <- sum(duplicated(new.fam$PSEUDOIDEXT))
if(n.duplicated.PSEUDOIDEXT >= 1){
  cat("[WARNING] a total of", n.duplicated.PSEUDOIDEXT, 
      "samples are duplicated, a *_dup* tag will be added to the sample ID")
  
  dup.table <- table(new.fam$PSEUDOIDEXT[which(duplicated(new.fam$PSEUDOIDEXT))])
  for(i.dup.id in names(dup.table)){
    i.dup.index <- which(new.fam$PSEUDOIDEXT == i.dup.id)
    
    n.dup.sufix.vector <- c("", paste0("_", 1:c(dup.table[i.dup.id])))
    new.fam$PSEUDOIDEXT[i.dup.index] <- paste0(unique(new.fam$PSEUDOIDEXT[i.dup.index]), n.dup.sufix.vector)
  }
}
## keep the pairing of the newly named duplicated samples in a different dataframe for later
pair_dup<-data.frame(cbind(new.fam$PSEUDOIDEXT,fam.table$V2,fam.table$PSEUDOIDEXT))
colnames(pair_dup)<-c("dup_PSEUDOIDEXT","Plate_pos","PSEUDOIDEXT")


#### create a new folder for outpur  -> copy input files for king -> change working directory to run king -> lounch king through system()
new.fam.file <- file.path(opt$workdir,"batchinfo.fam")
write.table(new.fam, file=new.fam.file, row.names = FALSE, col.names = FALSE, quote = FALSE )
setwd(dir = opt$workdir)

## if we have the complete data the we merge the whole questionary information with it, else we just check family in the batch

if (opt$makeped==TRUE) {
  
  ###merge new.fam with the whole pedigree
  plink.system.call <- paste0("ml plink;",
                              " plink ",
                              " --bed ", paste0(opt$plink,".bed"),
                              " --fam ", paste0(opt$workdir,"batchinfo.fam"),
                              " --bim ", paste0(opt$plink,".bim"),
                              " --merge ", paste0(opt$dummy,".ped")," ", paste0(opt$dummy,".map"),
                              " --merge-mode 4 ",
                              " --make-bed",
                              " --out fullped")
  
  system(plink.system.call)
  #king system call based on http://people.virginia.edu/~wc9c/KING/manual.html#INPUT
  king.system.call <- paste0(c(opt$king),
                             " -b ", "fullped.bed",
                             " --related ", 
                             " --degree 2",
                             " --prefix famCheck_genotypeQC")
  
  system(king.system.call)
  
} else{
  
  #king system call based on http://people.virginia.edu/~wc9c/KING/manual.html#INPUT
  king.system.call <- paste0(c(opt$king),
                             " -b ", paste0(opt$plink,".bed"),
                             " --fam ", paste0(opt$workdir,"batchinfo.fam"),
                             " --bim ", paste0(opt$plink,".bim"),
                             " -- related", 
                             " --degree 2",
                             " --prefix famCheck_genotypeQC")
  system(king.system.call)
  
}


##########
#Read king output. 
#####

# .king0 file contains the results for all possible pairs for which there is no genetec relationship implicated in the pedigree information.
king_0.file <- file.path(opt$workdir,"famCheck_genotypeQC.kin0")
king_0 <- fread(king_0.file, data.table = FALSE)

# .king file contains the results for all pairs with same family ID.
king.file <- file.path(opt$workdir,"famCheck_genotypeQC.kin")
king <- fread(king.file, data.table = FALSE)

##########
#Prepare data for plotting
#####

# Number of erros across family relationships. 
king$Error.tag <- cut(king$Error, breaks=c(-Inf, 0.49 ,0.51,1), 
                      labels= c("Ok", "Warning", "Error"), right = T)

## Evaluate all errors from king output. 
king.error <- king[which(king$Error.tag == "Error"),]

## king.error can be further filtered to only include FS, PO and UN
king.error.filtered <- king.error[which(king.error$InfType %in% c("FS", "PO", "UN")),]
UN.error.king <- king.error.filtered[king.error.filtered$InfType == "UN",]

#table(as.data.frame(info.table[info.table$FAM_ID %in% unique(UN.error.king$FID),])$FAM_ID)

for(i.un.error in 1:nrow(UN.error.king)){
  info.table[info.table$FAM_ID %in% UN.error.king$FID[i.un.error],]
  
}

##########
#Plotting
#####

n.errors.families.bar <- ggplot(king, aes(x=Error.tag))+
  geom_bar(stat = "count")+
  geom_text(aes(label=..count..),stat='count',position=position_dodge(1), size=4,vjust=0)+
  xlab("")+
  ggtitle("Number of concordant and non concordant genetic relationships")+
  theme_classic()+
  theme(text = element_text(size=10, family = "Helvetica"))

n.errors.fam.relation <- ggplot(king.error, aes(x= InfType))+
  geom_bar(stat = "count")+
  geom_text(aes(label=..count..),stat='count',position=position_dodge(1), size=4, vjust=0)+
  xlab("Relationship inferred by genetics")+
  ggtitle("Types of family relationships corrected from pedigree")+
  theme_classic()+
  theme(text = element_text(size=10, family = "Helvetica"))

infered.expected.hex <- ggplot(king, aes(x=Kinship, y=Z0))+
  geom_hex()+
  scale_fill_viridis_c()+
  theme_classic()+
  theme(text = element_text(size=10, family = "Helvetica"))

king_0$InfType <- factor(king_0$InfType, levels= c("Dup/MZ" , "PO", "FS", "2nd", "3rd"))
non.family.inferences.plot <- ggplot(king_0, aes(x=InfType))+
  geom_bar(stat = "count")+
  geom_text(aes(label=..count.. ),stat='count',position=position_dodge(1.5), size=4,vjust=0)+
  xlab("Relationship inferred by genetics")+
  ggtitle("Number non annotated genetic relationships")+
  theme_classic()+
  theme(text = element_text(size=10, family = "Helvetica"))

plot.file <- file.path(opt$out, paste0("07.famCheck_plots.tiff"))
tiff(plot.file,  width = 3000, height = 3500, units = "px", res = 300, compression = "lzw")
grid.arrange(n.errors.families.bar, n.errors.fam.relation,
             infered.expected.hex, non.family.inferences.plot,
             nrow=2)
dev.off()



###create duplicate samples only report
duplicate_samples<-rbind(king_0[king_0$InfType=="Dup/MZ", c("ID1","ID2")],king[king$InfType=="Dup/MZ", c("ID1","ID2")])
if (nrow(duplicate_samples)!=0){
  duplicate_samples$ID1 <- as.character(pair_dup$Plate_pos
                                        [match(duplicate_samples$ID1, pair_dup$dup_PSEUDOIDEXT)])
  duplicate_samples$ID2 <- as.character(pair_dup$Plate_pos
                                        [match(duplicate_samples$ID2, pair_dup$dup_PSEUDOIDEXT)])
  write.table(duplicate_samples,paste0(opt$workdir,"equal.samples"),quote = F,row.names = F)
}

####

### if the questionary information is compete we will want to make the pedigrees check, otherwise, just looking
### duplicates should be enough

if (opt$makeped==TRUE) {
  
  info.table$Age<-pairing.table$Age[match(info.table$PSEUDOIDEXT,pairing.table$PSEUDOIDEXT)]
  info.table$Birth_year<-pairing.table$BIRTHYEAR[match(info.table$PSEUDOIDEXT,pairing.table$PSEUDOIDEXT)]
  info.table[which(is.na(info.table$Age)),"Age"]<-" "
  
  
  ############
  ###prepare list of families for plotting
  
  names(new.fam)<-c("FAM_ID","PSEUDOIDEXT","FATHER_PSEUDOID","MOTHER_PSEUDOID","GENDER1M2F","V6")
  
  ####for kin0: list of families with more than 3 memebers and new FIRST GRADE relationships
  fstdeg <- king_0[king_0$InfType=="FS" | king_0$InfType=="PO", ]
  fam_list0<-c()
  for (i in 1:nrow(fstdeg)) {
    size1<-nrow(new.fam[which(new.fam$FAM_ID==fstdeg$FID1[i] |new.fam$PSEUDOIDEXT==fstdeg$ID1[i]), ])
    size2<-nrow(new.fam[which(new.fam$FAM_ID==fstdeg$FID2[i] |new.fam$PSEUDOIDEXT==fstdeg$ID2[i]), ])
    if (size1>2) {fam_list0<-c(fam_list0,fstdeg$FID1[i])} 
    else { if (size2>2) {fam_list0<-c(fam_list0,fstdeg$FID2[i])}}
  }
  fam_list0<-unique(fam_list0)
  
  ####for kin: list of families with more than 3 memebers and reported FIRST GRADE relationships with ERROR
  fstdeg2 <- king[which(king$Error==1 & (king$InfType=="FS" | king$InfType=="PO")), ]
  
  fam_list<-c()
  for (i in 1:nrow(fstdeg2)) {
    size1<-nrow(new.fam[which(new.fam$FAM_ID==fstdeg2$FID[i]),])
    if (size1>2 ) {fam_list<-c(fam_list,fstdeg2$FID[i])} 
  }
  fam_list<-unique(fam_list)
  
  
  #########################################################################################################
  ### Pedigree function with Cranefoot
  
  pedigree_crane<-function(ls,pedfile,king,king_0,unexpected=TRUE,Fs.grade=F,fam_batch,crane.path){
    
    if(Fs.grade==T){rel_vector=c("PO","FS")} else {rel_vector=king_0$InfType}
    
    ####generate ethe single family (or 2 families) file
    if(unexpected==T) {
      ###processing from kin0 information
      IDS<-rbind(king_0[which((king_0$FID1==ls|king_0$FID2==ls) & 
                                king_0$InfType %in% rel_vector),"ID2"], 
                 king_0[which((king_0$FID1==ls|king_0$FID2==ls) & 
                                king_0$InfType %in% rel_vector),"ID1"] )
      family.ped<-pedfile[which(pedfile$FAM_ID==ls|pedfile$PSEUDOIDEXT %in% IDS),c(1,2,3,4,5,7) ] 
    } else {
      ###processing from kin information
      family.ped<-pedfile[pedfile$FAM_ID==ls ,c(1,2,3,4,5,7) ]
    }
    names(family.ped)<-c("IID","FAM_ID","FATHER_PSEUDOID","MOTHER_PSEUDOID","GENDER1M2F","AGE")

    
    ##retrieve parents to make them individuals
    extra.IDs <- unique(c(family.ped[,"FATHER_PSEUDOID"],family.ped[,"MOTHER_PSEUDOID"]))
    `%!in%` = Negate(`%in%`)## create negation of %in% function
    extra.IDs <- extra.IDs[ which(extra.IDs %!in% family.ped$PSEUDOIDEXT)]   # remove extra IDs (parents) which are already in the final.fam$PSEUDOIDEXT
    extra.IDs.sex <- ifelse(extra.IDs %in% family.ped$FATHER_PSEUDOID, 1, 2) #define sex of new inidivudals (parents)
    #fill data for parents
    FAM_ID<-ifelse(extra.IDs.sex==1,family.ped$FAM_ID[match(extra.IDs,family.ped$FATHER_PSEUDOID)],
                   family.ped$FAM_ID[match(extra.IDs,family.ped$MOTHER_PSEUDOID)])
    AGE<-ifelse(extra.IDs %in% family.ped$IID, family.ped$AGE[match(extra.IDs,family.ped$IID)]," ")
    
    extra.fam <- data.frame(extra.IDs,
                            FAM_ID,
                            rep(0, length(extra.IDs)),
                            rep(0, length(extra.IDs)),
                            extra.IDs.sex,
                            AGE)
    #unite parents with offspring in a unique database
    colnames(extra.fam) <- colnames(family.ped) 
    final.fam <- rbind(family.ped, extra.fam)
    final.fam<-final.fam[final.fam$IID!=0,]
    
    
    ##Generate phenotypes files (sex, genetic info)
    #final.fam <-family.ped
    final.fam$GENDER1M2F<-ifelse(final.fam$GENDER1M2F==1,"M","F")## gender info
    final.fam$Genetic_info<-ifelse(final.fam$IID %in% fam_batch$PSEUDOIDEXT,"550077","999999")## genetic info colored "purple"
    
    #### include relations from kin
   
    if(unexpected==T) {
      ###for kin 0
      relations<-king_0[which(king_0$InfType!="UN" & 
                                (king_0$FID2 %in% unique(final.fam$FAM_ID) & king_0$FID1 %in% unique(final.fam$FAM_ID))
                              & king_0$InfType %in% rel_vector), ]
      if (nrow(relations)==0){gen.fam<-"incomplete family information"}
      else {
        relations$Familial_errors<- 1:nrow(relations)
        gen.fam<-gather(relations, key="mode", "IID", "ID1", "ID2")## group each relation
        ###stablish error filters
        err.row.index<-c(seq(1:nrow(gen.fam)))
        err.col.index<-c("FID1","FID2","Familial_errors","IID","message","InfType")
        event<-"new_found."
      }
    } else {
      relations<-king[which( (king$ID1 %in% unique(final.fam$IID)| king$ID2 %in% unique(final.fam$IID)) ), ]
      relations$Familial_errors<- 1:nrow(relations)
      gen.fam<-gather(relations, key="mode", "IID", "ID1", "ID2")## group each relation
      ###stablish error filters
      err.row.index<-which(gen.fam$Error.tag=="Error")
      err.col.index<-c("FID","Familial_errors","IID","Error.tag","message","InfType")
      event<-"error."
    }
    if (gen.fam=="incomplete family information") {return(paste0("Family ",ls," incomplete"))} ####incomplete will be reported when there is no pedigree onformation  for genetic samples
    else {
      
      gen.fam$GENDER1M2F<-family.ped$GENDER1M2F[match(gen.fam$IID,family.ped$IID)]
      ##add  text with the information of relationships
      gen.fam$message<-ifelse(gen.fam$mode=="ID1",
                              paste0(gen.fam$InfType," with ",gen.fam[which(gen.fam$Familial_errors==gen.fam$Familial_errors & gen.fam$mode=="ID2"), "IID"]),
                              paste0(gen.fam$InfType," with ",gen.fam[which(gen.fam$Familial_errors==gen.fam$Familial_errors & gen.fam$mode=="ID1"), "IID"]))
      
      ###separate familial error in a different table
      Gen_errors<-gen.fam[err.row.index,err.col.index]
      
      ####make text columns for information of relationships
      n.text.col<-max(table(Gen_errors$IID))
      fillrels<-function(x) {
        k<-c("IID"=x,
             Gen_errors[Gen_errors$IID==x ,"message"], rep("",n.text.col-length(Gen_errors[Gen_errors$IID==x,"message"])))
        return(k)
      }
      mesdf<-lapply(unique(Gen_errors$IID), FUN= fillrels )
      mesdf<-data.frame(matrix(unlist(mesdf), nrow=length(mesdf), byrow=T))
      names(mesdf)<-c("IID",paste0("Genetic_relationship_",seq(1:n.text.col))) 
      mesdf$IID<-as.character(mesdf$IID)
      Gen_errors$IID<-as.character(Gen_errors$IID)
      Gen_errors<-right_join(Gen_errors,mesdf,by="IID")
      
      ###crate directory to save the result plots
      dir.create(paste0(opt$out,"Crane_fam_scripts"),recursive = TRUE, showWarnings = FALSE)
      crane.dir<-paste0(opt$out,"Crane_fam_scripts/")

      
      ## write necessary input files for cranefoot
      write.table(final.fam,paste0(opt$workdir,"family.ped"),quote = F,row.names = F,col.names = T,sep = "\t")
      write.table(Gen_errors,paste0(opt$workdir,"fam.error"),quote = F,row.names = F,col.names = T,sep = "\t")
      write.table(final.fam,paste0(opt$workdir,"phenotype_1"),quote = F,row.names = F,col.names = T,sep = "\t")
      
      ## create config file for cranefoot
      config.file<-data.frame(
        cbind(
          
          c("PedigreeFile","PedigreeName","NameVariable","FatherVariable",
            "MotherVariable","GenderVariable","ColorVariable","TextVariable","TextVariable","ArrowVariable",rep("TextVariable",n.text.col)),
          
          c(paste0(opt$workdir,"family.ped"),paste0(crane.dir,"07.",event ,ls,".ped"),
            "IID","FATHER_PSEUDOID","MOTHER_PSEUDOID","GENDER1M2F","Genetic_info","IID","AGE",
            "Familial_errors", paste0("Genetic_relationship_",seq(1:n.text.col)) ),
          
          c("","","","","",paste0(opt$workdir,"phenotype_1"),paste0(opt$workdir,"phenotype_1"),paste0(opt$workdir,"phenotype_1"),
            paste0(opt$workdir,"phenotype_1"),paste0(opt$workdir,"fam.error"), rep(paste0(opt$workdir,"fam.error"),n.text.col) )
          
        )
      )
      write.table(config.file,paste0(opt$workdir,"CFG"),quote = F,row.names = F,col.names = F,sep = "\t")
      
      ## create system call for cranefoot
      crane.system.call <- paste0(c(opt$crane)," ",paste0(opt$workdir,"CFG"))
      system(crane.system.call)
      return(paste0("Family ",ls," done"))
    }
  }
  
  ###########################################################################################
  
  ####make padigrees with cranefoot
  ##list
  all_error.list<-lapply(fam_list,FUN= pedigree_crane,pedfile=info.table,king=king,king_0=king_0,unexpected=F,
                         Fs.grade=F,fam_batch=new.fam,crane.path=opt$crane)
  
  all_new_found.list<-lapply(fam_list0,FUN= pedigree_crane,pedfile=info.table,king=king,king_0=king_0,
                             unexpected=T,Fs.grade=F,fam_batch=new.fam,crane.path=opt$crane)
  
  write.table(unlist(all_error.list),paste0(opt$out,"Crane_all_error.FID.list"),quote = F,row.names = F,col.names = F)
  write.table(unlist(all_new_found.list),paste0(opt$out,"Crane_all_newfound.FID.list"),quote = F,row.names = F,col.names = F)

  
  #########################################################################################################
  ### Pedigree function with R
  
  
  pedigree_graph<-function(ls,pedfile,king,king_0,unexpected=TRUE,Fs.grade=TRUE,add=FALSE,fam_batch){
    
    ###################################
    ### pedigree graph using ggplot2
    ### date: 02-05-2019
    
    ########requirements
    #ls: vector containing the families to be viewed in a pedigree
    #pedfile: .famfile with column names= FAM_ID","PSEUDOIDEXT","FATHER_PSEUDOID","MOTHER_PSEUDOID","GENDER1M2F","PARTNEREXT"
    #king:kin file with expected genetic relationships
    #king_0; kin0 file with unexpected genetic relationships
    #unexpected: TRUE to visualize unexpected (kin0) genetic relationships, FALSE to evaluate pedigree-known (kin) relationships
    #Fs.grade: TRUE to evaluate only first grade relationships
    #add: TRUE to visualize expected genetic relationships over the unexpected relationships graph (applies only when unexpected=TRUE)
    #fam_batch: the fam file from the batch
    
    
    if(Fs.grade==T){rel_vector=c("PO","FS")} else {rel_vector=king_0$InfType}
    
    ##arrange order of columns
    pedfile<-pedfile[,c("FAM_ID","PSEUDOIDEXT","FATHER_PSEUDOID","MOTHER_PSEUDOID","GENDER1M2F","PARTNEREXT","Age")]
    
    
    if(unexpected==T) {
      ###processing from kin0 information
      IDS<-rbind(king_0[which((king_0$FID1==ls|king_0$FID2==ls) & 
                                king_0$InfType %in% rel_vector),"ID2"], 
                 king_0[which((king_0$FID1==ls|king_0$FID2==ls) & 
                                king_0$InfType %in% rel_vector),"ID1"] )
      family.fam<-pedfile[which(pedfile$FAM_ID==ls|pedfile$PSEUDOIDEXT %in% IDS), ] 
    } else {
      ###processing from kin information
      family.fam<-pedfile[pedfile$FAM_ID==ls , ]
    }
    
    #####1. Define generations (Y axis)
    ##retrieve parents to make them individuals
    extra.IDs <- unique(c(family.fam[,"FATHER_PSEUDOID"],family.fam[,"MOTHER_PSEUDOID"]))
    `%!in%` = Negate(`%in%`)## create negation of %in% function
    extra.IDs <- extra.IDs[ which(extra.IDs %!in% family.fam$PSEUDOIDEXT)]   # remove extra IDs (parents) which are already in the final.fam$PSEUDOIDEXT
    extra.IDs.sex <- ifelse(extra.IDs %in% family.fam$FATHER_PSEUDOID, 1, 2) #define sex of new inidivudals (parents)
    #fill data for parents
    FAM_ID<-ifelse(extra.IDs.sex==1,family.fam$FAM_ID[match(extra.IDs,family.fam$FATHER_PSEUDOID)],
                   family.fam$FAM_ID[match(extra.IDs,family.fam$MOTHER_PSEUDOID)])
    
    extra.fam <- data.frame(FAM_ID,
                            extra.IDs, 
                            rep(0, length(extra.IDs)),
                            rep(0, length(extra.IDs)),
                            extra.IDs.sex,rep(NA,length(extra.IDs)),rep(NA,length(extra.IDs)) )
    #unite parents with offspring in a unique database
    colnames(extra.fam) <- colnames(family.fam) 
    final.fam <- rbind(family.fam, extra.fam)
    #create Generation column and assing firts generation to parents (and individuales with unknow ascendance)
    final.fam$GENERATION<-ifelse(final.fam$FATHER_PSEUDOID==0 & final.fam$MOTHER_PSEUDOID==0,"F0","undetermined")
    #Define generation for the rest of individuals with a loop
    final.fam<-final.fam[which(final.fam$PSEUDOIDEXT!="0"),]
    this.gen<-final.fam[which(final.fam$GENERATION!="F0"),]
    i=0
    while (nrow(this.gen)>0){
      prev.gen<-final.fam[final.fam$GENERATION==paste0("F",i),"PSEUDOIDEXT"]#define the previous generation
      this.gen <- final.fam[ which(final.fam$FATHER_PSEUDOID %in% prev.gen| final.fam$MOTHER_PSEUDOID %in% prev.gen),]#define this generation
      # this generation are the offspring of previous generation
      final.fam[which(final.fam$PSEUDOIDEXT %in% this.gen$PSEUDOIDEXT),"GENERATION"]<-paste0("F",i+1)#mark this generation
      i=i+1
      #cat(i,"\n")
    }
    ###use partner information to fix generation
    unknowindex<-which(final.fam$GENERATION=="F0" & !is.na(final.fam$PARTNEREXT) & (final.fam$PARTNEREXT %in%final.fam$PSEUDOIDEXT))
    final.fam[unknowindex,"GENERATION"]<-
      final.fam$GENERATION[match(final.fam$PARTNEREXT[unknowindex],final.fam$PSEUDOIDEXT)]
    
    #####
    names(final.fam)[2]<-"IID"
    final.fam<-final.fam[which(final.fam$IID!="0"),]
    
    ######Use offspring information to adress generation
    parent1<-final.fam[which(final.fam$GENERATION=="F0" & is.na(final.fam$PARTNEREXT)
                             & (final.fam$IID %in% final.fam$FATHER_PSEUDOID|
                                  final.fam$IID %in% final.fam$MOTHER_PSEUDOID)),"IID"]
    if (length(parent1)>0){
      highgen<-final.fam[which( (final.fam$FATHER_PSEUDOID %in% parent1| 
                                   final.fam$MOTHER_PSEUDOID %in% parent1)  &
                                  as.numeric(gsub("F","",final.fam$GENERATION))>1),]
      if(nrow(highgen)>0){
        highgen$Gen2<-paste0("F",as.numeric(gsub("F","",highgen$GENERATION))-1)
        new.gen.indexF<-which(final.fam$IID %in% parent1 & 
                                final.fam$IID %in% highgen$FATHER_PSEUDOID)
        final.fam[new.gen.indexF,"GENERATION"]<-highgen$Gen2[match(final.fam$IID[new.gen.indexF],highgen$FATHER_PSEUDOID)]
        new.gen.indexM<-which(final.fam$IID %in% parent1 & 
                                final.fam$IID %in% highgen$MOTHER_PSEUDOID)
        final.fam[new.gen.indexM,"GENERATION"]<-highgen$Gen2[match(final.fam$IID[new.gen.indexM],highgen$MOTHER_PSEUDOID)]
        
      }
    }
    
    ### order Generation as a factor
    final.fam$GENERATION <- factor(final.fam$GENERATION, 
                                   levels=c(NA,"Undetermined",paste0("F",seq(length(unique(final.fam$GENERATION))-1,0))))
    
    ####3. generate a nuclear family code for organizing each nuclea family in X axis
    final.fam$fam_group <- final.fam %>% group_indices(c(MOTHER_PSEUDOID))#asigning code to everyone according to mother
    final.fam$fam_group <- final.fam %>% group_indices(c(FATHER_PSEUDOID))#asigning code to everyone according to father
    ##creating familygrooups for parents
    momgroup<-unique(final.fam[which(final.fam$fam_group!="1"),c("MOTHER_PSEUDOID","fam_group")])
    colnames(momgroup)[1]<-"PID"
    dadgroup<-unique(final.fam[which(final.fam$fam_group!="1"),c("FATHER_PSEUDOID","fam_group")])
    colnames(dadgroup)[1]<-"PID"
    parentgroup<-rbind(momgroup,dadgroup)
    ##assign family groups for the parents
    replace.index<-which(final.fam$fam_group=="1")
    final.fam[which(final.fam$fam_group=="1"),"fam_group"]<-
      parentgroup$fam_group[match(final.fam$IID[replace.index],parentgroup$PID)]
    
    ###4. genrate X axis by generation in family order
    #function to distribute coordinate (from 0 to 1)
    generateXcoord <- function(size){
      if(size %% 2 != 0 & size != 1){   # Check if size is odd
        newsize <- size - 1
        interval <- 1/newsize
        x <- seq(0, 1, interval)
      }
      if(size %% 2 == 0){    # Check if size is even
        interval <- 1/size
        x <- seq(0, 1, interval)[-size-1] + diff(seq(0, 1, interval))/2   
      }
      if(size == 1) x <- 0.5
      x
    }
    ###generate column of Xcoordinate in dataframe
    xdistribution<- unique(final.fam[,c("fam_group","IID","GENERATION")])
    xdistribution<-xdistribution[order(xdistribution$fam_group, decreasing = FALSE),]
    ##use function to generate coordinate
    xdistribution<-as.data.frame(xdistribution%>%group_by(GENERATION)%>%mutate(xcoord=generateXcoord(length(IID))))
    #add coordinate information to dataframe
    final.fam$xcoord<- xdistribution$xcoord[match(final.fam$IID,xdistribution$IID)]
    
    ######position unknown generation
    final.fam[which(final.fam$GENERATION=="F0" & !(final.fam$IID %in% final.fam$FATHER_PSEUDOID | 
                                                     final.fam$IID  %in% final.fam$MOTHER_PSEUDOID)),"GENERATION"]<-"Undetermined"
    final.fam$GENERATION <- factor(final.fam$GENERATION, 
                                   levels=c(NA,"Undetermined",paste0("F",seq(length(unique(final.fam$GENERATION))-1,0))))
    
    #####5. make Data for line plot joining EACH parent with EACH offspring
    lines.fam<-gather(final.fam, key="PARENT", "PID", "FATHER_PSEUDOID", "MOTHER_PSEUDOID")
    lines.fam$Parentline <- 1:nrow(lines.fam)
    lines.fam <- melt(lines.fam, id.vars = "Parentline", measure.vars=c("IID", "PID"))
    names(lines.fam)[3]<-"IID"
    lines.fam<-lines.fam[which(lines.fam$IID!="0"),]
    lines.fam$x<-final.fam$xcoord[match(lines.fam$IID,final.fam$IID)]
    lines.fam$y<-final.fam$GENERATION[match(lines.fam$IID,final.fam$IID)]
    
    #####6. assign genetic relations found (from kin and/or kin0)
    
    if(unexpected==T) {
      ###for kin 0
      relations<-king_0[which(king_0$InfType!="UN" & 
                                (king_0$FID2 %in% unique(final.fam$FAM_ID) & king_0$FID1 %in% unique(final.fam$FAM_ID))
                              & king_0$InfType %in% rel_vector), ]
      if (nrow(relations)==0){gen.fam<-"incomplete family information"}
      else {
        relations$rel_line <- 1:nrow(relations)
        gen.fam<-gather(relations, key="mode", "IID", "ID1", "ID2")
        gen.fam$x<-final.fam$xcoord[match(gen.fam$IID,final.fam$IID)]
        gen.fam$y<-final.fam$GENERATION[match(gen.fam$IID,final.fam$IID)]
        
      }
      
      if (add==T){ 
        relations2<-king[which( king$InfType!="UN" &
                                  (king$ID1 %in% unique(final.fam$IID)| king$ID2 %in% unique(final.fam$IID)) &
                                  king$InfType %in% rel_vector ) , ]
        if (nrow(relations2)==0){gen.fam2<-"incomplete family information"}
        else {
          relations2$rel_line2 <- 1:nrow(relations2)
          gen.fam2<-gather(relations2, key="mode", "IID", "ID1", "ID2")
          names(gen.fam2)[13]<-"InfType2"
          gen.fam2<-gen.fam2[which(gen.fam2$IID %in% final.fam$IID),]
          gen.fam2$x<-final.fam$xcoord[match(gen.fam2$IID,final.fam$IID)]
          gen.fam2$y<-final.fam$GENERATION[match(gen.fam2$IID,final.fam$IID)]
          gen.fam2$InfType2 <- factor(gen.fam2$InfType2, levels= c("PO","FS","2nd","3rd","4th","Dup/MZ"))
          linetypesf<-c("solid", "dashed", "dotted", 
                        "dotdash", "longdash","twodash")
          names(linetypesf)<-levels(gen.fam2$InfType2)
        }
      }
    } else {
      ####for kin
      relations<-king[which( king$InfType!="UN" &
                               (king$ID1 %in% unique(final.fam$IID)| king$ID2 %in% unique(final.fam$IID)) &
                               king$InfType %in% rel_vector) , ]
      if (nrow(relations)==0){gen.fam<-"incomplete family information"}
      else {
        relations$rel_line <- 1:nrow(relations)
        gen.fam<-gather(relations, key="mode", "IID", "ID1", "ID2")
        gen.fam$x<-final.fam$xcoord[match(gen.fam$IID,final.fam$IID)]
        gen.fam$y<-final.fam$GENERATION[match(gen.fam$IID,final.fam$IID)]
      }
    }
    
    if (class(gen.fam)=="character") {
      return("error")
      } else {
      
      gen.fam$InfType <- factor(gen.fam$InfType, levels= c("PO","FS","2nd","3rd","4th","Dup/MZ"))
      linetypesf<-c("solid", "dashed", "dotted", 
                    "dotdash", "longdash","twodash")
      names(linetypesf)<-levels(gen.fam$InfType)
      
      ####7. plot graph
      
      final.fam$infered.type <- gen.fam$InfType[match(final.fam$IID,gen.fam$IID)]
      final.fam$infered.shapes <- as.factor(final.fam$GENDER1M2F)
      final.fam$infered.shapes[which(is.na(final.fam$infered.type))] <- NA
      final.fam$gen.info<-ifelse(final.fam$IID %in% fam_batch$PSEUDOIDEXT,as.factor(final.fam$GENDER1M2F),NA)
      
      if(unexpected){
        ped.plot<-ggplot(final.fam, aes(x=xcoord,y=GENERATION)) +
          scale_shape_manual(values=c(15,16))+
          geom_line(data=lines.fam,aes(x=x,y=y,group = Parentline),color="lightgray",size=3)+
          geom_line(data=gen.fam,aes(x=x,y=y,group = as.factor(rel_line) , linetype=as.factor(InfType)),position = position_jitter(height = 0.05,width = 0),
                    color="red",size=0.5)+
          geom_point(aes(shape=infered.shapes), size=12, show.legend = F, color="red")+
          geom_point(aes(shape=as.factor(gen.info)), size=11, show.legend = F, color="black")+
          geom_point(aes(shape=as.factor(final.fam$GENDER1M2F),
                         color= as.factor(final.fam$FAM_ID)),size=9)+
          guides(shape=F)+
          scale_color_brewer(name = "Family", palette = 'Accent')+
          scale_linetype_discrete(na.translate=FALSE)+
          scale_linetype_manual(values = linetypesf,
                                labels=c("Parent-Offspring","Full-Sibling","2nd-degree","3rd-degree","4th-degree","Dup/MZ" ),drop=F)+
          geom_text(aes(label=final.fam$IID),hjust=0.5, vjust=3.89,size=2.5)+
          guides(color= guide_legend(nrow=2, byrow = TRUE),
                 linetype =(guide_legend(nrow=2, byrow = TRUE,title = 'Infered Relationship')))+
          theme_classic()+
          ggtitle(paste("Families:",paste(unique(final.fam$FAM_ID),collapse=" & " )))+
          theme(legend.position = 'bottom', axis.ticks = element_blank(),  
                axis.text.x = element_blank(), axis.line = element_blank(), axis.title.x =element_blank(), 
                legend.title = element_text( size = 10), legend.text = element_text( size = 8 ),
                legend.background = element_rect(colour = "black",size=0.1),plot.title = element_text(hjust = 0.5,size=12))
        
        if (add==T){
          if (class(gen.fam2)=="data.frame"){
            if (sum(which(duplicated(gen.fam2$rel_line2)))>0) {
              ped.plot <- ped.plot + 
                geom_line(data=gen.fam2,aes(x=x,y=y,group = as.factor(rel_line2) , linetype=InfType2)
                          ,color="darkgreen",size=0.5, position = position_jitter(height = 0.05,width = 0),show.legend = F)
            }
          }
        }
      } else {
        
        ped.plot<-ggplot(final.fam, aes(x=xcoord,y=GENERATION)) +
          geom_line(data=lines.fam,aes(x=x,y=y,group = Parentline),color="lightgray",size=3)+
          geom_line(data=gen.fam,aes(x=x,y=y,group = as.factor(rel_line) , 
                                     linetype=as.factor(InfType)),
                    position = position_jitter(height = 0.05,width = 0),color="red",size=0.5)+
          geom_point(aes(shape=infered.shapes), size=12, show.legend = F, color="red")+
          geom_point(aes(shape=as.factor(gen.info)), size=11, show.legend = F, color="black")+
          geom_point(aes(shape=as.factor(final.fam$GENDER1M2F)),size=9,show.legend = F, color="darkcyan")+
          scale_shape_manual(values=c(15,16))+
          scale_linetype_manual(values = linetypesf,na.translate=FALSE,
                                labels=c("Parent-Offspring","Full-Sibling","2nd-degree","3rd-degree","4th-degree","Dup/MZ"),drop=F)+
          geom_text(aes(label=final.fam$IID),hjust=0.5, vjust=3.89,size=2.5)+
          guides(color= guide_legend(nrow=2, byrow = TRUE),
                 linetype =(guide_legend(nrow=2, byrow = TRUE,title = 'Infered Relationship')))+
          theme_classic()+
          ggtitle(paste("Families:",paste(unique(final.fam$FAM_ID),collapse=" & " )))+
          theme(legend.position = 'bottom', axis.ticks = element_blank(),  
                axis.text.x = element_blank(), axis.line = element_blank(), axis.title.x =element_blank(), 
                legend.title = element_text( size = 10), legend.text = element_text( size = 8 ),
                legend.background = element_rect(colour = "black",size=0.1), plot.title = element_text(hjust = 0.5,size=12))
        
      }
    }
    
    
    return(tryCatch(ped.plot, error=function(e) NULL))
  }
  
  
  
  ##################plot pedigrees##################
  
  dir.create(paste0(opt$out,"pedigree_graph"))
  pedigree.file<-paste0(opt$out,"pedigree_graph/")
  plot_list<-lapply(fam_list0,FUN= pedigree_graph,pedfile=info.table,
                    king=king,king_0=king_0,unexpected=TRUE,Fs.grade=F,add=T,fam_batch=new.fam)
  
  incomplete.families<-c()
  for (e in 1:length(plot_list)){
    if (class(plot_list[[e]])=="character") {incomplete.families<-c(incomplete.families,fam_list0[[e]])} 
    else{
      ped.plot.file<-paste0(pedigree.file,"new_found_",fam_list0[e],"pedigree.tiff")
      tiff(ped.plot.file,  width =4000, height = 2000, units = "px", res = 300, compression = "lzw")
      plot(plot_list[[e]])
      dev.off()
    }
  }
  write.table(fam_list0,paste0(pedigree.file,"all_newfound.FID.list"),quote = F,row.names = F,col.names = F)
  write.table(incomplete.families,paste0(pedigree.file,"incomplete_newfound.FID.list"),quote = F,row.names = F,col.names = F)
  
  
  plot_list<-lapply(fam_list,FUN= pedigree_graph,pedfile=info.table,king=king,king_0=king_0,unexpected=F,Fs.grade=F,fam_batch=new.fam)
  incomplete.families<-c()
  for (e in 1:length(plot_list)){
    if (class(plot_list[[e]])=="character") {incomplete.families<-c(incomplete.families,fam_list[[e]])} 
    else{
      ped.plot.file<-paste0(pedigree.file,"errors",fam_list[e],"pedigree.tiff")
      tiff(ped.plot.file,  width =4000, height = 2000, units = "px", res = 300, compression = "lzw")
      plot(plot_list[[e]])
      dev.off()
    }
  }
  write.table(fam_list,paste0(pedigree.file,"all_error.FID.list"),quote = F,row.names = F,col.names = F)
  write.table(incomplete.families,paste0(pedigree.file,"incomplete_error.FID.list"),quote = F,row.names = F,col.names = F)
  
}


####
##done





