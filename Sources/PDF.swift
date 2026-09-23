import Foundation
import AppKit
import CoreText
import PDFKit

final class PDFWriter {
    let ctx:CGContext
    var y:CGFloat=36
    var page=0
    let ink=NSColor(calibratedRed:0.14,green:0.20,blue:0.25,alpha:1)
    let teal=NSColor(calibratedRed:0.07,green:0.40,blue:0.50,alpha:1)
    let muted=NSColor(calibratedRed:0.34,green:0.40,blue:0.45,alpha:1)
    let width:CGFloat=532
    let person:String
    init(url:URL,name:String,title:String) throws {
        var box=CGRect(x:0,y:0,width:612,height:792)
        guard let consumer=CGDataConsumer(url:url as CFURL), let ctx=CGContext(consumer:consumer, mediaBox:&box, [kCGPDFContextTitle as String:title,kCGPDFContextAuthor as String:name] as CFDictionary) else { throw RCError("Could not create the PDF.") }
        self.ctx=ctx; self.person=name
    }
    func attributed(_ s:String,size:CGFloat,bold:Bool=false,color:NSColor?=nil)->NSAttributedString {
        let para=NSMutableParagraphStyle(); para.lineSpacing=1.7
        let font=NSFont(name:bold ? "Arial-BoldMT":"ArialMT",size:size) ?? (bold ? NSFont.boldSystemFont(ofSize:size):NSFont.systemFont(ofSize:size))
        return NSAttributedString(string:s,attributes:[.font:font,.foregroundColor:color ?? ink,.paragraphStyle:para])
    }
    func height(_ s:String,width:CGFloat,size:CGFloat,bold:Bool=false)->CGFloat {
        let setter=CTFramesetterCreateWithAttributedString(attributed(s,size:size,bold:bold))
        return ceil(CTFramesetterSuggestFrameSizeWithConstraints(setter,CFRange(location:0,length:0),nil,CGSize(width:width,height:10000),nil).height)+1
    }
    @discardableResult func draw(_ s:String,x:CGFloat=40,top:CGFloat,width:CGFloat=532,size:CGFloat=10,bold:Bool=false,color:NSColor?=nil)->CGFloat {
        let attr=attributed(s,size:size,bold:bold,color:color)
        let setter=CTFramesetterCreateWithAttributedString(attr)
        let h=height(s,width:width,size:size,bold:bold)
        let path=CGPath(rect:CGRect(x:x,y:792-top-h,width:width,height:h+1),transform:nil)
        let frame=CTFramesetterCreateFrame(setter,CFRange(location:0,length:attr.length),path,nil)
        ctx.saveGState();ctx.textMatrix = .identity;CTFrameDraw(frame,ctx);ctx.restoreGState();return h
    }
    func footer() {
        draw(person,x:40,top:758,width:490,size:7.4,color:muted)
        draw("\(page)",x:559,top:758,width:20,size:7.4,color:muted)
    }
    func newPage() { if page>0 { footer();ctx.endPDFPage() };ctx.beginPDFPage(nil); page+=1;y=36 }
    func ensure(_ h:CGFloat) { if y+h>742 { newPage(); y += draw(person+" | Continued",top:y,size:10,bold:true,color:muted)+12 } }
    func paragraph(_ s:String,size:CGFloat=10,bold:Bool=false,gap:CGFloat=3,x:CGFloat=40,width:CGFloat=532,color:NSColor?=nil) {
        let h=height(s,width:width,size:size,bold:bold)
        if h>680 {
            for part in s.components(separatedBy:"\n") { if part.count>1500 { for start in stride(from:0,to:part.count,by:1000) { let a=part.index(part.startIndex,offsetBy:start);let b=part.index(a,offsetBy:min(1000,part.count-start));paragraph(String(part[a..<b]),size:size,bold:bold,gap:gap,x:x,width:width,color:color) } } else { paragraph(part,size:size,bold:bold,gap:gap,x:x,width:width,color:color) } }; return
        }
        ensure(h+gap);y += draw(s,x:x,top:y,width:width,size:size,bold:bold,color:color)+gap
    }
    func section(_ title:String) { ensure(50);y+=5;ctx.setStrokeColor(NSColor(calibratedWhite:0.80,alpha:1).cgColor);ctx.setLineWidth(0.5);ctx.move(to:CGPoint(x:40,y:792-y));ctx.addLine(to:CGPoint(x:572,y:792-y));ctx.strokePath();y+=6;paragraph(title.uppercased(),size:9.2,bold:true,gap:4,color:teal) }
    func image(_ file:URL,crop:[Double]?,x:CGFloat,top:CGFloat,w:CGFloat,h:CGFloat) {
        guard let src=CGImageSourceCreateWithURL(file as CFURL,nil), let cg=CGImageSourceCreateImageAtIndex(src,0,nil) else { return }
        let image:CGImage
        if let a=crop,a.count==4,let sub=cg.cropping(to:CGRect(x:a[0],y:a[1],width:a[2]-a[0],height:a[3]-a[1])) { image=sub } else { image=cg }
        let scale=min(w/CGFloat(image.width),h/CGFloat(image.height))
        let iw=CGFloat(image.width)*scale,ih=CGFloat(image.height)*scale
        ctx.draw(image,in:CGRect(x:x+(w-iw)/2,y:792-top-h+(h-ih)/2,width:iw,height:ih))
        ctx.setStrokeColor(NSColor(calibratedWhite:0.8,alpha:1).cgColor);ctx.setLineWidth(0.4);ctx.stroke(CGRect(x:x,y:792-top-h,width:w,height:h))
    }
    func finish() { footer();ctx.endPDFPage();ctx.closePDF() }
}

