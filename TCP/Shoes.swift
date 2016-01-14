//
//  Shoes.swift
//  TCP
//
//  Created by Chris Eidhof on 14-01-16.
//  Copyright © 2016 Chris Eidhof. All rights reserved.
//

import Cocoa

class MyAppDelegate: NSObject, NSApplicationDelegate {
    var didFinishLaunching: App -> () = { _ in () }
    var willTerminate: () -> () = { _ in () }
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        didFinishLaunching(App(NSApplication.sharedApplication()))
    }
    
    func applicationWillTerminate(notification: NSNotification) {
        willTerminate()
    }
}

public class App {
    private var application: NSApplication
    
    init(_ theApplication: NSApplication) {
        application = theApplication
    }
    
    func exit() {
        application.terminate(nil)
    }
}

func app(onTerminate: () -> (), finishLaunching: App-> ()) {
    let app = NSApplication.sharedApplication()
    let appDelegate = MyAppDelegate()
    appDelegate.didFinishLaunching = { app in
        finishLaunching(app)
        NSApplication.sharedApplication().activateIgnoringOtherApps(true)
    }
    app.setActivationPolicy(.Regular)
    app.delegate = appDelegate
    app.run()
}

public func window(title: String, width: Int = 400, height: Int = 200, rootView: () -> View) -> NSWindow {
    let view = rootView()
    let window = NSWindow()
    window.setContentSize(NSSize(width:width, height:height))
    window.styleMask = NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask
    window.opaque = false
    window.center()
    window.title = title
    window.contentView!.wantsLayer = true
    
    window.makeKeyAndOrderFront(window)
    let contentView = window.contentView!
    
    contentView.addSubview(view.rootView)
    if view.rootView.frame == CGRectZero {
        view.rootView.sizeToParent()
    }
    window.layoutIfNeeded()
    view.afterAdding()
    return window
}

extension NSView {
    func sizeToParent() {
        frame = superview!.bounds
        autoresizingMask = NSAutoresizingMaskOptions([.ViewWidthSizable, .ViewMaxXMargin, .ViewMinYMargin, .ViewHeightSizable, .ViewMaxYMargin])
    }
}

public struct TextViewConfiguration {
    var text: String = ""
    var size: NSSize? = NSMakeSize(180,160)
    var origin: NSPoint? = NSMakePoint(20,10)
    var editable: Bool = false
    var selectable: Bool = true
}

public protocol View {
    var rootView: NSView { get }
    var id: String { get set }
    var afterAdding: () -> () { get }
    func getValue(key: String) -> AnyObject?
    func setValue(key: String, value: AnyObject) throws
}

extension View {
    public func getValue(key: String) -> AnyObject? {
        return nil
    }

    public func setValue(key: String, value: AnyObject) throws {
      throw "Value \(key) cannot be set for \(id)"
    }
}

public class TextView: View {
    public var rootView: NSView
    public var id: String
    var textView: NSTextView
    public var afterAdding: () -> ()
    var text: String {
        get {
            return textView.string ?? ""
        }
        set {
            textView.string = newValue
        }
    }
    init(rootView: NSView, id: String, textView: NSTextView, afterAdding: () -> () = { _ in () } ) {
        self.rootView = rootView
        self.afterAdding = afterAdding
        self.textView = textView
        self.id = id
    }

    public func getValue(key: String) -> AnyObject? {
      switch key {
        case "text": return text
        default: return nil
      }
    }

    public func setValue(key: String, value: AnyObject) throws {
      switch key {
        case "text" where value is String:
            text = value as! String
        default:
            throw "Value \(key) cannot be set for \(id)"
      }
    }
}

public class SimpleView: View {
    public var rootView: NSView
    public var id: String
    public var afterAdding: () -> ()
    var delegate: AnyObject?
    init(rootView: NSView, id: String = NSUUID().UUIDString, delegate: AnyObject? = nil, afterAdding: () -> () = { _ in () } ) {
        self.rootView = rootView
        self.delegate = delegate
        self.afterAdding = afterAdding
        self.id = id
    }
}

public func textView(text: String, editable: Bool, id: String?) -> TextView {
    var configuration = TextViewConfiguration()
    configuration.text = text
    configuration.editable = editable
    return textView(configuration, id: id)
}

public func textView(configuration: TextViewConfiguration, id: String?) -> TextView {
    let scrollView = NSScrollView(frame: CGRectZero)
    scrollView.borderType = .NoBorder
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = false
    
    let ed = NSTextView(frame: CGRectZero)
    
    let afterAdding = {
        ed.frame = scrollView.bounds
        ed.minSize = scrollView.bounds.size
        ed.maxSize = NSSize(width: CGFloat.max, height: CGFloat.max)
        ed.string = configuration.text
        ed.editable = configuration.editable
        ed.selectable = configuration.selectable
        ed.verticallyResizable = true
        ed.horizontallyResizable = false
        ed.textContainer!.containerSize = NSSize(width: scrollView.bounds.size.width, height: CGFloat.max)
        ed.textContainer!.widthTracksTextView = true
        scrollView.documentView = ed
    }
    
    return TextView(rootView: scrollView, id: id ?? NSUUID().UUIDString, textView: ed, afterAdding: afterAdding)
}

class ButtonDelegate: NSObject {
    var callback: () -> ()
    init(_ callback: () -> ()) {
        self.callback = callback
    }
    @objc func buttonClicked() {
        callback()
    }
}

public func button(text: String, id: String? = nil ,onClick: () -> ()) -> View {
    let button = NSButton(frame: CGRectZero)
    let delegate = ButtonDelegate(onClick)
    button.title = text
    button.target = delegate
    button.action = "buttonClicked"
    button.bezelStyle = .SmallSquareBezelStyle
    return SimpleView(rootView: button, id: id ?? NSUUID().UUIDString, delegate: delegate)
}

public func label(text: String, id: String? = nil) -> View {
    let field = NSTextField(frame: CGRectZero)
    field.bezeled = false
    field.drawsBackground = false
    field.editable = false
    field.selectable = false
    field.stringValue = text
    return SimpleView(rootView: field, id: id ?? NSUUID().UUIDString)
}

final class Box<A>: NSObject {
    var unbox: A
    init(_ value: A) { unbox = value }
}

public func stack(views: [View], orientation: NSUserInterfaceLayoutOrientation = .Vertical, id: String? = nil) -> View {
    let stackView = NSStackView(frame: CGRectZero)
    stackView.orientation = orientation
    stackView.autoresizingMask = NSAutoresizingMaskOptions([.ViewWidthSizable, .ViewHeightSizable])
    for view in views {
        stackView.addView(view.rootView, inGravity: .Top)
    }
    
    let afterAdding = {
        views.forEach { $0.afterAdding() }
    }
    return SimpleView(rootView: stackView, id:id ?? NSUUID().UUIDString, delegate: Box(views), afterAdding: afterAdding)
}

// TODO: left-hand side finder-like tree tructure
// TODO: toolbar at the top.
// Goal: build something like notes?
