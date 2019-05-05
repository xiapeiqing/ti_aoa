function PosDeg = estimatePos(muLUTs,sigmaLUTs,LUTangleDeg,meas,algoChoice)
global X;
switch algoChoice
%     case 'multiplyWeightedErrSum'
%         PosCostVal = zeros(1,X.datasetSpecific.PosEachCycle);
%         for posii = 1:X.datasetSpecific.PosEachCycle
%             muLUT       = muLUTs(posii,:);
%             sigmaLUT    = sigmaLUTs(posii,:);
%             PosCostVal(posii) = sum(abs(modmPitoPi(muLUT - meas)).*sigmaLUT); % bad
%         end
%         [~,ii] = min(PosCostVal);
%         PosDeg = (ii-1)*X.datasetSpecific.stepDeg;
%     case 'best5elementLUT'
%         PosCostVal = zeros(1,X.datasetSpecific.PosEachCycle);
%         for posii = 1:X.datasetSpecific.PosEachCycle
%             muLUT       = muLUTs(posii,:);
%             sigmaLUT    = sigmaLUTs(posii,:);
%             [~,ii] = sort(sigmaLUT);
%             ii = ii(1:5);
%             PosCostVal(posii) = sum(abs(modmPitoPi(muLUT(ii) - meas(ii))));
%         end
%         [~,ii] = min(PosCostVal);
%         PosDeg = (ii-1)*X.datasetSpecific.stepDeg;
%     case 'NLweightedErrSum'
%         PosCostVal = zeros(1,X.datasetSpecific.PosEachCycle);
%         referenceSigma = prctile(muLUTs(:),50);
%         for posii = 1:X.datasetSpecific.PosEachCycle
%             muLUT       = muLUTs(posii,:);
%             sigmaLUT    = sigmaLUTs(posii,:);
%             PosCostVal(posii) = sum(abs(modmPitoPi(muLUT - meas)).*((sigmaLUT/referenceSigma).^2)); % bad
%         end
%         [~,ii] = min(PosCostVal);
%         PosDeg = (ii-1)*X.datasetSpecific.stepDeg;
%     case 'dropOneAndCompared'
%         PosCostVal = zeros(size(muLUTs));
%         Coeff = ones(X.LUTcnt,X.LUTcnt);
%         for ii = 1:X.LUTcnt
%             Coeff(ii,ii) = 0;
%         end
%         for posii = 1:size(muLUTs,1)
%             muLUT       = muLUTs(posii,:);
%             sigmaLUT    = sigmaLUTs(posii,:);
%             for studyii = 1:X.LUTcnt
%                 indexSelection = 1:X.LUTcnt;
%                 indexSelection(studyii) = [];
%                 PosCostVal(posii,studyii) = sum(abs(modmPitoPi(muLUT(indexSelection) - meas(indexSelection))));
%             end
%         end
%         [~,ii] = min(PosCostVal);
%         PosCandidates_rad = LUTangleDeg(ii)*pi/180;%(ii-1)*X.datasetSpecific.stepDeg*pi/180;
%         [PhsMean,estPhsStd,indexSelected,IndexRemaining] = KmeanMerge_rad(PosCandidates_rad,2);
%         if length(indexSelected) >= 5
%             PosDeg = PhsMean*180/pi;
%         else
%             PosDeg = NaN;
%         end
    case 'drop2AndCompared'
        PosDeg = dropNAndCompared(muLUTs,sigmaLUTs,meas,LUTangleDeg,2);
    otherwise
        assert(false);
end
end

function PosDeg = dropNAndCompared(muLUTs,sigmaLUTs,meas,LUTangleDeg,N)
% muLUTs: X.datasetSpecific.PosEachCycle,X.LUTcnt
global X;
candidateCntAfterDrop = X.LUTcnt;
for ii = 1:N-1
    candidateCntAfterDrop = candidateCntAfterDrop*(X.LUTcnt-ii);
end
for ii = 2:N
    candidateCntAfterDrop = candidateCntAfterDrop/ii;
end
biasMagnitude = abs(muLUTs-meas);
Coeff = ones(X.LUTcnt,candidateCntAfterDrop);
combii = 0;
assert(N==2,'replace it with recursive function');
for loop1ii = 1:X.LUTcnt-1
    for loop2ii = loop1ii+1:X.LUTcnt
        combii = combii + 1;
        Coeff([loop1ii,loop2ii],combii) = 0;
    end
end
algoChoice = 1;
switch algoChoice
    case 1
        PosCostVal = biasMagnitude*Coeff;
        [~,ii] = min(PosCostVal);
        PosCandidates_rad = LUTangleDeg(ii)*pi/180;
        [PhsMean,~,indexSelected,~] = KmeanMerge_rad(PosCandidates_rad,2);
        if length(indexSelected) >= candidateCntAfterDrop*0.65
            PosDeg = PhsMean*180/pi;
        else
            PosDeg = NaN;
        end
    case 2
        selection = 1:X.datasetSpecific.PosEachCycle;
        for jj = 1:X.LUTcnt
            singleMeasLUT = muLUTs(:,jj);
            thisSel = find(abs(singleMeasLUT-meas(jj))<1);
            selection = intersect(selection,thisSel);
        end
        if isempty(selection)
            PosDeg = 0;
        else
            PosDeg = NaN;
        end
%     case 2
%         this_pPosterior = NP_Parzen_Classifier(muLUTs',sigmaLUTs',1:6,meas');
%         [~,pPosterior_ii] = max(this_pPosterior);
%         PosDeg = LUTangleDeg(pPosterior_ii);
%     case 3
%         pPosterior_ii = zeros(1,size(Coeff,2));
%         for subsetii = 1:size(Coeff,2)
%             this_pPosterior = NP_Parzen_Classifier(muLUTs',sigmaLUTs',find(Coeff(:,subsetii)==1),meas');
%             [~,pPosterior_ii(subsetii)] = max(this_pPosterior);
%         end
%         pPosteriorRad = LUTangleDeg(pPosterior_ii)*pi/180;
%         [PhsMean,~,indexSelected,~] = KmeanMerge_rad(pPosteriorRad,2);
%         if length(indexSelected) >= candidateCntAfterDrop*0.65
%             PosDeg = PhsMean*180/pi;
%         else
%             PosDeg = NaN;
%         end
    otherwise
        assert(false);
end
end
