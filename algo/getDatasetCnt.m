function [etDataset,sanityDatasetCnt,etListSanityDataset] = getDatasetCnt(datasetCategory)
if nargin < 1
    datasetCategory = 'RcvPavilion_CarDriveway_TxTree';
end
etDataset = 0;
sanityDatasetCnt = 0;
etListSanityDataset = [];
while true
    [strlogFolder,~,etResultStatus,~] =  globalSettings_datasetSpecific(datasetCategory,etDataset);
    if isempty(strlogFolder)
        break;
    else
        switch etResultStatus
            case 'SanityMember'
                sanityDatasetCnt = sanityDatasetCnt + 1;
                etListSanityDataset = [etListSanityDataset etDataset];
            case {'nonSanityMember','invalidEntry','CommonTmpFolder'}
                % do nothing
        end
        etDataset = etDataset + 1;
    end
end
end