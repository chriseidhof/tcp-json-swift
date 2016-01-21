//
//  Messages.swift
//  TCP
//
//  Created by Chris Eidhof on 14-01-16.
//  Copyright © 2016 Chris Eidhof. All rights reserved.
//

import Cocoa

enum Message {
    case Window(title: String, width: Int, height: Int, rootView: ViewEmbedding)
    case GetValue(id: String, property: String)
    case SetValue(id: String, property: String, value: AnyObject)
}

enum ReturnMessage {
    case ButtonClick(id: String)
    case Value(id: String, property: String, value: AnyObject)
    case Error(error: ErrorType)
    case Hello
}

extension ReturnMessage {
    var json: [String:AnyObject] {
        switch self {
        case .ButtonClick(let id):
            return ["type": "click", "receiver": id]
        case let .Value(id, property, value):
            return ["type": "value", "receiver": id, "property": property, "value": value]
        case .Error(let e):
            return ["type": "error", "message": "\(e)"]
        case .Hello:
            return ["type": "hello", "version": "0.0.1"] // TODO use a real version
        }
    }
}


enum StackDirection: String {
    case horizontal
    case vertical
    
    var orientation: NSUserInterfaceLayoutOrientation {
        switch self {
        case .horizontal:
            return .Horizontal
        case .vertical:
            return .Vertical
        }
    }
}

enum ViewEmbedding {
    // TODO: I don't like that we have to duplicate the id for every case, but not sure if the code will become simpler if we pull it out
    case Button(id: String?, title: String)
    case Stack(id: String?, items: [ViewEmbedding], direction: StackDirection)
    case Label(id: String?, title: String)
    case TextView(id: String?, text: String, editable: Bool)
}

extension Dictionary {
    func viewEmbedding(key: Key) throws -> ViewEmbedding {
        guard let dict = self[key] as? [String:AnyObject] else {
            throw "Expected \(key) to be a dictionary"
        }
        return try ViewEmbedding(dictionary: dict)
    }
}

extension Message {
    init(json: AnyObject) throws {
        let dictionary = try json as? [String:AnyObject] !! "Not a dictionary"
        let type = try dictionary["type"] as? String !! "No message type \(dictionary)"
        switch type {
        case "window":
            let (title, width, height, rootView) = try
                all(dictionary.string("title"),
                    dictionary.int("width"),
                    dictionary.int("height"),
                    dictionary.viewEmbedding("root")
            )
            self = .Window(title: title, width: width, height: height, rootView: rootView)
        case "get":
           let (id, property) = try all(dictionary.string("id"),
                                        dictionary.string("property"))
           self = .GetValue(id: id, property: property)
        case "set":
           let (id, property, value) = try all(dictionary.string("id"),
                                               dictionary.string("property"),
                                               dictionary["value"] !! "No value")
           self = .SetValue(id: id, property: property, value: value)
        case "app":
            throw "\"app\" is now renamed to \"window\""
        default:
            throw "Message not understood: \(type)"
        }
    }
}

extension ViewEmbedding {
    init(dictionary: [String:AnyObject]) throws {
        let type = try dictionary["type"] as? String !! "No view type"
        let id = dictionary["id"] as? String
        switch type {
        case "button":
            let title = try dictionary.string("title")
            self = .Button(id: id, title: title)
        case "label":
            let title = try dictionary.string("title")
            self = .Label(id: id, title: title)
        case "text":
            let text = try dictionary.string("text")
            let editable = try dictionary.bool("editable")
            self = .TextView(id: id, text: text, editable: editable)
        case "stack":
            // TODO combine these `try`s
            let rawItems: [[String:AnyObject]] = try dictionary.array("items")
            let direction: StackDirection = try dictionary.raw("direction")
            let items = try rawItems.mapAll(ViewEmbedding.init)
            self = .Stack(id: id, items: items, direction: direction)
        default:
            throw "View type not understood \(type)"
        }
    }
}
