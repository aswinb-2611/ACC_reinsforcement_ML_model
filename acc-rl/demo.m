function demo(scenario_type, which, save_gif)
% DEMO  Animated top-down view: AI driver vs. conventional ACC, side by side.
%
%   demo()                         % default: an unseen hard-brake test
%   demo('cut_in')                 % choose a scenario family
%   demo('mixed', 3)               % the 3rd unseen 'mixed' test episode
%   demo('stop_and_go', 1, true)   % also save an animated GIF in results/
%
% Families: 'constant', 'stop_and_go', 'hard_brake', 'slow_then_fast',
%           'cut_in', 'random_smooth', 'mixed'
%
% Top    : two roads. Upper road = AI (blue car), lower road = baseline
%          (red car). The grey car is the lead car, doing EXACTLY the same
%          thing on both roads. The green strip is the safe distance d_safe.
%          The camera follows our car, so the road markings slide past.
% Bottom : live graphs of speed, gap and acceleration for both drivers.
%
% Uses only trained_agent.mat and test_scenarios.mat, no training needed.

if nargin < 1 || isempty(scenario_type), scenario_type = 'hard_brake'; end
if nargin < 2 || isempty(which), which = 1; end
if nargin < 3, save_gif = false; end

cfg = acc_config();
S = load(cfg.model_file);
agent = S.agent;
if exist(cfg.test_file, 'file')
    T = load(cfg.test_file); test_scs = T.test_scs;
else
    test_scs = make_scenarios('test', 15, cfg.seed_test, cfg);
    save(cfg.test_file, 'test_scs', '-v7');
end
idx = [];
for i = 1:numel(test_scs)
    if strcmp(test_scs{i}.type, scenario_type), idx(end + 1) = i; end %#ok<AGROW>
end
if isempty(idx), error('Unknown scenario family: %s', scenario_type); end
sc = test_scs{idx(min(which, numel(idx)))};

% Drive both controllers first (fast), then play the recording as a movie.
ai.type = 'rl'; ai.net = agent.net; ai.actions = agent.actions;
bl.type = 'baseline';
[~, la] = run_episode(sc, ai, cfg);
[~, lb] = run_episode(sc, bl, cfg);
n = min(numel(la.t), numel(lb.t));

show = can_show_figures();
if show
    fig = figure('Name', 'ACC demo: AI vs Baseline', 'Color', 'w', 'Position', [60 60 1150 720]);
else
    fig = figure('visible', 'off', 'Color', 'w', 'Position', [60 60 1150 720]);
end

% ---------------- road panels ----------------
view_x = [-25 125];                        % metres shown around our car
car_L = 4.5; car_W = 1.8;
axA = axes('Position', [0.05 0.79 0.92 0.14]);
[hA, tA] = draw_road(axA, view_x, [0.15 0.35 0.9]);
axB = axes('Position', [0.05 0.58 0.92 0.14]);
[hB, tB] = draw_road(axB, view_x, [0.9 0.25 0.25]);

% ---------------- live graphs ----------------
ax1 = axes('Position', [0.05 0.08 0.27 0.40]); hold(ax1, 'on'); grid(ax1, 'on');
g1l = plot(ax1, nan, nan, 'k:', 'LineWidth', 1.2);
g1a = plot(ax1, nan, nan, 'b', 'LineWidth', 1.6);
g1b = plot(ax1, nan, nan, 'r--', 'LineWidth', 1.6);
plot(ax1, [0 cfg.T], [cfg.v_set cfg.v_set], 'Color', [0.6 0.6 0.6]);
xlim(ax1, [0 cfg.T]); ylim(ax1, [0 35]);
title(ax1, 'speed [m/s]'); xlabel(ax1, 'time [s]');
legend(ax1, {'lead', 'AI', 'Baseline', 'cruise'}, 'Location', 'southwest');

ax2 = axes('Position', [0.38 0.08 0.27 0.40]); hold(ax2, 'on'); grid(ax2, 'on');
g2a = plot(ax2, nan, nan, 'b', 'LineWidth', 1.6);
g2b = plot(ax2, nan, nan, 'r--', 'LineWidth', 1.6);
g2s = plot(ax2, nan, nan, 'b:', 'LineWidth', 1.0);
xlim(ax2, [0 cfg.T]); ylim(ax2, [0 cfg.range]);
title(ax2, 'gap [m]  (dotted = AI safe distance)'); xlabel(ax2, 'time [s]');
legend(ax2, {'AI', 'Baseline', 'd\_safe'}, 'Location', 'northeast');

ax3 = axes('Position', [0.71 0.08 0.27 0.40]); hold(ax3, 'on'); grid(ax3, 'on');
g3a = plot(ax3, nan, nan, 'b', 'LineWidth', 1.4);
g3b = plot(ax3, nan, nan, 'r--', 'LineWidth', 1.4);
xlim(ax3, [0 cfg.T]); ylim(ax3, [-3.5 2.5]);
title(ax3, 'acceleration [m/s^2]'); xlabel(ax3, 'time [s]');
legend(ax3, {'AI', 'Baseline'}, 'Location', 'southwest');

