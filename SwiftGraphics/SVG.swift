//
//  SVG.swift
//  SwiftGraphics
//
//  Created by Jonathan Wight on 8/27/14.
//  Copyright (c) 2014 schwa.io. All rights reserved.
//

import CoreGraphics

// TODO: This is all very WIP. Expect a _lot_ to change.
// Intent here is to break this code into two - parsing SVG in one part.
// The second part is about representing a SVG Document as data - so bezier paths
// And transformation stacks and whatnot.
// This will allow us to deserialise a SVG document _or_ use a more efficient
// (binary) file format for scalable graphics.

// MARK: SVGDocument

public class SVGDocument {
    var bounds : CGRect = CGRectZero
    var commands : [DrawingCommand] = []
}

public enum DrawingCommand {
    case StartGroup
    case EndGroup
    case Path(CGPath)
}

public extension CGContextRef {
    func draw(document:SVGDocument) {
        self.with {
            let transform = CGAffineTransform(sx:1.0, sy:-1.0).translated(tx: 0, ty: -document.bounds.size.height)
            CGContextConcatCTM(self, transform)
            for command in document.commands {
                switch command {
                    case .Path(let bezierPath):
                        CGContextAddPath(self, bezierPath)
                        CGContextFillPath(self)
                        bezierPath.dump()
                    default:
                        false
                }
            }
        }
    }
}

// #############################################################################

public class SVGParser {

    var document = SVGDocument()

    public init() {
    }

    public func parseDocument(XMLDocument:NSXMLDocument) -> SVGDocument {
        document = SVGDocument()
        parseSVGElement(XMLDocument.rootElement()!)
        return document
    }

    func parseElement(element:NSXMLElement) {
        switch element.name! {
            case "svg":
                parseSVGElement(element)
            case "g":
                parseGroupElement(element)
            case "path":
                parsePathElement(element)
            case "circle":
                parseCircleElement(element)
            case "rect":
                parseRectElement(element)
            case "polygon":
                parsePolygonElement(element)
            default:
                println("Cannot handle element \(element)")
        }
    }

    func parseSVGElement(element:NSXMLElement) {
        
        // TODO: So much unwrapping. Gonna make bang happen!
        
        var x = CGFloat(0)
        var y = CGFloat(0) 
        
        if let xElement = element.attributeForName("x") {
            (x, _) = parseDimension(xElement.stringValue!)
            }
        if let yElement = element.attributeForName("y") {
            (y, _) = parseDimension(yElement.stringValue!)
            }
        let (width, _) = parseDimension(element.attributeForName("width")!.stringValue!)
        let (height, _) = parseDimension(element.attributeForName("height")!.stringValue!)
        document.bounds = CGRect(x:x, y:y, width:width, height:height)

        if let children = element.children {
            for node in children {
                if let subelement = node as? NSXMLElement {
                    parseElement(subelement)
                }
            }
        }
    }

    func parseGroupElement(element:NSXMLElement) {
        document.commands.append(.StartGroup)
        if let children = element.children {
            for node in children {
                if let subelement = node as? NSXMLElement {
                    parseElement(subelement)
                }
            }
        }
        document.commands.append(.EndGroup)
    }

    func parsePathElement(element:NSXMLElement) {
        let path = element.attributeForName("d")!.stringValue!
        let atoms = stringToAtoms(path)
        let pathCommands = atomsToPathCommands(atoms)
        let bezierPath = pathCommandsToPath(pathCommands)
        document.commands.append(.Path(bezierPath))
    }

    func parseCircleElement(element:NSXMLElement) {
        let cx = CGFloat(element.attributeForName("cx")!.stringValue!)
        let cy = CGFloat(element.attributeForName("cy")!.stringValue!)
        let r = CGFloat(element.attributeForName("r")!.stringValue!)
        let path = CGPathCreateWithEllipseInRect(CGRect(center:CGPoint(cx,cy), size:CGSize(width:r * 2, height:r * 2)), nil)
        document.commands.append(.Path(path))
    }

    func parseRectElement(element:NSXMLElement) {
        let x = CGFloat(element.attributeForName("x")!.stringValue!)
        let y = CGFloat(element.attributeForName("y")!.stringValue!)
        let width = CGFloat(element.attributeForName("width")!.stringValue!)
        let height = CGFloat(element.attributeForName("height")!.stringValue!)
        let path = CGPathCreateWithRect(CGRect(x:x, y:y, width:width, height:height), nil)
        document.commands.append(.Path(path))
    }

