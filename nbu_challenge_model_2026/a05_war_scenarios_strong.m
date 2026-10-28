%% WAR SCENARIOS: baseline, strong escalation, strong de-escalation
% Moderate scenarios are retained for sensitivity checks.
% NBU UChallenge 2026 / IRIS Toolbox
% This is a stand-alone sensitivity exercise based on the SAME filtered
% historical dataset and model as the original a05_war_scenarios_test.m.
% Historical data end in 2026Q2; the forecast starts in 2026Q3.
% Shock magnitudes below are SCENARIO ASSUMPTIONS, not estimated probabilities.

close all; clc;

% Run from the root of nbu_challenge_model_2026, after iris.startup().
tmp = load('results\a02_read_model\model.mat');
m = tmp.m;
load('results\a03_run_filter\filter_data.mat', 'filtdb', 'dq');

rngfcast = dq.rngfcast;
initdb = dbclip(filtdb, dq.rnghist);

% Reproduce exactly the baseline assumptions for the euro area.
p = plan(m, rngfcast);
list_var = {'ir_ea', 'l_gdp_ea_gap', 'dl_cpi_ea'};
list_shock = {'res_ir_ea', 'res_l_gdp_ea_gap', 'res_dl_cpi_ea'};
p = exogenize(p, list_var, rngfcast);
p = endogenize(p, list_shock, rngfcast);

dbext = filtdb.mean;
dbext.ir_ea(rngfcast) = dq.IR_EA(rngfcast);
dbext.l_gdp_ea_gap(rngfcast) = dq.L_GDP_EA_GAP(rngfcast);
dbext.dl_cpi_ea(rngfcast) = dq.DL_CPI_EA(rngfcast);
initdb.mean = dbextend(initdb.mean, dbext);

% Make five independent forecast databases.
db_base = initdb;
db_esc = initdb;       % Moderate escalation: exactly the old 100% case
db_strong = initdb;    % New strong escalation case
db_deesc = initdb;     % Original moderate de-escalation comparison
db_deesc_strong = initdb; % New strong de-escalation scenario

%% INITIALIZE ALL FIVE WAR-RELATED SHOCKS
% Zeroing them in the full forecast period prevents one scenario's shocks
% from leaking into another. Foreign assumptions are unchanged.
war_shocks = {'res_prem_uip_gap', 'res_dl_cpi', 'res_l_gdp_gap', ...
              'res_l_gdp_tnd', 'res_dl_rer_tnd'};

for k = 1:numel(war_shocks)
    name = war_shocks{k};
    if ~isfield(db_base.mean, name)
        db_base.mean.(name) = Series();
    end
    if ~isfield(db_esc.mean, name)
        db_esc.mean.(name) = Series();
    end
    if ~isfield(db_strong.mean, name)
        db_strong.mean.(name) = Series();
    end
    if ~isfield(db_deesc.mean, name)
        db_deesc.mean.(name) = Series();
    end
    if ~isfield(db_deesc_strong.mean, name)
        db_deesc_strong.mean.(name) = Series();
    end
    db_base.mean.(name)(rngfcast) = 0;
    db_esc.mean.(name)(rngfcast) = 0;
    db_strong.mean.(name)(rngfcast) = 0;
    db_deesc.mean.(name)(rngfcast) = 0;
    db_deesc_strong.mean.(name)(rngfcast) = 0;
end

%% MODERATE ESCALATION: ORIGINAL 100% ASSUMPTIONS
qmod = qq(2026,4):qq(2027,2);  % Three quarters

db_esc.mean.res_prem_uip_gap(qmod) = 1i * [ 1.00,  0.50,  0.25];
db_esc.mean.res_dl_cpi(qmod)      = 1i * [ 0.50,  0.50,  0.25];
db_esc.mean.res_l_gdp_gap(qmod)   = 1i * [-0.50, -0.25, -0.10];
db_esc.mean.res_l_gdp_tnd(qq(2026,4)) = -0.50i;
db_esc.mean.res_dl_rer_tnd(qq(2026,4)) = 0.50i;

%% STRONG ESCALATION: NEW, MORE PERSISTENT WAR DISRUPTIONS
% Assumptions: major energy damage in winter 2026/27 and prolonged port,
% logistics, and production constraints through at least 2027Q3.
% Four quarters of shocks (rather than three in the moderate scenario).
qstrong = qq(2026,4):qq(2027,3);

