function a = baseline_acc(env, cfg, gains)
% BASELINE_ACC  A conventional (non-AI) Adaptive Cruise Controller.
%
%   a = baseline_acc(env, cfg)          uses the tuned default gains
%   a = baseline_acc(env, cfg, gains)   gains = [kp kd kv e_max ka]
%
% This is the "rule book driver" used in real cars for years: the
% CONSTANT TIME-GAP controller, a PD (proportional-derivative) law.
%
%   Follow mode :  a_follow = kp * e + kd * (lead speed - our speed) + ka * (lead accel)
%                  where e = gap - d_safe, capped at e_max ("saturation")
%                  "too close -> brake, closing in -> brake, pulling away -> go"
%   Cruise mode :  a_cruise = kv * (set speed - our speed)
%                  "below cruise speed -> accelerate"
%   Final       :  a = min(a_cruise, a_follow)  (obey whichever is more careful)
%                  then clip to [-3, +2] m/s^2, the same limits as the AI.
%
% Why cap e at e_max? Without it, a big gap (say +50 m) "cancels" a fast
% closing speed and the controller brakes far too late when a distant car
% brakes hard. Capping the spacing error is standard engineering practice
% and makes the baseline a stronger, fairer opponent.
%
% The default gains were found by tune_baseline.m: a fair grid search on
% the TRAINING scenarios, scored with the SAME reward the AI is trained on.

if nargin < 3 || isempty(gains)
    gains = [0.36, 0.56, 1.5625, 20, 0.30];  % [kp kd kv e_max ka] from tune_baseline.m (run 9)
end
kp = gains(1); kd = gains(2); kv = gains(3); e_max = gains(4);
ka = 0;
if numel(gains) >= 5, ka = gains(5); end

v = env.ve;
d_safe = cfg.d0 + cfg.t_gap * v;

a_cruise = kv * (cfg.v_set - v);
if env.gap <= cfg.range                      % radar sees a car ahead
    e = min(env.gap - d_safe, e_max);         % spacing error, capped
    % ka * (lead acceleration) is "feed-forward": if the car ahead brakes,
    % we start braking with it at once, before the gap has shrunk.
    a_follow = kp * e + kd * (env.vl - v) + ka * env.al;
    a = min(a_cruise, a_follow);
else                                         % road ahead is clear
    a = a_cruise;
end
a = min(max(a, cfg.a_min), cfg.a_max);
end
