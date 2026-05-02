import SwiftUI
struct ErrorStateView: View { let message:String; var body: some View { VStack{ Image(systemName:"exclamationmark.triangle"); Text(message) } } }
