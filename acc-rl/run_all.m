% RUN_ALL  One command to do everything.
%
%   >> run_all
%
% 1. Checks the hand-written backpropagation (gradient check).
% 2. Trains the AI driver, ONLY if trained_agent.mat does not exist yet
%    (delete that file if you want to retrain from scratch, about 20-40 min).
% 3. Runs the final exam on the unseen test scenarios and saves results.
% 4. Launches the animated demo.

clc;
here = fileparts(mfilename('fullpath'));
cd(here);
addpath(here);
cfg = acc_config();

fprintf('=== Step 1: gradient check ===\n');
gradient_check();

fprintf('=== Step 2: training ===\n');
if exist(cfg.model_file, 'file')
    fprintf('trained_agent.mat found, skipping training (delete it to retrain).\n');
else
    train();
end

fprintf('=== Step 3: evaluation on unseen scenarios ===\n');
evaluate();

fprintf('=== Step 4: demo ===\n');
demo('hard_brake');
