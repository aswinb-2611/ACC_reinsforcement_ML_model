# Learn With Me: the ideas behind this project

This guide explains every idea used in the project in plain words, with small
number examples. Read it top to bottom once, then use it as a dictionary.
Each section also says **which file** contains that idea, so you can open the
code and see it for real.

---

## 1. What is Adaptive Cruise Control (ACC)?

Normal cruise control holds a speed you choose, say 90 km/h, no matter what.
If a slower car is ahead, you must brake yourself.

**Adaptive** cruise control adds a radar at the front of the car. It:

1. drives at your chosen speed when the road ahead is clear (**cruise mode**), and
2. when a slower car is ahead, slows down and follows it at a safe distance
   (**follow mode**), then speeds up again when the road clears.

```
 FREE ROAD:      [our car] ---------->                (hold 25 m/s)

 FOLLOWING:      [our car] <-- safe gap --> [lead car] (match its speed)
```

In this project: cruise speed = 25 m/s (90 km/h). Files: `acc_config.m`.

---

## 2. Safe distance and time gap

Driving instructors teach the "2-second rule": stay at least 2 seconds behind
the car in front. We use a **time gap** of 1.5 s plus a standing buffer of 5 m:

```
 d_safe = d0 + t_gap * v = 5 + 1.5 * v
```

| our speed v | d_safe          |
|-------------|-----------------|
| 0 m/s       | 5 + 0 = 5 m     |
| 10 m/s      | 5 + 15 = 20 m   |
| 20 m/s      | 5 + 30 = 35 m   |
| 25 m/s      | 5 + 37.5 = 42.5 m |

Faster means a bigger gap, because you need more room to stop.
**Gap error** = gap minus d_safe. Gap 30 m at 20 m/s gives 30 - 35 = -5 m
(5 m too close). Files: `env_observe.m`, `acc_reward.m`.

---

## 3. What is reinforcement learning (RL)?

Think of a **learner driver** with no rule book. Nobody tells them the right
pedal at each moment. Instead, after every moment they get **marks**: good
marks for a nice safe gap, bad marks for tailgating, terrible marks for a
crash. By practising many times they slowly learn which choices lead to good
marks.

That is RL: **learning by trial, error and marks**, instead of learning from
a list of correct answers.

```
        +-------------- action (pedal) ------------->+
        |                                            |
   [ AGENT ]                                   [ ENVIRONMENT ]
   (the AI driver)                             (road, cars, physics)
        ^                                            |
        +------- new state + reward (marks) ---------+
```

---

## 4. Agent

The **agent** is the decision maker: our AI driver. Every 0.1 s it looks at
the situation and chooses one action. Files: `agent_act.m`, `agent_learn.m`.

## 5. Environment

The **environment** is everything the agent does not control: the road, the
lead car, the laws of motion. It takes the agent's action and answers
"here is what happened next, and here are your marks".
Files: `env_reset.m`, `env_step.m`, `env_observe.m`, `lead_profile.m`.

Physics in one line each (dt = 0.1 s):

```
 new speed    = speed + acceleration * 0.1
 new position = position + average speed * 0.1
```

Example: speed 20 m/s, acceleration -2 m/s^2 -> new speed 20 - 0.2 = 19.8 m/s.

We also model **engine/brake lag**: a real car does not jump instantly to the
acceleration you ask for. Our car closes about one third of the difference
every 0.1 s (time constant 0.3 s). Both the AI and the baseline get exactly the
same lag, so the comparison stays fair.

## 6. State

The **state** is what the agent sees at one moment. Ours has 6 numbers:

| # | meaning | example raw value | normalised (what the network sees) |
|---|---------|-------------------|-------------------------------------|
| 1 | our speed vs cruise speed | 20 m/s | 20/25 - 1 = -0.20 |
| 2 | relative speed (lead - us) | -3 m/s (we are closing in) | -3/10 = -0.30 |
| 3 | gap | 30 m | 30/150 = 0.20 |
| 4 | gap error (gap - d_safe) | 30 - 35 = -5 m | -5/50 = -0.10 |
| 5 | our current acceleration | -1 m/s^2 | -1/3 = -0.33 |
| 6 | the lead car's acceleration | -3 m/s^2 (it is braking) | -3/3 = -1.00 |

