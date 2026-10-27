function [T_ai, T_bl] = evaluate()
% EVALUATE  The final exam: AI vs. conventional ACC on UNSEEN scenarios.
%
%   evaluate()
%
% 1. Loads the trained AI from trained_agent.mat.
% 2. Loads the fixed UNSEEN test scenarios from test_scenarios.mat (or
%    creates them the first time with the test seed). There are 7 families
%    x 15 = 105 episodes. The 'mixed' family never appears in training.
% 3. Drives every test scenario with BOTH controllers (exactly the same
%    lead car behaviour for both, so the comparison is fair).
% 4. Prints and saves the metrics table (CSV) and plots (PNG) to results/.

cfg = acc_config();
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
if ~exist(cfg.model_file, 'file')
    error('trained_agent.mat not found. Run train() first (or run_all).');
end
S = load(cfg.model_file);
agent = S.agent;

if exist(cfg.test_file, 'file')
    T = load(cfg.test_file);
    test_scs = T.test_scs;
else
    test_scs = make_scenarios('test', 15, cfg.seed_test, cfg);
    save(cfg.test_file, 'test_scs', '-v7');
end
n = numel(test_scs);
fprintf('\nEvaluating on %d UNSEEN test episodes...\n', n);

ai.type = 'rl';       ai.net = agent.net;   ai.actions = agent.actions;
bl.type = 'baseline';

names = {'avg_gap', 'avg_dsafe', 'gap_err', 'speed_rmse', 'collided', ...
         'rms_acc', 'rms_jerk', 'min_gap', 'ret'};
M_ai = zeros(n, numel(names)); M_bl = zeros(n, numel(names));
types = cell(1, n);
logs_ai = cell(1, n); logs_bl = cell(1, n);
for i = 1:n
    [~, la] = run_episode(test_scs{i}, ai, cfg);
    [~, lb] = run_episode(test_scs{i}, bl, cfg);
    ma = compute_metrics(la, cfg); mb = compute_metrics(lb, cfg);
    for j = 1:numel(names)
        M_ai(i, j) = ma.(names{j});
        M_bl(i, j) = mb.(names{j});
    end
    types{i} = test_scs{i}.type;
    logs_ai{i} = la; logs_bl{i} = lb;
end

% ---------------- overall table ----------------
T_ai = summarise(M_ai, names);
T_bl = summarise(M_bl, names);
rows = {
 'Average following distance [m]',     'avg_gap',    'info'
 'Average safe distance d_safe [m]',   'avg_dsafe',  'info'
 'Gap error |gap - d_safe| [m]',       'gap_err',    'lower'
 'Speed tracking error RMSE [m/s]',    'speed_rmse', 'lower'
 'Collision rate [%]',                 'collided',   'lower'
 'RMS acceleration [m/s^2]',           'rms_acc',    'lower'
 'RMS jerk [m/s^3]',                   'rms_jerk',   'lower'
 'Minimum gap, worst episode [m]',     'min_gap_worst', 'higher'
 'Minimum gap, average episode [m]',   'min_gap',    'higher'
 'Average total reward per episode',   'ret',        'higher'
};
fprintf('\n=============== RESULTS on %d unseen test episodes ===============\n', n);
fprintf('%-36s %12s %12s   %s\n', 'Metric', 'AI (DQN)', 'Baseline', 'Better');
csv = fullfile(cfg.results_dir, 'metrics_table.csv');
fid = fopen(csv, 'w');
fprintf(fid, 'Metric,AI_DQN,Baseline_PD,Better\n');
for r = 1:size(rows, 1)
    key = rows{r, 2};
    va = T_ai.(key); vb = T_bl.(key);
    if strcmp(key, 'collided'), va = 100 * va; vb = 100 * vb; end
    w = winner(va, vb, rows{r, 3});
    fprintf('%-36s %12.3f %12.3f   %s\n', rows{r, 1}, va, vb, w);
    fprintf(fid, '"%s",%.4f,%.4f,%s\n', rows{r, 1}, va, vb, w);
