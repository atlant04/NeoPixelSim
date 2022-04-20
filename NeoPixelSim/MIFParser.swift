//
//  MIFParser.swift
//  NeoPixelSim
//
//  Created by Maksim Tochilkin on 4/17/22.
//

import Foundation

struct Instruction {
    let addr: UInt16
    let data: UInt16
    let asm: String?
}

class MIFParser {

    func parse(file: URL) -> [Instruction] {
        var instructions: [Instruction] = []
        
        let data = FileManager.default.contents(atPath: file.path)!
        let binary = String(data: data, encoding: .utf8)!
        let scanner = Scanner(string: binary)
        
        _ = scanner.scanUpToString("BEGIN")
        let instStart = binary.index(scanner.currentIndex, offsetBy: "BEGIN".count)
        _ = scanner.scanUpToString("END")
        let instEnd = scanner.currentIndex
        
        let instructionText = binary[instStart ..< instEnd]
        let instScanner = Scanner(string: String(instructionText))
        
        while !instScanner.isAtEnd {
            guard let str = instScanner.scanUpToString("\n") else { continue }
            
            let lineScanner = Scanner(string: str)
            lineScanner.charactersToBeSkipped = CharacterSet(charactersIn: " :-;\t")
            var addr: UInt64 = 0x0
            var inst: UInt64 = 0x0
            lineScanner.scanHexInt64(&addr)
            lineScanner.scanHexInt64(&inst)
            var asm = lineScanner.scanUpToString("\n")
            asm = asm?.replacingOccurrences(of: "\t", with: "")
            
            instructions.append(Instruction(addr: UInt16(addr), data: UInt16(inst), asm: asm))
        }
        
        return instructions
    }
}
