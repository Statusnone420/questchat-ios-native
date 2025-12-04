# Quest System Spec

This document defines the XP economy, quest catalog, and generation rules for QuestChat.

---

## XP Economy

- XP per level: **100 XP**
- Level formula: `level = floor(totalXP / 100)`

### Quest Difficulty Tiers

| Difficulty | Code    | XP Reward |
|-----------|---------|-----------|
| Tiny      | TIER_1  | 10 XP     |
| Small     | TIER_2  | 20 XP     |
| Medium    | TIER_3  | 35 XP     |
| Big       | TIER_4  | 60 XP     |

All quest XP values below use these tiers.

---

## Quest Types and Categories

**Types**
- `daily_core` – core loop quests that most users should see
- `daily_habit` – user-selected habits (hydration, focus, chores, HP, etc.)
- `bonus` – optional extra quests with higher XP or extra conditions
- `weekly` – longer arcs spanning the week
- `streak` – “X days in a row” bonuses (no punishment if broken)

**Categories**
- `focus` – focus timers, deep work, productivity
- `hydration` – water intake
- `hp_core` – mood, gut, sleep, HP bar
- `chores_work` – chores, cleaning, errands, work sprints
- `meta` – app usage: quests tab, stats tab, planning, reviews

**Completion Events (conceptual)**
These refer to events or derived stats the app already has or can easily expose:

- `focus_session_started(durationMinutes)`
- `focus_session_completed(durationMinutes)`
- `quick_timer_completed(category, durationMinutes)`
- `hydration_total_today_oz`
- `hydration_log_events_today`
- `hp_checkin_completed` (mood + gut + sleep set)
- `hp_value_now`
- `hp_value_start_of_day`
- `quests_tab_opened_today`
- `stats_tab_opened_after(timeOfDay)`
- `current_time_of_day`
- `day_end_snapshot` (HP, hydration, etc.)

Implementation details can be adjusted, but each quest has a clear condition.

---

## Daily Core Quests (10)

These are the main pool of **daily_core** quests. The generator will always include some of them, not necessarily all.

| ID                         | Type        | Category   | Difficulty | XP  | Title                     | Subtitle                                                        | Completion Condition (concept)                                                                 |
|----------------------------|------------|-----------|-----------|-----|---------------------------|------------------------------------------------------------------|------------------------------------------------------------------------------------------------|
| LOAD_QUEST_LOG             | daily_core | meta      | Tiny      | 10  | Load today’s quest log    | Open the Quests tab to see what’s on deck.                      | First time the Quests tab is opened on a given day.                                            |
| PLAN_FOCUS_SESSION         | daily_core | focus     | Medium    | 35  | Plan one focus session    | Pick a timer and commit to at least one run today.             | Start any focus timer with duration ≥ 15 minutes.                                              |
| COMPLETE_FOCUS_SESSION     | daily_core | focus     | Big       | 60  | Finish a focus session    | See one focus run all the way to zero.                          | Complete any focus timer with duration ≥ 25 minutes.                                           |
| HEALTHBAR_CHECKIN          | daily_core | hp_core   | Medium    | 35  | HealthBar check-in        | Update mood, gut, and sleep for today.                          | Mood, gut, and sleep all set at least once today.                                              |
| HYDRATE_CHECKPOINT_16OZ    | daily_core | hydration | Small     | 20  | Hydrate checkpoint        | Drink a real glass of water before you start.                   | `hydration_total_today_oz >= 16`.                                                              |
| HYDRATE_CHECKPOINT_48OZ    | daily_core | hydration | Medium    | 35  | Middle of the map         | Get at least halfway to your daily water goal.                 | `hydration_total_today_oz >= 48`.                                                              |
| IRL_PATCH_UPDATE           | daily_core | hp_core   | Small     | 20  | IRL patch update          | Stretch for 2 minutes and un-gremlin your spine.               | Complete any “Stretch” / “Movement” quick timer ≥ 2 minutes.                                   |
| CHORE_BLITZ                | daily_core | chores_work| Medium   | 35  | Chore blitz               | Clear a small IRL dungeon.                                      | Complete any “Chores” category timer with duration ≥ 10 minutes.                               |
| STATS_REVIEW               | daily_core | meta      | Tiny      | 10  | Check your stats          | Take a quick peek at today’s progress.                          | Open the Stats tab at least once after 7pm local time.                                         |
| WINDDOWN_ROUTINE           | daily_core | hp_core   | Small     | 20  | Wind-down routine         | Give Future You a calmer morning.                               | After 8pm, either update sleep slider OR complete any non-work timer ≥ 10 minutes.             |

