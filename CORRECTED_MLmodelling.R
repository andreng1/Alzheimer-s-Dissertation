#952781 - Andre Chor Him Ng
#SAIL Project ID: SAIL1074V
#File created on: 26th August, 2021 (corrected on 14/09/21)

#This R script continues the work from the SQL script and will
#model the prepared dataset with machine learning (ML)

#Load the libraries needed
library(data.table)
library(tidyverse)
library(RODBC)
library(reshape2)
library(reshape)
library(caret)
library(randomForest)
library(kernlab)
library(rpart.plot)
library(rpart)
library(yardstick)
library(pROC)
library(e1071)

#Set working directory
setwd("P:/ngc/workspace/CORRECTED Alzheimer's dissertation/CORRECTED R Scripts and Results")

#Log in to the SAIL database
source("sail_login.r")

#Loading the dataset prepared from SQL onto R
case_ctrl <- sqlQuery(channel, "SELECT * FROM SAILW1074V.C_CASE_CTRL_FEATURES")


#################
#Part 1: Finish preparing the table for modelling

#Cast/Pivot the tables to a wide format
#Casting a temporary table that shows the event count per event code & ALF_PE
temp1 <- dcast(case_ctrl, ALF_PE + GNDR_CD + YOB + DEP_SCORE + CASES + GROUP_ID ~ EVENT_CD,
              value.var = c("EVENT_COUNT"))
#Casting a 2nd temporary table that shows the event count per average event value & ALF_PE
temp2 <- dcast(case_ctrl, ALF_PE + GNDR_CD + YOB + DEP_SCORE + CASES + GROUP_ID ~ EVENT_CD,
                           value.var = c("AVG_EVT_VAL"))
#This had to be done because 'value.var = c("EVENT_COUNT","AVG_EVT_VAL")' generates an error

#Imputing 0 into temp1 in case the event counts are null or NA
temp1[is.na(temp1)] <- 0

#Removing columns in temp2 that are completely null or NA
temp2 <- temp2[,colSums(is.na(temp2))<nrow(temp2)]
#16 columns removed (including "Z.y" which should be completely null anyway as it was used
#to denote this particular ALF_PE did not have any of the most commonly found read codes

#Imputing median by cases and by controls separately
#Further splitting temp2 into only cases and controls
temp2case <- temp2 %>% filter(CASES == 1)
temp2ctrl <- temp2 %>% filter(CASES == 0)
#Removing columns with more than 50% rows with NA
temp2case <- temp2case[,colSums(is.na(temp2case))<(nrow(temp2case)/2)]
temp2ctrl <- temp2ctrl[,colSums(is.na(temp2ctrl))<(nrow(temp2ctrl)/2)]
#Impute median
#1st) Create a function that imputes NA rows with median
med_func <- function(x){
  x[is.na(x)] <- median(x, na.rm = TRUE)
  x
}
#2nd Apply function to each table
temp2case <- data.frame(apply(temp2case, 2, med_func))
temp2ctrl <- data.frame(apply(temp2ctrl, 2, med_func))
#Join tables back together
temp2 <- bind_rows(temp2case, temp2ctrl)
#There are no columns that is imputed in controls but NA in cases, or vice versa

#This leaves 34 columns
#Remove the tables that are no longer useful from R
rm(temp2case, temp2ctrl)

#The two temporary tables need to be joined back together so that both event count
#and average event value are shown
case_ctrl_wide <- merge(temp1, temp2, by = "ALF_PE")

#Deleting the duplicate columns
case_ctrl_wide <- select(case_ctrl_wide, -c(GNDR_CD.y, YOB.y, DEP_SCORE.y, CASES.y, GROUP_ID.y, Z))

#Renaming the columns because after the joining there are ".x" and "X" in the column names
#Note: ".x" is removed, whereas "X" is replaced with "VAL_" denoting its the average event value
case_ctrl_wide <- case_ctrl_wide %>% rename_with(~ gsub('X', 'VAL_', .x))

#Check the classes
View(lapply(case_ctrl_wide,class))
#The response variable needs to be changed into a factor
#(allows algorithms like random forest to assume classification instead of regression)
case_ctrl_wide$CASES.x <- as.factor(case_ctrl_wide$CASES.x)
#Check factor level
levels(case_ctrl_wide$CASES.x)
#Result: "0" "1"
#Needs to change positive class to 1 (aka the result should be "1" "0" instead)
case_ctrl_wide$CASES.x <- fct_relevel(case_ctrl_wide$CASES.x, "1", "0")
#Check again
levels(case_ctrl_wide$CASES.x)
#Result: "1", "0"

