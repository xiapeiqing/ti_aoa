function [PhsMean,PhsStd,SnrMean,SnrStd,SampleRatio] = KmeanMergeFirstNcandidates(phsDataRad,SNRdata,candidateCnt,acceptanceRatio)

if nargin < 3
    candidateCnt = X.studyNphsCandidate;
end
if nargin < 4
    acceptanceRatio = 0.1;
end
% input data can be vector/matrix, we don't care. analyze all elements
global X;
phsDataRad = phsDataRad(:);
remainingPhsData = phsDataRad;
remainingSNRdata = SNRdata;
PhsMean = zeros(candidateCnt,1)*NaN;
PhsStd  = zeros(candidateCnt,1)*NaN;
SnrMean = zeros(candidateCnt,1)*NaN;
SnrStd  = zeros(candidateCnt,1)*NaN;
SampleRatio = zeros(candidateCnt,1)*NaN;
for ii = 1:candidateCnt
    [PhsMean(ii),PhsStd(ii),indexSelected,IndexRemaining] = KmeanMerge_rad(remainingPhsData);
    SampleRatio(ii) = (length(remainingPhsData)-length(IndexRemaining))/length(phsDataRad);

    SNRdataSelected = remainingSNRdata(indexSelected);
    SnrMean(ii) = mean(SNRdataSelected);
    SnrStd(ii)  = std(SNRdataSelected);

    remainingPhsData = remainingPhsData(IndexRemaining);
    remainingSNRdata = remainingSNRdata(IndexRemaining);
    
    if length(remainingPhsData) <= acceptanceRatio*length(phsDataRad)
        break;
    end
end
end

