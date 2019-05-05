function savePlot(h_fig,figfilename)
    [a,b,ext]=fileparts(figfilename);
    if isempty(a)
        constructedfilename = ['./' figfilename];
    else
        constructedfilename = [a '\' b];
    end
    saveas(h_fig, constructedfilename, 'jpg')
    if isempty(ext)
        saveas(h_fig, constructedfilename, 'fig')
    end
end