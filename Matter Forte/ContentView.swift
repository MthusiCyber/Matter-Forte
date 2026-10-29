import SwiftUI

struct ContentView: View {
    var body: some View {
        // Keep the screen's full layout proposal when the keyboard appears.
        // Pin overflowing content to the top instead of letting SwiftUI recenter it.
        GeometryReader { geometry in
            SignUpView()
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    ContentView()
}
