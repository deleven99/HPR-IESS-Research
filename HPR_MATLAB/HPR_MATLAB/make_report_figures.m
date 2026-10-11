function make_report_figures(resultsFolder)
if nargin<1
    resultsFolder=uigetdir(pwd,'Select HPR_results');
    if isequal(resultsFolder,0), return; end
end
root=fileparts(mfilename('fullpath')); addpath(root);
out=fullfile(resultsFolder,'report_figures'); if ~isfolder(out), mkdir(out); end
E=readtable(fullfile(resultsFolder,'matched_offer_records.csv'),'TextType','string');
if ~isdatetime(E.Time), E.Time=hpr.time(E.Time); end
U=readtable(fullfile(resultsFolder,'window_sensitivity_and_bootstrap.csv'),'TextType','string');
cfg=hpr_config(resultsFolder,out); blue=[.114,.373,.541]; orange=[.745,.384,.169];
uid=["HPRG1","HPR1","HPRL1","HPR1"];
service=["RAISE6SEC","RAISE6SEC","LOWER60SEC","LOWER60SEC"];
titles=["Legacy generation: Raise 6 s","Single BDU: Raise 6 s", ...
    "Legacy load: Lower 60 s","Single BDU: Lower 60 s"];
shapeNames={'MaxAvail','ENABLEMENTMIN','LOWBREAKPOINT','HIGHBREAKPOINT','ENABLEMENTMAX'};
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1100,680]); tiledlayout(2,2,'TileSpacing','compact');
for k=1:4
    if mod(k,2)==1
        start=datetime(2024,9,3,0,5,0); finish=datetime(2024,9,24); col=blue;
    else
        start=datetime(2024,9,25,0,5,0); finish=datetime(2024,10,16); col=orange;
    end
    v=E(E.DUID==uid(k) & E.Service==service(k) & E.Time>=start & E.Time<=finish,:);
    assert(~isempty(v),'HPR:MissingOffers','Required offer group missing.');
    [shapes,~,index]=unique(v(:,shapeNames),'rows'); counts=accumarray(index,1);
    [n,ind]=max(counts); r=shapes(ind,:);
    x=[r.ENABLEMENTMIN,r.LOWBREAKPOINT,r.HIGHBREAKPOINT,r.ENABLEMENTMAX];
    y=[0,r.MaxAvail,r.MaxAvail,0];
    nexttile; fill(x,y,col,'FaceAlpha',.12,'EdgeColor',col,'LineWidth',1.8); hold on;
    title(titles(k)); ylabel('Offered FCAS (MW)'); ylim([0,100]); grid on;
    if mod(k,2)==0
        xlim([-135,165]); xline(0,':'); xlabel('Net MW: charge < 0, discharge > 0');
    elseif k==1
        xlim([-7,160]); xlabel('Generation (MW)');
    else
        xlim([-7,160]); xlabel('Consumption (MW)');
    end
    text(.98,.94,sprintf('Observed in %d / %d offers',n,height(v)), ...
        'Units','normalized','HorizontalAlignment','right','FontSize',9);
end
save_report_plot(f,out,'Fig2_observed_offer_shapes');
labels=["Raise 1 s","Raise 6 s","Raise 60 s","Raise 5 min", ...
    "Lower 1 s","Lower 6 s","Lower 60 s","Lower 5 min","Raise regulation","Lower regulation"];
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,960,680]); hold on;
for k=1:2
    if k==1, nd=21; offset=-.12; col=blue; else, nd=14; offset=.12; col=orange; end
    v=U(U.Days==nd,:); [present,ix]=ismember(cfg.services',v.Service);
    assert(all(present),'HPR:MissingStatistics','Required bootstrap row missing.'); v=v(ix,:);
    y=(1:10)'+offset;
    plot(v.MeanDifferenceMW,y,'o','Color',col,'MarkerFaceColor',col, ...
        'DisplayName',sprintf('%d-day windows',nd));
    for j=1:10
        plot([v.DailyBootstrapLo(j),v.DailyBootstrapHi(j)],[y(j),y(j)], ...
            'Color',col,'LineWidth',1.3,'HandleVisibility','off');
    end
end
xline(0,'--','HandleVisibility','off'); yticks(1:10); yticklabels(labels);
set(gca,'YDir','reverse'); xlim([-23,23]); ylim([.5,10.5]); grid on;
xlabel('Change in mean enabled capacity (MW): after minus before');
legend('Location','southwest'); save_report_plot(f,out,'Fig3_window_comparison');
fprintf('Final report plots saved to %s\n',out);
end
function save_report_plot(f,out,name)
exportgraphics(f,fullfile(out,[name '.png']),'Resolution',300);
exportgraphics(f,fullfile(out,[name '.pdf']),'ContentType','vector');
savefig(f,fullfile(out,[name '.fig'])); close(f);
end
