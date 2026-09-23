import AppKit
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1024,pixelsHigh:1024,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:rep)
NSColor(calibratedRed:0.13,green:0.23,blue:0.20,alpha:1).setFill()
NSBezierPath(roundedRect:NSRect(x:30,y:30,width:964,height:964),xRadius:215,yRadius:215).fill()
let border=NSBezierPath(roundedRect:NSRect(x:130,y:130,width:764,height:764),xRadius:132,yRadius:132)
NSColor(calibratedRed:0.51,green:0.62,blue:0.41,alpha:1).setStroke();border.lineWidth=4;border.stroke()
let paragraph=NSMutableParagraphStyle();paragraph.alignment = .center
let text=NSAttributedString(string:"r",attributes:[.font:NSFont(name:"Georgia",size:760)!, .foregroundColor:NSColor(calibratedRed:0.84,green:0.90,blue:0.65,alpha:1),.paragraphStyle:paragraph])
text.draw(in:NSRect(x:45,y:54,width:914,height:925))
NSColor(calibratedRed:0.84,green:0.90,blue:0.65,alpha:1).setFill();NSBezierPath(ovalIn:NSRect(x:725,y:232,width:69,height:69)).fill()
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("icon1024.png"))
