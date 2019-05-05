function [strlogFolder,strProcessedResultFolder,etResultStatus,datasetSpecific] = globalSettings_datasetSpecific(datasetCategory,etDataset)
global X;
X.datasetCategory = datasetCategory;
globalSettings();
assert(ismember(X.datasetCategory,{'RcvDoorStep_emptyDriveway_TxFense','RcvPavilion_CarDriveway_TxTree','Lab'}));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% folder path of dataset file storage
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       X.datasetSpecific.logFolder
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parameter need to match python parameters
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       X.datasetSpecific.repeatedTrainDataCollect: multiple data collection at each angular Pos for phs mean&std estimate 
%       X.datasetSpecific.StepDeg
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parameter need to match AoArcvSPI command line arguments
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%       X.datasetSpecific.AoArcvSPIlogPktCnt
X.etResultStatusList = {'SanityMember','nonSanityMember','invalidEntry','CommonTmpFolder'};
etResultStatus = 'SanityMember';
switch X.datasetCategory
    case 'Lab'
        switch etDataset
            case 0
                etResultStatus = 'CommonTmpFolder';
                X.datasetSpecific.repeatedTrainDataCollect = 56;
                X.datasetSpecific.repeatedEvalDataCollect = 0;
            case {1,2,3,4,5,6}
                X.datasetSpecific.repeatedTrainDataCollect = 20;
                X.datasetSpecific.repeatedEvalDataCollect = 0;
            case 7
                X.datasetSpecific.repeatedTrainDataCollect = 20;
                X.datasetSpecific.repeatedEvalDataCollect = 10;
            case 8
                X.datasetSpecific.repeatedTrainDataCollect = 20;
                X.datasetSpecific.repeatedEvalDataCollect = 5;
            case 9
                X.datasetSpecific.repeatedTrainDataCollect = 20;
                X.datasetSpecific.repeatedEvalDataCollect = 4;
            case 10
                X.datasetSpecific.repeatedTrainDataCollect = 20; % battery powered
                X.datasetSpecific.repeatedEvalDataCollect = 10;
            otherwise
                strlogFolder = NaN;
                etResultStatus = 'invalidEntry';
        end
        if ~exist('strlogFolder','var')
            strlogFolder = sprintf('%d',etDataset);
        end
    case 'RcvPavilion_CarDriveway_TxTree'
        switch etDataset
            case 0
                etResultStatus = 'CommonTmpFolder';
            case 1
                strlogFolder = '10_20cycles_moveRPiFartherCarInDriveway';
            case 2
                strlogFolder = '11_20cycles_moveRPiFartherCarInDriveway';
            case 3
                strlogFolder = '12';
            case 4
                strlogFolder = '13';
            otherwise
                strlogFolder = NaN;
                etResultStatus = 'invalidEntry';
        end
    case 'RcvDoorStep_emptyDriveway_TxFense'
        switch etDataset
            case 0
                etResultStatus = 'CommonTmpFolder';
            case 1
                strlogFolder = '7_20cycles';
            case 2
                strlogFolder = '8_20cycles';
            case 3
                strlogFolder = '9_20cycles';
            case 4
                strlogFolder = '1_almostPerfectExceptOneMeas';
            case 5
                strlogFolder = '2';
            case 6
                strlogFolder = '5_20cycles';
            case 7
                strlogFolder = '6_20cycles';
            otherwise
                etResultStatus = 'invalidEntry';
        end
    otherwise
        assert(false);
end
assert(ismember(etResultStatus,X.etResultStatusList));
dataLogRootPath = '../Host_workspaces/datalog/';
switch etResultStatus
    case {'SanityMember','nonSanityMember'}
        strlogFolder = sprintf('%s%s/%s/',dataLogRootPath,X.datasetCategory,strlogFolder);
    case 'invalidEntry'
        strlogFolder = '';
    case 'CommonTmpFolder'
        strlogFolder = dataLogRootPath;
    otherwise
        assert(false);
end
switch etResultStatus
    case {'CommonTmpFolder','nonSanityMember','SanityMember'}
        strProcessedResultFolder = sprintf('%s%s/',X.analysisResultFolder,X.datasetCategory);
    case 'invalidEntry'
        strProcessedResultFolder = '';
%     case {'CommonTmpFolder','nonSanityMember'}
%         strProcessedResultFolder = strlogFolder;
    otherwise
        assert(false);
end
if ~exist(strProcessedResultFolder,'dir')
    mkdir(strProcessedResultFolder);
end
if ~isfield(X.datasetSpecific,'repeatedTrainDataCollect')
    X.datasetSpecific.repeatedTrainDataCollect = 20;
end
if ~isfield(X.datasetSpecific,'repeatedEvalDataCollect')
    X.datasetSpecific.repeatedEvalDataCollect = 0;
end
X.datasetSpecific.StepDeg = 10;
X.datasetSpecific.AoArcvSPIlogPktCnt = 100;
datasetSpecific = X.datasetSpecific;

% motor motion parameter 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
X.LAMBDA_CNT_1Rotation = 14;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% antenna array configuration parameter 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
X.antPair = [2,1;3,1;3,2];
X.antArrayCnt = 2;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% parameter derived
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
X.datasetSpecific.logFolder = strlogFolder;
X.datasetSpecific.PosEachCycle = 180/X.datasetSpecific.StepDeg+1;
X.datasetSpecific.LogFileCntTrain = X.datasetSpecific.PosEachCycle*X.datasetSpecific.repeatedTrainDataCollect;
X.datasetSpecific.LogFileCntEval = X.datasetSpecific.PosEachCycle*X.datasetSpecific.repeatedEvalDataCollect;
X.totalMeasCnt = ...
    X.datasetSpecific.repeatedTrainDataCollect*...
    X.datasetSpecific.PosEachCycle*...
    X.datasetSpecific.AoArcvSPIlogPktCnt/X.antArrayCnt;
X.datasetSpecific.stepDeg = 180/(X.datasetSpecific.PosEachCycle-1);
X.antSingleDiffCnt = size(X.antPair,1);
X.measPerLogFile = X.datasetSpecific.AoArcvSPIlogPktCnt/X.antArrayCnt;
X.LUTcnt = X.antArrayCnt*X.antSingleDiffCnt; % 2 array, each has 3 single difference options

end

