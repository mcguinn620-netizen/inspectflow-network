import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ProfileViewModel()
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    avatar
                    VStack(alignment: .leading) {
                        Text(viewModel.fullName.isEmpty ? "Add your name" : viewModel.fullName)
                            .font(.headline)
                        Text(viewModel.email).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "camera.fill")
                    }
                }
            }
            Section("Profile") {
                TextField("Full name", text: $viewModel.fullName)
                    .textContentType(.name)
                TextField("Phone", text: $viewModel.phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            Section {
                Button {
                    Task {
                        if case let .signedIn(profile) = appState.authState {
                            await viewModel.save(userId: profile.id)
                        }
                    }
                } label: {
                    HStack {
                        if viewModel.isSaving { ProgressView().padding(.trailing, 6) }
                        Text("Save changes")
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
        .navigationTitle("Profile")
        .task {
            if case let .signedIn(profile) = appState.authState {
                await viewModel.load(userId: profile.id)
            }
        }
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   case let .signedIn(profile) = appState.authState {
                    await viewModel.uploadAvatar(userId: profile.id, data: data)
                }
            }
        }
        .alert("Profile", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .overlay(alignment: .bottom) {
            if let msg = viewModel.statusMessage {
                Text(msg)
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(nanoseconds: 2_500_000_000)
                        viewModel.statusMessage = nil
                    }
            }
        }
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = viewModel.avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Circle().fill(.secondary.opacity(0.2))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            Circle().fill(.secondary.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
        }
    }
}
