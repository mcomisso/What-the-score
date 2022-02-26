//
//  IntervalsList.swift
//  ScoreMatching
//
//  Created by Matteo Comisso on 26/02/22.
//

import Foundation
import SwiftUI

struct IntervalsList: View {

    var viewModel: ViewModel

    var body: some View {
        List {
            ForEach(viewModel.intervals.indices, id: \.self) { intervalIdx in
                VStack(alignment: .center) {
                    Text("Interval \(intervalIdx)")
                        HStack {
                            ForEach(viewModel.intervals[intervalIdx].points.map { $0.count }, id: \.self) { points in
                                Text("\(points)")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                            }
                    }
                }
            }.onDelete { indexSet in
                viewModel.removeInterval(indexSet.first!)
            }

            Section {
                Button("New interval") {
                    viewModel.addInterval()
                }
            }
        }
    }

}

struct Previews_IntervalsList_Previews: PreviewProvider {
    static var previews: some View {
        let vm = ViewModel.init()
        vm.intervals = [.init(id: 0, points: [.init("A"), .init("B")])]
        return IntervalsList(viewModel: vm)
    }
}
