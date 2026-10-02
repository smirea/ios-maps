import MapKit
import Observation

@Observable @MainActor
final class MapsModel {
    var query = ""
    private(set) var submittedQuery = ""
    private(set) var places: [Place] = []
    private(set) var selectedPlace: Place?
    private(set) var searching = false
    private(set) var loadingDetails = false
    private(set) var searchError: String?
    private(set) var detailError: String?
    private(set) var searchRevision = 0
    private var searchTask: Task<Void, Never>?
    private var detailTask: Task<Void, Never>?
    private var requestID = UUID()

    func search(in region: MKCoordinateRegion) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        searchTask?.cancel()
        closePlace()
        let requestID = UUID()
        self.requestID = requestID
        submittedQuery = query
        places = []
        searchError = nil
        searching = true
        let client = PlacesClient.configured()
        let center = region.center
        let radius = region.span.latitudeDelta * 111_000 / 2
        searchTask = Task {
            do {
                let results = try await client.search(query, latitude: center.latitude, longitude: center.longitude, radius: radius)
                try Task.checkCancellation()
                guard self.requestID == requestID else { return }
                places = results
                searching = false
                searchRevision += 1
            } catch {
                guard !Task.isCancelled, self.requestID == requestID else { return }
                searching = false
                searchError = error.localizedDescription
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        requestID = UUID()
        closePlace()
        query = ""
        submittedQuery = ""
        places = []
        searchError = nil
        searching = false
    }

    func select(_ place: Place) {
        detailTask?.cancel()
        selectedPlace = place
        detailError = nil
        loadingDetails = true
        let client = PlacesClient.configured()
        detailTask = Task {
            do {
                let details = try await client.details(place.id)
                try Task.checkCancellation()
                guard selectedPlace?.id == place.id else { return }
                selectedPlace = details
                loadingDetails = false
            } catch {
                guard !Task.isCancelled, selectedPlace?.id == place.id else { return }
                detailError = error.localizedDescription
                loadingDetails = false
            }
        }
    }

    func closePlace() {
        detailTask?.cancel()
        selectedPlace = nil
        detailError = nil
        loadingDetails = false
    }
}
