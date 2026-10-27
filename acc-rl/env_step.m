function [env, r, done, info] = env_step(env, a_cmd, cfg)
% ENV_STEP  Moves the world forward by one time step (0.1 s).
%
%   [env, r, done, info] = env_step(env, a_cmd, cfg)
%
%   a_cmd : the acceleration the driver (AI or baseline) ASKS for [m/s^2]
%   r     : the REWARD (marks) for this step
%   done  : true if the episode is over (crash, or time is up)
%   info  : extra numbers for plots and metrics
%
% Physics used (simple and standard):
%   actual accel moves toward the requested accel with a lag of tau seconds
%   v_next = v + a * dt                (speed update)
%   x_next = x + average speed * dt    (position update)

dt = cfg.dt;
env.k = env.k + 1;
k = env.k;

% ---------------- 1. Our car ----------------
a_cmd  = min(max(a_cmd, cfg.a_min), cfg.a_max);    % respect pedal limits
a_prev = env.ae;
a_new  = a_prev + (a_cmd - a_prev) * dt / cfg.tau; % engine/brake lag
v_old  = env.ve;
v_new  = min(max(v_old + a_new * dt, 0), cfg.v_max);
a_new  = (v_new - v_old) / dt;                     % real accel after speed clipping
env.xe = env.xe + 0.5 * (v_old + v_new) * dt;
env.ve = v_new;
env.ae = a_new;
jerk   = (a_new - a_prev) / dt;                    % how suddenly accel changed

% ---------------- 2. Lead car ----------------
sc = env.sc;
if sc.cut_k > 0 && k == sc.cut_k
    % CUT-IN: a new car suddenly appears in front of us
    env.xl = env.xe + sc.cut_gap;
    env.vl = max(0, env.ve - sc.cut_dv);
end
vl_old = env.vl;
vl_new = min(max(vl_old + sc.al(k) * dt, 0), cfg.vl_max);
env.xl = env.xl + 0.5 * (vl_old + vl_new) * dt;
env.vl = vl_new;
% the lead car's real acceleration this step. A real ACC radar measures
% this too (from how fast the relative speed changes). Right after a
% cut-in the radar has only just found the new car, so it reads 0.
env.al = (vl_new - vl_old) / dt;
if sc.cut_k > 0 && k == sc.cut_k
    env.al = 0;
end

% ---------------- 3. Gap and checks ----------------
env.gap = env.xl - env.xe;
env.t   = k * dt;
collided = env.gap <= 0;
env.collided = collided;
done = collided || (k >= cfg.N);
env.done = done;

% ---------------- 4. Reward ----------------
[r, parts] = acc_reward(env, jerk, cfg);

info.gap      = env.gap;
info.d_safe   = cfg.d0 + cfg.t_gap * env.ve;
info.ve       = env.ve;
info.vl       = env.vl;
info.ae       = env.ae;
info.a_cmd    = a_cmd;
info.jerk     = jerk;
info.collided = collided;
info.timeout  = (k >= cfg.N) && ~collided;   % time ran out (not a real "ending")
info.following = parts.following;
info.parts    = parts;
end
