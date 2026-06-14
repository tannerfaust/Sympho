//
//  ContentView.swift
//  Sympho
//
//  Created by Tanner Fause on 30.05.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var navigationContext = AppNavigationContext()

    var body: some View {
        NavigationShell()
            .environment(navigationContext)
            .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
