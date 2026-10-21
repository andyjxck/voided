# Step 3: screen readers, browser playtest, design doc

Step 3 makes the game screen usable with a screen reader, fixes a phone drag bug found in the browser playtest, and adds DESIGN.md. 106 tests pass (92 before, 14 new), `flutter analyze` finds no issues, and `flutter build web` succeeds. No balance numbers changed.

## Screen readers

What step 2 saw: with semantics on, the game screen was one unlabelled group of raw text ("GET READY 3s 0/100 100 0 ..."). In this step's headless Chrome check the text did change over time, but it had no meaning (the pennies and leaves were bare numbers), the board was invisible, and nothing was ever announced.

What changed (`lib/ui/a11y.dart`, `lib/ui/game_screen.dart`, `lib/ui/widgets.dart`):

- **Top bar:** one label in words: wave, seconds to the next wave or left on the boss, sea things on the pier, pennies and leaves. Built from whole seconds and counts, so it changes about once a second (a test checks under 300 changes in 30 seconds of play, against 1,800 frames).
- **Boss bar:** name, title, health rounded to 5%, shield and seconds left.
- **Board:** a summary of both boards, and each of your 18 spots as an invisible button with its contents ("Spot 4, row 1: 2 Lifeguard Lou, Rare. Ready to merge."). Double-tap selects, a custom action swaps with the selected spot. Only built while semantics are on; pointer events pass through.
- **Announcements:** `GameNarrator` speaks wave starts, boss arrival and mechanic, 15 seconds left on a boss, boss defeated, the pier passing 50, 75 and 90, the results of your own actions, errors and the end of the run. One line per 2 seconds at most, 3 queued at most, quick summons replace each other, the end of the run goes out at once.
- **Transient banner and toast** are left out of the tree, since they're announced.
- **Summon button** reads "Summon a figurine, N pennies".

Checked in headless Chrome at 390 × 844: the tree shows the labels and updates as the game runs, and the browser's live region spoke, for example, "Summoned Admiral Tinbeak, Rare.", "Wave 1 of 40.", "Need 27 pennies.", "Moved to Spot 18, row 3.", "Boss wave 10: Mother Brine, She Who Puddles. Spawns three Drips every 6 seconds. 60 seconds to beat it."

## Browser playtest

Scripted in headless Chrome on the release build, phone (390 × 844, plus 360 × 640 for the drag) and desktop (1280 × 800), with real taps, clicks and touch drags:

- **Merge:** worked on phone and desktop (select a ready spot, press MERGE).
- **Gamble:** worked on both; leaves went from 3 to 2 and the result showed and was spoken.
- **Boss fight:** played to wave 10 at 2× speed on both; Mother Brine was beaten and the run carried on into wave 11. No page or console errors.
- **Drag-to-swap: bug on phones, fixed.** On desktop it worked. On a phone the drag picked up the wrong figurine: the field's drag reported where the drag was recognised, after Flutter's touch slop (about 36 px), which is past the edge of a phone-sized spot, so it moved the neighbour in the drag direction. The field now uses `DragStartBehavior.down`. Rechecked in the browser at 390 × 844 and 360 × 640: the right figurine moves. `test/touch_drag_test.dart` fails without the fix and passes with it.

## New tests

- `test/a11y_test.dart` (12): HUD, boss and board labels, label churn, narrator throttling, queue limit, summon replacement, boss and lane announcements, end of run, and a widget test of the live screen with semantics on.
- `test/touch_drag_test.dart` (2): a touch drag along a row at 390 × 844 and 360 × 640.

## Still open

- Not tried with a real screen reader (VoiceOver, TalkBack, NVDA).
- Brenda's chat is readable but not announced, and enemy positions aren't described beyond the lane count.
- Screenshots of the playtest are in `/tmp/ld/shots` on this machine, not in the repo; the look and feel still need a person.
