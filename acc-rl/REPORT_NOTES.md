# Report and Viva Notes

Use this as the skeleton of your college report and as practice for the viva.
Every number in the Results section comes from `results/metrics_table.csv`,
produced by `evaluate.m` on the unseen test set.

---

## 1. Problem statement

Adaptive Cruise Control (ACC) must keep a car at a driver-chosen cruise speed
when the road is clear, and follow a slower lead vehicle at a safe distance
otherwise, while staying comfortable (no harsh or jerky acceleration) and
never colliding. Conventional ACC uses a hand-designed control law. We ask:
**can a reinforcement learning agent, built and trained entirely from
scratch, learn this behaviour by trial and error, and how does it compare
with a fairly tuned conventional controller on situations it has never seen?**

## 2. Objectives

1. Build a 1D longitudinal highway simulator with a lead and an ego vehicle.
2. Implement a Deep Q-Network (Double DQN) from scratch in base MATLAB:
   network, backpropagation, Adam, replay buffer, target network, exploration.
3. Verify backpropagation with a numerical gradient check.
4. Design a reward that encodes safety, tracking and comfort.
5. Tune a conventional constant time-gap PD controller fairly.
6. Compare both on 105 unseen test episodes across 7 scenario families.

## 3. System model (environment)

* Time step dt = 0.1 s, episode 60 s (600 steps).
* Ego: v(k+1) = v(k) + a(k) dt, position by trapezoidal integration,
  0 <= v <= 35 m/s, -3 <= a <= +2 m/s^2.
* First-order actuator lag, time constant 0.3 s (same for both controllers):
  a_actual(k+1) = a_actual(k) + (a_cmd - a_actual(k)) dt / tau.
* Safe distance d_safe = d0 + t_gap v with d0 = 5 m, t_gap = 1.5 s.
* Cruise speed 25 m/s. Radar range 150 m (beyond it the road reads as clear).
* Collision when gap <= 0, which ends the episode.

**Scenario families**: constant speed, stop-and-go, sudden hard brake,
slow-then-fast, cut-in, random smooth profile. Test set: same families with
a different seed and shifted parameter ranges, plus a 7th family, `mixed`
(random drive + cut-in + hard brake), that never appears in training.
All scenarios are physically survivable with the ego's braking limit.

## 4. RL formulation

**State (6, normalised):** v/25 - 1, (v_lead - v)/10, gap/150,
(gap - d_safe)/50, a_actual/3, a_lead/3. When no car is within radar range,
gap = 150 and relative speed and lead acceleration = 0. (The lead
acceleration was added in run 9: without it, a hard-braking car far ahead
was indistinguishable from a cruising one, so the state was not Markov.)

**Actions (10):** {-3, -2, -1, -0.5, -0.25, 0, +0.25, +0.5, +1, +2} m/s^2.

**Reward per step:**

* Following mode (car in range and slower than cruise speed, or closer
  than d_safe): near = 0.7 * exp(-0.5 ((gap - d_safe)/(0.25 d_safe))^2)
  + 0.3 * speed score, blended with the free-road score by distance:
  task = w * speed score + (1 - w) * near, w = clip((gap - d_safe)/d_safe, 0, 1).
* Free road: speed score = max(0, 1 - |v - 25| / 15).
* Penalties: closer than d_safe (2 * relative shortfall squared), closer than
  0.5 d_safe (up to 3), time-to-collision under 4 s (up to 1), braking needed
  above 1.5 m/s^2 (up to 3), acceleration 0.05 (a/3)^2, jerk 0.20 (jerk/5)^2,
  speed above the set speed 0.15 per m/s.
  Braking needed = max(closing speed^2 / (2 gap), v^2 / (2 (gap + d_lead - 2)))
  where d_lead = v_lead^2 / (2 b) is the lead car's stopping distance when it
  is braking at b > 0.5 m/s^2 (second term added in run 9).
* The four safety penalties together are capped at 2.5 per step, so a long
  close call can never cost more than a crash (run 8, the "give up" trap).
* Collision: -300 and the episode terminates.
* Running out of time is NOT treated as a terminal state (bootstrapping
  continues), only a collision is.

## 5. Agent (Double DQN, hand-written)

