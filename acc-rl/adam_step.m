function [net, opt] = adam_step(net, g, opt)
% ADAM_STEP  Moves every weight one small step to reduce the loss.
%
%   [net, opt] = adam_step(net, g, opt)
%
% Formulas (for each weight w with gradient g):
%   m = beta1*m + (1-beta1)*g          smoothed gradient
%   v = beta2*v + (1-beta2)*g.^2       smoothed squared gradient
%   m_hat = m / (1 - beta1^t)          correction: m and v start at 0,
%   v_hat = v / (1 - beta2^t)          so early on they are too small
%   w = w - lr * m_hat / (sqrt(v_hat) + eps)
opt.t = opt.t + 1;
c1 = 1 - opt.beta1 ^ opt.t;
c2 = 1 - opt.beta2 ^ opt.t;
for i = 1:numel(opt.fields)
    f = opt.fields{i};
    opt.m.(f) = opt.beta1 * opt.m.(f) + (1 - opt.beta1) * g.(f);
    opt.v.(f) = opt.beta2 * opt.v.(f) + (1 - opt.beta2) * (g.(f) .^ 2);
    m_hat = opt.m.(f) / c1;
    v_hat = opt.v.(f) / c2;
    net.(f) = net.(f) - opt.lr * m_hat ./ (sqrt(v_hat) + opt.eps);
end
end
