function S=update_hpr_regulation_checks(resultsFolder)
if nargin<1
    resultsFolder=uigetdir(pwd,'Select the existing HPR_results folder');
    if isequal(resultsFolder,0), return; end
end
root=fileparts(mfilename('fullpath')); addpath(root);
source=fullfile(resultsFolder,'matched_offer_records.csv');
assert(isfile(source),'HPR:MissingExport','Cannot find %s',source);
E=readtable(source,'TextType','string');
if ~isdatetime(E.Time), E.Time=hpr.time(E.Time); end
out=fullfile(resultsFolder,'corrected_regulation');
if ~isfolder(out), mkdir(out); end
cfg=hpr_config(resultsFolder,out);
C=hpr.combine_regulation(E); S=hpr.regulation_statistics(C,cfg);
reg=E.DUID=="HPR1" & ismember(E.Service,["RAISEREG","LOWERREG"]);
E.DirectionApplicable(reg)=false;
for name=["UtilizationOfSimpleCeiling","DiagnosticAboveEnvelope","DiagnosticAboveSimpleCeiling"]
    E.(name)=double(E.(name)); E.(name)(reg)=NaN;
end
writetable(E,fullfile(out,'matched_offer_records_corrected.csv'));
writetable(C,fullfile(out,'combined_regulation_checks.csv'));
writetable(S,fullfile(out,'combined_regulation_statistics.csv'));
oldStats=fullfile(resultsFolder,'offer_statistics.csv');
if isfile(oldStats)
    O=readtable(oldStats,'TextType','string');
    m=O.DUID=="HPR1" & ismember(O.Service,["RAISEREG","LOWERREG"]);
    for name=["MeanEnabledToSimpleCeiling","EnvelopeDiagnosticCount","SimpleCeilingDiagnosticCount"]
        O.(name)=double(O.(name)); O.(name)(m)=NaN;
    end
    writetable(O,fullfile(out,'offer_statistics_corrected.csv'));
end
disp(S); fprintf('Corrected outputs saved to %s\n',out);
end
