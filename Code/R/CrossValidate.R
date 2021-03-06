library(ROCR)

source('./featurefiltering.R');
source('./learnWithCV.R')

timestamp();

set.seed(10);

#svmCostList = c(0.3, 1, 3, 10, 30, 100);
svmCostList = c(1);
#featureCountList = seq(from=25, to=7000, by=25);
featureCountList = c(287);

# 10 fold CV
nFolds = 10

fScheme = "_novel_comb";

RDSFolder          = "RDSFiles/"

rankedFeaturesFile = paste(RDSFolder, "ff_SvmRFE2"  , fScheme, ".rds", sep = "");
featureFile        = paste(RDSFolder, "featurized" , fScheme, ".rds", sep = "");
outFile            = paste("out"        , fScheme, ".csv", sep = "");

cat(as.character(Sys.time()),">> Reading training set features from", featureFile, "...\n");
features = readRDS(featureFile);
cat(as.character(Sys.time()),">> Done\n");

cat(as.character(Sys.time()),">> Reading feature ranking from", rankedFeaturesFile, "...\n");
rankedFeatures = readRDS(rankedFeaturesFile);
cat(as.character(Sys.time()),">> Done\n");

# jackknife
if (nFolds < 0) {
  nFolds = length(features[,1])
}

# random shuffle of features
features <- features[sample(nrow(features)),]

bestPerf = NULL;
bestParams = NULL;
accData = NULL;

cat(as.character(Sys.time()),">> Entering cross validation. Folds = ", nFolds, " ...\n");

# Reduce the feature vectors to the max size that we will be testing.
# This way the filtering cost in the loop below will be reduced.
features = featurefiltering(features, rankedFeatures, max(featureCountList));

# For regression study, we need to 'unfactor' the dependent var.
# When converting from factor to numeric, Antigens becomes 2 and Non-antigens becomes 1.
# So we need to deduct 1.
features$protection = as.numeric(features$protection) - 1;

for (maxFeatureCount in featureCountList) 
{
  trainingSet = featurefiltering(features, rankedFeatures, maxFeatureCount);

  for (svmC in svmCostList) 
  {
    perf = learnWithCV(protection ~ ., trainingSet, cross = nFolds, "svm", 
                  kernel = "linear", svmCost = svmC);
    #perf = learnWithCV(protection ~ ., trainingSet, cross = nFolds, "rf");
    
    cat(
        maxFeatureCount, ",", 
        svmC, ",", 
        round(perf$AUCROC, 2),  ",",  
        round(perf$threshold, 2), ",", 
        round(perf$acc, 2), ",", 
        round(perf$sens, 2), ",", 
        round(perf$spec, 2), ",", 
        round(perf$prec, 2),  ",", 
        round(perf$mcc, 2), ","
        );
    accData = rbind(accData, c(maxFeatureCount, svmC, perf$AUCROC, perf$threshold, perf$acc, perf$sens, perf$spec, perf$prec, perf$mcc));
    colnames(accData) = c("nF", "Cost", "AUCROC", "Threshold", "Accuracy", "Sensitivity", "Specificity", "Precision", "MCC");
    write.csv(accData, outFile);
    
    if (is.null(bestPerf) || bestPerf$acc < perf$acc) {
      bestPerf = perf;
      bestParams = list(
        "maxFeatureCount" = maxFeatureCount,
        "svmC" = svmC
      )
      cat(",<-- BEST");
    }
    
    cat("\n");
  }
}

cat("Best Result for <nF, C> = ", bestParams$maxFeatureCount, bestParams$svmC, "\n");
cat("AUCROC      : ", bestPerf$auc, "\n");
cat("Threshold   : ", bestPerf$threshold, "\n");
cat("Accuracy    : ", bestPerf$acc, "\n");
cat("Sensitivity : ", bestPerf$sens, "\n");
cat("Specificity : ", bestPerf$spec, "\n");
cat("MCC         : ", bestPerf$mcc, "\n");