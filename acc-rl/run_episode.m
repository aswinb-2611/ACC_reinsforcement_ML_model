function [R, log] = run_episode(sc, ctrl, cfg)
% RUN_EPISODE  Drives one full episode with a given driver and records it.
%
%   [R, log] = run_episode(sc, ctrl, cfg)
%
%   ctrl.type = 'rl'       -> uses the trained network ctrl.net (greedy, no exploring)
%                             and its list of accelerations ctrl.actions
%   ctrl.type = 'baseline' -> uses baseline_acc with optional ctrl.gains
%
%   R   : total reward (sum of all step marks)
%   log : time histories (speed, gap, accel...) for plots and metrics

env = env_reset(sc, cfg);
N = cfg.N;
log.t = zeros(1, N); log.ve = zeros(1, N); log.vl = zeros(1, N);
log.gap = zeros(1, N); log.d_safe = zeros(1, N); log.ae = zeros(1, N);
log.jerk = zeros(1, N); log.following = false(1, N); log.r = zeros(1, N);
log.xe = zeros(1, N); log.xl = zeros(1, N); log.a_cmd = zeros(1, N);
R = 0;
n = 0;
if ~isfield(ctrl, 'gains'), ctrl.gains = []; end
if ~isfield(ctrl, 'actions'), ctrl.actions = cfg.actions; end

while ~env.done
    if strcmp(ctrl.type, 'rl')
        s = env_observe(env, cfg);
        s = s(1:size(ctrl.net.W1, 2));         % brains before run 9 saw only the first 5 numbers
        q = nn_forward(ctrl.net, s);           % Q-value for each action
        [~, ia] = max(q);                      % pick the best one
        a_cmd = ctrl.actions(ia);
    else
        a_cmd = baseline_acc(env, cfg, ctrl.gains);
    end
    [env, r, ~, info] = env_step(env, a_cmd, cfg);
    R = R + r;
    n = n + 1;
    log.t(n) = env.t;       log.ve(n) = info.ve;     log.vl(n) = info.vl;
    log.gap(n) = info.gap;  log.d_safe(n) = info.d_safe;
    log.ae(n) = info.ae;    log.jerk(n) = info.jerk;
    log.following(n) = info.following;  log.r(n) = r;
    log.xe(n) = env.xe;     log.xl(n) = env.xl;     log.a_cmd(n) = a_cmd;
end

% trim unused slots (only matters if the episode ended early by a crash)
f = fieldnames(log);
for i = 1:numel(f)
    log.(f{i}) = log.(f{i})(1:n);
end
log.collided = env.collided;
log.name = sc.name;
end
