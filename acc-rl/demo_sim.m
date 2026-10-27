function out = demo_sim(mode, varargin)
% DEMO_SIM  Runs the drivers live, one 0.1 s step at a time.
%
%   sc  = demo_sim('scenario', cfg)
%       A "live" lead car: starts 60 m ahead, at 22 m/s. Its speed is set
%       by you (slider, buttons or arrow keys), not by a script.
%
%   sim = demo_sim('reset', sc, cfg)
%       Puts every car back at the start.
%
%   sim = demo_sim('step', sim, vt, agent, cfg)
%       Moves the world forward by one step. vt = the speed you chose [m/s].
%
% Both drivers (AI and classic ACC) follow their own copy of the same lead
% car, so they always face exactly the same situation.
%
% EMERGENCY BRAKING (AEB): real cars have two separate systems.
%   ACC (adaptive cruise control) is for comfort: it may brake at most
%   3 m/s^2. That is what the AI and the classic controller do.
%   AEB (automatic emergency braking) only wakes up when a crash is about
%   to happen, and may brake much harder (here 7 m/s^2).
% In this live demo you can brake the lead car harder than ACC is allowed
% to brake, so, just like a real car, our car has AEB as a safety net. The
% screen counts how often each driver needed it: a good driver needs it
% rarely or never. (The exam in evaluate.m does NOT use AEB: there the AI
% has to manage on its own.)

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
function sc = live_scenario(cfg) %#ok<INUSD>
% the lead car's "script" for live driving: its acceleration is filled in
% step by step from your controls, so we only need room for a long session
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
sim.env_ai = env_reset(sc, cfg);
sim.env_bl = env_reset(sc, cfg);
sim.R_a = 0;                     % running total of marks, AI
sim.R_b = 0;                     % running total of marks, classic ACC
sim.aeb_a = false;               % is emergency braking active right now?
sim.aeb_b = false;
sim.n_aeb_a = 0;                 % how many times it was needed
sim.n_aeb_b = 0;
sim.stopped = false;             % becomes true if a crash happens
end

% ======================================================================
function sim = step_sim(sim, vt, agent, cfg)
% one 0.1 s step for every car

env_a = sim.env_ai;
env_b = sim.env_bl;
k = env_a.k + 1;                 % the number of the step we are about to take

% ---- the lead car: speed up or brake toward the speed you chose.
% It can speed up at 2 m/s^2 and brake at up to 4 m/s^2, a firm stop that
% is harder than ACC alone may brake (3 m/s^2).
a_lead = min(max((vt - env_a.vl) / 1.0, -4), 2);
env_a.sc.al(k) = a_lead;
env_b.sc.al(k) = a_lead;

% ---- the AI looks at the road and picks its pedal
s = env_observe(env_a, cfg);
s = s(1:size(agent.net.W1, 2));  % brains before run 9 saw only the first 5 numbers
q = nn_forward(agent.net, s);    % 10 Q-values, one per pedal position
[~, ia] = max(q);
a_ai = agent.actions(ia);

% ---- the classic controller uses its rule book
a_bl = baseline_acc(env_b, cfg);

% ---- emergency braking checks (can override both drivers)
[a_ai, on_a] = aeb(env_a, a_ai, sim.aeb_a, cfg);
[a_bl, on_b] = aeb(env_b, a_bl, sim.aeb_b, cfg);
sim.n_aeb_a = sim.n_aeb_a + (on_a && ~sim.aeb_a);   % count each new emergency
sim.n_aeb_b = sim.n_aeb_b + (on_b && ~sim.aeb_b);
sim.aeb_a = on_a;
sim.aeb_b = on_b;

% ---- move the cars. While AEB is on, the car may brake harder than ACC.
cfg_aeb = cfg;
cfg_aeb.a_min = -7;
[env_a, r_a] = env_step(env_a, a_ai, cfg_aeb);
if env_b.collided
    % the classic car already crashed: it stays frozen where it crashed
    r_b = 0;
else
    [env_b, r_b] = env_step(env_b, a_bl, cfg_aeb);
end

sim.env_ai = env_a;
sim.env_bl = env_b;
sim.R_a = sim.R_a + r_a;
sim.R_b = sim.R_b + r_b;
sim.stopped = env_a.collided;            % the drive stops if the AI crashes
end

% ======================================================================
function [a, on] = aeb(env, a_cmd, was_on, cfg)
% Automatic emergency braking. It looks at how hard we would have to brake
% to avoid hitting the car in front (school physics: v^2 = 2*a*s):
%     braking needed = closing speed^2 / (2 * (gap - 2 m))
% If that is more than ACC can do (about 3 m/s^2), or a crash is less than
% 1.5 s away, AEB brakes at 7 m/s^2. It lets go again once the danger is
% clearly over.
gap = env.xl - env.xe;
closing = env.ve - env.vl;                   % > 0 means we are getting closer
if gap > cfg.range || closing <= 0
    need = 0;  ttc = inf;
else
    need = closing ^ 2 / (2 * max(gap - 2, 0.1));
    ttc  = gap / closing;
end
if was_on
    on = ~((need < 1.2 && ttc > 3) || closing <= 0.2);
else
    on = need > 2.8 || (ttc < 1.5 && closing > 1);
end
if on
    a = -7;
else
    a = a_cmd;
end
end
