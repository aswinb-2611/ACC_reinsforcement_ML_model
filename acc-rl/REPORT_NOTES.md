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

* 800 episodes, about 19 minutes in Octave on one CPU core.
* Reward curve (`results/training_reward_curve.png`): starts far below
  zero (random pedals, frequent crashes, each crash now costs -300), rises
  steadily, and plateaus around 400 to 450 once exploration falls to 5%
  (episode 480).
* Three seeds were trained (run 9). Saved model: seed 1, episode 730,
  mock-test score 428.7 on 21 validation drives, with zero crashes.

### 7.2 Final exam: 105 unseen test episodes (7 families x 15)

| Metric | AI (DQN) | Baseline (PD) | Better |
|--------|---------:|--------------:|--------|
| Average following distance [m] | 38.74 | 35.18 | (info) |
| Average safe distance d_safe [m] | 29.63 | 29.84 | (info) |
| Gap error abs(gap - d_safe) [m] | 10.14 | **6.14** | **Baseline**, clearly |
| Speed tracking RMSE [m/s] | **2.60** | 2.61 | AI, by 0.5% (a tie) |
| **Collision rate** | **0%** | **0%** | tie |
| RMS acceleration [m/s^2] | **0.85** | 0.88 | **AI**, by 3% |
| RMS jerk [m/s^3] | 1.43 | **0.69** | **Baseline**, clearly |
| Minimum gap, worst episode [m] | 4.85 | 5.00 | Baseline (a tie) |
| Minimum gap, average episode [m] | **20.13** | 19.20 | AI, by 5% |
| Average total reward per episode | 447.9 | 473.1 | Baseline |

Per scenario family (gap error AI / Baseline, metres): constant 8.6 / 3.3,
cut-in 15.8 / 11.9, hard brake 15.5 / 7.4, mixed 7.5 / 5.9, random smooth
13.5 / 7.2, slow then fast 5.5 / 4.0, stop and go 4.5 / 3.2. Both have
zero collisions in every family, including `mixed`, which the AI never saw
during training.

The AI follows on average 9 m further back than d_safe (38.7 m vs 29.6 m):
it has become a cautious driver. That is why its gap error is larger and
its average minimum gap is larger at the same time.

### 7.3 Development set (35 drives: 30 exam-like plus 5 live-like, own seed)

| | AI | Baseline |
|---|---:|---:|
| Mean marks | 446.1 | 446.5 |
| Collisions | **0** | 1 |
| Gap error [m] | 15.65 | **11.95** |
| Speed RMSE [m/s] | **3.00** | 3.21 |
| RMS acceleration | **0.89** | 0.96 |
| RMS jerk | 1.49 | **0.67** |
| Worst minimum gap [m] | **5.2** | -0.1 (crash) |

### 7.4 Live-demo stress test: 60 "press STOP" drives, no emergency brake

The lead car cruises at 12, 18, 22, 26 or 30 m/s, then at 8, 20 or 40 s
brakes at 3 or 4 m/s^2 to 0 or 8 m/s, then speeds up again. The AEB safety
net of the live demo is switched OFF, so only the controller counts.

| | crashes (of 60) | closest gap |
|---|---:|---:|
| AI, run 6 (5 inputs, before the fixes) | 7 | crash |
| **AI, run 9 (final)** | **0** | **4.7 m** |
| Baseline, final gains | 8 | crash |

All 8 baseline crashes are full stops from a lead speed of 26 or 30 m/s,
faster than our 25 m/s cruise speed: the gap has grown large, the capped
spacing error still says "fine", and by the time the closing speed is big
the stop is no longer possible at 3 m/s^2. This is our own test, designed
after we saw the live-demo crash, so it is reported separately from the
exam.

### 7.5 Honest interpretation

* **Safety goal met, and clearly better than before:** zero collisions in
  all 105 unseen tests, zero on the dev set (where the tuned baseline
  crashed once), and zero in the 60 hard-stop drives where the baseline
  crashed 8 times and the previous AI 7 times.
* **The price is accuracy:** the final AI keeps a bigger gap than it
  needs, so its gap error on the exam (10.1 m) is worse than the baseline's
  (6.1 m) and worse than the previous AI's (6.3 m). In the live demo you see
  this as the blue car hanging back a little further than the dotted safe
  distance. Speed tracking and acceleration are a tie or slightly better.
* **Clear loss: jerk.** The AI's RMS jerk is about twice the baseline's.
  Cause: discrete actions. The AI picks from 10 fixed accelerations and
  keeps making small corrections between neighbouring levels, while the PD
  controller outputs any value smoothly. A continuous-action method
  (DDPG/TD3) is the natural fix.
* **The baseline is strong because we made it strong:** spacing-error
  saturation, lead-acceleration feed-forward and a fair 5-parameter grid
  search with the same reward. Without saturation, the plain PD law crashed
  in a hard-brake test.

### 7.6 How the test set was used (transparency)

