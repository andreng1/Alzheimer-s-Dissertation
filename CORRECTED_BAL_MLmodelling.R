#952781 - Andre Chor Him Ng
#SAIL Project ID: SAIL1074V
#File created on: 2nd September, 2021, CORRECTED ON :14/09/21


#NOTE: THIS IS A NEAR CARBON COPY SCRIPT TO THE OTHER R SCRIPT CALLED
#MLmodelling.R, WITH MINOR ADJUSTMENTS FOR INPUTING THE BALANCED DATASET
#INSTEAD (1 to 1 case control ratio)


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
library(ggplot2)
library(e1071)

#Set working directory
setwd("P:/ngc/workspace/CORRECTED Alzheimer's dissertation/CORRECTED R Scripts and Results")

#Log in to the SAIL database
source("sail_login.r")

#Loading the dataset prepared from SQL onto R
bal_case_ctrl <- sqlQuery(channel, "SELECT * FROM SAILW1074V.C_CASE_CTRL_FEATURES_BAL")


#################
#Part 1: Finish preparing the table for modelling

#Cast/Pivot the tables to a wide format
#Casting a temporary table that shows the event count per event code & ALF_PE
bal_temp1 <- dcast(bal_case_ctrl, ALF_PE + GNDR_CD + YOB + DEP_SCORE + CASES + GROUP_ID ~ EVENT_CD,
               value.var = c("EVENT_COUNT"))
#Casting a 2nd temporary table that shows the event count per average event value & ALF_PE
bal_temp2 <- dcast(bal_case_ctrl, ALF_PE + GNDR_CD + YOB + DEP_SCORE + CASES + GROUP_ID ~ EVENT_CD,
               value.var = c("AVG_EVT_VAL"))
#This had to be done because 'value.var = c("EVENT_COUNT","AVG_EVT_VAL")' generates an error

#Imputing 0 into temp1 in case the event counts are null or NA
bal_temp1[is.na(bal_temp1)] <- 0

#Removing columns in temp2 that are completely null or NA
bal_temp2 <- bal_temp2[,colSums(is.na(bal_temp2))<nrow(bal_temp2)]
#17 columns removed (including "Z.y" which should be completely null anyway as it was used
#to denote this particular ALF_PE did not have any of the most commonly found read codes

#Imputing median by cases and by controls separately
#Further splitting temp2 into only cases and controls
bal_temp2case <- bal_temp2 %>% filter(CASES == 1)
bal_temp2ctrl <- bal_temp2 %>% filter(CASES == 0)
#Removing columns with more than 50% rows with NA
bal_temp2case <- bal_temp2case[,colSums(is.na(bal_temp2case))<(nrow(bal_temp2case)/2)]
bal_temp2ctrl <- bal_temp2ctrl[,colSums(is.na(bal_temp2ctrl))<(nrow(bal_temp2ctrl)/2)]
#Impute median
#1st) Create a function that imputes NA rows with median
med_func <- function(x){
  x[is.na(x)] <- median(x, na.rm = TRUE)
  x
}
#2nd Apply function to each table
bal_temp2case <- data.frame(apply(bal_temp2case, 2, med_func))
bal_temp2ctrl <- data.frame(apply(bal_temp2ctrl, 2, med_func))
#Join tables back together
bal_temp2 <- bind_rows(bal_temp2case, bal_temp2ctrl)
#There are no columns that is imputed in controls but NA in cases, or vice versa

#This leaves 34 columns in temp2
#Remove the tables that are no longer useful from R
rm(bal_temp2case, bal_temp2ctrl)

#The two temporary tables need to be joined back together so that both event count
#and average event value are shown
bal_case_ctrl_wide <- merge(bal_temp1, bal_temp2, by = "ALF_PE")

#Deleting the duplicate columns
bal_case_ctrl_wide <- select(bal_case_ctrl_wide, -c(GNDR_CD.y, YOB.y, DEP_SCORE.y, CASES.y, GROUP_ID.y, Z))

#Renaming the columns because after the joining there are ".x" and "X" in the column names
#Note: ".x" is removed, whereas "X" is replaced with "VAL_" denoting its the average event value
bal_case_ctrl_wide <- bal_case_ctrl_wide %>% rename_with(~ gsub('X', 'VAL_', .x))

#Check the classes
View(lapply(bal_case_ctrl_wide,class))
#The response variable needs to be changed into a factor
#(allows algorithms like random forest to assume classification instead of regression)
bal_case_ctrl_wide$CASES.x <- as.factor(bal_case_ctrl_wide$CASES.x)
#Check factor level
levels(bal_case_ctrl_wide$CASES.x)
#Result: "0" "1"
#Needs to change positive class to 1 (aka the result should be "1" "0" instead)
bal_case_ctrl_wide$CASES.x <- fct_relevel(bal_case_ctrl_wide$CASES.x, "1", "0")
#Check again
levels(bal_case_ctrl_wide$CASES.x)
#Result: "1", "0"

#Remove the unnecessary columns
#detach("package:MASS", unload = TRUE) #might need to detach the package MASS to avoid errors
bal_case_ctrl_wide2 <- select(bal_case_ctrl_wide, -c(ALF_PE, GNDR_CD.x, YOB.x, 
                                             DEP_SCORE.x))


#Renaming the columns to start with "READ_" because some columns have read
#codes as their names, which starts with a number, which in turn
#causes problems for the randomForest package
colnames(bal_case_ctrl_wide2) <- paste0("READ_", colnames(bal_case_ctrl_wide2)) 


