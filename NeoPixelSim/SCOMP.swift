//
//  SCASM.swift
//  NeoPixelSim
//
//  Created by Maksim Tochilkin on 4/18/22.
//

import Foundation
import Combine

class NeoPixelController {
    var pixelData: [Int16] = [Int16](repeating: 0, count: 512)
    var pxlAddr: Int16 = 0x0
    
    var queue: [() -> ()] = []
    var timer: AnyPublisher = Timer.publish(every: 0.05, on: .main, in: .default)
        .autoconnect()
        .eraseToAnyPublisher()
    var timerCancellable: AnyCancellable?
    
    init() {
        timerCancellable = timer.sink { [unowned self] date in
            guard self.queue.first != nil else { return }
            let action = self.queue.removeFirst()
            action()
        }
    }
    
    func out(addr: UInt16, data: Int16) {
        if addr == 0xb0 {
            pxlAddr = data
        } else if addr == 0xb1 {
            if data == 0 {
                print("here")
            }
            pixelData[Int(pxlAddr)] = data
            let pxlAddrCopy = self.pxlAddr
            queue.append { [unowned self] in
                if (data == 0) {
                    print("here")
                }
                self.onWrite(UInt16(pxlAddrCopy), data)
            }
        }
    }
    
    func `in`(addr: UInt16) -> Int16 {
        let addr = Int(pxlAddr)
        if pxlAddr == 0 {
            print("stop")
        }
        if addr < 0 { return 0 }
        return pixelData[Int(pxlAddr)]
    }
    
    var onWrite: (UInt16, Int16) -> Void = {_, _ in }
}

enum OpCode: UInt16 {
    case nop = 0b00000
    case load = 0b00001
    case store = 0b00010
    case add = 0b00011
    case sub = 0b00100
    case jump = 0b00101
    case jneg = 0b00110
    case jpos = 0b00111
    case jzero = 0b01000
    case and = 0b01001
    case or = 0b01010
    case xor = 0b01011
    case shift = 0b01100
    case addi = 0b01101
    case iload = 0b01110
    case istore = 0b01111
    case call = 0b10000
    case `return` = 0b10001
    case `in` = 0b10010
    case out = 0b10011
    case loadi = 0b10111
    
    
}

class SCOMP {
    let instructions: [Instruction]
    
    let controller: NeoPixelController
    
    init(instructions: [Instruction], controller: NeoPixelController) {
        self.instructions = instructions
        self.controller = controller
        
        spAddr = instructions.first {
            if let asm = $0.asm {
                return asm.contains("SP:")
            }
            return false
        }?.addr ?? 0x0
        
        bpAddr = instructions.first {
            if let asm = $0.asm {
                return asm.contains("BP:")
            }
            return false
        }?.addr ?? 0x0
        
        for instruction in instructions {
            mem[Int(instruction.addr)] = instruction.data
        }
        
    }
    
    var sp: Int16 = 0x0
    var bp: Int16 = 0x0
    let spAddr: UInt16
    let bpAddr: UInt16
    
    var mem: [UInt16] = [UInt16](repeating: 0, count: 0x4000)
    var ac: Int16 = 0x0
    var pc: UInt16 = 0x0
    var callstack: [UInt16] = []
    var isHalted: Bool = false
    
    func run() {
        var ticks = 0
        while !isHalted {
            let instr = mem[Int(pc)]
//            print(pc.hex)
            pc += 1
            exec(data: instr)
            
            let opcode = OpCode(rawValue: instr >> 11)
            
            ticks += 1
            if ticks > 1200000 { break }
            
//            for i in 0x2f0 ... 0x2ff {
//                print("\(String(i, radix: 16)): \(String(mem[i], radix: 16))")
//            }
//            print("-------------")
        }
        
//        for (i, mem) in mem.enumerated() {
//            print("\(String(i, radix: 16)): \(String(mem, radix: 16))")
//        }
    
    }
    
    func halt() {
        isHalted = true
    }
    
    func resume() {
        isHalted = false
        run()
    }
    
    func exec(data: UInt16) {
        let opcode = OpCode(rawValue: data >> 11)
//        print("data: \(data.bin)")
        let operand = data & 0x7ff
        let extended: Int16 = (Int16(operand) << 5) >> 5;
//        print("operand: \(operand.bin)")
//        operand = operand >> (64 - 11)
//        print("operand2: \(operand.bin)")
        
        let index = Int(operand)
        
        switch opcode {
        case .nop:
            return
        case .load:
            ac = mem[index].signed
        case .store:
            if let lastInstr = instructions.last,
               lastInstr.addr + 1 == index {
                fatalError("STACK OVERFLOW")
            }
            let instr = instructions[index + 1]
            if let asm = instr.asm, !asm.contains("DW") {
                fatalError("writing to code")
            }
            if operand == self.spAddr {
                self.sp = ac
            }
            if operand == self.bpAddr {
                self.bp = ac
            }
            mem[index] = UInt16(bitPattern: ac)
        case .add:
            ac += mem[index].signed
        case .sub:
            ac -= mem[index].signed
        case .jump:
            pc = operand
        case .jneg:
            if ac < 0 { pc = operand }
        case .jpos:
            if ac > 0 { pc = operand }
        case .jzero:
            if ac == 0 { pc = operand }
        case .and:
            ac = ac & mem[index].signed
        case .or:
            ac = ac | mem[index].signed
        case .xor:
            ac = ac ^ mem[index].signed
        case .shift:
            if operand > 0 { ac = ac << operand }
            else { ac = ac >> operand }
        case .addi:
            ac += extended
        case .iload:
            ac = mem[Int(mem[index])].signed
        case .istore:
            mem[Int(mem[index])] = UInt16(bitPattern: ac)
        case .call:
            callstack.append(pc)
            pc = operand
        case .return:
            pc = callstack.popLast() ?? 0x0
        case .in:
            ac = controller.in(addr: operand)
        case .out:
//            let acCopy = ac
//            let operandCopy = operand
//            DispatchQueue.global().asyncAfter(deadline: .now() + 1) { [unowned self] in
//                sleep(1)
//                DispatchQueue.main.async {
//                    self.controller.out(addr: operandCopy, data: acCopy)
//                }
//            }
            self.controller.out(addr: operand, data: ac)
            if (ac == 125 && operand == 0xb0) {
                print("here")
            }
            switch operand {
            case 0xb0:
                print("out PXL_A: \(ac)")
            case 0xb1:
            return
//                print("out PXL_D: \(UInt16(bitPattern: ac).bin)")
            default:
                print("out \(ac)")
            }
            return
        case .loadi:
            ac = extended
        case .none:
            return
        }
    }
}

extension BinaryInteger {
    var hex: String {
        return String(self, radix: 16)
    }
    
    var bin: String {
        return String(self, radix: 2)
    }
}

extension UInt16 {
    var signed: Int16 {
        return Int16(bitPattern: self)
    }
}
