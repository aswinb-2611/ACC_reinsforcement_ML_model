function [S, A, R, S2, D] = replay_sample(buf, B)
% REPLAY_SAMPLE  Picks B random experiences from the notebook (a mini-batch).
idx = randi(buf.n, 1, B);
S  = buf.S(:, idx);
A  = buf.A(idx);
R  = buf.R(idx);
S2 = buf.S2(:, idx);
D  = buf.D(idx);
end
