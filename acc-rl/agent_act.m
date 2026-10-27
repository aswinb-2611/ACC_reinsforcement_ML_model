function ia = agent_act(net, s, epsilon, nA)
% AGENT_ACT  Chooses an action with the "epsilon-greedy" rule.
%
%   ia = agent_act(net, s, epsilon, nA)   returns an action NUMBER (1..nA)
%
% With probability epsilon : pick a RANDOM action  (explore: try new things)
% Otherwise                : pick the action with the highest Q-value
%                            (exploit: do what currently looks best)
%
% Example: epsilon = 0.2 means about 1 step in 5 is a random experiment.
% Early in training epsilon is 1.0 (all random, the learner knows nothing),
% and it shrinks to 0.05 as the learner becomes skilled.
if rand() < epsilon
    ia = randi(nA);
else
    q = nn_forward(net, s);
    [~, ia] = max(q);
end
end
