function best = tune_baseline()
% TUNE_BASELINE  Fairly tunes the conventional ACC controller.
%
% We try many combinations of the five settings [kp kd kv e_max ka] and score each
% combination on TRAINING-style scenarios (never the test scenarios),
% using exactly the same reward the AI is trained with. Any combination
% that crashes even once is thrown out. The best one is printed, and it
% is the default inside baseline_acc.m.
%
% Two rounds: a coarse grid over a wide area, then a fine grid around
% the winner (like searching a city first, then a street).

cfg = acc_config();
scs = make_scenarios('train', 3, 99, cfg);    % 21 tuning scenarios (own seed)
ctrl.type = 'baseline';

kp_list = [0.2 0.3 0.45 0.6];
kd_list = [0.4 0.7 1.0 1.4];
kv_list = [0.7 1.0 1.25];
em_list = [10 20 inf];                % inf = no cap (the plain PD law)
ka_list = [0 0.6 1.2];                % 0 = no feed-forward (the older design)
best = search(kp_list, kd_list, kv_list, em_list, ka_list, scs, ctrl, cfg);
fprintf('Coarse best: kp=%.3f kd=%.3f kv=%.3f e_max=%.1f ka=%.2f  score=%.2f\n', best.g, best.score);

g = best.g;
kp_list = g(1) * [0.8 1 1.25];
kd_list = g(2) * [0.8 1 1.25];
kv_list = g(3) * [0.8 1 1.25];
em_list = unique(g(4) * [0.7 1 1.4]);
ka_list = unique(max(0, g(5) + [-0.3 0 0.3]));
best = search(kp_list, kd_list, kv_list, em_list, ka_list, scs, ctrl, cfg);
fprintf('Fine best:   kp=%.3f kd=%.3f kv=%.3f e_max=%.1f ka=%.2f  score=%.2f\n', best.g, best.score);
end

function best = search(kp_list, kd_list, kv_list, em_list, ka_list, scs, ctrl, cfg)
best.score = -inf; best.g = [];
for kp = kp_list
    for kd = kd_list
        for kv = kv_list
          for em = em_list
           for ka = ka_list
            ctrl.gains = [kp kd kv em ka];
            total = 0; crashed = false;
            for i = 1:numel(scs)
                [R, lg] = run_episode(scs{i}, ctrl, cfg);
                total = total + R;
                if lg.collided, crashed = true; break; end
            end
            score = total / numel(scs);
            if ~crashed && score > best.score
                best.score = score; best.g = [kp kd kv em ka];
            end
           end
          end
        end
    end
end
end
