function [LogProcessResult,PhsDiffKmeanRad,PhsStd,muRSSI,stdRSSI,ValidSampleRatio,antSDpairsPhsRawRad] = ...
    ProcessBatch128uS_log(logfile,strDescription,allowUsingSaveMatResult)
bStandaloneCall = false;
if nargin < 3
    allowUsingSaveMatResult = true;
end
if nargin < 2
    strDescription = '';
end
if nargin < 1
    %logfile = '../Host_workspaces/datalog/Log_083_01510_00.dat';
    logfile = '../Host_workspaces/datalog/Log_064_01150_00.dat';
    disp(logfile);
    clear global X;
    bStandaloneCall = true;
end
%bStandaloneCall = true;
global X;
if ~isfield(X,'datasetSpecific')
    globalSettings_datasetSpecific('Lab',0);
end
strDescription = sprintf('%s%s',strDescription,X.algor);
[FILEPATH,fielNAME,~] = fileparts(logfile);
savedMatFile = sprintf('%s/%s.mat',FILEPATH,fielNAME);
if exist(savedMatFile,'file') && ~bStandaloneCall && allowUsingSaveMatResult
    load(savedMatFile);
else
    [timestampMs,AntArrayAx,packetId,RFchannel,RSSI,IFsample] = loadM2RbBinaryLog(logfile,'');
    if allowUsingSaveMatResult
        save(savedMatFile, 'timestampMs', 'AntArrayAx', 'packetId', 'RFchannel', 'RSSI', 'IFsample');
    end
end
if false
    figure;
    subplot(311);plot(AntArrayAx,'.-');title('antenna array');
    subplot(312);plot(packetId,'.-');title('packet');
    subplot(313);plot(RFchannel,'.-');title('RF channel');xlabel('128uS pkt#');
end
assert(length(packetId) == length(AntArrayAx));
assert(length(RFchannel) == length(AntArrayAx));
pktCnt  = length(AntArrayAx);

if mod(pktCnt,X.antArrayCnt)~=0 || length(timestampMs) ~= X.datasetSpecific.AoArcvSPIlogPktCnt
    LogProcessResult = X.LogProcessResult.Corruption;
    PhsDiffKmeanRad = [];
    PhsStd = [];
    muRSSI = [];
    stdRSSI = [];
    ValidSampleRatio = [];
    antSDpairsPhsRawRad = [];
