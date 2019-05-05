function [allAntPairPhsDiffRad, allValPhsStd, allmuRSSI, allstdRSSI, allValidSampleRatio, angleTruthInCycle, allantArrSDpairsPhs] = ...
    calcSDphsWholeDataset(datasetCategory,etLogFolder,datFilePattern,Eval_Train_All)
global X;
bEnableProgressBar = true;%true false
if nargin < 1
    close all;
    datasetCategory = 'Lab';
    bStandaloneCall = true;
else
    bStandaloneCall = false;
end
if nargin < 2
    etLogFolder = 0;
end
if nargin < 3
    datFilePattern = 'Log_*.dat';
end
if nargin < 4
    Eval_Train_All = 'Train';
end
[strLogFolder,~,~,~] = globalSettings_datasetSpecific(datasetCategory,etLogFolder);
savedResultFile = sprintf('%sanaSDphs%d%s%s',strLogFolder,etLogFolder,X.algor,Eval_Train_All);

allLogs = dir([strLogFolder datFilePattern]);
switch Eval_Train_All
    case 'Eval'
        allLogs = allLogs(X.datasetSpecific.LogFileCntTrain+1:end);
    case 'Train'
        allLogs = allLogs(1:X.datasetSpecific.LogFileCntTrain);
    case 'All'
        % do nothing
    otherwise
        assert(false);
end
LogFileCnt = length(allLogs);
if exist([savedResultFile '.mat'],'file') && ~bStandaloneCall
    load([savedResultFile '.mat'], 'allAntPairPhsDiffRad','allValPhsStd','allmuRSSI','allstdRSSI','allValidSampleRatio','angleTruthInCycle','allantArrSDpairsPhs');
else
    allAntPairPhsDiffRad =	zeros(LogFileCnt,X.antArrayCnt,X.antSingleDiffCnt);
    allValPhsStd =        	zeros(LogFileCnt,X.antArrayCnt,X.antSingleDiffCnt);
    allmuRSSI =           	zeros(LogFileCnt,X.antArrayCnt,X.antSingleDiffCnt);
    allstdRSSI =           	zeros(LogFileCnt,X.antArrayCnt,X.antSingleDiffCnt);
    allValidSampleRatio = 	zeros(LogFileCnt,X.antArrayCnt,X.antSingleDiffCnt);
    allantArrSDpairsPhs = 	zeros(LogFileCnt,X.antArrayCnt,X.measPerLogFile,X.antSingleDiffCnt);
    angleTruthInCycle =     zeros(LogFileCnt,1);
    validRecordCnt = 0;
    
    if bEnableProgressBar
        h = waitbar(0,sprintf('processing log files in %s',strLogFolder));
    end
    for Logii0 = 0:LogFileCnt-1
        if bEnableProgressBar && mod(Logii0,2) == 0
            waitbar(Logii0/LogFileCnt,h);
        end
        if Logii0 == 58
            tt = 1;
        end
%         for cheatTrialii = 1:2
            [LogProcessResult,AntPairPhsDiffRad,ValPhsStd,muRSSI,stdRSSI,ValidSampleRatio,antArrSDpairsPhs] = ...
                ProcessBatch128uS_log([strLogFolder allLogs(Logii0+1).name],'');
            %close all;
            switch LogProcessResult
                case X.LogProcessResult.badMeas
                    % ignore result from this data file
                case X.LogProcessResult.OK
                    validRecordCnt = validRecordCnt + 1;
                    allAntPairPhsDiffRad(validRecordCnt,:,:) = AntPairPhsDiffRad;
                    allValPhsStd(validRecordCnt,:,:) = ValPhsStd;
                    allmuRSSI(validRecordCnt,:,:) = muRSSI;
                    allstdRSSI(validRecordCnt,:,:) = stdRSSI;
                    allValidSampleRatio(validRecordCnt,:,:) = ValidSampleRatio; %X.antArrayCnt,X.studyNphsCandidate,X.antSingleDiffCnt
                    allantArrSDpairsPhs(validRecordCnt,:,:,:) = antArrSDpairsPhs;
                    ctrlSigDeg = sscanf(allLogs(Logii0+1).name,'Log_%d_%d_%d.dat');
                    angleTruthInCycle(validRecordCnt) = ctrlSigDeg(2)/360;
                case X.LogProcessResult.Corruption
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % we can cheat with other existing file, but that harms the stats of result 
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    % cheatDataFile0indexed = mod(Logii0,X.datasetSpecific.PosEachCycle);
                    % if cheatDataFile0indexed == Logii0
                    %     cheatDataFile0indexed = cheatDataFile0indexed + X.datasetSpecific.PosEachCycle;
                    % end
                    % warningMsg = sprintf('%s missing, cheat with Log_%03d\n',[strLogFolder allLogs(Logii0+1).name],cheatDataFile0indexed);
                    % ButtonName = questdlg(warningMsg, '??', 'No');
                    % switch ButtonName
                    %     case 'Yes'
                    %         FileDestination = [strLogFolder allLogs(Logii0+1).name];
                    %         delete(fullfile(strLogFolder,allLogs(Logii0+1).name));
                    %         try
                    %             [DestinationFILEPATH,DestinationNAME,~] = fileparts(FileDestination);
                    %             delete([strLogFolder DestinationNAME '.mat']);
                    %         end
                    %         copyfile(fullfile(strLogFolder,allLogs(cheatDataFile0indexed+1).name),...
                    %             FileDestination);
                    %     case 'No'
                    %     otherwise
                    %         assert(false);
                    % end
                    % disp(warningMsg);
                otherwise
                    assert(false,'dfgsdhweryhrgngfdyjey');
            end
