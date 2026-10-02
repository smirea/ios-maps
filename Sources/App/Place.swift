import CoreLocation
import Foundation

struct Place: Decodable, Identifiable, Sendable {
    struct DisplayName: Decodable, Sendable {
        let text: String
    }

    struct Location: Decodable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    struct OpeningHours: Decodable, Sendable {
        let openNow: Bool?
        let weekdayDescriptions: [String]?
    }

    struct Photo: Decodable, Identifiable, Sendable {
        struct Author: Decodable, Sendable {
            let displayName: String?
            let uri: String?

            var url: URL? {
                guard let uri else { return nil }
                return URL(string: uri.hasPrefix("//") ? "https:" + uri : uri)
            }
        }

        let name: String
        let authorAttributions: [Author]?
        var id: String { name }
    }

    let id: String
    let displayName: DisplayName?
    let formattedAddress: String?
    let location: Location?
    let rating: Double?
    let userRatingCount: Int?
    let priceLevel: String?
    let primaryType: String?
    let businessStatus: String?
    let googleMapsUri: URL?
    let websiteUri: URL?
    let nationalPhoneNumber: String?
    let internationalPhoneNumber: String?
    let currentOpeningHours: OpeningHours?
    let regularOpeningHours: OpeningHours?
    let photos: [Photo]?

    var title: String { displayName?.text ?? "Unnamed place" }
    var category: String { (primaryType ?? "place").replacingOccurrences(of: "_", with: " ").capitalized }

    var coordinate: CLLocationCoordinate2D? {
        guard let location, CLLocationCoordinate2DIsValid(.init(latitude: location.latitude, longitude: location.longitude)) else { return nil }
        return .init(latitude: location.latitude, longitude: location.longitude)
    }

    var price: String? {
        switch priceLevel {
        case "PRICE_LEVEL_FREE": "Free"
        case "PRICE_LEVEL_INEXPENSIVE": "$"
        case "PRICE_LEVEL_MODERATE": "$$"
        case "PRICE_LEVEL_EXPENSIVE": "$$$"
        case "PRICE_LEVEL_VERY_EXPENSIVE": "$$$$"
        default: nil
        }
    }

    var openLabel: String? {
        if businessStatus == "CLOSED_PERMANENTLY" { return "Permanently closed" }
        if businessStatus == "CLOSED_TEMPORARILY" { return "Temporarily closed" }
        guard let open = currentOpeningHours?.openNow else { return nil }
        return open ? "Open now" : "Closed now"
    }

    var symbol: String {
        let type = primaryType ?? ""
        if type.contains("cafe") || type.contains("coffee") { return "cup.and.saucer.fill" }
        if type.contains("restaurant") || type.contains("food") || type.contains("bakery") { return "fork.knife" }
        if type.contains("park") || type.contains("hiking") { return "leaf.fill" }
        if type.contains("lodging") || type.contains("hotel") { return "bed.double.fill" }
        if type.contains("store") || type.contains("shopping") { return "bag.fill" }
        return "mappin"
    }
}
