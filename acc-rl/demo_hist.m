function hist = demo_hist(mode, varargin)
% DEMO_HIST  Keeps a record of everything the picture and the graphs need.
%
%   hist = demo_hist('init')
%       An empty record.
%
%   hist = demo_hist('push', hist, sim, cfg)
%       Adds the current moment of a live run to the record.
%
%   hist = demo_hist('from_logs', la, lb, cfg)
%       Builds the record from two finished episodes (one per driver),
%       for replaying a test drive. la and lb come from run_episode.
%
% Every field is a list with one number per moment, so frame k of the
% animation just reads entry k of each list.

fields = {'t', 'xe_a', 'xe_b', 'xl', 've_a', 've_b', 'vl', ...
          'gap_a', 'gap_b', 'dsafe', 'ae_a', 'ae_b', 'R_a', 'R_b'};

switch mode
    case 'init'
        for i = 1:numel(fields)
            hist.(fields{i}) = [];
        end

    case 'push'
        hist = varargin{1};
        sim = varargin{2};
        cfg = varargin{3};
        a = sim.env_ai;
        b = sim.env_bl;
        % the new numbers for this moment, one per field
        v.t      = a.t;
        v.xe_a   = a.xe;
        v.xe_b   = b.xe;
        v.xl     = a.xl;
        v.ve_a   = a.ve;
        v.ve_b   = b.ve;
        v.vl     = a.vl;
        v.gap_a  = a.xl - a.xe;
        v.gap_b  = b.xl - b.xe;
        v.dsafe  = cfg.d0 + cfg.t_gap * a.ve;   % the safe distance for our speed
        v.ae_a   = a.ae;
        v.ae_b   = b.ae;
        v.R_a    = sim.R_a;
        v.R_b    = sim.R_b;
        for i = 1:numel(fields)
            hist.(fields{i})(end + 1) = v.(fields{i});
        end

    case 'from_logs'
        la = varargin{1};
        lb = varargin{2};
        cfg = varargin{3};
        % the two drivers can crash at different times, so the shorter
        % recording is padded by holding its last value
        n = max(numel(la.t), numel(lb.t));
        hist.t     = (1:n) * cfg.dt;
        hist.xe_a  = pad(la.xe, n);
        hist.xe_b  = pad(lb.xe, n);
        hist.xl    = pad(la.xl, n);
        hist.ve_a  = pad(la.ve, n);
        hist.ve_b  = pad(lb.ve, n);
        hist.vl    = pad(la.vl, n);
        hist.gap_a = pad(la.gap, n);
        hist.gap_b = pad(lb.gap, n);
        hist.dsafe = pad(la.d_safe, n);
        hist.ae_a  = pad(la.ae, n);
        hist.ae_b  = pad(lb.ae, n);
        hist.R_a   = pad(cumsum(la.r), n);     % running total of marks
        hist.R_b   = pad(cumsum(lb.r), n);     % (add up first, then pad)

    otherwise
        error('demo_hist: unknown mode %s', mode);
end
end

% ======================================================================
function x = pad(x, n)
% makes a list n long by repeating its last value (a car that has stopped
% in the picture keeps its last place)
x = x(:)';
if numel(x) < n
    x = [x, repmat(x(end), 1, n - numel(x))];
end
end
