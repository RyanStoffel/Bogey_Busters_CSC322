import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes
// CRITICAL: Must be named EXACTLY "LiveActivitiesAppAttributes" for the plugin to work
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState // Required by live_activities plugin
    
    public struct ContentState: Codable, Hashable {
        var holeNumber: Int
        var distanceToGreen: Int
        var relativeToPar: Int
        var courseName: String
    }
    
    var id = UUID()
}

// MARK: - Live Activity Widget
struct BogeyBustersLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // Lock screen view
            VStack(spacing: 0) {
                // Header with course name
                HStack {
                    Image(systemName: "figure.golf")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text(context.state.courseName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                // Main content - horizontal layout
                HStack(alignment: .center, spacing: 0) {
                    // Left - Hole
                    VStack(spacing: 4) {
                        Text("HOLE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text("\(context.state.holeNumber)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 50)
                        .background(Color.white.opacity(0.3))
                    
                    // Center - Distance
                    VStack(spacing: 2) {
                        Text("\(context.state.distanceToGreen)")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        Text("YARDS")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .frame(height: 50)
                        .background(Color.white.opacity(0.3))
                    
                    // Right - Score
                    VStack(spacing: 4) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Text(formatScore(context.state.relativeToPar))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(getScoreColor(context.state.relativeToPar))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.5, blue: 0.25),
                        Color(red: 0.2, green: 0.55, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("HOLE")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(context.state.holeNumber)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("SCORE")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formatScore(context.state.relativeToPar))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(getScoreColor(context.state.relativeToPar))
                    }
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 4) {
                        Text("\(context.state.distanceToGreen)")
                            .font(.system(size: 28, weight: .bold))
                        Text("YARDS")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.courseName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
            } compactLeading: {
                Text("⛳\(context.state.holeNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                
            } compactTrailing: {
                Text("\(context.state.distanceToGreen)")
                    .font(.caption)
                    .fontWeight(.semibold)
                
            } minimal: {
                Image(systemName: "flag.fill")
                    .foregroundColor(.green)
            }
        }
    }
}

// MARK: - Helper Functions
func formatScore(_ score: Int) -> String {
    if score == 0 {
        return "E"
    } else if score > 0 {
        return "+\(score)"
    } else {
        return "\(score)"
    }
}

func getScoreColor(_ score: Int) -> Color {
    if score > 0 {
        return Color(red: 1.0, green: 0.3, blue: 0.3)  // Red (over par)
    } else if score < 0 {
        return Color(red: 0.3, green: 1.0, blue: 0.3)  // Green (under par)
    } else {
        return Color.white  // White (even par)
    }
}

// MARK: - Previews
#Preview("Lock Screen", as: .content, using: LiveActivitiesAppAttributes()) {
    BogeyBustersLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState(
        holeNumber: 7,
        distanceToGreen: 145,
        relativeToPar: -2,
        courseName: "Pebble Beach Golf Links"
    )
    LiveActivitiesAppAttributes.ContentState(
        holeNumber: 18,
        distanceToGreen: 523,
        relativeToPar: 3,
        courseName: "Augusta National"
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: LiveActivitiesAppAttributes()) {
    BogeyBustersLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState(
        holeNumber: 12,
        distanceToGreen: 203,
        relativeToPar: 0,
        courseName: "St Andrews Links"
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: LiveActivitiesAppAttributes()) {
    BogeyBustersLiveActivity()
} contentStates: {
    LiveActivitiesAppAttributes.ContentState(
        holeNumber: 15,
        distanceToGreen: 98,
        relativeToPar: -1,
        courseName: "Torrey Pines"
    )
}
