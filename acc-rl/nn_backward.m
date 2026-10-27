function g = nn_backward(net, cache, dQ)
% NN_BACKWARD  Backpropagation: works out how to change every weight.
%
%   g = nn_backward(net, cache, dQ)
%
%   dQ : "blame" on each output = d(loss)/d(Q), size 8 x B.
%        (For DQN only the output of the action actually taken gets blame;
%         the other rows of dQ are zero.)
%   g  : gradients, same field names as net (g.W1, g.b1, ... g.b3).
%        g.W1(i,j) says: "if W1(i,j) goes up a tiny bit, the loss goes up
%        by g.W1(i,j) times that bit". So to REDUCE the loss we move each
%        weight a little in the OPPOSITE direction of its gradient.
%
% How it works: the CHAIN RULE from school calculus, applied layer by layer
% from the output back to the input (hence "back"-propagation):
%   Q = W3*H2 + b3   ->  dW3 = dQ*H2'  ,  db3 = sum(dQ) ,  dH2 = W3'*dQ
%   H2 = ReLU(Z2)    ->  dZ2 = dH2 where Z2>0, else 0   (ReLU slope is 1 or 0)
%   Z2 = W2*H1 + b2  ->  dW2 = dZ2*H1' ,  db2 = sum(dZ2), dH1 = W2'*dZ2
%   H1 = ReLU(Z1)    ->  dZ1 = dH1 where Z1>0, else 0
%   Z1 = W1*X + b1   ->  dW1 = dZ1*X'  ,  db1 = sum(dZ1)
% Summing over the batch (columns) adds up the blame from every example.

g.W3 = dQ * cache.H2';
g.b3 = sum(dQ, 2);
dH2  = net.W3' * dQ;

dZ2  = dH2 .* (cache.Z2 > 0);
g.W2 = dZ2 * cache.H1';
g.b2 = sum(dZ2, 2);
dH1  = net.W2' * dZ2;

dZ1  = dH1 .* (cache.Z1 > 0);
g.W1 = dZ1 * cache.X';
g.b1 = sum(dZ1, 2);
end
