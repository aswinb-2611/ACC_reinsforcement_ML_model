function parts = car_mesh(L, W, body_col)
% CAR_MESH  Builds a simple 3D car out of boxes and round tyres.
%
%   parts = car_mesh(L, W, body_col)
%
%   L, W     : car length and width [m] (a typical small car: 4.5 and 1.8)
%   body_col : [r g b] colour of the paint, each value between 0 and 1
%
% Coordinates used inside this file (the car's own "local" frame):
%   x = 0 is the REAR bumper, x = L is the FRONT bumper
%   y = 0 is the middle of the car, left and right are +y and -y
%   z = 0 is the road surface, z goes up
%
% The result is a struct array with one entry per colour group. The first
% entry is always the body, which the shadow code relies on.

glass    = [0.13 0.18 0.26];               % dark windows
tyre_col = [0.07 0.07 0.08];               % black tyres
lamp_col = [1.00 0.95 0.65];               % warm headlights
tail_col = [0.90 0.10 0.10];               % red tail lights

% ---- body: a low box for the bonnet and boot, plus a roof on top of the cabin
[Vb, Fb] = mesh_box(0, L, -W/2, W/2, 0.35, 1.00);
[Vr, Fr] = mesh_box(0.30*L, 0.76*L, -0.42*W, 0.42*W, 1.45, 1.52);
[Vbody, Fbody] = mesh_add(Vb, Fb, Vr, Fr);

% ---- cabin glass: the windows part of the car
[Vg, Fg] = mesh_box(0.30*L, 0.76*L, -0.42*W, 0.42*W, 1.00, 1.46);

% ---- four wheels: two at the back (x = 0.2L) and two at the front (x = 0.8L)
Vt = zeros(0, 3); Ft = zeros(0, 4);
for cx = [0.20*L, 0.80*L]
    for s = [-1, 1]
        y_in  = s * (W/2 - 0.12);          % wheel face nearest the car middle
        y_out = s * (W/2 + 0.16);          % wheel face sticking out a little
        [Vw, Fw] = mesh_wheel(cx, 0.33, 0.33, y_in, y_out, 14);
        [Vt, Ft] = mesh_add(Vt, Ft, Vw, Fw);
    end
end

% ---- headlights (front) and tail lights (back), one small box per lamp
[Vh1, Fh1] = mesh_box(L - 0.03, L + 0.02,  0.30*W, 0.75*W, 0.60, 0.85);
[Vh2, Fh2] = mesh_box(L - 0.03, L + 0.02, -0.75*W, -0.30*W, 0.60, 0.85);
[Vhead, Fhead] = mesh_add(Vh1, Fh1, Vh2, Fh2);
[Vk1, Fk1] = mesh_box(-0.02, 0.03,  0.30*W, 0.75*W, 0.60, 0.85);
[Vk2, Fk2] = mesh_box(-0.02, 0.03, -0.75*W, -0.30*W, 0.60, 0.85);
[Vtail, Ftail] = mesh_add(Vk1, Fk1, Vk2, Fk2);

% ---- pack every colour group into the output struct array
parts(1).V = Vbody;  parts(1).F = Fbody;  parts(1).color = body_col;
parts(2).V = Vg;     parts(2).F = Fg;     parts(2).color = glass;
parts(3).V = Vt;     parts(3).F = Ft;     parts(3).color = tyre_col;
parts(4).V = Vhead;  parts(4).F = Fhead;  parts(4).color = lamp_col;
parts(5).V = Vtail;  parts(5).F = Ftail;  parts(5).color = tail_col;
end
