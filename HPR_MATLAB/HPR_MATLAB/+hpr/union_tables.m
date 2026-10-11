function T=union_tables(A,B)
if isempty(A), T=B; return; end
if isempty(B), T=A; return; end
names=union(A.Properties.VariableNames,B.Properties.VariableNames,'stable');
for k=1:numel(names)
    name=names{k};
    if ~ismember(name,A.Properties.VariableNames), A.(name)=strings(height(A),1); end
    if ~ismember(name,B.Properties.VariableNames), B.(name)=strings(height(B),1); end
end
T=[A(:,names);B(:,names)];
end
