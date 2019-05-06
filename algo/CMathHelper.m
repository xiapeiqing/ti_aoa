classdef CMathHelper
    properties (Constant = true)
        TickMs = 20;
        MaxUDPpacketLength = 65508;
        SoL = 299792458;
    end
    
    methods (Static = true)
        
        function doPlot = shallwePlot(ImportanceLevel,savefilepath) % 0 being most critical
            if nargin < 2
                savefilepath = '';
            end
            global X;
            
            if ~isfield(X,'plotLevel')
                doPlot = true;
            else
                if ~isfield(X.plotLevel,'Thres')
                    doPlot = true;
                else
                    if ImportanceLevel <= X.plotLevel.Thres
                        doPlot = true;
                    else
                        doPlot = false;
                    end
                end
            end
            
            if doPlot && ~isempty(savefilepath) && exist(savefilepath,'file')
                doPlot = false;
            end
        end

        function savePlot(h_fig,figfilename)
            [a,b,ext]=fileparts(figfilename);
            if isempty(a)
                constructedfilename = ['..\testdata\' figfilename];
            else
                constructedfilename = [a '\' b];
            end
            saveas(h_fig, constructedfilename, 'jpg')
            if isempty(ext)
                saveas(h_fig, constructedfilename, 'fig')
            end
        end
        
        function Day = Ms2Day(Ms)
            assert(Ms >= 0);
            Day = Ms / 1000 / 24 / 3600;
        end
        
        function TickS = getTickS()
            TickS = 100e-3;
        end
        
        function Coeff = BuildCoefLSE(SamplingTimeS,order)
            if nargin == 1
                order = UWBcfg.LSE_Coeff;
            end
            sampleCnt = length(SamplingTimeS);
            switch order
                case 1
                    Coeff = ones(sampleCnt,1);
                case 2
                    Coeff = [ones(sampleCnt,1) SamplingTimeS];
                case 3
                    Coeff = [ones(sampleCnt,1) SamplingTimeS SamplingTimeS.^2];
                case 4
                    Coeff = [ones(sampleCnt,1) SamplingTimeS SamplingTimeS.^2 SamplingTimeS.^3];
                otherwise
                    assert(false);
            end
        end
        
        function Coef = LSE(SamplingTimeS,TimeTagMeas,order)
            if nargin == 2
                order = UWBcfg.LSE_Coeff;
            end
            EstimateCoeff = CMathHelper.BuildCoefLSE(SamplingTimeS,order);
            meanTimeTagMeas = mean(TimeTagMeas);
            demeanTimeTagMeas = TimeTagMeas - meanTimeTagMeas;
            Coef = (EstimateCoeff'*EstimateCoeff)^-1*EstimateCoeff'*demeanTimeTagMeas;
            Coef(1) = Coef(1) + meanTimeTagMeas;
        end
        
        function ReconstructedData = PolynomialCoef2DataSeq(SamplingTimeS,PolynomialCoef)
            PredictMatrix = CMathHelper.BuildCoefLSE(SamplingTimeS,length(PolynomialCoef));
            ReconstructedData = PredictMatrix*PolynomialCoef;
        end
        
        function newcurve = CurveFit(SamplingTimeS,TimeTagMeas,order)
            if nargin == 2
                order = UWBcfg.LSE_Coeff;
            end
            Coef = CMathHelper.LSE(SamplingTimeS,TimeTagMeas,order);
            newcurve = CMathHelper.PolynomialCoef2DataSeq(SamplingTimeS,Coef);
        end
        
        function Err = ReconstructErr(SamplingTimeS,TimeTagMeas,order)
            if nargin == 2
                order = UWBcfg.LSE_Coeff;
            end
            Err = TimeTagMeas - CMathHelper.CurveFit(SamplingTimeS,TimeTagMeas,order);
        end
        
		function [seldata,index] = removeoutliers(inputdata,stdRatio,trialTimes)
            if nargin < 3
                trialTimes = 1;
            end
            if nargin < 2
                stdRatio = 20;
            end
            NaNidx = find(isnan(inputdata)==1);
            inputdata(NaNidx) = [];
            seldata = inputdata;
			for ii = 1:trialTimes
				index = 1:length(seldata);
				removeIdx = find(abs(seldata - mean(seldata)) > stdRatio*std(seldata));
				if isempty(removeIdx)
					break;
				end
				seldata(removeIdx) = [];
				index(removeIdx) = [];
			end
        end
        
        function [history,stdval] = iterativeStd(history,newdata)
            %http://mathcentral.uregina.ca/QQ/database/QQ.09.02/carlos1.html
            if isempty(history)
                history.mean = newdata;
                history.cnt = 1;
                history.SumOfSq = 0;
                stdval = 0;
            else
                mean_prev = history.mean;
                history.mean = mean_prev + (newdata-history.mean)/(history.cnt+1);
                history.cnt = history.cnt + 1;
                history.SumOfSq = history.SumOfSq + (newdata - mean_prev) * (newdata - history.mean);
                stdval = sqrt(history.SumOfSq/(history.cnt-1));
            end
        end
        
        function [history,stdval] = iterativeForgettingStd(history,newdata)
            Cnt = 50;
            if isempty(history)
                history.data = zeros(1,Cnt);
                history.data(1) = newdata;
                history.WrIndex = 2;
                stdval = 0;
            else
                history.data(history.WrIndex) = newdata;
                history.WrIndex = history.WrIndex + 1;
                if history.WrIndex > Cnt
                    history.WrIndex = 1;
                end
                stdval = std(history.data);
            end
        end
        
        function [history,ExpectedVal] = iterativeMA(history,newdata)
            if isempty(history)
                history.ExpectedVal = newdata;
            else
                ratio = 0.02;
                assert(ratio <= 1 && ratio >= 0);
                history.ExpectedVal = history.ExpectedVal*(1-ratio) + newdata*ratio;
            end
            ExpectedVal = history.ExpectedVal;
        end
        
        function [history,meanval,stdval] = iterativeMAstd(history,newdata)
            if isempty(history)
                [history_MA,meanval] = CMathHelper.iterativeMA(history,newdata);
                [history_std,stdval] = CMathHelper.iterativeForgettingStd(history,newdata);
            else
                history_MA = [];
                history_MA.ExpectedVal = history.ExpectedVal;
                [history_MA,meanval] = CMathHelper.iterativeMA(history_MA,newdata);
                
                history_std = [];
                history_std.data = history.data;
                history_std.WrIndex = history.WrIndex;
                [history_std,stdval] = CMathHelper.iterativeForgettingStd(history_std,newdata-meanval);
            end
            history = [];
            history.ExpectedVal = history_MA.ExpectedVal;
            history.data = history_std.data;
            history.WrIndex = history_std.WrIndex;
        end
        
        function [groupedIndex,groupedData] = group1Dvector(data,GapThr)
            if false
                % 2.116916 sec
                [sortdata,sortii] = sort(data);
                incrementVal = [0 diff(sortdata')];
                IndexGapViolation = find(incrementVal > GapThr);
                if isempty(IndexGapViolation)
                    groupedIndex = 1:length(data);
                    groupedData = mean(data);
                else
                    groupedIndex = zeros(1,length(data));
                    groupedData = zeros(1,length(IndexGapViolation)+1);
                    for groupii = 1:length(IndexGapViolation)+1
                        if groupii == 1
                            beginIndex = 1;
                            endindex = IndexGapViolation(1)-1;
                        elseif groupii == length(IndexGapViolation)+1
                            beginIndex = IndexGapViolation(end);
                            endindex = length(data);
                        else
                            beginIndex = IndexGapViolation(groupii-1);
                            endindex = IndexGapViolation(groupii)-1;
                        end
                        groupedData(groupii) = mean(sortdata(beginIndex:endindex));
                        groupedIndex(sortii(beginIndex:endindex)) = groupii;
                    end
                end
                Sorteddata_groupedIndex = ones(1,length(sortdata));
                groupedDataEdge = sortdata(1);
                currentUniqueCnt = 1;
                for dataii = 2:length(sortdata)
                    if sortdata(dataii)-groupedDataEdge(end) > GapThr
                        currentUniqueCnt = currentUniqueCnt + 1;
                    end
                    groupedDataEdge(currentUniqueCnt) = sortdata(dataii);
                    Sorteddata_groupedIndex(dataii) = currentUniqueCnt;
                end
                groupedData = zeros(1,currentUniqueCnt);
                for gii = 1:currentUniqueCnt
                    groupedData(gii) = mean(sortdata(Sorteddata_groupedIndex==gii));
                end
                groupedIndex(sortii) = Sorteddata_groupedIndex;
            else
            % 1.647258 sec
            [sortdata,sortii] = sort(data);
            Sorteddata_groupedIndex = ones(1,length(sortdata));
            groupedDataEdge = sortdata(1);
            currentUniqueCnt = 1;
            for dataii = 2:length(sortdata)
                if sortdata(dataii)-groupedDataEdge(end) > GapThr
                    currentUniqueCnt = currentUniqueCnt + 1;
                end
                groupedDataEdge(currentUniqueCnt) = sortdata(dataii);
                Sorteddata_groupedIndex(dataii) = currentUniqueCnt;
            end
            groupedData = zeros(1,currentUniqueCnt);
            for gii = 1:currentUniqueCnt
                groupedData(gii) = mean(sortdata(Sorteddata_groupedIndex==gii));
            end
            groupedIndex(sortii) = Sorteddata_groupedIndex;
            end
        end
        
        function [fMergedX, fMergedY] = weightedMergeValues(dataindex,datavalue,groupedIndex)
            assert(length(dataindex)==length(datavalue));
            assert(length(dataindex)==length(groupedIndex));
            dataindex = dataindex(:);
            datavalue = datavalue(:);
            
            fMergedX = zeros(1,max(groupedIndex));
            fMergedY = zeros(1,max(groupedIndex));
            
            for ii =1:max(groupedIndex)
                allIndexInthisGroup = groupedIndex==ii;
                totalenergy = sum(datavalue(allIndexInthisGroup));
                fMergedY(ii) = totalenergy;
                fMergedX(ii) = dataindex(allIndexInthisGroup)'*datavalue(allIndexInthisGroup)/totalenergy;
            end
        end
        
        function [fMergedX, fMergedY] = weightedMergeValue(dataindex,datavalue)
            assert(length(dataindex)==length(datavalue));
            dataindex = dataindex(:);
            datavalue = datavalue(:);
            
            fMergedY = sum(datavalue);
            fMergedX = dataindex'*datavalue/fMergedY;
        end
        
        function heatmap = group2Dcluster(heatmap,radius)
            assert(false); % never used
            eheatmap = zeros(size(heatmap,1)+2*radius,size(heatmap,2)+2*radius);
            eheatmap(1:size(heatmap,1),1:size(heatmap,2)) = heatmap;
            thres = 0.5*max(max(eheatmap));
            for trial = 1:2
                bias = (trial-1)*radius;
                for rowii = radius+1+bias:2*radius:size(eheatmap,1)
                    for colii = radius+1+bias:2*radius:size(eheatmap,2)
                        if rowii+radius>size(eheatmap,1) || colii+radius>size(eheatmap,2)
                            break;
                        else
                            extractsquare = eheatmap(rowii-radius:rowii+radius,colii-radius:colii+radius);
                            peaksum = sum(sum(extractsquare));
                            if peaksum > 0
                                sumval = 0;
                                sumWeightedRow0 = 0;
                                sumWeightedCol0 = 0;
                                for squarerowii = 1:2*radius+1
                                    for squarecolii = 1:2*radius+1
                                        sumval = sumval + extractsquare(squarerowii,squarecolii);
                                        sumWeightedRow0 = sumWeightedRow0 + (squarerowii-1)*extractsquare(squarerowii,squarecolii);
                                        sumWeightedCol0 = sumWeightedCol0 + (squarecolii-1)*extractsquare(squarerowii,squarecolii);
                                    end
                                end
                                eheatmap(rowii-radius:rowii+radius,colii-radius:colii+radius) = zeros(2*radius+1,2*radius+1);
                                if sumval > thres
                                    eheatmap(rowii-radius+round(sumWeightedRow0/sumval),colii-radius+round(sumWeightedCol0/sumval)) = sumval;
                                end
                            end
                        end
                    end
                end
            end
            heatmap = eheatmap(1:size(heatmap,1),1:size(heatmap,2));
        end
        
        function heatmap = cyclicGroup2DsparseMatrix(heatmap,radius,dimenAxis)
            if dimenAxis == 2
                assert(size(heatmap,2)>4*radius);
                tmpEdgemap = [heatmap(:,end-(2*radius-1):end) heatmap(:,1:2*radius)];
                tmpEdgemap = CMathHelper.group2DsparseMatrix(tmpEdgemap,radius);
                heatmap(:,1:2*radius) = tmpEdgemap(:,2*radius+1:end);
                heatmap(:,end-(2*radius-1):end) = tmpEdgemap(:,1:2*radius);
            elseif dimenAxis == 1
                assert(false,'not yet implemented');
            else
                assert(false,'crap');
            end
        end
        
        function heatmap = group2DsparseMatrix(heatmap,radius)
            for rowii = 1:size(heatmap,1)
                nonzeroindex = find(heatmap(rowii,:)~=0);
                if ~isempty(nonzeroindex)
                    for colii = nonzeroindex
                        if rowii-radius < 1
                            rowstart = 1;
                            rowend = 2*radius+1;
                        elseif rowii+radius > size(heatmap,1)
                            rowstart = size(heatmap,1) - 2*radius;
                            rowend = size(heatmap,1);
                        else
                            rowstart = rowii - radius;
                            rowend = rowii + radius;
                        end
                        
                        if colii-radius < 1
                            colstart = 1;
                            colend = 2*radius+1;
                        elseif colii+radius > size(heatmap,2)
                            colstart = size(heatmap,2) - 2*radius;
                            colend = size(heatmap,2);
                        else
                            colstart = colii - radius;
                            colend = colii + radius;
                        end
                        currBlk = heatmap(rowstart:rowend,colstart:colend);
                        if ~isempty(find(currBlk(:)~=0, 1))
                            heatmap(rowstart:rowend,colstart:colend) = CMathHelper.Matrix2SinglePoint(currBlk);
                        end
                    end
                end
            end
        end
        
        function heatmap = AcceptPointsInBoth2Dmatrix(heatmap1,heatmap2,radius)
            % in the output matrix, we only accept entries with non-zero value available in both input matrix 
            heatmap = zeros(size(heatmap1));
            assert(size(heatmap1,1)==size(heatmap2,1));
            assert(size(heatmap1,2)==size(heatmap2,2));
            for rowii = 1:size(heatmap1,1)
                nonzeroindexInRow = find(heatmap1(rowii,:)~=0);
                if ~isempty(nonzeroindexInRow)
                    for colii = nonzeroindexInRow
                        if rowii-radius < 1
                            rowstart = 1;
                            rowend = radius + 1;
                        elseif rowii+radius > size(heatmap,1)
                            rowstart = size(heatmap,1) - radius;
                            rowend = size(heatmap,1);
                        else
                            rowstart = rowii - radius;
                            rowend = rowii + radius;
                        end
                        
                        if colii-radius < 1
                            colstart = 1;
                            colend = radius+1;
                        elseif colii+radius > size(heatmap,2)
                            colstart = size(heatmap,2) - radius;
                            colend = size(heatmap,2);
                        else
                            colstart = colii - radius;
                            colend = colii + radius;
                        end
                        currBlkIn2 = heatmap2(rowstart:rowend,colstart:colend);
                        if ~isempty(find(currBlkIn2(:)>0, 1))
                            heatmap(rowii,colii) = 1;
                        end
                    end
                end
            end
        end        
        
        function SinglePointMat = Matrix2SinglePoint(MatrixIn)
            if isempty(find(MatrixIn(:)~=0, 1))
                SinglePointMat = MatrixIn;
            else
                totalVal = sum(abs(MatrixIn(:)));
                SinglePointMat = zeros(size(MatrixIn));
                if abs(totalVal) > 1e-9
                    locDim1 = round(sum(abs(MatrixIn)'*(0:(size(MatrixIn,1)-1))')/totalVal)+1;
                    locDim2 = round(sum(abs(MatrixIn)*(0:(size(MatrixIn,2)-1))')/totalVal)+1;
                    SinglePointMat(locDim1,locDim2) = sum(MatrixIn(:));
                end
            end
        end
    end
end