The exam was run four times in total: (1) after run 4, which revealed that
the 12-drive validation set was too small; (2) after run 6; (3) a re-run
after restoring run 6, which gave identical numbers; (4) after run 9, the
final model. After the first run we introduced the separate development set
and made every later decision on it (fixing the sparse reward, choosing
seeds, rejecting run 7, choosing run 9 seed 1). Run 9 was chosen BEFORE the
fourth exam, by the same rule as before (crash-free on the dev set, best
mean dev marks), and it was kept even though the exam showed a worse gap
error than run 6. Swapping back because of exam numbers would mean
choosing the model on the test set.

### 7.7 Tuning history (summary)

| Run | Change | Outcome |
|-----|--------|---------|
| 1 | first working DQN | no mock-test crashes, but jerky (jerk penalty 11.5 vs 0.3) |
| 2-3 | jerk x4, finer actions, lr decay; "braking needed" penalty, baseline saturation | found and fixed a late-braking crash |
| 4 | fixed reward loophole (tailgating a slightly faster car) | dev and exam showed poor generalisation |
| 4b | refinement phase | worse; removed |
| 5-6 | distance-blended reward (fixes sparse reward), 18 mock-test drives, two seeds | 0 crashes on dev and exam, gap error a tie with the baseline |
| 7 | absolute-value jerk penalty | worse jerk, rejected |
| 8 | crash -300, safety penalties capped, speeding penalty, `live_like` family | still crashed in hard-stop drives (the AI could not see the lead braking) |
| 9 | 6th input: lead acceleration; braking-needed counts the lead's stopping distance; baseline feed-forward, re-tuned | **final model**: 0 crashes everywhere, but a looser gap |


## 8. Limitations (be honest, examiners like this)

* 1D longitudinal model only: no lane changes, no road grade, no
  aerodynamic drag, perfect sensors with no noise or delay.
* Discrete actions: the AI can only choose from 10 accelerations, which
  makes perfectly smooth control harder than for the continuous baseline.
* Simulation only: no real vehicle data. A real car would need far more
  testing and safety certification. The live demo has a simple emergency
  brake (AEB) as a fallback, but the exam deliberately runs without it.
* The final AI is cautious: it follows about 9 m further back than d_safe,
  so the safety gain cost some gap accuracy.
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
* Win back gap accuracy without losing safety: for example a stronger gap
  reward, or training longer on the `live_like` family. Decide on the dev
  set, not the exam.
* A formal safety layer ("shield"), like the live demo's AEB, used and
  evaluated in the exam too.
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
* "Playing with the live demo found a crash the exam never tested. The AI
  could not see that the car ahead was braking. One extra input, the lead
  car's acceleration, took it from 7 crashes to 0 in 60 hard-stop drives."

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
    Jerk: about 1.4 vs 0.7 m/s^3. The AI chooses from 10 fixed
    accelerations and keeps switching between neighbouring levels, while
    the PD controller outputs any value smoothly. And gap error: 10.1 vs
    6.1 m, because the final AI follows about 9 m further back than it
    needs to. Speed tracking and acceleration are a tie or slightly
    better. Both had zero collisions on the exam; in the hard-stop test the
    AI had 0 crashes and the baseline 8.

19. **Why not just report the results that look best?**
    Because that would be dishonest. I chose the model on validation and
    dev data, and the exam result is what it is. Reporting where the AI
    loses (jerk) and why is part of a credible result.

20. **What did you learn from the failed experiments?**
    The refinement phase failed because an empty replay buffer with almost
    no exploration made the agent forget bad situations. The absolute-value
    jerk penalty failed because it made big lurches cheaper, while the
    metric (RMS) punishes them most. The penalty should have the same shape
    as the metric.

21. **Could this go into a real car?**
    Not directly. It needs real sensor noise, many more scenarios, formal
    safety checks and a safety fallback. It is a proof of concept.

22. **What would you do next?**
    Win back gap accuracy without losing safety, continuous actions, sensor
    noise, a safety shield, and multi-car traffic.

23. **Why did you add the lead car's acceleration as an input?**
    In the live demo, when the lead car braked hard from far away, the AI
    reacted too late and crashed. With only one snapshot of speeds and gap,
    a car that has just started braking looks almost like a cruising one,
    so the state was missing information (it was not Markov). Real ACC
    radars measure lead acceleration too. After adding it, hard-stop
    crashes went from 7 to 0 out of 60.

24. **Your demo has emergency braking. Isn't that cheating?**
    No, because the exam does not use it. In the live demo a person can
    brake the lead car at 4 m/s^2, harder than ACC may brake (3 m/s^2), so
    in some situations no ACC can avoid a crash: that is physics. Real cars
    have a separate AEB system for exactly this. The demo shows and counts
    when it acts; the final AI did not need it in our STOP tests.

25. **Your new model has a worse gap error than the old one. Why keep it?**
    It was chosen on the development set before the exam, by the same rule
    as before. Swapping back because of the exam numbers would be choosing
    the model on the test set. And it fixes the crash that really matters:
    0 instead of 7 crashes when the car ahead stops hard.
