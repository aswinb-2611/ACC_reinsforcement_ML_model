function out = demo_world(mode, varargin)
% DEMO_WORLD  Builds and draws the 3D highway scene.
%
%   W = demo_world('build', ax)
%       Creates everything once: road, grass, barrier, guard rails, street
%       lights, trees, houses, mountains, sky, clouds, the cars and labels.
%
%   W = demo_world('draw', W, ax, hist, k, cam, compare)
%       Moves everything to moment k of the record and points the camera.
%       cam     : 'chase' (behind our car), 'drone' (high and to the side)
%                 or 'driver' (from the front of our car)
%       compare : true = also show the classic controller in the left lane
%
% THE TRICK FOR AN ENDLESS ROAD: the scenery is one 360 m "tile" that
% repeats. Three copies are placed one after another, and when our car has
% driven far enough the copies jump forward by one tile. They only move at
% that moment, so the scenery costs almost nothing to draw while driving.
%
% Real proportions: one unit is one metre in every direction
% (DataAspectRatio = [1 1 1]), so nothing is stretched.
%
% World coordinates: x along the road (direction of travel), y across the
% road (left is +y), z up. Our lane (the AI) is at y = -1.8 m. The left
% lane, used for the comparison, is at y = -5.4 m. The other side of the
% barrier is the oncoming carriageway.

switch mode
    case 'build'
        out = build_world(varargin{1});
    case 'draw'
        out = draw_world(varargin{:});
    otherwise
        error('demo_world: unknown mode %s', mode);
end
end

% ======================================================================
function W = build_world(ax)

W.L     = 4.5;               % car length [m]
W.Wd    = 1.8;               % car width [m]
W.laneA = -1.8;              % our lane (AI and the grey lead car)
W.laneB = -5.4;              % left lane, used when comparing with classic ACC
W.P     = 360;               % length of one scenery tile [m]
W.last_base = NaN;           % where the tiles were last placed

cla(ax); hold(ax, 'on');
view(ax, 3);                 % a 3D view (not the flat top-down 2D view)
set(ax, 'Color', [0.78 0.86 0.94], 'DataAspectRatio', [1 1 1], ...
        'XTick', [], 'YTick', [], 'ZTick', [], 'Box', 'off', ...
        'XColor', 'none', 'YColor', 'none', 'ZColor', 'none');

% ---- textures (pictures painted onto surfaces), made from simple maths
asphalt   = make_texture('asphalt', 48, 1024);
grass     = make_texture('grass', 128, 512);
grass_far = make_texture('far', 48, 48);

% ---- the tiles: road, grass and all roadside objects, three copies
G = tile_groups(W.P);
W.groups = G;
for j = 1:3
    % our carriageway (with hard shoulder) and the oncoming carriageway
    W.road1(j) = flat_surface(ax, 0, W.P, -9.0, 0.0, 0.00, asphalt);
    W.road2(j) = flat_surface(ax, 0, W.P,  3.0, 12.0, 0.00, asphalt);
    W.near(j)  = flat_surface(ax, 0, W.P, -60, 60, -0.08, grass);
    W.far(j)   = flat_surface(ax, 0, W.P, -950, 950, -0.30, grass_far);
    for g = 1:numel(G)
        W.tile(g, j) = patch('Parent', ax, 'Vertices', G(g).V, 'Faces', G(g).F, ...
                             'FaceColor', G(g).color, 'EdgeColor', 'none', ...
                             'FaceLighting', 'flat', 'AmbientStrength', 0.55, ...
                             'DiffuseStrength', 0.6, 'SpecularStrength', 0.1);
    end
end
W.road1_X = get(W.road1(1), 'XData');
W.near_X  = get(W.near(1), 'XData');
W.far_X   = get(W.far(1), 'XData');

