function files=unpack(path,cacheFolder)
[~,stem,ext]=fileparts(path);
if ~strcmpi(ext,'.zip'), files=string(path); return; end
digest=java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(char(path),'UTF-8'));
hex=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2)',1,[]));
folder=fullfile(cacheFolder,'unpacked',char(string(stem)+"_"+string(hex(1:12))));
info=dir(path); token=[info.bytes,info.datenum];
stamp=fullfile(folder,'unpack_stamp.mat');
valid=false;
if isfile(stamp), s=load(stamp,'token'); valid=isequal(token,s.token); end
if ~valid
    if isfolder(folder), rmdir(folder,'s'); end
    mkdir(folder); unzip(char(path),folder); save(stamp,'token');
end
allFiles=dir(fullfile(folder,'**','*')); allFiles=allFiles(~[allFiles.isdir]);
z=allFiles(endsWith(lower(string({allFiles.name})),'.zip'));
files=strings(0,1);
for k=1:numel(z)
    files=[files;hpr.unpack(string(fullfile(z(k).folder,z(k).name)),cacheFolder)];
end
csv=allFiles(endsWith(lower(string({allFiles.name})),'.csv'));
for k=1:numel(csv), files(end+1,1)=string(fullfile(csv(k).folder,csv(k).name)); end
files=unique(files,'stable');
end
