import MapKit
import SwiftUI

struct MapScreen: View {
    private static let fallback = MKCoordinateRegion(
        center: .init(latitude: 39.5, longitude: -98.35),
        span: .init(latitudeDelta: 35, longitudeDelta: 55)
    )

    @State private var model = MapsModel()
    @State private var location = LocationManager()
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(fallback))
    @State private var visibleRegion = fallback
    @State private var satellite = false
    @State private var panelPresented = false
    @State private var detent: PresentationDetent = .height(180)
    @State private var selectedPin: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        map
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) { mapControls.padding(.top, 60).padding(.trailing, 16) }
        #if os(iOS)
        .sheet(isPresented: $panelPresented) {
            panel
                .presentationDetents([.height(180), .medium, .large], selection: $detent)
                .presentationDragIndicator(.visible)
                .presentationBackground(.regularMaterial)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(28)
                .interactiveDismissDisabled()
        }
        #else
        .overlay(alignment: .bottomLeading) {
            panel
                .frame(width: 380, height: 460)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.12), radius: 20, y: 5)
                .padding(20)
        }
        #endif
        .task {
            location.start()
            panelPresented = true
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { location.start() } else { location.stop() }
        }
        .onChange(of: model.searchRevision) { _, _ in fitResults() }
    }

    private var map: some View {
        Map(position: $position, selection: $selectedPin) {
            UserAnnotation()
            ForEach(model.places) { place in
                if let coordinate = place.coordinate {
                    if let rating = place.rating {
                        Marker(place.title, monogram: Text(String(format: "%.1f", rating)), coordinate: coordinate)
                            .tint(model.selectedPlace?.id == place.id ? .blue : .orange)
                            .tag(place.id)
                    } else {
                        Marker(place.title, systemImage: place.symbol, coordinate: coordinate)
                            .tint(model.selectedPlace?.id == place.id ? .blue : .orange)
                            .tag(place.id)
                    }
                }
            }
        }
        .mapStyle(satellite ? .imagery(elevation: .realistic) : .standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControlVisibility(.hidden)
        .onMapCameraChange(frequency: .onEnd) { context in visibleRegion = context.region }
        .onChange(of: selectedPin) { _, id in
            guard let place = model.places.first(where: { $0.id == id }), model.selectedPlace?.id != id else { return }
            select(place)
        }
        .onChange(of: model.selectedPlace?.id) { _, id in selectedPin = id }
    }

    private var panel: some View {
        SearchPanel(model: model, location: location, detent: $detent, region: visibleRegion, onSelect: select)
    }

    private var mapControls: some View {
        VStack(spacing: 0) {
            Button {
                location.start()
                withAnimation { position = .userLocation(followsHeading: false, fallback: .region(visibleRegion)) }
            } label: {
                Image(systemName: "location.fill").frame(width: 48, height: 48)
            }
            .accessibilityLabel("Show my location")
            Divider().frame(width: 30)
            Button { satellite.toggle() } label: {
                Image(systemName: satellite ? "map" : "globe.americas.fill").frame(width: 48, height: 48)
            }
            .accessibilityLabel(satellite ? "Standard map" : "Satellite map")
        }
        .font(.system(size: 20, weight: .medium))
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 3)
    }

    private func select(_ place: Place) {
        model.select(place)
        detent = .medium
        guard let coordinate = place.coordinate else { return }
        withAnimation(.easeInOut(duration: 0.4)) {
            position = .region(.init(
                center: .init(latitude: coordinate.latitude - 0.003, longitude: coordinate.longitude),
                span: .init(latitudeDelta: 0.014, longitudeDelta: 0.014)
            ))
        }
    }

    private func fitResults() {
        let points = model.places.compactMap(\.coordinate).map { MKMapPoint($0) }
        guard let first = points.first else { return }
        var rect = MKMapRect(origin: first, size: .init(width: 0, height: 0))
        for point in points { rect = rect.union(.init(origin: point, size: .init(width: 0, height: 0))) }
        let minimum = MKMapPointsPerMeterAtLatitude(first.coordinate.latitude) * 1500
        let width = max(rect.width * 1.4, minimum)
        let height = max(rect.height * 2.4, minimum * 2)
        rect = .init(x: rect.midX - width / 2, y: rect.midY - height * 0.35, width: width, height: height)
        withAnimation(.easeInOut(duration: 0.5)) { position = .rect(rect) }
    }
}

