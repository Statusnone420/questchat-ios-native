import Foundation

enum QuestChatStrings {
    enum TimerCategories {
        static let deepFocusTitle = "Deep focus"
        static let deepFocusSubtitle = "Heads-down work, no scrolling."

        static let workSprintTitle = "Work sprint"
        static let workSprintSubtitle = "Ship stuff fast, no perfectionism."

        static let choresTitle = "Chores sprint"
        static let choresSubtitle = "Put the room back on your side."

        static let choresSprintTitle = "Chores sprint"
        static let choresSprintSubtitle = "Put the room back on your side."

        static let selfCareTitle = "Self-care reset"
        static let selfCareSubtitle = "Move, breathe, hydrate, unclench."

        static let gamingResetTitle = "Gaming reset"
        static let gamingResetSubtitle = "Queue break. Stretch and sip."

        static let quickBreakTitle = "Quick break"
        static let quickBreakSubtitle = "Step away so your brain comes back sharper."
    }

    enum FocusTimerModeTitles {
        static let focus = "Deep Focus"
        static let selfCare = "Self Care"
    }

    enum FocusAreaTitles {
        static let work = "Work"
        static let home = "Home"
        static let health = "Health"
        static let chill = "Chill"
    }

    enum PlayerTitles {
        static let rookie = "Focus Rookie"
        static let worker = "Deep Worker"
        static let knight = "Quest Knight"
        static let master = "Flow Master"
        static let sage = "Time Sage"
    }

    enum StatusLines {
        static func streak(_ days: Int) -> String {
            "On a \(days)-day streak. Keep it going!"
        }

        static func xpEarned(_ xp: Int) -> String {
            "\(xp) XP earned so far."
        }
    }

    enum HydrationNudges {
        static let streak = "Nice streak! Grab water and reset your posture."
        static let hour = "Hydrate and stretch—your focus streak is over an hour!"
        static let long = "Amazing focus. Take a hydration + posture break before continuing."
    }

    enum Notifications {
        static let timerCompleteTitle = "Timer complete"
        static let timerCompleteBody = "Hydrate and check your posture. Your session just wrapped up!"

        static let hydrateReminderTitle = "Hydration break"
        static let hydrateReminderBody = "Grab something that isn’t just caffeine or vibes."

        static let hydrateNudgeTitle = "Hydrate + posture check"
    }

    enum FocusView {
        static let navigationTitle = "Focus"

        static let sessionCompleteAccessory = "Session complete. Next..."
        static let focusAccessory = "Focus minutes turn into XP. For life too."
        static let selfCareAccessory = "Stretch, hydrate, reset."

        static func questProgress(completed: Int, total: Int) -> String {
            "\(completed) / \(total) quests done"
        }

        static func minutesProgress(totalMinutes: Int, targetMinutes: Int) -> String {
            "\(totalMinutes) / \(targetMinutes) min"
        }

        static func streakProgress(days: Int) -> String {
            days > 0 ? "\(days)-day streak" : "Start your streak"
        }

        static let headerQuestsTitle = "Quests"
        static let headerTodayTitle = "Today"
        static let headerStreakTitle = "Streak"

        static let todayQuestLabel = "Today's Quest"
        static let questCompletedLabel = "Completed"

        static let quickTimersTitle = "Quick timers"

        static let cancelButtonTitle = "Cancel"
        static let doneButtonTitle = "Done"
        static let durationPickerTitle = "Duration"

        static let resumeButtonTitle = "Resume"
        static let startButtonTitle = "Start"
        static let pauseButtonTitle = "Pause"
        static let resetButtonTitle = "Reset"

        static let sessionsLabel = "Sessions"
        static let hydratePostureLabel = "Hydrate + Posture"
        static let hydratePostureOn = "On"
        static let hydratePostureOff = "Off"

        static let reminderTitle = "Hydrate + posture when the timer ends"
        static let reminderSubtitle = "Reminders stay on this device for now. Your body still gets the buff."
        static let reminderTip = "Tip: keep the display black to save battery on OLED. Your streak and XP stay stored on device even if you close the app."

        static let hydrationBannerTitle = "Hydrate + posture check"

        static let comboComplete = "Combo complete today!"
        static let comboProgressPrefix = "Combo:"

