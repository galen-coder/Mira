import SwiftUI

struct SettingsView: View {
    @AppStorage("appLanguage") private var storedLanguage = AppLanguage.system.rawValue
    @AppStorage("startupDocumentBehavior") private var storedStartupBehavior = StartupDocumentBehavior.temporaryDocument.rawValue
    @AppStorage("imageInsertAction") private var storedImageAction = ImageInsertAction.copyToAssets.rawValue
    @AppStorage("assetsFolderName") private var assetsFolderName = "assets"
    @AppStorage("assetsFolderBehavior") private var storedAssetsBehavior = AssetsFolderBehavior.ask.rawValue

    private var language: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: storedLanguage) ?? .system },
            set: { storedLanguage = $0.rawValue }
        )
    }

    private var imageAction: Binding<ImageInsertAction> {
        Binding(
            get: { ImageInsertAction(rawValue: storedImageAction) ?? .copyToAssets },
            set: { storedImageAction = $0.rawValue }
        )
    }

    private var startupBehavior: Binding<StartupDocumentBehavior> {
        Binding(
            get: { StartupDocumentBehavior(rawValue: storedStartupBehavior) ?? .temporaryDocument },
            set: { storedStartupBehavior = $0.rawValue }
        )
    }

    private var assetsBehavior: Binding<AssetsFolderBehavior> {
        Binding(
            get: { AssetsFolderBehavior(rawValue: storedAssetsBehavior) ?? .ask },
            set: { storedAssetsBehavior = $0.rawValue }
        )
    }

    private var currentLanguage: AppLanguage {
        AppLanguage(rawValue: storedLanguage) ?? .system
    }

    var body: some View {
        TabView {
            Form {
                Picker(L10n.tr("settings.language", language: currentLanguage), selection: language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }

                Picker(L10n.tr("settings.startupBehavior", language: currentLanguage), selection: startupBehavior) {
                    Text(L10n.tr("settings.openTemporaryDocument", language: currentLanguage)).tag(StartupDocumentBehavior.temporaryDocument)
                    Text(L10n.tr("settings.openRecentClosedDocument", language: currentLanguage)).tag(StartupDocumentBehavior.recentClosedDocument)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label(L10n.tr("settings.general", language: currentLanguage), systemImage: "gearshape") }

            Form {
                Picker(L10n.tr("settings.imageAction", language: currentLanguage), selection: imageAction) {
                    Text(L10n.tr("settings.copyToAssets", language: currentLanguage)).tag(ImageInsertAction.copyToAssets)
                    Text(L10n.tr("settings.linkOriginal", language: currentLanguage)).tag(ImageInsertAction.linkOriginal)
                }

                TextField(L10n.tr("settings.assetsFolder", language: currentLanguage), text: $assetsFolderName)

                Picker(L10n.tr("settings.assetsBehavior", language: currentLanguage), selection: assetsBehavior) {
                    Text(L10n.tr("settings.askCreate", language: currentLanguage)).tag(AssetsFolderBehavior.ask)
                    Text(L10n.tr("settings.autoCreate", language: currentLanguage)).tag(AssetsFolderBehavior.createAutomatically)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label(L10n.tr("settings.images", language: currentLanguage), systemImage: "photo") }
        }
        .frame(width: 560, height: 320)
        .scenePadding()
    }
}
