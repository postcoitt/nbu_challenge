
%% WAR SCENARIOS: first test
close all; clc;

% Load the same model and filtered data as baseline
tmp = load('results\a02_read_model\model.mat');
m = tmp.m;

load('results\a03_run_filter\filter_data.mat', 'filtdb', 'dq');

rngfcast = dq.rngfcast;
qshock = qq(2026,3);

% Recreate baseline external assumptions
initdb = dbclip(filtdb, dq.rnghist);

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

% Initialize the risk-premium shock
if ~isfield(initdb.mean, 'res_prem_uip_gap')
    initdb.mean.res_prem_uip_gap = Series();
end
initdb.mean.res_prem_uip_gap(rngfcast) = 0;

% Three independent forecasts
db_base = initdb;
db_esc = initdb;
db_deesc = initdb;


%% WAR SCENARIO ASSUMPTIONS
% Scenario shocks: 2026Q4 to 2027Q2
qwar = qq(2026,4):qq(2027,2);

% Initialize additional shocks to zero
shocks = {'res_prem_uip_gap', ...
    'res_dl_cpi', ...
    'res_l_gdp_gap'};

for k = 1:numel(shocks)
    name = shocks{k};
    db_esc.mean.(name)(rngfcast) = 0;
    db_deesc.mean.(name)(rngfcast) = 0;
end

%% ESCALATION

% Higher sovereign risk premium
db_esc.mean.res_prem_uip_gap(qwar) = [1.00 0.50 0.25];

% Higher inflation pressure
db_esc.mean.res_dl_cpi(qwar) = [0.50 0.50 0.25];

% Weaker economic activity
db_esc.mean.res_l_gdp_gap(qwar) = [-0.50 -0.25 -0.10];

%% DE-ESCALATION

% Lower sovereign risk premium
db_deesc.mean.res_prem_uip_gap(qwar) = [-0.50 -0.50 -0.25];

% Lower inflation pressure
db_deesc.mean.res_dl_cpi(qwar) = [-0.25 -0.25 -0.10];

% Gradual economic recovery
db_deesc.mean.res_l_gdp_gap(qwar) = [0.20 0.30 0.30];

% Run forecasts
f_base = jforecast(m, db_base, rngfcast, ...
    'plan', p, 'anticipate', true);

f_esc = jforecast(m, db_esc, rngfcast, ...
    'plan', p, 'anticipate', true);

f_deesc = jforecast(m, db_deesc, rngfcast, ...
    'plan', p, 'anticipate', true);

% Compare policy rates
dates = qq(2026,3):qq(2027,4);

disp('Policy rate: Baseline / Escalation / De-escalation');
disp([double(f_base.mean.ir_pol(dates)), ...
      double(f_esc.mean.ir_pol(dates)), ...
      double(f_deesc.mean.ir_pol(dates))]);

% Save results
mkdir('results\a05_war_scenarios');
save('results\a05_war_scenarios\war_scenarios.mat', ...
    'f_base', 'f_esc', 'f_deesc');

disp('War scenarios Done!');
