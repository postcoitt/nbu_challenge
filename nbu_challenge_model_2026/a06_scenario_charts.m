%% A06: WAR SCENARIO CHARTS FOR NBU UCHALLENGE 2026
% Uses only the NUMERIC results saved by a05_war_scenarios_strong.m.
% No IRIS startup is required to run this script.
%
% Three presentation scenarios:
%   1. Baseline
%   2. Strong escalation
%   3. Strong de-escalation (including reconstruction)
%
% Run from the project root (the folder containing the a05 script).
% Before running A06, run A05 at least once to create its numeric .mat file.

clearvars; close all; clc;

%% 1. LOAD AND CHECK THE NUMERIC FORECAST
source_file = fullfile('results', 'a05_war_scenarios', ...
    'war_scenarios_reconstruction_numeric.mat');

if ~isfile(source_file)
    error(['Cannot find %s\n' ...
           'Run a05_war_scenarios_strong.m first, from the project root.'], ...
           source_file);
end

loaded = load(source_file, 'out');
if ~isfield(loaded, 'out')
    error('The MAT file does not contain the expected variable "out".');
end
out = loaded.out;

% Find scenarios BY NAME, rather than relying on column positions.
scenario_names = out.scenarios;
wanted = {'baseline', 'strong', 'strong_deescalation'};
cols = zeros(1, numel(wanted));
for k = 1:numel(wanted)
    idx = find(strcmp(scenario_names, wanted{k}), 1);
    if isempty(idx)
        error('Missing scenario "%s" in the numeric MAT file.', wanted{k});
    end
    cols(k) = idx;
end

% Generate quarter labels directly from the file's forecast horizon.
start_parts = sscanf(out.forecast_start, '%dQ%d');
end_parts   = sscanf(out.forecast_end,   '%dQ%d');
if numel(start_parts) ~= 2 || numel(end_parts) ~= 2
    error('Unexpected forecast date format (expected e.g. "2026Q3").');
end

n_quarters = (end_parts(1) - start_parts(1))*4 ...
           + end_parts(2) - start_parts(2) + 1;
if n_quarters < 1
    error('Forecast end must not precede forecast start.');
end

quarter_labels = cell(1, n_quarters);
for k = 1:n_quarters
    zero_based_quarter = start_parts(2) - 1 + k - 1;
    yr = start_parts(1) + floor(zero_based_quarter/4);
    qt = mod(zero_based_quarter, 4) + 1;
    quarter_labels{k} = sprintf('%dQ%d', yr, qt);
end
x = 1:n_quarters;

required_fields = {'inflation_yoy', 'policy_rate', ...
                   'real_gdp_log', 'exchange_rate_log'};
for k = 1:numel(required_fields)
    values = out.(required_fields{k});
    if ~isnumeric(values) || size(values,1) ~= n_quarters ...
            || size(values,2) < max(cols) ...
            || any(~isfinite(values(:, cols)), 'all')
        error('Invalid data in out.%s.', required_fields{k});
    end
end

%% 2. PREPARE FOUR INDICATORS IN ECONOMICALLY MEANINGFUL UNITS
% Inflation and policy rate are already expressed in percent.
inflation = out.inflation_yoy(:, cols);              % % year-on-year
policy_rate = out.policy_rate(:, cols);               % % per annum

% In this QPM, l_gdp = 100*log(real GDP).
% Express GDP as an index: all scenarios = 100 in 2026Q3.
% This is a LEVEL index, NOT quarterly or yearly GDP growth.
gdp_initial_log = out.real_gdp_log(1, cols(1));
gdp_index = 100 * exp((out.real_gdp_log(:, cols) ...
                       - gdp_initial_log)/100);

% IMPORTANT: l_er = 100*log(UAH per EUR), not UAH per USD.
uah_per_eur = exp(out.exchange_rate_log(:, cols)/100);

chart_data = {inflation, policy_rate, gdp_index, uah_per_eur};
chart_titles = {'Інфляція', 'Облікова ставка (QPM)', ...
                'Реальний ВВП (2026Q3 = 100)', 'Курс гривні до євро'};