else
    LogProcessResult = X.LogProcessResult.OK;
    Ngroups = 2;
    PhsDiffKmeanRad =   zeros(X.antArrayCnt,Ngroups,X.antSingleDiffCnt);
    PhsStd =            zeros(X.antArrayCnt,Ngroups,X.antSingleDiffCnt);
    muRSSI  =           zeros(X.antArrayCnt,Ngroups,X.antSingleDiffCnt);
    stdRSSI =           zeros(X.antArrayCnt,Ngroups,X.antSingleDiffCnt);
    ValidSampleRatio =  zeros(X.antArrayCnt,Ngroups,X.antSingleDiffCnt);
    antSDpairsPhsRawRad = zeros(X.antArrayCnt,pktCnt/X.antArrayCnt,X.antSingleDiffCnt);

    for antArrayii0 = 0:X.antArrayCnt-1
        IndexAntArray = find(AntArrayAx == antArrayii0);
        RssiAntArray = RSSI(IndexAntArray);
        
        IqErrRad                        = zeros(pktCnt/X.antArrayCnt,length(X.cycleAnt));
        QoS                             = zeros(pktCnt/X.antArrayCnt,length(X.cycleAnt));
        AllcomplexPhsApproxRateRad      = zeros(pktCnt/X.antArrayCnt,length(X.cycleAnt));
        AllcomplexPhsApproxErrStdRad    = zeros(pktCnt/X.antArrayCnt,length(X.cycleAnt));
        PhsRad                          = zeros(pktCnt/X.antArrayCnt,length(X.cycleAnt));
        
        for pktii1 = IndexAntArray %  9:10%
            if pktii1 == 400
                tt = 1;
            end
            IFdat = IFsample(:,pktii1);
            pktii_AntArray = floor((pktii1-1)/X.antArrayCnt)+1;
            for antii = 1:length(X.cycleAnt)
                % switch among all antenna elements, ~4uS/3 each
                selIndex = 1+sum(X.cycleAnt(1:antii-1))*16:sum(X.cycleAnt(1:antii))*16;
                ANTxIF_CplxDat = IFdat(selIndex);
                ANTxIF_CplxDat = ANTxIF_CplxDat(1+X.removeHead:end-X.removeTail);
                switch X.algor
                    case 'UnwrapPhs'
                        [~,complexPhsApproxRad] = unwrapIQ2freqEst(ANTxIF_CplxDat,'',false); % bStandaloneCall
                        PhsRad(pktii_AntArray,antii) = complexPhsApproxRad(1);
                        AllcomplexPhsApproxRateRad(pktii_AntArray,antii) = complexPhsApproxRad(2);
                        AllcomplexPhsApproxErrStdRad(pktii_AntArray,antii) = complexPhsApproxRad(3);
                    case 'IQindepen'
                        [thisIQphsRad,QoSiqErrRad,thisQoS] = studyIQseperately(ANTxIF_CplxDat);
                        % when Phs(I) is 1, which is 1*j*e^(0), Phs(Q) is i, which is 1*j*e^(pi/2)
                        IqErrRad(pktii_AntArray,antii) = QoSiqErrRad;
                        QoS(pktii_AntArray,antii) = thisQoS;
                        PhsRad(pktii_AntArray,antii) = thisIQphsRad;
                    otherwise
                        assert(false);
                end
            end
        end
        [PhsDiffKmeanRad(antArrayii0+1,:,:),PhsStd(antArrayii0+1,:,:),muRSSI(antArrayii0+1,:,:),stdRSSI(antArrayii0+1,:,:),...
            ValidSampleRatio(antArrayii0+1,:,:),antSDpairsPhsRawRad(antArrayii0+1,:,:)] = AnalyzePhsArray...
            (timestampMs,Ngroups,PhsRad,RssiAntArray,sprintf('A%d%s',antArrayii0+1,strDescription),FILEPATH,fielNAME,bStandaloneCall,antArrayii0);
        if antArrayii0 == 0 && false
            figure;
            for anteleii = 0:2
                if antArrayii0 == 0 && anteleii == 0
                    title('raw phs(rad)');
                end
                %subplot(3,2,anteleii*2+antArrayii0+1);
                subplot(3,1,anteleii+1);
                plot(PhsRad(:,anteleii+1));
                if antArrayii0 == 0
                    ylabel(sprintf('ele%d',anteleii));
                end
                if anteleii == 0
                    title(sprintf('ant arr%d',antArrayii0));
                end
            end
            figure;
            arraychoice0 = 0;
            SDpairchoice0 = 0;
            plot(antSDpairsPhsRawRad(arraychoice0+1,:,SDpairchoice0+1));
            title(sprintf('array%dant(%s)',arraychoice0,getStrAntPair(SDpairchoice0)));
%             disp('antSDpairsPhsRawRad');
%             disp(squeeze(antSDpairsPhsRawRad(1,1:3,:)));
%             disp('PhsRad');
%             disp(PhsRad(1:3,:));
            tt = 1;
        end
    end
    ValidSampleRatio2Cand = zeros(X.antArrayCnt,X.antSingleDiffCnt);
    for ii = 1:X.antArrayCnt
        ValidSampleRatio2Cand(ii,:) = sum(squeeze(ValidSampleRatio(ii,:,:)));
        if ~isempty(find(ValidSampleRatio2Cand(ii,:) < 0.75,1))
            LogProcessResult = X.LogProcessResult.badMeas;
        end
    end
    [PhsDiffKmeanRad,PhsStd,muRSSI,stdRSSI,ValidSampleRatio] = Proc120degAmbiguity(Ngroups,PhsDiffKmeanRad,PhsStd,muRSSI,stdRSSI,ValidSampleRatio);
    %disp(PhsDiffKmeanRad);
end
end

function [newPhsDiffKmeanRad,newPhsStd,newmuRSSI,newstdRSSI,newValidSampleRatio] = Proc120degAmbiguity...
    (Ngroups,PhsDiffKmeanRad,PhsStd,muRSSI,stdRSSI,ValidSampleRatio)