% ---- far away: mountains, clouds and the sky. They follow the camera.
ym = linspace(-950, 950, 140);
hm = 45 + 35 * sin(ym / 61) + 22 * sin(ym / 23 + 1.3) + 12 * sin(ym / 9 + 0.4);
W.mtn_X = 900 * ones(2, numel(ym));
Cm = zeros(2, numel(ym), 3);
Cm(1, :, :) = repmat(reshape([0.33 0.42 0.36], 1, 1, 3), 1, numel(ym));
Cm(2, :, :) = repmat(reshape([0.55 0.62 0.72], 1, 1, 3), 1, numel(ym));
W.mtn = surface('Parent', ax, 'XData', W.mtn_X, 'YData', [ym; ym], ...
                'ZData', [zeros(size(hm)); hm], 'CData', Cm, 'FaceColor', 'interp', ...
                'EdgeColor', 'none', 'FaceLighting', 'none');
sky = make_texture('sky', 64, 2);
W.sky_X = [980 980; 980 980];
W.sky = surface('Parent', ax, 'XData', W.sky_X, 'YData', [-960 960; -960 960], ...
                'ZData', [0 0; 540 540], 'CData', sky, 'FaceColor', 'texturemap', ...
                'EdgeColor', 'none', 'FaceLighting', 'none');
[Vc, Fc] = cloud_mesh();
W.cloud_V = Vc;
W.cloud = patch('Parent', ax, 'Vertices', Vc, 'Faces', Fc, 'FaceColor', [1 1 1], ...
                'EdgeColor', 'none', 'FaceAlpha', 0.85, 'FaceLighting', 'none');

% ---- sunlight from above and behind-left, plus a soft fill light
try
    light(ax, 'Position', [-0.5 0.6 1.0], 'Style', 'infinite');
    light(ax, 'Position', [0.6 -0.5 0.4], 'Style', 'infinite', 'Color', [0.45 0.45 0.5]);
catch
    % some graphics systems have no lights; the scene still works
end

% ---- the cars
W.ai    = car_handles(ax, car_mesh(W.L, W.Wd, [0.10 0.35 0.85]));   % AI: blue
W.lead  = car_handles(ax, car_mesh(W.L, W.Wd, [0.62 0.64 0.67]));   % you: grey
W.cls   = car_handles(ax, car_mesh(W.L, W.Wd, [0.80 0.12 0.12]));   % classic ACC: red
W.lead2 = car_handles(ax, car_mesh(W.L, W.Wd, [0.62 0.64 0.67]));   % your car, copied to the left lane

% ---- a few cars on the other side of the barrier, just for life
colours = [0.92 0.92 0.94; 0.15 0.18 0.22; 0.90 0.68 0.15; 0.25 0.45 0.30];
W.onc_lane  = [4.8 8.4 4.8 8.4];
W.onc_speed = [29 24 31 26];
W.onc_start = [150 420 620 820];
for i = 1:4
    W.onc(i) = car_handles(ax, flip_parts(car_mesh(W.L, W.Wd, colours(i, :)), W.L));
end

% ---- labels floating above the cars
W.lab_lead  = make_label(ax, 'YOU',          [0.35 0.36 0.38]);
W.lab_ai    = make_label(ax, 'AI',           [0.10 0.35 0.85]);
W.lab_cls   = make_label(ax, 'CLASSIC ACC',  [0.80 0.12 0.12]);
W.lab_lead2 = make_label(ax, 'YOU',          [0.35 0.36 0.38]);
end

% ======================================================================
function W = draw_world(W, ax, hist, k, cam, compare)
% moves everything to moment k

xe = hist.xe_a(k);           % front bumper of the AI car
xb = hist.xe_b(k);           % front bumper of the classic car
xl = hist.xl(k);             % rear bumper of the lead car (yours)
t  = hist.t(k);

% ---- scenery tiles: only move them when we have driven into a new tile
base = floor((xe - 120) / W.P) * W.P;
if ~isequal(base, W.last_base)
    for j = 1:3
        off = base + (j - 1) * W.P;
        set(W.road1(j), 'XData', W.road1_X + off);
        set(W.road2(j), 'XData', W.road1_X + off);
        set(W.near(j),  'XData', W.near_X + off);
        set(W.far(j),   'XData', W.far_X + off);
        for g = 1:numel(W.groups)
            set(W.tile(g, j), 'Vertices', W.groups(g).V + [off 0 0]);
        end
    end
    W.last_base = base;
end