**Normalising** means dividing by a typical size so all numbers are roughly
between -1 and 1. A neural network learns badly if one input is 150 and
another is 0.3, the big one drowns out the small one.

Why number 5? We punish jerky driving (see reward). Jerk depends on what the
pedal is doing now, so the agent must be able to see it.

Why number 6? It is the AI's version of seeing brake lights. A car far
ahead that has just started braking hard looks, in the other 5 numbers,
almost like a car cruising along. Without number 6 the AI noticed too late
(see section 23, run 9).

## 7. Action

An **action** is what the agent can do. Ours: pick one acceleration from

```
 -3   -2   -1   -0.5   -0.25   0   +0.25   +0.5   +1   +2      (m/s^2)
 hard brake ......... gentle ... coast ... gentle ......... strong gas
```

Like a gear lever with 10 fixed positions. The small steps (-0.25, +0.25)
were added during tuning so the agent has a gentle option instead of
flicking between 0 and 0.5 (see section 23). File: `acc_config.m`.

## 8. Reward

The **reward** is the marks for one 0.1 s step. It is the only way we tell the
agent what "good driving" means, so it is the most important design choice.
File: `acc_reward.m`.

| situation | marks |
|-----------|-------|
| following a car, gap exactly d_safe | up to +1.0 per step |
| following, but still far behind (2 x d_safe or more) | marked like free road: +1.0 at 25 m/s |
| free road, speed exactly 25 m/s | +1.0 per step |
| gap smaller than d_safe | minus up to 2 |
| gap smaller than half of d_safe (danger) | minus up to 3 more |
| time to collision under 4 s | minus up to 1 |
| "braking needed" above 1.5 m/s^2 | minus up to 3 |
| strong acceleration, jerky pedal changes | small minus (comfort) |
| driving faster than the set speed | minus 0.15 per m/s too fast |
| crash | **-300** and the episode ends |

The four safety minuses together are capped at 2.5 per step, so that a
long close call never costs more than a crash (see section 23, run 8).

"Following" means: a car is within radar range AND it is either slower than
our cruise speed, or closer than d_safe. Otherwise it is "free road".

**Braking needed** comes from school physics, v^2 = 2*a*s. If we are closing
in on the lead at 18 m/s with 73 m left, the braking needed to stop closing
in is 18^2 / (2 * 73) = 2.2 m/s^2, close to our 3 m/s^2 limit. This warns
early, while the gap still looks big. If the lead car itself is braking,
we also count the distance it still rolls before it stops (section 23,
run 9), so the warning comes even earlier.

Small example: following at 20 m/s, d_safe = 35 m, gap = 35 m, speed matches
the lead. Gap score = 1.0, so reward is about 0.7 * 1.0 + 0.3 * (speed score)
minus tiny comfort costs. If the gap shrinks to 25 m: gap score drops to about
0.52 (bell width 0.25 * 35 = 8.75 m), plus a "too close" penalty of
2 * (10/35)^2 = 0.16.

**Blending by distance**: far behind a car, the right thing is simply to
cruise and catch up. So between d_safe and 2 x d_safe the marks slide from
"hold the gap" to "drive at cruise speed". Example: d_safe = 40 m, gap = 60 m
is halfway, so the marks are half "gap" and half "speed".

A full perfect episode (600 steps) would score about 600. A crash early on
gives about -300 and ends the practice drive.

## 9. Episode

An **episode** is one complete practice drive: 60 s = 600 steps, or less if it
ends in a crash. Then the world is reset with a new random traffic situation.
Like one driving lesson. File: `train.m`.

## 10. Policy

The **policy** is the agent's habit: "in situation s, I do action a". At the
start it is random. After training, our policy is: compute the 8 Q-values, pick
the biggest. File: `agent_act.m`, `run_episode.m`.

## 11. Q-value

The **Q-value** Q(s, a) is the agent's estimate of "how many marks will I
collect from now on, if I take action a now in situation s, and then keep
driving well".

