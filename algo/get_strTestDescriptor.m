function str = get_strTestDescriptor(datasetCategory,etLUTfolder,etMeasFolder,Eval_Train_All)
if nargin < 3
    etMeasFolder = '';
end
if nargin < 4
    Eval_Train_All = '';
end

str = sprintf('ana_%s_LUT%d',datasetCategory,etLUTfolder);

if ~isempty(etMeasFolder)
    str = sprintf('%s_meas%d',str,etMeasFolder);
end
if ~isempty(Eval_Train_All)
    str = sprintf('%s%s',str,Eval_Train_All);
end
end