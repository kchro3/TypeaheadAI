//
//  ContentView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @Binding var textFieldContent: String
    
    var body: some View {
        TextField("Type or paste something here...", text: $textFieldContent)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding()
    }
}
