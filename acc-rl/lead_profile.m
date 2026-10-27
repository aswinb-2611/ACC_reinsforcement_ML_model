function sc = lead_profile(type, setname, cfg)
% LEAD_PROFILE  Writes the "script" the lead car will follow in one episode.
%
%   sc = lead_profile(type, setname, cfg)
%
%   type    : 'constant', 'stop_and_go', 'hard_brake', 'slow_then_fast',
%             'cut_in', 'random_smooth', or 'mixed' (test only)
%   setname : 'train' or 'test'. Test scenarios use slightly different
%             number ranges and a different random seed, so the AI is
%             examined on situations it has never practised.
%   cfg     : settings from acc_config()
%
% The lead car is described by its ACCELERATION at every time step (sc.al)
% plus its starting speed. The environment then moves the lead car using
% exactly that script. A cut-in is described separately: at step sc.cut_k
% a new car appears sc.cut_gap metres in front of us, sc.cut_dv m/s slower
% than us.
%
% Random numbers come from MATLAB's rand(), so the caller sets the seed.

N  = cfg.N;
dt = cfg.dt;
is_test = strcmp(setname, 'test');

% Default: no cut-in
sc.type    = type;
sc.cut_k   = 0;
sc.cut_gap = 0;
sc.cut_dv  = 0;

% Our car's starting speed (random)
if is_test
    ve0 = urand(12, 28);
else
    ve0 = urand(5, 30);
end

switch type
    case 'constant'
        % Lead drives at one steady speed for the whole minute.
        vl0 = pick(is_test, [12 28], [8 30]);
        vt  = vl0 * ones(1, N);
        [al, vl0] = track_targets(vt, vl0, 1.0, 1.0, dt, cfg);

    case 'stop_and_go'
        % Traffic jam: lead speeds up, slows to a crawl (or stops), repeats.
        v_hi = pick(is_test, [10 20], [8 22]);
        v_lo = pick(is_test, [0 4],   [0 5]);
        vt = zeros(1, N);
        k = 1; high = true;
        while k <= N
            if high
                len = round(urand(6, 12) / dt);  vt(k:min(N, k+len-1)) = v_hi;
            else
                len = round(urand(4, 9) / dt);   vt(k:min(N, k+len-1)) = v_lo;
            end
            k = k + len; high = ~high;
        end
        a_up = pick(is_test, [0.8 1.5], [0.8 1.8]);
        a_dn = pick(is_test, [1.5 2.5], [1.2 2.8]);
        [al, vl0] = track_targets(vt, v_hi, a_up, a_dn, dt, cfg);

    case 'hard_brake'
        % Lead cruises, then suddenly brakes hard, waits, then speeds up again.
        v0    = pick(is_test, [18 26], [15 28]);
        v_end = pick(is_test, [0 10],  [0 12]);
        b     = pick(is_test, [3.0 4.0], [2.5 4.0]);    % braking strength
        t_b   = pick(is_test, [12 35], [8 40]);         % when the brake happens
        hold  = urand(3, 8);
        vt = v0 * ones(1, N);
        k1 = round(t_b / dt); k2 = min(N, k1 + round(hold / dt));
        % the braking part (target drops instantly, lead brakes at b m/s^2)
        vt(k1:k2) = v_end;
        [al, vl0] = track_targets(vt, v0, 1.5, b, dt, cfg);

    case 'slow_then_fast'
        % Lead starts slow, later speeds up (often faster than our cruise speed,
        % so the road ahead "opens up" and we should return to cruising).
        v_slow = pick(is_test, [8 15],  [6 16]);
        v_fast = pick(is_test, [24 32], [20 33]);
        t_s    = pick(is_test, [15 35], [10 40]);
        a_up   = pick(is_test, [1.0 2.0], [0.8 2.0]);
        vt = v_slow * ones(1, N);
        vt(round(t_s / dt):end) = v_fast;
        [al, vl0] = track_targets(vt, v_slow, a_up, 2.0, dt, cfg);

    case 'cut_in'
        % The original lead is far ahead; then another car suddenly squeezes
        % in between, close to us and a bit slower.
        vl0 = pick(is_test, [18 30], [15 32]);
        vt  = vl0 * ones(1, N);
        [al, vl0] = track_targets(vt, vl0, 1.0, 1.0, dt, cfg);
        sc.cut_k   = round(pick(is_test, [12 40], [8 45]) / dt);
        sc.cut_gap = pick(is_test, [12 25], [10 30]);
        sc.cut_dv  = pick(is_test, [0 4],   [0 5]);
        % after the cut-in, the new car keeps its speed, then gently
        % changes speed a little (so it is not perfectly boring)
        al(sc.cut_k:end) = 0;
        k3 = min(N, sc.cut_k + round(urand(5, 10) / dt));
        k4 = min(N, k3 + round(4 / dt));
        al(k3:k4) = urand(-0.5, 0.8);

    case 'random_smooth'
        % A random but smooth speed plan: new target speed every 8 to 15 s.
        [al, vl0] = random_waypoints(is_test, dt, cfg);

    case 'live_like'
        % Like a person playing with the live demo's speed slider: a new
        % target speed every 4 to 12 s. Sometimes faster than our cruise
        % speed, sometimes a full stop. The lead speeds up at up to 2 m/s^2,
        % exactly like the demo's lead car.
        vt = zeros(1, N);
        k = 1;
        while k <= N
            len = round(urand(4, 12) / dt);
            r = rand();
            if r < 0.25
                v_t = urand(26, 34);           % faster than our cruise speed
            elseif r < 0.40
                v_t = urand(0, 3);             % (almost) a full stop
            else
                v_t = urand(5, 25);
            end
            vt(k:min(N, k + len - 1)) = v_t;
            k = k + len;
        end
        a_dn = pick(is_test, [3.0 3.5], [2.5 3.5]);
        [al, vl0] = track_targets(vt, vt(1), 2.0, a_dn, dt, cfg);

    case 'mixed'
        % TEST ONLY: a random drive that ALSO contains a hard brake and a
        % cut-in. The AI never trained on this combination.
        [al, vl0] = random_waypoints(true, dt, cfg);
        kb = round(urand(30, 40) / dt);
        kb2 = min(N, kb + round(urand(2, 3.5) / dt));
        al(kb:kb2) = -3.5;                 % hard brake burst
        sc.cut_k   = round(urand(10, 22) / dt);
        sc.cut_gap = urand(14, 25);
        sc.cut_dv  = urand(0, 3);

    otherwise
        error('Unknown scenario type: %s', type);
