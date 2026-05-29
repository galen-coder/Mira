import SwiftUI

struct EditorPreferences {
    @AppStorage("editorMode") var storedMode = EditorMode.split.rawValue
    @AppStorage("showsOutline") var showsOutline = true
    @AppStorage("isFocusMode") var isFocusMode = false
    @AppStorage("previewFontSize") var previewFontSize = 16.0

    var mode: EditorMode {
        get { EditorMode(rawValue: storedMode) ?? .split }
        nonmutating set { storedMode = newValue.rawValue }
    }
}
