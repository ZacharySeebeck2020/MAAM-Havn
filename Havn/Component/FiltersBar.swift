import SwiftUI
import CoreData

// MARK: - Public wrapper
struct FiltersBar: View {
    @State var isExpanded: Bool = false
    @Binding var moodFilter: Int
    @Binding var energyFilter: Int
    @Binding var weatherFilter: Int
    @Binding var searchFilter: String
    
    private let barHeight: CGFloat = 60
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color("PrimaryColor")
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(Color("TextMutedColor"))

                    TextField(
                        "Search entries, tags…",
                        text: $searchFilter,
                        prompt: Text("Search entries, tags…")
                    )
                    .foregroundStyle(Color("TextMainColor"))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                
                VStack {
                    Spacer()
                    Button {
                        Haptics.soft()
                        withAnimation(.snappy) { isExpanded = true }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("PrimaryColor"))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color("AccentColor").opacity(0.35), lineWidth: 1)
                                )
                            Image(systemName: "chevron.down")
                                .font(.headline.weight(.semibold))
                        }
                    }
                    .accessibilityLabel("Open filters.")
                    .buttonStyle(.plain)
                    .padding(.bottom, -30) // let the circle dip into the content below
                }

            }
            .frame(height: barHeight)                // bar content fits this height
            .background(Color("PrimaryColor"))
        } .overlay(alignment: .top) {
            if (isExpanded) {
                FiltersPanel(isExpanded: $isExpanded, moodFilter: $moodFilter, energyFilter: $energyFilter, weatherFilter: $weatherFilter)
                    .offset(y: barHeight - 30)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)

            }
        }
        .zIndex(20)
        .animation(.snappy, value: isExpanded)
    }
}

// MARK: - Sliding Filers Panel
private struct FiltersPanel: View {
    @Binding var isExpanded: Bool
    @Binding var moodFilter: Int
    @Binding var energyFilter: Int
    @Binding var weatherFilter: Int
    
    
    var body: some View {
        ZStack(alignment: .top) {
            ZStack(alignment: .top) {
                // Full-width panel
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        ChipSelector(headline: "Mood", filterIndex: $moodFilter, objectArray: VitalsEmoji.emojis(for: .mood))
                            .padding(.vertical, 5)
                        
                        ChipSelector(headline: "Energy", filterIndex: $energyFilter, objectArray: VitalsEmoji.emojis(for: .energy))
                            .padding(.vertical, 5)
                        
                        ChipSelector(headline: "Weather", filterIndex: $weatherFilter, objectArray: VitalsEmoji.emojis(for: .weather))
                            .padding(.vertical, 5)
                    }
                    .padding(.all, 10)
                    .padding(.top, 0)
                    .padding(.bottom, 15)

                    HStack {
                        Spacer()
                        Button("Clear all") {
                            withAnimation(.snappy) {
                                moodFilter = 0
                                energyFilter = 0
                                weatherFilter = 0
                            }
                            Haptics.soft()
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color("AccentColor"))
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }
                    
                }
                .background(Color("PrimaryColor"))

                // Centered bottom handle (circle) with chevron
                VStack {
                    Spacer()
                    Button {
                        withAnimation(.snappy) { isExpanded = false }
                        Haptics.soft()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color("PrimaryColor"))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color("AccentColor").opacity(0.35), lineWidth: 1)
                                )
                            Image(systemName: "chevron.up")
                                .font(.headline.weight(.semibold))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close filters")
                    .padding(.bottom, -30) // let the circle dip into the content below
                }
            }
            .zIndex(30)
        }
    }
}

private struct ChipSelector: View {
    @State var headline: String;
    @Binding var filterIndex: Int;
    @State var objectArray: Array<String>;
    
    var body: some View {
        Text(headline)
            .font(HavnTheme.Typeface.headline)
            .foregroundStyle(Color("TextMutedColor"))
            .padding(.horizontal, 10)

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 15) {
                // "Any" chip (index 0)
                Button {
                    withAnimation(.snappy) { filterIndex = 0 }
                    Haptics.soft()
                } label: {
                    Text("Any")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(filterIndex == 0 ? Color("TextMainColor") : Color("TextMutedColor"))
                        .background(
                            Capsule().fill(
                                filterIndex == 0 ? Color("AccentColor").opacity(0.22)
                                                 : Color("BackgroundColor").opacity(0.12)
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(filterIndex == 0 ? Color("AccentColor").opacity(0.35) : .clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                // Emoji chips (indices 1...n)
                ForEach(Array(objectArray.enumerated()), id: \.offset) { idx, emoji in
                    let chipIndex = idx + 1
                    Button {
                        withAnimation(.snappy) { filterIndex = chipIndex }
                        Haptics.light()
                    } label: {
                        Text(emoji)
                            .font(.title3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(
                                    filterIndex == chipIndex ? Color("AccentColor").opacity(0.22)
                                                             : Color("BackgroundColor").opacity(0.18)
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(filterIndex == chipIndex ? Color("AccentColor").opacity(0.35) : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(headline) option \(emoji)")
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Demo / Preview
private struct WeekMonthDemo: View {
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var moodFilter: Int = 0
    @State private var energyFilter: Int = 0
    @State private var weatherFilter: Int = 0
    @State private var searchFilter: String = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            // Page content beneath (will be covered when expanded)
            ScrollView {
                VStack(spacing: 28) {
                    ForEach(1..<12, id: \.self) { i in
                        Text("Row \(i)").frame(maxWidth: .infinity, minHeight: 80)
                            .background(Color("BackgroundColor"))
                            .foregroundStyle(Color("TextMainColor"))
                    }
                    Spacer(minLength: 240)
                }
                .padding(.top, 12)
            }
            .background(Color("BackgroundColor").ignoresSafeArea())

            // Header
            FiltersBar(moodFilter: $moodFilter, energyFilter: $energyFilter, weatherFilter: $weatherFilter, searchFilter: $searchFilter)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Week→Month • Light") { WeekMonthDemo().preferredColorScheme(.light).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext) }
#Preview("Week→Month • Dark")  { WeekMonthDemo().preferredColorScheme(.dark).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext) }
