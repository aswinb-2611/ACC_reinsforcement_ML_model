function demo(scenario_type, which, save_gif)
% DEMO  The 3D driving demo. You drive the grey car, the AI follows it.
%
%   demo()                        % LIVE: you drive the grey lead car
%   demo('hard_brake')            % REPLAY: an unseen exam drive, played back
%   demo('cut_in', 2)             % the 2nd drive of that scenario family
%   demo('mixed', 1, true)        % also save an animated GIF into results/
%
% LIVE MODE: you control the GREY car in front. The BLUE car is the AI: it
% decides by itself how to follow you. Controls (top bar, or the keyboard):
%   Up / Down arrow, slider, -1 / +1   change your speed
%   STOP  (or S)                        brake your car to a stop
%   Camera (or C)                       chase view -> drone view -> driver view
%   Compare (or M)                      also show the classic controller,
%                                       driving the same road in the left lane
%   Graphs (or G)                       show / hide speed, gap and accel graphs
%   Pause (or Space), Restart (or R)
%
% REPLAY MODE: plays one of the unseen exam drives. Replay plays it again.
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
% you drive the lead car, and the AI reacts to it on the screen

if ~can_show_figures()
    error('Live mode needs a screen. Use demo(''hard_brake'') to save an animation instead.');
end

[fig, ax, UI] = make_window('ACC demo: you drive the grey car', 'on');
ui = new_ui(22);
ui.compare = false;                    % one car pair to start with: you and the AI

% the top bar: speed slider and buttons
uicontrol(UI.bar, 'Style', 'text', 'String', 'Your speed', 'Units', 'normalized', ...
          'Position', [0.005 0.15 0.08 0.7], 'FontSize', 10, 'FontWeight', 'bold', ...
          'BackgroundColor', UI.bar_col, 'ForegroundColor', [1 1 1]);
ui.slider = uicontrol(UI.bar, 'Style', 'slider', 'Min', 0, 'Max', 35, 'Value', 22, ...
                      'Units', 'normalized', 'Position', [0.09 0.28 0.22 0.44], ...
                      'Callback', @(s, e) on_slider(s, fig));
labels  = {'-1 m/s', '+1 m/s', 'STOP', 'Camera', 'Compare', 'Graphs', 'Pause', 'Restart'};
actions = {'slower', 'faster', 'stop', 'camera', 'compare', 'graphs', 'pause', 'restart'};
for i = 1:numel(labels)
    b = add_button(UI.bar, fig, labels{i}, [0.32 + 0.0825 * (i - 1) 0.15 0.075 0.7], actions{i});
    if strcmp(actions{i}, 'stop')
        set(b, 'BackgroundColor', [0.75 0.12 0.10], 'ForegroundColor', [1 1 1]);
    end
end
set(UI.help, 'String', ['You drive the GREY car (arrow keys, slider or buttons). ', ...
                        'The BLUE car is the AI: it decides by itself.   Close the window to exit.']);
set(fig, 'UserData', ui, 'KeyPressFcn', @(s, e) on_key(s, e, fig));

W = demo_world('build', ax);
G = demo_graphs('build', UI.gx, cfg);

sc = demo_sim('scenario', cfg);
sim = demo_sim('reset', sc, cfg);
hist = demo_hist('init');
hist = demo_hist('push', hist, sim, cfg);