| item | value |
|------|-------|
| network | MLP 6 - 64 - 64 - 10, ReLU, linear output, 5,258 weights |
| initialisation | He (sqrt(2/fan_in)), small output layer |
| loss | Huber (delta 5) on the TD error |
| optimiser | Adam (beta1 0.9, beta2 0.999), lr 5e-4 decaying linearly to 1e-4 |
| gradient clipping | global norm 10 |
| replay buffer | 100,000 transitions, mini-batch 64, warm-up 3,000 steps |
| target network | hard copy every 2,000 steps |
| target | y = r + 0.99 (1 - done) Q_target(s', argmax_a Q_online(s', a)) |
| exploration | epsilon-greedy, 1.0 to 0.05 linearly over 60% of training |
| training | 800 episodes, fixed seed; best crash-free mock-test model kept |
| model selection | every 10 episodes, 21 fixed validation drives (not the test set) |
| data sets | training (random, new every episode), validation (21), development (35, exam-like plus live-like, own seed), test (105) |

**Gradient check:** central finite differences on a small network give a
relative error of about 1e-11 for every parameter, proving the
backpropagation is correct.

## 6. Baseline

Constant time-gap PD with spacing-error saturation and cruise mode:

    e        = min(gap - d_safe, e_max)
    a_follow = kp * e + kd * (v_lead - v) + ka * a_lead
    a_cruise = kv * (v_set - v)
    a        = clip(min(a_cruise, a_follow), -3, +2)

Gains tuned by a two-stage grid search on 21 training-style scenarios with
the same reward as the AI, rejecting any setting that crashed. The
feed-forward gain ka (run 9) gives it the same lead-acceleration
information the AI gets, so the comparison stays fair; ka = 0 is in the
grid, so the search could have rejected it.

## 7. Results

### 7.1 Training

* 800 episodes, about 18 minutes in Octave on one CPU core.
* Reward curve (`results/training_reward_curve.png`): starts around -100 to
  -200 per episode (random pedals, frequent crashes), rises steadily, and
  plateaus around 400 to 440 once exploration falls to 5% (episode 480).
* Saved model: episode 770, mock-test score 435.1 on 18 validation drives,
  with zero crashes.

### 7.2 Final exam: 105 unseen test episodes (7 families x 15)

| Metric | AI (DQN) | Baseline (PD) | Better |
|--------|---------:|--------------:|--------|
| Average following distance [m] | 34.08 | 35.35 | (info) |
| Average safe distance d_safe [m] | 30.42 | 29.81 | (info) |
| Gap error abs(gap - d_safe) [m] | 6.29 | 6.24 | Baseline, by 0.7% (practically a tie) |
| Speed tracking RMSE [m/s] | 2.80 | 2.61 | Baseline, by 7% |
| **Collision rate** | **0%** | **0%** | tie |
| RMS acceleration [m/s^2] | **0.88** | 0.91 | **AI**, by 3% |
| RMS jerk [m/s^3] | 1.50 | **0.72** | **Baseline**, clearly |
| Minimum gap, worst episode [m] | 4.00 | 5.00 | Baseline |
| Minimum gap, average episode [m] | 18.74 | 19.06 | Baseline, by 2% |
| Average total reward per episode | 448.7 | 485.5 | Baseline |

Per scenario family (AI / Baseline): the AI holds the safe distance more
accurately than the baseline in the **hard brake** (5.75 / 7.63 m) and
**random smooth** (5.45 / 7.48 m) families; the baseline is more accurate in
the others. Both have zero collisions in every family, including `mixed`,
which the AI never saw during training.

### 7.3 Development set (30 exam-like drives, own seed)

| | AI | Baseline |
|---|---:|---:|
| Collisions | **0** | 1 |
| Gap error [m] | **9.28** | 10.32 |
| Speed RMSE [m/s] | **3.12** | 3.14 |
| RMS acceleration | **0.91** | 0.97 |
| RMS jerk | 1.55 | **0.71** |
| Worst minimum gap [m] | **4.6** | -0.7 (crash) |

### 7.4 Honest interpretation

* **Safety goal met:** zero collisions in all 105 unseen tests, and zero on
  the dev set, where even the tuned baseline crashed once (a stop-and-go
  drive with a slow start).
* **Competitive, not dominant:** on the exam, the AI is within about 1% of
  the baseline on gap error and 2% on average minimum gap, 7% behind on
  speed tracking, and slightly better on acceleration. On the dev set it
  wins 5 of the 7 metrics.
