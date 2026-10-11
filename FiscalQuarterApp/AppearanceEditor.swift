import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Background, type, colors, and what is shown, for the app and every widget at once.
/// Shared by the Mac panel and the iOS app.
struct AppearanceEditor: View {
    @ObservedObject var calendar: CalendarModel
    let today: CalendarDate

    @State private var photo: PhotosPickerItem?
    @State private var importingFile = false
    @State private var problem: String?
    /// The background tab on screen. It can be Photo before any picture is chosen.
    @State private var tab: BackgroundKind?

    private var look: Appearance { calendar.appearance }

    var body: some View {
        Form {
            Section {
                preview
            }

            Section("Background") {
                Picker("Background", selection: kind) {
                    ForEach(BackgroundKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                backgroundControls
                if let problem {
                    Text(problem)
                        .font(.footnote)
                        .foregroundStyle(Theme.warning)
                }
            }

            Section("Text") {
                Picker("Typeface", selection: binding(\.typeface)) {
                    ForEach(Appearance.Typeface.allCases) { face in
                        Text(face.title)
                            .font(Theme(appearance: Appearance(typeface: face)).font(13))
                            .tag(face)
                    }
                }
                Picker("Number weight", selection: binding(\.numberWeight)) {
                    ForEach(Appearance.Weight.allCases) { weight in
                        Text(weight.title).tag(weight)
                    }
                }
                // A segmented picker hides its own label in a form, so each gets one above it.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Size")
                    Picker("Size", selection: binding(\.textSize)) {
                        ForEach(Appearance.TextSize.allCases) { size in
                            Text(size.title).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Text color")
                    Picker("Text color", selection: binding(\.foreground)) {
                        ForEach(Appearance.Foreground.allCases) { foreground in
                            Text(foreground.title).tag(foreground)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                HStack {
                    ColorPicker("Accent", selection: accent, supportsOpacity: false)
                    if look.accent != nil {
                        Button("Reset") { update { $0.accent = nil } }
                    }
                }
            }

            Section("Show") {
                Toggle("Progress bars", isOn: binding(\.display.progressBars))
                Toggle("End date", isOn: binding(\.display.endDate))
                Toggle("Quarter under a label", isOn: binding(\.display.subtitle))
                Toggle("Half and year in medium widgets", isOn: binding(\.display.otherPeriods))
                Toggle("Center the number", isOn: binding(\.display.centered))
            }

            Section {
                Button("Reset to the standard look", role: .destructive) {
                    calendar.setAppearance(.standard)
                    tab = nil
                    problem = nil
                }
                .disabled(look == .standard)
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $importingFile, allowedContentTypes: [.image]) { result in
            switch result {
            case .success(let url):
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                useImage((try? Data(contentsOf: url)) ?? Data())
            case .failure(let error):
                problem = error.localizedDescription
            }
        }
        .onChange(of: photo) { item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    useImage(data ?? Data())
                    photo = nil
                }
            }
        }
    }

    // MARK: Preview

    /// Both widget sizes, drawn the way the widgets will be, so every change shows at once.
    private var preview: some View {
        let entry = CountdownEntry(
            date: Date(),
            snapshot: QuarterSnapshot(on: today, config: calendar.config),
            target: .quarter,
            unit: .days,
            label: nil,
            appearance: look,
            backgroundImage: calendar.backgroundImage
        )
        return AppearancePreview(entry: entry)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Widget preview")
    }

    // MARK: Background

    private var currentTab: BackgroundKind {
        tab ?? BackgroundKind(look.background)
    }

    @ViewBuilder
    private var backgroundControls: some View {
        switch currentTab {
        case .system:
            Text("The system's own background, light or dark to match.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .color:
            ColorPicker("Color", selection: solidColor, supportsOpacity: false)
        case .gradient:
            let gradient: GradientSpec = {
                if case .gradient(let current) = look.background { return current }
                return GradientSpec.presets[1].gradient
            }()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(GradientSpec.presets, id: \.name) { preset in
                        Button {
                            update { $0.background = .gradient(GradientSpec(colors: preset.gradient.colors, angle: gradient.angle)) }
                        } label: {
                            Circle()
                                .fill(LinearGradient(colors: preset.gradient.colors.map(Color.init), startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.15)))
                        }
                        .buttonStyle(.plain)
                        .help(preset.name)
                        .accessibilityLabel(preset.name)
                    }
                }
                .padding(.vertical, 2)
            }
            ColorPicker("Start", selection: gradientColor(0), supportsOpacity: false)
            ColorPicker("End", selection: gradientColor(1), supportsOpacity: false)
            Picker("Direction", selection: gradientAngle) {
                Text("Top to bottom").tag(0.0)
                Text("Diagonal").tag(45.0)
                Text("Left to right").tag(90.0)
                Text("Rising").tag(135.0)
            }
        case .image:
            if look.imageFile == nil {
                Text("Choose a picture. It is copied into the app and scaled to widget size.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            PhotosPicker(selection: $photo, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
            }
            Button {
                importingFile = true
            } label: {
                Label("Choose an image file", systemImage: "folder")
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Darken")
                Slider(value: binding(\.scrim), in: 0...0.7)
            }
        }
    }

    private func useImage(_ data: Data) {
        do {
            let name = try BackgroundImageStore.importImage(data)
            update { $0.background = .image(name) }
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
    }

    // MARK: Bindings

    private func update(_ change: (inout Appearance) -> Void) {
        var next = look
        change(&next)
        calendar.setAppearance(next)
    }

    private func binding<Value>(_ path: WritableKeyPath<Appearance, Value>) -> Binding<Value> {
        Binding(get: { look[keyPath: path] }, set: { value in update { $0[keyPath: path] = value } })
    }

    /// Switching to System, Color, or Gradient applies at once. Photo keeps the current
    /// background until a picture is chosen.
    private var kind: Binding<BackgroundKind> {
        Binding(
            get: { currentTab },
            set: { kind in
                tab = kind
                problem = nil
                guard kind != BackgroundKind(look.background) else { return }
                switch kind {
                case .system: update { $0.background = .system }
                case .color: update { $0.background = .color(RGBAColor(hex: "#1F3A5F")!) }
                case .gradient: update { $0.background = .gradient(GradientSpec.presets[1].gradient) }
                case .image: break
                }
            }
        )
    }

    private var solidColor: Binding<Color> {
        Binding(
            get: { if case .color(let color) = look.background { return Color(color) } else { return .blue } },
            set: { color in if let rgba = RGBAColor(color) { update { $0.background = .color(rgba) } } }
        )
    }

    private func gradientColor(_ index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard case .gradient(let gradient) = look.background, gradient.colors.indices.contains(index) else { return .blue }
                return Color(gradient.colors[index])
            },
            set: { color in
                guard let rgba = RGBAColor(color) else { return }
                update { appearance in
                    guard case .gradient(var gradient) = appearance.background, gradient.colors.indices.contains(index) else { return }
                    gradient.colors[index] = rgba
                    appearance.background = .gradient(gradient)
                }
            }
        )
    }

    private var gradientAngle: Binding<Double> {
        Binding(
            get: { if case .gradient(let gradient) = look.background { return gradient.angle } else { return 45 } },
            set: { angle in
                update { appearance in
                    guard case .gradient(var gradient) = appearance.background else { return }
                    gradient.angle = angle
                    appearance.background = .gradient(gradient)
                }
            }
        )
    }

    private var accent: Binding<Color> {
        Binding(
            get: { Theme(appearance: look).accent },
            set: { color in if let rgba = RGBAColor(color) { update { $0.accent = rgba } } }
        )
    }
}

/// The background tabs. A photo and an image file are both stored as an image.
private enum BackgroundKind: String, CaseIterable, Identifiable {
    case system, color, gradient, image

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .color: return "Color"
        case .gradient: return "Gradient"
        case .image: return "Photo"
        }
    }

    init(_ background: Appearance.Background) {
        switch background {
        case .system: self = .system
        case .color: self = .color
        case .gradient: self = .gradient
        case .image: self = .image
        }
    }
}
