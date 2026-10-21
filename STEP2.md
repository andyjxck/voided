# Step 2: tests, balance, web build and browser playtest

Nothing pushed. `flutter analyze`: no issues. `flutter test`: 92 passed, 0 failed (about 45 s).

## Tests (test/)

- `sim_test.dart` (33): summon odds (sum to 100 at every luck level, luck clamps, 40,000 rolls match the odds within 1 point, the Machine's Mercy streak cap, rising price, Bent Coin only for you, broke/full-board refusals); merge-3 (three into next tier, two not enough, Legendaries don't merge, stacking, Mythic recipe); economy (starting purse and meta bonuses, wages plus a leaf every fifth wave, kill rewards, selling, in-run upgrades, Elbow Grease, gamble odds); wave scaling (HP curve 15%/12%/9%, spawn counts, enemy pool, boss and Big Drip waves, difficulty HP, overrun at the lane limit); Solo HP (one constant in 0.5 to 0.65, applied to every enemy, boss and Bailiff); bosses (HP and timer, timer loss, Mother Brine's Drips, the Inspector condemning your strongest cell and ignoring slow/stun, the Undertow's dive-heal-surge, the Landlord's shields, Bailiffs and rent, boss payout, wave 40 win).
- `meta_test.dart` (25): payouts per wave/boss/win and difficulty, unlocks, no double pay, Endless pays only new progress, best waves, album; Back Room buy/max/afford and feed into GameConfig, total cost sanity; eleven jobs, pay once, Solo/Storm jobs, stat jobs; save round-trip, seven broken saves load fresh, unknown ids dropped and values clamped.
- `balance_test.dart` (7): bot-played batches of 16 seeds on the real sim (below).
- `layout_test.dart` (27): every screen at 390x844, 1280x800 and 360x640, including 40 s of live play in each mode and the tutorial. Fails on any overflow or exception.

## Solo health: kept at 0.5

Calm plus Choppy win rates added together (16 seeds each, full-skill bot): co-op 1.63, Solo at 0.5 is 1.38, Solo at 0.65 is 0.88. 0.5 is closest to co-op; 0.65 makes Solo clearly harder. It stays one constant, `kSoloHpMultiplier`, and a test pins both facts.

## Balance: no number changes

Bot results (16 seeds, no Back Room upgrades):

| | Co-op | Solo |
|---|---|---|
| Calm, full-skill bot | 100%, final boss left 22 s of 60 | 88%, 30 s left |
| Calm, slow sloppy bot (skill 0.5, 1.5 s per move) | 81% | 75% |
| Choppy | 63% | 50% |
| Storm | 19%, median death wave 30 | 25%, median wave 30 |
| Storm with a full Back Room | 44% | 69% |

Calm looks easy only for the bot: it moves every 0.4 s and never misplays, and the final boss still eats a third or more of its timer. A slow bot wins three in four, which is the right place for a new player. Choppy and Storm are each a clear step down. The Back Room takes roughly 10 to 14 runs to fill (1,235 sea glass), and a full one roughly doubles Storm odds without making it free. None of this was clearly off, so I left the upgrade sizes, sea glass rates and job rewards alone. The balance tests fail if any of those bands drift.

## Browser playtest (headless Chromium, release build served locally)

Phone 390x844 (touch), small phone 360x640 and desktop 1280x800. Co-op with the full tutorial on phone and desktop, Solo on phone and desktop. Summoning, the tutorial steps, speed, pause and the timer were checked by tapping and comparing screenshots. No page errors or console errors on any run.

Fixed:
- **Game screen created a new FocusNode every frame** (60 a second, never disposed) and asked for focus each time. Now one node, disposed with the screen.
- **OPEN UP was below the fold** on a 360x640 phone (only 11 px showing). It is now pinned under the scrolling list on every size.
- **Summon button** text could wrap and overflow its 58 px height on the narrow desktop side panel; it now scales down to fit.
- **Phone HUD**: wave label and timer scale down instead of overflowing; the lane meter drops the words "on the pier" below 190 px and keeps the numbers; the speed and pause buttons are compact.
- **Menu toggles** (Sound, Music, Shake) wrap instead of overflowing.
- **Tutorial**: the Skip button can shrink, and Enter now advances the tip on desktop (added to the key hint).

## For step 3

- With the browser's accessibility tree switched on, the game screen's tree goes stale (it rebuilds every frame), so screen readers can't follow it. Normal mouse and touch input works.
- Not exercised in the browser: drag-to-swap, merging from the selection panel, gambles, a boss, or a whole run. The sim and widget tests cover the rules.
- I could not look at the screenshots myself, so readability and feel still need a human eye. They are not in the repo.
- A typical Storm run ends around wave 30 for the bot; worth a human playtest before tuning further.
- `tool/balance.dart` is still the quick way to rerun the numbers: `dart run tool/balance.dart 30 [soloMult] [skill]`.
