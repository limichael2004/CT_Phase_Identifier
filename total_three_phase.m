% Define the path to the CSV file
csvFilePath = '/Radonc/Cancer Physics and Engineering Lab/Michael Li/FullValidationSetConverted.csv';
outputCsvFile = '/Radonc/Cancer Physics and Engineering Lab/Michael Li/FullValidationSetOutput.csv';
newCsvFileWithPatientIDs = '/Radonc/Cancer Physics and Engineering Lab/Michael Li/FullValidationSetwPatientIDs.csv';

% Load the dataset with preserved column headers and ensure correct parsing
opts = detectImportOptions(csvFilePath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
data = readtable(csvFilePath, opts);

% Verify the dataset
disp('Dataset loaded successfully.');
disp('Dataset preview:');
disp(data(1:5, :));  % Display the first few rows to inspect the structure

% Extract and display column names
columnNames = data.Properties.VariableNames;
disp('Column names:');
disp(columnNames);

% Check if required columns are present
requiredColumns = {'ID', 'Image', 'Mask'};
for i = 1:length(requiredColumns)
    if ~ismember(requiredColumns{i}, columnNames)
        error('Missing required column: %s', requiredColumns{i});
    end
end

% Define the ROI labels and their names
roiLabels = {'52', '64'};
roiNames = {'aorta', 'portal_vein_and_splenic_vein'};

% Path to the PyRadiomics configuration file
yamlFile = 'final.yaml';

% Process the first patient to extract headers
firstPatientProcessed = false;

for i = 1:height(data)
    patientID = data.ID(i);
    rawFile = data.Image{i};
    mlFile = data.Mask{i};

    disp(['Processing patient: ', patientID]); % Debugging
    disp(['Raw file path: ', rawFile]); % Debugging
    disp(['Mask file path: ', mlFile]); % Debugging

    if isfile(rawFile) && isfile(mlFile)
        for k = 1:length(roiLabels)
            label = roiLabels{k};
            roiName = roiNames{k};
            tempOutputCsv = ['pyradiomics_output_', roiName, '.csv'];
            logFile = ['pyradiomics_log_', roiName, '.txt'];

            % Run PyRadiomics and save output to temporary CSV file
            command = sprintf('pyradiomics %s %s --param %s --setting "label:%s" --format csv --out %s --verbosity 3 > %s 2>&1', rawFile, mlFile, yamlFile, label, tempOutputCsv, logFile);
            disp(['Running command: ', command]); % Debugging
            system(command);

            % If this is the first patient, extract headers
            if ~firstPatientProcessed && isfile(tempOutputCsv)
                % Extract headers from the temporary output CSV file
                opts = detectImportOptions(tempOutputCsv, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
                tempData = readtable(tempOutputCsv, opts);
                extractedHeaders = tempData.Properties.VariableNames;

                % Define combined headers
                combinedHeaders = [{'Patient', 'Folder', 'Label'}, extractedHeaders];
                disp('Combined headers defined:'); % Debugging
                disp(combinedHeaders); % Debugging

                % Write headers to the master CSV file
                writetable(cell2table(combinedHeaders), outputCsvFile, 'WriteVariableNames', false);

                % Mark that the first patient has been processed
                firstPatientProcessed = true;
            end

            % Append the results to the master CSV file
            if isfile(tempOutputCsv)
                append_features_to_csv(patientID, '', roiName, tempOutputCsv, outputCsvFile);
                delete(tempOutputCsv);
                delete(logFile);
            else
                disp(['Error: PyRadiomics did not produce an output file for ', roiName, ' (label ', label, ') in patient folder ', patientID]); % Debugging
            end
        end
    else
        disp(['Files not found for patient ', patientID, ': ', rawFile, ', ', mlFile]); % Debugging
    end
end

% Verify the dataset
disp('Dataset loaded successfully.');
disp('Dataset preview:');
disp(head(data));

% Load the dataset from the output CSV file
opts = detectImportOptions(outputCsvFile, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
data = readtable(outputCsvFile, opts);
test_data_1 = readtable(csvFilePath, opts);

% Verify the dataset
disp('Dataset loaded successfully.');
disp('Dataset preview:');
disp(data(1:5, :));  % Display the first few rows to inspect the structure

% Add a PatientID column based on row pairs
numPatients = height(data) / 2;
patientIDs = repelem((1:numPatients)', 2);

% Create a table for PatientID
patientIDTable = table(patientIDs, 'VariableNames', {'PatientID'});

% Concatenate PatientID table and data table
data = [patientIDTable, data];
% Verify the dataset with PatientID column
disp('Dataset with PatientID column:');
disp(data(1:5, :));  % Display the first few rows to inspect the structure

% Save the updated dataset with PatientID column to a new CSV file
writetable(data, newCsvFileWithPatientIDs);
disp(['Updated dataset with PatientID saved to ', newCsvFileWithPatientIDs]);

% Classify phases and add predictions to the dataset
predictedPhases = classify_phases(newCsvFileWithPatientIDs);

% Load the original dataset (test data)
opts = detectImportOptions(csvFilePath, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
originalData = readtable(csvFilePath, opts);

% Initialize Prediction column
originalData.Prediction = strings(height(originalData), 1);

for i = 1:height(test_data_1)
    %rowind = test_data(i);
    pred_phase = predictedPhases(i, 2);

    test_data_1(i, "Prediction") = {pred_phase.PredictedPhase{1}};
end

% Save the final dataset with predictions back to the original input CSV
writetable(test_data_1, csvFilePath);
disp(['Final dataset with predictions saved to ', csvFilePath]);

% Function to append features to CSV
function append_features_to_csv(patientID, folder, roiName, tempOutputCsv, outputCsvFile)
    % Load temporary output CSV
    opts = detectImportOptions(tempOutputCsv, 'Delimiter', ',', 'VariableNamingRule', 'preserve');
    tempData = readtable(tempOutputCsv, opts);

    % Add patientID, folder, and roiName to the table
    tempData.Patient = repmat({patientID}, height(tempData), 1);
    tempData.Folder = repmat({folder}, height(tempData), 1);
    tempData.Label = repmat({roiName}, height(tempData), 1);

    % Reorder columns to have Patient, Folder, Label at the beginning
    tempData = [tempData(:, end-2:end), tempData(:, 1:end-3)];

    % Append to the master CSV file
    writetable(tempData, outputCsvFile, 'WriteVariableNames', false, 'WriteMode', 'append');
end

% Classification function
function predictedPhases = classify_phases(inputFilePath)
    % Load the dataset
    data = readtable(inputFilePath, 'VariableNamingRule', 'preserve');

    % Verify the dataset, preliminary debug check
    disp('Dataset loaded successfully.');
    disp('Dataset preview:');
    disp(head(data));

    % Define the regions of interest
    aortaROI = 'aorta';
    portalVeinROI = 'portal_vein_and_splenic_vein';

    % Preconfigured median and IQR values
    arterialAortaMedian = 267;
    arterialAortaIQR = 117.5;
    arterialPortalVeinMedian = 92;
    arterialPortalVeinIQR = 52.75;

    portalVenousAortaMedian = 121;
    portalVenousAortaIQR = 30;
    portalVenousPortalVeinMedian = 132;
    portalVenousPortalVeinIQR = 34;

    preContrastAortaMedian = 37;
    preContrastAortaIQR = 10;
    preContrastPortalVeinMedian = 32; 
    preContrastPortalVeinIQR = 9;

    disp('Median and Interquartile Range (IQR) of Intensities:');
disp(['Arterial Aorta Median: ', num2str(arterialAortaMedian), ', IQR: ', num2str(arterialAortaIQR)]);
disp(['Arterial Portal Vein Median: ', num2str(arterialPortalVeinMedian), ', IQR: ', num2str(arterialPortalVeinIQR)]);
disp(['Portal Venous Aorta Median: ', num2str(portalVenousAortaMedian), ', IQR: ', num2str(portalVenousAortaIQR)]);
disp(['Portal Venous Portal Vein Median: ', num2str(portalVenousPortalVeinMedian), ', IQR: ', num2str(portalVenousPortalVeinIQR)]);
disp(['Pre-Contrast Aorta Median: ', num2str(preContrastAortaMedian), ', IQR: ', num2str(preContrastAortaIQR)]);
disp(['Pre-Contrast Portal Vein Median: ', num2str(preContrastPortalVeinMedian), ', IQR: ', num2str(preContrastPortalVeinIQR)]);

    % Preconfigured cutoff values
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

    % Load the pre-trained k-NN model
    load('thefinal.mat', 'thefinalModel');

    for i = 1:length(patientIDs)
        patientID = patientIDs(i);
        disp(['Processing Patient ID: ', num2str(patientID)]); % Debugging statement

        % Get aorta and portal vein data for the current patient
        aortaData = data(data.PatientID == patientID & strcmp(data.Label, aortaROI), :);
        portalVeinData = data(data.PatientID == patientID & strcmp(data.Label, portalVeinROI), :);

        if ~isempty(aortaData) && ~isempty(portalVeinData)
            aortaMedian = aortaData.original_firstorder_Median;
            portalVeinMedian = portalVeinData.original_firstorder_Median;

            % Display the extracted median values
            disp(['Aorta Median: ', num2str(aortaMedian)]);
            disp(['Portal Vein Median: ', num2str(portalVeinMedian)]);

            % Specific If-Then Statement for Classification using tunable IQRs
           if aortaMedian > (portalVenousAortaMedian + 3 * portalVenousAortaIQR)
            predictedPhase = 'Arterial';
        elseif aortaMedian < (arterialAortaMedian - 3 * arterialAortaIQR)
            if aortaMedian < (portalVenousAortaMedian - 3 * portalVenousAortaIQR)
                predictedPhase = 'Pre_Contrast';
            else
                predictedPhase = 'Portal_Venous';
            end
                else
                    % Cutoff-based classification logic
                if aortaMedian > aortaCutoff && portalVeinMedian < portalVeinCutoff
                        predictedPhase = 'Arterial';
                    elseif aortaMedian < aortaCutoff && portalVeinMedian > portalVeinCutoff
                        predictedPhase = 'Portal_Venous';
                    elseif aortaMedian < aortaCutoff && portalVeinMedian < portalVeinCutoff
                        predictedPhase = 'Pre_Contrast';
                    else
                    % Use k-NN to classify the phase
                    featureVector = [aortaMedian, portalVeinMedian];
                    predictedPhase = predict(thefinalModel, featureVector);
                end
            end

            % Assign the predicted phase to the relevant rows
            data.PredictedPhase(data.PatientID == patientID & (strcmp(data.Label, aortaROI) | strcmp(data.Label, portalVeinROI))) = {char(predictedPhase)};
            disp(['Predicted phase for Patient ID ', num2str(patientID), ': ', predictedPhase]);
        end
    end

    % Output the predicted phases for each unique patient
    predictedPhases = unique(data(:, {'Patient', 'PredictedPhase'}));
    disp('Predicted phases for each patient:');
    disp(predictedPhases);
end
