# The following two commands remove any previously installed H2O packages for R.
if ("package:h2o" %in% search()) { detach("package:h2o", unload=TRUE) }
if ("h2o" %in% rownames(installed.packages())) { remove.packages("h2o") }

# Next, we download packages that H2O depends on.
if (! ("methods" %in% rownames(installed.packages()))) { install.packages("methods") }
if (! ("statmod" %in% rownames(installed.packages()))) { install.packages("statmod") }
if (! ("stats" %in% rownames(installed.packages()))) { install.packages("stats") }
if (! ("graphics" %in% rownames(installed.packages()))) { install.packages("graphics") }
if (! ("RCurl" %in% rownames(installed.packages()))) { install.packages("RCurl") }
if (! ("jsonlite" %in% rownames(installed.packages()))) { install.packages("jsonlite") }
if (! ("tools" %in% rownames(installed.packages()))) { install.packages("tools") }
if (! ("utils" %in% rownames(installed.packages()))) { install.packages("utils") }

# Now we download, install and initialize the H2O package for R.
install.packages("h2o", type="source", repos=(c("http://h2o-release.s3.amazonaws.com/h2o/rel-turing/8/R")))

# Load library
library(h2o)

# Start instance with all cores
h2o.init(nthreads = -1, max_mem_size = "8G")

# Clean state
h2o.removeAll()

# Info about cluster
h2o.clusterInfo()

# Production Cluster (Not applicable because we're using in the same machine)
#localH2O <- h2o.init(ip = '10.112.81.210', port =54321, nthreads=-1) # Server 1
#localH2O <- h2o.init(ip = '10.112.80.74', port =54321, nthreads=-1) # Server 2

# Random Forests

# URL with data
LaymanBrothersURL = "https://raw.githubusercontent.com/fclesio/learning-space/master/Datasets/02%20-%20Classification/default_credit_card.csv"

# Load data 
creditcard.hex = h2o.importFile(path = LaymanBrothersURL, destination_frame = "creditcard.hex")

# Convert DEFAULT, SEX, EDUCATION, MARRIAGE variables to categorical
creditcard.hex[,25] <- as.factor(creditcard.hex[,25]) # DEFAULT
creditcard.hex[,3] <- as.factor(creditcard.hex[,3]) # SEX
creditcard.hex[,4] <- as.factor(creditcard.hex[,4]) # EDUCATION
creditcard.hex[,5] <- as.factor(creditcard.hex[,5]) # MARRIAGE

# Let's see the summary
summary(creditcard.hex)

# We'll get 3 dataframes Train (60%), Test (20%) and Validation (20%)
creditcard.split = h2o.splitFrame(data = creditcard.hex
                                  ,ratios = c(0.6,0.2)
                                  ,destination_frames = c("creditcard.train.hex", "creditcard.test.hex", "creditcard.validation.hex")
                                  ,seed = 12345)

# Get the train dataframe(1st split object)
creditcard.train = creditcard.split[[1]]

# Get the test dataframe(2nd split object)
creditcard.test = creditcard.split[[2]]

# Get the validation dataframe(3rd split object)
creditcard.validation = creditcard.split[[3]]

# Set dependent variable
Y = "DEFAULT"

# Set independent variables
X = c("LIMIT_BAL","EDUCATION","MARRIAGE","AGE"
      ,"PAY_0","PAY_2","PAY_3","PAY_4","PAY_5","PAY_6"
      ,"BILL_AMT1","BILL_AMT2","BILL_AMT3","BILL_AMT4","BILL_AMT5","BILL_AMT6"
      ,"PAY_AMT1","PAY_AMT3","PAY_AMT4","PAY_AMT5","PAY_AMT6")

# Train a model
creditcard.rf <- h2o.randomForest(
                training_frame = creditcard.train
                ,validation_frame = creditcard.validation
                ,x=X
                ,y=Y
                ,model_id = "credit_card_rf_01"
                ,ntrees = 500
                ,max_depth = 50
                ,nbins = 10
                ,mtries = 10
                ,histogram_type = 'AUTO'
                ,min_rows = 5
                ,stopping_rounds = 100
                ,stopping_tolerance = 0.0001
                ,score_each_iteration = T
                ,build_tree_one_node = TRUE
                ,nbins_cats = 3
                ,binomial_double_trees = TRUE
                ,seed = 12345)

# AUC: 77.70%

# Summary of the model
summary(creditcard.rf)

creditcard.rf@model
creditcard.rf@model$training_metrics
creditcard.rf@model$validation_metrics
(creditcard.rf@model$run_time/1000)
creditcard.rf@model$variable_importances 

# Grid Search with Random Forests

# Set hyparameters
search_criteria = list(strategy = "Cartesian")

ntrees_list <- list(50,100,150,200,250,300)

max_depth_list <- list(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20)

min_rows_list <- list(1,2,3,4,5)


# Full list of hyper parameters that will be used
hyper_parameters <- list(ntrees = ntrees_list
                         ,max_depth = max_depth_list
                         ,min_rows = min_rows_list)

rf_grid <- h2o.grid("randomForest" 
                     ,training_frame = creditcard.train
                     ,validation_frame = creditcard.validation
                     ,x=X
                     ,y=Y
                     ,grid_id="rf_credit_card"
                     ,stopping_metric = "AUTO" 
                     ,stopping_rounds = 2
                     ,stopping_tolerance = 1e-2
                     ,score_each_iteration = T
                     ,max_runtime_secs=10000
                     ,seed = 54321
                     ,hyper_params = hyper_parameters
                     ,search_criteria = search_criteria)

# sort the grid models by decreasing AUC
sortedGrid <- h2o.getGrid("rf_credit_card", sort_by="auc", decreasing = TRUE)    

# Let's see our models
sortedGrid

# Grab the model_id based in AUC
best_glm_model_id <- sortedGrid@model_ids[[1]]

# The best model
best_glm <- h2o.getModel(best_glm_model_id)

# Summary
summary(best_glm)

# Some useful metrics
best_glm@model$training_metrics
best_glm@model$validation_metrics
(best_glm@model$run_time/1000)
best_glm@model$variable_importances  

# Some predictions
rf_predictions <- h2o.predict(object = model, newdata = creditcard.test)

rf_predictions
  
# Frame with predictions
dataset_rf_predictions = as.data.frame(rf_predictions)

# Write a csv file
write.csv(dataset_rf_predictions, file = "/Users/flavio.clesio/Desktop/model/dataset_rf_predictions.csv", row.names=TRUE)




  
# Saving the model on the disk
h2o.saveModel(best_glm,"/Users/flavio.clesio/Desktop/model/",force=T)

# Load the model again
loadedModel = h2o.loadModel(path=paste0("/Users/flavio.clesio/Desktop/model","/","rf_credit_card_model_26"))

# Reload the model again and put it in an object
modelReloaded <- h2o.predict(object = loadedModel, newdata = creditcard.test)

# See predictions of the reloaded model
modelReloaded

# See the POJO file of the model
h2o.download_pojo(best_glm)

# Shutdown the cluster 
h2o.shutdown()

# Are you sure you want to shutdown the H2O instance running at http://localhost:54321/ (Y/N)? Y
# [1] TRUE