    func parsePolygonElement(element:NSXMLElement) {
        let pointsString = element.attributeForName("points")!.stringValue!

        let scanner = NSScanner(string:pointsString)
        scanner.charactersToBeSkipped = NSCharacterSet(charactersInString:" \n,")

        let path = CGPathCreateMutable()

        if let point = scanner.scanCGPoint() {
            path.move(point)
        }
        else {
            assert(false)
        }

        while scanner.atEnd == false {
            if let point = scanner.scanCGPoint() {
                path.addLine(point)
            }
            else {
                assert(false)
            }
        }

        path.close()
        document.commands.append(.Path(path))
    }
}

// #############################################################################

enum Atom {
    case Command(Character)
    case Number(CGFloat)
    case NOP // TODO: change to NOP?

    var isNumber : Bool {
        get {
            switch self {
                case .Command:
                    return false
                case .Number:
                    return true
                case .NOP:
                    return false
            }
        }
    }

    var value : CGFloat! {
        get {
            switch self {
                case .Command:
                    return nil
                case .Number(let value):
                    return value
                case .NOP:
                    return nil
            }
        }
    }
}

func stringToAtoms(path:String) -> [Atom] {
    var atoms : [Atom] = []
    let scanner = NSScanner(string: path)
    // TODO: Use real whitespace
    scanner.charactersToBeSkipped = NSCharacterSet(charactersInString:" \n,")
    let set = NSCharacterSet(charactersInString:"MmZzLlHhVvCcSsQqTtAa")
    while scanner.atEnd == false {
        var s : NSString?
        if scanner.scanCharactersFromSet(set, intoString:&s) {
            let c = Character(s!)
            atoms.append(.Command(c))
        }
        var d : Double = 0.0
        if scanner.scanDouble(&d) {
            atoms.append(.Number(CGFloat(d)))
            }
        }
    atoms.append(.NOP)
    return atoms
    }

// #############################################################################

enum PathCommand {
    case MoveTo(relative:Bool, xy:CGPoint)
    case ClosePath
    case LineTo(relative:Bool, xy:CGPoint)
    case HorizontalLineTo(relative:Bool, x:CGFloat)
    case VerticalLineTo(relative:Bool, y:CGFloat)
    case BezierCurveTo(relative:Bool, curve:BezierCurve)
// TODO: Shorthand curve forms
//    case ShorthandQuadraticBezierCurveTo
    case EllipticalArc(relative:Bool, rxy:CGPoint, xrotation:CGFloat, largeArcFlag:Bool, sweepFlag:Bool, xy:CGPoint)
}

// #############################################################################

func atomsToPathCommands(atoms:[Atom]) -> [PathCommand] {
    var commands : [PathCommand] = []
    var index = 0
    while index < atoms.count {
        let atom = atoms[index++]
        switch atom {
            case .Command(let c):
                let relative = c.isLowercase
                switch c {
                    case "M", "m":
                        while (atoms[index].isNumber) {
                            let x = atoms[index++].value
                            let y = atoms[index++].value
                            let coord = CGPoint(x:x, y:y)
                            let command = PathCommand.MoveTo(relative:relative, xy:coord)
                            commands.append(command)
                        }
                    case "Z", "z":
                        let command = PathCommand.ClosePath
                        commands.append(command)
                    case "L", "l":
                        while (atoms[index].isNumber) {
                            let x = atoms[index++].value
                            let y = atoms[index++].value
                            let coord = CGPoint(x:x, y:y)
                            let command = PathCommand.LineTo(relative:relative, xy:coord)
                            commands.append(command)
                        }
                    case "H", "h":
                        while (atoms[index].isNumber) {
                            let x = atoms[index++].value
                            let command = PathCommand.HorizontalLineTo(relative:relative, x:x)
                            commands.append(command)
                        }
                    case "V", "v":
                        while (atoms[index].isNumber) {
                            let y = atoms[index++].value
                            let command = PathCommand.VerticalLineTo(relative:relative, y:y)
                            commands.append(command)
                        }
                    case "C", "c":
                        while (atoms[index].isNumber) {
                            let xy1 = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            let xy2 = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            let xy = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            let curve = BezierCurve(control1:xy1, control2:xy2, end:xy)
                            let command = PathCommand.BezierCurveTo(relative:relative, curve:curve)
                            commands.append(command)
                        }
                    case "S", "s":
                        while (atoms[index].isNumber) {
                            let xy1 = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            let xy = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            let curve = BezierCurve(control1:xy1, end:xy)
                            let command = PathCommand.BezierCurveTo(relative:relative, curve:curve)
                            commands.append(command)
                        }
                    case "Q", "q":
                        assert(false)
                    case "T", "T":
                        assert(false)
                    case "A", "a":
                        while (atoms[index].isNumber) {
                            let rxy = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            let xrotation = atoms[index++].value
                            let largeArcFlag = atoms[index++].value
                            let sweepflag = atoms[index++].value
                            let xy = CGPoint(x:atoms[index++].value, y:atoms[index++].value)
                            
                            let command = PathCommand.EllipticalArc(relative:relative, rxy:rxy, xrotation: xrotation, largeArcFlag:largeArcFlag != 0.0, sweepFlag:sweepflag != 0.0, xy:xy)
                            commands.append(command)
                        }
                    default:
                        println("Unhandled command \(c)")
                        assert(false)
                }
            case .Number(let value):
                println("Unprocessed number \(value)")
            case .NOP:
                break // TODO: Continue?
            }
        }
    return commands
    }

