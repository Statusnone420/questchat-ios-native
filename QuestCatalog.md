# Quest System Spec - Version 1.6.2

> **IMPORTANT**: This document reflects the quest system as of version 1.6.2.
> Last updated: December 2025
>
> This is the authoritative reference for all quest IDs, titles, rewards, and completion conditions.
> The actual implementation in QuestCatalog.swift should match these tables.

This document defines the XP economy, quest catalog, timer categories, and generation rules for QuestChat Native (iOS).

---

## XP Economy

- **XP per level**: 100 XP
- **Level formula**: `level = floor(totalXP / 100)`

### Quest Difficulty Tiers

| Difficulty | XP Range  | Typical Use Case |
|-----------|-----------|------------------|
| Tiny      | 10 XP     | Quick wins, first steps |
| Easy      | 10-20 XP  | Simple daily habits |
| Small     | 20 XP     | Light effort tasks |
| Medium    | 35-40 XP  | Moderate effort, longer timers |
| Big/Hard  | 60-200 XP | Challenging goals, weekly milestones |

---

## Timer Categories (v1.6.2)

The app uses these timer categories for quest tracking:

| Category ID  | Display Title | Purpose |
|-------------|---------------|---------|
| `create` | Create | Creative work, making things |
| `focusMode` | Focus Mode | Deep work, concentration sessions |
| `chores` | Chores | Cleaning, organizing, errands |
| `selfCare` | Self-Care | Rest, recovery, wellness |
| `gamingReset` | Gaming Reset | Intentional gaming/leisure |
| `move` | Move | Exercise, stretching, physical activity |

---

## Quest System Overview

### Quest Types
- **daily** – Quests that reset every day
- **weekly** – Quests that span the entire week

### Quest Categories (in code)
- **timer** – Completion requires finishing timers
- **healthBar** – Related to health tracking (mood, sleep, hydration, gut, posture)
- **meta** – App engagement (opening tabs, completing setup)
- **easyWin** – Quick, low-barrier completions

### Quest Tiers
- **core** – Essential daily quests, often contribute to daily chest
- **habit** – Optional habit-building quests
- **bonus** – Extra challenges with higher rewards

---

## Daily Quests - Active Pool (v1.6.2)

### Streamlined Daily Quests (19 quests)
These are quick, dopamine-hit quests with low XP (10-20). The system picks 5 per day.

#### Timer Category (5 quests)

| Quest ID | Title | Subtitle | XP | Difficulty | Category | Tier |
|----------|-------|----------|----|-----------|---------| -----|
| `DAILY_TIMER_QUICK_WORK` | Self Care Aficionado | Complete a Create, Self-Care, or Move session for 10 or more minutes. | 15 | easy | timer | habit |
| `DAILY_TIMER_CHORES_BURST` | Chore Burst | Complete a chores timer for 5+ minutes. | 15 | easy | timer | habit |
| `DAILY_TIMER_MINDFUL_BREAK` | Mindful Moment | Finish a Self-Care timer for 5+ minutes. | 15 | easy | timer | habit |
| `DAILY_TIMER_CHILL_CHOICE` | Nerd Time | Complete a 10 or more minute gaming session timer. | 15 | easy | timer | habit |
| `DAILY_TIMER_GAMING_SESSION` | Guilt-Free Gaming | Complete a 5 or more minute gaming session timer. | 15 | easy | timer | habit |

#### HealthBar Category (5 quests)

| Quest ID | Title | Subtitle | XP | Difficulty | Category | Tier |
|----------|-------|----------|----|-----------|---------| -----|
| `DAILY_HB_MORNING_CHECKIN` | Morning Check-In | Log today's mood. | 15 | easy | healthBar | habit |
| `DAILY_HB_SLEEP_LOG` | Sleep Log | Log how you slept last night. | 15 | easy | healthBar | habit |
| `DAILY_HB_FIRST_POTION` | First Potion | Log your first Mana Potion (hydrate!) today. | 15 | easy | healthBar | habit |
| `DAILY_HB_POSTURE_CHECK` | Posture Check | Acknowledge one posture reminder. | 15 | easy | healthBar | habit |
| `DAILY_HB_GUT_CHECK` | Gut Check-In | Log today's gut health. | 15 | easy | healthBar | habit |

