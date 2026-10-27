function out = demo_graphs(mode, varargin)
% DEMO_GRAPHS  The three small graphs under the 3D scene: speed, gap, accel.
%
%   G = demo_graphs('build', gx, cfg)          creates the empty graphs once
%   demo_graphs('update', G, hist, k, cfg)     fills them up to moment k
%
% They show the same numbers the AI and the classic controller use, so
% you can see WHY a car brakes: the gap line drops below the dotted safe
% distance, and the acceleration line swings down.

switch mode
    case 'build'
        out = build_graphs(varargin{1}, varargin{2});
    case 'update'
        update_graphs(varargin{1}, varargin{2}, varargin{3}, varargin{4});
    otherwise
        error('demo_graphs: unknown mode %s', mode);
end
end

% ======================================================================
function G = build_graphs(gx, cfg)
% gx(1) = speed, gx(2) = gap, gx(3) = acceleration
G.ax = gx;
for i = 1:3
    hold(gx(i), 'on');
    grid(gx(i), 'on');
    box(gx(i), 'on');
    % fixed light colours, so the graphs look the same in MATLAB's dark theme
    set(gx(i), 'Color', [1 1 1], 'XColor', [0.2 0.2 0.2], 'YColor', [0.2 0.2 0.2], ...
               'GridColor', [0.6 0.6 0.6]);
end

% ---- speed: ours (blue), classic (red dashed), lead car (black dotted)
G.v_a = plot(gx(1), NaN, NaN, 'b-',  'LineWidth', 1.8);
G.v_b = plot(gx(1), NaN, NaN, 'r--', 'LineWidth', 1.5);
G.v_l = plot(gx(1), NaN, NaN, 'k:',  'LineWidth', 1.5);
plot(gx(1), [0 1e4], [cfg.v_set cfg.v_set], 'Color', [0.6 0.6 0.6]);   % cruise speed
ylim(gx(1), [0 35]);
title(gx(1), 'speed [m/s]');
G.lg(1) = legend(gx(1), {'AI', 'classic ACC', 'lead car (you)'}, 'Location', 'southeast');

% ---- gap: ours, classic, and our safe distance (dotted blue)
G.g_a = plot(gx(2), NaN, NaN, 'b-',  'LineWidth', 1.8);
G.g_b = plot(gx(2), NaN, NaN, 'r--', 'LineWidth', 1.5);
G.g_s = plot(gx(2), NaN, NaN, 'b:',  'LineWidth', 1.3);
ylim(gx(2), [0 160]);
title(gx(2), 'gap [m]   (dotted = safe distance)');
G.lg(2) = legend(gx(2), {'AI gap', 'classic gap', 'safe distance'}, 'Location', 'northeast');

% ---- acceleration: the pedal action of each driver
G.a_a = plot(gx(3), NaN, NaN, 'b-',  'LineWidth', 1.4);
G.a_b = plot(gx(3), NaN, NaN, 'r--', 'LineWidth', 1.4);
ylim(gx(3), [-7.5 3]);           % down to -7: emergency braking
title(gx(3), 'acceleration [m/s^2]');
G.lg(3) = legend(gx(3), {'AI', 'classic ACC'}, 'Location', 'southwest');

for i = 1:3
    xlabel(gx(i), 'time [s]');
    set(get(gx(i), 'Title'), 'Color', [0.1 0.1 0.1]);
    set(get(gx(i), 'XLabel'), 'Color', [0.2 0.2 0.2]);
    try
        set(G.lg(i), 'Color', [1 1 1], 'TextColor', [0.1 0.1 0.1]);
    catch
    end
end
end

% ======================================================================
function update_graphs(G, hist, k, cfg)
% puts the data up to moment k into the lines, and slides the time window
t = hist.t(1:k);
set(G.v_a, 'XData', t, 'YData', hist.ve_a(1:k));
set(G.v_b, 'XData', t, 'YData', hist.ve_b(1:k));
set(G.v_l, 'XData', t, 'YData', hist.vl(1:k));

set(G.g_a, 'XData', t, 'YData', min(hist.gap_a(1:k), 160));
set(G.g_b, 'XData', t, 'YData', min(hist.gap_b(1:k), 160));
set(G.g_s, 'XData', t, 'YData', hist.dsafe(1:k));

set(G.a_a, 'XData', t, 'YData', hist.ae_a(1:k));
set(G.a_b, 'XData', t, 'YData', hist.ae_b(1:k));

% show the last 60 seconds, so the graphs stay readable for a long drive
window = [max(0, t(end) - 60), max(60, t(end) + 1)];
for i = 1:numel(G.ax)
    xlim(G.ax(i), window);
end
end
