function parts = car_mesh(L, W, body_col)
% CAR_MESH  Builds a rounded 3D car: body, windows, wheels, lights, shadow.
%
%   parts = car_mesh(L, W, body_col)
%
%   L, W     : car length and width [m] (a typical car: 4.5 and 1.8)
%   body_col : [r g b] colour of the paint, each value between 0 and 1
%
% Coordinates used inside this file (the car's own "local" frame):
%   x = 0 is the REAR bumper, x = L is the FRONT bumper
%   y = 0 is the middle of the car (left is +y, right is -y)
%   z = 0 is the road surface, z goes up
%
% HOW THE BODY IS MADE: imagine slicing a car like a loaf of bread. Each
% slice is a rounded rectangle (a "superellipse"). The slices are taller
% in the middle (the cabin) and lower at the bonnet and boot, and they get
% smaller at both ends so the nose and tail are rounded. Joining all the
% slices gives one smooth surface. Points high up on the cabin sides are
% coloured as glass, so the windows appear by themselves.
%
% The result is a struct array, one entry per part:
%   kind  'surf' (smooth surface: X, Y, Z, C) or 'patch' (V, F, color)
%   role  'body', 'tyre', 'rim', 'head', 'tail' or 'shadow'

glass    = [0.07 0.09 0.13];             % dark tinted windows
trim     = [0.12 0.12 0.13];             % black lower trim and bumpers
tyre_col = [0.06 0.06 0.07];
rim_col  = [0.72 0.74 0.78];             % silver wheel rims
lamp_col = [1.00 0.96 0.80];             % headlights
tail_col = [0.45 0.03 0.03];             % tail lights (brighter when braking)

% ---- 1. the body: slices along the length of the car
ns = 34;                                 % number of slices
nt = 28;                                 % points around each slice
s  = linspace(0, 1, ns);                 % 0 = rear bumper, 1 = front bumper
% roof line (height of the top of each slice), from rear to front:
% boot, rear window, roof, windscreen, bonnet, nose
xp = [0    0.05 0.18 0.30 0.70 0.83 0.95 1.00];
hp = [0.80 0.95 1.00 1.42 1.45 1.00 0.92 0.80];
H  = interp1(xp, hp, s);                 % top of each slice [m]
B  = 0.30;                               % bottom of the body (ground clearance)
belt = 1.0;                              % where the windows start
th = linspace(0, 2*pi, nt);              % angle around a slice
p  = 5;                                  % 2 = ellipse, bigger = boxier

X = zeros(ns, nt); Y = X; Z = X; C = zeros(ns, nt, 3);
for i = 1:ns
    % end taper: slices shrink near the bumpers so the nose and tail are round
    cs = (1 - abs(2 * s(i) - 1) ^ 7) ^ 0.3;
    zc = (H(i) + B) / 2;                 % middle height of this slice
    hz = (H(i) - B) / 2;                 % half height of this slice
    for j = 1:nt
        cy = sign(cos(th(j))) * abs(cos(th(j))) ^ (2 / p);
        cz = sign(sin(th(j))) * abs(sin(th(j))) ^ (2 / p);
        z  = zc + hz * cz;
        % the cabin is narrower at the top than the body ("tumblehome")
        narrow = 1 - 0.24 * min(max((z - belt) / (1.45 - belt), 0), 1);
        X(i, j) = s(i) * L;
        Y(i, j) = (W / 2) * cy * narrow * cs;
        Z(i, j) = zc + (z - zc) * cs;
        % colour of this point: glass for the window band, trim at the bottom
        col = body_col;
        if Z(i, j) > belt + 0.03 && Z(i, j) < H(i) - 0.05 && s(i) > 0.17 && s(i) < 0.84
            col = glass;
        elseif Z(i, j) < 0.42
            col = trim;
        end
        C(i, j, :) = reshape(col, 1, 1, 3);
    end
end
parts(1) = make_part('surf', 'body', X, Y, Z, C, [], [], []);

% ---- 2. four wheels: black tyres with silver rims
Vt = zeros(0, 3); Ft = zeros(0, 4);
Vr = zeros(0, 3); Fr = zeros(0, 4);
for cx = [0.20 * L, 0.79 * L]
    for sd = [-1, 1]
        y_in  = sd * (W / 2 - 0.10);
        y_out = sd * (W / 2 + 0.06);
        [Vw, Fw] = mesh_wheel(cx, 0.34, 0.34, y_in, y_out, 18);
        [Vt, Ft] = mesh_add(Vt, Ft, Vw, Fw);
        [Vw, Fw] = mesh_wheel(cx, 0.34, 0.21, y_out, y_out + sd * 0.015, 18);
        [Vr, Fr] = mesh_add(Vr, Fr, Vw, Fw);
    end
end
parts(2) = make_part('patch', 'tyre', [], [], [], [], Vt, Ft, tyre_col);
parts(3) = make_part('patch', 'rim',  [], [], [], [], Vr, Fr, rim_col);

% ---- 3. headlights (front) and tail lights (back)
[Va, Fa] = mesh_box(L - 0.30, L - 0.10,  0.28,  0.62, 0.60, 0.76);
[Vb, Fb] = mesh_box(L - 0.30, L - 0.10, -0.62, -0.28, 0.60, 0.76);
[Vh, Fh] = mesh_add(Va, Fa, Vb, Fb);
parts(4) = make_part('patch', 'head', [], [], [], [], Vh, Fh, lamp_col);
[Va, Fa] = mesh_box(0.10, 0.30,  0.30,  0.66, 0.72, 0.86);
[Vb, Fb] = mesh_box(0.10, 0.30, -0.66, -0.30, 0.72, 0.86);
[Vk, Fk] = mesh_add(Va, Fa, Vb, Fb);
parts(5) = make_part('patch', 'tail', [], [], [], [], Vk, Fk, tail_col);

% ---- 4. a soft dark shadow on the road under the car (an oval)
a = 2 * pi * (0:31)' / 32;
Vs = [L / 2 + (L / 2 + 0.25) * cos(a), (W / 2 + 0.25) * sin(a), 0.02 * ones(32, 1)];
Fs = 1:32;                               % one face through all 32 points
parts(6) = make_part('patch', 'shadow', [], [], [], [], Vs, Fs, [0 0 0]);
end

% ======================================================================
function pt = make_part(kind, role, X, Y, Z, C, V, F, color)
% packs one part into a struct (every part has the same list of fields)
pt.kind = kind;  pt.role = role;
pt.X = X; pt.Y = Y; pt.Z = Z; pt.C = C;
pt.V = V; pt.F = F; pt.color = color;
end
