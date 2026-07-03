//
//  BucketBrowserView.swift
//  ShareMasterIOS
//
//  Lists the objects in a destination's bucket (under its path prefix).
//  Tap a row for a preview + actions; swipe or context menu for quick
//  copy-link and delete.
//

import SwiftUI

struct BucketBrowserView: View {
    let destination: Destination

    @State private var objects: [S3Object] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedObject: S3Object?
    @State private var copiedKey: String?

    private var config: S3Config? {
        ConfigStore.shared.s3Config(for: destination)
    }

    var body: some View {
        Group {
            if isLoading && objects.isEmpty {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, objects.isEmpty {
                ContentUnavailableView {
                    Label("Couldn't Load", systemImage: "exclamationmark.icloud")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") { Task { await refresh() } }
                }
            } else if objects.isEmpty {
                ContentUnavailableView(
                    "Empty",
                    systemImage: "tray",
                    description: Text("No files in this destination yet.")
                )
            } else {
                objectList
            }
        }
        .navigationTitle(destination.name.isEmpty ? destination.bucket : destination.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .refreshable { await refresh() }
        .sheet(item: $selectedObject) { object in
            ObjectDetailView(object: object, destination: destination) {
                objects.removeAll { $0.key == object.key }
            }
        }
    }

    private var objectList: some View {
        List(objects) { object in
            Button {
                selectedObject = object
            } label: {
                ObjectRow(object: object, copied: copiedKey == object.key)
            }
            .foregroundStyle(.primary)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    Task { await delete(object) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    Task { await copyLink(object) }
                } label: {
                    Label("Copy Link", systemImage: "link")
                }
                .tint(.blue)
            }
            .contextMenu {
                Button {
                    Task { await copyLink(object) }
                } label: {
                    Label("Copy Link", systemImage: "link")
                }
                Button(role: .destructive) {
                    Task { await delete(object) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func refresh() async {
        guard let config else {
            errorMessage = "Destination not configured"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            objects = try await S3Service.shared.listObjects(config: config)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyLink(_ object: S3Object) async {
        guard let config else { return }
        if let link = try? await S3Service.shared.shareLink(for: object.key, config: config) {
            UIPasteboard.general.string = link
            copiedKey = object.key
            try? await Task.sleep(for: .seconds(1.5))
            if copiedKey == object.key { copiedKey = nil }
        }
    }

    private func delete(_ object: S3Object) async {
        guard let config else { return }
        do {
            try await S3Service.shared.deleteObject(key: object.key, config: config)
            objects.removeAll { $0.key == object.key }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ObjectRow: View {
    let object: S3Object
    let copied: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(object.filename)
                    .lineLimit(1)
                Text("\(object.size.formattedFileSize) · \(object.lastModified.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if copied {
                Label("Copied", systemImage: "checkmark.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }

    private var iconName: String {
        switch (object.key as NSString).pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg": "photo"
        case "mp4", "mov", "m4v", "webm": "video"
        case "mp3", "m4a", "wav", "aac": "waveform"
        case "zip", "gz", "tar", "7z", "rar": "doc.zipper"
        case "pdf": "doc.richtext"
        default: "doc"
        }
    }
}

/// Preview sheet: shows the image (when the object is one) and offers
/// copy link / share / delete.
struct ObjectDetailView: View {
    let object: S3Object
    let destination: Destination
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var link: String?
    @State private var copied = false
    @State private var errorMessage: String?

    private var isImage: Bool {
        ["png", "jpg", "jpeg", "gif", "webp", "heic"]
            .contains((object.key as NSString).pathExtension.lowercased())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isImage, let link, let url = URL(string: link) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fit)
                        case .failure:
                            Label("Preview unavailable", systemImage: "eye.slash")
                                .foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }

                VStack(spacing: 4) {
                    Text(object.filename)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                    Text("\(object.size.formattedFileSize) · \(object.lastModified.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                VStack(spacing: 10) {
                    Button {
                        if let link {
                            UIPasteboard.general.string = link
                            copied = true
                        }
                    } label: {
                        Label(copied ? "Link Copied" : "Copy Link",
                              systemImage: copied ? "checkmark" : "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(link == nil)

                    if let link, let url = URL(string: link) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(role: .destructive) {
                        Task { await deleteObject() }
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard let config = ConfigStore.shared.s3Config(for: destination) else { return }
                link = try? await S3Service.shared.shareLink(for: object.key, config: config)
            }
        }
    }

    private func deleteObject() async {
        guard let config = ConfigStore.shared.s3Config(for: destination) else { return }
        do {
            try await S3Service.shared.deleteObject(key: object.key, config: config)
            onDelete()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension Int64 {
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
