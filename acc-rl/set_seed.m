function set_seed(seed)
% SET_SEED  Makes the random numbers repeat exactly every time we run.
%
% Computers make "random" numbers with a formula that starts from a seed.
% Same seed -> same sequence -> same results. This is called reproducibility.
% Works in both MATLAB and Octave. (Note: MATLAB and Octave use different
% internal formulas, so the SAME seed can still give different numbers on
% the two programs. That is why the test scenarios are saved to a file.)
if exist('rng', 'file') || exist('rng', 'builtin')
    rng(seed, 'twister');
else
    rand('twister', seed);   %#ok<RAND>
    randn('twister', seed);  %#ok<RAND>
end
end
