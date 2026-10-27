function tf = can_show_figures()
% CAN_SHOW_FIGURES  True if a screen is available to show live windows.
% (When running on a server or with "matlab -batch", there is no screen,
%  so we only save pictures to the results folder.)
if exist('OCTAVE_VERSION', 'builtin')
    tf = ispc() || ~isempty(getenv('DISPLAY'));
    return
end

% MATLAB. We do NOT use usejava('desktop'): from MATLAB R2025a the desktop
% is no longer built on Java, so that check says "no screen" even when
% you are looking at one. Instead we ask two simpler questions.
tf = true;
try
    if batchStartupOptionUsed()          % started with "matlab -batch"
        tf = false;
    end
catch
    % older MATLAB without this function: keep going
end
try
    if ~feature('ShowFigureWindows')     % started with "matlab -nodisplay"
        tf = false;
    end
catch
    % if MATLAB cannot answer, assume there is a screen
end
end
