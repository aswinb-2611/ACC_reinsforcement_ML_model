function [V, F] = mesh_wheel(cx, cz, r, y_in, y_out, n)
% MESH_WHEEL  Makes a round tyre (a short cylinder) for the 3D car.
%
%   [V, F] = mesh_wheel(cx, cz, r, y_in, y_out, n)
%
%   cx, cz : centre of the wheel along the car (x) and height (z)
%   r      : tyre radius [m]
%   y_in   : sideways position of the wheel face closest to the car middle
%   y_out  : sideways position of the outer wheel face
%   n      : how many straight sides the circle has (more = rounder)
%
% The circle is built from n points on each face. The sides are quads,
% and the two round ends are closed with thin triangles.

th = 2 * pi * (0:n - 1) / n;               % n evenly spaced angles around the circle
ring_in  = [cx + r * cos(th)', y_in  * ones(n, 1), cz + r * sin(th)'];
ring_out = [cx + r * cos(th)', y_out * ones(n, 1), cz + r * sin(th)'];
c_in  = [cx, y_in,  cz];                   % middle point of the inner end
c_out = [cx, y_out, cz];                   % middle point of the outer end

V = [ring_in; ring_out; c_in; c_out];     % points 1..n inner, n+1..2n outer, then the 2 centres
F = zeros(0, 4);
for i = 1:n
    j = mod(i, n) + 1;                     % the next point around the circle
    F(end + 1, :) = [i, j, n + j, n + i];          %#ok<AGROW> round side of the tyre
    F(end + 1, :) = [2*n + 1, i, j, j];            %#ok<AGROW> inner end (a triangle)
    F(end + 1, :) = [2*n + 2, n + j, n + i, n + i]; %#ok<AGROW> outer end (a triangle)
end
end