% ---- far scenery follows us, so it always sits on the horizon
set(W.mtn,   'XData', W.mtn_X + xe);
set(W.sky,   'XData', W.sky_X + xe);
set(W.cloud, 'Vertices', W.cloud_V + [xe 0 0]);

% ---- our car, your lead car, and (if comparing) the classic pair
car_move(W.ai,   xe - W.L, W.laneA);
car_move(W.lead, xl,       W.laneA);
car_brake(W.ai,   hist.ae_a(k) < -0.4);
car_brake(W.lead, hist.al(k)   < -0.4);
set_label(W.lab_ai,   xe - W.L / 2, W.laneA);
set_label(W.lab_lead, xl + W.L / 2, W.laneA);
% from behind or inside our car it is obvious which car is the AI, and the
% tag would only float in the middle of the road, so show it from above only
set(W.lab_ai, 'Visible', onoff(strcmp(cam, 'drone')));

car_show(W.cls, compare);  car_show(W.lead2, compare);
set(W.lab_cls, 'Visible', onoff(compare));
set(W.lab_lead2, 'Visible', onoff(compare));
if compare
    car_move(W.cls,   xb - W.L, W.laneB);
    car_move(W.lead2, xl,       W.laneB);
    car_brake(W.cls,   hist.ae_b(k) < -0.4);
    car_brake(W.lead2, hist.al(k)   < -0.4);
    set_label(W.lab_cls,   xb - W.L / 2, W.laneB);
    set_label(W.lab_lead2, xl + W.L / 2, W.laneB);
end

% ---- oncoming traffic: drives the other way, wraps around out of sight
for i = 1:numel(W.onc)
    xo = W.onc_start(i) - W.onc_speed(i) * t;
    xo = (xe - 150) + mod(xo - (xe - 150), 950);
    car_move(W.onc(i), xo, W.onc_lane(i));
end

% ---- camera: where it sits, where it looks, how wide it sees
switch cam
    case 'drone'
        % high up and to the side, like a drone following the cars
        pos = [xe - 30, W.laneA - 34, 26];  tgt = [xe + 22, W.laneA - 1, 0];  va = 42;
    case 'driver'
        % from just in front of our car, at driver eye height
        pos = [xe + 0.3, W.laneA, 1.3];     tgt = [xe + 60, W.laneA, 1.0];    va = 60;
    otherwise
        % chase: a little above and behind our car, like a driving game
        pos = [xe - 11, W.laneA - 0.6, 3.4]; tgt = [xe + 25, W.laneA - 0.6, 1.0]; va = 46;
end
try
    % the view angle is set FIRST: some graphics systems refuse the other
    % camera settings until the angle is a normal (finite) number
    set(ax, 'CameraViewAngle', va);
    set(ax, 'Projection', 'perspective', 'CameraUpVector', [0 0 1]);
    % the part of the world to draw (everything within these limits)
    set(ax, 'XLim', [xe - 150, xe + 1000], 'YLim', [-960 960], 'ZLim', [-1 545]);
    set(ax, 'CameraPosition', pos, 'CameraTarget', tgt);
catch
    % a graphics system that cannot move the camera still shows the scene
end
end

% ======================================================================
function G = tile_groups(P)
% everything at the roadside for one tile (x from 0 to P), one shape per colour

n = 0;
% --- white lane markings: dashed lane dividers and solid edge lines
V = zeros(0, 3); F = zeros(0, 4);
for yc = [-3.6 6.6]                              % dashed dividers
    for x = 0:12:P - 12
        [V, F] = mesh_add(V, F, quad(x, x + 3, yc - 0.08, yc + 0.08, 0.03), [1 2 3 4]);
    end
end
for yc = [-0.3 -7.1 3.3 9.9]                     % solid edge lines
    [V, F] = mesh_add(V, F, quad(0, P, yc - 0.08, yc + 0.08, 0.03), [1 2 3 4]);
end
n = n + 1; G(n) = grp(V, F, [0.95 0.95 0.95]);

% --- concrete barrier in the middle of the highway
[V, F] = mesh_box(0, P, 1.25, 1.75, 0, 0.85);
n = n + 1; G(n) = grp(V, F, [0.72 0.72 0.70]);

