function [estPhsRad,QoSworst,QoS,truthPhsRad] = algo_adaptiveAlldataCorr(realSamples,fc_est,strComment)
% QoSworst,QoS: no unit, Err_reconstruction/RMS_signal
if nargin == 0
    % this is a simulation
    fHz = 0.01;
    truthPhsRad = 2*pi*rand; 
    realSamples = sin(2*pi*fHz*(0:10/fHz-1) + truthPhsRad);
    strComment = 'simu, sampling duration must be full cycles, otherwise fail';
    fc_est = NaN;
else
    truthPhsRad = NaN;
end
assert(isreal(realSamples));
realSamples = realSamples(:)';
% figure;
% hist(realSamples);
% title(sprintf('\\mu=%2.1f',mean(realSamples)));
[estPhsRad,QoSworst,QoS] = findPhaseRegression(realSamples,fc_est,strComment);
if ~isnan(truthPhsRad)
    fprintf(1,'%3.2frad truth phs is estimated to be %3.2frad\n', modmPitoPi(truthPhsRad),estPhsRad);
end
end

function [estPhsRad,QoSworst,QoS] = findPhaseRegression(DatInput,fc_est,strComment)
% QoSworst,QoS: no unit, Err_reconstruction/RMS_signal
global X;
TapNum = 2;
dataSeqLen = length(DatInput);
if isnan(fc_est)
    % Find frequency
    D = abs(fftshift(fft(DatInput .* hamming(dataSeqLen)')));
    f = -0.5:1.0/dataSeqLen:0.5-1.0/dataSeqLen;
    [~,pos] = max(D);
    fc_est = f(pos); % not in Hz, but in -0.5sampleClk=>0.5sampleClk
end
% Create datLocalSynth (synthetic sin wave)
datLocalSynth = sin(2*pi*(-(TapNum-1):dataSeqLen-1)*abs(fc_est));
%figure;plot([datLocalSynth(1:dataSeqLen)',DatInput'],'.');
% Compute w
w = LS_local(DatInput,datLocalSynth,TapNum);
y = datLocalSynth(1:dataSeqLen)*w(2) + datLocalSynth(2:dataSeqLen+1)*w(1);
err = DatInput - y;
if CMathHelper.shallwePlot(X.plotLevel.VERBOSE)
    figure;
    subplot(211); plot([DatInput' y'],'.-'); title(strComment); legend('IF meas','reproduced');
    subplot(212); plot(err,'.-'); title('error');
end
QoSworst    = (prctile(err,X.QoSworstprctile))/std(w);
QoS         = (prctile(err,X.QoSprctile))/std(w);
% Initialize
ph0 = 0;
ph1 = -2*pi*abs(fc_est);

% Compute ph
ph = atan( (w(1)*sin(ph0) + w(2)*sin(ph1)) / (w(1)*cos(ph0) + w(2)*cos(ph1)) );
if sign((w(1)*cos(ph0) + w(2)*cos(ph1))) < 0
    ph = ph - pi;
end

estPhsRad = modmPitoPi(ph);
end

% function val = modmPitoPi(val)
% while val <= -pi
%     val = val + 2*pi;
% end
% while val > pi
%     val = val - 2*pi;
% end
% end

function w = LS_local(DatInput,datLocalSynth,Lw)

% Initialize
LenInputDat = length(DatInput);
LenLocalSynthDat = length(datLocalSynth);

% Check
assert(LenLocalSynthDat == (LenInputDat + Lw - 1),'Length of datLocalSynth or length of DatInput is incorrect.');


% Build R
xx = zeros(Lw,LenInputDat);
for i=0:Lw-1 % i in range(Lw):
    xx(i+1,:) = datLocalSynth(Lw-i:Lw-i-1+LenInputDat);%datLocalSynth[Lw-i-1:Lw-i-1+LenInputDat]
end
R = xx*xx';

% Build p
p = DatInput*xx';

% Compute w
w = inv(R)*p';
end


