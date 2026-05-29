import SwiftUI

private struct EditorModeKey: FocusedValueKey {
    typealias Value = Binding<EditorMode>
}

private struct ShowsOutlineKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

private struct FocusModeKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

private struct MarkdownEditCommandKey: FocusedValueKey {
    typealias Value = Binding<MarkdownEditCommand?>
}

extension FocusedValues {
    var editorMode: Binding<EditorMode>? {
        get { self[EditorModeKey.self] }
        set { self[EditorModeKey.self] = newValue }
    }

    var showsOutline: Binding<Bool>? {
        get { self[ShowsOutlineKey.self] }
        set { self[ShowsOutlineKey.self] = newValue }
    }

    var isFocusMode: Binding<Bool>? {
        get { self[FocusModeKey.self] }
        set { self[FocusModeKey.self] = newValue }
    }

    var markdownEditCommand: Binding<MarkdownEditCommand?>? {
        get { self[MarkdownEditCommandKey.self] }
        set { self[MarkdownEditCommandKey.self] = newValue }
    }
}
