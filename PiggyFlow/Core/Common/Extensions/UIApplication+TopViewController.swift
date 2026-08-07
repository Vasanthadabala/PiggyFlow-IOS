import UIKit

extension UIApplication {
    /// The view controller currently presented on screen.
    ///
    /// Needed whenever a UIKit-based flow has to be presented from SwiftUI — Google Sign-In
    /// and the PDF share sheet both require a presenting controller. Walks past navigation
    /// stacks, tab bars and any modally presented controllers to find the real top.
    static func topViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
}