% --- metal guard rails on both outer edges, with posts every 4 m
V = zeros(0, 3); F = zeros(0, 4);
for yc = [-9.3 12.3]
    [Vb, Fb] = mesh_box(0, P, yc - 0.04, yc + 0.04, 0.55, 0.80);
    [V, F] = mesh_add(V, F, Vb, Fb);
    for x = 0:4:P - 4
        [Vb, Fb] = mesh_box(x, x + 0.12, yc - 0.06, yc + 0.06, 0, 0.72);
        [V, F] = mesh_add(V, F, Vb, Fb);
    end
end
n = n + 1; G(n) = grp(V, F, [0.62 0.64 0.66]);

% --- street lights on the barrier: a tall pole with an arm over each side
V = zeros(0, 3); F = zeros(0, 4);
Vl = zeros(0, 3); Fl = zeros(0, 4);
for x = 0:45:P - 45
    [Vb, Fb] = mesh_box(x - 0.09, x + 0.09, 1.41, 1.59, 0.85, 9.0);
    [V, F] = mesh_add(V, F, Vb, Fb);
    [Vb, Fb] = mesh_box(x - 0.06, x + 0.06, -2.2, 5.2, 8.75, 8.9);
    [V, F] = mesh_add(V, F, Vb, Fb);
    for yl = [-2.2 5.2]
        [Vb, Fb] = mesh_box(x - 0.5, x + 0.5, yl - 0.25, yl + 0.25, 8.55, 8.75);
        [Vl, Fl] = mesh_add(Vl, Fl, Vb, Fb);
    end
end
n = n + 1; G(n) = grp(V, F, [0.32 0.33 0.36]);
n = n + 1; G(n) = grp(Vl, Fl, [1.00 0.95 0.78]);

% --- trees: a mix of pines (cones) and leafy trees (balls)
Vt = zeros(0, 3); Ft = zeros(0, 4);      % trunks
Vp = zeros(0, 3); Fp = zeros(0, 4);      % pine needles
Vr = zeros(0, 3); Fr = zeros(0, 4);      % leafy crowns
c = 0;
for side = [-1 1]
    for x0 = 6:15:P - 6
        c = c + 1;
        x = x0 + 6 * (hsh(c) - 0.5);
        y = side * (16 + 24 * hsh(c + 100)) + (side > 0) * 3;
        sz = 0.8 + 0.5 * hsh(c + 200);
        if hsh(c + 300) < 0.55
            [Vb, Fb] = mesh_box(x - 0.2, x + 0.2, y - 0.2, y + 0.2, 0, 1.6 * sz);
            [Vt, Ft] = mesh_add(Vt, Ft, Vb, Fb);
            [Vb, Fb] = mesh_cone(x, y, 1.2 * sz, 2.6 * sz, 5.0 * sz, 9);
            [Vp, Fp] = mesh_add(Vp, Fp, Vb, Fb);
            [Vb, Fb] = mesh_cone(x, y, 3.8 * sz, 1.9 * sz, 4.4 * sz, 9);
            [Vp, Fp] = mesh_add(Vp, Fp, Vb, Fb);
        else
            [Vb, Fb] = mesh_box(x - 0.25, x + 0.25, y - 0.25, y + 0.25, 0, 2.6 * sz);
            [Vt, Ft] = mesh_add(Vt, Ft, Vb, Fb);
            [Vb, Fb] = mesh_ball(x, y, 4.2 * sz, 2.9 * sz, 2.4 * sz, 6);
            [Vr, Fr] = mesh_add(Vr, Fr, Vb, Fb);
        end
    end
end
n = n + 1; G(n) = grp(Vt, Ft, [0.36 0.24 0.14]);
n = n + 1; G(n) = grp(Vp, Fp, [0.12 0.34 0.16]);
n = n + 1; G(n) = grp(Vr, Fr, [0.28 0.52 0.20]);