% Increased sovereign-risk premium and pressure on exchange-rate expectations
db_strong.mean.res_prem_uip_gap(qstrong) = 1i * [ 2.00,  1.50,  1.00,  0.50];

% Direct quarterly inflation shocks: energy, fuel, transport and supply costs
% IRIS variable dl_cpi is an annualized quarterly CPI growth rate.
db_strong.mean.res_dl_cpi(qstrong)      = 1i * [ 1.50,  1.50,  1.00,  0.50];

% Temporary losses in demand / actual output relative to productive potential
db_strong.mean.res_l_gdp_gap(qstrong)   = 1i * [-1.00, -0.75, -0.50, -0.25];

% Permanent reductions in potential-GDP LEVEL from capital destruction.
% A one-quarter level shock stays in the trend; do not repeat casually.
db_strong.mean.res_l_gdp_tnd(qq(2026,4)) = -1.00i;
db_strong.mean.res_l_gdp_tnd(qq(2027,1)) = -0.25i;

% Trend real depreciation: retain old +0.50 instead of scaling everything.
% This was already 2x the parameter file's shock std (0.25).
db_strong.mean.res_dl_rer_tnd(qq(2026,4)) = 0.50i;

%% DE-ESCALATION: ORIGINAL ASSUMPTIONS FOR REFERENCE
db_deesc.mean.res_prem_uip_gap(qmod) = 1i * [-0.50, -0.50, -0.25];
db_deesc.mean.res_dl_cpi(qmod)      = 1i * [-0.25, -0.25, -0.10];
db_deesc.mean.res_l_gdp_gap(qmod)   = 1i * [ 0.20,  0.30,  0.30];
db_deesc.mean.res_l_gdp_tnd(qq(2026,4)) = 0.25i;
db_deesc.mean.res_dl_rer_tnd(qq(2026,4)) = -0.25i;

%% STRONG DE-ESCALATION: DURABLE CEASEFIRE AND GRADUAL RECOVERY
% Hypothetical assumptions, starting in 2026Q4:
% - Durable ceasefire / credible security improvements.
% - Lower sovereign risk, gradual restoration of maritime exports.
% - Lower energy/logistics costs, stronger private activity.
% - Reopening idle capacity raises the LEVEL of potential GDP with a delay.
% - Investment, workforce recovery, and productivity support potential
%   GDP GROWTH through 2028, rather than a one-off rebound in 2027.
% This is an optimistic risk scenario, not a probability-weighted forecast.
qdeesc_strong = qq(2026,4):qq(2027,3);

% Falling risk premium as the security and financing outlook improves
db_deesc_strong.mean.res_prem_uip_gap(qdeesc_strong) = ...
    1i * [-1.50, -1.25, -0.75, -0.50];

% Supply-side disinflation as logistics and energy disruptions ease
db_deesc_strong.mean.res_dl_cpi(qdeesc_strong) = ...
    1i * [-0.75, -0.75, -0.50, -0.25];

% Gradual rebound in activity as exporters and firms resume operations
db_deesc_strong.mean.res_l_gdp_gap(qdeesc_strong) = ...
    1i * [0.50, 0.75, 0.75, 0.50];

% Delayed capacity restoration: rebuilding does not happen on ceasefire day
db_deesc_strong.mean.res_l_gdp_tnd(qq(2027,2)) = 0.25i;
db_deesc_strong.mean.res_l_gdp_tnd(qq(2027,4)) = 0.25i;

% Continued reconstruction: additional POTENTIAL GDP GROWTH, not a level
% jump. In model.model, dl_gdp_tnd is annualized and follows an AR(1) with
% persistence 0.9; each innovation also affects later quarters.
% A +0.25 innovation is 1 standard deviation in model/param.m (std = 0.25);
% +0.35 is 1.4 standard deviations. These are transparent optimistic
% assumptions to test, NOT empirically estimated effects of a ceasefire.
% Capacity reopening above and growth in new productive capacity here are
% treated as separate channels; avoid counting the same investments twice.
rebuild_quarters = qq(2027,3):qq(2028,4);
rebuild_growth_shocks = [0.25, 0.25, 0.35, 0.35, 0.35, 0.35];
if ~isfield(db_deesc_strong.mean, 'res_dl_gdp_tnd')
    db_deesc_strong.mean.res_dl_gdp_tnd = Series();
