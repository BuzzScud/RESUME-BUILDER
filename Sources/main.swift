import Foundation
import AppKit
import WebKit
import PDFKit
import UniformTypeIdentifiers

@MainActor final class AppDelegate:NSObject,NSApplicationDelegate,WKScriptMessageHandler,WKNavigationDelegate,WKUIDelegate {
    var window:NSWindow!
    var web:WKWebView!
    var store:Store!
    var busy=false
    var terminating=false
    func applicationDidFinishLaunching(_ notification:Notification) {
        do { store=try Store(resources:Bundle.main.resourceURL!) } catch { alert(error.localizedDescription);NSApp.terminate(nil);return }
        NSApp.setActivationPolicy(.regular)
        let menu=NSMenu();let appItem=NSMenuItem();menu.addItem(appItem);let appMenu=NSMenu()
        appMenu.addItem(withTitle:"About Rolecraft",action:#selector(showAbout),keyEquivalent:"")
        appMenu.addItem(.separator());appMenu.addItem(withTitle:"Quit Rolecraft",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q");appItem.submenu=appMenu
        let editItem=NSMenuItem();menu.addItem(editItem);let edit=NSMenu(title:"Edit")
        for (title,sel,key) in [("Undo","undo:","z"),("Redo","redo:","Z"),("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] { edit.addItem(withTitle:title,action:Selector(sel),keyEquivalent:key) };editItem.submenu=edit
        NSApp.mainMenu=menu
        let config=WKWebViewConfiguration();config.userContentController.add(self,name:"rolecraft")
        config.websiteDataStore = .nonPersistent()
        web=WKWebView(frame:.zero,configuration:config);web.navigationDelegate=self;web.uiDelegate=self
        web.setValue(false,forKey:"drawsBackground")
        // Match the taller workspace chosen by Christian, then remember later adjustments.
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:1200,height:1144),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="Rolecraft";window.minSize=NSSize(width:940,height:670);window.contentView=web
        let frameName="RolecraftMainWindow"
        if !window.setFrameUsingName(frameName) { window.center() }
        // Keep restored windows usable when moving to a smaller or different display.
        if let visible=window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            var frame=window.frame
            frame.size.width=min(frame.width,visible.width);frame.size.height=min(frame.height,visible.height)
            frame.origin.x=max(visible.minX,min(frame.minX,visible.maxX-frame.width))
            frame.origin.y=max(visible.minY,min(frame.minY,visible.maxY-frame.height))
            window.setFrame(frame,display:false)
        }
        window.setFrameAutosaveName(frameName)
        window.makeKeyAndOrderFront(nil)
        window.backgroundColor=NSColor(calibratedRed:0.96,green:0.96,blue:0.93,alpha:1)
        let root=store.resources.appendingPathComponent("web")
        web.loadFileURL(root.appendingPathComponent("index.html"),allowingReadAccessTo:store.resources)
        NSApp.activate(ignoringOtherApps:true)
    }
    @objc func showAbout() { let a=NSAlert();a.messageText="Rolecraft 1.0";a.informativeText="A personal resume and cover-letter studio for Christian Tavarez.\n\nBuilt for macOS. Screenshot text is read on this Mac. Originals remain unchanged. AI is optional.";a.runModal() }
    func alert(_ text:String) { let a=NSAlert();a.messageText="Rolecraft";a.informativeText=text;a.runModal() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { true }
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if terminating || web == nil { return .terminateNow }
        terminating=true
        web.evaluateJavaScript("if (window.flushBeforeQuit) window.flushBeforeQuit(); void 0;") { _,error in
            if error != nil { sender.reply(toApplicationShouldTerminate:true) }
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+5) { sender.reply(toApplicationShouldTerminate:true) }
        return .terminateLater
    }
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void) {
        guard let u=navigationAction.request.url else { decisionHandler(.cancel);return }
        if u.isFileURL && u.standardizedFileURL.path.hasPrefix(store.resources.standardizedFileURL.path+"/") { decisionHandler(.allow) }
        else { decisionHandler(.cancel);if navigationAction.navigationType == .linkActivated && ["https","mailto"].contains(u.scheme ?? "") { NSWorkspace.shared.open(u) } }
    }
    func webView(_ webView:WKWebView,runOpenPanelWith parameters:WKOpenPanelParameters,initiatedByFrame frame:WKFrameInfo,completionHandler:@escaping([URL]?)->Void) {
        let panel=NSOpenPanel();panel.allowsMultipleSelection=parameters.allowsMultipleSelection;panel.canChooseDirectories=false;panel.beginSheetModal(for:window) { response in completionHandler(response == .OK ? panel.urls:nil) }
    }
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage) {
        guard message.frameInfo.isMainFrame, let u=message.frameInfo.request.url,u.isFileURL,u.standardizedFileURL.path.hasPrefix(store.resources.path+"/"),let body=message.body as? Obj,let id=body["id"] as? String else { return }
        Task { do { let result=try await action(body.string("action"),body.object("payload"));reply(id,result:result,error:nil) } catch { reply(id,result:[:],error:error.localizedDescription) } }
    }
    func reply(_ id:String,result:Any,error:String?) {
        let obj:Obj=["id":id,"result":result,"error":error as Any? ?? NSNull()]
        guard let s=try? jsonString(obj) else { return }
        web.evaluateJavaScript("window.nativeReply(\(s))",completionHandler:nil)
    }
    func action(_ name:String,_ payload:Obj) async throws -> Any {
        switch name {
        case "quitReady": NSApp.reply(toApplicationShouldTerminate:true);return [:]
        case "bootstrap": return ["library":try store.library(),"settings":store.settings(),"history":try store.history(),"portfolio":try store.portfolio(),"exportsPath":store.exportsURL.path,"version":"1.0"]
        case "saveSettings": return try store.saveSettings(payload)
        case "testConnection": return try await AIClient(store.settings()).test()
        case "saveSession": return try store.saveSession(payload)
        case "history": return try store.history()
        case "loadSession": return try store.loadSession(payload.string("id"))
        case "ocr":
            guard let data=Data(base64Encoded:payload.string("data")),data.count<=20_000_000 else { throw RCError("Choose a screenshot smaller than 20 MB.") }
            return try await Task.detached(priority:.userInitiated) { try ocrImage(data) }.value
        case "importResume":
            let panel=NSOpenPanel();panel.title="Import a resume";panel.allowedContentTypes=[.pdf,.plainText];panel.allowsMultipleSelection=false
            let response=await withCheckedContinuation { continuation in panel.beginSheetModal(for:window) { continuation.resume(returning:$0) } }
            guard response == .OK, let url=panel.url else { return ["cancelled":true] }
            let data=try Data(contentsOf:url);guard data.count<=25_000_000 else { throw RCError("Use a resume file smaller than 25 MB.") }
            let text:String
            if url.pathExtension.lowercased()=="pdf" { text=try await Task.detached { try extractPDF(url) }.value }
            else { guard let str=String(data:data,encoding:.utf8) else { throw RCError("Please use a UTF-8 text file.") };text=clean(str) }
            let lines=text.components(separatedBy:.newlines).filter { !$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty }
            let id=UUID().uuidString
            let item:Obj=["id":id,"title":url.deletingPathExtension().lastPathComponent,"template":"classic","imported":true,"needsMapping":true,"text":text,"profile":["name":lines.first ?? "","headline":"","contact":"","summary":"","experience":[],"projects":[],"skills":[],"education":[]]]
            try atomic(item,to:store.importsURL.appendingPathComponent(id+".json"));return item
        case "saveSource":
            var item=payload
            guard UUID(uuidString:item.string("id")) != nil else { throw RCError("The built-in Classic resume is read-only. Save your edits as a new source.") }
            guard !item.object("profile").string("name").isEmpty else { throw RCError("A resume needs a name.") }
            item["needsMapping"]=false
            try atomic(item,to:store.importsURL.appendingPathComponent(item.string("id")+".json"));return item
        case "generate":
            guard !busy else { throw RCError("A draft is already being generated.") }
            let job=payload.string("job").trimmingCharacters(in:.whitespacesAndNewlines)
            guard job.count>=80,job.count<=40000 else { throw RCError("The posting should contain between 80 and 40,000 characters. Include responsibilities and requirements.") }
            let p=payload.object("profile");guard !p.string("name").isEmpty,!p.objects("experience").isEmpty else { throw RCError("Review the source resume and add at least one experience entry first.") }
            busy=true;defer { busy=false }
            return try await AIClient(store.settings()).generate(profile:p,job:job,company:payload.string("company"),role:payload.string("role"),extra:clean(payload.string("extra"),max:10000))
        case "preview":
            let dir=store.root.appendingPathComponent("preview");try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            let p=payload.object("draft").object("profile")
            let projects=try selectedPortfolio(payload)
            let resume=dir.appendingPathComponent("resume.pdf")
            let count=try renderResume(profile:p,portfolio:projects,resources:store.resources,url:resume)
            var images:[String]=[]
            if let doc=PDFDocument(url:resume) { for i in 0..<doc.pageCount { if let page=doc.page(at:i),let tiff=page.thumbnail(of:NSSize(width:918,height:1188),for:.mediaBox).tiffRepresentation,let rep=NSBitmapImageRep(data:tiff),let png=rep.representation(using:.png,properties:[:]) { images.append("data:image/png;base64,"+png.base64EncodedString()) } } }
            return ["images":images,"resumePages":count,"totalPages":images.count]
        case "export":
            let draft=payload.object("draft")
            guard !payload.flag("needsRegeneration") else { throw RCError("The job or source facts changed after this draft was generated. Generate a new draft before exporting.") }
            guard payload.flag("reviewed") else { throw RCError("Confirm you reviewed the resume and cover letter before export.") }
            guard draft.objects("requirements").allSatisfy({ $0.string("status")=="supported" || $0.flag("resolved") }) else { throw RCError("Resolve the open qualification questions before exporting. You can add facts or explicitly leave a gap out.") }
            let profile=draft.object("profile");let company=payload.string("company"),role=payload.string("role")
            guard !company.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!role.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw RCError("Add the employer and role so the export can be organized.") }
            if payload.flag("includeCover") && draft.string("coverLetter").trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { throw RCError("Write a cover letter or turn off its export.") }
            let stamp=ISO8601DateFormatter().string(from:Date()).replacingOccurrences(of:":",with:"-")
            let folder=store.exportsURL.appendingPathComponent(safeName(company)+"_"+safeName(role)+"_"+stamp+"_"+String(UUID().uuidString.prefix(5)))
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let stem=safeName(profile.string("name"));let resume=folder.appendingPathComponent(stem+"_Resume.pdf")
            do {
                let count=try renderResume(profile:profile,portfolio:selectedPortfolio(payload),resources:store.resources,url:resume)
                if payload.flag("onePage") && count>1 { throw RCError("The resume needs \(count) pages. Shorten it in Review, remove some projects, or turn off the one-page limit.") }
                var files=[resume.lastPathComponent]
                if payload.flag("includeCover") {
                    let url=folder.appendingPathComponent(stem+"_Cover_Letter.pdf")
                    try renderCover(profile:profile,text:draft.string("coverLetter"),company:company,role:role,url:url);files.append(url.lastPathComponent)
                }
                try atomic(payload,to:folder.appendingPathComponent("Editable_Draft.json"))
                try Data(payload.string("job").utf8).write(to:folder.appendingPathComponent("Job_Posting.txt"),options:.atomic)
                var saved=payload;saved["exportPath"]=folder.path;_ = try store.saveSession(saved)
                let sourceID=UUID().uuidString
                let source:Obj=["id":sourceID,"title":company+" · "+role,"profile":profile,"template":"classic","text":try extractPDF(resume),"imported":true,"needsMapping":false]
                try atomic(source,to:store.importsURL.appendingPathComponent(sourceID+".json"))
                return ["folder":folder.path,"files":files,"resumePages":count,"library":try store.library(),"history":try store.history()]
            } catch {
                // Only delete this uniquely-created incomplete export, never an existing file.
                try? FileManager.default.removeItem(at:folder);throw error
            }
        case "revealExports":
            try FileManager.default.createDirectory(at:store.exportsURL,withIntermediateDirectories:true)
            NSWorkspace.shared.open(store.exportsURL);return [:]
        case "revealExport":
            let url=URL(fileURLWithPath:payload.string("path")).standardizedFileURL.resolvingSymlinksInPath()
            guard url.path.hasPrefix(store.exportsURL.resolvingSymlinksInPath().path+"/"),FileManager.default.fileExists(atPath:url.path) else { throw RCError("That export folder is unavailable.") }
            NSWorkspace.shared.open(url);return [:]
        default: throw RCError("Unknown app action.")
        }
    }
    func selectedPortfolio(_ payload:Obj) throws -> [Obj] {
        if !payload.flag("includePortfolio") { return [] }
        let ids=payload.strings("portfolioIds")
        let selected=try store.portfolio().filter { ids.contains($0.string("id")) }
        guard !selected.isEmpty else { throw RCError("Choose at least one portfolio project or turn off the portfolio page.") }
        return selected
    }
}