---

## Daily Habit Quests (16)

These are `daily_habit` quests pulled based on user-selected habits. The app can let the user toggle which categories they care about (hydration/focus/chores/hp).

### Hydration Habit Quests

| ID                         | Type        | Category   | Difficulty | XP  | Title                      | Subtitle                                          | Completion Condition                                                          |
|----------------------------|------------|-----------|-----------|-----|----------------------------|--------------------------------------------------|-------------------------------------------------------------------------------|
| HYDRATE_NOW_GLASS          | daily_habit| hydration | Tiny      | 10  | Potion sip                | Drink one real glass right now.                  | Log ≥ 8 oz of water after the quest is generated (same calendar day).        |
| HYDRATE_32OZ               | daily_habit| hydration | Small     | 20  | Halfway to full flask     | Hit at least 32 oz today.                        | `hydration_total_today_oz >= 32`.                                            |
| HYDRATE_64OZ               | daily_habit| hydration | Medium    | 35  | Full flask kind of day    | Hit 64 oz of water today.                        | `hydration_total_today_oz >= 64`.                                            |
| HYDRATE_MULTI_CHECKPOINT   | daily_habit| hydration | Medium    | 35  | Split the potions         | Log water at 3 or more separate times today.     | `hydration_log_events_today >= 3`.                                           |

### Focus Habit Quests

| ID                         | Type        | Category | Difficulty | XP  | Title                         | Subtitle                                             | Completion Condition                                                                 |
|----------------------------|------------|---------|-----------|-----|-------------------------------|-----------------------------------------------------|--------------------------------------------------------------------------------------|
| FOCUS_TWO_SESSIONS         | daily_habit| focus   | Medium    | 35  | Double focus                  | Complete two focus sessions today.                  | `focus_session_completed(duration >= 15m)` count ≥ 2.                                |
| FOCUS_DEEP_SESSION         | daily_habit| focus   | Big       | 60  | Deep dungeon dive             | One long, uninterrupted focus session.              | Complete one focus session with duration ≥ 45 minutes.                               |
| FOCUS_NO_DROP_SESSION      | daily_habit| focus   | Small     | 20  | No flinches                   | Start and finish a session without pausing.         | Complete a focus session ≥ 15 minutes with zero pauses / cancels.                    |
| FOCUS_MORNING_SESSION      | daily_habit| focus   | Small     | 20  | Morning initiative            | Win the morning with a focus run.                   | Complete any focus session ≥ 15 minutes that ends before 11am.                       |

### HP Core Habit Quests

| ID                         | Type        | Category | Difficulty | XP  | Title                         | Subtitle                                           | Completion Condition                                                                 |
|----------------------------|------------|---------|-----------|-----|-------------------------------|---------------------------------------------------|--------------------------------------------------------------------------------------|
| HP_TRIPLE_CHECK            | daily_habit| hp_core | Small     | 20  | Full system scan              | Log mood, gut, and sleep once today.              | Mood, gut, and sleep all updated at least once (same as HEALTHBAR_CHECKIN but optional). |
| HP_MOOD_BOOST              | daily_habit| hp_core | Medium    | 35  | Mood buff                     | Move your HP in the right direction.              | Log mood/gut/sleep, and HP value becomes higher than previous check-in.              |
| HP_STRETCH_TRIPLE          | daily_habit| hp_core | Medium    | 35  | Stretch combo                 | Shake off stiffness multiple times.               | Complete any “Stretch/Movement” quick timer 3 separate times today.                  |
| HP_HIGH_STATE              | daily_habit| hp_core | Medium    | 35  | Stay battle-ready             | Keep your HP high for most of the day.            | At day end snapshot, `hp_value_now >= 75`.                                           |

