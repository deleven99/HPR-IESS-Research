function cfg = hpr_config(dataFolder, outputFolder)
cfg.version = '1.1.0';
cfg.dataFolder = char(java.io.File(char(dataFolder)).getCanonicalPath());
cfg.outputFolder = char(java.io.File(char(outputFolder)).getCanonicalPath());
cfg.cacheFolder = fullfile(outputFolder,'cache');
cfg.figureFolder = fullfile(outputFolder,'figures');
cfg.duids = ["HPRG1","HPRL1","HPR1"];
cfg.region = "SA1";
cfg.services = ["RAISE1SEC","RAISE6SEC","RAISE60SEC","RAISE5MIN", ...
    "LOWER1SEC","LOWER6SEC","LOWER60SEC","LOWER5MIN","RAISEREG","LOWERREG"];
cfg.transitionDay = datetime(2024,9,24);
cfg.windows = [21,14];
cfg.thresholdsMW = [0.1,1,5];
cfg.enabledTolerance = 1e-6;
cfg.chunkRows = 100000;
cfg.bootstrapReplicates = 1000;
cfg.randomSeed = 4412;
cfg.figureVisible = 'off';
cfg.rebuildCache = false;
cfg.checkReference = true;
cfg.minimumStratumCount = 10;
end
