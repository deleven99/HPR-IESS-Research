function x=num(T,name)
if ismember(name,T.Properties.VariableNames)
    v=T.(name); if isnumeric(v), x=double(v); else, x=str2double(string(v)); end
else
    x=nan(height(T),1);
end
end
