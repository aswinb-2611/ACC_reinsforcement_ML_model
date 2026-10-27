function agent = train(n_episodes, seed)
% TRAIN  Trains the Deep Q-Network (DQN) driver from scratch.
%
%   agent = train()          % full training: 800 episodes, seed 1
%   agent = train(200)       % shorter, for a quick experiment
%   agent = train(800, 2)    % same, with a different random seed
%
% What happens, in plain words:
%   1. A brand-new network with random weights is created (it knows nothing).
%   2. For each episode (one 60 s practice drive in a random traffic
%      situation) the agent drives, sometimes trying random pedals
%      (exploring), and writes every moment into its replay notebook.
%   3. After every step it studies a random handful (mini-batch) of old
%      moments and nudges its weights to predict marks better (agent_learn).
%   4. Every 10 episodes it takes a "mock test" on 18 fixed validation
%      drives with NO random pedals. The best crash-free mock-test brain
%      is kept (not simply the last one, which may have had a bad day).
%   5. The best brain is saved to trained_agent.mat.
%
% The live window shows the REWARD CURVE: total marks per practice episode.
% Rising curve = the driver is improving.

if nargin < 1 || isempty(n_episodes), n_episodes = 800; end
cfg = acc_config();
if nargin < 2 || isempty(seed), seed = cfg.seed_train; end
if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
t0 = tic;

% ---------------- Hyper-parameters (the knobs of learning) ----------------
hp.hidden      = [64 64];   % two hidden layers of 64 neurons
hp.gamma       = 0.99;      % how much the future matters (0.99 -> about 10 s ahead)
hp.lr          = 5e-4;      % learning rate at the start: size of each weight nudge
hp.lr_end      = 1e-4;      % learning rate at the end (smaller, careful steps)
hp.batch       = 64;        % experiences studied per learning step
hp.buffer      = 100000;    % notebook size (about 170 episodes of memories)
hp.warmup      = 3000;      % steps of driving before learning starts
hp.train_every = 1;         % learn after every step
hp.target_sync = 2000;      % copy online net -> target net every 2000 steps
hp.eps_start   = 1.0;       % start fully random
hp.eps_end     = 0.05;      % end with 5% random pedals
hp.eps_decay_episodes = round(0.6 * n_episodes);   % shrink over 60% of training
hp.huber       = 5;         % Huber loss threshold
hp.clip        = 10;        % maximum gradient size
hp.val_every   = 10;        % mock test every 10 episodes
hp.n_episodes  = n_episodes;
hp.seed        = seed;

show = can_show_figures();
fig = [];
if show, fig = figure('Name', 'ACC-RL training: reward curve'); end

set_seed(seed);
net = nn_init(cfg.nS, hp.hidden, cfg.nA);           % a brand-new random brain
val_scs = make_val_set(cfg);
best.score = -inf; best.net = net; best.ep = 0;
hist = empty_hist();
fprintf('\nTraining a DQN driver from scratch for %d episodes (seed %d)...\n', n_episodes, seed);
[best, net_last, hist] = train_loop(net, hp, cfg, val_scs, best, hist, 0, fig, show);

if isinf(best.score)
    warning('No crash-free mock test was achieved; saving the final network instead.');
    best.net = net_last; best.ep = n_episodes;
end

agent.net  = best.net;                 % THE trained brain used by evaluate and demo
agent.best_episode   = best.ep;
agent.best_val_score = best.score;
agent.hp   = hp;
agent.actions = cfg.actions;
agent.hist = hist;
agent.train_minutes = toc(t0) / 60;
agent.created = datestr(now);
save(cfg.model_file, 'agent', '-v7');

if isempty(fig) || ~ishandle(fig), fig = figure('visible', 'off'); end
figure(fig); plot_training(hist, n_episodes, best);
print(fig, '-dpng', '-r100', fullfile(cfg.results_dir, 'training_reward_curve.png'));
if ~show, close(fig); end

fprintf('\nDone in %.1f minutes. Best mock-test brain came from episode %d (score %.1f).\n', ...
        agent.train_minutes, best.ep, best.score);
fprintf('Saved to %s\n', cfg.model_file);
end

% ======================================================================
function [best, net, hist] = train_loop(net, hp, cfg, val_scs, best, hist, ep0, fig, show)
% The training loop itself. ep0 = how many episodes came before (for numbering).
train_types = {'constant', 'stop_and_go', 'hard_brake', 'slow_then_fast', ...
               'cut_in', 'random_smooth'};
% how often each family is practised: the dangerous ones a bit more often
% (like extra emergency-stop lessons for a learner driver)
type_weights = [1, 1.5, 2, 1, 1.5, 1.5];
type_cum = cumsum(type_weights) / sum(type_weights);

target = net;                                   % target starts as an exact copy
opt    = adam_init(net, hp.lr);
buf    = replay_init(hp.buffer, cfg.nS);
n_episodes = hp.n_episodes;
total_steps = 0;