### Chores / Work Habit Quests

| ID                         | Type        | Category    | Difficulty | XP  | Title                         | Subtitle                                             | Completion Condition                                                                |
|----------------------------|------------|------------|-----------|-----|-------------------------------|-----------------------------------------------------|-------------------------------------------------------------------------------------|
| CHORE_THREE_SMALL          | daily_habit| chores_work| Medium    | 35  | Three tiny wins               | Knock out three small chores.                       | Complete 3 “Chores” timers with duration ≥ 5 minutes each.                          |
| WORK_SPRINT_25             | daily_habit| chores_work| Big       | 60  | Work sprint                   | Do a focused 25-minute work burst.                  | Complete a “Work” timer with duration ≥ 25 minutes.                                  |
| WORK_EARLY_BLOCK           | daily_habit| chores_work| Small     | 20  | Early shift                   | Get one work thing done before noon.                | Complete a “Work” timer ≥ 15 minutes that ends before 12pm.                          |
| CHORE_ROOM_RESET           | daily_habit| chores_work| Small     | 20  | Room reset                    | Do a cleaning pass somewhere that matters.          | Complete any “Chores” timer ≥ 10 minutes whose label includes “clean” or “tidy” if available. |

---

**Deprecated daily quest**

- `digital-cobweb` — Retired from rotation until a dedicated event source exists.

## Weekly Quests (8)

These are `weekly` type quests that sit in a separate “Weekly quests” section with longer-term goals.

| ID                         | Category    | Difficulty | XP  | Title                             | Subtitle                                                    | Completion Condition                                                                                 |
|----------------------------|------------|-----------|-----|-----------------------------------|------------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| WEEK_FOCUS_10_SESSIONS     | focus      | Medium    | 120 | Weekly focus grind                | Complete 10 focus sessions this week.                      | Count of `focus_session_completed(duration >= 15m)` ≥ 10.                                            |
| WEEK_FOCUS_3_DEEP          | focus      | Big       | 150 | Deep work trilogy                 | Finish three 45+ minute focus sessions.                    | Count of `focus_session_completed(duration >= 45m)` ≥ 3.                                             |
| WEEK_HYDRATE_4_DAYS_64OZ   | hydration  | Medium    | 120 | Hydration hero                    | Hit 64 oz of water on 4 different days.                    | On 4 days this week, `hydration_total_today_oz >= 64`.                                              |
| WEEK_CHORE_5_TIMERS        | chores_work| Medium    | 120 | Dungeon janitor                   | Run 5 “Chores” timers across the week.                     | Count of “Chores” timers (duration ≥ 10m) ≥ 5.                                                       |
| WEEK_HP_5_CHECKINS         | hp_core    | Medium    | 120 | Keep an eye on the bar            | Full HP check-in on 5 days.                                | On 5 days this week, mood + gut + sleep all updated.                                                |
| WEEK_DAILY_CORE_4_DAYS     | meta       | Big       | 150 | Four solid days                   | Clear your core dailies on 4 days this week.               | On 4 days this week, all `counts_for_daily_chest` quests completed.                                 |
| WEEK_SELFCARE_3_DAYS       | hp_core    | Medium    | 120 | Pamper the protagonist            | Do self-care timers on 3 different days.                   | On 3 days, complete at least one timer with category “Self-care” / appropriate flag.                |
| WEEK_MOVEMENT_3_DAYS       | hp_core    | Medium    | 120 | Keep the character moving         | Move your body at least 3 days this week.                  | On 3 days, complete a “Movement/Stretch/Walk” timer ≥ 10 minutes.                                   |

