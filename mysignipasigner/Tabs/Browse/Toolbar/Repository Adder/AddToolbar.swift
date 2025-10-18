//
//  AddToolbar.swift
//  mysignipasigner
//
//  Created by gliddd4
//

import SwiftUI

struct AddToolbar: ToolbarContent {
    let dismiss: DismissAction
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
    }
}
