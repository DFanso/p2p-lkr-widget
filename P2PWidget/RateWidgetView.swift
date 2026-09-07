import SwiftUI
import WidgetKit

struct RateWidgetView: View {
    let entry: RateEntry
    var body: some View {
        Text(entry.sample?.fillablePrice.map { String(format: "%.2f", $0) } ?? "—")
            .containerBackground(.fill, for: .widget)
    }
}
