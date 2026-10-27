function [r, p] = acc_reward(env, jerk, cfg)
% ACC_REWARD  The "marking scheme": how many points one 0.1 s step earns.
%
%   [r, p] = acc_reward(env, jerk, cfg)
%
% Good driving earns up to about +1 point per step. Bad driving loses points.
% A crash costs -100 points and ends the episode.
%
% Two situations:
%   FOLLOWING : a lead car is within radar range AND (it is not faster than
%               our cruise speed, OR it is closer than the safe distance).
%               Then the job is "sit at the safe distance".
%               (The second part closes a loophole found during tuning: a
%               car that cut in slightly faster than our cruise speed used to
%               count as "free road", so tailgating it was almost free.)
%   FREE ROAD : nobody (or only a faster car) ahead. Then the job is
%               "drive at the cruise speed".
%
% Small numeric example (cruise speed 25 m/s, our speed 20 m/s, lead 20 m/s):
%   safe distance = 5 + 1.5*20 = 35 m, bell width = 0.25*35 = 8.75 m.
%   If gap = 35 m the gap score is 1.0, if gap = 44 m it is about
%   exp(-0.5*(9/8.75)^2) = 0.59. Being too close costs extra.

rw = cfg.rw;
v  = env.ve;
d_safe = cfg.d0 + cfg.t_gap * v;
gap = env.gap;
in_range = gap <= cfg.range;
p.following = in_range && (env.vl <= cfg.v_set || gap < d_safe);

% --- speed score: 1 at cruise speed, falls to 0 at 15 m/s away from it
f_speed = max(0, 1 - abs(v - cfg.v_set) / 15);

% --- gap score: 1 exactly at d_safe, a bell curve around it
width = rw.gap_width * d_safe;
f_gap = exp(-0.5 * ((gap - d_safe) / width)^2);

if p.following
    % Blend by distance: far behind (2 x d_safe or more) the job is simply
    % "cruise", exactly like free road. Closer in, the job becomes "hold
    % the gap". Without this blend, a car starting far behind got almost
    % no marks for catching up (a "sparse reward") and learned to dawdle.
    % Example: d_safe = 40 m, gap = 60 m -> w_far = 0.5 (half and half).
    w_far = min(max((gap - d_safe) / d_safe, 0), 1);
    near  = rw.w_speed_follow * f_speed + rw.w_gap_follow * f_gap;
    p.task = w_far * f_speed + (1 - w_far) * near;
else
    p.task = f_speed;
end

% --- safety penalties
p.close = 0; p.danger = 0; p.ttc = 0; p.brake = 0;
if in_range && gap < d_safe
    p.close = rw.k_close * ((d_safe - gap) / d_safe)^2;       % gently too close
end
if in_range && gap < 0.5 * d_safe
    p.danger = rw.k_danger * (0.5 - gap / d_safe) / 0.5;      % dangerously close
end
closing_speed = v - env.vl;                                   % >0 means we approach
if in_range && closing_speed > 0
    ttc = gap / closing_speed;                                % time to collision [s]
    if ttc < rw.ttc_limit
        p.ttc = rw.k_ttc * (rw.ttc_limit - ttc) / rw.ttc_limit;
    end
    % "Braking needed": to stop closing in before the gap is used up, we
    % need a deceleration of  closing_speed^2 / (2 * gap)  (school physics,
    % v^2 = 2*a*s). Example: closing at 18 m/s with 73 m left needs
    % 18^2/(2*73) = 2.2 m/s^2, close to our 3 m/s^2 limit, so it is risky.
    % This warns EARLY at high closing speeds, when the gap still looks big.
    a_need = closing_speed^2 / (2 * max(gap, 0.1));
    if a_need > rw.brake_limit
        p.brake = min(3, rw.k_brake * (a_need - rw.brake_limit));   % capped at 3
    end
end

% --- comfort penalties (passengers hate harsh pedals)
p.acc  = rw.k_acc  * (env.ae / 3)^2;
% Jerk is SQUARED, like the RMS-jerk metric we report. (We also tried the
% absolute value |jerk|: it made big lurches cheaper, so the AI swapped
% small wiggles for fewer big ones and RMS jerk got worse. Lesson: give
% the penalty the same shape as the metric you care about.)
p.jerk = rw.k_jerk * (jerk / 5)^2;

r = p.task - p.close - p.danger - p.ttc - p.brake - p.acc - p.jerk;

% --- crash
if gap <= 0
    r = rw.collision;
end
end