#Remove the unnecessary columns
#detach("package:MASS", unload = TRUE) #might need to detach the package MASS to avoid errors
case_ctrl_wide2 <- select(case_ctrl_wide, -c(ALF_PE, GNDR_CD.x, YOB.x, 
                                             DEP_SCORE.x))


#Renaming the columns to start with "READ_" because some columns have read
#codes as their names, which starts with a number, which in turn
#causes problems for the randomForest package
colnames(case_ctrl_wide2) <- paste0("READ_", colnames(case_ctrl_wide2)) 


#################
#Part 2: Split the data in two (Train & test)
#As the cases are individually matched with five other controls, test and train
#data need to be split via group ID. 
#Note: each control were randomly selected to each cases.

#1st) Create the train test split (75% train, 25 % test)
#Note: Shown originally on SQL, there were 1549 groups (aka 15429 GROUP_IDs)
bound <- floor((15429/4)*3)

#Shuffle the data
#2nd) Create a new data frame with shuffled group IDs
random_ID <- data.frame(READ_GROUP_ID.x = sample(15429))

#3rd) Create test and train data frames from the shuffled data frame (random_ID)
#and split the number of group IDS by a 75% to 25% ratio
train <- data.frame(READ_GROUP_ID.x = random_ID[1:bound,])
test <- data.frame(READ_GROUP_ID.x = random_ID[(bound+1):nrow(random_ID),])

#4th) Inner join the train and test data frames back with the case_ctrl_features
#table to retrieve the rest of the columns
train <- merge(case_ctrl_wide2, train, by = 'READ_GROUP_ID.x')
test <- merge(case_ctrl_wide2, test, by = 'READ_GROUP_ID.x')

#5th) Remove the READ_GROUP_ID.x column (Becuase it is not a response variable 
#or risk factor) & READ_Z.x because it is zero for all rows as it was used
#to denote 'this ALF_PE did not have any of the most frequently found read code'
train <- select(train, -c("READ_GROUP_ID.x"))
test <- select(test, -c("READ_GROUP_ID.x"))

#Save the datasets
save(case_ctrl_wide2, test, train, file = "processed_data.Rdata")


#################
#Part 3: Model the data

#Random Forest
#Run the model
rfmodel1 <- randomForest(READ_CASES.x ~., data = train)

#Results:
rfmodel1
# Call:
#   randomForest(formula = READ_CASES.x ~ ., data = train) 
# Type of random forest: classification
# Number of trees: 500
# No. of variables tried at each split: 8
# 
# OOB estimate of  error rate: 5.17%
# Confusion matrix:
#   1     0  class.error
# 1 7983  3588 3.100856e-01
# 0    1 57854 1.728459e-05


