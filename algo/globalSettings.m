% do not call it directly, better let globalSettings_datasetSpecific.m call globalSettings() 
function globalSettings()
global X;
if ~isfield(X,'algor')
    X.realtimeLogFolder = '../Host_workspaces/datalog/';
    X.analysisResultFolder = '../Host_workspaces/datalog_analysisResult/';
    X.matlab2pcPythonCmdFile = 'rotate_and_EmbdAoAmeas.txt';
    X.pcPython2matlabStatusRptFile = 'AoArawDataCollectionStatus.txt';
    X.cycleAnt = [10 10 12];

    X.LogProcessResult.OK = 'OK';
    X.LogProcessResult.Corruption = 'Corruption'; % data file cannot be processed 
    X.LogProcessResult.badMeas = 'badMeas'; % data file process result unacceptable 
    
    X.algor = 'UnwrapPhs'; % UnwrapPhs IQindepen
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % log and plot settings
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    X.LogTimestampBytes = 4;
    X.plotLevel.ERROR = 0;
    X.plotLevel.WARN = X.plotLevel.ERROR + 1;
    X.plotLevel.INFO = X.plotLevel.WARN + 1;
    X.plotLevel.DEBUG = X.plotLevel.INFO + 1;
    X.plotLevel.VERBOSE = X.plotLevel.DEBUG + 1;
    X.plotLevel.Thres = X.plotLevel.INFO; % only group <= Thres will be plotted
    X.plotLevel.save = true;
    X.QoSworstprctile = 97.5;
    X.QoSprctile = 90;
    X.removeHead = 16;
    X.removeTail = 16;
    X.percentileThres = 50;

    X.KmeanMergeThresRad = 0.5;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % parameter used to convert one binary data file collected by blecpp to a few parameters 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    X.studyNphsCandidate = 1; % due to (maybe) multipath, there may exist more than one cluster of delta phase between same antenna pair 
    X.kmeanIniClusterCnt = 6; % start with these many clusters, then merge
    X.MinRatioCluster = 0.1;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % parameter used in final AoA output filer 
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    X.windowLength = 10;
    X.adoptedResults = 1;
    X.rejectedResults = 2;
    
    X.RawDatProtocol.SYNCBYTECNT = 4;
    X.RawDatProtocol.SIGSTRENGTH_BYTECNT = 1;
    X.RawDatProtocol.AOA_IQ_SAMPLE_BYTELEN = 512*4; % 512 sample of I/Q 16bit meas
    X.RawDatProtocol.SYNC0 = 0;
    X.RawDatProtocol.ByteAntArray = X.RawDatProtocol.SYNC0+X.RawDatProtocol.SYNCBYTECNT;
    X.RawDatProtocol.BytePktId = X.RawDatProtocol.ByteAntArray + 1;
    X.RawDatProtocol.ByteRfChan = X.RawDatProtocol.BytePktId + 1;
    X.RawDatProtocol.SNR_BYTE0 = X.RawDatProtocol.ByteRfChan + 1;
    X.RawDatProtocol.AOA_SAMPLES_BYTE0 = X.RawDatProtocol.SNR_BYTE0+X.RawDatProtocol.SIGSTRENGTH_BYTECNT;
    X.RawDatProtocol.SPI_PKG_CRC8 = X.RawDatProtocol.AOA_SAMPLES_BYTE0+X.RawDatProtocol.AOA_IQ_SAMPLE_BYTELEN;
    X.RawDatProtocol.bufSPIpacketLEN = X.RawDatProtocol.SPI_PKG_CRC8 + 1;
    
    if ~exist(X.analysisResultFolder,'dir')
        mkdir(X.analysisResultFolder);
    end
    assert(exist('../../../RadioLoc/matlab','dir')>0);
    addpath('../../../RadioLoc/matlab');
end
end