        static let levelUpTitlePrefix = "Level "
        static let levelUpSubtitle = "Keep the momentum going! Your focus streak just leveled up."
        static let levelUpButtonTitle = "Nice!"

        static let sessionCompleteTitle = "Session complete"
        static let sessionCompleteButtonTitle = "Nice, back to it"

        static let dailySetupTitle = "Daily setup"
        static let dailySetupDescription = "Pick where to focus and your energy. We'll set a realistic minute goal for today."
        static let focusAreaLabel = "Focus area"
        static let energyLevelLabel = "Energy level"
        static let saveTodayButtonTitle = "Save today"
    }

    enum StatsView {
        static let navigationTitle = "Stats"
        static let headerTitle = "Experience"
        static let headerSubtitle = "Everything is stored locally until Supabase sync lands."
        static let levelLabel = "Level"
        static func levelProgress(current: Int, total: Int) -> String {
            "\(current) / \(total) XP into this level"
        }

        static let momentumLabel = "Momentum"
        static let momentumReady = "Momentum: ready!"
        static let momentumAlmost = "Momentum: almost there"
        static let momentumCharging = "Momentum: charging"
        static let momentumStart = "Momentum: start a session"

        static let summaryXPTileTitle = "XP"
        static let summarySessionsTileTitle = "Sessions"
        static let streakTitle = "Streak"
        static let streakSubtitle = "Consecutive days with at least one session."

        static let minutesTitle = "Minutes"
        static let focusMinutesLabel = "Focus"
        static let selfCareMinutesLabel = "Self care"

        static let sessionHistoryTitle = "Session History"
        static let sessionHistoryEmpty = "No sessions yet."

        static let weeklyPathTitle = "Weekly path"
        static let weeklyStreakBonus = "Weekly streak! +120 XP bonus unlocked"

        static let todaysFocusGoal = "Today's focus goal"

        static func dailyGoalProgress(current: Int, total: Int) -> String {
            "\(current) / \(total) minutes"
        }

        static let weeklyGoalMet = "Goal met"
        static let weeklyGoalNotMet = "Goal not met"
    }

    enum StreakHeader {
        static let questsTitle = "Quests"
        static let todayTitle = "Today"
        static let streakTitle = "Streak"
    }

    enum QuestsView {
        static let headerTitle = "Daily quests"
        static let headerSubtitleSuffix = "complete"
        static let questChestReady = "Quest Chest ready – tap to claim bonus XP"
        static let chestProgressPrefix = "Complete"
        static let chestClaimed = "Quest Chest claimed for today"

        static let rerollDialogTitle = "Reroll a quest"
        static let rerollDialogEmpty = "No incomplete quests"
        static let rerollCancel = "Cancel"

        static let questChestClearedTitle = "Daily quests cleared!"
        static let questChestClearedBodyPrefix = "You unlocked a Quest Chest for"
        static let claimRewardButton = "Claim reward"

        static let rerollFooterDescription = "You can reroll one incomplete quest per day."
        static let rerollButtonTitle = "Reroll a quest"
        static let rerollUsed = "Reroll used for today"

        static let headerTotalXPLabel = "XP total"
        static let rerollActionTitle = "Reroll"

        static func headerSubtitle(completed: Int, total: Int, totalXP: Int) -> String {
            "\(completed) / \(total) \(headerSubtitleSuffix) • \(totalXP) \(headerTotalXPLabel)"
        }

        static func chestProgress(_ remaining: Int) -> String {
            "\(chestProgressPrefix) \(remaining) more quests to unlock the chest"
        }

        static func questChestClearedBody(reward: Int) -> String {
            "\(questChestClearedBodyPrefix) +\(reward) XP. Keep the streak alive!"
        }
    }

    enum QuestsPool {
        static let dailyCheckInTitle = "Load today’s quest log"
        static let dailyCheckInDescription = "Take 30 seconds to decide what actually matters."

        static let hydrateTitle = "Hydrate checkpoint"
        static let hydrateDescription = "Drink a real glass of water before you start."

        static let stretchTitle = "IRL patch update"
        static let stretchDescription = "Stretch for 2 minutes and un-gremlin your spine."

        static let planTitle = "Plan one focus session"
        static let planDescription = "Pick a timer and commit to at least one run today."