% the main loop: move the world, draw it, repeat, until the window is closed.
% The number of 0.1 s steps per picture follows the real clock, so the
% drive runs in real time even on a slower computer.
t_last = tic;
while ishandle(fig)
    try
        ui = get(fig, 'UserData');
        if ui.restart
            sim = demo_sim('reset', sc, cfg);
            hist = demo_hist('init');
            hist = demo_hist('push', hist, sim, cfg);
            ui.restart = false;
            ui.vt = sc.vl0;                      % your car starts at 22 m/s again
            if ishandle(ui.slider), set(ui.slider, 'Value', ui.vt); end
            set(fig, 'UserData', ui);
        end

        elapsed = toc(t_last);
        t_last = tic;
        nsteps = min(5, max(1, round(elapsed / cfg.dt)));
        if ~ui.paused && ~sim.stopped
            for j = 1:nsteps
                sim = demo_sim('step', sim, ui.vt, agent, cfg);
                hist = demo_hist('push', hist, sim, cfg);
                if sim.stopped, break; end
            end
        end

        n = numel(hist.t);
        W = demo_world('draw', W, ax, hist, n, ui.cam, ui.compare);
        update_hud(UI, hist, n, ui, cfg, '');
        show_graphs(UI, G, hist, n, ui, cfg);
        drawnow;
        pause(0.01);
    catch err
        if ~ishandle(fig), break; end     % the window was closed mid-frame: just stop
        rethrow(err);
    end
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
title_txt = sprintf('REPLAY: "%s" drive %d of the unseen exam. Both drivers face the same lead car.', ...
                    strrep(scenario_type, '_', ' '), pick);

show = can_show_figures();
if show, vis = 'on'; else, vis = 'off'; end
[fig, ax, UI] = make_window('ACC demo: replay of an unseen exam drive', vis);
ui = new_ui(0);
ui.compare = true;                     % in a replay, compare both drivers
set(fig, 'UserData', ui, 'KeyPressFcn', @(s, e) on_key(s, e, fig));
labels  = {'Camera', 'Compare', 'Graphs', 'Replay'};
actions = {'camera', 'compare', 'graphs', 'replay'};
for i = 1:numel(labels)
    add_button(UI.bar, fig, labels{i}, [0.62 + 0.0825 * (i - 1) 0.15 0.075 0.7], actions{i});
end
set(UI.help, 'String', 'Grey car = the lead car of the exam drive.  Blue = AI.  Red = classic ACC.  Close the window to exit.');

W = demo_world('build', ax);
G = demo_graphs('build', UI.gx, cfg);

[W, frames] = play(fig, W, ax, UI, G, hist, cfg, title_txt, save_gif, show);

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
n = numel(hist.t);
last = get(fig, 'UserData');
while ishandle(fig)
    try
        ui = get(fig, 'UserData');
        if ui.replay
            ui.replay = false;
            set(fig, 'UserData', ui);
            W = play(fig, W, ax, UI, G, hist, cfg, title_txt, false, true);
        elseif ~strcmp(ui.cam, last.cam) || ui.compare ~= last.compare || ui.graphs ~= last.graphs
            % a button was pressed: redraw the last moment with the new setting
            W = demo_world('draw', W, ax, hist, n, ui.cam, ui.compare);
            update_hud(UI, hist, n, ui, cfg, title_txt);
            show_graphs(UI, G, hist, n, ui, cfg);
            drawnow;
        end
        last = ui;
        pause(0.05);
    catch err
        if ~ishandle(fig), break; end
        rethrow(err);
    end
end
end

% ======================================================================
function [W, frames] = play(fig, W, ax, UI, G, hist, cfg, title_txt, save_gif, show)
% plays the recorded moments in real time. Returns pictures if a GIF is wanted.
n = numel(hist.t);
frames = {};
k = 1;
t_last = tic;
while k <= n
    if ~ishandle(fig), return; end
    ui = get(fig, 'UserData');
    W = demo_world('draw', W, ax, hist, k, ui.cam, ui.compare);
    update_hud(UI, hist, k, ui, cfg, title_txt);
    show_graphs(UI, G, hist, k, ui, cfg);
    drawnow;
    if save_gif
        frames{end + 1} = grab_frame(fig); %#ok<AGROW>
    end
    if k == n, break; end
    if show
        % skip ahead by however much real time has passed (real-time playback)
        pause(0.01);
        elapsed = toc(t_last);
        t_last = tic;
        k = min(n, k + max(1, round(elapsed / cfg.dt)));
    else
        k = min(n, k + 10);              % a saved GIF: one picture per second of drive
    end
end
end

% ======================================================================
function [fig, ax, UI] = make_window(name, visible)
% the window: the 3D scene fills it; a bar on top; text and graphs on top of the scene
fig = figure('Name', name, 'NumberTitle', 'off', 'Position', [40 40 1280 800], ...
             'MenuBar', 'none', 'ToolBar', 'none', 'Visible', visible);