#### Meta Category (3 quests)

| Quest ID | Title | Subtitle | XP | Difficulty | Category | Tier |
|----------|-------|----------|----|-----------|---------| -----|
| `DAILY_META_SETUP_COMPLETE` | Daily Setup | Complete sleep + mood + hydration setup. | 20 | easy | meta | core |
| `DAILY_META_STATS_TODAY` | Check Your Stats | View your progress in the Stats tab. | 15 | easy | meta | core |
| `DAILY_META_PLAYER_CARD` | Player Card | Open your Player Card. | 15 | easy | meta | core |

#### EasyWin Category (6 quests)

| Quest ID | Title | Subtitle | XP | Difficulty | Category | Tier |
|----------|-------|----------|----|-----------|---------| -----|
| `DAILY_EASY_TINY_TIDY` | Tiny Tidy | Complete a Chores timer for 3+ minutes. | 10 | easy | easyWin | bonus |
| `DAILY_EASY_ONE_NICE_THING` | One Nice Thing | Complete any timer for 5+ minutes. | 10 | easy | easyWin | bonus |
| `DAILY_EASY_HYDRATION_SIP` | Hydration Sip | Log at least 4oz of water. | 10 | easy | easyWin | bonus |
| `DAILY_EASY_FIRST_QUEST` | First Quest | Complete your first quest today. | 10 | easy | easyWin | bonus |
| `DAILY_EASY_TWO_CHAIN` | Quest Chain | Complete 2 quests within 10 minutes. | 15 | easy | easyWin | bonus |
| `DAILY_EASY_THREE_CHAIN` | Triple Chain | Complete 3 different quests within 30 minutes. | 15 | easy | easyWin | bonus |

### Legacy Daily Quests (11 quests - still available)

| Quest ID | Title | Subtitle | XP | Difficulty | Category | Tier |
|----------|-------|----------|----|-----------|---------| -----|
| `daily-checkin` | Load today's quest log | Open the quest log and feel accomplished today. | 10 | tiny | meta | core |
| `plan-focus-session` | Plan one focus session | Start a session timer that runs for at least 15 minutes today. | 35 | medium | timer | core |
| `healthbar-checkin` | HealthBar check-in | Update your mood, gut, and sleep before you go heads-down. | 35 | medium | healthBar | core |
| `chore-blitz` | Chore blitz | Run a Chores timer for at least 10 minutes to clear a small dungeon. | 35 | medium | timer | core |
| `finish-focus-session` | Finish one focus session | Complete a session timer that lasts 25 minutes or longer. | 35 | medium | timer | habit |
| `focus-25-min` | Hit 25 focus minutes today | Accumulate at least 25 minutes of session time. | 60 | big | timer | bonus |
| `hydrate-checkpoint` | Hydrate checkpoint | Drink at least 16 oz of water before a session starts. | 20 | small | healthBar | habit |
| `hydration-goal` | Hit your hydration goal today | Stay on top of water throughout the day. | 60 | big | healthBar | bonus |

**Disabled Legacy Quests** (removed from pool):
- `irl-patch` - IRL patch update
- `tidy-spot` - Tidy one small area
- `step-outside` - Step outside or change rooms
- `quick-self-care` - Do one quick self-care check

### Daily Quest Selection Rules

The game generates **5 daily quests** per day:
- **Max 2** timer quests
- **Min 1** HealthBar quest
- **Min 1** easyWin quest
- Preference for variety across categories

---

## Weekly Quests (v1.6.2)

### Active Weekly Quest Pool (15 quests)

