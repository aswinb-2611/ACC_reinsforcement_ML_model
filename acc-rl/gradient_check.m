function max_rel_err = gradient_check()
% GRADIENT_CHECK  Proves our hand-written backpropagation is correct.
%
% Idea: for any weight w, the gradient is "how much the loss changes when
% w changes a tiny bit". We can MEASURE that directly:
%       numeric gradient ~= ( L(w + h) - L(w - h) ) / (2h),   h = 1e-5
% and compare it with what nn_backward() CALCULATES with the chain rule.
% If they agree to about 1e-6 or better, the backpropagation is right.
%
% We use a small network (5 -> 7 -> 6 -> 4) and a DQN-style loss where only
% one output per example (the action taken) has a target:
%       L = 0.5 * sum( (Q(action) - target)^2 )

set_seed(42);
net = nn_init(5, [7 6], 4);
% make biases non-zero so they are tested properly too
net.b1 = 0.1 * randn(size(net.b1));
net.b2 = 0.1 * randn(size(net.b2));
net.b3 = 0.1 * randn(size(net.b3));
net.W3 = randn(size(net.W3)) * 0.5;

B = 6;                                   % 6 example states
X = randn(5, B);
acts = randi(4, 1, B);                   % action taken in each example
M = zeros(4, B);
M(sub2ind(size(M), acts, 1:B)) = 1;      % mask: 1 only for the taken action
Y = randn(4, B);                         % pretend targets

% ---- analytic gradient (our backprop)
[Q, cache] = nn_forward(net, X);
dQ = M .* (Q - Y);
g = nn_backward(net, cache, dQ);

% ---- numeric gradient, weight by weight
h = 1e-5;
f = {'W1', 'b1', 'W2', 'b2', 'W3', 'b3'};
max_rel_err = 0;
fprintf('\nGradient check (backprop vs. measured slope):\n');
for i = 1:numel(f)
    P = net.(f{i});
    num = zeros(size(P));
    for j = 1:numel(P)
        netp = net; netp.(f{i})(j) = P(j) + h;
        netm = net; netm.(f{i})(j) = P(j) - h;
        Lp = loss(netp, X, M, Y);
        Lm = loss(netm, X, M, Y);
        num(j) = (Lp - Lm) / (2 * h);
    end
    ana = g.(f{i});
    rel = norm(num(:) - ana(:)) / max(1e-12, norm(num(:)) + norm(ana(:)));
    max_rel_err = max(max_rel_err, rel);
    fprintf('  %-3s  relative error = %.2e\n', f{i}, rel);
end
if max_rel_err < 1e-6
    fprintf('  PASSED: backpropagation matches the numeric gradient.\n\n');
else
    fprintf('  WARNING: gradients disagree, check nn_backward.m\n\n');
end
end

function L = loss(net, X, M, Y)
Q = nn_forward(net, X);
L = 0.5 * sum(sum(M .* (Q - Y) .^ 2));
end
