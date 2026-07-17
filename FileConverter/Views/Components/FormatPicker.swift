import SwiftUI

/// 目标格式选择器
struct FormatPicker: View {
    let sourceFormat: ConversionFormat
    let selectedTarget: ConversionFormat
    let availableTargets: [ConversionFormat]
    let onSelect: (ConversionFormat) -> Void

    var body: some View {
        Menu {
            ForEach(availableTargets, id: \.self) { format in
                Button(action: { onSelect(format) }) {
                    HStack {
                        Text(format.displayName)
                        if format == selectedTarget {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedTarget.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