func runSelfTest(_ args:[String]) throws {
    let resources=URL(fileURLWithPath:args[2]);let out=URL(fileURLWithPath:args[3]);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
    let store=try Store(resources:resources,root:out.appendingPathComponent("data"))
    let profile=try store.profile()
    let job="Example Employer seeks a Python software developer with SQL, PostgreSQL, FastAPI, testing, and experience building retrieval systems. Required: a PhD and 12 years of Kubernetes experience."
    let draft=localDraft(profile:profile,job:job,company:"Example Employer",role:"Python Developer")
    precondition(draft.object("profile").objects("experience").map{$0.string("dates")}==profile.objects("experience").map{$0.string("dates")})
    precondition(!draft.objects("requirements").isEmpty)
    let valid:Obj=["headline":profile.string("headline"),"summary":profile.string("summary"),"bullets":sourceBullets(profile).sorted{$0.key<$1.key}.map{["sourceId":$0.key,"text":$0.value]},"projectIds":profile.objects("projects").map{$0.string("id")},"skills":profile.strings("skills"),"requirements":[["requirement":"PhD","status":"gap","evidence":"Not present in the source","question":"Do you hold this degree?"]],"coverLetter":"Dear Hiring Team,\n\nI build Python applications.\n\nSincerely,\nChristian Tavarez","notes":[]]
    let merged=try mergeResponse(valid,profile:profile,extra:"",mode:"test")
    precondition(!merged.objects("requirements")[0].flag("resolved"))
    var bad=valid;bad["skills"]=["Kubernetes - 12 years"]
    do { _=try mergeResponse(bad,profile:profile,extra:"",mode:"test");throw RCError("Unexpectedly accepted invented skills") } catch let e as RCError { if e.message.hasPrefix("Unexpectedly") { throw e } }
    bad=valid;bad["bullets"]=[["sourceId":"nonexistent","text":"Made things"]]
    do { _=try mergeResponse(bad,profile:profile,extra:"",mode:"test");throw RCError("Unexpectedly accepted unknown evidence") } catch let e as RCError { if e.message.hasPrefix("Unexpectedly") { throw e } }
    bad=valid;bad["bullets"]=[["sourceId":"job0-b0","text":"Increased revenue by 900%."]]
    let filtered=try mergeResponse(bad,profile:profile,extra:"",mode:"test");precondition(!filtered.strings("warnings").isEmpty);precondition(filtered.object("profile").objects("experience")[0].objects("bullets")[0].string("text")==sourceBullets(profile)["job0-b0"])
    for invalid in ["https://example.com","http://localhost@evil.test","http://127.0.0.1/path"] { do { _=try localURL(invalid);throw RCError("Unexpectedly accepted remote local model") } catch let e as RCError { if e.message.hasPrefix("Unexpectedly") { throw e } } }
    let s=try store.saveSession(["company":"Test","role":"Developer","draft":draft]);let loaded=try store.read(store.sessionURL(s.string("id"))) as! Obj;precondition(loaded.string("company")=="Test")
    let pages=try renderResume(profile:profile,portfolio:store.portfolio(),resources:resources,url:out.appendingPathComponent("Resume_Portfolio.pdf"))
    try renderCover(profile:profile,text:draft.string("coverLetter"),company:"Example Employer",role:"Python Developer",url:out.appendingPathComponent("Cover_Letter.pdf"))
    var long=profile;long["summary"]=String(repeating:profile.string("summary")+"\n",count:15)
    let longPages=try renderResume(profile:long,portfolio:[],resources:resources,url:out.appendingPathComponent("Overflow.pdf"));precondition(longPages>1)
    let read=try extractPDF(out.appendingPathComponent("Resume_Portfolio.pdf"));precondition(read.contains("600+"));precondition(read.contains("Physics Lab"))
    if args.count>4 { let result=try ocrImage(Data(contentsOf:URL(fileURLWithPath:args[4])));precondition(result.string("text").lowercased().contains("python"));try atomic(result,to:out.appendingPathComponent("ocr-result.json")) }
    try atomic(["status":"passed","resumePages":pages,"overflowPages":longPages,"checks":["local draft preserves dates","gap stays unresolved","invented skill rejected","unknown evidence rejected","new metrics restored","remote Ollama endpoint rejected","draft persistence","PDF text extraction","page overflow","OCR fixture"]],to:out.appendingPathComponent("test-results.json"))
    print("Rolecraft self-test passed; resume pages: \(pages), overflow pages: \(longPages).")
}

