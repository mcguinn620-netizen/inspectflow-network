import SwiftUI
struct TopBarView: View { let title:String; var body: some View { Text(title).font(.title2).foregroundColor(.white).frame(maxWidth:.infinity,alignment:.leading).padding().background(BSUColors.cardinalRed) }}
