function [averageAccuracy, stdAccuracy, averageF1, stdF1, averagePrecision, stdPrecision, averageRecall, stdRecall] = trying_something()
    % Define the input file path
    inputFilePath = '/Radonc/Cancer Physics and Engineering Lab/Michael Li/SecondCTPhase/modified_modified_modified_ThousandThreehundred.csv';

    % Load the dataset
    data = readtable(inputFilePath, 'VariableNamingRule', 'preserve');

    % Verify the dataset
    disp('Dataset loaded successfully.');
    disp('Dataset preview:');
    disp(head(data));

    % Define the phases
    arterialPhase = 'Arterial';
    portalVenousPhase = 'Portal_Venous';
    preContrastPhase = 'Pre_Contrast';

    % Define the regions of interest
    aortaROI = 'aorta';
    portalVeinROI = 'portal_vein_and_splenic_vein';

    % Filter data by phase
    arterialData = data(strcmp(data.Folder, arterialPhase), :);
    portalVenousData = data(strcmp(data.Folder, portalVenousPhase), :);
    preContrastData = data(strcmp(data.Folder, preContrastPhase), :);

    % Extract median intensities for the entire dataset
    arterialAortaMedians = arterialData{strcmp(arterialData.Label, aortaROI), 'original_firstorder_Median'};
    arterialPortalVeinMedians = arterialData{strcmp(arterialData.Label, portalVeinROI), 'original_firstorder_Median'};

    portalVenousAortaMedians = portalVenousData{strcmp(portalVenousData.Label, aortaROI), 'original_firstorder_Median'};
    portalVenousPortalVeinMedians = portalVenousData{strcmp(portalVenousData.Label, portalVeinROI), 'original_firstorder_Median'};

    preContrastAortaMedians = preContrastData{strcmp(preContrastData.Label, aortaROI), 'original_firstorder_Median'};
    preContrastPortalVeinMedians = preContrastData{strcmp(preContrastData.Label, portalVeinROI), 'original_firstorder_Median'};

    % Calculate median and interquartile range (IQR) for each group
    arterialAortaMedian = median(arterialAortaMedians);
    arterialAortaIQR = iqr(arterialAortaMedians);
    arterialPortalVeinMedian = median(arterialPortalVeinMedians);
    arterialPortalVeinIQR = iqr(arterialPortalVeinMedians);

    portalVenousAortaMedian = median(portalVenousAortaMedians);
    portalVenousAortaIQR = iqr(portalVenousAortaMedians);
    portalVenousPortalVeinMedian = median(portalVenousPortalVeinMedians);
    portalVenousPortalVeinIQR = iqr(portalVenousPortalVeinMedians);

    preContrastAortaMedian = median(preContrastAortaMedians);
    preContrastAortaIQR = iqr(preContrastAortaMedians);
    preContrastPortalVeinMedian = median(preContrastPortalVeinMedians);
    preContrastPortalVeinIQR = iqr(preContrastPortalVeinMedians);

    % Display the medians and IQRs
    disp('Median and Interquartile Range (IQR) of Intensities:');
    disp(['Arterial Aorta Median: ', num2str(arterialAortaMedian), ', IQR: ', num2str(arterialAortaIQR)]);
    disp(['Arterial Portal Vein Median: ', num2str(arterialPortalVeinMedian), ', IQR: ', num2str(arterialPortalVeinIQR)]);
    disp(['Portal Venous Aorta Median: ', num2str(portalVenousAortaMedian), ', IQR: ', num2str(portalVenousAortaIQR)]);
    disp(['Portal Venous Portal Vein Median: ', num2str(portalVenousPortalVeinMedian), ', IQR: ', num2str(portalVenousPortalVeinIQR)]);
    disp(['Pre-Contrast Aorta Median: ', num2str(preContrastAortaMedian), ', IQR: ', num2str(preContrastAortaIQR)]);
    disp(['Pre-Contrast Portal Vein Median: ', num2str(preContrastPortalVeinMedian), ', IQR: ', num2str(preContrastPortalVeinIQR)]);

    % Define cutoff values using median ± x * IQR
    aortaCutoff = arterialAortaMedian - 1.45 * arterialAortaIQR;
    portalVeinCutoff = arterialPortalVeinMedian + 0.01 * arterialPortalVeinIQR;

    % Display the cutoffs
    disp('Cutoff values:');
    disp(['Aorta Cutoff: ', num2str(aortaCutoff)]);
    disp(['Portal Vein Cutoff: ', num2str(portalVeinCutoff)]);

    % Combine all data for classification
    data.PredictedPhase = repmat("", height(data), 1);

    % Extract unique patient IDs
    patientIDs = unique(data.PatientID);
    disp('Unique Patient IDs:');
    disp(patientIDs);

    numIterations = 1000;
    accuracies = zeros(numIterations, 1);
    precisions = zeros(numIterations, 1);
    recalls = zeros(numIterations, 1);
    f1Scores = zeros(numIterations, 1);

    for iteration = 1:numIterations
        % Set the random seed for reproducibility
        rng(iteration);

        % Split the data into training (70%) and testing (30%) sets
        cv = cvpartition(length(patientIDs), 'HoldOut', 0.40);
        trainIdx = training(cv);
        testIdx = test(cv);

        trainPatientIDs = patientIDs(trainIdx);
        testPatientIDs = patientIDs(testIdx);

        trainData = data(ismember(data.PatientID, trainPatientIDs), :);
        testData = data(ismember(data.PatientID, testPatientIDs), :);

        % Extract features and labels for training
        trainFeatures = [trainData(strcmp(trainData.Label, aortaROI), :).original_firstorder_Median, ...
                         trainData(strcmp(trainData.Label, portalVeinROI), :).original_firstorder_Median];
        trainLabels = categorical(trainData(strcmp(trainData.Label, aortaROI), :).Folder); % Ensure labels are categorical

        % Train k-NN model on training data
        k = 25;
        knnModel = fitcknn(trainFeatures, trainLabels, 'NumNeighbors', k);

        % Iterate through each patient in the test data
        for i = 1:length(testPatientIDs)
            patientID = testPatientIDs(i);
            disp(['Processing Patient ID: ', num2str(patientID)]); % Debugging statement

            % Get aorta and portal vein data for the current patient
            aortaData = testData(testData.PatientID == patientID & strcmp(testData.Label, aortaROI), :);
            portalVeinData = testData(testData.PatientID == patientID & strcmp(testData.Label, portalVeinROI), :);

            if ~isempty(aortaData) && ~isempty(portalVeinData)
                aortaMedian = aortaData.original_firstorder_Median;
                portalVeinMedian = portalVeinData.original_firstorder_Median;

                % Specific If-Then Statement for Classification using tunable IQRs
                if aortaMedian > (portalVenousAortaMedian + 3.25 * portalVenousAortaIQR)
                    predictedPhase = arterialPhase;
                elseif aortaMedian < (arterialAortaMedian - 3.25 * arterialAortaIQR)
                    if aortaMedian < (portalVenousAortaMedian - 3.25 * portalVenousAortaIQR)
                        predictedPhase = preContrastPhase;
                    else
                        predictedPhase = portalVenousPhase;
                    end
                else
                    % Cutoff-based classification logic
                    if aortaMedian > aortaCutoff && portalVeinMedian < portalVeinCutoff
                        predictedPhase = arterialPhase;
                    elseif aortaMedian < aortaCutoff && portalVeinMedian > portalVeinCutoff
                        predictedPhase = portalVenousPhase;
                    elseif aortaMedian < aortaCutoff && portalVeinMedian < portalVeinCutoff
                        predictedPhase = preContrastPhase;
                    else
                        % If still uncertain, use k-NN to find the closest samples
                        % Combine aortaMedian and portalVeinMedian into a feature vector
                        featureVector = [aortaMedian, portalVeinMedian];

                        % Perform k-NN prediction
                        predictedPhase = predict(knnModel, featureVector);
                    end
                end

                % Assign the predicted phase to the relevant rows
                testData.PredictedPhase(testData.PatientID == patientID & (strcmp(testData.Label, aortaROI) | strcmp(testData.Label, portalVeinROI))) = {char(predictedPhase)};
            end
        end

        % Calculate accuracy, precision, recall, and F1 score
        correctPredictions = 0;
        allPredictions = [];
        allTrueLabels = [];

        for i = 1:length(testPatientIDs)
            patientID = testPatientIDs(i);
            patientData = testData(testData.PatientID == patientID, :);
            trueLabels = patientData.Folder;
            predictedLabels = patientData.PredictedPhase;

            if all(strcmp(predictedLabels, trueLabels))
                correctPredictions = correctPredictions + 1;
            end

            allTrueLabels = [allTrueLabels; trueLabels];
            allPredictions = [allPredictions; predictedLabels];
        end

        accuracy = correctPredictions / length(testPatientIDs);
        [confMat, order] = confusionmat(allTrueLabels, allPredictions);

        precision = diag(confMat) ./ sum(confMat, 2);
        recall = diag(confMat) ./ sum(confMat, 1)';
        f1 = 2 * (precision .* recall) ./ (precision + recall);

        % Handle NaNs in precision, recall, and F1 scores
        precision(isnan(precision)) = 0;
        recall(isnan(recall)) = 0;
        f1(isnan(f1)) = 0;

        % Store the metrics
        accuracies(iteration) = accuracy;
        precisions(iteration) = mean(precision);
        recalls(iteration) = mean(recall);
        f1Scores(iteration) = mean(f1);

        disp(['Iteration ', num2str(iteration), ' - Classification Accuracy: ', num2str(accuracy * 100), '%']);
    end

    % Calculate the average and standard deviation of the metrics
    averageAccuracy = mean(accuracies);
    stdAccuracy = std(accuracies);

    averagePrecision = mean(precisions);
    stdPrecision = std(precisions);

    averageRecall = mean(recalls);
    stdRecall = std(recalls);

    averageF1 = mean(f1Scores);
    stdF1 = std(f1Scores);

    disp(['Average Classification Accuracy over ', num2str(numIterations), ' iterations: ', num2str(averageAccuracy * 100), '%']);
    disp(['Standard Deviation of Accuracy: ', num2str(stdAccuracy * 100), '%']);
    disp(['Average Precision: ', num2str(averagePrecision * 100), '%']);
    disp(['Standard Deviation of Precision: ', num2str(stdPrecision * 100), '%']);
    disp(['Average Recall: ', num2str(averageRecall * 100), '%']);
    disp(['Standard Deviation of Recall: ', num2str(stdRecall * 100), '%']);
    disp(['Average F1 Score: ', num2str(averageF1 * 100), '%']);
    disp(['Standard Deviation of F1 Score: ', num2str(stdF1 * 100), '%']);

    % Train the k-NN model on the entire dataset
    allFeatures = [data(strcmp(data.Label, aortaROI), :).original_firstorder_Median, ...
                   data(strcmp(data.Label, portalVeinROI), :).original_firstorder_Median];
    allLabels = categorical(data(strcmp(data.Label, aortaROI), :).Folder);

    thefinalModel = fitcknn(allFeatures, allLabels, 'NumNeighbors', k);

    % Save the k-NN model
    save('thefinal.mat', 'thefinalModel');
end