%(X.antArrayCnt,Ngroups,X.antSingleDiffCnt)=>(X.antArrayCnt,X.antSingleDiffCnt)
global X;
assert(Ngroups == 2);
newPhsDiffKmeanRad = zeros(X.antArrayCnt,X.antSingleDiffCnt);
newPhsStd = zeros(X.antArrayCnt,X.antSingleDiffCnt);
newmuRSSI = zeros(X.antArrayCnt,X.antSingleDiffCnt);
newstdRSSI = zeros(X.antArrayCnt,X.antSingleDiffCnt);
newValidSampleRatio = zeros(X.antArrayCnt,X.antSingleDiffCnt);

for arrii = 1:X.antArrayCnt
    PhsDiffKmeanRad_arrii = squeeze(PhsDiffKmeanRad(arrii,:,:));
    PhsStd_arrii = squeeze(PhsStd(arrii,:,:));
    muRSSI_arrii = squeeze(muRSSI(arrii,:,:));
    stdRSSI_arrii = squeeze(stdRSSI(arrii,:,:));
    ValidSampleRatio_arrii = squeeze(ValidSampleRatio(arrii,:,:));
    for pairii = 1:X.antSingleDiffCnt
        [maxRatio,maxRatio_ii] = max(ValidSampleRatio_arrii(:,pairii));
        if maxRatio > 0.8
            % absolute dominance
            newPhsDiffKmeanRad(arrii,pairii) = PhsDiffKmeanRad_arrii(maxRatio_ii,pairii);
            newPhsStd(arrii,pairii) = PhsStd_arrii(maxRatio_ii,pairii);
            newmuRSSI(arrii,pairii) = muRSSI_arrii(maxRatio_ii,pairii);
            newstdRSSI(arrii,pairii) = stdRSSI_arrii(maxRatio_ii,pairii);
            newValidSampleRatio(arrii,pairii) = ValidSampleRatio_arrii(maxRatio_ii,pairii);
        else
%     1.3593   -2.1694    2.7627
%     2.5735    2.3184    0.8495
            distRad = abs(PhsDiffKmeanRad_arrii(1,pairii)-PhsDiffKmeanRad_arrii(2,pairii));
            if distRad > pi
                unwrapped_distRad = 2*pi - distRad;
            else
                unwrapped_distRad = distRad;
            end
            if abs(unwrapped_distRad - pi*2/3) < pi/6
                if distRad > pi
                    [newPhsDiffKmeanRad(arrii,pairii),selection_ii] = max(PhsDiffKmeanRad_arrii(:,pairii));
                else
                    [newPhsDiffKmeanRad(arrii,pairii),selection_ii] = min(PhsDiffKmeanRad_arrii(:,pairii));
                end
            else
                [~,selection_ii] = max(newValidSampleRatio(:,pairii));
                newPhsDiffKmeanRad(arrii,pairii) = PhsDiffKmeanRad_arrii(selection_ii,pairii);
            end
            newPhsStd(arrii,pairii) = PhsStd_arrii(selection_ii,pairii);
            newmuRSSI(arrii,pairii) = muRSSI_arrii(selection_ii,pairii);
            newstdRSSI(arrii,pairii) = stdRSSI_arrii(selection_ii,pairii);
            newValidSampleRatio(arrii,pairii) = ValidSampleRatio_arrii(selection_ii,pairii);
        end
    end
end
end

function [PhsDiffKmeanRad,PhsStd,muRSSI,stdRSSI,ValidSampleRatio,antSDpairsPhsRawRad] = AnalyzePhsArray...
    (timestampMs, Ngroups, AntArrayRad, RSSI, StrComments, FILEPATH,fielNAME,bStandaloneCall,antArrayii0)
global X;
PhsDiffKmeanRad = zeros(Ngroups,X.antSingleDiffCnt);
ValidSampleRatio    = zeros(Ngroups,X.antSingleDiffCnt);
muRSSI              = zeros(Ngroups,X.antSingleDiffCnt);
stdRSSI             = zeros(Ngroups,X.antSingleDiffCnt);
PhsStd              = zeros(Ngroups,X.antSingleDiffCnt);

antSDpairsPhsRawRad = zeros(size(AntArrayRad,1),X.antSingleDiffCnt);
for ant_pair_ii = 1:X.antSingleDiffCnt
    antPhsSDrawRad = modmPitoPi(AntArrayRad(:,X.antPair(ant_pair_ii,1))-AntArrayRad(:,X.antPair(ant_pair_ii,2)));
    antSDpairsPhsRawRad(:,ant_pair_ii) = antPhsSDrawRad;
    [PhsDiffKmeanRad(:,ant_pair_ii),PhsStd(:,ant_pair_ii), muRSSI(:,ant_pair_ii),stdRSSI(:,ant_pair_ii),ValidSampleRatio(:,ant_pair_ii)]...
        = KmeanMergeFirstNcandidates(antPhsSDrawRad,RSSI,Ngroups,0.1);