#################
#Part 2: Split the data in two (Train & test)
#As the cases are individually matched with five other controls, test and train
#data need to be split via group ID. 
#Note: each control were randomly selected to each cases.

#1st) Create the train test split (75% train, 25 % test)
#Note: Shown originally on SQL, there were 15429 groups (aka 15429 GROUP_IDs)
bal_bound <- floor((15429/4)*3)

#Shuffle the data
#2nd) Create a new data frame with shuffled group IDs
bal_random_ID <- data.frame(READ_GROUP_ID.x = sample(15429))

#3rd) Create test and train data frames from the shuffled data frame (random_ID)
#and split the number of group IDS by a 75% to 25% ratio
bal_train <- data.frame(READ_GROUP_ID.x = bal_random_ID[1:bal_bound,])
bal_test <- data.frame(READ_GROUP_ID.x = bal_random_ID[(bal_bound+1):nrow(bal_random_ID),])

#4th) Inner join the train and test data frames back with the case_ctrl_features
#table to retrieve the rest of the columns
bal_train <- merge(bal_case_ctrl_wide2, bal_train, by = 'READ_GROUP_ID.x')
bal_test <- merge(bal_case_ctrl_wide2, bal_test, by = 'READ_GROUP_ID.x')

#5th) Remove the READ_GROUP_ID.x column (Becuase it is not a response variable 
#or risk factor) & READ_Z.x because it is zero for all rows as it was used
#to denote 'this ALF_PE did not have any of the most frequently found read code'
#detach("package:MASS", unload = TRUE) #unload MASS library if needed
bal_train <- select(bal_train, -c("READ_GROUP_ID.x"))
bal_test <- select(bal_test, -c("READ_GROUP_ID.x"))


#Save the datasets
save(bal_case_ctrl_wide2, bal_test, bal_train, file = "processed_bal_data.Rdata")

#################
#Part 3: Model the data

#Random Forest
#Run the model
bal_rfmodel1 <- randomForest(READ_CASES.x ~., data = bal_train)

#Results:
bal_rfmodel1
# Call:
#   randomForest(formula = READ_CASES.x ~ ., data = bal_train) 
# Type of random forest: classification
# Number of trees: 500
# No. of variables tried at each split: 8
# 
# OOB estimate of  error rate: 12.83%
# Confusion matrix:
#   1     0 class.error
# 1 9927  1644   0.1420793
# 0 1326 10245   0.1145968

