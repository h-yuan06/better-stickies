import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let environment: AppEnvironment

    var body: some View {
        TabView {
            AppearanceSettings(environment: environment)
                .tabItem { Label("Appearance", systemImage: "paintpalette") }
            BehaviorSettings(environment: environment)
                .tabItem { Label("Behavior", systemImage: "gearshape") }
            UpdateSettings(environment: environment)
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }
        }
        .frame(width: 460)
        .scenePadding()
    }
}

// MARK: - Appearance

private struct AppearanceSettings: View {
    let environment: AppEnvironment
    private var settings: AppSettings { environment.settings }

    var body: some View {
        Form {
            Section {
                LabeledContent("Default tint") {
                    HStack(spacing: 6) {
                        ForEach(NoteTint.palette) { tint in
                            Button {
                                settings.defaultTintHex = tint.hex
                            } label: {
                                Circle()
                                    .fill(tint.swatchColor)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle().strokeBorder(
                                            isSelected(tint) ? Color.primary : Color.white.opacity(0.4),
                                            lineWidth: isSelected(tint) ? 2 : 0.5
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                            .help(tint.name)
                        }
                        ColorPicker(
                            "",
                            selection: Binding(
                                get: { Color(hex: settings.defaultTintHex) ?? NoteTint.sage.swatchColor },
                                set: { settings.defaultTintHex = $0.hexString }
                            )
                        )
                        .labelsHidden()
                        .help("Custom tint")
                    }
                }
                Text("Notes without their own tint use this one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Tint strength") {
                    Slider(value: Binding(
                        get: { settings.tintStrength },
                        set: { settings.tintStrength = $0 }
                    ), in: 0...1)
                    .frame(width: 200)
                }

                Picker("Glass", selection: Binding(
                    get: { settings.glassStyle },
                    set: { settings.glassStyle = $0 }
                )) {
                    ForEach(GlassStyle.allCases) { style in
                        Text(style.label).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                Text(settings.glassStyle.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Glass reacts to the pointer", isOn: Binding(
                    get: { settings.interactiveGlass },
                    set: { settings.interactiveGlass = $0 }
                ))

                LabeledContent("Opacity when focused") {
                    Slider(value: Binding(
                        get: { settings.windowOpacity },
                        set: {
                            settings.windowOpacity = $0
                            environment.windowManager.applySettings()
                        }
                    ), in: 0.35...1)
                    .frame(width: 200)
                }

                LabeledContent("Opacity when idle") {
                    Slider(value: Binding(
                        get: { settings.inactiveOpacity },
                        set: {
                            settings.inactiveOpacity = $0
                            environment.windowManager.applySettings()
                        }
                    ), in: 0.05...1)
                    .frame(width: 200)
                }
                Text("Notes fade back once you click away, and return when focused.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Font", selection: Binding(
                    get: { settings.fontName },
                    set: { settings.fontName = $0 }
                )) {
                    Text("System").tag(TextStyle.systemFontSentinel)
                    Divider()
                    ForEach(Self.fontFamilies, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                LabeledContent("Text size") {
                    Stepper(
                        "\(Int(settings.fontSize)) pt",
                        value: Binding(get: { settings.fontSize }, set: { settings.fontSize = $0 }),
                        in: 10...28,
                        step: 1
                    )
                }
            }
        }
        .formStyle(.grouped)
    }

    private func isSelected(_ tint: NoteTint) -> Bool {
        settings.defaultTintHex.caseInsensitiveCompare(tint.hex) == .orderedSame
    }

    /// A short, curated list beats every font on the system in a settings popup.
    private static let fontFamilies = [
        "Helvetica Neue", "Avenir Next", "Georgia", "Menlo", "SF Pro Rounded", "New York",
    ].filter { NSFontManager.shared.availableFontFamilies.contains($0) }
}

// MARK: - Behavior

private struct BehaviorSettings: View {
    let environment: AppEnvironment
    private var settings: AppSettings { environment.settings }

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section {
                Picker("Notes float", selection: Binding(
                    get: { settings.floatLevel },
                    set: {
                        settings.floatLevel = $0
                        environment.windowManager.applySettings()
                    }
                )) {
                    ForEach(FloatLevel.allCases) { level in
                        Text(level.label).tag(level)
                    }
                }
                Text("""
                Above app windows keeps notes visible over full-screen apps. \
                Above everything also covers the menu bar and system dialogs.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Quick capture") {
                    HotKeyRecorder(
                        combo: Binding(
                            get: { settings.hotKey },
                            set: {
                                settings.hotKey = $0
                                environment.registerHotKey()
                            }
                        )
                    )
                }
                Text("Creates a note under the pointer from anywhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                Button("Reset Appearance to Defaults") {
                    settings.resetToDefaults()
                    environment.registerHotKey()
                    environment.windowManager.applySettings()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            // Unsigned builds are frequently refused here; say so rather than
            // silently leaving the toggle in a lying state.
            launchAtLoginError = "Could not change this setting: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Updates

private struct UpdateSettings: View {
    let environment: AppEnvironment
    private var updater: UpdaterController { environment.updater }

    var body: some View {
        Form {
            Section {
                LabeledContent("Version", value: updater.currentVersion)
                if updater.isConfigured {
                    Toggle("Check for updates automatically", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                    LabeledContent("Last checked") {
                        Text(updater.lastUpdateCheckDate?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                            .foregroundStyle(.secondary)
                    }
                    Button("Check Now") { updater.checkForUpdates() }
                } else {
                    Text("""
                    Automatic updates are not configured in this build. Release builds \
                    from GitHub Actions carry the signing key that enables them.
                    """)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
