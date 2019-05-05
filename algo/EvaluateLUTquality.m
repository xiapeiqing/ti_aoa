function [prctileMetric,AllPosDeg,AllPosTruthDeg,allmuRSSI,allstdRSSI] = EvaluateLUTquality...
    (datasetCategory,etLUTfolder,etMeasFolder,algoChoice,FigTitle,save_Path_Filename,Eval_Train_All)
global X;
if nargin < 1
    datasetCategory = 'Lab';
    bStandaloneCall = true;
    close all;
else
    bStandaloneCall = false;
end
if nargin < 2
    etLUTfolder = 10;
end
if nargin < 3
%     etMeasFolder = etLUTfolder;
    etMeasFolder = 0;
end
if nargin < 4
    algoChoice = 'drop2AndCompared';
end
if nargin < 5
    FigTitle = '';
end
if nargin < 6
    save_Path_Filename = '';
end
if nargin < 7
    Eval_Train_All = 'All';% Eval Train All
end

[~,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific(datasetCategory,etMeasFolder);
savedResultFile = sprintf('%s%s_LUTquality_%s',strProcessedResultFolder,get_strTestDescriptor(datasetCategory,etLUTfolder,etMeasFolder,Eval_Train_All),algoChoice);
if ~isempty(save_Path_Filename)
    SaveFigFile = save_Path_Filename;
else
    SaveFigFile = savedResultFile;
end

if exist([savedResultFile '.mat'],'file') && ~bStandaloneCall
    load([savedResultFile '.mat'], 'prctileMetric','AllPosDeg','AllPosTruthDeg','allmuRSSI','allstdRSSI');
    visualizeAoAeachPkt(AllPosDeg,AllPosTruthDeg,SaveFigFile,FigTitle);
else
    [muLUTs,sigmaLUTs,LUTangleDeg,allmuRSSI,allstdRSSI] = buildLUT(datasetCategory,etLUTfolder,'Log*.dat',algoChoice);
    globalSettings_datasetSpecific(datasetCategory,etMeasFolder);

    %[allAntPairPhsDiffRad, allValPhsStd, allmuRSSI, allstdRSSI, allValidSampleRatio, angleTruthInCycle, allantArrSDpairsPhs] 
    [~, ~, allmuRSSI, allstdRSSI, ~, angleTruthInCycle, allantArrSDpairsPhs] = calcSDphsWholeDataset(datasetCategory,etMeasFolder,'Log_*.dat',Eval_Train_All);
    globalSettings_datasetSpecific(datasetCategory,etMeasFolder);

    allAntPairPhsDiffRad = zeros(size(allantArrSDpairsPhs,1)*X.measPerLogFile,X.LUTcnt);
    for logii = 0:size(allantArrSDpairsPhs,1)-1
        for pktii = 0:X.measPerLogFile-1
            for arrayii = 0:X.antArrayCnt-1
                for antPairii = 0:X.antSingleDiffCnt-1
                    allAntPairPhsDiffRad(logii*X.measPerLogFile+pktii+1,antPairii*X.antArrayCnt+arrayii+1) = ...
                        allantArrSDpairsPhs(logii+1,arrayii+1,pktii+1,antPairii+1);
                end
            end
        end
    end
    AllPosDeg = zeros(size(allAntPairPhsDiffRad,1),1);
    hWaitbar = waitbar(0,sprintf('use LUT(%d) to estimate Meas dataset(%d)%s\n',etLUTfolder,etMeasFolder,Eval_Train_All));
    %LUTgradient = getLUTgradient(muLUTs);
    for measii = 1:size(allAntPairPhsDiffRad,1)
        if mod(measii,10) == 0
            waitbar(measii/size(allAntPairPhsDiffRad,1),hWaitbar);
        end
        AllPosDeg(measii) = estimatePos(muLUTs,sigmaLUTs,LUTangleDeg,allAntPairPhsDiffRad(measii,:),algoChoice);
    end
    close(hWaitbar);
    AllPosTruthDeg = generateTruth(angleTruthInCycle);
    ErrDeg = AllPosDeg - AllPosTruthDeg;
    prctileMetric = prctile(abs(ErrDeg),X.percentileThres);
    save([savedResultFile '.mat'], 'prctileMetric','AllPosDeg','AllPosTruthDeg','allmuRSSI','allstdRSSI','prctileMetric');
end
visualizeAoAeachPkt(AllPosDeg,AllPosTruthDeg,SaveFigFile,FigTitle,bStandaloneCall);
end

function LUTgradient = getLUTgradient(LUT)
LUTgradient = zeros(size(LUT));
for ii = 1:size(LUT,1)
    for jj = 1:size(LUT,2)
        if jj == 1
            gradient = LUT(ii,2)-LUT(ii,size(LUT,2));
        elseif jj == size(LUT,2)
            gradient = LUT(ii,1)-LUT(ii,size(LUT,2)-1);
        else
            gradient = LUT(ii,jj+1)-LUT(ii,jj-1);
        end
        LUTgradient(ii,jj) = gradient;
    end
end
end

function AllPosTruthDeg = generateTruth(angleTruthInCycle)
if size(angleTruthInCycle,1)==1
    angleTruthInCycle = angleTruthInCycle';
end
global X;
generatedTruthCycles = ones(X.measPerLogFile,1)*mod(angleTruthInCycle,1)';
AllPosTruthDeg = generatedTruthCycles(:)*360;
end

% function AllPosTruthDeg = generateTruth(Eval_Train_All)
% global X;
% cycleCnt = getPlatformRotationCycles(Eval_Train_All);
% generatedTruthCycles = ones(X.datasetSpecific.PosEachCycle*X.measPerLogFile,1)*(0:cycleCnt-1);
% ModValInCycle = ones(X.measPerLogFile,1)*(0:(X.datasetSpecific.PosEachCycle-1))/((X.datasetSpecific.PosEachCycle-1)*2);
% ModValInCycle = ModValInCycle(:);
% generatedTruthCycles = generatedTruthCycles + ModValInCycle;
% generatedTruthCycles = generatedTruthCycles(:);
% AllPosTruthDeg = mod(generatedTruthCycles,1)*360;
% end

function cycleCnt = getPlatformRotationCycles(Eval_Train_All)
global X;
switch Eval_Train_All
    case 'Eval'
        cycleCnt = X.datasetSpecific.repeatedEvalDataCollect;
    case 'Train'
        cycleCnt = X.datasetSpecific.repeatedTrainDataCollect;
    case 'All'
        cycleCnt = X.datasetSpecific.repeatedEvalDataCollect + X.datasetSpecific.repeatedTrainDataCollect;
    otherwise
        assert(false);
end
end


