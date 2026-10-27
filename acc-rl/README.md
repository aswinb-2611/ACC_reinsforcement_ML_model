# AI-Based Adaptive Cruise Control (ACC) Using Reinforcement Learning

A complete college project in **plain base MATLAB** (no toolboxes). An AI
driver learns, from scratch, to follow a lead car at a safe distance while
holding a cruise speed. It is then compared, honestly, with a conventional
PD-based ACC controller on traffic situations it has never seen.

Everything is hand-written: the simulated road, the neural network (forward
pass and backpropagation), the Adam optimiser, the replay buffer, the Double
DQN learning algorithm and the training loop. No pretrained model, no RL
library, no Deep Learning Toolbox, no Reinforcement Learning Toolbox.

---

## Quick start (beginner, step by step)

1. Copy the whole `acc-rl` folder somewhere easy, for example your Desktop.
2. Open **MATLAB** (any recent version, R2018b or newer is fine; MATLAB Online
   also works: upload the folder to MATLAB Drive).
3. In MATLAB's **Current Folder** panel (left side), go into the `acc-rl`
   folder. Or type in the Command Window:
   ```matlab
   cd('C:\Users\<you>\Desktop\acc-rl')
   ```
4. Type and press Enter:
   ```matlab
   run_all
   ```
   This checks the maths, skips training (the trained model
   `trained_agent.mat` is already included), runs the exam on 105 unseen test
   drives, saves all results to `results/`, and opens the 3D demo.
5. To use the demo yourself:
   ```matlab
   demo()                      % LIVE: you drive the grey lead car
   demo('cut_in')              % REPLAY: an unseen exam drive, played back
   demo('mixed', 2)            % the 2nd unseen "mixed" test drive
   demo('hard_brake', 1, true) % also saves an animated GIF in results/ (large file)
   ```
   The window stays open until you close it.

### Live demo controls

**You drive the GREY car in front. The BLUE car behind it is the AI**, and
it decides everything by itself.

| what you want | button | key |
|---------------|--------|-----|
| grey car faster / slower by 1 m/s | `+1 m/s` / `-1 m/s` | Up / Down arrow |
| pick any speed (0 to 35 m/s) | the "Your speed" slider | |
| full stop (brakes at 4 m/s^2) | `STOP` | S |
| chase view, drone view, driver's seat | `Camera` | C |
| also show the classic controller (red car, left lane) | `Compare` | M |
| speed, gap and acceleration graphs | `Graphs` | G |
| pause / restart | `Pause` / `Restart` | Space / R |

If a key does nothing, click once on the 3D picture first (so the window
has the keyboard focus), or just use the buttons.

**Emergency brake (AEB).** In the live demo you can brake the grey car at
4 m/s^2, harder than ACC is allowed to brake (3 m/s^2). Real cars solve
this with two systems: ACC for comfort, and automatic emergency braking
(AEB) that only wakes up when a crash is close and may brake at 7 m/s^2.
Our demo has the same safety net, an orange banner shows when it acts,
and the screen counts how often each driver needed it. The exam in
`evaluate.m` does **not** use AEB: there the AI has to manage on its own.

**Compare mode** puts the classic controller in the left lane, behind its
own copy of your grey car, so both drivers face exactly the same thing
side by side and never overlap.
6. To retrain from scratch yourself (about 25 minutes in Octave, usually
   faster in MATLAB):
   ```matlab
   delete trained_agent.mat
   train()          % 800 practice episodes, live reward curve
   evaluate()
   ```
   Note: MATLAB and Octave make different random numbers from the same seed,
   so a MATLAB retrain gives a similar but not identical brain. The included
   `trained_agent.mat` and `test_scenarios.mat` make the evaluation itself
   exactly repeatable on both.

It also runs in **GNU Octave** (free), which is what it was developed and
tested with: `octave --eval "run_all"`.

---

## Results at a glance (105 unseen test drives)