        static let deepFocusTitle = "Deep focus"
        static let deepFocusDescription = "Commit to 25 distraction-free minutes."

        static let gratitudeTitle = "Gratitude note"
        static let gratitudeDescription = "Write down one thing you're grateful for."

        static let coreTier = "Core"
        static let habitTier = "Habit"
        static let bonusTier = "Bonus"
    }

    enum QuestsCopy {
        static let questDailyCheckInTitle = "Load today’s quest log"
        static let questDailyCheckInSubtitle = "Take 30 seconds to decide what actually matters."

        static let questHydrateTitle = "Hydrate checkpoint"
        static let questHydrateSubtitle = "Drink a real glass of water before you start."

        static let questStretchTitle = "IRL patch update"
        static let questStretchSubtitle = "Stretch for 2 minutes and un-gremlin your spine."

        static let questPlanFocusTitle = "Plan one focus session"
        static let questPlanFocusSubtitle = "Pick a timer and commit to at least one run today."
    }

    enum TodayAndStreak {
        static let todayTitle = "Today"
        static let todayEmptySubtitle = "No runs yet. Tap a timer to start your day’s story."
        static let todaySummaryFormat = "Quests: %d / %d • Focus: %d / %d min"
        static let todayMinutesSummaryFormat = "%d minutes of actual brain time today."

        static let streakTitle = "Streak"
        static let streakSingleDaySubtitle = "1 day in a row. Tiny streak, still counts."
        static let streakMultiDaySubtitleFormat = "%d-day streak. Don’t let today be the villain."
        static let streakBrokenSubtitleFormat = "Last streak: %d days. That’s still lore. Start a new arc."
    }

    enum HydratePosture {
        static let hydrateGoalFormat = "Goal: %d glasses today."
        static let hydrateProgressFormat = "%d / %d hydration checkpoints cleared."

        static let postureReminderTitle = "Posture check"
        static let postureReminderBody = "Unclench your jaw, drop your shoulders, one slow breath."
        static let postureGoalFormat = "Goal: %d posture checks today."
        static let postureProgressFormat = "%d posture checks logged. Spine approves."
        static let postureSnoozeHint = "Can’t move right now? Snooze it and come back to un-pretzel later."

        static let hydrateReminderTitle = "Hydration break"
        static let hydrateReminderBody = "Grab something that isn’t just caffeine or vibes."
        static let hydratePostureInfoTitle = "Hydrate + posture when the timer ends"
        static let hydratePostureInfoBody = "Reminders stay on this device for now. Your body still gets the buff."
    }

    enum PlayerCardCopy {
        static let playerCardTitle = "Player card"
        static let playerCardSubtitle = "Your little self-care stat sheet."
        static let playerDefaultName = "Player One"
        static let playerDefaultTitle = "Adventurer in progress"
        static let playerLevelFormat = "Level %d"
        static let playerXpToNextFormat = "%d XP to next level"
        static let playerBadgesTitle = "Badges"
        static let playerBadgesEmptySubtitle = "No badges yet. Quests, streaks, and focus runs will change that."
        static let playerTitlesSectionTitle = "Title"
        static let playerTitleHelper = "Pick one title to flex in stats and, later, in chat."
        static let playerTitleEmpty = "No title equipped. Running nameless like a side character."
        static let playerStatsSummaryFormat = "%d quests done • %d focus runs • %d days played"
        static let playerEditHint = "Nickname, avatar, titles — this is where you dial in main-character energy."
    }

    enum MoreView {
        static let moreComing = "More coming soon"
        static let timerDurationsTitle = "Timer durations"
        static let timerDurationsDescription = "Adjust each category directly from the Focus tab."
        static let hydrationToggleTitle = "Hydrate + posture nudges"
        static let hydrationToggleDescription = "In-app banners and local notifications when you cross focus milestones."
        static let visitSite = "Visit questchat.app"
    }

    enum PlayerCard {
        static let defaultName = "Player One"
        static let namePlaceholder = "Player name"
        static let levelLabel = "Level"
        static let totalXPLabel = "Total XP"
        static let streakLabel = "Current streak"
    }

    static func xpRewardText(_ amount: Int) -> String {
        "+\(amount) XP"
    }
}