The game shows **5-6 weekly quests** at a time, with a core set that always appears plus rotational extras.

#### Timer Category Weekly Quests

| Quest ID | Title | Subtitle | XP | Difficulty | Tier |
|----------|-------|----------|----|-----------| -----|
| `WEEK_WORK_WARRIOR` | Focus Consistency Champion | Complete 5 focus mode timers of 25+ minutes this week. | 120 | medium | bonus |
| `WEEK_DEEP_WORK` | Look Ma, No Focus Meds! | Accumulate 200 or more minutes of focus mode minutes this week. | 200 | hard | bonus |
| `WEEK_CLUTTER_CRUSHER` | Clutter Crusher | Accumulate 90+ Chores minutes this week. | 120 | medium | bonus |
| `WEEK_SELFCARE_CHAMPION` | Self-Care Champion | Complete 4 Self-Care timers of 15+ minutes on different days. | 120 | medium | bonus |
| `WEEK_EVENING_RESET` | Evening Reset Ritual | On 3 days, complete a Chores/Self-Care timer 15+ minutes after 6pm. | 120 | medium | bonus |

#### HealthBar Category Weekly Quests

| Quest ID | Title | Subtitle | XP | Difficulty | Tier |
|----------|-------|----------|----|-----------| -----|
| `WEEK_HYDRATION_HERO_PLUS` | Hydration Hero Week | Hit your hydration goal on 4 days. | 120 | medium | habit |
| `WEEK_HYDRATION_DEMON` | Hydration Demon Week | Hit hydration goal on 6+ days. | 200 | hard | bonus |
| `WEEK_MOOD_TRACKER` | Mood Tracker | Log mood on 5 days. | 120 | medium | habit |
| `WEEK_SLEEP_SENTINEL` | Sleep Sentinel | Log sleep on 5 days. | 120 | medium | habit |
| `WEEK_BALANCED_BAR` | Balanced Bar | On 3 days this week: log mood and sleep, and reach at least 50% of your water goal. | 140 | medium | habit |

#### Meta Category Weekly Quests

| Quest ID | Title | Subtitle | XP | Difficulty | Tier |
|----------|-------|----------|----|-----------| -----|
| `WEEK_DAILY_SETUP_STREAK` | Daily Setup Streak | Complete Daily Setup on 5 days. | 140 | medium | habit |
| `WEEK_QUEST_FINISHER` | Quest Finisher | Complete 20+ daily quests this week. | 120 | medium | habit |
| `WEEK_MINI_BOSS` | Mini-Boss Week | Finish 3+ Hard difficulty quests. | 200 | hard | bonus |
| `WEEK_THREE_GOOD_DAYS` | Three Good Days | Have 3 days with 4+ quests completed. | 140 | medium | habit |
| `WEEK_WEEKEND_WARRIOR` | Weekend Warrior | On Sat/Sun, complete 2 quests and 1 timer 20+ minutes. | 140 | medium | habit |

### Core Weekly Quest IDs (always included)

These 5 quests always appear in the weekly rotation:
1. `WEEK_HYDRATION_HERO_PLUS`
2. `WEEK_BALANCED_BAR`
3. `WEEK_DAILY_SETUP_STREAK`
4. `WEEK_THREE_GOOD_DAYS`
5. `WEEK_SLEEP_SENTINEL`

### Legacy Weekly Quests (6 quests - still available)

| Quest ID | Title | Subtitle | XP | Difficulty | Tier |
|----------|-------|----------|----|-----------| -----|
| `weekly-focus-marathon` | Weekly focus marathon | Hit 120 total session minutes this week. | 100 | hard | bonus |
| `weekly-session-grinder` | Session grinder | Complete 15 timed sessions this week. | 100 | hard | bonus |
| `weekly-daily-quest-slayer` | Daily quest slayer | Complete 20 daily quests this week. | 60 | medium | habit |
| `weekly-health-check` | Health check-in | Log mood, gut, and sleep on 4 days this week. | 60 | medium | habit |
| `weekly-hydration-hero` | Hydration hero | Hit your hydration goal on 4 days this week. | 60 | medium | habit |

