//
//  UploadMenu.swift
//  ShareMasterIOS
//
//  Toolbar "+" menu for uploading from within the app: pick photos/videos
//  from the library or any file from Files, then upload to a destination.
//  When used inside the bucket browser the destination is fixed; from the
//  root list a destination picker is shown first (same flow as the share
//  extension). Links are copied to the clipboard on completion.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct UploadMenu: View {
    /// Upload straight to this destination when set; otherwise ask.
    var destination: Destination? = nil
    /// Called after a successful upload (e.g. to refresh the object list).
    var onUploaded: () -> Void = {}

    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var uploadRequest: UploadRequest?

    var body: some View {
        Menu {
            Button {
                showPhotosPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            Button {
                showFileImporter = true
            } label: {
                Label("Choose Files", systemImage: "folder")
            }
        } label: {
            Image(systemName: "plus")
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photoSelection)
        .onChange(of: photoSelection) { _, items in
            guard !items.isEmpty else { return }
            photoSelection = []
            Task {
                var urls: [URL] = []
                for item in items {
                    if let file = try? await item.loadTransferable(type: PickedFile.self) {
                        urls.append(file.url)
                    }
                }
                if !urls.isEmpty { uploadRequest = UploadRequest(files: urls) }
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard let urls = try? result.get() else { return }
            let copied = urls.compactMap(Self.copyToTemp)
            if !copied.isEmpty { uploadRequest = UploadRequest(files: copied) }
        }
        .sheet(item: $uploadRequest) { request in
            AppUploadView(
                files: request.files,
                fixedDestination: destination,
                onUploaded: onUploaded
            )
        }
    }

    /// fileImporter URLs are security-scoped and short-lived — copy them out.
    private static func copyToTemp(_ url: URL) -> URL? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            return try PickedFile.tempCopy(of: url)
        } catch {
            return nil
        }
    }
}

private struct UploadRequest: Identifiable {
    let id = UUID()
    let files: [URL]
}

/// Imports a PhotosPicker item as a real file, keeping its original filename.
private struct PickedFile: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .item) { received in
            PickedFile(url: try tempCopy(of: received.file))
        }
    }

    /// Copies into a unique per-pick temp directory so identically-named
    /// files don't clash (mirrors the share extension's AttachmentLoader).
    static func tempCopy(of url: URL) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        try FileManager.default.copyItem(at: url, to: dest)
        return dest
    }
}

/// The upload sheet: destination picker (when not fixed) → progress →
/// links-copied confirmation. Mirrors the share extension's flow.
struct AppUploadView: View {
    let files: [URL]
    let fixedDestination: Destination?
    var onUploaded: () -> Void = {}

    private enum Phase {
        case pickingDestination
        case uploading(destination: String)
        case done(linkCount: Int)
        case failed(String)
    }

    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .pickingDestination
    @State private var progress: Double = 0
    private let config = ConfigStore.shared

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Upload")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if case .pickingDestination = phase {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
                }
        }
        .interactiveDismissDisabled(isUploading)
        .onAppear {
            if let fixedDestination { upload(to: fixedDestination) }
        }
    }

    private var isUploading: Bool {
        if case .uploading = phase { return true }
        return false
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .pickingDestination:
            destinationPicker
        case .uploading(let destination):
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 32)
                Text("Uploading to \(destination)…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .done(let linkCount):
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text(linkCount == 1 ? "Link copied" : "\(linkCount) links copied")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ContentUnavailableView {
                Label("Upload Failed", systemImage: "exclamationmark.icloud")
            } description: {
                Text(message)
            } actions: {
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var destinationPicker: some View {
        List {
            Section(files.count == 1 ? "Upload 1 file to" : "Upload \(files.count) files to") {
                ForEach(config.sortedDestinations) { destination in
                    Button {
                        upload(to: destination)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "externaldrive.badge.icloud")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(destination.name.isEmpty ? destination.bucket : destination.name)
                                    .foregroundStyle(.primary)
                                Text(destination.bucket)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if destination.id == config.lastSelectedDestinationID {
                                Text("Last used")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func upload(to destination: Destination) {
        guard let s3Config = config.s3Config(for: destination) else {
            phase = .failed("This destination's account is missing its credentials.")
            return
        }
        config.lastSelectedDestinationID = destination.id
        phase = .uploading(destination: destination.name.isEmpty ? destination.bucket : destination.name)

        Task {
            do {
                var links: [String] = []
                for (index, file) in files.enumerated() {
                    let result = try await S3Service.shared.upload(fileURL: file, config: s3Config) { fileProgress in
                        Task { @MainActor in
                            progress = (Double(index) + fileProgress) / Double(files.count)
                        }
                    }
                    links.append(result.url)
                }

                UIPasteboard.general.string = links.joined(separator: "\n")
                phase = .done(linkCount: links.count)
                onUploaded()
                try? await Task.sleep(for: .seconds(1.2))
                dismiss()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
