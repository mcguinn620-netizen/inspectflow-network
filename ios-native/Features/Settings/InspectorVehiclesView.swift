//
//  InspectorVehiclesView.swift
//  AutoInspectorNetwork
//
//  Created by Matt McGuinn on 6/11/26.
//

import SwiftUI
import Foundation

// MARK: - Model

struct InspectorVehicle: Identifiable, Codable, Hashable {
    let id: UUID
    let user_id: UUID

    var nickname: String?
    var year: Int?
    var make: String?
    var model: String?
    var license_plate: String?

    var is_default: Bool
    var is_archived: Bool

    let created_at: String?
}

// MARK: - ViewModel

@MainActor
final class InspectorVehiclesViewModel: ObservableObject {

    @Published var vehicles: [InspectorVehicle] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true

        defer {
            isLoading = false
        }

        do {
            let userID = try await currentUserID()

            let response: [InspectorVehicle] =
                try await SupabaseService.shared.client
                    .db
                    .from("inspector_vehicles")
                    .select()
                    .eq("user_id", value: userID.uuidString)
                    .eq("is_archived", value: false)
                    .order("is_default", ascending: false)
                    .execute()
                    .value

            vehicles = response

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ vehicle: InspectorVehicle) async {

        do {
            try await SupabaseService.shared.client
                .db
                .from("inspector_vehicles")
                .update([
                    "is_archived": true
                ])
                .eq("id", value: vehicle.id.uuidString)
                .execute()

            await load()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefault(_ vehicle: InspectorVehicle) async {

        do {

            let userID = try await currentUserID()

            try await SupabaseService.shared.client
                .db
                .from("inspector_vehicles")
                .update([
                    "is_default": false
                ])
                .eq("user_id", value: userID.uuidString)
                .execute()

            try await SupabaseService.shared.client
                .db
                .from("inspector_vehicles")
                .update([
                    "is_default": true
                ])
                .eq("id", value: vehicle.id.uuidString)
                .execute()

            await load()

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func currentUserID() async throws -> UUID {

        let session = try await SupabaseService.shared.client.auth.session

        return session.user.id
    }
}

// MARK: - View

struct InspectorVehiclesView: View {

    @StateObject private var vm = InspectorVehiclesViewModel()

    @State private var showingAdd = false

    var body: some View {

        List {

            ForEach(vm.vehicles) { vehicle in

                VStack(alignment: .leading, spacing: 6) {

                    HStack {

                        Text(
                            [
                                vehicle.year.map(String.init),
                                vehicle.make,
                                vehicle.model
                            ]
                            .compactMap { $0 }
                            .joined(separator: " ")
                        )
                        .font(.headline)

                        Spacer()

                        if vehicle.is_default {
                            Text("Default")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.green.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    if let nickname = vehicle.nickname,
                       !nickname.isEmpty {

                        Text(nickname)
                            .foregroundColor(.secondary)
                    }

                    if let plate = vehicle.license_plate,
                       !plate.isEmpty {

                        Text(plate)
                            .foregroundColor(.secondary)
                    }
                }
                .swipeActions {

                    Button("Default") {

                        Task {
                            await vm.setDefault(vehicle)
                        }
                    }

                    Button(role: .destructive) {

                        Task {
                            await vm.delete(vehicle)
                        }

                    } label: {
                        Label("Archive", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("My Vehicles")
        .toolbar {

            ToolbarItem(placement: .navigationBarTrailing) {

                Button {

                    showingAdd = true

                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {

            AddInspectorVehicleView {
                Task {
                    await vm.load()
                }
            }
        }
        .task {
            await vm.load()
        }
        .alert(
            "Error",
            isPresented: .constant(vm.errorMessage != nil)
        ) {

            Button("OK") {
                vm.errorMessage = nil
            }

        } message: {

            Text(vm.errorMessage ?? "")
        }
    }
}

// MARK: - Add Vehicle

struct AddInspectorVehicleView: View {

    @Environment(\.dismiss) private var dismiss

    let onSaved: () -> Void

    @State private var nickname = ""
    @State private var year = ""
    @State private var make = ""
    @State private var model = ""
    @State private var plate = ""

    @State private var saving = false

    var body: some View {

        NavigationStack {

            Form {

                TextField("Nickname", text: $nickname)
                TextField("Year", text: $year)
                TextField("Make", text: $make)
                TextField("Model", text: $model)
                TextField("License Plate", text: $plate)
            }
            .navigationTitle("Add Vehicle")
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Save") {

                        Task {
                            await save()
                        }
                    }
                    .disabled(saving)
                }
            }
        }
    }

    private func save() async {

        saving = true

        defer {
            saving = false
        }

        do {

            let session =
                try await SupabaseService.shared.client.auth.session

            try await SupabaseService.shared.client
                .db
                .from("inspector_vehicles")
                .insert([
                    [
                        "user_id": session.user.id.uuidString,
                        "nickname": nickname,
                        "year": Int(year) as Any,
                        "make": make,
                        "model": model,
                        "license_plate": plate,
                        "is_default": false,
                        "is_archived": false
                    ]
                ])
                .execute()

            onSaved()
            dismiss()

        } catch {
            print(error)
        }
    }
}