#Confusion Matrix to show performance
confusionMatrix(predict(bal_rfmodel1, bal_test), bal_test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction    1    0
# 1 3298  432
# 0  560 3426
# 
# Accuracy : 0.8714          
# 95% CI : (0.8638, 0.8788)
# No Information Rate : 0.5             
# P-Value [Acc > NIR] : < 2.2e-16       
# 
# Kappa : 0.7429          
# 
# Mcnemar's Test P-Value : 5.524e-05       
#                                           
#             Sensitivity : 0.8548          
#             Specificity : 0.8880          
#          Pos Pred Value : 0.8842          
#          Neg Pred Value : 0.8595          
#              Prevalence : 0.5000          
#          Detection Rate : 0.4274          
#    Detection Prevalence : 0.4834          
#       Balanced Accuracy : 0.8714          
#                                           
#        'Positive' Class : 1


#Varaibles plot to show the most important features
varImpPlot(bal_rfmodel1)

#Save the model
save(bal_rfmodel1, file = "bal_rfmodel1")


#Create ROC curves
#output class probabilities:
bal_rfmodel1_probs <- predict(bal_rfmodel1, newdata = bal_test, type = 'prob')
#output class labels:
bal_rfmodel1_classes <- predict(bal_rfmodel1, newdata = bal_test, type = 'response')

#combine ground truth into dataframe
bal_rfmodel1_pred <- cbind(bal_test$READ_CASES.x, bal_rfmodel1_classes, bal_rfmodel1_probs)

#Change the names
colnames(bal_rfmodel1_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(bal_rfmodel1_pred)

class(bal_rfmodel1_pred)
#For some reason it is not a data frame!
#Change to data frame
bal_rfmodel1_pred <- as.data.frame(bal_rfmodel1_pred)

#Plot the ROC curve
bal_rfmodel1_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Caculate AUC
bal_rfmodel1_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.963

#Remove the temporary objects
rm(bal_rfmodel1_probs, bal_rfmodel1_classes)


###
#Tune the random forest model with k-cross fold 
#Create "control" as k-cross fold validation
bal_control10 <- trainControl(method = 'cv', number = '10', savePredictions = 'TRUE', 
                        classProbs = 'TRUE', search = 'random')
#Train the model again
bal_rfmodel3 <- randomForest(READ_CASES.x ~., data = bal_train, trControl = bal_control10,
                             tuneLength = 20)
#Results:
bal_rfmodel3
# Call:
#   randomForest(formula = READ_CASES.x ~ ., data = bal_train, trControl = bal_control10,      tuneLength = 20) 
# Type of random forest: classification
# Number of trees: 500
# No. of variables tried at each split: 8
# 
# OOB estimate of  error rate: 13.12%
# Confusion matrix:
#   1     0 class.error
# 1 9934  1637   0.1414744
# 0 1399 10172   0.1209057

confusionMatrix(predict(bal_rfmodel3, bal_test), bal_test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction    1    0
# 1 3309  442
# 0  549 3416
# 
# Accuracy : 0.8716         
# 95% CI : (0.8639, 0.879)
# No Information Rate : 0.5            
# P-Value [Acc > NIR] : < 2.2e-16      
# 
# Kappa : 0.7431         
# 
# Mcnemar's Test P-Value : 0.0007594      
#                                          
#             Sensitivity : 0.8577         
#             Specificity : 0.8854         
#          Pos Pred Value : 0.8822         
#          Neg Pred Value : 0.8615         
#              Prevalence : 0.5000         
#          Detection Rate : 0.4288         
#    Detection Prevalence : 0.4861         
#       Balanced Accuracy : 0.8716         
#                                          
#        'Positive' Class : 1 

#Variables plot to show the most important features
varImpPlot(bal_rfmodel3)

#Save the model
save(bal_rfmodel3, file = "bal_rfmodel3")

#Create ROC curves
#output class probabilities:
bal_rfmodel3_probs <- predict(bal_rfmodel3, newdata = bal_test, type = 'prob')
#output class labels:
bal_rfmodel3_classes <- predict(bal_rfmodel3, newdata = bal_test, type = 'response')

#combine ground truth into dataframe
bal_rfmodel3_pred <- cbind(bal_test$READ_CASES.x, bal_rfmodel3_classes, bal_rfmodel3_probs)

#Change the names
colnames(bal_rfmodel3_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(bal_rfmodel3_pred)

class(bal_rfmodel3_pred)
#For some reason it is not a data frame!
#Change to data frame
bal_rfmodel3_pred <- as.data.frame(bal_rfmodel3_pred)

#Plot the ROC curve
bal_rfmodel3_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Caculate AUC
bal_rfmodel3_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.963

#Remove temporary objects
rm(bal_rfmodel3_probs, bal_rfmodel3_classes)

#The bal_rfmodel3 has veery similar results to bal_rfmodel1, but its has k=10 to
#avoid overfitting therefore it will be used to be improved upon 



####################
#SVM model #takes A LONG TIME TO RUN (~2 to 4 days) AND MIGHT CRASH THE PROGRAM
bal_svmFit1 <- train(READ_CASES.x~., data = bal_train, method = 'svmLinear') #NEED TO ADD K-CROSS FOLD
bal_svmFit1

confusionMatrix(predict(bal_svmFit1, bal_test), bal_test$READ_CASES.x)


save(bal_svmFit1, file = "bal_svmFit1")


#PROBLEM: TO RUN THE ROC CURVE I NEED TO RERUN THE SVM MODEL AGAIN WITH
bal_svmFit2 <- train(READ_CASES.x~., data = bal_train, method = 'svmLinear', 
                     trControl(method = 'cv', repeats = 3, classProbs = TRUE))

#Create ROC curves
#output class probabilities:
#bal_svmFit1_probs <- predict(bal_svmFit1, newdata = bal_test, type = 'prob')
# #output class labels:
# bal_svmFit1_classes <- predict(bal_svmFit1, newdata = bal_test, type = 'class')
# 
# #combine ground truth into dataframe
# bal_svmFit1_pred <- cbind(bal_test$READ_CASES.x, bal_svmFit1_classes, bal_svmFit1_probs)
# 
# #Change the names
# colnames(bal_svmFit1_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes') #Is it the other way round? probYes,probNo?
# head(bal_svmFit1_pred)
# 
# #Plot the ROC curve
# bal_svmFit1_pred %>%
#   roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
#   autoplot()
# 
# #Calculate AUC
# bal_svmFit1_pred %>%
#   roc_auc(bal_test$READ_CASES.x, 'probNo')

####################
#Naive Bayes
bal_nbFit <- naiveBayes(READ_CASES.x~., data = bal_train)
bal_nbFit
# Naive Bayes Classifier for Discrete Predictors
# 
# Call:
#   naiveBayes.default(x = X, y = Y, laplace = laplace)
# 
# A-priori probabilities:
#   Y
# 1   0 
# 0.5 0.5 

confusionMatrix(predict(bal_nbFit, bal_test), bal_test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction    1    0
# 1  241  224
# 0 3617 3634
# 
# Accuracy : 0.5022         
# 95% CI : (0.491, 0.5134)
# No Information Rate : 0.5            
# P-Value [Acc > NIR] : 0.3536         
# 
# Kappa : 0.0044         
# 
# Mcnemar's Test P-Value : <2e-16         
#                                          
#             Sensitivity : 0.06247        
#             Specificity : 0.94194        
#          Pos Pred Value : 0.51828        
#          Neg Pred Value : 0.50117        
#              Prevalence : 0.50000        
#          Detection Rate : 0.03123        
#    Detection Prevalence : 0.06026        
#       Balanced Accuracy : 0.50220        
#                                          
#        'Positive' Class : 1 

#Save the model
save(bal_nbFit, file = "bal_nbFit")

#Create ROC curves
#Output class probabilities:
bal_nbFit_probs <- predict(bal_nbFit, newdata = bal_test, type = 'raw')
#output class labels:
bal_nbFit_classes <- predict(bal_nbFit, newdata = bal_test, type = 'class')

#combine ground truth into dataframe
bal_nbFit_pred <- cbind(bal_test$READ_CASES.x, bal_nbFit_classes, bal_nbFit_probs)

#Change the names
colnames(bal_nbFit_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(bal_nbFit_pred)

class(bal_nbFit_pred)
#For some reason it is not a data frame!
#Change to data frame
bal_nbFit_pred <- as.data.frame(bal_nbFit_pred)

#Plot the ROC curve
bal_nbFit_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Calculate AUC
bal_nbFit_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.556

#Remove the temporary objects
rm(bal_nbFit_probs, bal_nbFit_classes)

####################
#GLM - Generalised Linear model
bal_glmFit1 <- train(READ_CASES.x~., data = bal_train, method = 'glm')
bal_glmFit1
# Generalized Linear Model 
# 
# 23142 samples
# 78 predictor
# 2 classes: '1', '0' 
# 
# No pre-processing
# Resampling: Bootstrapped (25 reps) 
# Summary of sample sizes: 23142, 23142, 23142, 23142, 23142, 23142, ... 
# Resampling results:
#   
#   Accuracy   Kappa    
# 0.5689097  0.1379725

confusionMatrix(predict(bal_glmFit1, bal_test), bal_test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction    1    0
# 1 2452 1894
# 0 1406 1964
# 
# Accuracy : 0.5723          
# 95% CI : (0.5612, 0.5834)
# No Information Rate : 0.5             
# P-Value [Acc > NIR] : < 2.2e-16       
# 
# Kappa : 0.1446          
# 
# Mcnemar's Test P-Value : < 2.2e-16       
#                                           
#             Sensitivity : 0.6356          
#             Specificity : 0.5091          
#          Pos Pred Value : 0.5642          
#          Neg Pred Value : 0.5828          
#              Prevalence : 0.5000          
#          Detection Rate : 0.3178          
#    Detection Prevalence : 0.5632          
#       Balanced Accuracy : 0.5723          
#                                           
#        'Positive' Class : 1    

#Save the model
save(bal_glmFit1, file = "bal_glmFit1")

#Create ROC curves
#Output class probabilities:
bal_glmFit1_probs <- predict(bal_glmFit1, newdata = bal_test, type = 'prob')
#output class labels:
bal_glmFit1_classes <- predict(bal_glmFit1, newdata = bal_test, type = 'raw')

#combine ground truth into dataframe
bal_glmFit1_pred <- cbind(bal_test$READ_CASES.x, bal_glmFit1_classes, bal_glmFit1_probs)

#Change the names
colnames(bal_glmFit1_pred) <- c('Observed', 'Predicted', 'probAD', 'probCTRL')
head(bal_glmFit1_pred)

class(bal_glmFit1_pred)

#Plot the ROC curve
bal_glmFit1_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probAD') %>%
  autoplot()

#Calculate AUC
bal_glmFit1_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probAD')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.603

#Remove the temporary objects
rm(bal_glmFit1_probs, bal_glmFit1_classes)


####################
#Generalised Logistic Model (ALSO GLM, nameed glgm for moree clarity)
bal_glgmFit1 <- glm(READ_CASES.x~., data = bal_train, family = 'binomial')
summary(bal_glgmFit1)
# Call:
#   glm(formula = READ_CASES.x ~ ., family = "binomial", data = bal_train)
# 
# Deviance Residuals: 
#   Min       1Q   Median       3Q      Max  
# -3.0410  -1.1272  -0.1081   1.1706   2.3261  
# 
# Coefficients:
#   Estimate Std. Error z value Pr(>|z|)    
# (Intercept)    -2.157e+00  6.988e-01  -3.087  0.00202 ** 
#   READ_1371.      2.387e-02  2.889e-03   8.262  < 2e-16 ***
#   READ_22A..     -1.429e-02  4.359e-03  -3.278  0.00105 ** 
#   READ_22K..      5.365e-03  3.972e-03   1.350  0.17688    
# READ_246..      3.753e-03  7.450e-04   5.038 4.71e-07 ***
#   READ_4....     -4.208e-04  6.291e-04  -0.669  0.50360    
# READ_423..      5.075e-03  9.026e-03   0.562  0.57390    
# READ_424..      8.933e-04  2.938e-03   0.304  0.76112    
# READ_426..     -4.515e-02  8.073e-03  -5.592 2.24e-08 ***
#   READ_428..      9.847e-03  8.671e-03   1.136  0.25610    
# READ_42A..      2.125e-02  1.344e-02   1.582  0.11373    
# READ_42H..     -1.319e-02  6.190e-03  -2.132  0.03304 *  
#   READ_42J..      2.477e-03  1.820e-02   0.136  0.89178    
# READ_42K..     -1.379e-02  1.242e-02  -1.110  0.26710    
# READ_42L..      1.895e-02  7.815e-03   2.425  0.01530 *  
#   READ_42M..     -1.859e-03  1.267e-02  -0.147  0.88333    
# READ_42N..      1.830e-02  1.494e-02   1.225  0.22062    
# READ_42P..      1.409e-03  1.267e-02   0.111  0.91146    
# READ_42QE.      3.034e-04  4.186e-04   0.725  0.46855    
# READ_44E..     -1.478e-03  3.155e-03  -0.468  0.63945    
# READ_44F..     -1.294e-02  5.695e-03  -2.272  0.02306 *  
#   READ_44G3.      8.255e-03  3.349e-03   2.465  0.01370 *  
#   READ_44I4.      8.088e-03  1.865e-02   0.434  0.66455    
# READ_44I5.     -1.497e-02  1.841e-02  -0.813  0.41604    
# READ_44J3.      5.399e-03  3.634e-03   1.486  0.13734    
# READ_44J9.     -6.463e-03  3.521e-03  -1.836  0.06639 .  
# READ_44M3.      4.999e-03  4.826e-03   1.036  0.30033    
# READ_44M4.      4.880e-03  6.339e-03   0.770  0.44139    
# READ_44M5.     -1.142e-03  2.831e-03  -0.403  0.68670    
# READ_44P..      7.526e-03  4.156e-03   1.811  0.07012 .  
# READ_44P5.      1.381e-02  5.901e-03   2.341  0.01923 *  
#   READ_44P6.      4.334e-03  7.451e-03   0.582  0.56079    
# READ_44Q..     -1.669e-02  5.330e-03  -3.131  0.00174 ** 
#   READ_451E.     -4.766e-03  2.943e-03  -1.619  0.10540    
# READ_65E..      2.119e-03  2.160e-03   0.981  0.32648    
# READ_9N11.      2.644e-04  5.321e-04   0.497  0.61929    
# READ_a6b1.     -4.779e-05  6.213e-04  -0.077  0.93869    
# READ_a6c3.      9.908e-04  6.835e-04   1.450  0.14715    
# READ_b211.      1.293e-06  3.625e-04   0.004  0.99715    
# READ_b312.     -1.721e-03  6.344e-04  -2.713  0.00666 ** 
#   READ_bd35.      2.039e-04  4.591e-04   0.444  0.65691    
# READ_blb1.      1.593e-03  5.940e-04   2.682  0.00731 ** 
#   READ_bu23.     -1.448e-04  4.570e-04  -0.317  0.75140    
# READ_bu2c.     -6.284e-04  5.451e-04  -1.153  0.24895    
# READ_bxd2.     -9.392e-04  5.638e-04  -1.666  0.09574 .  
# READ_bxd5.     -1.130e-03  5.774e-04  -1.957  0.05035 .  
# READ_di21.     -1.522e-03  5.692e-04  -2.674  0.00749 ** 
#   READ_dia2.     -1.820e-03  8.844e-04  -2.058  0.03959 *  
#   READ_f41y.     -3.565e-03  7.562e-04  -4.714 2.43e-06 ***
#   READ_f922.     -3.764e-04  6.088e-04  -0.618  0.53639    
# READ_f923.      5.720e-04  5.170e-04   1.106  0.26855    
# READ_VAL_22A..  1.013e-02  1.060e-03   9.560  < 2e-16 ***
#   READ_VAL_22K.. -3.705e-06  3.304e-06  -1.121  0.26211    
# READ_VAL_246.. -8.749e-09  9.756e-09  -0.897  0.36985    
# READ_VAL_423..  7.815e-04  9.093e-04   0.859  0.39013    
# READ_VAL_426.. -1.304e-03  2.047e-03  -0.637  0.52410    
# READ_VAL_428..  3.231e-03  1.037e-02   0.312  0.75528    
# READ_VAL_42A.. -9.140e-03  4.002e-03  -2.284  0.02237 *  
#   READ_VAL_42H.. -1.342e-02  7.061e-03  -1.901  0.05730 .  
# READ_VAL_42J.. -2.482e-02  5.427e-03  -4.573 4.81e-06 ***
#   READ_VAL_42K.. -4.896e-05  3.420e-03  -0.014  0.98858    
# READ_VAL_42L.. -4.711e-02  1.393e-01  -0.338  0.73520    
# READ_VAL_42M..  4.586e-02  8.509e-03   5.390 7.04e-08 ***
#   READ_VAL_42N..  1.467e-02  4.079e-02   0.360  0.71913    
# READ_VAL_42P..  9.498e-04  2.505e-04   3.791  0.00015 ***
#   READ_VAL_44E..  3.777e-03  3.407e-03   1.109  0.26758    
# READ_VAL_44F..  2.365e-03  3.887e-04   6.085 1.16e-09 ***
#   READ_VAL_44G3.  6.646e-03  1.345e-03   4.942 7.72e-07 ***
#   READ_VAL_44I4. -5.637e-02  2.211e-02  -2.549  0.01079 *  
#   READ_VAL_44I5.  1.291e-02  4.222e-03   3.059  0.00222 ** 
#   READ_VAL_44J3. -2.430e-03  9.415e-04  -2.581  0.00984 ** 
#   READ_VAL_44J9.  7.345e-02  1.140e-02   6.441 1.19e-10 ***
#   READ_VAL_44M3. -1.098e-02  4.376e-03  -2.510  0.01209 *  
#   READ_VAL_44M4.  1.472e-02  5.707e-03   2.579  0.00990 ** 
#   READ_VAL_44P.. -6.308e-04  1.081e-03  -0.583  0.55965    
# READ_VAL_44P5.  3.448e-03  1.658e-02   0.208  0.83531    
# READ_VAL_44P6. -1.022e-02  1.960e-02  -0.521  0.60203    
# READ_VAL_44Q..  2.285e-02  1.635e-02   1.397  0.16239    
# READ_VAL_451E. -7.622e-04  1.189e-03  -0.641  0.52141    
# ---
#   Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
# 
# (Dispersion parameter for binomial family taken to be 1)
# 
# Null deviance: 32082  on 23141  degrees of freedom
# Residual deviance: 31406  on 23063  degrees of freedom
# AIC: 31564
# 
# Number of Fisher Scoring iterations: 5

bal_glgm_pd <- predict(bal_glgmFit1, bal_test, type = 'response')
table(predicted = as.numeric(bal_glgm_pd>0.5), observed = bal_test$READ_CASES.x)
# observed
# predicted    1    0
# 0 2452 1894
# 1 1406 1964

#Which would amount to:
#Accuracy: 0.5723, Sensitivity: 0.6356, Specificity: 0.4909

#Save the model
save(bal_glgmFit1, file = "bal_glgmFit1")

#Create ROC curves
#Output class probabilities:
bal_glgmFit1_probs <- predict(bal_glgmFit1, newdata = bal_test, type = 'response')

bal_glgmFit1_pred <- roc(bal_test$READ_CASES.x~bal_glgmFit1_probs, levels = c(1, 0))
plot(bal_glgmFit1_pred)


#Get AUC
bal_glgmFit1_pred
# Call:
#   roc.formula(formula = bal_test$READ_CASES.x ~ bal_glgmFit1_probs,     levels = c(1, 0))
# 
# Data: bal_glgmFit1_probs in 3858 controls (bal_test$READ_CASES.x 1) < 3858 cases (bal_test$READ_CASES.x 0).
# Area under the curve: 0.6029

#Remove the temporary objects
rm(bal_glgmFit1_probs)

####################
#Decision Trees
bal_dtFit1 <- rpart(READ_CASES.x~., data = bal_train, method = 'class')
summary(bal_dtFit1)
# Call:
#   rpart(formula = READ_CASES.x ~ ., data = bal_train, method = "class")
# n= 23142 
# 
# CP nsplit rel error    xerror        xstd
# 1 0.41595368      0 1.0000000 1.0134820 0.006572946
# 2 0.03953850      1 0.5840463 0.5842192 0.005978407
# 3 0.02895169      3 0.5049693 0.5057471 0.005714501
# 4 0.01339556      5 0.4470659 0.4500907 0.005490384
# 5 0.01041397      6 0.4336704 0.4360038 0.005428284
# 6 0.01000000      8 0.4128425 0.4243367 0.005375100
# 
# Variable importance
# READ_VAL_44G3.     READ_44G3. READ_VAL_44E..     READ_44F..     READ_451E.     READ_44M4.     READ_44M3.     READ_44J9. 
# 26             15              9              7              7              7              5              4 
# READ_VAL_44P5. READ_VAL_44Q.. READ_VAL_44M3. READ_VAL_44P6.     READ_44E.. READ_VAL_44J9. 
# 4              3              3              3              3              2 

#Create a decision tree plot
rpart.plot(bal_dtFit1)

bal_dt_pd <- predict(bal_dtFit1, bal_test, type = 'class')
table(predicted = bal_dt_pd, observed = bal_test$READ_CASES.x)
# observed
# predicted    1    0
# 1 2479  190
# 0 1379 3668

#This gives an accuracy of: 0.7967, sensitivity: 0.6426, specificity:0.9508 

#Create ROC curves
#Output class probabilities:
bal_dtFit1_probs <- predict(bal_dtFit1, newdata = bal_test, type = 'prob')
#output class labels:
bal_dtFit1_classes <- predict(bal_dtFit1, newdata = bal_test, type = 'class')

#combine ground truth into dataframe
bal_dtFit1_pred <- cbind(bal_test$READ_CASES.x, bal_dtFit1_classes, bal_dtFit1_probs)

#Change the names
colnames(bal_dtFit1_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(bal_dtFit1_pred)

class(bal_dtFit1_pred)
#For some reason it is not a data frame!
#Change to data frame
bal_dtFit1_pred <- as.data.frame(bal_dtFit1_pred)

#Plot the ROC curve
bal_dtFit1_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Calculate AUC
bal_dtFit1_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.887

#Remove the temporary objects
rm(bal_dtFit1_probs, bal_dtFit1_classes)


###
#Details on complexity parameter
printcp(bal_dtFit1)
# Classification tree:
#   rpart(formula = READ_CASES.x ~ ., data = bal_train, method = "class")
# 
# Variables actually used in tree construction:
#   [1] READ_44E..     READ_44G3.     READ_44J9.     READ_VAL_44E.. READ_VAL_44G3. READ_VAL_44J9.
# 
# Root node error: 11571/23142 = 0.5
# 
# n= 23142 
# 
# CP nsplit rel error  xerror      xstd
# 1 0.415954      0   1.00000 1.01348 0.0065729
# 2 0.039539      1   0.58405 0.58422 0.0059784
# 3 0.028952      3   0.50497 0.50575 0.0057145
# 4 0.013396      5   0.44707 0.45009 0.0054904
# 5 0.010414      6   0.43367 0.43600 0.0054283
# 6 0.010000      8   0.41284 0.42434 0.0053751

#Plot complexity parameter 
plotcp(bal_dtFit1)


#############################################################################
#Feature selection
#As bal_rfmodel3 and bal_dtFit1 performed best, their features will be looked
#into, removing features that are not useful, in an attempt to improve their model 
#performance 

######################
#Random forest (bal_rfmodel3)
#1st) Create a list of variables with their relative importance
bal_rfmodel3_varImp <- as.data.frame(varImp(bal_rfmodel3))
#2nd)Order them by importance
bal_rfmodel3_varImp <- bal_rfmodel3_varImp %>% arrange(desc(Overall))
#3rd) Extract the most important variables
View(bal_rfmodel3_varImp) 

#4th) Create a training dataset with only these variables
#(Variable importance with 70 or higher)
bal_rf_train <- select(bal_train,
                  c('READ_CASES.x', #Adding the cases column too
                    'READ_VAL_44E..',
                    'READ_VAL_44G3.',
                    'READ_VAL_451E.',
                    'READ_VAL_44J9.',
                    'READ_44E..',
                    'READ_44G3.',
                    'READ_VAL_44P6.',
                    'READ_44J9.',
                    'READ_VAL_44Q..',
                    'READ_VAL_44P5.',
                    'READ_451E.',
                    'READ_VAL_426..',
                    'READ_44P6.',
                    'READ_VAL_44M3.',
                    'READ_VAL_42J..',
                    'READ_44P5.',
                    'READ_VAL_44F..',
                    'READ_VAL_44P..',
                    'READ_VAL_42K..',
                    'READ_44Q..',
                    'READ_VAL_22K..',
                    'READ_VAL_44I5.',
                    'READ_VAL_42M..',
                    'READ_VAL_42N..',
                    'READ_VAL_423..',
                    'READ_VAL_42H..',
                    'READ_VAL_44M4.',
                    'READ_VAL_428..',
                    'READ_VAL_42P..',
                    'READ_44P..',
                    'READ_44J3.',
                    'READ_VAL_22A..',
                    'READ_VAL_44J3.',
                    'READ_246..',
                    'READ_VAL_42A..',
                    'READ_44I5.',
                    'READ_44M3.',
                    'READ_VAL_44I4.',
                    'READ_VAL_246..',
                    'READ_44F..',
                    'READ_44I4.',
                    'READ_44M4.',
                    'READ_42P..',
                    'READ_42J..',
                    'READ_42M..',
                    'READ_42K..',
                    'READ_42A..',
                    'READ_426..',
                    'READ_428..',
                    'READ_42N..',
                    'READ_22K..',
                    'READ_22A..',
                    'READ_423..',
                    'READ_VAL_42L..',
                    'READ_42H..'))

#5th) Train a new model with this data
bal_rfmodel3A <- randomForest(READ_CASES.x ~., data = bal_rf_train, trControl = bal_control10,
                             tuneLength = 20)
#Results:
bal_rfmodel3A
# Call:
#   randomForest(formula = READ_CASES.x ~ ., data = bal_rf_train,      trControl = bal_control10, tuneLength = 20) 
# Type of random forest: classification
# Number of trees: 500
# No. of variables tried at each split: 7
# 
# OOB estimate of  error rate: 13.18%
# Confusion matrix:
#   1     0 class.error
# 1 9912  1659   0.1433757
# 0 1390 10181   0.1201279

confusionMatrix(predict(bal_rfmodel3A, bal_test), bal_test$READ_CASES.x)
# Confusion Matrix and Statistics
# 
# Reference
# Prediction    1    0
# 1 3316  435
# 0  542 3423
# 
# Accuracy : 0.8734          
# 95% CI : (0.8658, 0.8807)
# No Information Rate : 0.5             
# P-Value [Acc > NIR] : < 2.2e-16       
# 
# Kappa : 0.7468          
# 
# Mcnemar's Test P-Value : 0.0006958       
#                                           
#             Sensitivity : 0.8595          
#             Specificity : 0.8872          
#          Pos Pred Value : 0.8840          
#          Neg Pred Value : 0.8633          
#              Prevalence : 0.5000          
#          Detection Rate : 0.4298          
#    Detection Prevalence : 0.4861          
#       Balanced Accuracy : 0.8734          
#                                           
#        'Positive' Class : 1 

#Variable importance plot
varImpPlot(bal_rfmodel3A)

#Create ROC curves
#output class probabilities:
bal_rfmodel3A_probs <- predict(bal_rfmodel3A, newdata = bal_test, type = 'prob')
#output class labels:
bal_rfmodel3A_classes <- predict(bal_rfmodel3A, newdata = bal_test, type = 'response')

#combine ground truth into dataframe
bal_rfmodel3A_pred <- cbind(bal_test$READ_CASES.x, bal_rfmodel3A_classes, bal_rfmodel3A_probs)

#Change the names
colnames(bal_rfmodel3A_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(bal_rfmodel3A_pred)

class(bal_rfmodel3A_pred)
#For some reason it is not a data frame!
#Change to data frame
bal_rfmodel3A_pred <- as.data.frame(bal_rfmodel3A_pred)

#Plot the ROC curve
bal_rfmodel3A_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Caculate AUC
bal_rfmodel3A_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.964

#Remove temporary objects
rm(bal_rfmodel3A_probs, bal_rfmodel3A_classes)

######################
#Decision Tree (bal_dtFit1)
#1st) Create a list of variables with their relative importance
bal_dtFit1_varImp <- as.data.frame(varImp(bal_dtFit1))
#2nd)Order them by importance
bal_dtFit1_varImp <- bal_dtFit1_varImp %>% arrange(desc(Overall))
#3rd) Extract the most important variables
View(bal_dtFit1_varImp) 


#4th) Create a training dataset with only these variables
#(Variable importance with 70 or higher)
bal_dt_train <- select(bal_train,
                       c('READ_CASES.x', #Add cases column
                         'READ_VAL_44G3.',
                         'READ_VAL_44E..',
                         'READ_VAL_451E.',
                         'READ_44G3.',
                         'READ_VAL_44J9.',
                         'READ_VAL_44P6.',
                         'READ_44M4.',
                         'READ_44J9.',
                         'READ_44E..',
                         'READ_451E.',
                         'READ_VAL_44Q..',
                         'READ_VAL_42J..',
                         'READ_44M3.',
                         'READ_VAL_426..',
                         'READ_426..'))

#Train a second model with this data
bal_dtFit1A <- rpart(READ_CASES.x~., data = bal_dt_train, method = 'class')
#Results:
summary(bal_dtFit1A)
# Call:
#   rpart(formula = READ_CASES.x ~ ., data = bal_dt_train, method = "class")
# n= 23142 
# 
# CP nsplit rel error    xerror        xstd
# 1 0.41595368      0 1.0000000 1.0218650 0.006571972
# 2 0.03953850      1 0.5840463 0.5846513 0.005979705
# 3 0.02895169      3 0.5049693 0.5054879 0.005713532
# 4 0.01339556      5 0.4470659 0.4483623 0.005482887
# 5 0.01041397      6 0.4336704 0.4392015 0.005442581
# 6 0.01000000      8 0.4128425 0.4252874 0.005379494
# 
# Variable importance
# READ_VAL_44G3.     READ_44G3. READ_VAL_44E..     READ_44J9.     READ_451E.     READ_44M4.     READ_44M3. READ_VAL_44J9. 
# 27             16              9              8              7              7              7              5 
# READ_VAL_44Q.. READ_VAL_44P6. READ_VAL_426..     READ_44E.. 
# 3              3              3              3 
# 
# Node number 1: 23142 observations,    complexity param=0.4159537
# predicted class=1  expected loss=0.5  P(node) =1
# class counts: 11571 11571
# probabilities: 0.500 0.500 
# left son=2 (11619 obs) right son=3 (11523 obs)

#Create a decision tree plot
rpart.plot(bal_dtFit1A)

bal_dt_pd2 <- predict(bal_dtFit1A, bal_test, type = 'class')
table(predicted = bal_dt_pd2, observed = bal_test$READ_CASES.x)
# observed
# predicted    1    0
# 1 2479  190
# 0 1379 3668

#This gives an accuracy of: 0.7967, sensitivity: 0.6427, specificity: 0.9508

#Create ROC curves
#Output class probabilities:
bal_dtFit1A_probs <- predict(bal_dtFit1A, newdata = bal_test, type = 'prob')
#output class labels:
bal_dtFit1A_classes <- predict(bal_dtFit1A, newdata = bal_test, type = 'class')

#combine ground truth into dataframe
bal_dtFit1A_pred <- cbind(bal_test$READ_CASES.x, bal_dtFit1A_classes, bal_dtFit1A_probs)

#Change the names
colnames(bal_dtFit1A_pred) <- c('Observed', 'Predicted', 'probNo', 'probYes')
head(bal_dtFit1A_pred)

class(bal_dtFit1A_pred)
#For some reason it is not a data frame!
#Change to data frame
bal_dtFit1A_pred <- as.data.frame(bal_dtFit1A_pred)

#Plot the ROC curve
bal_dtFit1A_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo') %>%
  autoplot()

#Calculate AUC
bal_dtFit1A_pred %>%
  roc_auc(bal_test$READ_CASES.x, 'probNo')
# # A tibble: 1 x 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 roc_auc binary         0.887

#Remove the temporary objects
rm(bal_dtFit1A_probs, bal_dtFit1A_classes)


##############
#Trying to plot multiple ROC curves from the balanced dataset onto the same graph

#First extract the ROC curve values (threshold, specificity, sensitivity) 
#into a separate object for each model
#Random forest
bal_rfmodel1_ROC <- bal_rfmodel1_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo')
#Random forest (k=10)
bal_rfmodel3_ROC <- bal_rfmodel3_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo')
#Decision Tree
bal_dtFit1_ROC <- bal_dtFit1_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo')
#Naive bayes
bal_nbFit_ROC <- bal_nbFit_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probNo')
#GLM
bal_glmFit1_ROC <- bal_glmFit1_pred %>%
  roc_curve(bal_test$READ_CASES.x, 'probAD')
#GLGM
#As generalised logistic model was never able to producee a "_pred" table
#We extract the specificity and sensitivity from the roc object into a new data frame
bal_glgmFit1_ROC <- as.data.frame(bal_glgmFit1_pred$specificities)
bal_glgmFit1_ROC <- bal_glgmFit1_ROC %>%
            mutate(bal_glgmFit1_pred$sensitivities)
colnames(bal_glgmFit1_ROC) <- c('specificity', 'sensitivity')
View(bal_glgmFit1_ROC)

#Plot the graph
all_roc <- ggplot() +
  geom_path(data = bal_rfmodel1_ROC, aes(x = 1 - specificity, y = sensitivity, color = "blue")) +
  geom_path(data = bal_rfmodel3_ROC, aes(x = 1 - specificity, y = sensitivity, color = "red")) +
  geom_path(data = bal_dtFit1_ROC, aes(x = 1 - specificity, y = sensitivity, color = "orange")) +
  geom_path(data = bal_nbFit_ROC, aes(x = 1 - specificity, y = sensitivity, color = "purple")) +
  geom_path(data = bal_glmFit1_ROC, aes(x = 1 - specificity, y = sensitivity, color = "green")) +
  geom_path(data = bal_glgmFit1_ROC, aes(x = 1 - specificity, y = sensitivity, color = "pink")) +
  geom_abline(linetype = 2, slope = 1, intercept = 0) +
  scale_colour_manual(name = "Models (balanced dataset)",
                      breaks = c("blue", "red", "orange", "purple", "green", "pink"),
                      values = c("blue", "red", "orange", "purple", "green", "pink"),
                      labels = c("Random Forest", "Random Forest (k=10)", "Decision Tree", "Naive Bayes",
                                 "Generalised Linear Model", "Generalised Logistic Model"))
print(all_roc)


##########################################
###IGNORE:
#Save workspace often
#save.image()

#Gradient boosted trees
#bal_gbtFit1 <- train(READ_CASES.x~., data = bal_train, method = 'xgbTree')