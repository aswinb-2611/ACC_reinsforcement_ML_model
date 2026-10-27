function [net, opt, loss] = agent_learn(net, target, opt, S, A, R, S2, D, hp)
% AGENT_LEARN  One learning step of Double DQN on a mini-batch.
%
%   [net, opt, loss] = agent_learn(net, target, opt, S, A, R, S2, D, hp)
%
%   net    : the ONLINE network (the one that is learning and driving)
%   target : the TARGET network (a frozen copy, refreshed every few thousand steps)
%   S,A,R,S2,D : a mini-batch of experiences from the replay buffer
%   hp     : hyper-parameters (gamma, huber, clip)
%
% THE CORE IDEA (Bellman equation, in words):
%   "The value of pressing pedal a now = the marks I get now
%    + gamma * the value of the best thing I can do next."
%   Q(s,a)  should equal   y = r + gamma * max_a' Q(s2, a')
%   If the episode ended with a crash (d = 1) there is no future: y = r.
%
% DOUBLE DQN detail: the ONLINE net chooses the best next action, but the
% TARGET net says how good it is. Using one net for both tends to be
% over-optimistic (it trusts its own lucky guesses), so we split the jobs.
%
% Numbers example: r = 0.8, gamma = 0.99, target net says next value = 50
%   -> y = 0.8 + 0.99*50 = 50.3. If the net currently says Q(s,a) = 48,
%   the error is 48 - 50.3 = -2.3, so the net is nudged to raise Q(s,a).

B = size(S, 2);

% ---- 1. Build the targets y (no learning happens here)
Q2_online = nn_forward(net, S2);           % online net looks at next states
[~, a_star] = max(Q2_online, [], 1);       % ... and picks its favourite actions
Q2_target = nn_forward(target, S2);        % target net judges those actions
idx2 = sub2ind(size(Q2_target), a_star, 1:B);
y = R + hp.gamma * (1 - D) .* Q2_target(idx2);

% ---- 2. Current predictions for the actions that were actually taken
[Q, cache] = nn_forward(net, S);
idx = sub2ind(size(Q), A, 1:B);
err = Q(idx) - y;                          % prediction error ("TD error")

% ---- 3. Huber loss: squared for small errors, straight line for big ones.
% This stops one surprising experience (e.g. a crash) from yanking the
% weights too hard. Its slope is the error, capped at +/- hp.huber.
loss = mean(min(abs(err), hp.huber) .* (abs(err) - 0.5 * min(abs(err), hp.huber)));
derr = max(min(err, hp.huber), -hp.huber) / B;

% ---- 4. Backpropagation: only the taken action's output gets blame
dQ = zeros(size(Q));
dQ(idx) = derr;
g = nn_backward(net, cache, dQ);

% ---- 5. Gradient clipping: if the total gradient is huge, shrink it
f = {'W1', 'b1', 'W2', 'b2', 'W3', 'b3'};
total = 0;
for i = 1:numel(f)
    total = total + sum(g.(f{i})(:) .^ 2);
end
gnorm = sqrt(total);
if gnorm > hp.clip
    for i = 1:numel(f)
        g.(f{i}) = g.(f{i}) * (hp.clip / gnorm);
    end
end

% ---- 6. Adam takes one step downhill
[net, opt] = adam_step(net, g, opt);
end
