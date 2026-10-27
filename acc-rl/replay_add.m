function buf = replay_add(buf, S, A, R, S2, D)
% REPLAY_ADD  Writes experiences into the notebook (overwrites the oldest when full).
%
%   buf = replay_add(buf, S, A, R, S2, D)
%
% S and S2 can hold one column (one experience) or many columns (a whole
% episode at once). train.m adds a whole episode at once because copying
% the big notebook once per episode is much faster than once per step.
n = size(S, 2);
idx = mod(buf.ptr + (0:n - 1), buf.cap) + 1;   % next n slots, wrapping around
buf.S(:, idx)  = S;
buf.A(idx)     = A;
buf.R(idx)     = R;
buf.S2(:, idx) = S2;
buf.D(idx)     = D;
buf.ptr = idx(end);
buf.n   = min(buf.n + n, buf.cap);
end
