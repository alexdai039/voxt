import AppKit
import SwiftUI

struct SettingsMenuOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: AnyHashable { AnyHashable(value) }
}

struct SettingsMenuPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [SettingsMenuOption<Value>]
    let selectedTitle: String
    let width: CGFloat

    private var resolvedWidth: CGFloat {
        SettingsUIStyle.resolvedSelectWidth(width)
    }

    var body: some View {
        SettingsNativeMenuPicker(
            selection: $selection,
            options: options,
            selectedTitle: selectedTitle,
            preferredWidth: resolvedWidth
        )
        .frame(width: resolvedWidth, height: 34)
        .alignmentGuide(.firstTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center]
        }
        .alignmentGuide(.lastTextBaseline) { dimensions in
            dimensions[VerticalAlignment.center]
        }
    }
}

struct SettingsSelectionButton<Label: View>: View {
    let width: CGFloat
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    private var resolvedWidth: CGFloat {
        SettingsUIStyle.resolvedSelectWidth(width)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SettingsSelectLikeButtonStyle())
        .frame(width: resolvedWidth)
    }
}

struct SettingsSelectLikeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: SettingsUIStyle.controlCornerRadius, style: .continuous)
                    .fill(SettingsUIStyle.controlFillColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: SettingsUIStyle.controlCornerRadius, style: .continuous)
                    .strokeBorder(SettingsUIStyle.subtleBorderColor, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct SettingsDialogActionRow<Leading: View, Trailing: View>: View {
    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            leading
            Spacer(minLength: 12)
            trailing
        }
        .padding(.top, 4)
    }
}

enum SettingsMenuInteraction {
    @discardableResult
    static func performSelection(for menuItem: NSMenuItem?) -> Bool {
        guard
            let menuItem,
            let menu = menuItem.menu
        else {
            return false
        }

        let index = menu.index(of: menuItem)
        guard index >= 0 else {
            return false
        }

        menu.performActionForItem(at: index)
        menu.cancelTracking()
        return true
    }
}

private struct SettingsNativeMenuPicker<Value: Hashable>: NSViewRepresentable {
    @Binding var selection: Value
    let options: [SettingsMenuOption<Value>]
    let selectedTitle: String
    let preferredWidth: CGFloat

    private var state: SettingsNativeMenuPickerState {
        let selectionBinding = $selection
        return SettingsNativeMenuPickerState(
            options: options.map { option in
                SettingsNativeMenuPickerOption(value: AnyHashable(option.value), title: option.title)
            },
            selectedValue: AnyHashable(selection),
            selectedTitle: selectedTitle,
            preferredWidth: preferredWidth,
            onSelectValue: { selectedValue in
                guard let value = selectedValue.base as? Value else { return }
                if selectionBinding.wrappedValue != value {
                    selectionBinding.wrappedValue = value
                }
            }
        )
    }

    func makeCoordinator() -> SettingsNativeMenuPickerCoordinator {
        SettingsNativeMenuPickerCoordinator(state: state)
    }

    func makeNSView(context: Context) -> SettingsMenuHostView {
        let hostView = SettingsMenuHostView()
        hostView.onSelectIndex = { [weak coordinator = context.coordinator] index in
            coordinator?.selectionDidChange(index: index)
        }
        return hostView
    }

    func updateNSView(_ nsView: SettingsMenuHostView, context: Context) {
        context.coordinator.state = state
        nsView.onSelectIndex = { [weak coordinator = context.coordinator] index in
            coordinator?.selectionDidChange(index: index)
        }
        context.coordinator.update(nsView)
    }
}

private final class SettingsNativeMenuPickerCoordinator: NSObject {
    var state: SettingsNativeMenuPickerState

    init(state: SettingsNativeMenuPickerState) {
        self.state = state
    }

