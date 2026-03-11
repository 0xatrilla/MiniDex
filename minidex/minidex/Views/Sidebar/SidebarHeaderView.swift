// FILE: SidebarHeaderView.swift
// Purpose: Displays the sidebar app identity header.
// Layer: View Component
// Exports: SidebarHeaderView

import SwiftUI

struct SidebarHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            CodexBrandMark(size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text("MiniDex")
                    .font(AppFont.title3(weight: .medium))
                    .foregroundStyle(CodexBrand.ink)

                Text("Mobile command deck")
                    .font(AppFont.caption())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}

#Preview {
    SidebarHeaderView()
}