func atomsToString(atoms:[Atom]) -> String {
    var result : String = ""
    for atom in atoms {
        switch atom {
            case .Command(let c):
                result += "\(c) "
            case .Number(let d):
                result += "\(d) "
            default:
                break
        }
    }
    return result
}

// #############################################################################

func pathCommandsToAtoms(commands : [PathCommand]) -> [Atom]! {
    var atoms : [Atom] = []
    for command in commands {
        switch command {
            case .MoveTo(let relative, let xy):
                atoms += [
                    .Command(!relative ? "M" : "m"),
                    .Number(xy.x), .Number(xy.y)
                ]
            case .ClosePath:
                atoms += [
                    .Command("Z")
                ]
            case .LineTo(let relative, let xy):
                atoms += [
                    .Command(!relative ? "L" : "l"),
                    .Number(xy.x), .Number(xy.y)
                ]
            case .HorizontalLineTo(let relative, let x):
                atoms += [
                    .Command(!relative ? "H" : "h"),
                    .Number(x)
                ]
            case .VerticalLineTo(let relative, let y):
                atoms += [
                    .Command(!relative ? "V" : "v"),
                    .Number(y)
                ]
            case .BezierCurveTo(let relative, let curve):
                switch curve.order {
                    case .Quadratic:
                        atoms += [
                            .Command(!relative ? "S" : "s"),
                            .Number(curve.controls[0].x), .Number(curve.controls[0].y),
                            .Number(curve.end.x), .Number(curve.end.y),
                        ]
                    case .Cubic:
                        atoms += [
                            .Command(!relative ? "C" : "c"),
                            .Number(curve.controls[0].x), .Number(curve.controls[0].y),
                            .Number(curve.controls[1].x), .Number(curve.controls[1].y),
                            .Number(curve.end.x), .Number(curve.end.y),
                        ]
                    default:
                        return nil
                }
            default:
                println("Nope")
        }
    }
    return atoms
}

func pathCommandsToPath(commands : [PathCommand]) -> CGMutablePath {
    var bezier = CGPathCreateMutable()
    
    for command in commands {
        switch command {
            case .MoveTo(let relative, let xy):
                bezier.move(xy, relative:relative)
            case .ClosePath:
                bezier.close()
            case .LineTo(let relative, let xy):
                bezier.addLine(xy, relative:relative)
            case .HorizontalLineTo(let relative, let x):
                var p = bezier.currentPoint
                if relative {
                    p.x += x
                }
                else {
                    p.x = x
                }
                bezier.addLine(p)
            case .VerticalLineTo(let relative, let y):
                var p = bezier.currentPoint
                if relative {
                    p.y += y
                }
                else {
                    p.y = y
                }
                bezier.addLine(p)
            case .BezierCurveTo(let relative, let curve):
                bezier.addCurve(curve, relative:relative)
            case .EllipticalArc(let relative, let rxy, let xrotation, let largeArcFlag, let sweepFlag, let xy):
                println("Not handled \(command)")
                assert(false)                
            default:
                println("Not handled \(command)")
                assert(false)
        }
    }
    
    return bezier
}