    func update(_ hostView: SettingsMenuHostView) {
        let titles = state.options.map(\.title)
        if let selectedIndex = state.options.firstIndex(where: { $0.value == state.selectedValue }) {
            hostView.toolTip = state.options[selectedIndex].title
            hostView.updateMenu(
                titles: titles,
                selectedIndex: selectedIndex,
                fallbackTitle: state.options[selectedIndex].title,
                preferredWidth: state.preferredWidth
            )
        } else if let firstOption = state.options.first {
            hostView.toolTip = firstOption.title
            hostView.updateMenu(
                titles: titles,
                selectedIndex: 0,
                fallbackTitle: firstOption.title,
                preferredWidth: state.preferredWidth
            )
            if state.selectedValue != firstOption.value {
                DispatchQueue.main.async { [weak self] in
                    self?.state.onSelectValue(firstOption.value)
                }
            }
        } else {
            hostView.toolTip = state.selectedTitle
            hostView.updateMenu(
                titles: [],
                selectedIndex: nil,
                fallbackTitle: state.selectedTitle,
                preferredWidth: state.preferredWidth
            )
        }
    }

    func selectionDidChange(index: Int) {
        guard state.options.indices.contains(index) else { return }
        state.onSelectValue(state.options[index].value)
    }
}

private struct SettingsNativeMenuPickerState {
    let options: [SettingsNativeMenuPickerOption]
    let selectedValue: AnyHashable
    let selectedTitle: String
    let preferredWidth: CGFloat
    let onSelectValue: (AnyHashable) -> Void
}

private struct SettingsNativeMenuPickerOption {
    let value: AnyHashable
    let title: String
}

private final class SettingsMenuHostView: NSView {
    private let titleField = NSTextField(labelWithString: "")
    private let indicatorView = NSImageView()
    private let popupMenu = NSMenu()
    private var selectedIndex: Int?
    private var currentMenuWidth: CGFloat = 0
    var onSelectIndex: ((Int) -> Void)?

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        popupMenu.autoenablesItems = false
        popupMenu.showsStateColumn = true

        titleField.translatesAutoresizingMaskIntoConstraints = false
        titleField.font = .systemFont(ofSize: 13, weight: .medium)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.image = NSImage(
            systemSymbolName: "chevron.up.chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(.init(pointSize: 11, weight: .semibold))
        indicatorView.contentTintColor = .secondaryLabelColor

        addSubview(titleField)
        addSubview(indicatorView)

        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleField.trailingAnchor.constraint(lessThanOrEqualTo: indicatorView.leadingAnchor, constant: -8),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicatorView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            indicatorView.centerYAnchor.constraint(equalTo: centerYAnchor),
            indicatorView.widthAnchor.constraint(equalToConstant: 14),
            indicatorView.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = SettingsUIStyle.controlCornerRadius
        layer?.backgroundColor = SettingsUIStyle.controlFillNSColor.cgColor
        layer?.borderColor = SettingsUIStyle.subtleBorderNSColor.cgColor
        layer?.borderWidth = 1
    }

    func updateMenu(titles: [String], selectedIndex: Int?, fallbackTitle: String, preferredWidth: CGFloat) {
        let menuWidth = max(ceil(preferredWidth), 1)
        let needsRebuild = popupMenu.items.map(\.title) != titles || abs(currentMenuWidth - menuWidth) > 0.5

        if needsRebuild {
            popupMenu.removeAllItems()
            for (index, title) in titles.enumerated() {
                let item = NSMenuItem(title: title, action: #selector(selectMenuItem(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                item.state = index == selectedIndex ? .on : .off
                popupMenu.addItem(item)
            }
            currentMenuWidth = menuWidth
        }

        self.selectedIndex = selectedIndex
        for item in popupMenu.items {
            item.state = item.tag == selectedIndex ? .on : .off
        }

        popupMenu.minimumWidth = menuWidth
        titleField.stringValue = fallbackTitle
    }

    override func mouseDown(with event: NSEvent) {
        guard !popupMenu.items.isEmpty else { return }
        let selectedItem = selectedIndex.flatMap { index in
            popupMenu.items.first(where: { $0.tag == index })
        }
        _ = popupMenu.popUp(positioning: selectedItem, at: NSPoint(x: 0, y: bounds.height + 8), in: self)
    }

    @objc
    private func selectMenuItem(_ sender: NSMenuItem) {
        onSelectIndex?(sender.tag)
    }
}
