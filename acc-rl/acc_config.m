function cfg = acc_config()
% ACC_CONFIG  All the project settings live here, in one place.
%
% Think of this file as the "rule book" of our little world. Every other
% file asks this function for its numbers, so if you want to change, say,
% the cruising speed, you change it here once and everything follows.
%
% Usage:  cfg = acc_config();

% ---------------- Time ----------------
cfg.dt      = 0.1;            % one simulation step = 0.1 seconds
cfg.T       = 60;             % one episode lasts 60 seconds
cfg.N       = round(cfg.T / cfg.dt);   % so an episode has 600 steps

% ---------------- Ego car (our car) ----------------
cfg.v_max   = 35;             % top speed allowed [m/s] (35 m/s = 126 km/h)
cfg.a_min   = -3.0;           % strongest braking allowed [m/s^2]
cfg.a_max   = 2.0;            % strongest acceleration allowed [m/s^2]
cfg.tau     = 0.3;            % engine/brake lag [s]: a real car needs a moment
                              % to reach the acceleration the driver asks for.
                              % Used identically for the AI and the baseline.

% ---------------- Driving targets ----------------
cfg.v_set   = 25;             % cruise speed the driver has chosen [m/s] (90 km/h)
cfg.d0      = 5;              % gap we want even when standing still [m]
cfg.t_gap   = 1.5;            % time gap [s]: stay 1.5 seconds behind the lead
                              % safe distance d_safe = d0 + t_gap * v
cfg.range   = 150;            % radar range [m]: beyond this the road "looks clear"

% ---------------- Lead car ----------------
cfg.vl_max  = 40;             % lead car speed is kept between 0 and 40 m/s

% ---------------- AI actions ----------------
% The AI picks ONE of these accelerations every 0.1 s (a "discrete" choice,
% like a gear lever with fixed positions instead of a smooth pedal).
cfg.actions = [-3, -2, -1, -0.5, -0.25, 0, 0.25, 0.5, 1, 2];
cfg.nA      = numel(cfg.actions);
cfg.nS      = 5;              % the AI sees 5 numbers (the "state"), see env_observe.m

% ---------------- Reward weights (the marking scheme) ----------------
cfg.rw.w_speed_follow = 0.3;  % when following: small share of marks for speed
cfg.rw.w_gap_follow   = 0.7;  % when following: big share for a good gap
cfg.rw.gap_width      = 0.25; % how strict "near d_safe" is (fraction of d_safe)
cfg.rw.k_close        = 2.0;  % penalty for being closer than d_safe
cfg.rw.k_danger       = 3.0;  % extra penalty for being closer than half d_safe
cfg.rw.ttc_limit      = 4.0;  % time-to-collision below this [s] is "risky"
cfg.rw.k_ttc          = 1.0;  % penalty weight for risky time-to-collision
cfg.rw.brake_limit    = 1.5;  % braking NEEDED to avoid a crash above this [m/s^2] is risky
cfg.rw.k_brake        = 1.0;  % penalty weight for "you will soon need hard braking"
cfg.rw.k_acc          = 0.05; % comfort: penalty for strong acceleration
cfg.rw.k_jerk         = 0.20; % comfort: penalty for jerk (sudden pedal changes)
cfg.rw.collision      = -100; % very large penalty for a crash

% ---------------- Reproducibility ----------------
cfg.seed_train = 1;           % random seed for training
cfg.seed_val   = 777;         % seed for the validation scenarios
cfg.seed_test  = 2024;        % seed for the UNSEEN test scenarios (never trained on)

% ---------------- Paths ----------------
here = fileparts(mfilename('fullpath'));
cfg.root        = here;
cfg.results_dir = fullfile(here, 'results');
cfg.model_file  = fullfile(here, 'trained_agent.mat');
cfg.test_file   = fullfile(here, 'test_scenarios.mat');
end
