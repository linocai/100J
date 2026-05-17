import Foundation

public final class SpaceRepository {
    private let api: APIClient

    public init(api: APIClient) {
        self.api = api
    }

    public func list() async throws -> [Space] {
        let response: PageResponse<Space> = try await api.send("/spaces", response: PageResponse<Space>.self)
        return response.items
    }
}