Example: in some state the network outputs

```
 action:   -3    -2    -1   -0.5  -0.25   0   +0.25  +0.5   +1    +2
 Q-value:  41.0  43.5  47.2  48.9  48.6  48.1  46.0  44.0  30.2  12.5
```

The best is -0.5 m/s^2 (Q = 48.9), so the agent brakes gently.
Strong gas (+2) has a low Q-value because it probably leads to tailgating.

Future marks are **discounted** by gamma = 0.99 per step: a mark 1 step away
counts 0.99, 100 steps (10 s) away counts 0.99^100 = 0.37. So the agent cares
about roughly the next 10 seconds, enough to plan a braking manoeuvre.

The learning rule (the **Bellman equation**) in words:

```
 Q(now) should equal  (marks now) + 0.99 * (best Q next step)
```

If Q(now) says 48 but the marks now are 0.8 and the best next Q is 50,
the target is 0.8 + 0.99 * 50 = 50.3, so the agent raises its guess a bit.

## 12. Neural network

There are infinitely many possible states, so we cannot store a Q-value for
each one in a table. Instead a **neural network** is a formula with thousands
of adjustable knobs (weights) that takes the 5 state numbers and outputs the
8 Q-values.

```
 6 inputs --> [64 neurons] --> [64 neurons] --> 10 outputs (Q-values)
```

Each neuron: multiply each input by a weight, add them up, add a bias, then
apply **ReLU** = "if negative, make it 0".

Tiny example with 2 inputs: inputs (0.5, -1), weights (2, 1), bias 0.3
-> 0.5*2 + (-1)*1 + 0.3 = 0.3 -> ReLU(0.3) = 0.3. If the sum were -0.4,
ReLU gives 0.

Our network has 6*64 + 64 + 64*64 + 64 + 64*10 + 10 = **5,258 weights**, all
learned by us. Files: `nn_init.m`, `nn_forward.m`.

## 13. Backpropagation

After a prediction we know the **error** (prediction minus target). We want to
know: for each of the 5,064 weights, should it go up or down, and by how much?

**Backpropagation** answers that using the chain rule from calculus, working
backwards from the output to the input. Analogy: a team project got a bad
grade. Backpropagation works out how much each team member contributed to the
mistake, starting from the person who handed it in, then the people who fed
them, and so on.

Then each weight moves a small step in the direction that reduces the error.
That is **gradient descent**: walking downhill on an "error landscape".
File: `nn_backward.m`.

**Gradient check** (`gradient_check.m`): because we wrote backpropagation by
hand, a single wrong sign would silently break learning. So we measure each
slope directly: change one weight by +0.00001 and -0.00001, see how the error
changes, divide. If our formula and the measurement agree (they agree to about
1e-11 here), the maths is proven correct.

## 14. Optimiser (Adam)

Plain gradient descent takes steps of a fixed size. **Adam** is a smarter
walker: it remembers the average direction of recent steps (momentum, like a
ball rolling downhill) and takes smaller steps where the ground is bumpy.
Learning rate 0.0005 = tiny steps, so learning is slow but steady.
Files: `adam_init.m`, `adam_step.m`.

**Gradient clipping**: if one surprising experience produces a huge gradient,
we shrink it to a maximum size, so one weird moment cannot wreck the network.
**Huber loss** does a similar job on the error itself. File: `agent_learn.m`.

## 15. Replay buffer

The agent writes every moment into a notebook: (state, action, marks, next
state, crashed?). It holds the latest 100,000 moments. When learning, it
studies a **random mix of 64 old moments** at a time.

Why not just learn from the latest moment? Moments 0.1 s apart are almost
identical. Studying only them is like revising one page of the textbook 100
times in a row. A random mix is like a shuffled set of flashcards. It also
lets rare events (a hard brake) be studied many times.
Files: `replay_init.m`, `replay_add.m`, `replay_sample.m`.

## 16. Target network

