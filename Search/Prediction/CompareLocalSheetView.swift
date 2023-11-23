//
//  CompareLocalSheetView.swift
//  Search
//
//  Created by Benoît on 22/11/23.
//

import SwiftUI

struct CompareLocalSheetView: View {
    @Binding var sortedImageNames: [String]

    let imagesPerRow: Int = 4
    var imageSize: Double {
        (UIScreen.main.bounds.width) / Double(imagesPerRow)
    }

    var body: some View {
        NavigationStack{
            VStack {
                ScrollView {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(spacing: 0), count: imagesPerRow),
                        spacing: 0
                    ) {
                        ForEach(self.sortedImageNames, id: \.self) {imageName in
                            Image(imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(
                                    width: imageSize,
                                    height: imageSize
                                )
                                .clipped()
                                .accessibilityLabel("Photo taken on \(CompareLocalView.getSimulatedDate(imageName: imageName))")
                        }
                    }
                    .padding(0)
                }
                .accessibilityLabel("Similar Images")
            }
            .navigationTitle("Similar Images")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

//#Preview {
//    CompareLocalSheetView()
//}