#Confusion Matrix to show performance
confusionMatrix(predict(rfmodel1, test), test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction     1     0
# 1  2704     0
# 0  1154 19290
# 
# Accuracy : 0.9501          
# 95% CI : (0.9473, 0.9529)
# No Information Rate : 0.8333          
# P-Value [Acc > NIR] : < 2.2e-16       
# 
# Kappa : 0.7961          
# 
# Mcnemar's Test P-Value : < 2.2e-16       
#                                           
#             Sensitivity : 0.7009          
#             Specificity : 1.0000          
#          Pos Pred Value : 1.0000          
#          Neg Pred Value : 0.9436          
#              Prevalence : 0.1667          
#          Detection Rate : 0.1168          
#    Detection Prevalence : 0.1168          
#       Balanced Accuracy : 0.8504          
#                                           
#        'Positive' Class : 1

#Varaibles plot to show the most important features
varImpPlot(rfmodel1)

#Save the model
save(rfmodel1, file = "rfmodel1")


#Create ROC curves
#output class probabilities:
rfmodel1_probs <- predict(rfmodel1, newdata = test, type = 'prob')
#output class labels:
rfmodel1_classes <- predict(rfmodel1, newdata = test, type = 'response')

#combine ground truth into dataframe
rfmodel1_pred <- cbind(test$READ_CASES.x, rfmodel1_classes, rfmodel1_probs)

#Change the names
colnames(rfmodel1_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(rfmodel1_pred)

class(rfmodel1_pred)
#For some reason it is not a data frame!
#Change to data frame
rfmodel1_pred <- as.data.frame(rfmodel1_pred)

#Plot the ROC curve
rfmodel1_pred %>%
  roc_curve(test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Calculate AUC
rfmodel1_pred %>%
  roc_auc(test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.962

#Remove temporary objects
rm(rfmodel1_probs, rfmodel1_classes)


####################
#SVM model #takes A LONG TIME TO RUN (days) #May cause fatal error
svmFit1 <- train(READ_CASES.x~., data = train, method = 'svmLinear') #NEED TO ADD k-CROSSFOLD
svmFit1

confusionMatrix(predict(svmFit1, test), test$READ_CASES.x)


####################
#Naive Bayes
nbFit <- naiveBayes(READ_CASES.x~., data = train)
nbFit
# Naive Bayes Classifier for Discrete Predictors
# 
# Call:
#   naiveBayes.default(x = X, y = Y, laplace = laplace)
# 
# A-priori probabilities:
#   Y
# 1         0 
# 0.1666667 0.8333333

confusionMatrix(predict(nbFit, test), test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction     1     0
# 1  2744 12510
# 0  1114  6780
# 
# Accuracy : 0.4114          
# 95% CI : (0.4051, 0.4178)
# No Information Rate : 0.8333          
# P-Value [Acc > NIR] : 1               
# 
# Kappa : 0.0288          
# 
# Mcnemar's Test P-Value : <2e-16          
#                                           
#             Sensitivity : 0.7112          
#             Specificity : 0.3515          
#          Pos Pred Value : 0.1799          
#          Neg Pred Value : 0.8589          
#              Prevalence : 0.1667          
#          Detection Rate : 0.1185          
#    Detection Prevalence : 0.6590          
#       Balanced Accuracy : 0.5314          
#                                           
#        'Positive' Class : 1

#Save the model
save(nbFit, file = "nbFit")

#Create ROC curves
#output class probabilities:
nbFit_probs <- predict(nbFit, newdata = test, type = 'raw')
#output class labels:
nbFit_classes <- predict(nbFit, newdata = test, type = 'class')

#combine ground truth into dataframe
nbFit_pred <- cbind(test$READ_CASES.x, nbFit_classes, nbFit_probs)

#Change the names
colnames(nbFit_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(nbFit_pred)

class(nbFit_pred)
#For some reason it is not a data frame!
#Change to data frame
nbFit_pred <- as.data.frame(nbFit_pred)

#Plot the ROC curve
nbFit_pred %>%
  roc_curve(test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Calculate AUC
nbFit_pred %>%
  roc_auc(test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.557

#Remove temporary objects
rm(nbFit_probs, nbFit_classes)


####################
#Decision Trees
dtFit1 <- rpart(READ_CASES.x~., data = train, method = 'class')

#Create a decision tree plot
rpart.plot(dtFit1)

dt_pd <- predict(dtFit1, test, type = 'class')
table(predicted = dt_pd, observed = test$READ_CASES.x)
# observed
# predicted     1     0
# 1  2270     0
# 0  1588 19290

#This gives an accuracy of 0.9314, sensitivity:0.7943, specificity: 1.0000

save(dtFit1, file = 'dtFit1')

#Create ROC curves
#output class probabilities:
dtFit1_probs <- predict(dtFit1, newdata = test, type = 'prob')
#output class labels:
dtFit1_classes <- predict(dtFit1, newdata = test, type = 'class')

#combine ground truth into dataframe
dtFit1_pred <- cbind(test$READ_CASES.x, dtFit1_classes, dtFit1_probs)

#Change the names
colnames(dtFit1_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(dtFit1_pred)

class(dtFit1_pred)
#For some reason it is not a data frame!
#Change to data frame
dtFit1_pred <- as.data.frame(dtFit1_pred)

#Plot the ROC curve
dtFit1_pred %>%
  roc_curve(test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Calculate AUC
dtFit1_pred %>%
  roc_auc(test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.892

#Remove temporary objects
rm(dtFit1_probs, dtFit1_classes)






