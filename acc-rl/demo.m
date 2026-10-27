function demo(scenario_type, which, save_gif)
% DEMO  The 3D animated demo. You drive the lead car, the AI reacts live.
%
%   demo()                        % LIVE: you set the lead car's speed
%   demo('hard_brake')            % REPLAY: an unseen exam drive, played back
%   demo('cut_in', 2)             % the 2nd drive of that scenario family
%   demo('mixed', 1, true)        % also save an animated GIF into results/
%
% In LIVE mode, use the buttons at the top (mouse clicks):
%   slider, -1 m/s, +1 m/s     change the lead car's speed
%   Camera                     switch chase camera <-> isometric view
%   Pause                      pause / continue
%   Restart                    start the drive again
%

% In REPLAY mode:
%   Replay                     play the drive again
%   Camera                     switch the camera
%
% The window stays open until YOU close it.

if nargin < 1 || isempty(scenario_type), scenario_type = ''; end
if nargin < 2 || isempty(which), which = 1; end
if nargin < 3, save_gif = false; end

cfg = acc_config();
S = load(cfg.model_file);
agent = S.agent;                       % the trained brain, from trained_agent.mat

if isempty(scenario_type)
    run_live(cfg, agent);
else
    run_replay(cfg, agent, scenario_type, which, save_gif);
end
end

% ======================================================================
function run_live(cfg, agent)
% you drive the lead car, and both drivers react to it on the screen

if ~can_show_figures()
    error('Live mode needs a screen. Use demo(''hard_brake'') to save an animation instead.');
end

[fig, ax, gx] = make_window('ACC demo: you drive the grey lead car', 'on');
ui = new_ui(22);

% the speed slider, along the top of the window
ui.slider = uicontrol(fig, 'Style', 'slider', 'Min', 0, 'Max', 35, 'Value', 22, ...
                      'Units', 'normalized', 'Position', [0.15 0.955 0.42 0.03], ...
                      'Callback', @(s, e) on_slider(s, fig));
uicontrol(fig, 'Style', 'text', 'String', 'Lead speed:', ...
          'Units', 'normalized', 'Position', [0.01 0.95 0.13 0.04], ...
          'BackgroundColor', get(fig, 'Color'), 'HorizontalAlignment', 'right', 'FontSize', 10);
% buttons: you can click these with the mouse, no keyboard needed
add_button(fig, '-1 m/s', [0.59 0.955 0.06 0.035], 'slower');
add_button(fig, '+1 m/s', [0.66 0.955 0.06 0.035], 'faster');
add_button(fig, 'Camera', [0.73 0.955 0.09 0.035], 'camera');
add_button(fig, 'Pause',  [0.83 0.955 0.07 0.035], 'pause');
add_button(fig, 'Restart',[0.91 0.955 0.08 0.035], 'restart');
uicontrol(fig, 'Style', 'text', ...
          'String', 'Slider or buttons: lead speed     Camera: chase / overview     Pause     Restart     close the window to exit', ...
          'Units', 'normalized', 'Position', [0.03 0.0 0.94 0.03], ...
          'BackgroundColor', get(fig, 'Color'));
set(fig, 'UserData', ui, 'KeyPressFcn', @(s, e) on_key(s, e, fig));

W = demo_world('build', ax);
G = demo_graphs('build', gx, cfg);

sc = demo_sim('scenario', cfg);
sim = demo_sim('reset', sc, cfg);
hist = demo_hist('init');
hist = demo_hist('push', hist, sim, cfg);

% the main loop: move the world, draw it, repeat, until the window is closed
while ishandle(fig)
    ui = get(fig, 'UserData');
    if ui.restart
        sim = demo_sim('reset', sc, cfg);
        hist = demo_hist('init');
        hist = demo_hist('push', hist, sim, cfg);
        ui.restart = false;
        set(fig, 'UserData', ui);
    end

    if ~ui.paused && ~sim.stopped
        for j = 1:2                      % two 0.1 s steps per picture keeps it smooth
            sim = demo_sim('step', sim, ui.vt, agent, cfg);
            hist = demo_hist('push', hist, sim, cfg);
            if sim.stopped, break; end
        end
    end

    n = numel(hist.t);
    prefix = sprintf('LIVE: lead car at %.0f m/s (you set this)', ui.vt);
    demo_world('draw', W, ax, hist, n, ui.cam, prefix);
    demo_graphs('update', G, hist, n, cfg);
    drawnow;
    pause(0.03);
end
end

% ======================================================================
function run_replay(cfg, agent, scenario_type, which, save_gif)
% plays back one of the unseen exam drives, with both drivers

