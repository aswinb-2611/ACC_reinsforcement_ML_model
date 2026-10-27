function net = nn_init(n_in, n_hidden, n_out)
% NN_INIT  Creates a brand new neural network with random starting weights.
%
%   net = nn_init(5, [64 64], 8)
%
% Shape of our network (a "multi-layer perceptron", MLP):
%
%    5 inputs  ->  64 neurons  ->  64 neurons  ->  8 outputs
%    (state)       (hidden 1)      (hidden 2)      (one Q-value per action)
%
% Each layer has a WEIGHT matrix W (how strongly each input matters to each
% neuron) and a BIAS vector b (a neuron's own offset). Learning = slowly
% adjusting all these numbers.
%
% Starting values: small random numbers ("He initialisation"). If all
% weights started equal, every neuron would learn the same thing, so we
% need randomness. The size sqrt(2/fan_in) keeps signals from blowing up
% or dying out as they pass through ReLU layers.

h1 = n_hidden(1);
h2 = n_hidden(2);
net.W1 = randn(h1, n_in) * sqrt(2 / n_in);
net.b1 = zeros(h1, 1);
net.W2 = randn(h2, h1) * sqrt(2 / h1);
net.b2 = zeros(h2, 1);
net.W3 = randn(n_out, h2) * sqrt(1 / h2) * 0.1;   % small: start with near-zero Q-values
net.b3 = zeros(n_out, 1);
end
