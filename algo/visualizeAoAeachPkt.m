function visualizeAoAeachPkt(AllPosDeg,AllPosTruthDeg,SaveFigFile,FigTitle,bStandaloneCall)
global X;
ErrDeg = AllPosDeg - AllPosTruthDeg;
meaningfulErrDeg = ErrDeg(~isnan(ErrDeg));
ErrBiasDeg = mean(meaningfulErrDeg);
ErrStdDeg = std(meaningfulErrDeg);
prctileMetric = prctile(abs(ErrDeg),X.percentileThres);


if ~exist([SaveFigFile '.jpg'],'file') || bStandaloneCall
    %%
    h_fig = figure;
    subplot(311);
    hold on;
    xaxis = (0:X.datasetSpecific.PosEachCycle*X.measPerLogFile*X.datasetSpecific.repeatedTrainDataCollect-1)*X.datasetSpecific.repeatedTrainDataCollect/X.datasetSpecific.PosEachCycle*X.measPerLogFile*X.datasetSpecific.repeatedTrainDataCollect;
    if length(xaxis) == length(AllPosDeg)
        plot(xaxis,AllPosDeg,'*-');
    else
        plot(AllPosDeg,'*-');
    end
    grid on;
    ylabel('deg');
    if length(xaxis) == length(AllPosDeg)
        plot(xaxis,AllPosTruthDeg,'o-');
    else
        plot(AllPosTruthDeg,'o-');
    end
    grid on;
    xlabel('cycles');
    ylabel('deg');
    title(sprintf('%s RSSI',FigTitle));
    legend('estimated','truth');
    subplot(312);
    plot(ErrDeg,'.-');
    subplot(313);
    hist(ErrDeg,20);
    grid on;
    ylabel('deg');
    title(sprintf('estimation Err distribution,\\sigma=%2.1f,%dprctile=%2.1f,yield=%2.1f',ErrStdDeg,round(X.percentileThres),prctileMetric,length(meaningfulErrDeg)/length(ErrDeg)));
    if ~exist([SaveFigFile '.jpg'],'file')
        savePlot(h_fig,SaveFigFile);
    end
end
end