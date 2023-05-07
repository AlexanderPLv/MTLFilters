//
//  MTLFiltersApp.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 04.05.2023.
//

import SwiftUI

@main
struct MTLFiltersApp: App {
    
    let context = MetalContext()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(context)
        }
    }
}
