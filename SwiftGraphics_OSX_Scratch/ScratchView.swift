//
//  ScratchView.swift
//  SwiftGraphics
//
//  Created by Jonathan Wight on 1/25/15.
//  Copyright (c) 2015 schwa.io. All rights reserved.
//

import Cocoa

import SwiftGraphics

extension Rectangle: HitTestable {
    public func contains(point:CGPoint) -> Bool {
        return self.frame.contains(point)
    }

    // TODO: Move to "EdgeHitTestable" protocol?
    public func onEdge(point:CGPoint, lineThickness:CGFloat) -> Bool {
        if self.frame.insetted(dx: -lineThickness * 0.5, dy: -lineThickness * 0.5).contains(point) {
            return self.frame.insetted(dx: lineThickness * 0.5, dy: lineThickness * 0.5).contains(point) == false
        }
        return false
    }
}

class ScratchView: NSView {

    typealias Thing = protocol <HitTestable, Drawable>

    var things:[Thing]
    var selectedThings:NSMutableIndexSet = NSMutableIndexSet()

    required init?(coder: NSCoder) {
        things = [
            Rectangle(frame:CGRect(x:0, y:0, width:100, height:100)),
        ]

        super.init(coder:coder)

        self.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: Selector("click:")))

    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        let context = NSGraphicsContext.currentContext()!.CGContext

        for (index, thing) in enumerate(things) {
            if selectedThings.containsIndex(index) {
                context.strokeColor = CGColor.redColor()
            }
            thing.drawInContext(context)
        }
    }

    func click(gestureRecognizer:NSClickGestureRecognizer) {
        let location = gestureRecognizer.locationInView(self)

        for (index, thing) in enumerate(things) {
            if thing.contains(location) {
                println(thing)
                self.selectedThings.addIndex(index)
                self.needsDisplay = true
                return
            }
        }

        self.selectedThings.removeAllIndexes()
        self.needsDisplay = true


    }

}
