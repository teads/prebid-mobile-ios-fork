import Foundation
import ObjectiveC

/// Records the URL of every task the app's URL sessions start. It only observes: it never handles a request.
/// The SDK sets `protocolClasses` on its own session configurations, so that setter is swizzled to keep this class in.
final class RequestRecorder: URLProtocol {

    static let didRecord = Notification.Name("RequestRecorderDidRecord")

    private static let lock = NSLock()
    private static var urls = [String]()
    private static var seenTasks = Set<ObjectIdentifier>()

    static var recordedURLs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    static func start() {
        _ = installOnce
    }

    private static let installOnce: Void = {
        let configurationClass: AnyClass = type(of: URLSessionConfiguration.ephemeral)
        let selector = #selector(setter: URLSessionConfiguration.protocolClasses)
        guard let method = class_getInstanceMethod(configurationClass, selector) else { return }

        typealias Setter = @convention(c) (AnyObject, Selector, NSArray?) -> Void
        let originalSetter = unsafeBitCast(method_getImplementation(method), to: Setter.self)
        let setter: @convention(block) (AnyObject, NSArray?) -> Void = { configuration, classes in
            var protocols = (classes as? [AnyClass]) ?? []
            if !protocols.contains(where: { $0 == RequestRecorder.self }) {
                protocols.insert(RequestRecorder.self, at: 0)
            }
            originalSetter(configuration, selector, protocols as NSArray)
        }
        method_setImplementation(method, imp_implementationWithBlock(setter))
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        false
    }

    /// Called per task, possibly more than once, so tasks are recorded only the first time.
    override class func canInit(with task: URLSessionTask) -> Bool {
        guard let url = task.originalRequest?.url?.absoluteString else { return false }
        lock.lock()
        let isNew = seenTasks.insert(ObjectIdentifier(task)).inserted
        if isNew {
            urls.append(url)
        }
        lock.unlock()
        if isNew {
            NotificationCenter.default.post(name: didRecord, object: nil)
        }
        return false
    }
}