private struct SearchPanel: View {
    @Bindable var model: MapsModel
    let location: LocationManager
    @Binding var detent: PresentationDetent
    let region: MKCoordinateRegion
    let onSelect: (Place) -> Void
    @State private var settingsPresented = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let place = model.selectedPlace {
                HStack {
                    Text("Place details").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        model.closePlace()
                        detent = .medium
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                            .frame(width: 30, height: 30).background(.quaternary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close place details")
                }
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 10)
                ScrollView {
                    PlaceDetails(place: place, loading: model.loadingDetails, error: model.detailError) {
                        model.select(place)
                    }
                    .padding(.bottom, 30)
                }
                .id(place.id)
            } else {
                searchHeader
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let message = location.message {
                            Label(message, systemImage: "location.slash").font(.footnote).foregroundStyle(.secondary)
                            #if os(iOS)
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                Link("Location settings", destination: url).font(.footnote.weight(.semibold))
                            }
                            #endif
                        }
                        if model.searching {
                            HStack(spacing: 12) { ProgressView(); Text("Searching for \(model.submittedQuery)…") }
                                .font(.subheadline).padding(.vertical, 16)
                        } else if let error = model.searchError {
                            ContentUnavailableView {
                                Label("Search unavailable", systemImage: "network.slash")
                            } description: { Text(error) } actions: {
                                Button("Try again") { submit() }.buttonStyle(.borderedProminent)
                                Button("Search Connection") { settingsPresented = true }
                            }
                        } else if !model.submittedQuery.isEmpty {
                            HStack {
                                Text(model.submittedQuery).font(.title2.bold())
                                Spacer()
                                Text("\(model.places.count) places").font(.subheadline).foregroundStyle(.secondary)
                            }
                            if model.places.isEmpty {
                                ContentUnavailableView.search(text: model.submittedQuery)
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(model.places) { place in
                                        Button { onSelect(place) } label: { PlaceRow(place: place) }
                                            .buttonStyle(.plain)
                                        Divider().padding(.leading, 48)
                                    }
                                }
                                Text("Place information from Google Maps").font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Explore your surroundings").font(.title2.bold())
                            Text("Find a favorite spot or somewhere new. Search near the area you’re looking at.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Label("Your map. Your way.", systemImage: "map.fill")
                                .font(.footnote.weight(.medium)).foregroundStyle(.blue).padding(.top, 10)
                        }
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .sheet(isPresented: $settingsPresented) { BridgeSettings() }
        .onChange(of: searchFocused) { _, focused in if focused { detent = .large } }
    }

    private var searchHeader: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search places", text: $model.query)
                        .textFieldStyle(.plain)
                        .font(.body)
                        .submitLabel(.search)
                        .focused($searchFocused)
                        .onSubmit(submit)
                        .accessibilityIdentifier("placeSearch")
                        #if os(iOS)
                        .autocorrectionDisabled()
                        #endif
                    if !model.query.isEmpty {
                        Button { model.clear() } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }
                .padding(13)
                .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                Button { settingsPresented = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 34, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("Search Connection")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    category("Coffee", symbol: "cup.and.saucer.fill")
                    category("Restaurants", symbol: "fork.knife")
                    category("Parks", symbol: "leaf.fill")
                    category("Groceries", symbol: "basket.fill")
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 12)
    }

    private func category(_ title: String, symbol: String) -> some View {
        Button {
            model.query = title
            submit()
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(.background.opacity(0.7), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searchFocused = false
        detent = .medium
        model.search(in: region)
    }
}

private struct PlaceRow: View {
    let place: Place
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: place.symbol)
                .foregroundStyle(.orange).frame(width: 36, height: 36)
                .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 5) {
                Text(place.title).font(.headline).foregroundStyle(.primary)
                Text([place.category, place.price].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    RatingLabel(place: place)
                    if let status = place.openLabel {
                        Text(status).font(.caption)
                            .foregroundStyle(place.currentOpeningHours?.openNow == true ? .green : .secondary)
                    }
                }
                if let address = place.formattedAddress {
                    Text(address).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14).contentShape(Rectangle())
    }
}

struct RatingLabel: View {
    let place: Place
    var body: some View {
        HStack(spacing: 4) {
            if let rating = place.rating {
                Image(systemName: "star.fill").foregroundStyle(.orange)
                Text(String(format: "%.1f", rating)).fontWeight(.semibold)
                if let count = place.userRatingCount { Text("(\(count.formatted()))").foregroundStyle(.secondary) }
            } else {
                Text("No ratings yet").foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }
}
