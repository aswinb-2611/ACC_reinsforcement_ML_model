function [V, F] = mesh_ball(cx, cy, cz, rx, rz, n)
% MESH_BALL  Makes a rounded ball (used for the crowns of leafy trees).
%
%   [V, F] = mesh_ball(cx, cy, cz, rx, rz, n)
%
%   cx, cy, cz : centre of the ball
%   rx         : sideways radius [m]
%   rz         : up-down radius [m] (a little smaller looks like a real tree)
%   n          : detail level (6 to 10 is plenty)
%
% Built like a globe: lines of latitude and longitude make square faces.

lat = linspace(-pi/2, pi/2, n + 1);      % from the bottom pole to the top pole
lon = linspace(0, 2*pi, 2*n + 1);
lon = lon(1:end - 1);                    % the last line would repeat the first
nl = numel(lon);
V = zeros((n + 1) * nl, 3);
for a = 1:n + 1
    for b = 1:nl
        V((a - 1) * nl + b, :) = [cx + rx * cos(lat(a)) * cos(lon(b)), ...
                                  cy + rx * cos(lat(a)) * sin(lon(b)), ...
                                  cz + rz * sin(lat(a))];
    end
end
F = zeros(n * nl, 4);
c = 0;
for a = 1:n
    for b = 1:nl
        b2 = mod(b, nl) + 1;
        c = c + 1;
        F(c, :) = [(a - 1) * nl + b, (a - 1) * nl + b2, a * nl + b2, a * nl + b];
    end
end
end
