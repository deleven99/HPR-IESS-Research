function q=trapezoid(p,maxAvail,emin,low,high,emax,bandSum)
p=double(p); z=zeros(size(p));
maxAvail=maxAvail+z; emin=emin+z; low=low+z;
high=high+z; emax=emax+z; bandSum=bandSum+z;
q=maxAvail;
valid=isfinite(p)&isfinite(maxAvail)&isfinite(emin)&isfinite(low)& ...
    isfinite(high)&isfinite(emax)&isfinite(bandSum)& ...
    maxAvail>=0 & bandSum>=0 & emin<=low & low<=high & high<=emax;
left=valid & low>emin; right=valid & emax>high;
q(left)=min(q(left),maxAvail(left).*(p(left)-emin(left))./(low(left)-emin(left)));
q(right)=min(q(right),maxAvail(right).*(emax(right)-p(right))./(emax(right)-high(right)));
q=min(q,bandSum); q=max(q,0);
q(valid & (p<emin | p>emax))=0; q(~valid)=NaN;
end