end
db_deesc_strong.mean.res_dl_gdp_tnd(rngfcast) = 0;
db_deesc_strong.mean.res_dl_gdp_tnd(rebuild_quarters) = ...
    1i * rebuild_growth_shocks;

% Smaller real-exchange-rate trend adjustment (one std in param.m)
db_deesc_strong.mean.res_dl_rer_tnd(qq(2026,4)) = -0.25i;

%% RUN FORECASTS
f_base = jforecast(m, db_base, rngfcast, 'plan', p, 'anticipate', true);
f_esc = jforecast(m, db_esc, rngfcast, 'plan', p, 'anticipate', true);
f_strong = jforecast(m, db_strong, rngfcast, 'plan', p, 'anticipate', true);
f_deesc = jforecast(m, db_deesc, rngfcast, 'plan', p, 'anticipate', true);
f_deesc_strong = jforecast(m, db_deesc_strong, rngfcast, ...
    'plan', p, 'anticipate', true);

%% COMPARE MACRO RESULTS
dates = qq(2026,3):qq(2027,4);
disp('Rows: 2026Q3, 2026Q4, 2027Q1, 2027Q2, 2027Q3, 2027Q4');
disp('Policy rate: Baseline | Moderate esc | Strong esc | Moderate deesc | Strong deesc');
disp([double(f_base.mean.ir_pol(dates)), ...
      double(f_esc.mean.ir_pol(dates)), ...
      double(f_strong.mean.ir_pol(dates)), ...
      double(f_deesc.mean.ir_pol(dates)), ...
      double(f_deesc_strong.mean.ir_pol(dates))]);

disp('CPI inflation, year-on-year: Baseline | Moderate esc | Strong esc | Moderate deesc | Strong deesc');
disp([double(f_base.mean.d4l_cpi(dates)), ...
      double(f_esc.mean.d4l_cpi(dates)), ...
      double(f_strong.mean.d4l_cpi(dates)), ...
      double(f_deesc.mean.d4l_cpi(dates)), ...
      double(f_deesc_strong.mean.d4l_cpi(dates))]);

disp('GDP level relative to baseline, log percentage points: Moderate esc | Strong esc | Moderate deesc | Strong deesc');
disp([double(f_esc.mean.l_gdp(dates) - f_base.mean.l_gdp(dates)), ...
      double(f_strong.mean.l_gdp(dates) - f_base.mean.l_gdp(dates)), ...
      double(f_deesc.mean.l_gdp(dates) - f_base.mean.l_gdp(dates)), ...
      double(f_deesc_strong.mean.l_gdp(dates) - f_base.mean.l_gdp(dates))]);

% One-row summary useful for the presentation: 2027Q4
qcheck = qq(2027,4);
fprintf('\n2027Q4 strong minus baseline:\n');
fprintf('Policy rate: %+.2f percentage points\n', ...
    double(f_strong.mean.ir_pol(qcheck) - f_base.mean.ir_pol(qcheck)));
fprintf('YoY CPI inflation: %+.2f percentage points\n', ...
    double(f_strong.mean.d4l_cpi(qcheck) - f_base.mean.d4l_cpi(qcheck)));
fprintf('Real GDP level: %+.2f log percentage points\n', ...
    double(f_strong.mean.l_gdp(qcheck) - f_base.mean.l_gdp(qcheck)));

fprintf('\n2027Q4 strong de-escalation minus baseline:\n');
fprintf('Policy rate: %+.2f percentage points\n', ...
    double(f_deesc_strong.mean.ir_pol(qcheck) - f_base.mean.ir_pol(qcheck)));
fprintf('YoY CPI inflation: %+.2f percentage points\n', ...
    double(f_deesc_strong.mean.d4l_cpi(qcheck) - f_base.mean.d4l_cpi(qcheck)));
fprintf('Real GDP level: %+.2f log percentage points\n', ...
    double(f_deesc_strong.mean.l_gdp(qcheck) - f_base.mean.l_gdp(qcheck)));

