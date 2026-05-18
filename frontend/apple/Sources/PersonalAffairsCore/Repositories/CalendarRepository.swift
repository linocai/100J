import Foundation

public final class CalendarRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func list(
        spaceId: String? = nil,
        projectId: String? = nil,
        type: CalendarItemType? = nil,
        fromDate: String? = nil,
        toDate: String? = nil
    ) async throws -> [CalendarItem] {
        try await api.fetchAll("/calendar-items", query: calendarQuery(
            spaceId: spaceId,
            projectId: projectId,
            type: type,
            fromDate: fromDate,
            toDate: toDate
        ))
    }

    public func page(
        spaceId: String? = nil,
        projectId: String? = nil,
        type: CalendarItemType? = nil,
        fromDate: String? = nil,
        toDate: String? = nil,
        limit: Int = 100,
        cursor: String? = nil
    ) async throws -> PageResponse<CalendarItem> {
        var query = calendarQuery(
            spaceId: spaceId,
            projectId: projectId,
            type: type,
            fromDate: fromDate,
            toDate: toDate
        )
        query.append(URLQueryItem(name: "limit", value: "\(limit)"))
        query.appendIfPresent("cursor", cursor)
        return try await api.send(
            "/calendar-items",
            query: query,
            response: PageResponse<CalendarItem>.self
        )
    }

    private func calendarQuery(
        spaceId: String?,
        projectId: String?,
        type: CalendarItemType?,
        fromDate: String?,
        toDate: String?
    ) -> [URLQueryItem] {
        var query: [URLQueryItem] = []
        query.appendIfPresent("space_id", spaceId)
        query.appendIfPresent("project_id", projectId)
        query.appendIfPresent("type", type?.rawValue)
        query.appendIfPresent("from_date", fromDate)
        query.appendIfPresent("to_date", toDate)
        return query
    }

    public func create(_ request: CalendarItemCreateRequest) async throws -> CalendarItem {
        try await api.send("/calendar-items", method: .post, body: request, response: CalendarItem.self)
    }

    public func update(id: String, request: CalendarItemUpdateRequest) async throws -> CalendarItem {
        try await api.send("/calendar-items/\(id)", method: .patch, body: request, response: CalendarItem.self)
    }

    public func delete(id: String) async throws -> DeleteResponse {
        try await api.send("/calendar-items/\(id)", method: .delete, response: DeleteResponse.self)
    }

    public func merged(personalSpaceId: String, companySpaceId: String, fromDate: String? = nil, toDate: String? = nil) async throws -> [CalendarItem] {
        async let personal = list(spaceId: personalSpaceId, fromDate: fromDate, toDate: toDate)
        async let company = list(spaceId: companySpaceId, fromDate: fromDate, toDate: toDate)
        return try await (personal + company).sorted { lhs, rhs in
            lhs.sortKey < rhs.sortKey
        }
    }
}

private extension CalendarItem {
    var sortKey: String {
        if let startDate { return startDate }
        if let startAt { return ISO8601DateFormatter().string(from: startAt) }
        return title
    }
}
