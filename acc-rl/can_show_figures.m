function tf = can_show_figures()
% CAN_SHOW_FIGURES  True if a screen is available to show live windows.
% (When running on a server or with "matlab -batch", there is no screen,
%  so we only save pictures to the results folder.)
if exist('OCTAVE_VERSION', 'builtin')
    tf = ispc() || ~isempty(getenv('DISPLAY'));
else
    tf = usejava('desktop');
end
end
