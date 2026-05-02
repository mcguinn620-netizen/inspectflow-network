import SwiftUI
struct DiningView: View { @EnvironmentObject var store:AppStore; var body: some View { NavigationStack { Group { if store.isLoading { LoadingStateView() } else if let e=store.errorMessage { ErrorStateView(message:e) } else if store.halls.isEmpty { EmptyStateView(message:"No dining halls available") } else { HallGridView() } }.navigationTitle("Dining") } }}
