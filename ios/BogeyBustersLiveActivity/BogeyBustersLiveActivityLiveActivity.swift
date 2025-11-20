//
//  BogeyBustersLiveActivityLiveActivity.swift
//  BogeyBustersLiveActivity
//
//  Created by Ryan Stoffel on 11/20/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct BogeyBustersLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct BogeyBustersLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BogeyBustersLiveActivityAttributes.self) { context in
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

extension BogeyBustersLiveActivityAttributes {
    fileprivate static var preview: BogeyBustersLiveActivityAttributes {
        BogeyBustersLiveActivityAttributes(name: "World")
    }
}

extension BogeyBustersLiveActivityAttributes.ContentState {
    fileprivate static var smiley: BogeyBustersLiveActivityAttributes.ContentState {
        BogeyBustersLiveActivityAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: BogeyBustersLiveActivityAttributes.ContentState {
         BogeyBustersLiveActivityAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: BogeyBustersLiveActivityAttributes.preview) {
   BogeyBustersLiveActivityLiveActivity()
} contentStates: {
    BogeyBustersLiveActivityAttributes.ContentState.smiley
    BogeyBustersLiveActivityAttributes.ContentState.starEyes
}