func renderResume(profile:Obj,portfolio:[Obj],resources:URL,url:URL) throws -> Int {
    guard !profile.string("name").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw RCError("Add your name before exporting.") }
    let p=try PDFWriter(url:url,name:profile.string("name"),title:profile.string("name")+" - Resume")
    p.newPage()
    p.paragraph(profile.string("name"),size:25,bold:true,gap:3)
    p.paragraph(profile.string("headline"),size:10.1,bold:true,gap:4,color:p.teal)
    p.paragraph(profile.string("contact"),size:8.5,gap:2,color:p.muted)
    if !profile.string("summary").isEmpty { p.section("Profile");p.paragraph(profile.string("summary"),size:9.7,gap:1) }
    if !profile.objects("experience").isEmpty { p.section("Experience") }
    for job in profile.objects("experience") {
        let heading=job.string("title")+(job.string("company").isEmpty ? "":" | "+job.string("company"))
        p.ensure(p.height(heading,width:532,size:10,bold:true)+40)
        p.paragraph(heading,size:10,bold:true,gap:1)
        if !job.string("dates").isEmpty { p.paragraph(job.string("dates"),size:8.1,gap:3,color:p.muted) }
        for b in job.objects("bullets") where !b.string("text").isEmpty { p.paragraph("• "+b.string("text"),size:9.6,gap:2,x:44,width:528) }
        p.y += 3
    }
    if !profile.objects("projects").isEmpty { p.section("Selected Projects") }
    for project in profile.objects("projects") {
        p.paragraph(project.string("title")+" - "+project.string("text"),size:9.5,gap:4)
    }
    if !profile.strings("skills").isEmpty { p.section("Technical Skills"); for s in profile.strings("skills") { p.paragraph(s,size:9.3,gap:1) } }
    if !profile.strings("education").isEmpty { p.section("Education");for s in profile.strings("education") { p.paragraph(s,size:9.3,gap:1) } }
    let resumePages=p.page
    if !portfolio.isEmpty {
        p.newPage();p.paragraph(profile.string("name"),size:25,bold:true,gap:4);p.paragraph("SELECTED PROJECT PORTFOLIO",size:10.2,bold:true,gap:7,color:p.teal)
        p.paragraph("Machine learning, applied AI and software engineering",size:8.8,gap:18,color:p.muted)
        for project in portfolio.prefix(5) {
            p.ensure(120);let top=p.y
            if project.flag("physics") {
                p.image(resources.appendingPathComponent("shots/circle-full.png"),crop:[323,175,679,459],x:40,top:top+3,w:77,h:83)
                p.image(resources.appendingPathComponent("shots/atoms-full.png"),crop:[273,150,729,745],x:121,top:top+3,w:77,h:83)
                p.draw("CIRCLE",x:40,top:top+91,width:77,size:7,color:p.muted);p.draw("ATOMS",x:121,top:top+91,width:77,size:7,color:p.muted)
            } else {
                p.image(resources.appendingPathComponent("shots/"+project.string("image")),crop:project["crop"] as? [Double],x:40,top:top+3,w:158,h:85)
                p.draw(project.string("caption"),x:40,top:top+92,width:158,size:7,color:p.muted)
            }
            var t=top
            t += p.draw(project.string("title"),x:216,top:t,width:356,size:10.6,bold:true)+3
            t += p.draw(project.string("category"),x:216,top:t,width:356,size:7.1,bold:true,color:p.teal)+6
            t += p.draw(project.string("body"),x:216,top:t,width:356,size:9.1)+3
            t += p.draw(project.string("detail"),x:216,top:t,width:356,size:8.8)+4
            t += p.draw(project.string("stack"),x:216,top:t,width:356,size:7.5,color:p.muted)
            p.y=max(top+112,t+12)
        }
        p.y+=5;p.paragraph("Public source: github.com/BuzzScud/PHYSICS-SIMS",size:8,color:p.teal)
        p.paragraph("Additional project source and demonstrations available on request.",size:8,color:p.muted)
    }
    p.finish();return resumePages
}
func renderCover(profile:Obj,text:String,company:String,role:String,url:URL) throws {
    let p=try PDFWriter(url:url,name:profile.string("name"),title:"Cover Letter - "+company)
    p.newPage();p.paragraph(profile.string("name"),size:25,bold:true,gap:8)
    p.paragraph(profile.string("contact"),size:9,gap:16,color:p.muted)
    p.paragraph(DateFormatter.localizedString(from:Date(),dateStyle:.long,timeStyle:.none),size:10,gap:7,color:p.muted)
    if !company.isEmpty { p.paragraph(company,size:11,bold:true,gap:4) }
    if !role.isEmpty { p.paragraph("Re: "+role,size:10,gap:20,color:p.teal) }
    for paragraph in text.components(separatedBy:"\n\n") { p.paragraph(paragraph,size:11,gap:13) }
    p.finish()
}
func thumbnail(_ url:URL) throws -> String {
    guard let pdf=PDFDocument(url:url), let page=pdf.page(at:0), let tiff=page.thumbnail(of:NSSize(width:612,height:792),for:.mediaBox).tiffRepresentation,let rep=NSBitmapImageRep(data:tiff),let png=rep.representation(using:.png,properties:[:]) else { throw RCError("Unable to preview this PDF.") }
    return "data:image/png;base64,"+png.base64EncodedString()
}
