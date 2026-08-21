import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct LibraryImportView: View {
    @EnvironmentObject private var store: AppSessionStore
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                CourtBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header
                        importButtons

                        if store.videos.isEmpty {
                            emptyState
                        } else {
                            ForEach(store.videos) { video in
                                videoRow(video)
                            }
                            dropZone
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }

                if isImporting {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView(String(localized: "library.importing"))
                        .padding(20)
                        .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(HardCourt.text)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .settings:
                    SettingsView()
                }
            }
        }
        .alert(
            String(localized: "error.title"),
            isPresented: Binding(
                get: { store.alertMessage != nil },
                set: { if !$0 { store.alertMessage = nil } }
            )
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {
                store.alertMessage = nil
            }
        } message: {
            Text(store.alertMessage ?? "")
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie, .audiovisualContent],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                isImporting = true
                store.importVideo(from: url)
                isImporting = false
            case .failure:
                store.alertMessage = String(localized: "error.decode_failed")
            }
        }
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                isImporting = true
                defer { isImporting = false }
                do {
                    guard let movie = try await newItem.loadTransferable(type: ImportableMovie.self) else {
                        store.alertMessage = String(localized: "error.decode_failed")
                        return
                    }
                    store.importVideo(from: movie.url, displayName: movie.suggestedName)
                } catch {
                    store.alertMessage = String(localized: "error.decode_failed")
                }
                photoItem = nil
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Image("LogoLockup")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 28)
                    .accessibilityLabel("TennisRally")
                Text("library.tagline")
                    .font(.system(size: 15))
                    .foregroundStyle(HardCourt.muted)
            }
            Spacer()
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "icloud.slash")
                        .font(.system(size: 12, weight: .medium))
                    Text("library.works_offline")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(HardCourt.muted)

                NavigationLink(value: LibraryRoute.settings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(HardCourt.muted)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(Text("settings.title"))
            }
            .padding(.top, 2)
        }
    }

    private var importButtons: some View {
        VStack(spacing: 10) {
            PhotosPicker(selection: $photoItem, matching: .videos, photoLibrary: .shared()) {
                Label(String(localized: "library.import_photos"), systemImage: "photo.on.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(HardCourt.bg)
                    .background(HardCourt.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                showFileImporter = true
            } label: {
                Label(String(localized: "library.import_files"), systemImage: "folder")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(HardCourt.accent)
                    .background(HardCourt.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func videoRow(_ video: LibraryVideo) -> some View {
        Button {
            store.activeVideoID = video.id
            switch video.status {
            case .processed:
                store.selectedTab = .rallies
            case .processing:
                store.selectedTab = .process
            case .failed:
                store.alertMessage = video.lastErrorMessage ?? String(localized: "error.decode_failed")
            case .notProcessed:
                if video.localURL != nil {
                    store.prepareProcessing(for: video.id)
                } else {
                    store.selectedTab = .process
                }
            }
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(HardCourt.surface)
                    .frame(width: 72, height: 54)
                    .overlay {
                        Image(systemName: video.status == .failed ? "exclamationmark.triangle" : "camera.viewfinder")
                            .foregroundStyle(video.status == .failed ? HardCourt.danger : HardCourt.accent.opacity(0.8))
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(HardCourt.text)
                    Text("\(video.durationLabel) • \(statusLabel(for: video))")
                        .font(.system(size: 13))
                        .foregroundStyle(HardCourt.muted)
                    if let err = video.lastErrorMessage, video.status == .failed {
                        Text(err)
                            .font(.system(size: 12))
                            .foregroundStyle(HardCourt.danger)
                            .lineLimit(2)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HardCourt.muted)
            }
            .padding(12)
            .background(HardCourt.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statusLabel(for video: LibraryVideo) -> String {
        AppLocalization.text(video.statusLabelKey, locale: settings.language.locale)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 28))
                .foregroundStyle(HardCourt.muted)
            Text("library.drop_hint")
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [7, 6]))
                .foregroundStyle(HardCourt.muted.opacity(0.55))
        )
        .onTapGesture {
            showFileImporter = true
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image("LogoMark")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
            Text("library.empty_title")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HardCourt.text)
            Text("library.empty_body")
                .font(.system(size: 14))
                .foregroundStyle(HardCourt.muted)
                .multilineTextAlignment(.center)
            dropZone
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }
}

/// Transferable wrapper so PhotosPicker can hand us a temporary movie file URL.
struct ImportableMovie: Transferable {
    let url: URL
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PhotoImports", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let name = received.file.lastPathComponent
            let dest = tempDir.appendingPathComponent("\(UUID().uuidString)-\(name)")
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.copyItem(at: received.file, to: dest)
            return ImportableMovie(url: dest, suggestedName: name)
        }
    }
}
