function [muLUTs,sigmaLUTs,LUTangleDeg,allmuRSSI,allstdRSSI] = buildLUT(datasetCategory,etLUTfolder,datFilePattern,algoChoice)
global X;
standaloneCall = false;
if nargin < 4
    algoChoice = 'drop2AndCompared';
end
if nargin < 3
    datFilePattern = 'Log*.dat';
end
if nargin < 2
    etLUTfolder = 0;
end
if nargin < 1
    close all;
    datasetCategory = 'Lab';
    standaloneCall = true;
end
[strlogFolder,strProcessedResultFolder,~,~] = globalSettings_datasetSpecific(datasetCategory,etLUTfolder);
savedResultFile = sprintf('%s%s_%s',strlogFolder,get_strTestDescriptor(datasetCategory,etLUTfolder),algoChoice);

if exist([savedResultFile '.mat'],'file') && ~standaloneCall
    load([savedResultFile '.mat']);
    visualizeLUT(muLUTs,sigmaLUTs,'after MP screening',savedResultFile);
else
    [allAntPairPhsDiffRad, allValPhsStd, allmuRSSI, allstdRSSI, allValidSampleRatio, angleTruthInCycle, allantArrSDpairsPhs] = ...
        calcSDphsWholeDataset(datasetCategory,etLUTfolder,datFilePattern,'Train');
    globalSettings_datasetSpecific(datasetCategory,etLUTfolder);
    allAntPairPhsDiffRad = reshape(allAntPairPhsDiffRad,[size(allAntPairPhsDiffRad,1),X.LUTcnt]);
    if standaloneCall
        figure('Name','all Phs Diff data over the whole experiment','NumberTitle','off');
        for antpair_ii = 0:X.antSingleDiffCnt-1
            for arr_ii = 0:X.antArrayCnt-1
                plotii = antpair_ii*X.antArrayCnt+arr_ii+1;
                subplot(X.LUTcnt,1,plotii);
                plot(angleTruthInCycle,allAntPairPhsDiffRad(:,plotii),'.-');
                if antpair_ii == X.antSingleDiffCnt-1 && arr_ii == X.antArrayCnt-1
                    xlabel('platform rotation(cycle)');
                end
                ylabel(sprintf('Arr%dEle(%s)',arr_ii,getStrAntPair(antpair_ii)));
                ylim([-pi,pi]);
                grid on;
            end
        end
    end
    % X.datasetSpecific.PosEachCycle,X.datasetSpecific.repeatedTrainDataCollect,X.LUTcnt
    % allAntPairPhsDiffRadChoice1 = reshape(allAntPairPhsDiffRadChoice1,[X.datasetSpecific.PosEachCycle,X.datasetSpecific.repeatedTrainDataCollect,X.LUTcnt]);
    muLUTs_round1 = zeros(X.datasetSpecific.PosEachCycle,X.LUTcnt);
    sigmaLUTs_round1 = zeros(X.datasetSpecific.PosEachCycle,X.LUTcnt);
    adoptedDataCnt_round1 = zeros(X.datasetSpecific.PosEachCycle,X.LUTcnt);
    for iiPos0 = 0:X.datasetSpecific.PosEachCycle-1
        fixPosAllTestAllLUT = squeeze(allAntPairPhsDiffRad(find(abs(mod(angleTruthInCycle,1)-iiPos0/(360/X.datasetSpecific.StepDeg))<1e-3),:));
        for iiLUT = 1:X.LUTcnt
            thisPosThisLUT = fixPosAllTestAllLUT(:,iiLUT);
            [muLUTs_round1(iiPos0+1,iiLUT),sigmaLUTs_round1(iiPos0+1,iiLUT),adoptedDataCnt_round1(iiPos0+1,iiLUT)] = stats_pmPi(thisPosThisLUT);
        end
    end
    if standaloneCall
        visualizeLUT(muLUTs_round1,sigmaLUTs_round1,'b4 MP screening');
    end
    LUTangleDeg = (0:X.datasetSpecific.PosEachCycle-1)*X.datasetSpecific.stepDeg;
    for iiPos0 = 0:X.datasetSpecific.PosEachCycle-1
        fixPosAllTestAllLUT = squeeze(allAntPairPhsDiffRad(find(abs(mod(angleTruthInCycle,1)-iiPos0/(360/X.datasetSpecific.StepDeg))<1e-3),:));
        for iiLUT = 1:X.LUTcnt
            thisPosThisLUT = fixPosAllTestAllLUT(:,iiLUT);
            [muLUTs(iiPos0+1,iiLUT),sigmaLUTs(iiPos0+1,iiLUT),indexSelected,~] = KmeanMerge_rad(thisPosThisLUT);
            adoptedDataCnt(iiPos0+1,iiLUT) = length(indexSelected);
        end
    end
    visualizeLUT(muLUTs,sigmaLUTs,'after MP screening',savedResultFile);
    save([savedResultFile '.mat'], 'muLUTs','sigmaLUTs','LUTangleDeg','allmuRSSI','allstdRSSI','allAntPairPhsDiffRad');
end
end

function [meanval,stdval] = stats_of_validValues(data)
data = data(:);
data = data(~isnan(data));
meanval = mean(data);
stdval = std(data);
end

function visualizeLUT(muLUTs,sigmaLUTs,StrExtra,savedResultFile)
global X;
if nargin < 6
    savedResultFile = '';
end

strPhsStdFig = sprintf('%s%s',savedResultFile,'PhsStd');
if ~exist([strPhsStdFig '.jpg'],'file')
    hPhsStdFig = figure;
    imagesc(sigmaLUTs);
    colorbar;
    title(sprintf('\\sigma_{\\phi}, greater number=multipath, %s',StrExtra));
    xlabel(sprintf('%d LUT',X.LUTcnt));
    ylabel(sprintf('%d discrete angle',X.datasetSpecific.PosEachCycle));
    if ~isempty(savedResultFile)
        CMathHelper.savePlot(hPhsStdFig,strPhsStdFig);
    end
end

strStabilityMultiCycleFig = sprintf('%s%s',savedResultFile,'StabilityMultiCycle');
if ~exist([strStabilityMultiCycleFig '.jpg'],'file')
    hStabFig = figure('Name',sprintf('mu&std at each angular position,%s',StrExtra),'NumberTitle','off');
    hold on;
    for arr_ii = 1:X.antArrayCnt
        for antpair_ii = 1:size(X.antPair,1)
            LUTii = (arr_ii-1)*size(X.antPair,1)+antpair_ii;
            subplot(size(X.antPair,1),X.antArrayCnt,LUTii);
            errorbar(1:X.datasetSpecific.PosEachCycle,muLUTs(:,LUTii),sigmaLUTs(:,LUTii));
            title(sprintf('Arr%dEle(%s)',arr_ii+1,getStrAntPair(antpair_ii-1)));
            ylabel('rad');
            xlabel('testing angle');
            ylim([-pi,pi]);
        end
    end
    if ~isempty(savedResultFile)
        CMathHelper.savePlot(hStabFig,strStabilityMultiCycleFig);
    end
end
end