%         end
    end
    if validRecordCnt ~= LogFileCnt
        allAntPairPhsDiffRad(validRecordCnt+1:end,:,:) = [];
        allValPhsStd(validRecordCnt+1:end,:,:) = [];
        allmuRSSI(validRecordCnt+1:end,:,:) = [];
        allstdRSSI(validRecordCnt+1:end,:,:) = [];
        allValidSampleRatio(validRecordCnt+1:end,:,:) = [];
        allantArrSDpairsPhs(validRecordCnt+1:end,:,:,:) = [];
        angleTruthInCycle(validRecordCnt+1:end) = [];
    end

    if bEnableProgressBar
        close(h);
    end
    save([savedResultFile '.mat'],'allAntPairPhsDiffRad','allValPhsStd','allmuRSSI','allstdRSSI','allValidSampleRatio','angleTruthInCycle','allantArrSDpairsPhs');
end

xaxisUnit = 'cycle';
overlayCNo = false;
if bStandaloneCall
    for antArrayii = 1:X.antArrayCnt
        for diffPair_ii = 1:X.antSingleDiffCnt
            strPhsHistFig = sprintf('%sPhsHist_arr%d_ele%d',savedResultFile,antArrayii,diffPair_ii);
            hPhsHistFig = figure('Name',sprintf('distribution of Phs result for arr%d,(%s)',antArrayii-1,getStrAntPair(diffPair_ii-1)),'NumberTitle','off');
            for ii = 1:X.datasetSpecific.PosEachCycle
                subplot(5,4,ii);
                dataAtPos = squeeze(allAntPairPhsDiffRad(ii:19:end,antArrayii,diffPair_ii));
                %hist(dataAtPos);xlim([-pi,pi]);
                plot(dataAtPos,'.-');ylim([-pi,pi]);
                title(sprintf('anglar Pos:%dDeg',(ii-1)*X.datasetSpecific.StepDeg));
                
            end
            if ~exist([strPhsHistFig '.jpg'],'file')
                CMathHelper.savePlot(hPhsHistFig,strPhsHistFig);
            end
        end
    end
end
for antArrayii = 1:X.antArrayCnt
    strPhsEstFig = sprintf('%s%s%d',savedResultFile,'PhsEst',antArrayii);
    strPhsEstMetaFig = sprintf('%s%s%d',savedResultFile,'PhsEstMeta',antArrayii);
    if bStandaloneCall || ~exist([strPhsEstFig '.jpg'],'file')% || ~exist([strPhsEstMetaFig '.jpg'],'file')
        hPhsEstFig = figure('Name',sprintf('Phs estimate, array%d',antArrayii),'NumberTitle','off');
        columnNum = 3;
        plotii = 1;

