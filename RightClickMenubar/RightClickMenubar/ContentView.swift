import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Preferences...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Quit") {
                NSApp.terminate(nil)
            }
        }
        .padding()
    }
}
