import Cocoa

private func d<Key,Value>(key: Key?, _ value: Value) -> (Value, [Key:Value]) {
  if let key = key { return (value, [key:value]) } else { return (value, [:]) }
}

extension ViewEmbedding {
    func build(callback: ReturnMessage -> ()) -> (View, [String:View]) {
    switch self {
      case let .Button(id, title):
          let result = button(title, id: id) {
            guard let id = id else { return }
            callback(.ButtonClick(id: id))
          }
          return d(id, result)
      case let .Label(id, title):
          return d(id, label(title, id: id))
      case let .TextView(id, text, editable):
        return d(id, textView(text, editable: editable, id: id))
      case let .Stack(id, items, direction):
        let items = items.map { $0.build(callback) }
        let view = stack(items.map { $0.0 }, orientation: direction.orientation, id: id)
        var dict = id == nil ? [:] : [id!:view]
        for others in items.map({ $0.1 }) {
            for (key, value) in others {
                dict[key] = value
            }
        }
        return (view, dict)
    }
  }
}

class ShoesServer {
    var viewIDs: [String:View] = [:]
    var socket: JSONSocket?
    var windows: [NSWindow] = []
    
    func send(message: ReturnMessage) {
        _ = try? self.socket?._writeAll(message.json)
    }
    
    func sendError(error: ErrorType) {
        send(ReturnMessage.Error(error: error))
    }

    init(port: Int) throws {
        socket = try JSONSocket(port: port) { [unowned self] messageDict in
            do {
              let message = try Message(json: messageDict)
              dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                do {
                    try self.run(message, callback: self.send)
                } catch {
                    self.sendError(error)
                }
              }
            } catch {
              self.sendError(error)
            }
            return nil
        }
    }
    
    func run(message: Message, callback: ReturnMessage -> ()) throws {
        switch message {
        case .Window(let title, let width, let height, let rootView):
            windows.append(window(title, width: width, height: height) { [unowned self] app in
                let (view, dict) = rootView.build(callback)
                self.viewIDs = dict
                return view
            })
        case let .GetValue(id, property):
            let view = try viewIDs[id] !! "Could not find view with id: \(id)"
            let result = try view.getValue(property) !! "No property \(property) on view with id \(id)"
            callback(ReturnMessage.Value(id: id, property: property, value: result))
        case let .SetValue(id, property, value):
            let view = try viewIDs[id] !! "Could not find view with id: \(id)"
            try view.setValue(property, value: value)
        }
    }

}

var server: ShoesServer?
app({
    server = nil
}) { _ in
    server = try! ShoesServer(port: 2015)
}
server = nil
