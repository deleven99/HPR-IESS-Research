function q=quantile(x,p)
x=sort(x(isfinite(x))); n=numel(x);
if n==0, q=nan(size(p)); return; end
if n==1, q=repmat(x,size(p)); return; end
positions=((1:n)-0.5)/n;
q=interp1([0,positions,1],[x(1);x(:);x(end)],p,'linear');
end
