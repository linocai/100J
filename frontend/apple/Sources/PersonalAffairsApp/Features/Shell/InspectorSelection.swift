import Foundation

enum InspectorSelection: Equatable {
    case task(String)
    case calendarItem(String)
    case note(String)
    case project(String)
    case agentLog(String)
}
