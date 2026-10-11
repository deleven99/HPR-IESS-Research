function T = inventory(cfg)
a = dir(fullfile(cfg.dataFolder,'**','*'));
paths = strings(0,1); bytes = []; modified = []; kind = strings(0,1);
out = string(cfg.outputFolder);
for k=1:numel(a)
    if a(k).isdir || startsWith(a(k).name,'.'), continue; end
    p = string(fullfile(a(k).folder,a(k).name));
    if startsWith(p,out+filesep) || p==out, continue; end
    [~,~,ext]=fileparts(p);
    if ~ismember(lower(string(ext)),[".zip",".csv",".xlsx",".xls",".pdf",".png"])
        continue
    end
    paths(end+1,1)=p; bytes(end+1,1)=a(k).bytes;
    modified(end+1,1)=a(k).datenum; kind(end+1,1)=lower(string(ext));
end
T=table(paths,bytes,modified,kind,'VariableNames',{'Path','Bytes','ModifiedSerial','Extension'});
T=sortrows(T,'Path');
fprintf('Inventory: %d files. XLSX/PDF/image inputs are catalogued, not treated as dispatch.\n',height(T));
end
