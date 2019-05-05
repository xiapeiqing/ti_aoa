function algo_FFTphs()
close all;
FsNominal = 8e6;
FsErrPPM = 20;
TxFcNominal = 250e3;
iniPhsCycle = 0.3;
DelayCycles = 2.4;
SampleCnt = 10*(FsNominal/TxFcNominal);
%%
TxFc = TxFcNominal*(1+FsErrPPM/1e6);
t = (0:SampleCnt-1)/FsNominal;
y = exp(1j*(2*pi*(TxFc*t+iniPhsCycle)));
y = transpose(y);
tau = DelayCycles*(FsNominal/TxFcNominal);
delayedY = delayseq(y,tau);
SNRdB = -10;
%%
phsCycledelayed = extractPhs(delayedY,SNRdB)/(2*pi);
phsCycleref = extractPhs(y,SNRdB)/(2*pi);
fprintf(1,'%4.3f %4.3f %f %f\n',phsCycledelayed,phsCycleref,phsCycleref-phsCycledelayed, mod(DelayCycles,1) );

function phs = extractPhs(y,SNRdB)
if ~isnan(SNRdB)
    fftRef = fft(awgn(y,SNRdB));
else
    fftRef = fft(y);
end
[~,maxIndex] = max(abs(fftRef));
phs = angle(fftRef(maxIndex));