When the agent learns, its target ("marks now + 0.99 * best next Q") uses its
own guesses. If the network changes, the targets change too, like trying to
hit a moving goalpost. So we keep a frozen copy, the **target network**, that
computes the targets and is refreshed only every 2,000 steps.

**Double DQN**: the online network picks the best next action, and the target
network says how good it is. This avoids over-optimism (believing your own
lucky guesses). File: `agent_learn.m`, `train.m`.

## 17. Epsilon-greedy exploration

If the agent always did what it currently thinks is best, it would never
discover anything better. So with probability **epsilon** it presses a random
pedal instead.

```
 episode   1: epsilon = 1.00  (100% random: knows nothing, just experiments)
 episode 240: epsilon = 0.53
 episode 480: epsilon = 0.05  (5% random: mostly uses what it learned)
```

Like a new cook trying random spices at first, then mostly sticking to the
recipes that worked. File: `agent_act.m`.

## 18. Training vs. testing

* **Training**: practice drives with random situations, exploring and learning.
* **Validation (mock test)**: every 10 episodes, 21 fixed drives with no
  random pedals. We keep the brain that scored best here.
* **Development set**: 30 extra drives with the same kind of situations as
  the exam but a different seed. Used by us (not by training) to diagnose
  problems and compare training runs, so the exam stays untouched.
* **Testing (final exam)**: 105 drives the agent has NEVER seen, from a
  different random seed and different number ranges, plus a whole scenario
  family ('mixed') that never appears in training. The weights are frozen,
  nothing is learned here. File: `evaluate.m`.

Using a separate exam is what makes the result honest. Testing on training
drives would be like grading a student on the exact questions they memorised.

## 19. Overfitting

**Overfitting** = memorising the practice questions instead of understanding
the subject. An overfit agent would drive perfectly in its practice drives
but badly in new ones. We guard against it by (a) random new scenarios every
episode, (b) choosing the saved brain by a separate mock test, and (c) judging
only on unseen exam drives.

## 20. What does a reward curve mean?

The reward curve (`results/training_reward_curve.png`) plots total marks per
episode against episode number.

* **Light blue**: each practice drive. Very jumpy, because every drive is a
  different situation and some pedals are random.
* **Dark blue**: average of the last 20 drives. This shows the trend.
  Going up = the agent is improving.
* **Red dots**: mock-test score (no random pedals). The most honest progress
  measure during training.
* **Black x**: a practice drive that ended in a crash. Common early, rare late.

A flat curve at the end means the agent has learned what it can with this
setup. A curve that rises then falls would be a warning sign (unstable
learning), which is why we keep the best mock-test brain, not simply the last.

## 21. The conventional controller (baseline)

The "rule book" ACC used in real cars, a **PD controller**:

```
 e        = gap - d_safe, but never more than e_max   ("saturation")
 a_follow = kp * e + kd * (lead speed - our speed)
 a_cruise = kv * (25 - our speed)
 a        = the smaller (more careful) of the two, limited to [-3, +2]
```

Why the cap e_max? Without it, a big gap (+50 m, "plenty of room!") cancels
a fast closing speed ("coming in fast!") and the controller brakes far too
late when a distant car brakes hard. We saw exactly this crash during
testing (section 23).

Example: kp = 0.2, gap error = -5 m, relative speed = -2 m/s, kd = 0.7:
a = 0.2 * (-5) + 0.7 * (-2) = -1.0 - 1.4 = -2.4 m/s^2 (brake firmly).

We tuned kp, kd, kv and e_max fairly with a grid search on training
scenarios, using the same marks as the AI. File: `baseline_acc.m`, `tune_baseline.m`.

## 22. RMS, RMSE and jerk (the exam metrics)

* **RMS** (root mean square) of values 1, -1, 3: square (1, 1, 9), average
  (3.67), square root (1.91). A "typical size" that punishes big values.
* **RMSE** = RMS of the errors. Speed RMSE 1.5 m/s means "typically 1.5 m/s
  away from the right speed".
* **Jerk** = how fast acceleration changes. Acceleration going from 0 to -2
  m/s^2 in 0.5 s is a jerk of -4 m/s^3. Low jerk = passengers' coffee stays
  in the cup.