**Disabled Weekly Quest**:
- `weekly-digital-dust` - Digital dust buster (manual debug mode only)

---

## Quest Completion Events

These are the key events that trigger quest progress in the app:

### Timer Events
- `focusSessionStarted(durationMinutes: Int)`
- `focusSessionCompleted(durationMinutes: Int)`
- `timerCompleted(category: TimerCategory.Kind, durationMinutes: Int, endedAt: Date)`
- `focusMinutesUpdated(totalMinutesToday: Int)`
- `focusSessionsUpdated(totalSessionsToday: Int)`
- `choresTimerCompleted(durationMinutes: Int)`

### HealthBar Events
- `hpCheckinCompleted` (mood + gut + sleep logged)
- `hydrationLogged(amountMl: Int, totalMlToday: Int, percentOfGoal: Double)`
- `hydrationGoalReached`
- `hydrationGoalDayCompleted`
- `postureReminderFired`

### Meta Events
- `questsTabOpened`
- `dailySetupCompleted`
- `statsViewed(scope: StatsScope)` - where scope is `.today` or `.yesterday`
- `playerCardViewed`
- `hydrationReminderFired`

---

## Generation & Progression Rules

### Daily Quest Generation

1. **Reset Timing**: New daily quests generate at midnight local time (or on first app open after midnight)
2. **Selection**: Pick 5 quests from the combined daily pool (streamlined + legacy)
3. **Distribution Rules**:
   - Max 2 timer quests
   - Min 1 healthBar quest
   - Min 1 easyWin quest
   - Avoid repeating the same quest more than 2 days in a row
4. **Mystery Quest**: One quest can be marked as "mystery" with a hint (optional feature)
5. **Quest Chest**: Completing 4+ core quests unlocks the daily chest reward

### Weekly Quest Generation

1. **Reset Timing**: New week starts on Sunday (or first app open of the week)
2. **Core Set**: Always include the 5 core weekly quests
3. **Bonus Selection**: Pick 0-1 additional quests from the bonus/habit pool
4. **Progress**: Weekly quests track cumulative progress across all 7 days

### Reroll System

- Players can **reroll 1 daily quest per day**
- Only **incomplete** quests can be rerolled
- Reroll picks a replacement from the same category/tier when possible
- Once reroll is used, it's locked until the next day

---

## Version History

### v1.6.2 (Current)
- Streamlined daily quests to 17 "dopamine hit" quests (10-20 XP)
- Renamed timer categories (added Create, Gaming Reset, Move)
- Gamified quest titles (e.g., "Nerd Time", "First Potion")
- XP rebalancing across the board
- Added new gaming and movement quests
- Expanded weekly quest pool to 15 quests
- Disabled several legacy quests (irl-patch, tidy-spot, step-outside, quick-self-care)

### Pre-v1.6.2
- Original 27+ daily quests with mixed XP values (15-60 XP)
- Basic timer categories (Work, Chores, Self-Care, Chill)
- 6 legacy weekly quests

---

## Implementation Notes

### Quest Status Tracking
- **pending** - Quest is available but not started
- **inProgress** - Quest has partial progress toward completion
- **completed** - Quest is done and XP has been awarded
- **failed** - (Not currently used)

### Completion Modes
- **automatic** - Quest completes automatically when conditions are met
- **manualDebug** - Quest requires manual marking (used for testing/unimplemented features)

### Storage Keys
Quests use UserDefaults with date-based keys for tracking:
- Daily completion: `last-completion-{date-key}`
- Active quests: `daily-active-{date-key}`
- Reroll status: `reroll-{date-key}`
- Quest chest: `quest-chest-granted-{date-key}`

---

**End of Quest Catalog Specification**