try
    theme(fig, 'light');                 % MATLAB R2025a+: ignore the dark desktop theme
catch
end
set(fig, 'Color', [0.10 0.11 0.13]);

ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0 0 1 0.94]);
try
    set(ax, 'PositionConstraint', 'innerposition');     % newer MATLAB
catch
    try
        set(ax, 'ActivePositionProperty', 'position');  % older MATLAB and Octave
    catch
    end
end

% the control bar along the top
UI.bar_col = [0.13 0.14 0.17];
UI.bar = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0 0.94 1 0.06], ...
                 'BackgroundColor', UI.bar_col, 'BorderType', 'none');

% the heads-up display (HUD): four lines of live numbers, top left
hud_bg = [0.07 0.08 0.10];
for i = 1:4
    UI.hud(i) = uicontrol(fig, 'Style', 'text', 'String', '', 'Units', 'normalized', ...
                          'Position', [0.01 0.895 - 0.034 * (i - 1) 0.66 0.034], ...
                          'FontSize', 11, 'HorizontalAlignment', 'left', ...
                          'BackgroundColor', hud_bg, 'ForegroundColor', [0.95 0.95 0.95]);
end
set(UI.hud(1), 'FontWeight', 'bold', 'ForegroundColor', [1 0.86 0.35]);

% a big banner for crashes and emergency braking (hidden until needed)
UI.banner = uicontrol(fig, 'Style', 'text', 'String', '', 'Units', 'normalized', ...
                      'Position', [0.30 0.50 0.40 0.07], 'FontSize', 20, 'FontWeight', 'bold', ...
                      'BackgroundColor', [0.75 0.10 0.10], 'ForegroundColor', [1 1 1], ...
                      'Visible', 'off');

% the graphs live on a white panel at the bottom (hidden until Graphs is pressed)
UI.gpanel = uipanel('Parent', fig, 'Units', 'normalized', 'Position', [0 0.03 1 0.29], ...
                    'BackgroundColor', [1 1 1], 'BorderType', 'none', 'Visible', 'off');
for i = 1:3
    UI.gx(i) = axes('Parent', UI.gpanel, 'Units', 'normalized', ...
                    'Position', [0.05 + 0.33 * (i - 1) 0.22 0.27 0.64]);
end

% one line of help along the bottom
UI.help = uicontrol(fig, 'Style', 'text', 'String', '', 'Units', 'normalized', ...
                    'Position', [0 0 1 0.03], 'FontSize', 10, ...
                    'BackgroundColor', hud_bg, 'ForegroundColor', [0.85 0.85 0.85]);
end

% ======================================================================
function update_hud(UI, hist, k, ui, cfg, title_txt)
% writes the live numbers in the four HUD lines, and shows the banner
if isempty(title_txt)
    l1 = sprintf('YOU drive the GREY car:  target %2.0f m/s,  now %4.1f m/s', ui.vt, hist.vl(k));
else
    l1 = title_txt;
end
l2 = sprintf('AI (blue):   %4.1f m/s    gap %5.1f m    safe gap %5.1f m    ->  %s', ...
             hist.ve_a(k), hist.gap_a(k), hist.dsafe(k), ...
             status_of(hist.gap_a(k), hist.ve_a(k), hist.vl(k), hist.ae_a(k), hist.aeb_a(k), hist.dsafe(k), cfg));
if ui.compare
    l3 = sprintf('Classic ACC (red, left lane):   %4.1f m/s    gap %5.1f m    ->  %s', ...
                 hist.ve_b(k), hist.gap_b(k), ...
                 status_of(hist.gap_b(k), hist.ve_b(k), hist.vl(k), hist.ae_b(k), hist.aeb_b(k), hist.dsafe_b(k), cfg));
else
    l3 = 'Press Compare to watch the classic controller drive the same road in the left lane.';
