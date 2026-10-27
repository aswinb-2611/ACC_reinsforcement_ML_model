function scs = make_scenarios(setname, n_per_type, seed, cfg)
% MAKE_SCENARIOS  Builds a list (cell array) of scenarios.
%
%   scs = make_scenarios('test', 15, cfg.seed_test, cfg)
%
% 'train' and 'val' use the six training scenario families.
% 'test' uses the same six families with DIFFERENT number ranges and seed,
% plus a seventh family ('mixed') that never appears in training at all.

set_seed(seed);
types = {'constant', 'stop_and_go', 'hard_brake', 'slow_then_fast', ...
         'cut_in', 'random_smooth'};
if strcmp(setname, 'test')
    types{end + 1} = 'mixed';
    profile_set = 'test';
else
    types{end + 1} = 'live_like';      % practice for the live demo (never in the exam)
    profile_set = 'train';
end

scs = {};
for i = 1:n_per_type
    for j = 1:numel(types)
        sc = lead_profile(types{j}, profile_set, cfg);
        sc.id = numel(scs) + 1;
        scs{end + 1} = sc; %#ok<AGROW>
    end
end
end
