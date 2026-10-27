function out = demo_world(mode, varargin)
% DEMO_WORLD  Builds and draws the 3D road scene.
%
%   W = demo_world('build', ax)
%       Creates the scenery (grass, road, lane lines, trees, lamp posts)
%       and the three cars. Run once per window.
%
%   demo_world('draw', W, ax, hist, k, cam, prefix)
%       Moves the cars to frame k of the history, moves the scenery so it
%       always surrounds the car, and points the camera.
%       cam is 'chase' (behind our car) or 'iso' (angled overview).
%
% Everything is real 3D: the scene is made of patches with x, y and z
% coordinates, and the camera looks at it in perspective or isometric view.
%
% The scenery is one short "tile" that repeats. Three copies of the tile
% are slid along the road so there is always scenery around the car, which
% means a drive can go on for as long as you like.
%
% World coordinates: x along the road (direction of travel), y across the
% road, z up. Our lane is at y = -1.75 m.

switch mode
    case 'build'
        out = build_world(varargin{1});
    case 'draw'
        draw_world(varargin{:});
    otherwise
        error('demo_world: unknown mode %s', mode);
end
end

% ======================================================================
function W = build_world(ax)
% creates the cars, the scenery tile (three copies) and the text lines

W.L    = 4.5;                 % car length [m]
W.Wd   = 1.8;                 % car width [m]
W.lane = -1.75;               % centre of our lane [m]
W.P    = 360;                 % length of one tile of scenery [m]

cla(ax); hold(ax, 'on');
set(ax, 'Color', [0.62 0.80 0.95]);   % sky colour
% hide the axis lines, numbers and box. (Hiding the whole axes would also hide
% the sky colour, so we switch off only the parts we do not want to see.)
set(ax, 'XTick', [], 'YTick', [], 'ZTick', [], 'Box', 'off', ...
        'XColor', 'none', 'YColor', 'none', 'ZColor', 'none');

% three lines of text above the scene, for the live numbers
fig = get(ax, 'Parent');
for i = 1:3
    W.hud(i) = uicontrol(fig, 'Style', 'text', 'String', '', 'FontSize', 11, ...
                         'Units', 'normalized', 'Position', [0.03 0.915 - 0.03*(i-1) 0.94 0.03], ...
                         'HorizontalAlignment', 'left', 'BackgroundColor', get(fig, 'Color'));
end

% ---- the scenery: one tile, drawn three times so it always surrounds us
[groups, colours] = tile_groups(W.P);
W.tileV = groups;                              % the tile's corner points, per group
W.tile = zeros(numel(groups), 3);
for g = 1:numel(groups)
    for j = 1:3
        W.tile(g, j) = patch('Parent', ax, 'Vertices', groups{g}.V, 'Faces', groups{g}.F, ...
                             'FaceColor', colours(g, :), 'EdgeColor', 'none', ...
                             'FaceLighting', 'flat', 'AmbientStrength', 0.6);
    end
end

% ---- light from above and in front, so the 3D shapes show their shading
try
    light(ax, 'Position', [-60 -40 80], 'Style', 'infinite');
catch
    % some graphics systems have no light; the picture still works without it
end

% ---- the cars: ours (blue, solid), the lead car (grey, solid), the classic
% ACC ghost (red and see-through, with a red outline so it stays visible)
W.ego   = car_handles(ax, car_mesh(W.L, W.Wd, [0.18 0.45 0.95]), 1.00, true, 'none');
W.lead  = car_handles(ax, car_mesh(W.L, W.Wd, [0.55 0.55 0.58]), 1.00, true, 'none');
W.ghost = car_handles(ax, car_mesh(W.L, W.Wd, [0.90 0.20 0.20]), 0.25, false, [1 0.15 0.15]);
end

% ======================================================================
function [groups, colours] = tile_groups(P)
% the scenery of one tile, from x = 0 to x = P, as one shape per colour group.
% The tile repeats exactly, so the trees and lamps line up from tile to tile.

