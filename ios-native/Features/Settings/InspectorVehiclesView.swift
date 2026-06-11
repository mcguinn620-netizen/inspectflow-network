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
        guard let userID = SupabaseService.shared.currentUserID else {
            errorMessage = "No signed-in user."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            vehicles = try await SupabaseService.shared.fetchInspectorVehicles(userId: userID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ vehicle: InspectorVehicle) async {
        do {
            try await SupabaseService.shared.archiveInspectorVehicle(id: vehicle.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setDefault(_ vehicle: InspectorVehicle) async {
        guard let userID = SupabaseService.shared.currentUserID else { return }
        do {
            try await SupabaseService.shared.clearDefaultInspectorVehicle(userId: userID)
            try await SupabaseService.shared.setDefaultInspectorVehicle(id: vehicle.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
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

                    if let nickname = vehicle.nickname, !nickname.isEmpty {
                        Text(nickname).foregroundColor(.secondary)
                    }
                    if let plate = vehicle.license_plate, !plate.isEmpty {
                        Text(plate).foregroundColor(.secondary)
                    }
                }
                .swipeActions {
                    Button("Default") {
                        Task { await vm.setDefault(vehicle) }
                    }
                    Button(role: .destructive) {
                        Task { await vm.delete(vehicle) }
                    } label: {
                        Label("Archive", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("My Vehicles")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddInspectorVehicleView {
                Task { await vm.load() }
            }
        }
        .task { await vm.load() }
        .alert(
            "Error",
            isPresented: .constant(vm.errorMessage != nil)
        ) {
            Button("OK") { vm.errorMessage = nil }
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
    @State private var errorMessage: String?

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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(saving)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private func save() async {
        guard let userID = SupabaseService.shared.currentUserID else {
            errorMessage = "No signed-in user."
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await SupabaseService.shared.createInspectorVehicle(
                userId: userID,
                nickname: nickname,
                year: Int(year),
                make: make,
                model: model,
                plate: plate
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
