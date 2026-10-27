function buf = replay_init(capacity, nS)
% REPLAY_INIT  Creates an empty experience replay buffer.
%
% The buffer is the AI's notebook of past moments. Each entry stores one
% "experience" = (state s, action a, reward r, next state s2, done d):
%   "I was in situation s, I pressed pedal a, I got r marks, and the world
%    became s2 (d = 1 means the episode ended there with a crash)."
%
% Why keep a notebook instead of learning only from the latest moment?
%   1) Consecutive moments are almost identical (0.1 s apart). Learning
%      from a random mix of old moments is far more stable.
%   2) Rare events (like a hard brake) can be re-studied many times.
% When full, the oldest entries are overwritten (a circular buffer).
buf.S   = zeros(nS, capacity);
buf.A   = zeros(1, capacity);
buf.R   = zeros(1, capacity);
buf.S2  = zeros(nS, capacity);
buf.D   = zeros(1, capacity);
buf.cap = capacity;
buf.ptr = 0;        % where the newest entry was written
buf.n   = 0;        % how many entries are filled
end
