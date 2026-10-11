function check_unique(T,keys,label)
if isempty(T), return; end
if height(unique(T(:,keys),'rows'))~=height(T)
    error('HPR:DuplicateKey','Conflicting duplicate natural keys in %s. Inspect source copies.',label);
end
end
