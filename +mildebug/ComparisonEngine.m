classdef ComparisonEngine < handle
    methods
        function r=compare(~,a,b,absTol,relTol)
            if nargin<4, absTol=1e-6; end
            if nargin<5, relTol=1e-3; end
            r=struct('Pass',false,'MaxAbs',NaN,'MaxRel',NaN);
            if isempty(a)||isempty(b), return; end
            x=a(:); y=b(:); n=min(numel(x),numel(y)); x=x(1:n); y=y(1:n);
            d=abs(x-y); r.MaxAbs=max(d,[],'omitnan'); r.MaxRel=max(d./max(abs(y),eps),[],'omitnan');
            r.Pass=r.MaxAbs<=absTol && r.MaxRel<=relTol;
        end
    end
end