end
visualizePhsEstimate(Ngroups,antSDpairsPhsRawRad,RSSI,PhsDiffKmeanRad,ValidSampleRatio,PhsStd,FILEPATH,fielNAME,StrComments,StrComments,bStandaloneCall);
end

function visualizePhsEstimate(Ngroups,antSDpairsPhsRawRad,RSSI,PhsDiffKmeanRad,ValidSampleRatio,PhsStd,FILEPATH,fielNAME,strFigDescription,saveFilePrefix,bStandaloneCall)
global X;
savedResultFile = sprintf('%s/%s%s',FILEPATH,fielNAME,saveFilePrefix);
if bStandaloneCall
    hFig = figure('name',strFigDescription);
    antPairCnt = X.antSingleDiffCnt;
    FigPerRow = 3;
    plotSubFigii = 1;
    for iiRow = 1:antPairCnt
        thisPhsDiffResultRad = PhsDiffKmeanRad(:,iiRow);
        thisValidSampleRatio = ValidSampleRatio(:,iiRow);
        candidateCnt = 0;
        for ii = 1:Ngroups
            if thisValidSampleRatio(ii) > 0.1
                candidateCnt = candidateCnt + 1;
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        subplot(antPairCnt,FigPerRow,plotSubFigii); plotSubFigii = plotSubFigii + 1;
        compass(exp(1j*thisPhsDiffResultRad(1:candidateCnt)).*thisValidSampleRatio(1:candidateCnt));
        title(sprintf('%dCandidates(\\Delta=%2.1f)',candidateCnt,modmPitoPi(thisPhsDiffResultRad(2)-thisPhsDiffResultRad(1))*180/pi));
        if iiRow == 1
            xlabel(strFigDescription);
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        subplot(antPairCnt,FigPerRow,plotSubFigii); plotSubFigii = plotSubFigii + 1;
        if iiRow == 2
            tt = 1;
        end
        plot(antSDpairsPhsRawRad(:,iiRow)/pi,'o');
        ylabel(strFigDescription);ylim([-1,1]);
        hold on;
        for ii = 1:candidateCnt
            if ii == 1
                linetype = 'r.-';
            else
                linetype = 'b.-';
            end
            plot(thisPhsDiffResultRad(ii)*ones(1,size(antSDpairsPhsRawRad,1))/pi,linetype);
        end
        ylabel('[-1,1]\equiv360^{o}');
        title(getStrAntPair(iiRow-1));
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        if false
            subplot(antPairCnt,FigPerRow,plotSubFigii); plotSubFigii = plotSubFigii + 1;
            hist(antSDpairsPhsRawRad(:,iiRow)/pi,-1:0.1:1);
            xlabel('[-1,1]\equiv360^{o}');
            if iiRow == 1
                title(sprintf('%2.1f%% correct esti',100*thisValidSampleRatio(1)));
            else
                title(sprintf('%2.1f%%',100*thisValidSampleRatio(1)));
            end
        end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        subplot(antPairCnt,FigPerRow,plotSubFigii); plotSubFigii = plotSubFigii + 1;
        plot(RSSI,'b.')
        ylim([-100 -45]);
        ylabel('dBm');
    end
    if ~exist([savedResultFile '.jpg'],'file')
        CMathHelper.savePlot(hFig,savedResultFile);
    end
end
end


function [screeneddata,index] = removeOutliers(data,ratio0to1)
assert(ratio0to1 > 0 && ratio0to1 < 1);
err = abs(data-mean(data));
thres = prctile(err,ratio0to1*100);
index = find(err<=thres);
screeneddata = data(index);
end

function str = GaussianApprox(data)
assert(size(data,2)==1);
data = data-mean(data);
stdData = std(data);
RateSigma = zeros(1,3);
for sigmaii = 1:3
    RateSigma(sigmaii) = length(find(abs(data)<sigmaii*stdData))/length(data);
end
distribution = round(RateSigma*100);
str = sprintf('%d/%d/%d',distribution(1),distribution(2),distribution(3));
str = sprintf('%s 68/95/99.7rule',str);
end
