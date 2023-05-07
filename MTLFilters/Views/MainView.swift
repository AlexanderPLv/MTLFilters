//
//  MainView.swift
//  MTLFilters
//
//  Created by Alexander Pelevinov on 07.05.2023.
//

import SwiftUI

struct MainView: View {
    
    @EnvironmentObject var metalContext: MetalContext
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            MetalView()
                .environmentObject(metalContext)
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