end
l4 = sprintf('Emergency brake (AEB) needed:  AI %d,  classic %d        time %5.1f s        camera: %s', ...
             hist.n_aeb_a(k), hist.n_aeb_b(k), hist.t(k), ui.cam);
set(UI.hud(1), 'String', l1);
set(UI.hud(2), 'String', l2);
set(UI.hud(3), 'String', l3);
set(UI.hud(4), 'String', l4);

% the banner: a crash is shown in red, emergency braking in orange
if hist.gap_a(k) <= 0
    set(UI.banner, 'String', 'AI CRASHED  -  press Restart', 'BackgroundColor', [0.75 0.10 0.10], 'Visible', 'on');
elseif ui.compare && hist.gap_b(k) <= 0
    set(UI.banner, 'String', 'Classic ACC crashed', 'BackgroundColor', [0.75 0.10 0.10], 'Visible', 'on');
elseif hist.aeb_a(k)
    set(UI.banner, 'String', 'AI: EMERGENCY BRAKE!', 'BackgroundColor', [0.85 0.42 0.05], 'Visible', 'on');
else
    set(UI.banner, 'Visible', 'off');
end
end

% ======================================================================
function s = status_of(gap, v, vl, a, aeb_on, dsafe, cfg)
% one short word or phrase describing what a driver is doing right now
if gap <= 0
    s = 'CRASHED';
elseif aeb_on
    s = 'EMERGENCY BRAKE!';
elseif a < -0.6
    s = 'braking';
elseif gap <= cfg.range && (vl <= cfg.v_set || gap < dsafe)
    s = 'following the grey car';
else
    s = sprintf('cruising at the set speed (%d m/s)', cfg.v_set);
end
end

% ======================================================================
function show_graphs(UI, G, hist, k, ui, cfg)
% the graphs are drawn only while they are switched on
if ui.graphs
    set(UI.gpanel, 'Visible', 'on');
    demo_graphs('update', G, hist, k, cfg);
else
    set(UI.gpanel, 'Visible', 'off');
end
end

% ======================================================================
function ui = new_ui(vt)
% the settings shared between the buttons and the main loop (kept in the window)
ui.vt      = vt;           % your car's target speed [m/s]
ui.cam     = 'chase';      % camera: 'chase', 'drone' or 'driver'
ui.compare = false;        % show the classic controller in the left lane?
ui.graphs  = false;        % show the graphs?
ui.restart = false;
ui.paused  = false;
ui.replay  = false;
ui.slider  = [];           % handle of the speed slider (live mode only)
end

% ======================================================================
function on_slider(src, fig)
% the slider was moved: remember the new speed
ui = get(fig, 'UserData');
ui.vt = get(src, 'Value');
set(fig, 'UserData', ui);
end

% ======================================================================
function on_key(~, ev, fig)
% a key was pressed: do the same thing as the matching button
switch ev.Key
    case 'uparrow',   on_action(fig, 'faster');
    case 'downarrow', on_action(fig, 'slower');
    case 's',         on_action(fig, 'stop');
    case 'c',         on_action(fig, 'camera');
    case 'm',         on_action(fig, 'compare');
    case 'g',         on_action(fig, 'graphs');
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
        ui.vt = min(35, round(ui.vt) + 1);
    case 'slower'
        ui.vt = max(0, round(ui.vt) - 1);
    case 'stop'
        ui.vt = 0;
    case 'camera'
        switch ui.cam
            case 'chase',  ui.cam = 'drone';
            case 'drone',  ui.cam = 'driver';
            otherwise,     ui.cam = 'chase';
        end
    case 'compare'
        ui.compare = ~ui.compare;
    case 'graphs'
        ui.graphs = ~ui.graphs;
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
function b = add_button(parent, fig, label, pos, action)
% a clickable button; clicking it does the action named in 'action'
b = uicontrol(parent, 'Style', 'pushbutton', 'String', label, 'FontSize', 10, ...
              'FontWeight', 'bold', 'Units', 'normalized', 'Position', pos, ...
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
    frame = fr.cdata(1:2:end, 1:2:end, :);      % half size keeps the GIF smaller
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