% --- houses (walls with pointed roofs) and taller towers further away
Vw = zeros(0, 3); Fw = zeros(0, 4);      % house walls
Vf = zeros(0, 3); Ff = zeros(0, 4);      % roofs
Vo = zeros(0, 3); Fo = zeros(0, 4);      % towers
c = 500;
for side = [-1 1]
    for x0 = 20:65:P - 20
        c = c + 1;
        w = 9 + 7 * hsh(c);  d = 8 + 4 * hsh(c + 1);  h = 5 + 5 * hsh(c + 2);
        x = x0 + 10 * (hsh(c + 3) - 0.5);
        y = side * (58 + 25 * hsh(c + 4));
        [Vb, Fb] = mesh_box(x - w/2, x + w/2, y - d/2, y + d/2, 0, h);
        [Vw, Fw] = mesh_add(Vw, Fw, Vb, Fb);
        [Vb, Fb] = mesh_cone(x, y, h, 0.75 * max(w, d), 3.5, 4);
        [Vf, Ff] = mesh_add(Vf, Ff, Vb, Fb);
    end
    for x0 = [70 250]
        c = c + 1;
        h = 28 + 30 * hsh(c);
        y = side * (150 + 70 * hsh(c + 5));
        [Vb, Fb] = mesh_box(x0 - 11, x0 + 11, y - 11, y + 11, 0, h);
        [Vo, Fo] = mesh_add(Vo, Fo, Vb, Fb);
    end
end
n = n + 1; G(n) = grp(Vw, Fw, [0.88 0.83 0.72]);
n = n + 1; G(n) = grp(Vf, Ff, [0.58 0.25 0.20]);
n = n + 1; G(n) = grp(Vo, Fo, [0.58 0.64 0.72]);
end

% ======================================================================
function g = grp(V, F, color)
g.V = V; g.F = F; g.color = color;
end

function V = quad(x0, x1, y0, y1, z)
% the 4 corners of a flat rectangle at height z
V = [x0 y0 z; x1 y0 z; x1 y1 z; x0 y1 z];
end

function v = hsh(i)
% a repeatable "random looking" number between 0 and 1 (no random generator
% is used, so the scenery is identical every time and in every program)
v = mod(sin(i * 127.1 + 311.7) * 43758.5453, 1);
end

% ======================================================================
function h = flat_surface(ax, x0, x1, y0, y1, z, tex)
% a flat rectangle with a picture (texture) painted on it
h = surface('Parent', ax, 'XData', [x0 x1; x0 x1], 'YData', [y0 y0; y1 y1], ...
            'ZData', z * ones(2), 'CData', tex, 'FaceColor', 'texturemap', ...
            'EdgeColor', 'none', 'FaceLighting', 'none');
end

function tex = make_texture(kind, rows, cols)
% builds a texture picture from simple maths: a base colour plus "noise"
% (tiny random-looking changes), so the road and grass are not flat colours
[J, I] = meshgrid(1:cols, 1:rows);
fine = mod(sin(I * 12.9898 + J * 78.233) * 43758.5453, 1) - 0.5;
Ic = ceil(I / 8); Jc = ceil(J / 8);
coarse = mod(sin(Ic * 39.346 + Jc * 11.135) * 24634.6345, 1) - 0.5;
switch kind
    case 'asphalt'
        base = [64 66 70];
        v = 9 * fine + 4 * coarse;
        % slightly darker strips where the tyres usually run, in both lanes
        y = -9 + 9 * (I - 1) / (rows - 1);
        tracks = zeros(size(I));
        for yc = [-1.8 -5.4]
            tracks = tracks + (abs(abs(y - yc) - 0.8) < 0.35);
        end
        v = v - 5 * tracks;
        tex = cat(3, base(1) + v, base(2) + v, base(3) + v);
    case 'grass'
        v = 12 * fine + 16 * coarse;
        tex = cat(3, 70 + 0.6 * v, 118 + v, 50 + 0.5 * v);
    case 'far'
        v = 6 * fine + 10 * coarse;
        tex = cat(3, 74 + 0.6 * v, 112 + v, 58 + 0.5 * v);
    case 'sky'
        f = (I - 1) / (rows - 1);              % 0 at the horizon, 1 at the top
        tex = cat(3, 210 - 120 * f, 226 - 80 * f, 240 - 25 * f);
end
tex = uint8(min(max(tex, 0), 255));
end

