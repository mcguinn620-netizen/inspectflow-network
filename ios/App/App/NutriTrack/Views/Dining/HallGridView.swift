import SwiftUI
struct HallGridView: View { @EnvironmentObject var store:AppStore; let cols=[GridItem(.flexible()),GridItem(.flexible())]; var body: some View { ScrollView { LazyVGrid(columns: cols){ ForEach(store.halls){ hall in NavigationLink(hall.name){ StationGridView(hall: hall) }.padding().background(.white).cornerRadius(12) } }.padding() } }}