T = load_test_scenarios(cfg);
idx = [];
for i = 1:numel(T)
    if strcmp(T{i}.type, scenario_type), idx(end + 1) = i; end %#ok<AGROW>
end
if isempty(idx), error('Unknown scenario family: %s', scenario_type); end
pick = min(which, numel(idx));
sc = T{idx(pick)};

% run both drivers on this drive first, then play the recording
ai.type = 'rl';  ai.net = agent.net;  ai.actions = agent.actions;
bl.type = 'baseline';
[~, la] = run_episode(sc, ai, cfg);
[~, lb] = run_episode(sc, bl, cfg);
hist = demo_hist('from_logs', la, lb, cfg);
n = numel(hist.t);
prefix = sprintf('REPLAY: %s drive %d (unseen exam)', scenario_type, pick);

show = can_show_figures();
if show
    vis = 'on';
else
    vis = 'off';                         % no screen: draw invisibly, save files instead
end
[fig, ax, gx] = make_window('ACC demo: replay of an unseen drive', vis);
ui = new_ui(0);
ui.slider = [];
ui.cam = 'chase';
set(fig, 'UserData', ui, 'KeyPressFcn', @(s, e) on_key(s, e, fig));
if show
    add_button(fig, 'Camera', [0.73 0.955 0.09 0.035], 'camera');
    add_button(fig, 'Replay', [0.84 0.955 0.12 0.035], 'replay');
    uicontrol(fig, 'Style', 'text', ...
              'String', 'Replay: play the drive again     Camera: chase / overview     close the window to exit', ...
              'Units', 'normalized', 'Position', [0.03 0.0 0.94 0.03], ...
              'BackgroundColor', get(fig, 'Color'));
end

W = demo_world('build', ax);
G = demo_graphs('build', gx, cfg);

frames = play(fig, W, ax, G, hist, cfg, prefix, save_gif, show);

if ~show
    % no screen: save a picture of the last moment, and the GIF if asked
    if save_gif && ~isempty(frames)
        write_gif(frames, fullfile(cfg.results_dir, ['demo_', scenario_type, '.gif']), 10 * cfg.dt);
    end
    print(fig, '-dpng', '-r80', fullfile(cfg.results_dir, ['demo_', scenario_type, '.png']));
    close(fig);
    fprintf('Demo "%s" saved to %s\n', scenario_type, cfg.results_dir);
    return
end

% a screen is available: keep the window open until the user closes it
last_cam = get(fig, 'UserData').cam;
while ishandle(fig)
    ui = get(fig, 'UserData');
    if ui.replay
        ui.replay = false;
        set(fig, 'UserData', ui);
        play(fig, W, ax, G, hist, cfg, prefix, false, true);
        last_cam = ui.cam;
    elseif ~strcmp(ui.cam, last_cam)
        % the camera was switched: redraw the last moment from the new view
        last_cam = ui.cam;
        demo_world('draw', W, ax, hist, n, ui.cam, prefix);
        drawnow;
    end
    pause(0.05);
end
end

% ======================================================================
function frames = play(fig, W, ax, G, hist, cfg, prefix, save_gif, show)
% plays the recorded moments in order. Returns pictures if a GIF is wanted.
n = numel(hist.t);
stride = 2;                              % every 0.2 s of drive becomes one picture
if ~show
    stride = 10;                         % a saved GIF uses fewer pictures (1 s each, keeps the file smaller)
end
ks = unique([1:stride:n, n]);            % always end on the very last moment
frames = {};
for k = ks
    t0 = tic;
    if ~ishandle(fig), break; end
    ui = get(fig, 'UserData');
    demo_world('draw', W, ax, hist, k, ui.cam, prefix);
    demo_graphs('update', G, hist, k, cfg);
    drawnow;
    if save_gif
        frames{end + 1} = grab_frame(fig); %#ok<AGROW>
    end
    if show
        % keep the playback in real time: about 0.2 s of drive per picture
        pause(max(0, stride * cfg.dt - toc(t0)));
    end
end
end

% ======================================================================
function [fig, ax, gx] = make_window(name, visible)
% creates the window: the big 3D scene on top, three small graphs below
fig = figure('Name', name, 'NumberTitle', 'off', 'Color', [0.94 0.94 0.94], ...
             'Position', [40 40 1000 860], 'MenuBar', 'none', 'ToolBar', 'none', ...
             'Visible', visible);
ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.02 0.41 0.96 0.40]);
% use the Position we ask for exactly (some graphics systems otherwise resize 3D axes)
try
    set(ax, 'ActivePositionProperty', 'position');
