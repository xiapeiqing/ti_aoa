function [PhsMeanRad,PhsStdRad,indexSelected,IndexRemaining] = KmeanMerge_rad(originalPhsRad,kmeanIniClusterCnt)
% input data can be vector/matrix, we don't care. analyze all elements
global X;
if nargin < 2
    kmeanIniClusterCnt = X.kmeanIniClusterCnt;
end
if length(originalPhsRad) < 2*kmeanIniClusterCnt
    kmeanIniClusterCnt = floor(length(originalPhsRad)/2);
end

originalPhsRad = originalPhsRad(:); % kmeans doesn't accept row vector 
if std(originalPhsRad) < 0.5*X.KmeanMergeThresRad
    % deemed as one cluster
    PhsMeanRad = mean(originalPhsRad);
    PhsStdRad = std(originalPhsRad);
    indexSelected = 1:length(originalPhsRad);
    IndexRemaining = [];
else
    kmeanGroupIDX = kmeans(originalPhsRad,kmeanIniClusterCnt);
    occurrenceCnt = zeros(1,kmeanIniClusterCnt);
    meanValClusters = zeros(1,kmeanIniClusterCnt);
    indexOriginalData = cell(1,kmeanIniClusterCnt);
    for clii = 1:kmeanIniClusterCnt
        thisindex = find(kmeanGroupIDX == clii);
        occurrenceCnt(clii) = length(thisindex);
        valsInThisCluster = originalPhsRad(thisindex);
        meanValClusters(clii) = mean(valsInThisCluster);
        indexOriginalData{clii} = thisindex;
    end

    [occurrenceCnt,IndexInUnsortData] = sort(occurrenceCnt,'descend'); % sortedOccurrence = occurrenceCnt(sortOccurIndex)
    meanValClusters = meanValClusters(IndexInUnsortData);
    indexOriginalData = changeCellIndex(indexOriginalData,IndexInUnsortData);
    PhsMeanRad = meanValClusters(1);
    if false
       figure;
       errorbar(meanValClusters,ones(1,length(meanValClusters)),occurrenceCnt);
       xlabel('rad');
       ylabel('number of meas in this cluster');
    end

    AdoptedCnt = occurrenceCnt(1);
    indexOriginalData{1} = {};
    for sorted_clii = 2:kmeanIniClusterCnt
        if abs(modmPitoPi(meanValClusters(sorted_clii) - PhsMeanRad)) < X.KmeanMergeThresRad
            PhsMeanRad = add_pm_pi(PhsMeanRad,meanValClusters(sorted_clii),AdoptedCnt,occurrenceCnt(sorted_clii));
            AdoptedCnt = AdoptedCnt + occurrenceCnt(sorted_clii);
            indexOriginalData{sorted_clii} = {};
        end
    end
    IndexRemaining = [];
    for clii = 2:kmeanIniClusterCnt
        if ~isempty(indexOriginalData{clii})
            IndexRemaining = [IndexRemaining; indexOriginalData{clii}];
        end
    end

    indexSelected = 1:length(originalPhsRad);
    indexSelected(IndexRemaining) = [];

    acceptedData = originalPhsRad(indexSelected);
    [~,PhsStdRad,~] = stats_pmPi(acceptedData);
end
end
