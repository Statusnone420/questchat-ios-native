import WidgetKit
import SwiftUI

@main
struct QuestChatLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        if #available(iOS 17.0, *) {
            FocusSessionLiveActivityWidget()
        }
    }
}