%         hMetaFig = figure('Name',sprintf('estimation Meta info, array%d',antArrayii),'NumberTitle','off');
%         MetaColumnNum = 5;
%         MetaPlotii = 1;
        for diffPair_ii = 1:X.antSingleDiffCnt
            if antArrayii == 2 && diffPair_ii == 2
                tt = 1;
            end
            if true
                selectedIdx = 1:size(allAntPairPhsDiffRad,1);
                invalidIdx = [];
            else
                selectedIdx = find(...
                    allValidSampleRatio(:,antArrayii,1,diffPair_ii)>0.7 & ...
                    allValPhsStd(:,antArrayii,1,diffPair_ii) < 0.25 & ...
                    allmuRSSI(:,antArrayii,1,diffPair_ii) > -85 ...
                );
                invalidIdx = 1:X.datasetSpecific.LogFileCntTrain;
                invalidIdx(selectedIdx) = [];
            end
            %%%%%%%%%%%%%%%%%%%%%%%
            phs_rad = allAntPairPhsDiffRad(selectedIdx,antArrayii,diffPair_ii);
            figure(hPhsEstFig);
            subplot(X.antSingleDiffCnt,columnNum,plotii);plotii = plotii + 1;
            plot(angleTruthInCycle(selectedIdx),phs_rad/pi,'.-');
            %hold on;
            %plot(angleTruthInCycle(invalidIdx),zeros(1,length(invalidIdx)),'r.-');
            %plot(angleTruthInCycle(selectedIdx),zeros(length(selectedIdx),1),'g.');
            xlabel(sprintf('base rotation(%s)', xaxisUnit));
            ylabel('cycle');
            title(sprintf('ant%s',getStrAntPair(diffPair_ii-1)));grid on;
            if diffPair_ii == round(X.antSingleDiffCnt/2)
                ylabel('[-1,1]\equiv 1 cycle');
            end
            %%%%%%%%%%%%%%%%%%%%%%%
            subplot(X.antSingleDiffCnt,columnNum,plotii);plotii = plotii + 1;
            antDistance = abs(X.antPair(diffPair_ii,1) - X.antPair(diffPair_ii,2));
            if overlayCNo
                [ax, h1, h2] = plotyy(angleTruthInCycle(selectedIdx),unwrap(phs_rad)/antDistance,angleTruthInCycle(selectedIdx),allmuRSSI(selectedIdx,antArrayii));grid on;
                set(h1,'Marker','.','MarkerSize',8, 'MarkerEdgeColor','red', 'MarkerFaceColor',[1 .6 .6]);
                set(h2,'Marker','.','MarkerSize',8, 'MarkerEdgeColor','green', 'MarkerFaceColor',[1 .6 .6]);
            else
                plot(angleTruthInCycle(selectedIdx),unwrap(phs_rad)/antDistance,'.-');grid on;
            end
            %hold on;
            %plot(angleTruthInCycle(invalidIdx),zeros(1,length(invalidIdx)),'r.');
            %plot(angleTruthInCycle(selectedIdx),zeros(length(selectedIdx),1),'g.');
            ylabel(sprintf('unwrap \\times%d',antDistance));
            %%%%%%%%%%%%%%%%%%%%%%%
            subplot(X.antSingleDiffCnt,columnNum,plotii);plotii = plotii + 1;
            plot(angleTruthInCycle,allValidSampleRatio(:,antArrayii,diffPair_ii),'.-');
            xlabel(xaxisUnit);
            title('valid sample ratio');grid on;
            %%%%%%%%%%%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%
%             figure(hMetaFig);
%             %%%%%%%%%%%%%%%%%%%%%%%
%             subplot(X.antSingleDiffCnt,MetaColumnNum,MetaPlotii);MetaPlotii = MetaPlotii + 1;
%             plot(angleTruthInCycle,allmuRSSI(:,antArrayii,diffPair_ii),'.-');
%             title('adopted \mu_{RSSI}');
%             %%%%%%%%%%%%%%%%%%%%%%%
%             subplot(X.antSingleDiffCnt,MetaColumnNum,MetaPlotii);MetaPlotii = MetaPlotii + 1;
%             plot(angleTruthInCycle,allstdRSSI(:,antArrayii,diffPair_ii),'.-');
%             title('adopted \sigma_{RSSI}');
%             %%%%%%%%%%%%%%%%%%%%%%%
%             subplot(X.antSingleDiffCnt,MetaColumnNum,MetaPlotii);MetaPlotii = MetaPlotii + 1;
%             plot(angleTruthInCycle,allmuRSSI(:,antArrayii,X.rejectedResults,diffPair_ii),'.-');
%             title('rejected \mu_{RSSI}');
%             %%%%%%%%%%%%%%%%%%%%%%%
%             subplot(X.antSingleDiffCnt,MetaColumnNum,MetaPlotii);MetaPlotii = MetaPlotii + 1;
%             plot(angleTruthInCycle,allstdRSSI(:,antArrayii,X.rejectedResults,diffPair_ii),'.-');
%             title('rejected \sigma_{RSSI}');
%             %%%%%%%%%%%%%%%%%%%%%%%
%             subplot(X.antSingleDiffCnt,MetaColumnNum,MetaPlotii);MetaPlotii = MetaPlotii + 1;
%             aa = allstdRSSI(:,antArrayii,X.rejectedResults,diffPair_ii);
%             bb = (1-allValidSampleRatio(:,antArrayii,diffPair_ii));
%             hold on;
%             plot(angleTruthInCycle,aa.*bb,'.-');
%             plot(angleTruthInCycle(invalidIdx),zeros(1,length(invalidIdx)),'r.-');plot(angleTruthInCycle(selectedIdx),zeros(length(selectedIdx),1),'g.-');
        end
        CMathHelper.savePlot(hPhsEstFig,strPhsEstFig);
%         CMathHelper.savePlot(hMetaFig,strPhsEstMetaFig);
    end
end
end

function [peakMag, newdat] = Normalized(dat)
peakMag = max(abs(dat));
if abs(peakMag) > 1e-9
    newdat = dat/peakMag;
else
    newdat = dat;
end
end