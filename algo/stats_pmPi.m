function [mu,sigma,adoptedDataCnt] = stats_pmPi(vec)
global X;
if std(vec) < 0.5*X.KmeanMergeThresRad
    mu = mean(vec);
    sigma = std(vec);
    adoptedDataCnt = length(vec);
else
    [IDX, C] = kmeans(vec,2);
    if abs(C(1)-C(2)) < 0.3
        mu = mean(vec);
        sigma = std(vec);
        adoptedDataCnt = length(vec);
    elseif abs(C(1)-C(2)) > 0.8*2*pi
        shfted_vec = modmPitoPi(vec-pi);
        mu = modmPitoPi(mean(shfted_vec)+pi);
        sigma = std(shfted_vec);
        adoptedDataCnt = length(vec);
    else
        mu_alldat = mean(vec);
        sigma_alldat = std(vec);
        validData = vec(abs(vec-mu_alldat) < 2*sigma_alldat,1);
        adoptedDataCnt = length(validData);
        mu = mean(validData);
        sigma = std(validData);
    end
end
end
