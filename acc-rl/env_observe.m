function s = env_observe(env, cfg)
% ENV_OBSERVE  What the AI "sees" through its radar and speedometer.
%
%   s = env_observe(env, cfg)   returns a 5x1 column of numbers (the STATE)
%
% The 5 numbers are:
%   1) our speed compared with the cruise speed
%   2) relative speed  = lead speed - our speed (positive = lead pulling away)
%   3) gap distance
%   4) gap error       = gap - safe distance (negative = too close!)
%   5) our current actual acceleration (needed so the AI can be smooth)
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
else
    gap_seen = cfg.range;
    rel_seen = 0;
end

s = [ env.ve / cfg.v_set - 1;          % about -1 .. +0.4
      rel_seen / 10;                   % about -2 .. +2
      gap_seen / cfg.range;            % 0 .. 1
      (gap_seen - d_safe) / 50;        % about -1.2 .. +3
      env.ae / 3 ];                    % -1 .. +0.67
end
