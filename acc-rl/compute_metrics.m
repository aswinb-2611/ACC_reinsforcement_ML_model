function m = compute_metrics(lg, cfg)
% COMPUTE_METRICS  Turns one episode's recording into report-card numbers.
%
%   m = compute_metrics(log, cfg)
%
% Definitions (the same for the AI and the baseline):
%   following steps : a car is within radar range AND (not faster than our
%                     cruise speed OR closer than d_safe), so "follow at the
%                     safe distance" is the job (same rule as acc_reward.m)
%   avg_gap   : average gap during following steps [m]
%   avg_dsafe : average safe distance during following steps [m] (for reference)
%   gap_err   : average |gap - d_safe| during following steps [m]
%   speed_rmse: root-mean-square of (our speed - correct speed) [m/s], where
%               correct speed = lead speed when following, cruise speed otherwise
%   collided  : 1 if the episode ended in a crash
%   rms_acc   : root-mean-square acceleration [m/s^2] (comfort)
%   rms_jerk  : root-mean-square jerk [m/s^3] (comfort: sudden pedal changes)
%   min_gap   : smallest gap reached in the episode [m] (safety)
%   ret       : total reward for the episode
%
% "Root-mean-square" (RMS) = square every value, average them, take the
% square root. It is a fair "typical size" that punishes big values more.

f = lg.following;
if any(f)
    m.avg_gap   = mean(lg.gap(f));
    m.avg_dsafe = mean(lg.d_safe(f));
    m.gap_err   = mean(abs(lg.gap(f) - lg.d_safe(f)));
else
    m.avg_gap = NaN; m.avg_dsafe = NaN; m.gap_err = NaN;
end
v_ref = cfg.v_set * ones(size(lg.ve));
v_ref(f) = min(cfg.v_set, lg.vl(f));
m.speed_rmse = sqrt(mean((lg.ve - v_ref) .^ 2));
m.collided   = double(lg.collided);
m.rms_acc    = sqrt(mean(lg.ae .^ 2));
m.rms_jerk   = sqrt(mean(lg.jerk .^ 2));
m.min_gap    = min(lg.gap);
m.ret        = sum(lg.r);
end