| Metric | AI (DQN) | Baseline (PD) |
|--------|---------:|--------------:|
| Collisions | **0** | **0** |
| Gap error [m] | 6.29 | 6.24 |
| Speed RMSE [m/s] | 2.80 | 2.61 |
| RMS acceleration [m/s^2] | **0.88** | 0.91 |
| RMS jerk [m/s^3] | 1.50 | **0.72** |
| Worst minimum gap [m] | 4.00 | 5.00 |

The AI never crashes and is close to a carefully tuned conventional
controller on gap and speed. It is slightly gentler on acceleration, but
clearly less smooth (jerk), because it picks from 10 fixed accelerations
instead of a continuous value. Full discussion: `REPORT_NOTES.md`,
section 7. The 3D demo (`demo()`) is the best way to see the behaviour, and
it runs live on screen.

---

## What each file does (plain words)

### The world (environment)
| file | what it does |
|------|--------------|
| `acc_config.m` | All settings in one place: time step, speed limits, cruise speed, safe-distance rule, actions, reward weights, seeds. |
| `lead_profile.m` | Writes the "script" the lead car follows: constant speed, stop-and-go, hard brake, slow then fast, cut-in, random smooth, live-like (training only: a person on the slider, with sudden stops), and (test only) mixed. |
| `make_scenarios.m` | Builds a list of scenarios for training, validation or testing. |
| `env_reset.m` | Puts both cars on the road at the start of an episode. |
| `env_step.m` | Moves the world forward 0.1 s: physics, cut-ins, crash check, reward. |
| `env_observe.m` | What the AI sees: 6 normalised numbers (speed, relative speed, gap, gap error, current acceleration, lead car's acceleration). |
| `acc_reward.m` | The marking scheme: good gap, good speed, smooth pedals, big penalty for danger and crashes. |

### The conventional controller
| file | what it does |
|------|--------------|
| `baseline_acc.m` | Classic constant time-gap PD controller with spacing-error saturation, lead-acceleration feed-forward and cruise mode. |
| `tune_baseline.m` | Fair grid search of its 5 settings on training scenarios with the same reward. |

### The AI (all hand-written)
| file | what it does |
|------|--------------|
| `nn_init.m` | Creates the network 6 -> 64 -> 64 -> 10 with random starting weights. |
| `nn_forward.m` | Runs states through the network to get 10 Q-values (one per action). |
| `nn_backward.m` | Backpropagation: computes how every weight should change. |
| `gradient_check.m` | Proves backpropagation is correct by measuring slopes numerically. |
| `adam_init.m`, `adam_step.m` | The Adam optimiser that updates the weights. |
| `replay_init.m`, `replay_add.m`, `replay_sample.m` | The experience replay notebook. |
| `agent_act.m` | Epsilon-greedy choice: sometimes explore, usually pick the best action. |
| `agent_learn.m` | One Double DQN learning step (targets, Huber loss, backprop, clipping, Adam). |

### Running things
| file | what it does |
|------|--------------|
| `train.m` | Trains the AI from scratch, shows the live reward curve, saves `trained_agent.mat`. |
| `run_episode.m` | Drives one full episode with the AI or the baseline and records everything. |
| `compute_metrics.m` | Turns a recording into report-card numbers. |
| `evaluate.m` | Final exam: both controllers on the same 105 unseen tests, prints and saves the table and plots. |
| `dev_check.m` | Tuning tool: compares AI and baseline on a separate 35-drive development set (exam-like plus live-like, different seed), so the exam stays untouched. |
| `demo.m` | The 3D window: you drive the lead car (live), or replay an exam drive. Controls and graphs live here. |
| `demo_world.m` | Builds and draws the 3D world: two carriageways with textured asphalt, lane lines, barrier, guard rails, street lights, pine and leafy trees, houses, towers, mountains, sky and clouds, oncoming traffic, the cars, and the three cameras. |
| `demo_sim.m` | Live driving engine: moves the lead car from your controls, steps both drivers, and runs the emergency brake (AEB) safety net. |
| `demo_hist.m` | Keeps the record of every moment, for the picture and the graphs. |
| `demo_graphs.m` | The three small graphs (speed, gap, acceleration). |
| `car_mesh.m`, `mesh_box.m`, `mesh_wheel.m`, `mesh_cone.m`, `mesh_ball.m`, `mesh_add.m` | Build the 3D shapes: a smooth car body with windows, wheels with rims, lights and shadow; cones and balls for the trees. |
| `run_all.m` | One command: gradient check, train if needed, evaluate, demo. |
| `can_show_figures.m`, `set_seed.m` | Small helpers (is there a screen? fix the random seed). |

### Data and results
| file | what it is |
|------|------------|
| `trained_agent.mat` | The trained network (our own weights) plus its training history. |
| `test_scenarios.mat` | The fixed 105 unseen test drives, saved so results repeat exactly in MATLAB and Octave. |
| `results/training_reward_curve.png` | How the marks improved during training. |
| `results/scenario_*.png` | Speed, gap and acceleration of AI vs baseline, one per scenario family. |
| `results/comparison_bar_chart.png` | All metrics side by side. |
| `results/metrics_table.csv` | The final results table. |
| `results/metrics_by_scenario.csv` | Results split by scenario family. |
| `results/demo_*.gif` | Only created if you ask for one, with `demo('hard_brake', 1, true)`. These files are large (about 18 MB). |

### Documents
| file | what it is |
|------|------------|
| `LEARN_WITH_ME.md` | Beginner guide to every concept used. |
| `REPORT_NOTES.md` | Outline, talking points and viva questions with answers. |

---

## Design summary

* **Road**: 1D straight highway, dt = 0.1 s, 60 s episodes (600 steps).
* **Our car**: speed 0 to 35 m/s, acceleration limited to [-3, +2] m/s^2,
  engine/brake lag 0.3 s (same for both controllers).
* **Safe distance**: d_safe = 5 + 1.5 * v. Cruise speed 25 m/s. Radar range 150 m.
* **State (6 inputs)**: speed, relative speed, gap, gap error, current acceleration, lead car's acceleration, all normalised.
* **Actions (10)**: -3, -2, -1, -0.5, -0.25, 0, +0.25, +0.5, +1, +2 m/s^2.
* **Reward**: gap near d_safe when following, speed near 25 m/s on a free
  road; penalties for being too close, short time-to-collision, high
  "braking needed" (including the lead car's own stopping distance),
  speeding, strong acceleration and jerk; -300 for a crash.
* **Agent**: Double DQN, MLP 6-64-64-10 with ReLU (5,258 weights), Adam,
  Huber loss, gradient-norm clipping, replay buffer 100k, batch 64, target
  sync every 2000 steps, gamma 0.99, fixed seed.
  800 episodes, epsilon 1.0 -> 0.05, learning rate 5e-4 -> 1e-4.
  The brain with the best crash-free mock-test score (21 drives) is kept.
* **Baseline**: e = min(gap - d_safe, e_max); a = min(kv (25 - v), kp e + kd (v_lead - v)),
  clipped to [-3, 2]. Tuned: kp = 0.45, kd = 0.70, kv = 1.25, e_max = 20 m.
* **Testing**: 7 families x 15 = 105 unseen episodes, different seed and
  ranges from training, plus a family (`mixed`) never seen in training.

---

## Troubleshooting

* **"Undefined function"**: make sure MATLAB's Current Folder is `acc-rl`.
* **Octave prints "demo.m shadows a core library function"**: harmless.
  Octave has its own `demo` command; ours is used because it is in the
  current folder.
* **No animation window** (for example when using `matlab -batch`): use
  `demo('hard_brake', 1, true)` to save a GIF to `results/` instead (large file).