* **Clear loss: jerk.** The AI's RMS jerk is about twice the baseline's.
  Cause: discrete actions. The AI picks from 10 fixed accelerations and
  keeps making small corrections between neighbouring levels, while the PD
  controller outputs any value smoothly. A continuous-action method
  (DDPG/TD3) is the natural fix.
* **The baseline is strong because we made it strong:** spacing-error
  saturation plus a fair 4-parameter grid search with the same reward.
  Without saturation, the plain PD law crashed in a hard-brake test.

### 7.5 How the test set was used (transparency)

The exam was run three times in total: (1) after run 4, which revealed that
the 12-drive validation set was too small (gap error 10.8 vs 6.2 m and one
crash); (2) after run 6, the final model; (3) this re-run after restoring
run 6, which gave identical numbers. After the first run we introduced the
separate development set and made every later decision on it (fixing the
sparse reward, choosing seed 1 over seed 2, rejecting run 7), so the
reported model was not tuned on the test set.

### 7.6 Tuning history (summary)

| Run | Change | Outcome |
|-----|--------|---------|
| 1 | first working DQN | no mock-test crashes, but jerky (jerk penalty 11.5 vs 0.3) |
| 2-3 | jerk x4, finer actions, lr decay; "braking needed" penalty, baseline saturation | found and fixed a late-braking crash |
| 4 | fixed reward loophole (tailgating a slightly faster car) | dev and exam showed poor generalisation |
| 4b | refinement phase | worse; removed |
| 5-6 | distance-blended reward (fixes sparse reward), 18 mock-test drives, two seeds | **final model**: 0 crashes on dev and exam |
| 7 | absolute-value jerk penalty | worse jerk, rejected |


## 8. Limitations (be honest, examiners like this)

* 1D longitudinal model only: no lane changes, no road grade, no
  aerodynamic drag, perfect sensors with no noise or delay.
* Discrete actions: the AI can only choose from 10 accelerations, which
  makes perfectly smooth control harder than for the continuous baseline.
* Simulation only: no real vehicle data. A real car would need far more
  testing, safety certification and a fallback (e.g. emergency braking).
* A DQN gives no formal safety guarantee. Zero collisions on 105 test
  episodes is evidence, not proof.
* Results depend on the reward design; a different weighting of comfort vs.
  gap accuracy would give a different trade-off.
* Octave and MATLAB use different random-number generators, so retraining in
  MATLAB gives a slightly different (but similar) network. The saved model
  and saved test scenarios make the evaluation itself exactly repeatable.

## 9. Future work

* Continuous-action methods (DDPG, TD3, SAC) for smoother control.
* Sensor noise, delay and partial observability; a recurrent network.
* Safety layer ("shield") that overrides the agent if braking needed is too high.
* Multi-vehicle traffic and string stability (platooning).
* Real driving-data lead profiles (e.g. from public highway datasets).
* Hardware-in-the-loop or a small robot-car demo.

---

## 10. Talking points (short, say them out loud)

* "The agent is a learner driver; the reward is the marking scheme; training
  is thousands of practice drives."
* "I wrote the neural network and backpropagation myself and proved it
  correct with a numerical gradient check."
* "The final exam is 105 drives the agent never saw, including a scenario
  type it never trained on."
* "I tuned the conventional controller just as carefully, with the same
  reward, so the comparison is fair."
* "During tuning I found and fixed a reward loophole: the agent tailgated a
  car that was slightly faster than the cruise speed, because I had written
  the reward badly. RL optimises exactly what you reward."

## 11. Likely viva questions with simple answers

1. **What is reinforcement learning?**
   Learning by trial and error. An agent acts in an environment, gets a
   reward after each action, and improves its choices to collect the most
   reward over time. No one gives it the correct answers.

2. **Why did you build it from scratch instead of using a toolbox?**
   To understand and control every part, and to be able to explain it.
   Writing the network, backpropagation, optimiser and DQN myself meant I
   had to verify each piece, for example with the gradient check. It also
   means the project has no toolbox dependency and runs on base MATLAB.

3. **How does your network learn?**
   For a batch of past experiences it predicts Q-values, compares them with
   targets from the Bellman equation (reward now plus 0.99 times the best
   value next), measures the error, uses backpropagation (the chain rule) to
   find how each weight affects the error, and Adam moves each weight a
   small step to reduce it. Repeated hundreds of thousands of times.

