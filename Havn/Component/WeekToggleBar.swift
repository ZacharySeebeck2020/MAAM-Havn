import SwiftUI
import CoreData

// MARK: - Public wrapper
struct WeekMonthExpandable: View {
    @Binding var selectedDay: Date
    @State var isExpanded: Bool = false

    // Height of the compact week bar (used to position the overlay panel)
    private let barHeight: CGFloat = 76

    var body: some View {
        VStack(spacing: 0) {
            WeekBar(selectedDay: $selectedDay, isExpanded: $isExpanded)
                .frame(height: barHeight)                // bar content fits this height
                .background(Color("PrimaryColor"))
        } .overlay(alignment: .top) {
                if isExpanded {
                    MonthPanel(selectedDay: $selectedDay, isExpanded: $isExpanded)
                        .offset(y: barHeight - 80)               // aligns exactly under the bar
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
        .zIndex(20)
    }
}

// MARK: - Compact week bar with chevron
private struct WeekBar: View {
    @Binding var selectedDay: Date
    @Binding var isExpanded: Bool
    private let cal = Calendar.current

    var body: some View {
        ZStack {
            Color("PrimaryColor")

            HStack(spacing: 0) {
                WeekStrip(selectedDay: $selectedDay)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
            VStack {
                Spacer()
                Button {
                    withAnimation(.snappy) { isExpanded = true }
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
                        Image(systemName: "chevron.down")
                            .font(.headline.weight(.semibold))
                    }
                }
                .accessibilityLabel("Open calendar")
                .buttonStyle(.plain)
                .padding(.bottom, -30) // let the circle dip into the content below
            }

        }
    }
}

// MARK: - Sliding month panel (covers content) + centered bottom handle
private struct MonthPanel: View {
    @Binding var selectedDay: Date
    @Binding var isExpanded: Bool
    @State private var monthAnchor: Date = Date()
    @Environment(\.managedObjectContext) private var moc
    @State private var monthHasEntries: Bool = true

    private let cal = Calendar.current
    
    
    private func checkMonth() {
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: monthAnchor))!
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        let req: NSFetchRequest<JournalEntry> = JournalEntry.fetchRequest()
        req.fetchLimit = 1
        req.predicate = NSPredicate(format: "day >= %@ AND day < %@", start as NSDate, end as NSDate)
        monthHasEntries = ((try? moc.count(for: req)) ?? 0) > 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            // Full-width panel
            VStack(spacing: 12) {
                HStack {
                    Button { stepMonth(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 36, height: 36)
                    }.buttonStyle(.plain)

                    Spacer()

                    Text(monthTitle(monthAnchor))
                        .font(HavnTheme.Typeface.title)

                    Spacer()

                    Button { stepMonth(+1) } label: {
                        Image(systemName: "chevron.right").frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCurrentMonth)
                    .opacity(isCurrentMonth ? 0.35 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Weekday symbols
                HStack {
                    ForEach(cal.shortWeekdaySymbolsIndexed(), id: \.self.idx) { s in
                        Text(s.sym)
                            .font(HavnTheme.Typeface.weekday)
                            .foregroundStyle(Color("TextMutedColor"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)

                // Month grid (6 rows)
                let today = cal.startOfDay(for: Date())

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
                    ForEach(gridDays(in: monthAnchor), id: \.self) { day in
                        let dStart   = cal.startOfDay(for: day)

                        DayCell(
                            date: day,
                            isInMonth: cal.isDate(day, equalTo: monthAnchor, toGranularity: .month),
                            isSelected: cal.isDate(day, inSameDayAs: selectedDay),
                            isFuture: dStart > today
                        ) {
                            selectedDay = cal.startOfDay(for: day)
                            withAnimation(.snappy) { isExpanded = false }
                            Haptics.light()
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, monthHasEntries ? 56 : 10) // room for the centered handle
                
                if !monthHasEntries {
                    Text("No entries this month yet.")
                        .font(HavnTheme.Typeface.footnote)
                        .foregroundStyle(Color("TextMutedColor"))
                        .padding(.top, 0)
                        .padding(.bottom, 30)
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
                .accessibilityLabel("Close calendar")
                .padding(.bottom, -30) // let the circle dip into the content below
            }
        }
        .onAppear { monthAnchor = selectedDay }
        .onAppear { checkMonth() }
        .onChange(of: monthAnchor) { _, _ in checkMonth() }
        .zIndex(30)
    }

    private var isCurrentMonth: Bool {
        cal.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }
    private func stepMonth(_ delta: Int) {
        if let m = cal.date(byAdding: .month, value: delta, to: monthAnchor) {
            withAnimation(.snappy) { monthAnchor = m }
        }
    }
    private func monthTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).year())
    }
    private func gridDays(in month: Date) -> [Date] {
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let weekday = cal.component(.weekday, from: startOfMonth)
        let firstGridDay = cal.date(byAdding: .day, value: -(weekday - cal.firstWeekday), to: startOfMonth)!
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: firstGridDay) }
    }
}

// MARK: - Day cell
private struct DayCell: View {
    let date: Date
    let isInMonth: Bool
    let isSelected: Bool
    let isFuture: Bool
    let action: () -> Void
    @Environment(\.calendar) private var cal
    @Environment(\.colorScheme) private var scheme
    
    private var selFillOpacity: Double   { scheme == .dark ? 0.36 : 0.24 }
    private var selStrokeOpacity: Double { scheme == .dark ? 0.55 : 0.40 }
    private var outOpacity: Double       { scheme == .dark ? 1 : 0.55 }

    var body: some View {
        Button(action: action) {
            Text("\(cal.component(.day, from: date))")
                .font(.callout.weight(.semibold))
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .foregroundStyle(
                    isSelected ? Color("TextMainColor")
                    : isFuture  ? Color("TextMutedColor").opacity(0.35)
                    : isInMonth ? Color("TextMainColor")
                                : Color("TextMutedColor")
                )
                .background(
                    isSelected ?
                      RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color("AccentColor").opacity(selFillOpacity))
                      : nil
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .overlay(
            isSelected ?
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color("AccentColor").opacity(selStrokeOpacity), lineWidth: 1)
              : nil
        )
        .opacity(isFuture ? 0.55 : 1.0)
    }

    private var foreground: Color {
        if isSelected { return Color.black }
        return isInMonth ? Color("TextMainColor") : Color("TextMutedColor").opacity(outOpacity)
    }
}

// MARK: - Helpers
private extension Calendar {
    func shortWeekdaySymbolsIndexed() -> [(idx: Int, sym: String)] {
        let syms = shortWeekdaySymbols
        let start = firstWeekday - 1
        return (0..<7).map { i in (i, syms[(start + i) % 7]) }
    }
}

// MARK: - Demo / Preview
private struct WeekMonthDemo: View {
    @State private var selected = Calendar.current.startOfDay(for: .now)
    
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
            WeekMonthExpandable(selectedDay: $selected)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview("Week→Month • Light") { WeekMonthDemo().preferredColorScheme(.light).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext) }
#Preview("Week→Month • Dark")  { WeekMonthDemo().preferredColorScheme(.dark).environment(\.managedObjectContext, PersistenceController.preview.container.viewContext) }