end
fclose(fid);
fprintf('Total collisions: AI = %d, Baseline = %d (out of %d episodes each)\n', ...
        sum(M_ai(:, 5)), sum(M_bl(:, 5)), n);

% ---------------- per-scenario table ----------------
utypes = unique(types);
csv2 = fullfile(cfg.results_dir, 'metrics_by_scenario.csv');
fid = fopen(csv2, 'w');
fprintf(fid, 'Scenario,Controller,Episodes,GapError_m,SpeedRMSE_mps,Collisions,RMSAccel,RMSJerk,MinGapWorst_m,AvgReturn\n');
fprintf('\nPer scenario family (AI / Baseline):\n');
fprintf('%-15s %15s %15s %13s %15s %15s\n', 'scenario', 'gap err [m]', 'speed RMSE', 'crashes', 'RMS jerk', 'min gap [m]');
for u = 1:numel(utypes)
    sel = strcmp(types, utypes{u});
    a = summarise(M_ai(sel, :), names); b = summarise(M_bl(sel, :), names);
    fprintf('%-15s %7.2f/%-7.2f %7.2f/%-7.2f %6d/%-6d %7.2f/%-7.2f %7.1f/%-7.1f\n', utypes{u}, ...
        a.gap_err, b.gap_err, a.speed_rmse, b.speed_rmse, sum(M_ai(sel, 5)), sum(M_bl(sel, 5)), ...
        a.rms_jerk, b.rms_jerk, a.min_gap_worst, b.min_gap_worst);
    fprintf(fid, '%s,AI_DQN,%d,%.3f,%.3f,%d,%.3f,%.3f,%.3f,%.2f\n', utypes{u}, sum(sel), a.gap_err, ...
        a.speed_rmse, sum(M_ai(sel, 5)), a.rms_acc, a.rms_jerk, a.min_gap_worst, a.ret);
    fprintf(fid, '%s,Baseline_PD,%d,%.3f,%.3f,%d,%.3f,%.3f,%.3f,%.2f\n', utypes{u}, sum(sel), b.gap_err, ...
        b.speed_rmse, sum(M_bl(sel, 5)), b.rms_acc, b.rms_jerk, b.min_gap_worst, b.ret);
end
fclose(fid);

% ---------------- plots ----------------
for u = 1:numel(utypes)
    i = find(strcmp(types, utypes{u}), 1);       % first test episode of this family
    plot_scenario(logs_ai{i}, logs_bl{i}, utypes{u}, cfg);
end
plot_bars(T_ai, T_bl, cfg);
if isfield(agent, 'hist')
    plot_training_curve(agent, cfg);
end
fprintf('\nSaved: results/metrics_table.csv, results/metrics_by_scenario.csv and PNG plots.\n');
end

% ======================================================================
function T = summarise(M, names)
% average each metric over episodes (ignoring "not available" values)
for j = 1:numel(names)
    x = M(:, j); x = x(~isnan(x));
    if isempty(x), T.(names{j}) = NaN; else, T.(names{j}) = mean(x); end
end
T.min_gap_worst = min(M(:, strcmp(names, 'min_gap')));
end

function w = winner(a, b, rule)
switch rule
    case 'lower',  if abs(a - b) < 1e-9, w = 'tie'; elseif a < b, w = 'AI'; else, w = 'Baseline'; end
    case 'higher', if abs(a - b) < 1e-9, w = 'tie'; elseif a > b, w = 'AI'; else, w = 'Baseline'; end
    otherwise,     w = '(info)';
end
end