% 2028 annual real-GDP growth, using the average of quarterly GDP LEVELS.
% This is not the average of quarterly growth rates or logarithms.
yr27 = qq(2027,1):qq(2027,4);
yr28 = qq(2028,1):qq(2028,4);
gdp_2027 = [double(f_base.mean.l_gdp(yr27)), ...
            double(f_esc.mean.l_gdp(yr27)), ...
            double(f_strong.mean.l_gdp(yr27)), ...
            double(f_deesc.mean.l_gdp(yr27)), ...
            double(f_deesc_strong.mean.l_gdp(yr27))];
gdp_2028 = [double(f_base.mean.l_gdp(yr28)), ...
            double(f_esc.mean.l_gdp(yr28)), ...
            double(f_strong.mean.l_gdp(yr28)), ...
            double(f_deesc.mean.l_gdp(yr28)), ...
            double(f_deesc_strong.mean.l_gdp(yr28))];
growth_2028 = 100 * (sum(exp(gdp_2028/100), 1) ...
                       ./ sum(exp(gdp_2027/100), 1) - 1);
fprintf('\n2028 real-GDP annual growth (%%):\n');
disp('Baseline | Moderate esc | Strong esc | Moderate deesc | Strong deesc');
disp(growth_2028);

%% SAVE AS NEW RECONSTRUCTION EXPERIMENT; PRESERVE EARLIER RESULTS
result_dir = fullfile('results', 'a05_war_scenarios');
if ~exist(result_dir, 'dir')
    mkdir(result_dir);
end
save(fullfile(result_dir, 'war_scenarios_reconstruction.mat'), ...
    'f_base', 'f_esc', 'f_strong', 'f_deesc', 'f_deesc_strong', ...
    'qmod', 'qstrong', 'qdeesc_strong', 'war_shocks', ...
    'rebuild_quarters', 'rebuild_growth_shocks');

% Simple numeric file that can be opened even without the IRIS Toolbox.
% In every 10-by-5 matrix, columns follow this order:
% [baseline, moderate escalation, strong escalation,
%  moderate de-escalation, strong de-escalation].
out.forecast_start = '2026Q3';
out.forecast_end = '2028Q4';
out.scenarios = {'baseline', 'moderate', 'strong', ...
                 'deescalation', 'strong_deescalation'};
out.reconstruction_growth_shock_annualized_pp = ...
    reshape(rebuild_growth_shocks, [], 1);
out.reconstruction_growth_start = '2027Q3';
out.reconstruction_growth_end = '2028Q4';
out.policy_rate = [double(f_base.mean.ir_pol(rngfcast)), ...
                   double(f_esc.mean.ir_pol(rngfcast)), ...
                   double(f_strong.mean.ir_pol(rngfcast)), ...
                   double(f_deesc.mean.ir_pol(rngfcast)), ...
                   double(f_deesc_strong.mean.ir_pol(rngfcast))];
out.inflation_yoy = [double(f_base.mean.d4l_cpi(rngfcast)), ...
                     double(f_esc.mean.d4l_cpi(rngfcast)), ...
                     double(f_strong.mean.d4l_cpi(rngfcast)), ...
                     double(f_deesc.mean.d4l_cpi(rngfcast)), ...
                     double(f_deesc_strong.mean.d4l_cpi(rngfcast))];
out.real_gdp_log = [double(f_base.mean.l_gdp(rngfcast)), ...
                    double(f_esc.mean.l_gdp(rngfcast)), ...
                    double(f_strong.mean.l_gdp(rngfcast)), ...
                    double(f_deesc.mean.l_gdp(rngfcast)), ...
                    double(f_deesc_strong.mean.l_gdp(rngfcast))];
out.gdp_gap = [double(f_base.mean.l_gdp_gap(rngfcast)), ...
               double(f_esc.mean.l_gdp_gap(rngfcast)), ...
               double(f_strong.mean.l_gdp_gap(rngfcast)), ...
               double(f_deesc.mean.l_gdp_gap(rngfcast)), ...
               double(f_deesc_strong.mean.l_gdp_gap(rngfcast))];
out.exchange_rate_log = [double(f_base.mean.l_er(rngfcast)), ...
                         double(f_esc.mean.l_er(rngfcast)), ...
                         double(f_strong.mean.l_er(rngfcast)), ...
                         double(f_deesc.mean.l_er(rngfcast)), ...
                         double(f_deesc_strong.mean.l_er(rngfcast))];
save(fullfile(result_dir, 'war_scenarios_reconstruction_numeric.mat'), 'out');

disp('War scenarios (including persistent reconstruction) Done!');
