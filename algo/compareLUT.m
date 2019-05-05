function allLUTs = compareLUT(datasetCategory,algoChoice)
global X;
close all;
if nargin < 1
    bStandaloneCall = true;
    [~,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific('Lab',1);
    datasetCategory = 'Lab';
else
    [~,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific(datasetCategory,1);
    bStandaloneCall = false;
end
if nargin < 2
    algoChoice = 'drop2AndCompared';
end
savedResultFile = sprintf('%sanaLUTcompare_%s_%s',strProcessedResultFolder,datasetCategory,algoChoice);

if exist([savedResultFile '.mat'],'file') && ~bStandaloneCall
    load([savedResultFile '.mat'],'allLUTs');
else
    [datasetCnt,sanityDatasetCnt,etListSanityDataset] = getDatasetCnt(datasetCategory);
    allLUTs = zeros(sanityDatasetCnt,X.datasetSpecific.PosEachCycle,X.LUTcnt);
    for datasetii = 1:sanityDatasetCnt
        [allLUTs(datasetii,:,:),sigmaLUTs,LUTangleDeg,allmuRSSI,allstdRSSI] = buildLUT(datasetCategory,etListSanityDataset(datasetii));
    end
    save([savedResultFile '.mat'],'allLUTs');
end

figsavename = [savedResultFile 'EachLUTelement'];
if ~exist([figsavename '.jpg'],'file') || bStandaloneCall
    hFig = figure('Name',sprintf('std at each angular meas position over %d cycles',X.datasetSpecific.repeatedTrainDataCollect));
    for antPairii0 = 0:X.antSingleDiffCnt-1
        for arrayii0 = 0:X.antArrayCnt-1
            extractIndex = antPairii0*2+arrayii0+1;
            subplot(X.antSingleDiffCnt,X.antArrayCnt,extractIndex);
            extracteddata = allLUTs(:,:,extractIndex);
            stdresult = zeros(1,X.datasetSpecific.PosEachCycle);
            for angPosii = 1:X.datasetSpecific.PosEachCycle
                [~,stdresult(angPosii),~] = stats_pmPi(extracteddata(:,angPosii));
            end
            plot((0:X.datasetSpecific.PosEachCycle-1)*X.datasetSpecific.StepDeg,stdresult,'.-');
            grid on;
            xlabel('data collection angle(deg)');
            ylim([0,5]);
            if arrayii0 == 0
                ylabel(getStrAntPair(antPairii0));
            end
            if antPairii0 == 0
                title(sprintf('array%d',arrayii0));
            end
        end
    end
    savePlot(hFig,figsavename);
end
figsavename = [savedResultFile 'EachAngle'];
if ~exist([figsavename '.jpg'],'file') || bStandaloneCall
    hFig = figure('Name',sprintf('LUT value, one flat line per angle, total(%d)',X.datasetSpecific.PosEachCycle));
    for antPairii0 = 0:X.antSingleDiffCnt-1
        for arrayii0 = 0:X.antArrayCnt-1
            extractIndex = antPairii0*2+arrayii0+1;
            subplot(X.antSingleDiffCnt,X.antArrayCnt,extractIndex);
            extracteddata = squeeze(allLUTs(:,:,extractIndex));
            plot(extracteddata/pi,'.-');
            if arrayii0 == 0
                ylabel([getStrAntPair(antPairii0) ' (pi)']);
            end
            if antPairii0 == 0
                title(sprintf('array%d',arrayii0));
            end
            if antPairii0 == X.antSingleDiffCnt-1
                xlabel(sprintf('dataset [1,%d]',sanityDatasetCnt));
            end
        end
    end
    savePlot(hFig,figsavename);
end