% ---- ground (grass) and road surface
groups{1}.V = [0 -60 -0.05; P -60 -0.05; P 60 -0.05; 0 60 -0.05];
groups{1}.F = [1 2 3 4];
groups{2}.V = [0 -3.5 0; P -3.5 0; P 3.5 0; 0 3.5 0];
groups{2}.F = [1 2 3 4];
colours = [0.36 0.62 0.30;     % grass
           0.27 0.27 0.30];    % asphalt

% ---- dashed white line down the middle, and solid white edge lines
Vd = zeros(0, 3); Fd = zeros(0, 4);
for x = 0:12:P - 12
    [Vd, Fd] = mesh_add(Vd, Fd, [x -0.12 0.02; x + 4 -0.12 0.02; ...
                                 x + 4 0.12 0.02; x 0.12 0.02], [1 2 3 4]);
end
for s = [-1 1]
    [Vd, Fd] = mesh_add(Vd, Fd, [0 s*3.2 0.02; P s*3.2 0.02; ...
                                 P s*3.45 0.02; 0 s*3.45 0.02], [1 2 3 4]);
end
groups{3}.V = Vd; groups{3}.F = Fd;
colours(3, :) = [0.97 0.97 0.97];

% ---- trees along both roadsides: a brown trunk and a green crown
Vt = zeros(0, 3); Ft = zeros(0, 4);       % trunks
Vc = zeros(0, 3); Fc = zeros(0, 4);       % crowns
cnt = 0;
for s = [-1 1]
    for i = 0:19                          % 20 trees per side in one tile
        cnt = cnt + 1;
        x = i * 18;
        y = s * (12 + 1.5 * sin(0.37 * cnt));       % a little irregular
        h = 3.5 + 1.8 * abs(sin(0.7 * cnt));        % tree height
        [Vk, Fk] = mesh_box(x - 0.25, x + 0.25, y - 0.25, y + 0.25, 0, 0.4 * h);
        [Vt, Ft] = mesh_add(Vt, Ft, Vk, Fk);
        [Vk, Fk] = mesh_box(x - 1.7, x + 1.7, y - 1.7, y + 1.7, 0.4 * h, h);
        [Vc, Fc] = mesh_add(Vc, Fc, Vk, Fk);
    end
end
groups{4}.V = Vt; groups{4}.F = Ft; colours(4, :) = [0.40 0.26 0.13];
groups{5}.V = Vc; groups{5}.F = Fc; colours(5, :) = [0.20 0.48 0.20];

% ---- lamp posts every 60 m on both sides, with a light on top
Vp = zeros(0, 3); Fp = zeros(0, 4);       % poles
Vl = zeros(0, 3); Fl = zeros(0, 4);       % lamp heads
for s = [-1 1]
    for x = 0:60:P - 60
        [Vk, Fk] = mesh_box(x - 0.08, x + 0.08, s*4.6 - 0.08, s*4.6 + 0.08, 0, 5.5);
        [Vp, Fp] = mesh_add(Vp, Fp, Vk, Fk);
        [Vk, Fk] = mesh_box(x - 0.45, x + 0.45, s*4.6 - 0.3, s*4.6 + 0.3, 5.2, 5.5);
        [Vl, Fl] = mesh_add(Vl, Fl, Vk, Fk);
    end
end
groups{6}.V = Vp; groups{6}.F = Fp; colours(6, :) = [0.45 0.45 0.50];
groups{7}.V = Vl; groups{7}.F = Fl; colours(7, :) = [1.00 0.97 0.80];
end

% ======================================================================
function draw_world(W, ax, hist, k, cam, prefix)
% moves the cars and the scenery to frame k and sets the camera and the text

xe_a = hist.xe_a(k);            % front bumper of our (AI) car
xe_b = hist.xe_b(k);            % front bumper of the ghost (classic ACC)
xl   = hist.xl(k);              % rear bumper of the lead car

% a car's own origin is its REAR bumper, so subtract the car length for
% the cars whose front bumper we know
car_move(W.ego,   xe_a - W.L, W.lane);
car_move(W.ghost, xe_b - W.L, W.lane);
car_move(W.lead,  xl,         W.lane);

