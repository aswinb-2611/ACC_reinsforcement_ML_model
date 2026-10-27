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

**State (5, normalised):** v/25 - 1, (v_lead - v)/10, gap/150,
(gap - d_safe)/50, a_actual/3. When no car is within radar range,
gap = 150 and relative speed = 0.

**Actions (10):** {-3, -2, -1, -0.5, -0.25, 0, +0.25, +0.5, +1, +2} m/s^2.

**Reward per step:**

* Following mode (car in range and slower than cruise speed, or closer
  than d_safe): near = 0.7 * exp(-0.5 ((gap - d_safe)/(0.25 d_safe))^2)
  + 0.3 * speed score, blended with the free-road score by distance:
  task = w * speed score + (1 - w) * near, w = clip((gap - d_safe)/d_safe, 0, 1).
* Free road: speed score = max(0, 1 - |v - 25| / 15).
* Penalties: closer than d_safe (2 * relative shortfall squared), closer than
  0.5 d_safe (up to 3), time-to-collision under 4 s (up to 1), braking needed
  (closing speed^2 / (2 gap)) above 1.5 m/s^2 (up to 3), acceleration
  0.05 (a/3)^2, jerk 0.10 |jerk|/5 (absolute value, see tuning notes).
* Collision: -100 and the episode terminates.
* Running out of time is NOT treated as a terminal state (bootstrapping
  continues), only a collision is.

## 5. Agent (Double DQN, hand-written)

| item | value |
|------|-------|
| network | MLP 5 - 64 - 64 - 10, ReLU, linear output, 5,194 weights |
| initialisation | He (sqrt(2/fan_in)), small output layer |
| loss | Huber (delta 5) on the TD error |
| optimiser | Adam (beta1 0.9, beta2 0.999), lr 5e-4 decaying linearly to 1e-4 |
| gradient clipping | global norm 10 |
| replay buffer | 100,000 transitions, mini-batch 64, warm-up 3,000 steps |
| target network | hard copy every 2,000 steps |
| target | y = r + 0.99 (1 - done) Q_target(s', argmax_a Q_online(s', a)) |
| exploration | epsilon-greedy, 1.0 to 0.05 linearly over 60% of training |
| training | 800 episodes, fixed seed; best crash-free mock-test model kept |
| model selection | every 10 episodes, 18 fixed validation drives (not the test set) |
| data sets | training (random, new every episode), validation (18), development (30, exam-like, own seed), test (105) |

**Gradient check:** central finite differences on a small network give a
relative error of about 1e-11 for every parameter, proving the
backpropagation is correct.

## 6. Baseline

Constant time-gap PD with spacing-error saturation and cruise mode:

    e        = min(gap - d_safe, e_max)
    a_follow = kp * e + kd * (v_lead - v)
    a_cruise = kv * (v_set - v)
    a        = clip(min(a_cruise, a_follow), -3, +2)

Gains tuned by a two-stage grid search on 18 training-style scenarios with
the same reward as the AI, rejecting any setting that crashed.

## 7. Results

RESULTS_PLACEHOLDER

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
   State: speed, relative speed, gap, gap error and current acceleration,
   all normalised. Action: one of 10 accelerations from -3 to +2 m/s^2.
   Reward: points for a gap near d_safe or speed near 25 m/s, penalties for
   being too close, risky closing, harsh or jerky pedals, and -100 for a crash.

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
    (Use the Results section.) The honest explanation for any comfort gap
    is discrete actions: the AI switches between fixed levels, while the PD
    controller outputs any value smoothly.

19. **Could this go into a real car?**
    Not directly. It needs real sensor noise, many more scenarios, formal
    safety checks and a safety fallback. It is a proof of concept.

20. **What would you do next?**
    Continuous actions, sensor noise, a safety shield, and multi-car traffic.
