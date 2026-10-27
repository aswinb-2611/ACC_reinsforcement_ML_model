function [ai_mean, bl_mean] = dev_check(model_file)
% DEV_CHECK  Compares the AI and the baseline on the DEVELOPMENT set.
%
%   dev_check()                       % uses trained_agent.mat
%   dev_check('some_other_agent.mat') % compare another saved brain
%
% The development ("dev") set is 35 drives (5 of each training family)
% built with the SAME number ranges as the final exam but a DIFFERENT seed
% (31337). We used it while tuning to diagnose problems and to compare
% training runs, so the real exam (test_scenarios.mat) stays untouched.
% The 'mixed' family is deliberately left out, so it stays completely
% unseen until the exam.
%
% Prints one line per drive: total marks, gap error, closest gap, RMS jerk
% and crashes, for AI / baseline. Returns the mean marks of each.

cfg = acc_config();
if nargin < 1 || isempty(model_file), model_file = cfg.model_file; end
S = load(model_file);
ai.type = 'rl'; ai.net = S.agent.net; ai.actions = S.agent.actions;
bl.type = 'baseline';

set_seed(31337);
types = {'constant', 'stop_and_go', 'hard_brake', 'slow_then_fast', 'cut_in', 'random_smooth'};
scs = {};
for i = 1:5
    for j = 1:numel(types)
        scs{end + 1} = lead_profile(types{j}, 'test', cfg); %#ok<AGROW>
    end
end
% plus 5 drives like the ones you make in the live demo (a person moving the
% speed slider). They come after the first 30, so those stay exactly as before.
for i = 1:5
    scs{end + 1} = lead_profile('live_like', 'test', cfg); %#ok<AGROW>
end

fprintf('\n #  scenario        |  marks AI/BL   | gap err AI/BL | min gap AI/BL | jerk AI/BL | crash\n');
Ra = zeros(1, numel(scs)); Rb = Ra; ca = 0; cb = 0;
keys = {'gap_err', 'speed_rmse', 'rms_acc', 'rms_jerk', 'min_gap'};
Ma = zeros(numel(scs), numel(keys)); Mb = Ma;
for i = 1:numel(scs)
    [Ra(i), la] = run_episode(scs{i}, ai, cfg);
    [Rb(i), lb] = run_episode(scs{i}, bl, cfg);
    ma = compute_metrics(la, cfg); mb = compute_metrics(lb, cfg);
    ca = ca + la.collided; cb = cb + lb.collided;
    for k = 1:numel(keys)
        Ma(i, k) = ma.(keys{k}); Mb(i, k) = mb.(keys{k});
    end
    fprintf('%2d  %-15s | %6.1f/%6.1f | %5.1f/%5.1f   | %5.1f/%5.1f   | %4.2f/%4.2f  | %d/%d\n', ...
        i, scs{i}.type, Ra(i), Rb(i), ma.gap_err, mb.gap_err, ma.min_gap, mb.min_gap, ...
        ma.rms_jerk, mb.rms_jerk, la.collided, lb.collided);
end
ai_mean = mean(Ra); bl_mean = mean(Rb);
fprintf('Mean marks: AI %.1f, Baseline %.1f. Crashes: AI %d, Baseline %d.\n', ai_mean, bl_mean, ca, cb);
fprintf('Averages (AI / Baseline): gap err %.2f / %.2f m, speed RMSE %.2f / %.2f m/s, RMS accel %.2f / %.2f, RMS jerk %.2f / %.2f, worst min gap %.1f / %.1f m\n', ...
    nanmean_(Ma(:, 1)), nanmean_(Mb(:, 1)), mean(Ma(:, 2)), mean(Mb(:, 2)), mean(Ma(:, 3)), mean(Mb(:, 3)), ...
    mean(Ma(:, 4)), mean(Mb(:, 4)), min(Ma(:, 5)), min(Mb(:, 5)));
end

function m = nanmean_(x)
% average ignoring "not available" values
x = x(~isnan(x));
m = mean(x);
end
