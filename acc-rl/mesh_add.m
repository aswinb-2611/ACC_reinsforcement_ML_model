function [V, F] = mesh_add(V, F, V2, F2)
% MESH_ADD  Glues a second shape onto the first one, into one big list.
%
%   [V, F] = mesh_add(V, F, V2, F2)
%
% Each shape numbers its own corners from 1. When we join two shapes, the
% second shape's numbers must be moved past the corners we already have.
% Example: the first shape has 8 corners, so a face [1 2 3 4] in the second
% shape becomes [9 10 11 12] after joining.

F = [F; F2 + size(V, 1)];
V = [V; V2];
end
