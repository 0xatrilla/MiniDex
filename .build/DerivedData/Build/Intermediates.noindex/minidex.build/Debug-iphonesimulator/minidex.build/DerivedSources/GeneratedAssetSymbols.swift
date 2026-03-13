import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "command" asset catalog color resource.
    static let command = DeveloperToolsSupport.ColorResource(name: "command", bundle: resourceBundle)

    /// The "plan" asset catalog color resource.
    static let plan = DeveloperToolsSupport.ColorResource(name: "plan", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "AppLogo" asset catalog image resource.
    static let appLogo = DeveloperToolsSupport.ImageResource(name: "AppLogo", bundle: resourceBundle)

    /// The "GitHub_Invertocat_Black" asset catalog image resource.
    static let gitHubInvertocatBlack = DeveloperToolsSupport.ImageResource(name: "GitHub_Invertocat_Black", bundle: resourceBundle)

    /// The "arrow-circle-down" asset catalog image resource.
    static let arrowCircleDown = DeveloperToolsSupport.ImageResource(name: "arrow-circle-down", bundle: resourceBundle)

    /// The "arrow-circle-up" asset catalog image resource.
    static let arrowCircleUp = DeveloperToolsSupport.ImageResource(name: "arrow-circle-up", bundle: resourceBundle)

    /// The "brain" asset catalog image resource.
    static let brain = DeveloperToolsSupport.ImageResource(name: "brain", bundle: resourceBundle)

    /// The "cloud-upload" asset catalog image resource.
    static let cloudUpload = DeveloperToolsSupport.ImageResource(name: "cloud-upload", bundle: resourceBundle)

    /// The "codex-signin" asset catalog image resource.
    static let codexSignin = DeveloperToolsSupport.ImageResource(name: "codex-signin", bundle: resourceBundle)

    /// The "copy" asset catalog image resource.
    static let copy = DeveloperToolsSupport.ImageResource(name: "copy", bundle: resourceBundle)

    /// The "git-branch" asset catalog image resource.
    static let gitBranch = DeveloperToolsSupport.ImageResource(name: "git-branch", bundle: resourceBundle)

    /// The "git-commit" asset catalog image resource.
    static let gitCommit = DeveloperToolsSupport.ImageResource(name: "git-commit", bundle: resourceBundle)

    /// The "pen-square" asset catalog image resource.
    static let penSquare = DeveloperToolsSupport.ImageResource(name: "pen-square", bundle: resourceBundle)

    /// The "terminal" asset catalog image resource.
    static let terminal = DeveloperToolsSupport.ImageResource(name: "terminal", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "command" asset catalog color.
    static var command: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .command)
#else
        .init()
#endif
    }

    /// The "plan" asset catalog color.
    static var plan: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .plan)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "command" asset catalog color.
    static var command: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .command)
#else
        .init()
#endif
    }

    /// The "plan" asset catalog color.
    static var plan: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .plan)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "command" asset catalog color.
    static var command: SwiftUI.Color { .init(.command) }

    /// The "plan" asset catalog color.
    static var plan: SwiftUI.Color { .init(.plan) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "command" asset catalog color.
    static var command: SwiftUI.Color { .init(.command) }

    /// The "plan" asset catalog color.
    static var plan: SwiftUI.Color { .init(.plan) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "AppLogo" asset catalog image.
    static var appLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appLogo)
#else
        .init()
#endif
    }

    /// The "GitHub_Invertocat_Black" asset catalog image.
    static var gitHubInvertocatBlack: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .gitHubInvertocatBlack)
#else
        .init()
#endif
    }

    /// The "arrow-circle-down" asset catalog image.
    static var arrowCircleDown: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .arrowCircleDown)
#else
        .init()
#endif
    }

    /// The "arrow-circle-up" asset catalog image.
    static var arrowCircleUp: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .arrowCircleUp)
#else
        .init()
#endif
    }

    /// The "brain" asset catalog image.
    static var brain: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brain)
#else
        .init()
#endif
    }

    /// The "cloud-upload" asset catalog image.
    static var cloudUpload: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .cloudUpload)
#else
        .init()
#endif
    }

    /// The "codex-signin" asset catalog image.
    static var codexSignin: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .codexSignin)
#else
        .init()
#endif
    }

    /// The "copy" asset catalog image.
    static var copy: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .copy)
#else
        .init()
#endif
    }

    /// The "git-branch" asset catalog image.
    static var gitBranch: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .gitBranch)
#else
        .init()
#endif
    }

    /// The "git-commit" asset catalog image.
    static var gitCommit: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .gitCommit)
#else
        .init()
#endif
    }

    /// The "pen-square" asset catalog image.
    static var penSquare: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .penSquare)
#else
        .init()
#endif
    }

    /// The "terminal" asset catalog image.
    static var terminal: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .terminal)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "AppLogo" asset catalog image.
    static var appLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .appLogo)
#else
        .init()
#endif
    }

    /// The "GitHub_Invertocat_Black" asset catalog image.
    static var gitHubInvertocatBlack: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .gitHubInvertocatBlack)
#else
        .init()
#endif
    }

    /// The "arrow-circle-down" asset catalog image.
    static var arrowCircleDown: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .arrowCircleDown)
#else
        .init()
#endif
    }

    /// The "arrow-circle-up" asset catalog image.
    static var arrowCircleUp: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .arrowCircleUp)
#else
        .init()
#endif
    }

    /// The "brain" asset catalog image.
    static var brain: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .brain)
#else
        .init()
#endif
    }

    /// The "cloud-upload" asset catalog image.
    static var cloudUpload: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .cloudUpload)
#else
        .init()
#endif
    }

    /// The "codex-signin" asset catalog image.
    static var codexSignin: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .codexSignin)
#else
        .init()
#endif
    }

    /// The "copy" asset catalog image.
    static var copy: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .copy)
#else
        .init()
#endif
    }

    /// The "git-branch" asset catalog image.
    static var gitBranch: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .gitBranch)
#else
        .init()
#endif
    }

    /// The "git-commit" asset catalog image.
    static var gitCommit: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .gitCommit)
#else
        .init()
#endif
    }

    /// The "pen-square" asset catalog image.
    static var penSquare: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .penSquare)
#else
        .init()
#endif
    }

    /// The "terminal" asset catalog image.
    static var terminal: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .terminal)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

