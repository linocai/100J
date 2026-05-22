import Foundation

func viewModelError(from error: Error) -> APIClientError {
    if let apiError = error as? APIClientError {
        return apiError
    }
    return .transport(error.localizedDescription)
}

public func defaultCalendarWindow(now: Date = Date(), calendar: Calendar = .current) -> (fromDate: String, toDate: String) {
    let today = calendar.startOfDay(for: now)
    let from = calendar.date(byAdding: .day, value: -30, to: today) ?? today
    let to = calendar.date(byAdding: .day, value: 180, to: today) ?? today
    return (CalendarViewState.dayKey(from), CalendarViewState.dayKey(to))
}
