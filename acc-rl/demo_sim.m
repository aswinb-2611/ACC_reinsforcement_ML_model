function out = demo_sim(mode, varargin)
% DEMO_SIM  Runs the two drivers live, one 0.1 s step at a time.
%
%   sc  = demo_sim('scenario', cfg)
%       A "live" lead car: starts 60 m ahead, at 22 m/s. Its speed is set
%       by you (the slider), not by a script.
%
%   sim = demo_sim('reset', sc, cfg)
%       Puts the AI car and the classic car back at the start.
%
%   sim = demo_sim('step', sim, vt, agent, cfg)
%       Moves the world forward by one step.
%       vt is the speed you have chosen for the lead car [m/s].
%
% Both drivers share ONE lead car. The lead car does not react to us, so
% both drivers see exactly the same road. That is what makes the
% comparison fair.

switch mode
    case 'scenario'
        out = live_scenario(varargin{1});
    case 'reset'
        out = reset_sim(varargin{1}, varargin{2});
    case 'step'
        out = step_sim(varargin{:});
    otherwise
        error('demo_sim: unknown mode %s', mode);
end
end

% ======================================================================
function sc = live_scenario(cfg)
% the lead car's "script" for live driving: its acceleration is filled in
% step by step from your slider, so we only need room for a long session
sc.type    = 'live';
sc.name    = 'live';
sc.ve0     = 25;                 % our starting speed [m/s] (the cruise speed)
sc.vl0     = 22;                 % the lead car's starting speed [m/s]
sc.gap0    = 60;                 % starting gap [m]
sc.cut_k   = 0;                  % no cut-in in live mode
sc.cut_gap = 0;
sc.cut_dv  = 0;
sc.al      = zeros(1, 60000);    % room for about 100 minutes of driving
end

% ======================================================================
function sim = reset_sim(sc, cfg)
% both cars start from the same place, so their starts are identical
sim.env_ai = env_reset(sc, cfg);
sim.env_bl = env_reset(sc, cfg);
sim.R_a = 0;                     % running total of marks, AI
sim.R_b = 0;                     % running total of marks, classic ACC
sim.stopped = false;             % becomes true when a crash happens
end

% ======================================================================
function sim = step_sim(sim, vt, agent, cfg)
% one 0.1 s step for both cars

env_a = sim.env_ai;
env_b = sim.env_bl;
k = env_a.k + 1;                 % the number of the step we are about to take

% ---- the lead car: accelerate or brake toward the speed you chose
% (limited to -4 and +2 m/s^2 so the lead car stays physically sensible)
a_lead = min(max((vt - env_a.vl) / 1.0, -4), 2);
env_a.sc.al(k) = a_lead;
env_b.sc.al(k) = a_lead;

% ---- the AI looks at the road and picks its pedal
s = env_observe(env_a, cfg);
q = nn_forward(agent.net, s);    % 10 Q-values, one per pedal position
[~, ia] = max(q);
a_ai = agent.actions(ia);

% ---- the classic controller uses its rule book
a_bl = baseline_acc(env_b, cfg);

% ---- move both cars one step forward
[env_a, r_a] = env_step(env_a, a_ai, cfg);
[env_b, r_b] = env_step(env_b, a_bl, cfg);

sim.env_ai = env_a;
sim.env_bl = env_b;
sim.R_a = sim.R_a + r_a;
sim.R_b = sim.R_b + r_b;
sim.stopped = env_a.collided || env_b.collided;   % stop the run after a crash
end
