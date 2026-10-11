function results = run_hpr_research(dataFolder, outputFolder)
if nargin < 1 || strlength(string(dataFolder)) == 0
    dataFolder = uigetdir(pwd, 'Select the folder containing downloaded data');
    if isequal(dataFolder, 0), error('HPR:Cancelled','No folder selected.'); end
end
if nargin < 2, outputFolder = fullfile(dataFolder,'HPR_results'); end
codeRoot = fileparts(mfilename('fullpath'));
addpath(codeRoot);
cfg = hpr_config(dataFolder, outputFolder);
if ~isfolder(cfg.dataFolder), error('HPR:Folder','Data folder does not exist.'); end
if ~isfolder(cfg.outputFolder), mkdir(cfg.outputFolder); end
if ~isfolder(cfg.cacheFolder), mkdir(cfg.cacheFolder); end
if ~isfolder(cfg.figureFolder), mkdir(cfg.figureFolder); end
diary(fullfile(cfg.outputFolder,'execution_log.txt'));
cleanup = onCleanup(@() diary('off'));
fprintf('HPR empirical research pipeline %s\n', cfg.version);
fprintf('Data: %s\nOutput: %s\n',cfg.dataFolder,cfg.outputFolder);
fprintf('Market time: AEST UTC+10, without daylight saving adjustment.\n');
self_test_hpr(false);
inventory = hpr.inventory(cfg);
writetable(inventory, fullfile(cfg.outputFolder,'file_inventory.csv'));
types = ["DUDETAILSUMMARY","BIDDUIDDETAILS","DISPATCHLOAD", ...
    "DISPATCHPRICE","BIDPEROFFER_D","BIDDAYOFFER_D","GENCONDATA", ...
    "DISPATCH_FCAS_REQ"];
data = struct;
for k = 1:numel(types)
    name = char(types(k));
    data.(name) = hpr.load_data(inventory, types(k), cfg, strings(0,1));
end
required = ["DISPATCHLOAD","DISPATCHPRICE"];
for k = 1:numel(required)
    if isempty(data.(required(k)))
        hpr.missing_files(data, inventory, cfg);
        error('HPR:MissingCore','Missing %s. See missing_files.csv.',required(k));
    end
end
ids = strings(0,1);
if ~isempty(data.DISPATCH_FCAS_REQ)
    ids = unique(data.DISPATCH_FCAS_REQ.GENCONID);
end
if ~isempty(data.GENCONDATA)
    g = data.GENCONDATA;
    hit = contains(upper(g.GENCONID),'HPR');
    if ismember('DESCRIPTION',g.Properties.VariableNames)
        hit = hit | contains(upper(g.DESCRIPTION),'HORNSDALE');
    end
    ids = unique([ids;g.GENCONID(hit)]);
end
data.DISPATCHCONSTRAINT = hpr.load_data(inventory,"DISPATCHCONSTRAINT",cfg,ids);
results = hpr.analyse_dispatch(data, cfg);
results.offers = hpr.analyse_offers(data,results,cfg);
results.constraints = hpr.analyse_constraints(data,cfg);
results.supplement = hpr.supplement(data,cfg);
hpr.missing_files(data,inventory,cfg,results.constraints);
hpr.make_figures(results,cfg);
hpr.write_summary(results,cfg);
save(fullfile(cfg.outputFolder,'research_results.mat'),'results','cfg','-v7.3');
if results.offers.available, make_report_figures(cfg.outputFolder); end
fprintf('\nCompleted. Results: %s\n',cfg.outputFolder);
fprintf('Execution finished: %s\n',char(datetime('now')));
end
