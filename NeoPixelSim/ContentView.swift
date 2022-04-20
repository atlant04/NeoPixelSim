//
//  ContentView.swift
//  NeoPixelSim
//
//  Created by Maksim Tochilkin on 4/17/22.
//

import SwiftUI
import Combine

struct Pixel: View {
    var color: Color
    let x: Int
    let y: Int
    var mapX: Int { x }
    var mapY: Int { 5 - y }
    
    var mappedAddr: Int16 {
        if y % 2 == 0 {
            return Int16(mapY * 32 + mapX)
        } else {
            return Int16((mapY + 1) * 32 - (mapX + 1))
        }
    }
    
    var body: some View {
        ZStack {
            color
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            
            Text("\(mappedAddr)")
                .foregroundColor(Color.black)
        }
        .frame(width: 50, height: 50)
        .position(x: CGFloat(25 + x * 50), y: CGFloat(25 + y * 50))
    }
}

class ColorState: ObservableObject {
    @Published var pixels: [Pixel] = []
    var timer: AnyCancellable?
    
    let width: Int = 32
    let height: Int = 6
    let colors: [Color] = [.red, .green, .blue, .brown, .cyan, .yellow, .orange]
    let parser: MIFParser = MIFParser()
    let controller = NeoPixelController()
    let scomp: SCOMP
    init() {
        
        let url = Bundle.main.url(forResource: "main", withExtension: "mif")!
        let instr = parser.parse(file: url)
        self.scomp = SCOMP(instructions: instr, controller: controller)
        for x in 0 ..< width {
            for y in 0 ..< height {
                pixels.append(Pixel(color: .black, x: x, y: y))
            }
        }
        
        controller.onWrite = { [unowned self] addr, data in
            if let idx = self.pixels.firstIndex(where: {  $0.mappedAddr == addr }) {
                if data == 0 {
                    self.pixels[idx].color = .black
                } else {
                    self.pixels[idx].color = .white
                }
            }
        }
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink(receiveValue: self.fire(date:))
    }
    
    var currentX: Int = 0
    var currentY: Int = 0
    
    func fire(date: Date) {
//        colorData[0][currentX] = colors.randomElement()!
//        currentX += 1
    }
}

struct ContentView: View {
    @StateObject var state = ColorState()
    
    var body: some View {
        ZStack {
            ForEach(0 ..< state.width) { col in
                ForEach(0 ..< state.height) { row in
                    state.pixels[row * state.width + col]
                }
            }
        }
        .frame(width: CGFloat(state.width) * 50, height: CGFloat(state.height) * 50)
        .onAppear {
            state.scomp.run()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