function plot_scenario(la, lb, type, cfg)
fig = figure('visible', 'off', 'Position', [100 100 900 750]);
subplot(3, 1, 1);
plot(la.t, la.vl, 'k:', 'LineWidth', 1.2); hold on;
plot(la.t, la.ve, 'b', 'LineWidth', 1.5);
plot(lb.t, lb.ve, 'r--', 'LineWidth', 1.5);
plot([0 cfg.T], [cfg.v_set cfg.v_set], 'Color', [0.5 0.5 0.5]);
ylabel('speed [m/s]'); grid on;
legend({'lead car', 'AI (DQN)', 'Baseline', 'cruise speed'}, 'Location', 'northeast');
title(['Unseen test scenario: ', strrep(type, '_', ' ')]);
subplot(3, 1, 2);
plot(la.t, min(la.gap, cfg.range), 'b', 'LineWidth', 1.5); hold on;
plot(lb.t, min(lb.gap, cfg.range), 'r--', 'LineWidth', 1.5);
plot(la.t, la.d_safe, 'b:', lb.t, lb.d_safe, 'r:');
ylabel('gap [m]'); grid on;
legend({'AI gap', 'Baseline gap', 'AI d\_safe', 'Baseline d\_safe'}, 'Location', 'northeast');
subplot(3, 1, 3);
plot(la.t, la.ae, 'b', 'LineWidth', 1.2); hold on;
plot(lb.t, lb.ae, 'r--', 'LineWidth', 1.2);
ylabel('accel [m/s^2]'); xlabel('time [s]'); grid on;
legend({'AI', 'Baseline'}, 'Location', 'northeast');
print(fig, '-dpng', '-r90', fullfile(cfg.results_dir, ['scenario_', type, '.png']));
close(fig);
end

function plot_bars(A, B, cfg)
% side-by-side bars; each metric is divided by the larger of the two
% values so all metrics fit on one chart (1.0 = the bigger one)
keys = {'gap_err', 'speed_rmse', 'rms_acc', 'rms_jerk', 'min_gap_worst', 'collided'};
labels = {'gap error', 'speed RMSE', 'RMS accel', 'RMS jerk', 'min gap (higher=safer)', 'collision rate'};
va = zeros(1, numel(keys)); vb = va;
for i = 1:numel(keys), va(i) = A.(keys{i}); vb(i) = B.(keys{i}); end
mx = max([va; vb], [], 1); mx(mx == 0) = 1;
fig = figure('visible', 'off', 'Position', [100 100 950 480]);
h = bar([va ./ mx; vb ./ mx]');
set(h(1), 'FaceColor', [0.2 0.4 0.9]); set(h(2), 'FaceColor', [0.9 0.3 0.3]);
set(gca, 'XTick', 1:numel(keys), 'XTickLabel', labels);
ylabel('relative value (1 = larger of the two)'); grid on;
legend({'AI (DQN)', 'Baseline PD'}, 'Location', 'northwest');
title('AI vs Baseline on unseen tests (lower is better, except min gap)');
for i = 1:numel(keys)
    text(i - 0.15, va(i) / mx(i) + 0.03, sprintf('%.2f', va(i)), 'HorizontalAlignment', 'center', 'FontSize', 8);
    text(i + 0.15, vb(i) / mx(i) + 0.03, sprintf('%.2f', vb(i)), 'HorizontalAlignment', 'center', 'FontSize', 8);
end
ylim([0 1.2]);
print(fig, '-dpng', '-r90', fullfile(cfg.results_dir, 'comparison_bar_chart.png'));
close(fig);
end

function plot_training_curve(agent, cfg)
h = agent.hist;
n = numel(h.ep_return);
ma = zeros(1, n);
for i = 1:n, ma(i) = mean(h.ep_return(max(1, i - 19):i)); end
fig = figure('visible', 'off', 'Position', [100 100 900 450]);
plot(1:n, h.ep_return, 'Color', [0.7 0.8 1.0]); hold on;
plot(1:n, ma, 'b', 'LineWidth', 2);
plot(h.val_ep, h.val_score, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 4);
if agent.best_episode > 0
    plot(agent.best_episode, agent.best_val_score, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'y');
end
grid on; xlabel('episode'); ylabel('total reward per episode');
legend({'each practice episode', '20-episode average', 'mock test (no exploring)', 'saved model'}, ...
       'Location', 'southeast');
title('DQN training reward curve');
print(fig, '-dpng', '-r100', fullfile(cfg.results_dir, 'training_reward_curve.png'));
close(fig);
end