---

## Quest Generation Rules

### Daily Quest Generation

When a new day starts (or on first app open after midnight):

1. **Reset daily quests**
   - Mark all previous daily quests as archived.
   - Generate a new set for the current day.

2. **Core anchors (always included)**
   - Always include these three `daily_core` quests:
     - `LOAD_QUEST_LOG`
     - `PLAN_FOCUS_SESSION`
     - `HEALTHBAR_CHECKIN`

3. **Additional core quests**
   - Randomly select **2 more** quests from the remaining `daily_core` pool:
     - `COMPLETE_FOCUS_SESSION`
     - `HYDRATE_CHECKPOINT_16OZ`
     - `HYDRATE_CHECKPOINT_48OZ`
     - `IRL_PATCH_UPDATE`
     - `CHORE_BLITZ`
     - `STATS_REVIEW`
     - `WINDDOWN_ROUTINE`
   - Avoid picking two hydration quests at once if Hydration habits are off.

4. **Habit quests**
   - For each habit category the user has enabled (hydration/focus/hp_core/chores_work), pick **1 random `daily_habit` quest** from that category.
   - Max of **4 habit quests** per day.
   - If user has fewer habit categories enabled, you may pick a second quest from a high-priority habit (e.g., focus or hydration).

5. **Bonus quest**
   - Optionally add **1 `bonus` quest** (can reuse a `daily_habit` or `daily_core` definition but flagged as bonus) based on what was low yesterday:
     - If focus minutes were low → prefer a focus quest.
     - If hydration was low → prefer a hydration quest.
     - If HP was low → prefer an HP quest.

6. **Quest chest requirement**
   - Every day, exactly **4 quests** are flagged `counts_for_daily_chest = true`:
     - `LOAD_QUEST_LOG`
     - `PLAN_FOCUS_SESSION`
     - `HEALTHBAR_CHECKIN`
     - 1 additional quest (either a habit quest or a core quest chosen by the generator).
   - When all `counts_for_daily_chest` quests are completed, the user can claim the Quest Chest.
   - **Chest reward:** 75 XP (flat).

7. **Total daily XP target (from quests)**
   - With the above mix, a “normal” day should offer:
     - 3 core anchors ≈ 80 XP
     - 2 extra core quests ≈ 40–95 XP
     - 2–4 habit quests ≈ 70–160 XP
     - Chest reward: 75 XP  
     -> Rough range ≈ **190–310 XP** from quests alone, plus XP from timers if you award that separately.

### Weekly Quest Generation

When a new week starts (or first app open on the start-of-week day):

1. **Reset weekly quests**
   - Archive last week’s weekly quests and snapshot their state.

2. **Generate weekly quests**
   - Always include these four:
     - `WEEK_FOCUS_10_SESSIONS`
     - `WEEK_HYDRATE_4_DAYS_64OZ`
     - `WEEK_HP_5_CHECKINS`
     - `WEEK_DAILY_CORE_4_DAYS`
   - Then pick **2 additional** from:
     - `WEEK_FOCUS_3_DEEP`
     - `WEEK_CHORE_5_TIMERS`
     - `WEEK_SELFCARE_3_DAYS`
     - `WEEK_MOVEMENT_3_DAYS`
   - Total weekly quests visible: **6** at a time.

3. **Weekly progress**
   - Progress updates passively as normal events occur (no special actions needed).
   - Weekly quests never block daily quests; they are always optional extra XP.

### Reroll Rules

- User may **reroll 1 daily quest per day**.
- Only **incomplete** quests can be rerolled.
- Reroll picks a replacement quest that:
  - Matches the **same type** (`daily_core` vs `daily_habit` vs `bonus`).
  - Matches the **same difficulty tier** (Tiny/Small/Medium/Big).
  - Preferably matches the **same category** (hydration/focus/etc.) to avoid punishment.
- If the rerolled quest was `counts_for_daily_chest = true`, the replacement quest also gets `counts_for_daily_chest = true`.

---

