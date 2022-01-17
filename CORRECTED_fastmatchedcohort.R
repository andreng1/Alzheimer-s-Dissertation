#Script by Dr Arron Lacey, modified by Andre Ng
#THIS IS THE CORRECTED VERSION
#Date modified: 14/09/2021

#This script joins each case (from the case-control study) with five controls 
#by category matched sampling

#Loading the libraries
library(data.table)
library(tidyverse)
setwd("s:/1074 - Classifying Neurodegenerative Disorders for Clinical and Research purposes/")
library(RODBC)
source("sail_login.r")

#Loading the cases and controls tables
controls <- sqlQuery(channel, "SELECT * FROM SAILW1074V.CONTROLS")
cases <- sqlQuery(channel, "SELECT ALF_PE, GNDR_CD, (YEAR(DIAG_DT) - AGE) AS YOB, DEP_SCORE, CASES, DIAG_DT FROM SAILW1074V.C_AZ_CASES2")

#Create a data frame which will contain the results
matched <- data.frame()
control.pool<- data.table(controls, key = c("GNDR_CD","YOB","DEP_SCORE"))

gc()   # clear unused memory

#Matching the cases with controls (may take hours to run)
system.time(
  for (i in 1:nrow(cases)){
    merged<-data.table(inner_join(cases[i,],control.pool,by=c("GNDR_CD","YOB","DEP_SCORE")),key = c("GNDR_CD","YOB","DEP_SCORE") ) #control vars
    filter<-with(merged,merged[1:5,]) # 1:5 match
    matched<-data.table(rbind(filter,matched))
    control.pool<-control.pool[!control.pool$ALF_PE %in% filter$ALF_PE.y,]
  }
)

#Delete date rows as the 'dates' datatype causes problems loading the finished table
#onto SQL
matched2 <- subset(matched, select = -c(6))

#To save a table back to the database
sqlSave(channel, matched2,tablename = "SAILW1074V.C_CASE_CTRL",rownames=FALSE,append=TRUE, fast=TRUE)