end

sc.al  = al;
sc.vl0 = vl0;
sc.ve0 = ve0;

% Starting gap: random, but never physically impossible.
% We need room to brake from our speed down to the lead's speed at about
% 2 m/s^2, plus a little reaction distance and a 5 m cushion.
closing = max(0, ve0 - vl0);
gap_min = 5 + closing^2 / (2 * 2.0) + 0.5 * ve0;
if strcmp(type, 'cut_in')
    gap0 = urand(90, 170);       % original lead is far away (maybe out of radar range)
else
    gap0 = urand(gap_min, max(gap_min + 10, 130));
end
sc.gap0 = max(gap0, gap_min);
sc.name = type;
end

% ======================================================================
% Helper functions (only used inside this file)
% ======================================================================
function x = urand(a, b)
% uniform random number between a and b
x = a + (b - a) * rand();
end

function x = pick(is_test, test_range, train_range)
% choose a random number from the test range or the train range
if is_test
    x = urand(test_range(1), test_range(2));
else
    x = urand(train_range(1), train_range(2));
end
end

function [al, vl0] = random_waypoints(is_test, dt, cfg)
% random target speeds, held for 8 to 15 seconds each
N = cfg.N;
vt = zeros(1, N);
k = 1;
while k <= N
    len = round(urand(8, 15) / dt);
    if is_test
        vt(k:min(N, k + len - 1)) = urand(6, 30);
    else
        vt(k:min(N, k + len - 1)) = urand(3, 32);
    end
    k = k + len;
end
[al, vl0] = track_targets(vt, vt(1), urand(0.8, 1.6), urand(1.0, 2.5), dt, cfg);
end

function [al, v0] = track_targets(vt, v0, a_up, a_dn, dt, cfg)
% Turns a list of target speeds into a smooth acceleration script.
% The lead "driver" moves toward the target speed, but never faster than
% a_up (speeding up) or a_dn (braking).
N = numel(vt);
al = zeros(1, N);
v = v0;
for k = 1:N
    a = (vt(k) - v) / 1.0;                 % aim to close the speed error in ~1 s
    a = min(max(a, -a_dn), a_up);          % respect the limits
    v_new = min(max(v + a * dt, 0), cfg.vl_max);
    al(k) = (v_new - v) / dt;              % the acceleration actually used
    v = v_new;
end
end
