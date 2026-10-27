function opt = adam_init(net, lr)
% ADAM_INIT  Prepares the Adam optimiser's memory for every weight.
%
% Adam is a smarter version of "step downhill". For every weight it keeps:
%   m : a running AVERAGE of recent gradients   (which way is downhill, smoothed)
%   v : a running average of SQUARED gradients  (how bumpy that direction is)
% Then each weight takes a step of about size lr in the downhill direction,
% smaller where the ground is bumpy. This makes learning steadier.
f = {'W1', 'b1', 'W2', 'b2', 'W3', 'b3'};
for i = 1:numel(f)
    opt.m.(f{i}) = zeros(size(net.(f{i})));
    opt.v.(f{i}) = zeros(size(net.(f{i})));
end
opt.t     = 0;          % how many steps taken so far
opt.lr    = lr;         % learning rate (step size), e.g. 0.0005
opt.beta1 = 0.9;        % how much memory the average m keeps
opt.beta2 = 0.999;      % how much memory the squared average v keeps
opt.eps   = 1e-8;       % tiny number to avoid dividing by zero
opt.fields = f;
end
