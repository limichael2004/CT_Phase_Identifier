function [bestAortaMultiplier, bestPortalVeinMultiplier, bestAccuracy] = grid_search_with_pre_contrast()
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

    % Define the multipliers for grid search
    multipliers = 0:0.01:1.8;

    % Extract unique patient IDs
    patientIDs = unique(data.PatientID);

    % Perform grid search in parallel
    [bestAortaMultiplier, bestPortalVeinMultiplier, bestAccuracy] = performGridSearch(data, arterialAortaMedian, arterialAortaIQR, arterialPortalVeinMedian, arterialPortalVeinIQR, portalVenousAortaMedian, portalVenousAortaIQR, portalVenousPortalVeinMedian, portalVenousPortalVeinIQR, preContrastAortaMedian, preContrastAortaIQR, preContrastPortalVeinMedian, preContrastPortalVeinIQR, patientIDs, multipliers);
    
    % Display the best multipliers and accuracies
    disp(['Best Aorta Multiplier: ', num2str(bestAortaMultiplier)]);
    disp(['Best Portal Vein Multiplier: ', num2str(bestPortalVeinMultiplier)]);
    disp(['Best Classification Accuracy: ', num2str(bestAccuracy * 100), '%']);


end