% ---------------- play ----------------
stride = 2;                     % draw every 2nd step (0.2 s) to stay smooth
if save_gif && ~show, stride = 5; end
frames = {};
for k = 1:stride:n
    hA = update_road(hA, tA, la, k, 'AI (DQN)', car_L, car_W, view_x, cfg);
    hB = update_road(hB, tB, lb, k, 'Baseline PD', car_L, car_W, view_x, cfg);
    set(g1l, 'XData', la.t(1:k), 'YData', la.vl(1:k));
    set(g1a, 'XData', la.t(1:k), 'YData', la.ve(1:k));
    set(g1b, 'XData', lb.t(1:k), 'YData', lb.ve(1:k));
    set(g2a, 'XData', la.t(1:k), 'YData', min(la.gap(1:k), cfg.range));
    set(g2b, 'XData', lb.t(1:k), 'YData', min(lb.gap(1:k), cfg.range));
    set(g2s, 'XData', la.t(1:k), 'YData', la.d_safe(1:k));
    set(g3a, 'XData', la.t(1:k), 'YData', la.ae(1:k));
    set(g3b, 'XData', lb.t(1:k), 'YData', lb.ae(1:k));
    drawnow;
    if save_gif, frames{end + 1} = grab_frame(fig); end %#ok<AGROW>
    if show, pause(0.02); end
end

fprintf('Demo "%s": AI min gap %.1f m, Baseline min gap %.1f m, AI crashed: %d, Baseline crashed: %d\n', ...
        scenario_type, min(la.gap), min(lb.gap), la.collided, lb.collided);

if save_gif && ~isempty(frames)
    gif = fullfile(cfg.results_dir, ['demo_', scenario_type, '.gif']);
    write_gif(frames, gif, 0.1 * stride);
    fprintf('Saved animation to %s\n', gif);
end
if ~show, close(fig); end
end

% ======================================================================
function [h, t] = draw_road(ax, view_x, car_color)
axes(ax); cla(ax); hold(ax, 'on');
fill([view_x(1) view_x(2) view_x(2) view_x(1)], [-3 -3 3 3], [0.35 0.35 0.38], 'EdgeColor', 'none');
plot(view_x, [-3 -3], 'w', 'LineWidth', 2);
plot(view_x, [3 3], 'w', 'LineWidth', 2);
h.dash  = plot(nan, nan, 'w', 'LineWidth', 2);                       % moving road marks
h.dyn   = [];                                   % moving shapes, redrawn every frame
h.color = car_color;
h.arrow = text(view_x(2) - 2, 0, '', 'HorizontalAlignment', 'right', 'Color', 'w', 'FontWeight', 'bold');
set(ax, 'XLim', view_x, 'YLim', [-3.5 3.5], 'YTick', [], 'Box', 'on');
xlabel(ax, 'distance ahead of our car [m]');
t = title(ax, '');
end

function h = update_road(h, t, lg, k, label, L, W, view_x, cfg)
% our car: front bumper at x = 0 ; lead car: rear bumper at x = gap
% The moving shapes are deleted and drawn fresh each frame (this works the
% same in MATLAB and in Octave).
off = mod(lg.xe(k), 12);
xs = (view_x(1):12:view_x(2) + 12) - off;
X = [xs; xs + 5; nan(size(xs))];
Y = zeros(size(X)); Y(3, :) = nan;
set(h.dash, 'XData', X(:), 'YData', Y(:));
if ~isempty(h.dyn), delete(h.dyn(ishandle(h.dyn))); end
ax = get(h.dash, 'Parent');
ds = lg.d_safe(k);
g = lg.gap(k);
h.dyn = fill([0 ds ds 0], [-1.6 -1.6 1.6 1.6], [0.55 0.85 0.55], 'EdgeColor', 'none', 'Parent', ax);
h.dyn(2) = fill([-L 0 0 -L], [-W -W W W] / 2, h.color, 'EdgeColor', 'k', 'Parent', ax);
if g < view_x(2) - 2
    h.dyn(3) = fill([g g + L g + L g], [-W -W W W] / 2, [0.75 0.75 0.75], 'EdgeColor', 'k', 'Parent', ax);
    set(h.arrow, 'String', '');
else
    if g > cfg.range
        set(h.arrow, 'String', 'road clear (no car within radar range)  >>');
    else
        set(h.arrow, 'String', sprintf('lead car %.0f m ahead  >>', g));
    end
end
state = 'ok';
if g < 0.5 * ds, state = 'TOO CLOSE'; end
if g <= 0, state = 'CRASH'; end
set(t, 'String', sprintf('%s   t = %4.1f s   speed %5.1f m/s   gap %6.1f m   safe gap %5.1f m   accel %+5.2f   [%s]', ...
    label, lg.t(k), lg.ve(k), min(g, 999), ds, lg.ae(k), state));
end

function img = grab_frame(fig)
% MATLAB: getframe. Octave without a screen: print to a temporary PNG.
try
    fr = getframe(fig);
    img = fr.cdata;
catch
    tmp = [tempname(), '.png'];
    print(fig, '-dpng', '-r60', tmp);
    img = imread(tmp);
    delete(tmp);
end
end

function write_gif(frames, file, delay)
% GIF files store at most 256 colours, so each frame is mapped to a fixed
% palette of 6 x 6 x 6 = 216 colours (done by hand, works in MATLAB and Octave).
lv = (0:5)' / 5;
[R, G, B] = ndgrid(lv, lv, lv);
map = [R(:), G(:), B(:)];
for i = 1:numel(frames)
    q = round(double(frames{i}) / 255 * 5);          % each channel -> 0..5
    A = uint8(q(:, :, 1) + 6 * q(:, :, 2) + 36 * q(:, :, 3));
    if i == 1
        imwrite(A, map, file, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
    else
        imwrite(A, map, file, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
    end
end
end
