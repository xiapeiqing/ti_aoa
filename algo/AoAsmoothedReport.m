function AoAsmoothedDeg = AoAsmoothedReport(datasetCategory,etLUTfolder,etMeasFolder,algoChoice,save_Path_Filename)
global X;
close all;
if nargin < 1
    datasetCategory = 'Lab';
end
if nargin < 2
    etLUTfolder = 0;
end
if nargin < 3
    etMeasFolder = etLUTfolder;
end
if nargin < 4
    algoChoice = 'drop2AndCompared';
end
if nargin < 5
    save_Path_Filename = '';
endif nargin < 3if nargin < 3
    etMeasFolder = etLUTfolder;
end

    etMeasFolder = etLUTfolder;
end


[~,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific(datasetCategory,etMeasFolder);
upate it later!!!!! savedResultFile = sprintf('%sAoAsmoothed_LUT%d_meas%d_%s',strProcessedResultFolder,etLUTfolder,etMeasFolder,algoChoice);
if exist([savedResultFile '.mat'],'file')
    load([savedResultFile '.mat'],'AoAsmoothedDeg','AllPosTruthDeg');
else
    [ErrBiasDeg,ErrStdDeg,prctileMetric,AllPosDeg,AllPosTruthDeg,meanRssi] = EvaluateLUTquality(etLUTfolder,etMeasFolder,algoChoice);
    globalSettings_datasetSpecific(datasetCategory,etMeasFolder);
    
    AllPosDegIdxValid = find(~isnan(AllPosDeg));
    AllValidPosDeg = AllPosDeg(AllPosDegIdxValid);
    [PhsMeanRad,inputiiEnd_init,init_done] = blindInitialization(1,AllValidPosDeg);
    if ~init_done
        disp('AoA final stage report initialization failed');
    else
        outputDeg = PhsMeanRad*180/pi;
        innovateRatio = 0.1;
        AoAsmoothedDeg = zeros(length(AllValidPosDeg),2);
        AoAsmoothedDeg(1,1) = inputiiEnd_init;
        AoAsmoothedDeg(1,2) = outputDeg;
        reportLen = 1;
        skippedCnt = 0;
        hWaitbar = waitbar(0,'AoA smoothed report, Please wait...');
        for inputii = inputiiEnd_init+1:length(AllValidPosDeg)
            waitbar(inputii/length(AllValidPosDeg),hWaitbar);
            if abs(AllValidPosDeg(inputii)-outputDeg) < 20
                outputDeg = outputDeg*(1-innovateRatio)+AllValidPosDeg(inputii)*innovateRatio;
                reportLen = reportLen + 1;
                AoAsmoothedDeg(reportLen,1) = inputii;
                AoAsmoothedDeg(reportLen,2) = outputDeg;
                skippedCnt = 0;
            else
                skippedCnt = skippedCnt + 1;
                if skippedCnt > 10
                    [PhsMeanRad,inputiiEnd_reinit,init_done] = blindInitialization(inputii,AllValidPosDeg);
                    if ~init_done
                        break;
                    end
                    outputDeg = PhsMeanRad*180/pi;
                    reportLen = reportLen + 1;
                    AoAsmoothedDeg(reportLen,1) = inputiiEnd_reinit;
                    AoAsmoothedDeg(reportLen,2) = outputDeg;
                    skippedCnt = 0;
                else
                    continue;
                end
            end
        end
    end
    close(hWaitbar);
    AoAsmoothedDeg(reportLen+1:end,:) = [];
    AoAsmoothedDeg(:,1) = AllPosDegIdxValid(AoAsmoothedDeg(:,1));
    save([savedResultFile '.mat'],'AoAsmoothedDeg','AllPosTruthDeg');
end
h_fig = figure;
subplot(311);
plot(AoAsmoothedDeg(:,1),AoAsmoothedDeg(:,2),'.-');
hold on;
plot(AoAsmoothedDeg(:,1),AllPosTruthDeg(AoAsmoothedDeg(:,1)),'.-');
title(sprintf('AoA final report, LUT(%d), meas(%d)',etLUTfolder,etMeasFolder));
subplot(312);
plot(AoAsmoothedDeg(:,1),AoAsmoothedDeg(:,2)-AllPosTruthDeg(AoAsmoothedDeg(:,1)),'.-');
subplot(313);
ErrDeg = AoAsmoothedDeg(:,2)-AllPosTruthDeg(AoAsmoothedDeg(:,1));
hist(ErrDeg,20);
grid on;
ylabel('deg');
meaningfulErrDeg = ErrDeg(~isnan(ErrDeg));
prctileMetric = prctile(abs(ErrDeg),X.percentileThres);
title(sprintf('estimation Err distribution,%2.1f-prctile=%2.1f,yield=%4.3f',X.percentileThres,prctileMetric,length(meaningfulErrDeg)/X.totalMeasCnt));
if ~isempty(save_Path_Filename)
    savePlot(h_fig,save_Path_Filename);
else
    savePlot(h_fig,savedResultFile);
end

end

function [PhsMeanRad,inputiiEnd_init,init_done] = blindInitialization(begin_ii,AllPosDeg)
global X;
init_done = false;
for inputii_init = begin_ii:length(AllPosDeg)-X.windowLength+1
    smoothing_bufferDeg = AllPosDeg(inputii_init:X.windowLength+inputii_init-1);
    [PhsMeanRad,PhsStdRad,indexSelected,IndexRemaining] = KmeanMerge_rad(smoothing_bufferDeg*pi/180,2);
    if length(indexSelected)>0.8*X.windowLength
        init_done = true;
        inputiiEnd_init = inputii_init+X.windowLength-1;
        break;
    end
end
end