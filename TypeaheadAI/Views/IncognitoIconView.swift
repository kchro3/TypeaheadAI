//
//  IncognitoIconView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/3/23.
//

import SwiftUI

struct IncognitoIconView: View {
    var body: some View {
        ZStack {
            Image(systemName: "clipboard")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .padding(.bottom, 5)

            Image(systemName: "lock.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .padding(.horizontal, 2)
                .padding(.top, 3)
                .background()
        }
    }
}

struct IncognitoIconView_Previews: PreviewProvider {
    static var previews: some View {
        IncognitoIconView()
    }
}