y_labels = {'%, рік до року', '%, річних', ...
            'Індекс реального ВВП', 'UAH за 1 EUR'};
file_stems = {'01_inflation', '02_policy_rate', ...
              '03_real_gdp_index', '04_uah_eur'};

legend_labels = {'Базовий', 'Сильна ескалація', ...
                 'Сильна деескалація'};
palette = [0.19 0.27 0.39;   % Baseline: dark blue-gray
           0.76 0.19 0.18;   % Escalation: red
           0.10 0.48 0.35];  % De-escalation: green

%% 3. EXPORT FOUR INDIVIDUAL CHARTS
output_dir = fullfile('results', 'a06_scenario_charts');
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

% The figures are saved as PNG (for Google Slides/Docs) and editable FIG.
% Change to true if you want five figure windows to remain open.
show_figures = false;
visibility = 'off';
if show_figures
    visibility = 'on';
end

for i = 1:numel(chart_data)
    fig = figure('Color', 'w', 'Visible', visibility, ...
                 'Position', [100 100 1200 650]);
    ax = axes('Parent', fig);
    draw_three_scenarios(ax, x, chart_data{i}, quarter_labels, ...
        chart_titles{i}, y_labels{i}, legend_labels, palette, i == 1);

    exportgraphics(fig, fullfile(output_dir, [file_stems{i} '.png']), ...
        'Resolution', 250);
    savefig(fig, fullfile(output_dir, [file_stems{i} '.fig']));
    if ~show_figures
        close(fig);
    end
end

%% 4. EXPORT ONE COMPACT 2-BY-2 DASHBOARD
fig = figure('Color', 'w', 'Visible', visibility, ...
             'Position', [100 100 1550 1000]);
t = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

for i = 1:numel(chart_data)
    ax = nexttile(t);
    draw_three_scenarios(ax, x, chart_data{i}, quarter_labels, ...
        chart_titles{i}, y_labels{i}, legend_labels, palette, i == 1);
end
sgtitle(t, 'Воєнні сценарії QPM: 2026Q3–2028Q4', ...
    'FontSize', 17, 'FontWeight', 'bold');

exportgraphics(fig, fullfile(output_dir, '00_all_scenarios.png'), ...
    'Resolution', 220);
savefig(fig, fullfile(output_dir, '00_all_scenarios.fig'));
if ~show_figures
    close(fig);
end

fprintf('\nScenario charts are ready!\n');
fprintf('Folder: %s\n', output_dir);
fprintf('Exported: 4 PNG + 4 FIG + dashboard PNG/FIG.\n');
fprintf('Scenarios: Baseline / Strong escalation / Strong de-escalation.\n');

%% LOCAL PLOTTING FUNCTION
function draw_three_scenarios(ax, x, values, quarter_labels, ...
        chart_title, y_label, legend_labels, palette, show_cpi_target)

    hold(ax, 'on');
    lines = gobjects(1, 3);
    for j = 1:3
        lines(j) = plot(ax, x, values(:, j), '-o', ...
            'Color', palette(j, :), 'LineWidth', 2.3, ...
            'MarkerSize', 4.7, 'MarkerFaceColor', palette(j, :));
    end

    if show_cpi_target
        yline(ax, 5, '--', 'Ціль інфляції: 5%', ...
            'Color', [0.52 0.56 0.62], 'LineWidth', 1.2, ...
            'LabelHorizontalAlignment', 'left');
    end

    grid(ax, 'on');
    ax.GridAlpha = 0.13;
    ax.XLim = [x(1), x(end)];
    ax.XTick = x;
    ax.XTickLabel = quarter_labels;
    ax.XTickLabelRotation = 45;
    ax.FontName = 'Arial';
    ax.FontSize = 10.5;
    ax.Box = 'off';

    title(ax, chart_title, 'FontSize', 14, 'FontWeight', 'bold');
    ylabel(ax, y_label, 'FontSize', 11);
    legend(ax, lines, legend_labels, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'FontSize', 10, 'Box', 'off');
    hold(ax, 'off');
end
