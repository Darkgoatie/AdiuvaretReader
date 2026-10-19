import SwiftUI

struct RootView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No books yet",
                systemImage: "books.vertical",
                description: Text("Books you import stay on this device.")
            )
            .navigationTitle("Library")
        }
        .tint(Color(red: 0.165, green: 0.725, blue: 0.522))
    }
}
