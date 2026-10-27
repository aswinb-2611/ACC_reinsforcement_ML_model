function [V, F] = mesh_box(x0, x1, y0, y1, z0, z1)
% MESH_BOX  Makes a solid box, the basic building block of the 3D picture.
%
%   [V, F] = mesh_box(x0, x1, y0, y1, z0, z1)
%
% A box has 8 corner points (V, one per row, as [x y z]) and 6 square
% faces (F, one per row, listing 4 corner numbers each). MATLAB's patch
% command draws a 3D shape from exactly this kind of list.

% the 8 corners: first the 4 at the bottom (z0), then the 4 at the top (z1)
V = [x0 y0 z0;
     x1 y0 z0;
     x1 y1 z0;
     x0 y1 z0;
     x0 y0 z1;
     x1 y0 z1;
     x1 y1 z1;
     x0 y1 z1];

% the 6 faces: bottom, top, and the four sides, as lists of corner numbers
F = [1 2 3 4;
     5 6 7 8;
     1 2 6 5;
     2 3 7 6;
     3 4 8 7;
     4 1 5 8];
end
