function [estPhsRad,QoSworst,QoS,truthPhsRad] = algo_adaptiveAllComplexDataCorr(ComplexSamples,fc_est,strComment)
close all;
resultall = [];
SamplingFreqHz = 1000;
FcHz = 80;
for c = 0:23
    ExtraPhs = pi/12*c;
    resultall = [resultall;findPhaseRegression(exp(1j*(2*pi*FcHz*(0:999)/SamplingFreqHz + ExtraPhs)),ExtraPhs)];
end
figure;
plot(resultall(:,1)-resultall(:,2));
ylim([-1,1])
end
function result = findPhaseRegression(DatInput,phsTruth)
TapNum = 1;
% Find frequency
D = abs(fftshift(fft(DatInput .* hamming(length(DatInput))')));
f = -0.5:1.0/length(DatInput):0.5-1.0/length(DatInput);
[~,pos] = max(D);

% Create datLocalSynth (synthetic sin wave)
datLocalSynth = exp(1j*2*pi*(-(TapNum-1):length(D)-1)*abs(f(pos)));
%figure;plot([datLocalSynth(1:length(D))',DatInput'],'.');
% Compute w
w = LS_local(DatInput,datLocalSynth,TapNum);
% y = datLocalSynth(1:length(DatInput))*w(2) + datLocalSynth(2:length(DatInput)+1)*w(1);
% figure;
% subplot(211); plot([DatInput' y']);
% subplot(212); plot(DatInput'-y');ylim([-1,1]);
% % Initialize
% ph0 = 0;
% ph1 = -2*pi*abs(f(pos));
% 
% % Compute ph
% ph = atan( (w(1)*sin(ph0) + w(2)*sin(ph1)) / (w(1)*cos(ph0) + w(2)*cos(ph1)) );
% if sign((w(1)*cos(ph0) + w(2)*cos(ph1))) < 0
%     ph = ph - pi;
% end

result = [modmPitoPi(phsTruth),-angle(w)];
%fprintf(1, '%f,%f\n',phsTruth,ph);

end

function val = modmPitoPi(val)
while val <= -pi
    val = val + 2*pi;
end
while val > pi
    val = val - 2*pi;
end
end

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
R = cov(transpose(xx)); % cov() = 0.5*(u-mean(u))' * (u-mean(u))
% Build p
p = DatInput*xx';

% Compute w
w = inv(R)*p';

end