function [V, F] = cloud_mesh()
% a few soft white clouds, made of flat ovals, standing in front of the sky
V = zeros(0, 3); F = zeros(0, 4);
a = 2 * pi * (0:15)' / 16;
for i = 1:7
    yc = -800 + 260 * i + 40 * sin(i * 3.1);
    zc = 160 + 90 * hsh(i + 900);
    for b = 1:3
        ry = 55 + 25 * hsh(i * 7 + b);  rz = 18 + 8 * hsh(i * 11 + b);
        Vo = [970 * ones(16, 1), yc + (b - 2) * 45 + ry * cos(a), zc + rz * sin(a)];
        idx = size(V, 1) + (1:16);
        V = [V; Vo]; %#ok<AGROW>
        % an oval as a fan of thin triangles from its first point
        for q = 2:15
            F(end + 1, :) = [idx(1), idx(q), idx(q + 1), idx(q + 1)]; %#ok<AGROW>
        end
    end
end
end

% ======================================================================
function H = car_handles(ax, parts)
% creates the graphics objects for one car and remembers its shape
H.h = [];  H.kind = {};  H.base = {};  H.tail = 0;
for j = 1:numel(parts)
    pt = parts(j);
    if strcmp(pt.kind, 'surf')
        h = surface('Parent', ax, 'XData', pt.X, 'YData', pt.Y, 'ZData', pt.Z, ...
                    'CData', pt.C, 'FaceColor', 'interp', 'EdgeColor', 'none', ...
                    'FaceLighting', 'gouraud', 'AmbientStrength', 0.45, ...
                    'DiffuseStrength', 0.7, 'SpecularStrength', 0.9, 'SpecularExponent', 18);
        H.base{j} = {pt.X, pt.Y};
    else
        alpha = 1;
        if strcmp(pt.role, 'shadow'), alpha = 0.35; end
        h = patch('Parent', ax, 'Vertices', pt.V, 'Faces', pt.F, 'FaceColor', pt.color, ...
                  'EdgeColor', 'none', 'FaceAlpha', alpha, 'FaceLighting', 'gouraud', ...
                  'AmbientStrength', 0.5, 'SpecularStrength', 0.5);
        H.base{j} = pt.V;
        if strcmp(pt.role, 'tail'), H.tail = j; end
    end
    H.h(j) = h;
    H.kind{j} = pt.kind;
end
end

function car_move(H, x, y)
% slides a car so its rear bumper is at x, centred on y
for j = 1:numel(H.h)
    if strcmp(H.kind{j}, 'surf')
        set(H.h(j), 'XData', H.base{j}{1} + x, 'YData', H.base{j}{2} + y);
    else
        set(H.h(j), 'Vertices', H.base{j} + [x y 0]);
    end
end
end

function car_brake(H, on)
% brake lights glow bright red while the car is braking
if H.tail > 0
    if on
        set(H.h(H.tail), 'FaceColor', [1.0 0.08 0.05], 'AmbientStrength', 1);
    else
        set(H.h(H.tail), 'FaceColor', [0.45 0.03 0.03], 'AmbientStrength', 0.5);
    end
end
end

function car_show(H, vis)
set(H.h, 'Visible', onoff(vis));
end

function parts = flip_parts(parts, L)
% turns a car around (for oncoming traffic): front becomes back
for j = 1:numel(parts)
    if strcmp(parts(j).kind, 'surf')
        parts(j).X = L - parts(j).X;
        parts(j).Y = -parts(j).Y;
    else
        parts(j).V(:, 1) = L - parts(j).V(:, 1);
        parts(j).V(:, 2) = -parts(j).V(:, 2);
    end
end
end

function h = make_label(ax, str, col)
h = text('Parent', ax, 'Position', [0 0 0], 'String', str, 'Color', [1 1 1], ...
         'BackgroundColor', col, 'FontWeight', 'bold', 'FontSize', 10, ...
         'HorizontalAlignment', 'center', 'Margin', 2);
end

function set_label(h, x, y)
set(h, 'Position', [x, y, 2.6]);
end

function s = onoff(tf)
if tf, s = 'on'; else, s = 'off'; end
end
