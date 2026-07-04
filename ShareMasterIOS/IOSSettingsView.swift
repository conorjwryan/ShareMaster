//
//  IOSSettingsView.swift
//  ShareMasterIOS
//
//  Accounts & Destinations editors, mirroring the macOS settings but as
//  iOS-native forms. Secrets go to the shared keychain; everything else to
//  the App Group defaults, so the share extension picks changes up
//  immediately.
//

import SwiftUI

struct IOSSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var config = ConfigStore.shared

    @State private var editingAccount: Account?
    @State private var addingAccount = false
    @State private var duplicatingAccount: Account?
    @State private var editingDestination: Destination?
    @State private var addingDestination = false
    @State private var duplicatingDestination: Destination?

    var body: some View {
        @Bindable var config = config
        NavigationStack {
            List {
                Section {
                    Toggle("Upload on Mobile Data", isOn: $config.allowsCellularUploads)
                    Toggle("Skip Mobile Data Warnings", isOn: $config.suppressCellularWarnings)
                        .disabled(!config.allowsCellularUploads)
                    Toggle("iCloud Sync", isOn: $config.iCloudSyncEnabled)
                } header: {
                    Text("Sync")
                } footer: {
                    Text("With Mobile Data off, files upload only over Wi-Fi — browsing and copying links work anywhere. With it on, you'll see how much data an upload will use before it starts, unless warnings are skipped. iCloud Sync shares your accounts and destinations between devices through iCloud Keychain.")
                }

                // Both sections filter through the wordmark reveal: with it
                // off, hidden destinations and their dedicated accounts are
                // absent here too, so Settings looks like an ordinary setup.
                Section("Accounts") {
                    ForEach(config.visibleAccounts) { account in
                        Button {
                            editingAccount = account
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(account.name.isEmpty ? "Untitled" : account.name)
                                    .foregroundStyle(.primary)
                                Text(account.endpoint.isEmpty ? "AWS S3 · \(account.region)" : account.endpoint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                _ = config.deleteAccount(id: account.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(!config.destinationsUsing(accountId: account.id).isEmpty)
                        }
                        .contextMenu {
                            Button {
                                duplicatingAccount = account
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                        }
                    }
                    Button {
                        addingAccount = true
                    } label: {
                        Label("Add Account", systemImage: "plus")
                    }
                }

                Section("Destinations") {
                    ForEach(config.visibleDestinations) { destination in
                        Button {
                            editingDestination = destination
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(destination.name.isEmpty ? "Untitled" : destination.name)
                                        .foregroundStyle(.primary)
                                    Text(destination.bucket + (destination.pathPrefix.isEmpty ? "" : "/\(destination.pathPrefix)"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if destination.isHidden {
                                    Spacer()
                                    Image(systemName: "eye.slash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                config.deleteDestination(id: destination.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            Button {
                                duplicatingDestination = destination
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }
                        }
                    }
                    Button {
                        addingDestination = true
                    } label: {
                        Label("Add Destination", systemImage: "plus")
                    }
                    .disabled(config.visibleAccounts.isEmpty)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $addingAccount) {
                AccountEditorView(account: nil)
            }
            .sheet(item: $editingAccount) { account in
                AccountEditorView(account: account)
            }
            .sheet(item: $duplicatingAccount) { account in
                AccountEditorView(duplicating: account)
            }
            .sheet(isPresented: $addingDestination) {
                DestinationEditorView(destination: nil)
            }
            .sheet(item: $editingDestination) { destination in
                DestinationEditorView(destination: destination)
            }
            .sheet(item: $duplicatingDestination) { destination in
                DestinationEditorView(duplicating: destination)
            }
        }
    }
}

// MARK: - Account editor

struct AccountEditorView: View {
    let account: Account?   // nil = create

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Account
    @State private var accessKeyId: String
    @State private var secret: String
    private let isNew: Bool

    init(account: Account?) {
        self.account = account
        let existing = account ?? Account()
        _draft = State(initialValue: existing)
        isNew = account == nil
        if let account {
            _accessKeyId = State(initialValue: ConfigStore.shared.accessKeyId(for: account.id))
            _secret = State(initialValue: ConfigStore.shared.secret(for: account.id))
        } else {
            _accessKeyId = State(initialValue: "")
            _secret = State(initialValue: "")
        }
    }

    /// Duplicate flow: a fresh draft copied from `source` with the
    /// credentials pre-filled; nothing is stored until Save.
    init(duplicating source: Account) {
        account = nil
        isNew = true
        _draft = State(initialValue: ConfigStore.shared.duplicateDraft(of: source))
        _accessKeyId = State(initialValue: ConfigStore.shared.accessKeyId(for: source.id))
        _secret = State(initialValue: ConfigStore.shared.secret(for: source.id))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Name", text: $draft.name)
                    TextField("Region (e.g. us-east-1)", text: $draft.region)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Endpoint (empty for AWS)", text: $draft.endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section {
                    TextField("Access Key ID", text: $accessKeyId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Secret Access Key", text: $secret)
                } header: {
                    Text("Credentials")
                } footer: {
                    Text("Stored in the keychain and shared with the share extension.")
                }
            }
            .navigationTitle(isNew ? "New Account" : "Edit Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ConfigStore.shared.upsertAccount(
                            draft,
                            accessKeyId: accessKeyId.isEmpty ? nil : accessKeyId,
                            secret: secret.isEmpty ? nil : secret
                        )
                        dismiss()
                    }
                    .disabled(draft.name.isEmpty || (isNew && (accessKeyId.isEmpty || secret.isEmpty)))
                }
            }
        }
    }
}

// MARK: - Destination editor

struct DestinationEditorView: View {
    let destination: Destination?   // nil = create

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Destination
    private let isNew: Bool

    init(destination: Destination?) {
        self.destination = destination
        isNew = destination == nil
        let fallbackAccount = ConfigStore.shared.visibleAccounts.first?.id ?? UUID()
        _draft = State(initialValue: destination ?? Destination(accountId: fallbackAccount))
    }

    /// Duplicate flow: a fresh draft copied from `source`; nothing is stored
    /// until Save.
    init(duplicating source: Destination) {
        destination = nil
        isNew = true
        _draft = State(initialValue: ConfigStore.shared.duplicateDraft(of: source))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Destination") {
                    TextField("Name", text: $draft.name)
                    Picker("Account", selection: $draft.accountId) {
                        ForEach(ConfigStore.shared.visibleAccounts) { account in
                            Text(account.name.isEmpty ? "Untitled" : account.name).tag(account.id)
                        }
                    }
                    TextField("Bucket", text: $draft.bucket)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Path prefix (optional)", text: $draft.pathPrefix)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    TextField("Naming template", text: $draft.namingTemplate)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Naming")
                } footer: {
                    Text("Preview: \(NamingTemplate.preview(draft.namingTemplate))\nTokens: \(NamingTemplate.allTokens.joined(separator: " "))")
                }

                Section {
                    Toggle("Hide from main list", isOn: $draft.isHidden)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Hidden destinations disappear from the main list and from Settings. Tap the ShareMaster word mark on the main screen to reveal them everywhere.")
                }

                Section("Link") {
                    Picker("Link type", selection: $draft.linkMode) {
                        Text("Public URL").tag(LinkMode.publicUrl)
                        Text("Presigned").tag(LinkMode.presigned)
                    }
                    if draft.linkMode == .publicUrl {
                        TextField("Public URL base (optional)", text: $draft.publicUrlBase)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                        Toggle("Make uploads public", isOn: $draft.makePublic)
                    } else {
                        Picker("Expires after", selection: $draft.presignExpirySeconds) {
                            Text("1 hour").tag(3_600)
                            Text("1 day").tag(86_400)
                            Text("1 week").tag(604_800)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Destination" : "Edit Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ConfigStore.shared.upsertDestination(draft)
                        dismiss()
                    }
                    .disabled(draft.name.isEmpty || draft.bucket.isEmpty)
                }
            }
        }
    }
}