File: `compute_metrics.m`.

---

## 23. The tuning journey (what went wrong, and how we fixed it)

Real machine learning is never "write it once and it works". These are the
actual problems we hit, in order. Each one is a good viva story.

**Run 1: it learned, but it was jerky.** After 450 episodes the AI never
crashed in the mock test, but it scored 417 marks per drive versus 452 for
the baseline. We split the marks into parts and found the biggest loss was
the jerk penalty: 11.5 points per drive for the AI versus 0.3 for the
baseline. The AI was "chattering": flicking between two pedal positions
whose Q-values were nearly equal.
*Fixes:* jerk penalty x4, two extra gentle actions (-0.25, +0.25), 700
episodes, and a learning rate that shrinks from 0.0005 to 0.0001 (big steps
early, careful steps at the end).

**Exam rehearsal: a crash for BOTH drivers.** In one hard-brake test the lead
was 117 m ahead, then braked from 25 to 3 m/s. The baseline did not brake
until the gap was 73 m and we were closing in at 18 m/s: too late. Its
formula let the big gap cancel the closing speed. The scenario was
survivable (braking early was easy), so the drivers were at fault, not the
scenario.
*Fixes:* (1) baseline gets spacing-error saturation e_max (standard
practice), tuned fairly; (2) the reward gets a "braking needed" penalty
that warns early at high closing speeds; (3) dangerous families (hard brake,
cut-in, stop-and-go) are practised more often.

**A loophole in the marking scheme.** Watching the demo, the AI sat at 21 m
behind a car that had cut in, when the safe distance was 42.5 m. The cut-in
car was going 25.2 m/s, a hair faster than our 25 m/s cruise speed, and our
reward only used "following mode" for slower cars. So the AI was marked on
speed alone and tailgating was nearly free. The AI did exactly what we
rewarded, not what we meant.
*Fix:* a car closer than d_safe always counts as "being followed".

Lesson: **an RL agent optimises the reward you wrote, not the behaviour you
had in mind.** Checking its behaviour with plots and animations, not just
its score, is how you catch this.

**Run 4: better, and a "refinement phase" that backfired.** With all fixes,
the AI held the safe distance more accurately than the baseline on the mock
test, and its jerk penalty dropped from 11.5 to 8.9. We then tried a second
"refinement" phase: 300 more episodes with almost no exploring and tiny
learning steps. It made things worse at first (crashes in the mock test)
and never beat the phase-1 best. Reason: it started with an empty notebook
and only saw its own good driving, so it forgot what trouble looks like.
We removed it. (Good lesson: exploring is not only for beginners.)

**The exam showed the truth.** On the 105 unseen tests the run-4 AI was
clearly worse than the baseline (gap error 10.8 m vs 6.2 m, and 1 crash).
The 12 mock-test drives had made it look better than it was: picking "the
best of many brains on just 12 drives" partly picks a lucky one. From then
on we used a separate **development set** (30 drives, exam-like situations,
different seed) for diagnosis, and kept the exam for the very end.

**Sparse reward: the AI that would not catch up.** The dev set showed the
worst drives all started with our car slow and the lead car far ahead. The
AI dawdled for the whole minute. Our reward only paid for the gap NEAR
d_safe, so from 128 m back there were no marks to be had, and the AI never
discovered that catching up pays off. Like a student who only gets marks
for the last question and never starts the test.
*Fix:* blend by distance (see section 8): far behind, it is marked like
free road, so driving at cruise speed to catch up earns marks right away.
Also: jerk weight 0.20, a slightly wider gap bell (0.25), 18 mock-test
drives, 800 episodes, and two training runs with different seeds.

**Run 6: zero crashes, but still fidgety.** Seed 2 looked better on the
18-drive mock test (439.7 vs 435.1) but crashed 3 times on the 30-drive dev
set, while seed 1 crashed 0 times. Picking between runs is exactly what the
dev set is for, so seed 1 won. On the exam it had zero crashes and nearly
the same gap error as the baseline (6.29 m vs 6.24 m), but twice the jerk.

