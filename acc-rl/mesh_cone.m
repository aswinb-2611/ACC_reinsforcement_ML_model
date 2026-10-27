function [V, F] = mesh_cone(cx, cy, z0, r, h, n)
% MESH_CONE  Makes a cone (used for the crowns of pine trees).
%
%   [V, F] = mesh_cone(cx, cy, z0, r, h, n)
%
%   cx, cy : where the cone stands on the ground plan
%   z0     : height of the cone's flat base
%   r, h   : base radius and height [m]
%   n      : number of sides (more = rounder)
%
% The cone is n thin triangles from the base circle up to the tip, plus a
% flat bottom. Triangles are written as 4-corner faces with the last
% corner repeated, so they fit in the same list as square faces.

th = 2 * pi * (0:n - 1)' / n;
ring = [cx + r * cos(th), cy + r * sin(th), z0 * ones(n, 1)];
tip  = [cx, cy, z0 + h];
mid  = [cx, cy, z0];
V = [ring; tip; mid];                    % points 1..n ring, n+1 tip, n+2 base centre
F = zeros(2 * n, 4);
for i = 1:n
    j = mod(i, n) + 1;
    F(2*i - 1, :) = [i, j, n + 1, n + 1];    % side triangle
    F(2*i, :)     = [n + 2, j, i, i];        % bottom triangle
end
end
