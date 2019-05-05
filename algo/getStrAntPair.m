function str = getStrAntPair(choice0indexed)
global X;
str = sprintf('%d-%d',X.antPair(choice0indexed+1,1)-1,X.antPair(choice0indexed+1,2)-1);