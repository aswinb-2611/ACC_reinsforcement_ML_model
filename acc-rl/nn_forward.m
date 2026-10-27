function [Q, cache] = nn_forward(net, X)
% NN_FORWARD  Runs inputs through the network (the "forward pass").
%
%   [Q, cache] = nn_forward(net, X)
%
%   X : inputs, one column per example (5 x B). B can be 1 (one state)
%       or many (a mini-batch of states, processed all at once).
%   Q : outputs, one column per example (8 x B), one score per action.
%   cache : the in-between values, saved because backpropagation needs them.
%
% Every layer does the same two simple things:
%   z = W * x + b        (weighted sum: "how much evidence for each neuron")
%   h = max(z, 0)        (ReLU: keep positive evidence, replace negative by 0)
% The last layer has no ReLU, because Q-values can be negative.

Z1 = net.W1 * X + net.b1;     % layer 1 weighted sums  (64 x B)
H1 = max(Z1, 0);              % layer 1 ReLU
Z2 = net.W2 * H1 + net.b2;    % layer 2 weighted sums  (64 x B)
H2 = max(Z2, 0);              % layer 2 ReLU
Q  = net.W3 * H2 + net.b3;    % output layer           (8 x B)

if nargout > 1
    cache.X = X; cache.Z1 = Z1; cache.H1 = H1; cache.Z2 = Z2; cache.H2 = H2;
end
end
