import DroppyKit
import SwiftUI

struct FaceUnlockSettings: View {
    @ObservedObject var droplet: FaceUnlockDroplet

    var body: some View {
        DropletSettingsPane {
            DropletSettingsCard {
                FaceScanHero(droplet: droplet)
            }

            DropletSettingsCard {
                DropletToggleRow(
                    title: L.s("set.enable"),
                    icon: "faceid",
                    iconColor: .green,
                    subtitle: readinessText,
                    isOn: droplet.isEnabledBinding
                )
                DropletControlRow(title: L.s("set.how"), icon: "keyboard", iconColor: .gray,
                                  infoTip: L.s("set.howTip")) {
                    Text(L.s("set.howValue"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                if let last = droplet.lastEvent {
                    DropletControlRow(title: L.s("set.last"), icon: "clock.arrow.circlepath", iconColor: .gray) {
                        Text(last)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 320, alignment: .trailing)
                    }
                }
            }

            DropletSettingsSection {
                VStack(alignment: .leading, spacing: 2) {
                    settingsSectionHeader(LocalizedStringKey(L.s("set.credentials")))
                    Text(L.s("set.credentialsDetail"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } content: {
                CredentialsCard(droplet: droplet)
            }

            DropletSettingsSection {
                VStack(alignment: .leading, spacing: 2) {
                    settingsSectionHeader(LocalizedStringKey(L.s("set.recognition")))
                    Text(L.s("set.recognitionDetail"))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            } content: {
                DropletSettingsCard {
                    DropletSliderRow(
                        title: L.s("set.strictness"),
                        value: String(format: "%.2f", droplet.threshold),
                        binding: droplet.thresholdBinding,
                        range: 0.2...1.5,
                        step: 0.01
                    )
                    if droplet.threshold > FaceUnlockDroplet.looseThreshold {
                        DropletControlRow(title: L.s("set.loose"), icon: "exclamationmark.triangle.fill", iconColor: .orange,
                                          infoTip: L.s("set.looseTip")) {
                            EmptyView()
                        }
                    }
                    DropletControlRow(
                        title: L.s("set.savedFace"),
                        icon: "person.crop.circle",
                        iconColor: .blue
                    ) {
                        if droplet.hasFaceEnrolled {
                            Button(L.s("set.remove"), role: .destructive) { droplet.deleteFace() }
                                .buttonStyle(DroppyQuietButtonStyle(size: .small, destructive: true))
                        } else {
                            DropletValuePill(text: L.s("set.none"))
                        }
                    }
                }
            }

            DropletSettingsSection {
                settingsSectionHeader(LocalizedStringKey(L.s("set.permissions")))
            } content: {
                DropletSettingsCard {
                    DropletControlRow(title: L.s("set.camera"), icon: "camera.fill", iconColor: .orange) {
                        if droplet.cameraStatus == .granted {
                            StatusDot(text: L.s("set.allowed"), ok: true)
                        } else {
                            Button(L.s("set.allow")) { droplet.requestCamera() }
                                .buttonStyle(DroppyAccentButtonStyle(size: .small))
                        }
                    }
                    DropletControlRow(
                        title: L.s("set.accessibility"),
                        icon: "keyboard.fill",
                        iconColor: .purple,
                        infoTip: L.s("set.accessibilityTip")
                    ) {
                        if droplet.accessibilityTrusted {
                            StatusDot(text: L.s("set.allowed"), ok: true)
                        } else {
                            HStack(spacing: DroppySpacing.xs) {
                                Button(L.s("set.open")) { droplet.openAccessibilitySettings() }
                                    .buttonStyle(DroppyAccentButtonStyle(size: .small))
                                Button {
                                    droplet.refreshPermissions()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                .help(L.s("set.recheck"))
                            }
                        }
                    }
                    DropletControlRow(
                        title: L.s("set.input"),
                        icon: "hand.tap.fill",
                        iconColor: .blue,
                        infoTip: L.s("set.inputTip")
                    ) {
                        if droplet.inputMonitoring {
                            StatusDot(text: L.s("set.allowed"), ok: true)
                        } else {
                            HStack(spacing: DroppySpacing.xs) {
                                Button(L.s("set.allow")) { droplet.requestInputMonitoring() }
                                    .buttonStyle(DroppyAccentButtonStyle(size: .small))
                                Button {
                                    droplet.refreshPermissions()
                                } label: {
                                    Image(systemName: "arrow.clockwise")
                                }
                                .buttonStyle(DroppyCircleButtonStyle(size: 24))
                                .help(L.s("set.recheck"))
                            }
                        }
                    }
                }
                .droppyFlatGlassControls()
            }
        }
    }

    private var readinessText: String {
        let missing = droplet.readiness
        if missing.isEmpty { return L.s("set.ready") }
        return L.f("set.missing", missing.joined(separator: ", "))
    }
}

private struct CredentialsCard: View {
    @ObservedObject var droplet: FaceUnlockDroplet
    @State private var username = ""
    @State private var password = ""
    @State private var reveals = false
    @State private var savedFlash = false

    var body: some View {
        DropletSettingsCard {
            DropletControlRow(title: L.s("cred.username"), icon: "person.fill", iconColor: .blue) {
                TextField("", text: $username, prompt: Text(droplet.defaultUsername))
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 220)
            }

            DropletControlRow(title: L.s("cred.password"), icon: "key.fill", iconColor: .yellow) {
                HStack(spacing: DroppySpacing.xs) {
                    Group {
                        if reveals {
                            TextField("", text: $password, prompt: Text(placeholder))
                        } else {
                            SecureField("", text: $password, prompt: Text(placeholder))
                        }
                    }
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 200)
                    .onSubmit(save)

                    Button {
                        reveals.toggle()
                    } label: {
                        Image(systemName: reveals ? "eye.slash" : "eye")
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(DroppyCircleButtonStyle(size: 24))
                    .help(L.s(reveals ? "cred.hide" : "cred.show"))
                }
            }

            DropletToggleRow(
                title: L.s("cred.typeUser"),
                icon: "rectangle.and.pencil.and.ellipsis",
                iconColor: .gray,
                subtitle: L.s("cred.typeUserDetail"),
                isOn: droplet.typesUsernameBinding
            )

            DropletControlRow(
                title: L.s(droplet.hasPasswordSaved ? "cred.saved" : "cred.nothing"),
                icon: droplet.hasPasswordSaved ? "lock.fill" : "lock.open",
                iconColor: droplet.hasPasswordSaved ? .green : .gray
            ) {
                HStack(spacing: DroppySpacing.xs) {
                    if savedFlash {
                        Label(L.s("cred.flash"), systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.green)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                    if droplet.hasPasswordSaved {
                        Button(L.s("cred.delete"), role: .destructive) { droplet.deletePassword() }
                            .buttonStyle(DroppyQuietButtonStyle(size: .small, destructive: true))
                    }
                    Button(L.s("cred.save"), action: save)
                        .buttonStyle(DroppyAccentButtonStyle(size: .small))
                        .disabled(!canSave)
                }
            }
        }
        .droppyFlatGlassControls()
        .onAppear { username = droplet.username }
    }

    private var placeholder: String { droplet.hasPasswordSaved ? "••••••••" : L.s("cred.placeholder") }

    private var canSave: Bool {
        !password.isEmpty || (droplet.hasPasswordSaved && username != droplet.username)
    }

    private func save() {
        guard canSave else { return }
        droplet.saveCredentials(username: username, password: password)
        password = ""
        reveals = false
        withAnimation(.spring(duration: 0.35)) { savedFlash = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { savedFlash = false }
        }
    }
}

private struct StatusDot: View {
    let text: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(ok ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
