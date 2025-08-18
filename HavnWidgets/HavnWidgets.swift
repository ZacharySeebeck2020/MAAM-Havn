import WidgetKit
import SwiftUI
import os.log
import ImageIO
import MobileCoreServices // (or CoreServices on older SDKs)

private func loadDownsampledImage(url: URL, maxPixelDimension: Int) -> UIImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
    return UIImage(cgImage: thumb)
}

extension WidgetConfiguration
{
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration
    {
        if #available(iOSApplicationExtension 17.0, *)
        {
            return self.contentMarginsDisabled()
        }
        else
        {
            return self
        }
    }
}

extension View {
    @ViewBuilder
    func widgetContainerBackground<BG: View>(_ bg: @autoclosure () -> BG) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            self.containerBackground(for: .widget) { bg() }
        } else {
            self.background(bg())
        }
    }
}

private let HAVN_WIDGET_MAX_PIXEL_AREA = 400_000 // buffer below observed limit (1,144,440)

private extension UIImage {
    func resizedToFit(maxArea: Int) -> UIImage {
        // Convert from points to pixels using the image scale.
        let pixelWidth = size.width * scale
        let pixelHeight = size.height * scale
        let currentArea = pixelWidth * pixelHeight
        if currentArea <= CGFloat(maxArea) { return self }

        // Compute uniform scale factor based on area ratio.
        let scaleFactor = sqrt(CGFloat(maxArea) / currentArea)
        let newSizePoints = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)

        // Preserve color space and format where possible.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1 // we already baked scale into newSizePoints; render at 1.0 to get exact pixel count
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: newSizePoints, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSizePoints))
        }
    }
}

struct HavnWidgetEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
    let image: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> HavnWidgetEntry { load() }
    func getSnapshot(in context: Context, completion: @escaping (HavnWidgetEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HavnWidgetEntry>) -> Void) {
        let entry = load()
        // Refresh periodically; app also calls reloadAllTimelines() when writing bridge
        let next = Date().addingTimeInterval(60 * 45)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private let wlog = Logger(subsystem: "work.seebeck.havn.widget", category: "timeline")

    private func load() -> HavnWidgetEntry {
        let fm = FileManager.default
        let container = fm.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
        let stateURL = container!.appendingPathComponent("widget-state.json")
        let thumbURL = container!.appendingPathComponent("today-thumb.jpg")
        let data = (try? Data(contentsOf: stateURL)) ?? Data()
        let state = (try? JSONDecoder().decode(WidgetState.self, from: data))
            ?? WidgetState(hasEntryToday: false, streak: 0, bestStreak: 0, locked: false, updatedAt: .distantPast)
        let maxDim = Int(sqrt(Double(HAVN_WIDGET_MAX_PIXEL_AREA))) // e.g. 632 for 400k area
        var img: UIImage? = loadDownsampledImage(url: thumbURL, maxPixelDimension: maxDim)

        // (Optional) If the file on disk might already be small, keep your safety resize:
        if let raw = img {
            img = raw.resizedToFit(maxArea: HAVN_WIDGET_MAX_PIXEL_AREA)
        }

        return HavnWidgetEntry(date: Date(), state: state, image: img)
    }
}

struct HavnWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: HavnWidgetEntry
    
    var body: some View {
        switch family {
        case .systemMedium:
            contentMedium
        default:
            contentSmall
        }
    }
    
    @ViewBuilder
    var contentSmall: some View {
        ZStack {
            if entry.state.locked {
                backgroundView.opacity(0.7).blur(radius: 10).redacted(reason: .privacy).overlay() {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(.ultraThinMaterial).opacity(0.6)
                }
            } else {
                backgroundView.overlay() {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(.ultraThinMaterial).opacity(0.6)
                }
            }

            VStack(spacing: 4) {
                HStack {
                    Image(systemName: "flame.fill")
                    Text("\(entry.state.streak)").monospacedDigit().bold()
                    Spacer()
                }
                .font(.caption)
                .padding(.all, 10)
                
                Spacer()

                if entry.state.hasEntryToday {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done for today")
                        Spacer()
                    }
                    .font(.footnote)
                    .padding(.all, 10)
                } else {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add today’s entry")
                        Spacer()
                    }
                    .font(.footnote)
                    .padding(.all, 10)
                }
            }
            .padding(8)
            .foregroundStyle(.white)
        }
        .widgetContainerBackground(backgroundView)
        .widgetURL(URL(string: "havn://openTodayEditor"))
    }
    
    private var contentMedium: some View {
        ZStack {
            if entry.state.locked {
                backgroundView.opacity(0.7).blur(radius: 10).redacted(reason: .privacy).overlay() {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(.ultraThinMaterial).opacity(0.55)
                }
            } else {
                backgroundView.overlay() {
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(.ultraThinMaterial).opacity(0.45)
                }
            }

            VStack(spacing: 10) {
                // Top: Streak + Best
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Label { Text("\(entry.state.streak)").monospacedDigit().bold() } icon: { Image(systemName: "flame.fill") }
                        .font(.title3)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                        Text("Best \(entry.state.bestStreak)").monospacedDigit()
                    }
                    .font(.caption)
                    .opacity(0.95)
                }

                // Middle: last 7 days mini-history (filled = entry day)
                HStack(spacing: 6) {
                    let days = last7Booleans()
                    ForEach(days.indices, id: \.self) { i in
                        let filled = days[i]
                        Circle()
                            .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                            .background(Circle().fill(filled ? .white : .clear))
                            .frame(width: 10, height: 10)
                            .opacity(filled ? 1.0 : 0.75)
                    }
                    Spacer()
                }

                Spacer(minLength: 0)

                // Bottom: status/CTA
                HStack(spacing: 8) {
                    if entry.state.hasEntryToday {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Done for today")
                            .font(.footnote)
                            .bold()
                    } else {
                        Image(systemName: "plus.circle.fill")
                        Text("Add today’s entry")
                            .font(.footnote)
                            .bold()
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(.white)
        }
        .widgetContainerBackground(backgroundView)
        .widgetURL(URL(string: "havn://openTodayEditor"))
    }

    /// Naive last-7 visualization derived from the current streak.
    /// Fills the last `streak` days up to 7 (most recent on the right).
    private func last7Booleans() -> [Bool] {
        let s = max(0, min(7, entry.state.streak))
        var arr = Array(repeating: false, count: 7)
        if s > 0 {
            for i in 0..<(s) { arr[6 - i] = true }
        }
        return arr
    }


    @ViewBuilder private var backgroundView: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            if let img = entry.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: w + 2, height: h + 2, alignment: .center) // slight overdraw to avoid black border
                    .clipped()
            } else {
                LinearGradient(colors: [Color("AccentColor"), Color("PrimaryColor")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: w + 2, height: h + 2, alignment: .center)
                    .clipped()
            }
        }
    }
}

@main
struct HavnWidgets: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "HavnWidgets", provider: Provider()) { entry in
            HavnWidgetView(entry: entry)
        }
        .configurationDisplayName("Havn")
        .description("See your streak and jump into today’s entry.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}
