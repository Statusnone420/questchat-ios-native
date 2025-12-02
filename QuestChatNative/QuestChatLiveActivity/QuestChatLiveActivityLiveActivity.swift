//
//  QuestChatLiveActivityLiveActivity.swift
//  QuestChatLiveActivity
//
//  Created by Anthony Gagliardo on 12/2/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct QuestChatLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct QuestChatLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuestChatLiveActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension QuestChatLiveActivityAttributes {
    fileprivate static var preview: QuestChatLiveActivityAttributes {
        QuestChatLiveActivityAttributes(name: "World")
    }
}

extension QuestChatLiveActivityAttributes.ContentState {
    fileprivate static var smiley: QuestChatLiveActivityAttributes.ContentState {
        QuestChatLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: QuestChatLiveActivityAttributes.ContentState {
         QuestChatLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: QuestChatLiveActivityAttributes.preview) {
   QuestChatLiveActivityLiveActivity()
} contentStates: {
    QuestChatLiveActivityAttributes.ContentState.smiley
    QuestChatLiveActivityAttributes.ContentState.starEyes
}