**Run 7: a good idea that failed (and why).** The jerk penalty is squared:
0.2 * (jerk/5)^2. A tiny pedal wiggle with jerk 0.8 costs only
0.2 * (0.8/5)^2 = 0.005 marks, practically free. So we tried an
absolute-value penalty, 0.1 * |jerk|/5, which charges 0.016 for the same
wiggle (three times more). Result on the dev set: jerk got WORSE (2.1 vs
1.55) and one run crashed once. Why? The absolute penalty also made BIG
pedal changes about 4 times cheaper (jerk 10: 0.8 before, 0.2 after), so the
AI swapped many small wiggles for fewer big lurches. Our exam metric is RMS
jerk, which squares every value and punishes big lurches heavily.
Lesson: **give the penalty the same shape as the metric you care about.**
We went back to the run-6 model, which is the final one.

**Run 8: the live demo found three new problems.** Driving the grey car by
hand in the live demo, pressing STOP made the AI crash into it. A drive like
that was never in the exam, which is exactly why playing with the live demo
is useful. We found three separate causes:

1. *The "give up" trap.* Near a crash, the small safety penalties (too
   close, short time-to-collision, braking needed) added up, step after
   step, to MORE than the one-off crash penalty of -100. So for the AI,
   crashing quickly looked cheaper than suffering a long close call. It
   had learned that giving up pays. *Fix:* the crash now costs -300, and
   the safety penalties together are capped at 2.5 per step. Now a crash
   is always the worst thing that can happen.
2. *Driving above the set speed.* Nothing in the marks said "never go
   faster than the cruise speed", so sometimes it did, to close a gap
   faster. *Fix:* a small penalty for every m/s above 25 m/s.
3. *Never practised.* None of the training families looked like a person
   on a slider: long cruises, then sudden full stops. *Fix:* a new
   training family, `live_like`, that does exactly that.

**Run 9: the AI could not see brake lights.** After run 8 we tested 60
"press STOP" drives with the emergency brake switched OFF. Both the AI and
the classic controller still crashed in several of them, even when the
grey car braked no harder than 3 m/s^2. We printed one drive second by
second. The grey car was braking hard toward a stop, but the gap was still
100 m, so both drivers thought "plenty of room" and did nothing. Six
seconds later stopping in time was already impossible.

The reason: the AI's 5 inputs describe only ONE instant (speed, relative
speed, gap, gap error, own acceleration). A car 100 m ahead that has just
started braking hard looks almost exactly like a car cruising along. You
would see its brake lights; the AI could not. In RL language, the state
was missing information the agent needed (it was not "Markov": the best
action depended on something it could not see).

*Fixes:*
* A 6th input: **the lead car's acceleration**. Real ACC radars measure it
  (from how fast the relative speed changes). Now the network is
  6 -> 64 -> 64 -> 10.
* The "braking needed" penalty now counts the lead car's own stopping
  distance. If the lead car (at speed vl, braking at b) keeps braking to a
  stop, it still rolls vl^2 / (2 b) metres, and we must stop behind that
  point. Example: lead at 15 m/s braking at 3 m/s^2 rolls 37.5 m more; we
  do 25 m/s with an 87.5 m gap, so we need 625 / (2 x 123) = 2.5 m/s^2.
  Brake now, even though the gap still looks big.
* To keep the comparison fair, the classic controller gets the same
  information: a "feed-forward" term ka x (lead acceleration), which is
  standard in real ACC designs. Its 5 settings were re-tuned on training
  drives with the new marking scheme.

**Why the live demo also has an emergency brake.** In the live demo you
can brake the grey car at 4 m/s^2, but ACC may only brake at 3 m/s^2. If
the car ahead brakes harder than you are allowed to, from a short gap,
no driver can avoid it with 3 m/s^2: it is physics, not intelligence. Real
cars handle this with a second system, AEB (automatic emergency braking),
that only acts when a crash is close. The demo has one too, and counts how
often each driver needed it. A good ACC driver needs it rarely. The exam
does not use AEB at all.

Lesson: **test your AI in situations you did not design.** The exam
measures what you thought of; playing with it finds what you did not.