catch
end

% a solid strip along the top, so the tops of the trees cannot show behind the controls
uicontrol(fig, 'Style', 'text', 'String', '', 'Units', 'normalized', ...
          'Position', [0 0.935 1 0.065], 'BackgroundColor', get(fig, 'Color'));
gx(1) = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.05 0.07 0.26 0.20]);
gx(2) = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.38 0.07 0.26 0.20]);
gx(3) = axes('Parent', fig, 'Units', 'normalized', 'Position', [0.71 0.07 0.26 0.20]);
end

% ======================================================================
function ui = new_ui(vt)
% the controls shared between the window and the main loop (stored in the window)
ui.vt      = vt;           % lead car's target speed [m/s], from the slider
ui.cam     = 'chase';      % camera: 'chase' or 'iso'
ui.restart = false;        % set by R
ui.paused  = false;        % set by Space
ui.replay  = false;        % set by the Replay button
ui.slider  = [];           % handle of the slider (live mode only)
end

% ======================================================================
function on_slider(src, fig)
% the slider was moved: remember the new lead car speed
ui = get(fig, 'UserData');
ui.vt = get(src, 'Value');
set(fig, 'UserData', ui);
end

% ======================================================================
function on_key(~, ev, fig)
% a key was pressed in the window: map it to the same action as a button
switch ev.Key
    case 'uparrow',   on_action(fig, 'faster');
    case 'downarrow', on_action(fig, 'slower');
    case 'c',         on_action(fig, 'camera');
    case 'r',         on_action(fig, 'restart');
    case 'space',     on_action(fig, 'pause');
end
end

% ======================================================================
function on_action(fig, action)
% does one thing the user asked for: from a button, a key or the slider
ui = get(fig, 'UserData');
switch action
    case 'faster'
        ui.vt = min(35, ui.vt + 1);
    case 'slower'
        ui.vt = max(0, ui.vt - 1);
    case 'camera'
        if strcmp(ui.cam, 'chase'), ui.cam = 'iso'; else, ui.cam = 'chase'; end
    case 'pause'
        ui.paused = ~ui.paused;
    case 'restart'
        ui.restart = true;
    case 'replay'
        ui.replay = true;
end
if ~isempty(ui.slider) && ishandle(ui.slider)
    set(ui.slider, 'Value', ui.vt);      % keep the slider in step with the buttons
end
set(fig, 'UserData', ui);
end

% ======================================================================
function add_button(fig, label, pos, action)
% a clickable button; clicking it does the action named in 'action'
uicontrol(fig, 'Style', 'pushbutton', 'String', label, 'FontSize', 10, ...
          'Units', 'normalized', 'Position', pos, ...
          'Callback', @(s, e) on_action(fig, action));
end

% ======================================================================
function T = load_test_scenarios(cfg)
% loads the fixed unseen exam drives (or makes them the first time)
if exist(cfg.test_file, 'file')
    S = load(cfg.test_file);
    T = S.test_scs;                      % same variable name evaluate.m uses
else
    T = make_scenarios('test', 15, cfg.seed_test, cfg);
    test_scs = T;                        %#ok<NASGU>
    save(cfg.test_file, 'test_scs', '-v7');
end
end

% ======================================================================
function frame = grab_frame(fig)
% takes a picture of the window. MATLAB has getframe; Octave saves a PNG.
try
    fr = getframe(fig);
    frame = fr.cdata(1:2:end, 1:2:end, :);      % half size keeps the GIF small
catch
    tmp = [tempname(), '.png'];
    print(fig, '-dpng', '-r60', tmp);
    img = imread(tmp);
    frame = img(1:2:end, 1:2:end, :);
    delete(tmp);
end
end

% ======================================================================
function write_gif(frames, file, delay)
% saves a list of pictures as an animated GIF. GIF can only hold 256
% colours, so every picture is squeezed onto one fixed set of 216 colours.
lv = (0:5)' / 5;
[R, G, B] = ndgrid(lv, lv, lv);
map = [R(:), G(:), B(:)];
for i = 1:numel(frames)
    q = round(double(frames{i}) / 255 * 5);
    A = uint8(q(:, :, 1) + 6 * q(:, :, 2) + 36 * q(:, :, 3));
    if i == 1
        imwrite(A, map, file, 'gif', 'LoopCount', Inf, 'DelayTime', delay);
    else
        imwrite(A, map, file, 'gif', 'WriteMode', 'append', 'DelayTime', delay);
    end
end
end
