function s = env_observe(env, cfg)
% ENV_OBSERVE  What the AI "sees" through its radar and speedometer.
%
%   s = env_observe(env, cfg)   returns a 6x1 column of numbers (the STATE)
%
% The 6 numbers are:
%   1) our speed compared with the cruise speed
%   2) relative speed  = lead speed - our speed (positive = lead pulling away)
%   3) gap distance
%   4) gap error       = gap - safe distance (negative = too close!)
%   5) our current actual acceleration (needed so the AI can be smooth)
%   6) the lead car's acceleration (is the car ahead braking right now?)
%
% Why number 6? Without it the AI sees only ONE instant. A car 100 m ahead
% that is braking hard toward a stop looks almost the same as a car
% cruising along, so the AI reacted too late (we saw it crash in the live
% demo when the lead car pressed STOP). With it, the AI can see the
% danger coming while the gap still looks big, just like you see brake
% lights. Real ACC radars measure this too.
%
% NORMALISING: neural networks learn best when inputs are small numbers,
% roughly between -1 and +1. So we divide each quantity by a typical size.
% Example: speed 20 m/s -> 20/25 - 1 = -0.2 ; gap 75 m -> 75/150 = 0.5.
%
% If the lead car is beyond radar range (150 m) the radar sees nothing:
% we report the gap as 150 m and the relative speed as 0, exactly like a
% real ACC system that has "no target".

d_safe = cfg.d0 + cfg.t_gap * env.ve;

if env.gap <= cfg.range
    gap_seen = env.gap;
    rel_seen = env.vl - env.ve;
    al_seen  = env.al;
else
    gap_seen = cfg.range;
    rel_seen = 0;
    al_seen  = 0;
end

s = [ env.ve / cfg.v_set - 1;          % about -1 .. +0.4
      rel_seen / 10;                   % about -2 .. +2
      gap_seen / cfg.range;            % 0 .. 1
      (gap_seen - d_safe) / 50;        % about -1.2 .. +3
      env.ae / 3;                      % -1 .. +0.67
      al_seen / 3 ];                   % about -1.3 .. +0.67
end
