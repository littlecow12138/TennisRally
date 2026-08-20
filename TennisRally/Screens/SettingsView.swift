import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        ZStack {
            CourtBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    appearanceSection
                    languageSection
                    Text("settings.apply_immediately")
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, -8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(Text("settings.title"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(HardCourt.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(HardCourt.accent)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.appearance")
            HStack(spacing: 12) {
                Text("settings.theme")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(HardCourt.text)
                Spacer(minLength: 8)
                ThemeSegmentedControl(selection: $settings.theme)
                    .frame(maxWidth: 240)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("settings.language")
            VStack(spacing: 0) {
                ForEach(Array(AppLanguage.allCases.enumerated()), id: \.element.id) { index, language in
                    languageRow(language)
                    if index < AppLanguage.allCases.count - 1 {
                        Rectangle()
                            .fill(HardCourt.hairline)
                            .frame(height: 1)
                            .padding(.leading, 14)
                    }
                }
            }
            .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(HardCourt.muted)
            .textCase(settings.language == .english ? .uppercase : nil)
            .tracking(settings.language == .english ? 0.6 : 0)
            .padding(.leading, 4)
    }

    private func languageRow(_ language: AppLanguage) -> some View {
        let selected = settings.language == language
        return Button {
            settings.language = language
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(selected ? HardCourt.accent : Color.clear)
                    .frame(width: 3, height: 22)
                Text(language.displayNameKey)
                    .font(.system(size: 16, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? HardCourt.text : HardCourt.muted)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(HardCourt.accent)
                }
            }
            .padding(.trailing, 14)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ThemeSegmentedControl: View {
    @Binding var selection: ThemePreference

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ThemePreference.allCases) { option in
                let selected = selection == option
                Button {
                    selection = option
                } label: {
                    Text(option.titleKey)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? Color.black : HardCourt.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selected ? HardCourt.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(HardCourt.bg.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(HardCourt.hairline, lineWidth: 1)
        )
    }
}
