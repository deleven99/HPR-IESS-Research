function make_figures(R,cfg)
S=R.statistics; b=S(S.Days==21 & S.Period=="before",:); a=S(S.Days==21 & S.Period=="after",:);
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1100,650]);
tiledlayout(2,1,'TileSpacing','compact');
nexttile; bar([b.MeanMW,a.MeanMW]); xticks(1:10); xticklabels(cfg.services); xtickangle(25);
ylabel('Mean enabled capacity (MW)'); legend('Before','After','Location','northeast'); grid on;
title('HPR FCAS enablement: 21-day windows');
nexttile; bar([b.EnabledPct,a.EnabledPct]); xticks(1:10); xticklabels(cfg.services); xtickangle(25);
ylabel('Intervals with enablement (%)'); grid on;
savefigs(f,'01_fcas_enablement',cfg);
U=R.uncertainty;
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1100,470]); hold on;
for k=1:numel(cfg.windows)
    nd=cfg.windows(k); v=U(U.Days==nd,:); x=(1:10)+(k-1.5)*.18;
    line=plot(x,v.MeanDifferenceMW,'o','LineWidth',1.1,'DisplayName',sprintf('%d days',nd));
    plot([x;x],[v.DailyBootstrapLo';v.DailyBootstrapHi'],'Color',line.Color, ...
        'LineWidth',1.1,'HandleVisibility','off');
end
yline(0,':','HandleVisibility','off'); xticks(1:10); xticklabels(cfg.services); xtickangle(25);
ylabel('After minus before (MW)'); title('Window sensitivity with descriptive daily bootstrap intervals');
legend('Location','best'); grid on; savefigs(f,'02_window_sensitivity',cfg);
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1000,430]);
tiledlayout(1,2);
for k=1:2
    labels=["before","after"]; v=R.states(R.states.Days==21 & R.states.Period==labels(k) & R.states.ThresholdMW==1,:);
    nexttile; z=nan(3,10); names=["charging","near_zero","discharging"];
    for j=1:3
        for s=1:10, q=v(v.State==names(j) & v.Service==cfg.services(s),:); z(j,s)=q.MeanMW; end
    end
    imagesc(z); colorbar;
    allState=R.states(R.states.Days==21 & R.states.ThresholdMW==1,:);
    upperLimit=max(allState.MeanMW,[],'omitnan');
    if isfinite(upperLimit) && upperLimit>0, caxis([0,upperLimit]); end
    xticks(1:10); xticklabels(cfg.services); xtickangle(60);
    yticks(1:3); yticklabels(["Charging","Near zero","Discharging"]); title(labels(k)+' mean enabled MW');
end
savefigs(f,'03_fcas_by_operating_state',cfg);
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1050,600]);
tiledlayout(2,1,'TileSpacing','compact');
b=R.windows.days21.before; a=R.windows.days21.after;
nexttile; plot(b.Time,b.PowerMW,'LineWidth',.6); hold on; plot(a.Time,a.PowerMW,'LineWidth',.6);
yline(0,':'); ylabel('Signed target (MW)'); title('Energy target: negative charging, positive discharging'); grid on;
nexttile; plot(a.Time,a.StoredEnergyMWh,'LineWidth',.7); ylabel('Reported initial energy (MWh)'); grid on;
title('New-unit stored energy reporting; legacy comparable field unavailable');
savefigs(f,'04_target_and_reported_energy',cfg);
f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1050,420]);
d=R.daily(R.daily.Days==21,:); plot(d.Day,d.MeanRRP,'o-','LineWidth',1.2); grid on;
ylabel('Daily mean SA energy price (AUD/MWh)'); title('Price context for the before and after windows');
savefigs(f,'05_daily_price_context',cfg);
if R.offers.available && ~isempty(R.offers.shapes)
    f=figure('Visible',cfg.figureVisible,'Color','w','Position',[50,50,1050,520]); tiledlayout(1,2);
    for service=["RAISE6SEC","LOWER6SEC"]
        nexttile; hold on;
        s=R.offers.shapes(R.offers.shapes.Service==service,:);
        for k=1:height(s)
            native=linspace(s.ENABLEMENTMIN(k),s.ENABLEMENTMAX(k),400)';
            q=hpr.trapezoid(native,s.MaxAvail(k),s.ENABLEMENTMIN(k), ...
                s.LOWBREAKPOINT(k),s.HIGHBREAKPOINT(k),s.ENABLEMENTMAX(k),s.MaxAvail(k));
            displayPower=native;
            if s.DUID(k)=="HPRL1", displayPower=-native; end
            plot(displayPower,q,'LineWidth',1.4,'DisplayName',s.DUID(k)+' '+s.Period(k));
        end
        xlabel('Signed display of native DUID power (MW)'); ylabel('Offer shape (MW)');
        title(service+' most frequent observed offer shape'); grid on; legend('Location','best');
    end
    savefigs(f,'06_offer_envelopes',cfg);
end
end
function savefigs(f,name,cfg)
exportgraphics(f,fullfile(cfg.figureFolder,[name '.png']),'Resolution',300);
exportgraphics(f,fullfile(cfg.figureFolder,[name '.pdf']),'ContentType','vector');
savefig(f,fullfile(cfg.figureFolder,[name '.fig'])); close(f);
end
