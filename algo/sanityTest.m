function sanityTestsQosSmetric = sanityTest(datasetCategory,algoChoice)
global X;
if nargin < 1
    datasetCategory = 'Lab';
    bStandaloneCall = true;
else
    bStandaloneCall = false;
end

if nargin < 2
    algoChoice = 'drop2AndCompared';
end
close all;
[~,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific(datasetCategory,1);
savedResultFile = sprintf('%sanaSanity_%s_%s',strProcessedResultFolder,datasetCategory,algoChoice);
if exist([savedResultFile '.mat'],'file') && ~bStandaloneCall
    load([savedResultFile '.mat'],'prctileMetric','AllPosDeg','AllPosTruthDeg','allmuRSSI','allstdRSSI');
else
    [datasetCnt,sanityDatasetCnt,etListSanityDataset] = getDatasetCnt(datasetCategory);

    sanityPrctileMetric   = zeros(sanityDatasetCnt,sanityDatasetCnt);
    for LUTii = 1:sanityDatasetCnt
        for experimentii = 1:sanityDatasetCnt
            fprintf(1,'sanity test LUT(%d) meas(%d)\n',etListSanityDataset(LUTii),etListSanityDataset(experimentii));
            save_Path_Filename = sprintf('%sLUT%d_ex%d',...
                savedResultFile,etListSanityDataset(LUTii),etListSanityDataset(experimentii));
            FigTitle = sprintf('Ex%d as reference, Ex%d as test data input',etListSanityDataset(LUTii),etListSanityDataset(experimentii));
            [prctileMetric,~,~,~,~] = EvaluateLUTquality(etListSanityDataset(LUTii),etListSanityDataset(experimentii),algoChoice,FigTitle,save_Path_Filename);
            sanityPrctileMetric(LUTii,experimentii) = prctileMetric;
        end
    end
    save([savedResultFile '.mat'],'sanityPrctileMetric');
end
figsavename = [savedResultFile 'matrixChk'];
if ~exist([figsavename '.jpg'],'file') || bStandaloneCall
    sanityTestsQosSmetric = mean(sanityPrctileMetric(:));
    hFig = figure;
    imagesc(sanityPrctileMetric);
    if true
        colormap(gray)
    end
    colorbar;
    title(sprintf('%2.1f percentile error',X.percentileThres));
    xlabel('experiment dataset');
    ylabel('LUT dataset');
    for testii = 1:sanityDatasetCnt
        [strlogFolder,~,etSanityTestMember,~] = globalSettings_datasetSpecific(datasetCategory,etListSanityDataset(testii));
        assert(strcmp(etSanityTestMember,'SanityMember'));
        fprintf(1,'%d:%s\n',testii,strlogFolder);
    end
    savePlot(hFig,figsavename);
end
figsavename = [savedResultFile 'LUTquality'];
if ~exist([figsavename '.jpg'],'file') || bStandaloneCall
    hFig = figure;
    subplot(211);
    plot(mean(sanityPrctileMetric));
    title('same experiment meas, average over all LUT(no real meaning)');
    subplot(212);
    plot(mean(sanityPrctileMetric'));
    title('same LUT, average over all experiment meas');  
    savePlot(hFig,figsavename);
end
end