% ---- scenery: put the three tile copies so they cover the area around us
base = floor((xe_a - 60) / W.P) * W.P;
for j = 1:3
    off = base + (j - 1) * W.P;
    for g = 1:numel(W.tileV)
        set(W.tile(g, j), 'Vertices', W.tileV{g}.V + [off 0 0]);
    end
end

% ---- camera
try
    if strcmp(cam, 'iso')
        % isometric: a fixed angled view from above that shows the whole road
        % around us. The camera is placed by hand (view() would reset it).
        % A small finite view angle keeps every graphics system happy.
        target = [xe_a + 35, W.lane, 0];
        set(ax, 'Projection', 'orthographic', 'CameraViewAngle', 10, ...
                'CameraTarget', target, 'CameraPosition', target + [-45, -60, 55], ...
                'CameraUpVector', [0 0 1]);
        set(ax, 'XLim', [xe_a - 35, xe_a + 110], 'YLim', [-14 14], 'ZLim', [-0.2 9]);
    else
        % chase: the camera sits behind our car and looks down the road
        set(ax, 'Projection', 'perspective');
        set(ax, 'XLim', [xe_a - 25, xe_a + 170], 'YLim', [-14 14], 'ZLim', [-0.2 9]);
        set(ax, 'CameraPosition', [xe_a - 16, W.lane, 4.2], ...
                'CameraTarget', [xe_a + 45, W.lane, 0.5], ...
                'CameraUpVector', [0 0 1], 'CameraViewAngle', 55);
    end
catch
    % a few graphics systems cannot change the camera; the scene still shows
end

% ---- the three lines of text above the scene: what is happening right now
line1 = sprintf('%s     time %5.1f s', prefix, hist.t(k));
line2 = sprintf('AI (blue):  speed %4.1f m/s   gap %5.1f m   safe gap %5.1f m   marks %6.1f', ...
                hist.ve_a(k), hist.gap_a(k), hist.dsafe(k), hist.R_a(k));
line3 = sprintf('Classic ACC (red ghost):  speed %4.1f m/s   gap %5.1f m   marks %6.1f', ...
                hist.ve_b(k), hist.gap_b(k), hist.R_b(k));
if hist.gap_a(k) <= 0
    line2 = [line2 '     <-- AI CRASHED'];
end
if hist.gap_b(k) <= 0
    line3 = [line3 '     <-- classic ACC CRASHED'];
end
set(W.hud(1), 'String', line1);
set(W.hud(2), 'String', line2);
set(W.hud(3), 'String', line3);
end

% ======================================================================
function H = car_handles(ax, parts, alpha, with_shadow, edge_col)
% creates one patch object per colour group of a car, plus a shadow.
% edge_col is the outline colour, or 'none' for no outline.
H.h = [];
H.base = {};
for j = 1:numel(parts)
    H.h(j) = patch('Parent', ax, 'Vertices', parts(j).V, 'Faces', parts(j).F, ...
                   'FaceColor', parts(j).color, 'EdgeColor', edge_col, ...
                   'FaceAlpha', alpha, 'FaceLighting', 'flat', 'AmbientStrength', 0.6);
    H.base{j} = parts(j).V;             % remember the car's own shape for moving later
end

H.shadow = [];
H.sbase  = [];
if with_shadow
    % a dark flat copy of the car's body, lying on the road
    sb = parts(1).V;
    sb(:, 3) = 0.03;
    H.shadow = patch('Parent', ax, 'Vertices', sb, 'Faces', parts(1).F(1:2, :), ...
                     'FaceColor', [0.05 0.05 0.06], 'EdgeColor', 'none', 'FaceAlpha', 0.35);
    H.sbase = sb;
end
end

% ======================================================================
function car_move(H, x, y)
% slides a car to a new place: every corner point moves by (x, y, 0)
d = [x y 0];
for j = 1:numel(H.h)
    set(H.h(j), 'Vertices', H.base{j} + d);
end
if ~isempty(H.shadow)
    set(H.shadow, 'Vertices', H.sbase + d);
end
end