4. **What is a Q-value?**
   The expected total future reward if I take action a in state s and then
   keep acting well. The agent picks the action with the highest Q-value.

5. **What are your state, action and reward?**
   State: speed, relative speed, gap, gap error, current acceleration and
   the lead car's acceleration, all normalised. Action: one of 10 accelerations from -3 to +2 m/s^2.
   Reward: points for a gap near d_safe or speed near 25 m/s, penalties for
   being too close, risky closing, harsh or jerky pedals, speeding, and -300 for a crash.

6. **Why a replay buffer?**
   Consecutive steps are almost identical, which makes learning unstable.
   Sampling random old experiences breaks that correlation and lets rare
   events, like hard brakes, be reused many times.

7. **Why a target network?**
   The learning target uses the network's own predictions. If they change at
   every step, the target moves while you chase it. A frozen copy, refreshed
   every 2,000 steps, keeps the target steady.

8. **What is Double DQN and why use it?**
   Normal DQN uses the same network to choose and to judge the next action,
   which overestimates values. Double DQN lets the online network choose and
   the target network judge, reducing that over-optimism.

9. **What is epsilon-greedy?**
   With probability epsilon take a random action (explore), otherwise the
   best-known action (exploit). Epsilon starts at 1 and decays to 0.05.

10. **What is the gradient check and why did you do it?**
    I compared my backpropagation gradients with gradients measured by
    nudging each weight by plus and minus 0.00001. They matched to about
    1e-11, which proves my hand-written calculus is correct. A bug there
    would silently stop learning.

11. **How did you make sure the comparison is fair?**
    Same simulator, same actuator lag, same acceleration limits, same test
    scenarios, and the baseline was tuned by grid search with the same
    reward the AI was trained on. Testing only on unseen scenarios.

12. **How do you know it is not overfitting?**
    Every training episode is a new random scenario, the saved model is
    chosen on a separate validation set, and all reported results are on a
    test set with a different seed, shifted ranges and one completely new
    scenario family.

13. **What does the reward curve show?**
    Total reward per training episode. It starts low and noisy (random
    actions, crashes) and rises as the agent learns. The red mock-test
    points show progress without exploration noise.

14. **What is the time gap and why 1.5 s?**
    The time it would take to reach the lead car's current position at your
    current speed. 1.5 s is a common ACC setting; d_safe = 5 + 1.5 v grows
    with speed because stopping distance grows with speed.

15. **Why discrete actions? Is that realistic?**
    DQN needs a finite list of actions. Ten levels from -3 to +2 is enough
    for good control; a continuous method like DDPG would be smoother and is
    listed as future work.

16. **Why did you add engine/brake lag?**
    Real vehicles cannot change acceleration instantly. A 0.3 s lag makes
    the simulation more realistic and makes the jerk comparison meaningful.
    Both controllers face the same lag.

17. **What was the hardest problem?**
    Reward design. The agent found a loophole and tailgated a car that was
    slightly faster than the cruise speed, because the reward did not count
    that as following. I fixed the definition of "following". RL agents
    optimise exactly what you reward.

18. **Where does your AI lose to the baseline and why?**
    Mainly jerk: about 1.5 vs 0.7 m/s^3. The AI chooses from 10 fixed
    accelerations and keeps switching between neighbouring levels, while
    the PD controller outputs any value smoothly. Speed tracking is 7% worse;
    gap error is essentially equal. Both had zero collisions.

21. **Why not just report the results that look best?**
    Because that would be dishonest. I chose the model on validation and
    dev data, and the exam result is what it is. Reporting where the AI
    loses (jerk) and why is part of a credible result.

22. **What did you learn from the failed experiments?**
    The refinement phase failed because an empty replay buffer with almost
    no exploration made the agent forget bad situations. The absolute-value
    jerk penalty failed because it made big lurches cheaper, while the
    metric (RMS) punishes them most. The penalty should have the same shape
    as the metric.

19. **Could this go into a real car?**
    Not directly. It needs real sensor noise, many more scenarios, formal
    safety checks and a safety fallback. It is a proof of concept.

20. **What would you do next?**
    Continuous actions, sensor noise, a safety shield, and multi-car traffic.
