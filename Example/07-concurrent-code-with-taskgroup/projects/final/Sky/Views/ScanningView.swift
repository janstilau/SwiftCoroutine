import SwiftUI

/// A view that displays the amount of total, completed, and avg. per second scan tasks.
struct ScanningView: View {
  @Binding var total: Int
  @Binding var completed: Int
  @Binding var perSecond: Double
  @Binding var scheduled: Int
  
  private func colorForAvg(_ num: Int) -> Color {
    switch num {
    case 0..<5: return .red
    case 5..<10: return .yellow
    case 10...: return .green
    default: return .gray
    }
  }
  
  var body: some View {
    VStack(alignment: .leading) {
      
      ProgressView("\(scheduled) scheduled",
                   value: Double(min(scheduled, total)),
                   total: Double(total))
        .tint(colorForAvg(scheduled))
        .padding()
      
      ProgressView(String(format: "%.2f per sec.", perSecond),
                   value: min(perSecond, 10),
                   total: 10)
        .tint(colorForAvg(Int(perSecond)))
        .padding()
      
      ProgressView("\(completed) tasks completed",
                   value: min(1.0, Double(completed) / Double(total)))
        .tint(Color.blue)
        .padding()
    }
    .font(.callout)
    .padding()
  }
}