func runChecklistTests(_ args:[String]) throws {
    let fixtures=URL(fileURLWithPath:args[2])
    let cases=try decode(Data(contentsOf:fixtures)) as! [Obj]
    func check(_ condition:Bool,_ message:String) throws { if !condition { throw RCError(message) } }
    for c in cases {
        let rows=manualRequirements(job:c.string("job"),company:c.string("company"),role:c.string("role"))
        let text=rows.map{$0.string("requirement")}.joined(separator:"\n")
        try check(rows.count==(c["count"] as! Int),c.string("name")+": wrong count \(rows.count)\n"+text)
        try check(rows.filter{$0.string("kind")=="required"}.count==(c["required"] as! Int),c.string("name")+": required count")
        try check(rows.filter{$0.string("kind")=="preferred"}.count==(c["preferred"] as! Int),c.string("name")+": preferred count")
        for include in c.strings("include") { try check(text.contains(include),c.string("name")+": missing "+include) }
        for exclude in c.strings("exclude") { try check(!text.contains(exclude),c.string("name")+": included metadata "+exclude) }
        try check(rows.allSatisfy{!$0.flag("resolved") && $0.string("status") != "supported"},"Manual parsing asserted a match")
        print("PASS: "+c.string("name"))
    }
    let first=cases[0]
    let session:Obj=["id":UUID().uuidString,"company":first.string("company"),"role":first.string("role"),"job":first.string("job"),"extra":"User-confirmed facts","reviewed":true,"draft":["mode":"manual","profile":["headline":"USER EDIT"],"coverLetter":"USER LETTER EDIT","requirements":[["requirement":"• Hands-on experience with embeddings, RAG patterns, vector","resolution":"My RAG project uses hybrid retrieval.","resolved":true,"status":"unclear"],["requirement":"Duration: 12 Months","resolution":"Do not lose this note.","resolved":true,"status":"unclear"]]],"previousDraft":["mode":"openai","coverLetter":"Previous AI draft"]]
    let updated=upgradeManualChecklist(session)
    try check(try jsonData(updated.object("draft").object("profile"))==jsonData(session.object("draft").object("profile")),"Migration changed resume edits")
    try check(updated.object("draft").string("coverLetter")=="USER LETTER EDIT","Migration changed cover letter")
    try check(updated.string("extra")==session.string("extra"),"Migration changed confirmed facts")
    try check(updated.object("draft").objects("previousChecklist")[1].string("resolution")=="Do not lose this note.","Migration lost archived notes")
    let rag=updated.object("draft").objects("requirements").first{$0.string("requirement").contains("RAG patterns")}!
    try check(rag.string("resolution").contains("hybrid retrieval"),"Migration lost a matching note")
    try check(!rag.flag("resolved"),"Migration marked a partially reviewed requirement complete")
    try check(!updated.flag("reviewed"),"Migration failed to reset final review")
    try check(try jsonData(updated.object("previousDraft"))==jsonData(session.object("previousDraft")),"Migration changed an AI draft")
    try check(try jsonData(upgradeManualChecklist(updated))==jsonData(updated),"Migration is not idempotent")
    let testRoot=fixtures.deletingLastPathComponent().appendingPathComponent("../build/checklist-test-"+UUID().uuidString).standardizedFileURL
    let testStore=try Store(resources:fixtures.deletingLastPathComponent(),root:testRoot)
    let saved=try testStore.saveSession(session)
    _=try testStore.loadSession(saved.string("id"))
    let backups=try FileManager.default.contentsOfDirectory(at:testRoot.appendingPathComponent("backups"),includingPropertiesForKeys:nil)
    try check(backups.count==1,"Missing pre-migration backup")
    _=try testStore.loadSession(saved.string("id"))
    try check(try FileManager.default.contentsOfDirectory(at:testRoot.appendingPathComponent("backups"),includingPropertiesForKeys:nil).count==1,"Repeated backup on unchanged load")
    print("PASS: draft migration preserves edits and notes, is idempotent, and creates a backup")
}

if CommandLine.arguments.contains("--checklist-tests") {
    do { try runChecklistTests(CommandLine.arguments) } catch { fputs("Checklist test failed: \(error.localizedDescription)\n",stderr);exit(1) }
} else if CommandLine.arguments.contains("--self-test") {
    do { try runSelfTest(CommandLine.arguments) } catch { fputs("Self-test failed: \(error.localizedDescription)\n",stderr);exit(1) }
} else {
    MainActor.assumeIsolated {
        let app=NSApplication.shared
        let delegate=AppDelegate();app.delegate=delegate;app.run()
    }
}