fprintf(' ep | scenario        | return | crash | epsilon |  loss  | mock test\n');
for e = 1:n_episodes
    ep = ep0 + e;                               % overall episode number
    % epsilon shrinks in a straight line from eps_start to eps_end
    frac = min(1, (e - 1) / max(1, hp.eps_decay_episodes));
    epsilon = hp.eps_start + frac * (hp.eps_end - hp.eps_start);
    % learning rate also shrinks in a straight line over training
    opt.lr = hp.lr + (e - 1) / max(1, n_episodes - 1) * (hp.lr_end - hp.lr);

    % a fresh random practice situation
    type = train_types{find(rand() <= type_cum, 1)};
    sc = lead_profile(type, 'train', cfg);
    env = env_reset(sc, cfg);
    s = env_observe(env, cfg);

    % small notepad for this episode's memories
    eS = zeros(cfg.nS, cfg.N); eA = zeros(1, cfg.N); eR = zeros(1, cfg.N);
    eS2 = zeros(cfg.nS, cfg.N); eD = zeros(1, cfg.N);
    n = 0; G = 0; losses = [];

    while ~env.done
        ia = agent_act(net, s, epsilon, cfg.nA);           % choose a pedal
        [env, r, ~, info] = env_step(env, cfg.actions(ia), cfg);
        s2 = env_observe(env, cfg);
        n = n + 1;
        eS(:, n) = s; eA(n) = ia; eR(n) = r; eS2(:, n) = s2;
        eD(n) = double(info.collided);   % time-up is NOT a real ending
        G = G + r;
        s = s2;
        total_steps = total_steps + 1;

        % study a mini-batch from the notebook
        if buf.n >= hp.warmup && mod(total_steps, hp.train_every) == 0
            [S, A, R, S2, D] = replay_sample(buf, hp.batch);
            [net, opt, L] = agent_learn(net, target, opt, S, A, R, S2, D, hp);
            losses(end + 1) = L; %#ok<AGROW>
        end
        % refresh the frozen target network now and then
        if mod(total_steps, hp.target_sync) == 0
            target = net;
        end
    end
    buf = replay_add(buf, eS(:, 1:n), eA(1:n), eR(1:n), eS2(:, 1:n), eD(1:n));

    hist.ep_return(ep) = G;
    hist.ep_type{ep}   = type;
    hist.ep_crash(ep)  = env.collided;
    hist.epsilon(ep)   = epsilon;
    hist.loss(ep)      = NaN;
    if ~isempty(losses), hist.loss(ep) = mean(losses); end

    % ---------------- mock test (validation) ----------------
    val_txt = '';
    if mod(e, hp.val_every) == 0
        [vs, vc] = validate(net, val_scs, cfg);
        hist.val_ep(end + 1) = ep;
        hist.val_score(end + 1) = vs;
        hist.val_crash(end + 1) = vc;
        % keep the best brain: no crashes first, then highest score
        better = (vc == 0) && (vs > best.score);
        if better
            best.score = vs; best.net = net; best.ep = ep;
        end
        val_txt = sprintf('score %6.1f, crashes %d%s', vs, vc, ifelse(better, '  <- best so far', ''));
    end

    fprintf('%4d | %-15s | %6.1f |  %d    |  %.2f   | %6.3f | %s\n', ep, type, G, ...
            env.collided, epsilon, hist.loss(ep), val_txt);

    % refresh the live reward curve every 10 episodes
    if show && mod(e, 10) == 0
        figure(fig); plot_training(hist, ep, best);
        drawnow;
    end
end
end

function h = empty_hist()
h.ep_return = []; h.ep_type = {}; h.ep_crash = false(0); h.epsilon = [];
h.loss = []; h.val_ep = []; h.val_score = []; h.val_crash = [];
end

function val_scs = make_val_set(cfg)
% fixed validation drives (mock test), built from their own seed, without
% disturbing the training random numbers
st = save_rng();
val_scs = make_scenarios('val', 3, cfg.seed_val, cfg);     % 18 drives
load_rng(st);
end

function [score, crashes] = validate(net, scs, cfg)
% drive every validation scenario greedily (no exploring) and average marks
ctrl.type = 'rl'; ctrl.net = net; ctrl.actions = cfg.actions;
total = 0; crashes = 0;
for i = 1:numel(scs)
    [R, lg] = run_episode(scs{i}, ctrl, cfg);
    total = total + R;
    crashes = crashes + lg.collided;
end
score = total / numel(scs);
end

function plot_training(hist, ep, best)
clf;
x = 1:ep;
y = hist.ep_return(x);
w = 20;                                     % moving average over 20 episodes
ma = zeros(size(y));
for i = x
    ma(i) = mean(y(max(1, i - w + 1):i));
end
plot(x, y, 'Color', [0.7 0.8 1.0]); hold on;
plot(x, ma, 'b', 'LineWidth', 2);
if ~isempty(hist.val_ep)
    plot(hist.val_ep, hist.val_score, 'ro-', 'LineWidth', 1.5, 'MarkerSize', 4);
end
if best.ep > 0
    plot(best.ep, best.score, 'kp', 'MarkerSize', 14, 'MarkerFaceColor', 'y');
end
crash = find(hist.ep_crash(x));
if ~isempty(crash)
    plot(crash, y(crash), 'kx', 'MarkerSize', 5);
end
legend({'each practice episode', '20-episode average', 'mock test (no exploring)', 'best (saved) brain'}, ...
       'Location', 'southeast');
grid on; xlabel('episode'); ylabel('total reward (marks) per episode');
title(sprintf('DQN training reward curve (episode %d)   x = crash', ep));
hold off;
end

function out = ifelse(c, a, b)
if c, out = a; else, out = b; end
end

function st = save_rng()
if exist('rng', 'file') || exist('rng', 'builtin'), st = rng(); else, st = rand('state'); end %#ok<RAND>
end

function load_rng(st)
if exist('rng', 'file') || exist('rng', 'builtin'), rng(st); else, rand('state', st); end %#ok<RAND>
end
