import MapKit
import SwiftUI

struct PlaceDetails: View {
    let place: Place
    let loading: Bool
    let error: String?
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.title).font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                Text([place.category, place.price].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    RatingLabel(place: place)
                    if let status = place.openLabel {
                        Text(status).font(.subheadline.weight(.medium))
                            .foregroundStyle(place.currentOpeningHours?.openNow == true ? .green : .secondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                if place.coordinate != nil {
                    Button {
                        guard let coordinate = place.coordinate else { return }
                        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
                        item.name = place.title
                        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
                    } label: { actionLabel("Directions", symbol: "arrow.turn.up.right") }
                    .buttonStyle(.plain).foregroundStyle(.white)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                }
                if let url = place.websiteUri {
                    Link(destination: url) { actionLabel("Website", symbol: "safari") }
                        .buttonStyle(.plain).background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                }
                if let phone = place.internationalPhoneNumber ?? place.nationalPhoneNumber,
                   let url = URL(string: "tel:" + phone.filter { $0.isNumber || $0 == "+" }) {
                    Link(destination: url) { actionLabel("Call", symbol: "phone.fill") }
                        .buttonStyle(.plain).background(.quaternary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 20)

            if loading {
                HStack { ProgressView(); Text("Loading photos and details…").font(.subheadline).foregroundStyle(.secondary) }
                    .padding(.horizontal, 20).padding(.vertical, 20)
            } else if let error {
                VStack(alignment: .leading, spacing: 10) {
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                    Button("Retry details", action: retry).buttonStyle(.bordered)
                }
                .padding(.horizontal, 20)
            } else if let photos = place.photos, !photos.isEmpty {
                PhotoCarousel(photos: photos)
            } else {
                Label("No photos available for this place", systemImage: "photo")
                    .font(.subheadline).foregroundStyle(.secondary).padding(20)
            }

            VStack(alignment: .leading, spacing: 18) {
                if let address = place.formattedAddress {
                    detail("Address", symbol: "mappin.and.ellipse") { Text(address).textSelection(.enabled) }
                }
                if let hours = place.regularOpeningHours?.weekdayDescriptions, !hours.isEmpty {
                    detail("Opening hours", symbol: "clock") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(hours, id: \.self) { Text($0) }
                        }
                    }
                }
                if let phone = place.nationalPhoneNumber {
                    detail("Phone", symbol: "phone") { Text(phone).textSelection(.enabled) }
                }
                Divider()
                if let url = place.googleMapsUri {
                    Link(destination: url) { Label("View on Google Maps", systemImage: "arrow.up.right.square") }
                        .font(.subheadline.weight(.medium))
                }
                Text("Place information and photos from Google Maps")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
        }
    }

    private func actionLabel(_ text: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title3.weight(.semibold))
            Text(text).font(.caption.weight(.semibold))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 13)
    }

    private func detail<Content: View>(_ title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.weight(.semibold))
                content().font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PhotoCarousel: View {
    let photos: [Place.Photo]
    @State private var selectedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Photos").font(.headline)
                Spacer()
                let index = photos.firstIndex { $0.id == selectedID } ?? 0
                Text("\(index + 1) / \(photos.count)").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(photos) { photo in
                            PlacePhoto(photo: photo)
                                .frame(width: max(geometry.size.width - 48, 200), height: 230)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .id(photo.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $selectedID)
            }
            .frame(height: 230)
        }
    }
}

private struct PlacePhoto: View {
    let photo: Place.Photo
    @State private var data: Data?
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle().fill(.quaternary)
                if let data, let image = platformImage(data) {
                    image.resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .accessibilityLabel("Place photo")
                        .accessibilityIdentifier("loadedPlacePhoto")
                } else if failed {
                    VStack(spacing: 10) {
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                        Button("Retry photo") { attempt += 1 }.buttonStyle(.bordered)
                    }
                } else {
                    ProgressView()
                }
            }
            .overlay(alignment: .bottomLeading) {
                if let authors = photo.authorAttributions, !authors.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(authors.enumerated()), id: \.offset) { _, author in
                            if let name = author.displayName {
                                if let url = author.url {
                                    Link("Photo: \(name)", destination: url)
                                } else {
                                    Text("Photo: \(name)")
                                }
                            }
                        }
                    }
                    .font(.caption2.weight(.medium)).foregroundStyle(.white)
                    .padding(10).background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10)).padding(10)
                }
            }
        }
        .task(id: attempt) {
            failed = false
            do {
                let result = try await PlacesClient.configured().photo(photo.name)
                try Task.checkCancellation()
                guard platformImage(result) != nil else { failed = true; return }
                data = result
            } catch {
                if !Task.isCancelled { failed = true }
            }
        }
    }

    private func platformImage(_ data: Data) -> Image? {
        #if os(iOS)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #else
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #endif
    }
}
