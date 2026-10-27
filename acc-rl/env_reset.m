function env = env_reset(sc, cfg)
% ENV_RESET  Starts a fresh episode: puts both cars on the road.
%
%   env = env_reset(sc, cfg)
%
%   sc  : a scenario made by lead_profile()
%   cfg : settings from acc_config()
%
% The "env" struct is the complete state of the world at this moment.
% Positions are measured in metres along the road. "Gap" is the empty
% space between our front bumper and the lead car's rear bumper.

env.sc  = sc;          % the lead car's script for this episode
env.k   = 0;           % step counter (0 = start)
env.t   = 0;           % time [s]

env.xe  = 0;           % our (ego) car position [m]
env.ve  = sc.ve0;      % our speed [m/s]
env.ae  = 0;           % our ACTUAL acceleration right now [m/s^2]

env.xl  = sc.gap0;     % lead car position [m] (so the gap = gap0)
env.vl  = sc.vl0;      % lead car speed [m/s]

env.gap = env.xl - env.xe;
env.done = false;
env.collided = false;
end
