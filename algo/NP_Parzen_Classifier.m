function [pPosterior] = NP_Parzen_Classifier(xMean,xStd,ndx,meas)

% Try: for i=1:19, p=NP_Parzen_Classifier(1:6,xMean(:,i)+randn(6,1)*0.01); title(int2str(i)); pause(0.2), end
% Try: for i=1:50, p=NP_Parzen_Classifier(1:6,randn(6,1)*0.5); title(int2str(i)); pause(0.1), end

% User-defined parameters
N = 100;
sig = 0.8;
pPrior = ones(19,1)/19;

% Initialize
%randn('seed',13);
% xMean = zeros(6,19);
% xStd = zeros(6,19);
x = cell(6,1);

% Mean of example data
% xMean(1,:) = [-2.1 -2.0  1.8 -2.0 -2.3  1.5  2.1  2.1  0.4  2.5  1.8 -2.3 -2.3 -2.3 -2.2 -2.2 -2.2 -2.1 -2.1];
% xMean(2,:) = [ 0.0  0.0  0.1  0.1 -0.6 -1.2 -1.8 -1.7 -1.5 -1.1 -0.5  0.0  0.2  0.3  0.5  0.9  1.3  1.6  2.0];
% xMean(3,:) = [ 2.3  2.3  2.2  2.2  2.1  2.1  2.0  2.1  0.5  2.6 -2.8 -2.7 -2.6 -2.5 -2.4 -2.4 -2.3 -2.2 -2.1];
% xMean(4,:) = [ 2.2  2.1  2.2  2.3  2.4  2.5  2.6  2.7 -2.9 -2.8 -2.7 -2.7 -2.7 -2.7 -2.6  2.0  1.8 -2.3 -2.1];
% xMean(5,:) = [-2.0 -2.0 -1.9 -1.7 -1.4 -1.0 -0.6 -0.2  0.1  0.3  0.2  0.3  0.4  1.0 -1.0 -0.8 -0.5 -0.3 -0.1];
% xMean(6,:) = [ 2.0  2.0  2.2  2.4  2.6  2.8  3.0 -3.0 -2.9 -2.8  3.0  3.0  3.1 -2.8  0.0  1.2  1.8  2.1  0.4];
% 
% % Standard deviation of example data
% g = 0.03;
% xStd(1,:) = [2 2 3 4 3 3 2 2 2 3 2 1 1 1 1 1 1 1 1] * g;
% xStd(2,:) = [2 2 3 5 4 3 2 2 3 4 3 2 1 1 1 1 1 1 1] * g;
% xStd(3,:) = [1 1 1 1 1 1 1 1 2 2 3 1 1 1 1 1 1 1 1] * g;
% xStd(4,:) = [1 1 1 1 1 1 1 1 1 3 2 2 2 2 2 3 3 1 1] * g;
% xStd(5,:) = [1 1 1 1 1 1 1 1 1 2 2 2 2 2 3 3 3 2 2] * g;
% xStd(6,:) = [1 1 1 1 1 1 1 1 1 2 2 1 1 1 2 3 3 3 2] * g;

% Create example data
for i1 = 1:size(xMean,2)
    x{i1} = zeros(size(xMean,1),N);
    for i2 = 1:size(xMean,1)
        x{i1}(i2,:) = randn(1,N) * xStd(i2,i1) + xMean(i2,i1);
    end
end

% Initialize
theta = 0:10:(size(xMean,2)-1)*10;
C1 = 1/N * 1/((2*pi*sig^2)^(length(ndx)/2));
C2 = -1/(2*sig^2);
pConditional = zeros(size(xMean,2),1);
pPosterior = zeros(size(xMean,2),1);

% Conditional probability
for i1 = 1:size(xMean,2)
    for i3 = 1:N
        var1 = x{i1};
        var2 = var1(:,i3);
        var3 = var2(ndx);
        %pConditional(i1) = pConditional(i1) + C1 * exp(C2 * sum((meas(ndx) - var3).^2));
        pConditional(i1) = pConditional(i1) + C1 * exp(C2 * sum((inp(ndx) - x{i1}(:,i3)(ndx)).^2));
    end
end

% Posterior probability
if sum(pConditional .* pPrior) ~= 0
    pPosterior = pConditional .* pPrior ./ sum(pConditional .* pPrior);
%     plot(theta,pPosterior,'.-')
%     axis([theta(1) theta(end) 0 1])
else
    pPosterior = NaN;
end

% Check
if 0
    k1 = 1;
    i1 = 1;
    i2 = 3;
    d = 2;
    I4 = 1:0.1:3;
    p = zeros(length(I4));
    for i4 = I4
        k2 = 1;
        for i5 = I4
            for i3 = 1:N
                p(k1,k2) = p(k1,k2) + 1/N * (2*pi*sig^2)^(-d/2) * exp(-1/(2*sig^2)*sum(([i4;i5] - [x{i1}(i3,i2);x{i1+2}(i3,i2)]).^2));
            end
            k2 = k2 + 1;
        end
        k1 = k1 + 1;
    end
    mesh(p), sum(sum(p))*0.1^2
end

end
