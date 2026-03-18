// DFRPrivateAPI.swift — Private DFRFoundation API declarations
// These symbols come from Apple's private DFRFoundation.framework.
// Used by MTMR, Pock, touch-baer, and other Touch Bar customization tools.
//
// Since Swift Package Manager doesn't support bridging headers, we use
// dlopen/dlsym to dynamically load these symbols at runtime. This also
// gives us graceful degradation — if the framework doesn't exist (e.g.,
// on a Mac without a Touch Bar), we detect that and skip Touch Bar setup.
//
// Private API symbols used:
//   - DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL)
//   - DFRElementSetControlStripPresenceForIdentifier(NSTouchBarItemIdentifier, BOOL)
//   - NSTouchBarItem.addSystemTrayItem(_:)  (registers item with system tray)
//   - NSTouchBar.presentSystemModalTouchBar(_:placement:systemTrayItemIdentifier:)
//   - NSTouchBar.minimizeSystemModalTouchBar(_:)
//   - NSTouchBar.dismissSystemModalTouchBar(_:)

import AppKit

// MARK: - DFR Function Types

/// Typealias for DFRSystemModalShowsCloseBoxWhenFrontMost(BOOL)
/// Controls whether the close button appears when our Touch Bar is frontmost.
private typealias DFRShowsCloseBoxFunc = @convention(c) (Bool) -> Void

/// Typealias for DFRElementSetControlStripPresenceForIdentifier(id, BOOL)
/// Registers/unregisters an item in the Control Strip region.
private typealias DFRSetPresenceFunc = @convention(c) (NSString, Bool) -> Void

// MARK: - DFRFoundation Loader

/// Dynamically loads DFRFoundation.framework and resolves private API symbols.
/// Returns nil if the framework is unavailable (no Touch Bar hardware).
final class DFRFoundationLoader {

    static let shared = DFRFoundationLoader()

    /// Whether DFRFoundation was successfully loaded.
    let isLoaded: Bool

    private let handle: UnsafeMutableRawPointer?
    private let showsCloseBox: DFRShowsCloseBoxFunc?
    private let setPresence: DFRSetPresenceFunc?

    private init() {
        let frameworkPath = "/System/Library/PrivateFrameworks/DFRFoundation.framework/DFRFoundation"

        guard let handle = dlopen(frameworkPath, RTLD_LAZY) else {
            NSLog("[Pushling] DFRFoundation not available — Touch Bar features disabled")
            self.handle = nil
            self.isLoaded = false
            self.showsCloseBox = nil
            self.setPresence = nil
            return
        }

        self.handle = handle
        self.isLoaded = true

        // Resolve DFRSystemModalShowsCloseBoxWhenFrontMost
        if let sym = dlsym(handle, "DFRSystemModalShowsCloseBoxWhenFrontMost") {
            self.showsCloseBox = unsafeBitCast(sym, to: DFRShowsCloseBoxFunc.self)
        } else {
            NSLog("[Pushling] Warning: DFRSystemModalShowsCloseBoxWhenFrontMost not found")
            self.showsCloseBox = nil
        }

        // Resolve DFRElementSetControlStripPresenceForIdentifier
        if let sym = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") {
            self.setPresence = unsafeBitCast(sym, to: DFRSetPresenceFunc.self)
        } else {
            NSLog("[Pushling] Warning: DFRElementSetControlStripPresenceForIdentifier not found")
            self.setPresence = nil
        }

        NSLog("[Pushling] DFRFoundation loaded successfully")
    }

    deinit {
        if let handle = handle {
            dlclose(handle)
        }
    }

    // MARK: - Public API

    /// Hide the close button when our Touch Bar is frontmost.
    func setShowsCloseBoxWhenFrontMost(_ shows: Bool) {
        showsCloseBox?(shows)
    }

    /// Set Control Strip presence for an identifier.
    func setControlStripPresence(for identifier: NSTouchBarItem.Identifier, present: Bool) {
        setPresence?(identifier.rawValue as NSString, present)
    }
}

// MARK: - NSTouchBar Private API Extensions

/// Extensions to access NSTouchBar's private presentation methods.
/// These are instance methods on NSTouchBar that Apple uses internally
/// for system-modal presentation (Control Strip replacement).
///
/// We use @objc and performSelector since these are Objective-C methods
/// on NSTouchBar that aren't declared in public headers.
extension NSTouchBar {

    /// Present this Touch Bar as a system-modal overlay, replacing the system strip.
    /// Placement: 1 = replace system function bar region
    func presentAsSystemModal(
        placement: Int = 1,
        systemTrayItemIdentifier: NSTouchBarItem.Identifier
    ) {
        // Use the class method: +[NSTouchBar presentSystemModalTouchBar:placement:systemTrayItemIdentifier:]
        let selector = NSSelectorFromString(
            "presentSystemModalTouchBar:placement:systemTrayItemIdentifier:"
        )

        guard NSTouchBar.responds(to: selector) else {
            NSLog("[Pushling] NSTouchBar.presentSystemModalTouchBar not available")
            return
        }

        // Invoke via NSInvocation-style: we need the class method
        let cls: AnyClass = NSTouchBar.self
        guard let method = class_getClassMethod(cls, selector) else {
            NSLog("[Pushling] Could not get class method for presentSystemModalTouchBar")
            return
        }

        typealias PresentFunc = @convention(c) (
            AnyClass, Selector, NSTouchBar, Int, NSTouchBarItem.Identifier
        ) -> Void

        let imp = method_getImplementation(method)
        let present = unsafeBitCast(imp, to: PresentFunc.self)
        present(cls, selector, self, placement, systemTrayItemIdentifier)
    }

    /// Dismiss this Touch Bar from system-modal presentation.
    func dismissSystemModal() {
        let selector = NSSelectorFromString("dismissSystemModalTouchBar:")

        guard NSTouchBar.responds(to: selector) else {
            NSLog("[Pushling] NSTouchBar.dismissSystemModalTouchBar not available")
            return
        }

        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
            NSLog("[Pushling] Could not get class method for dismissSystemModalTouchBar")
            return
        }

        typealias DismissFunc = @convention(c) (
            AnyClass, Selector, NSTouchBar
        ) -> Void

        let imp = method_getImplementation(method)
        let dismiss = unsafeBitCast(imp, to: DismissFunc.self)
        dismiss(NSTouchBar.self, selector, self)
    }

    /// Minimize this Touch Bar (collapse to control strip item).
    func minimizeSystemModal() {
        let selector = NSSelectorFromString("minimizeSystemModalTouchBar:")

        guard NSTouchBar.responds(to: selector) else {
            return  // Silently fail — minimize is optional
        }

        guard let method = class_getClassMethod(NSTouchBar.self, selector) else {
            return
        }

        typealias MinimizeFunc = @convention(c) (
            AnyClass, Selector, NSTouchBar
        ) -> Void

        let imp = method_getImplementation(method)
        let minimize = unsafeBitCast(imp, to: MinimizeFunc.self)
        minimize(NSTouchBar.self, selector, self)
    }
}

// MARK: - NSTouchBarItem Private API Extension

extension NSTouchBarItem {

    /// Register this item with the system tray (control strip).
    /// Must be called BEFORE DFRElementSetControlStripPresenceForIdentifier.
    /// Without this call, the presence flag has no item to display.
    static func addSystemTrayItem(_ item: NSTouchBarItem) {
        let selector = NSSelectorFromString("addSystemTrayItem:")

        guard NSTouchBarItem.responds(to: selector) else {
            NSLog("[Pushling] NSTouchBarItem.addSystemTrayItem not available")
            return
        }

        guard let method = class_getClassMethod(NSTouchBarItem.self, selector) else {
            NSLog("[Pushling] Could not get class method for addSystemTrayItem")
            return
        }

        typealias AddFunc = @convention(c) (
            AnyClass, Selector, NSTouchBarItem
        ) -> Void

        let imp = method_getImplementation(method)
        let add = unsafeBitCast(imp, to: AddFunc.self)
        add(NSTouchBarItem.self, selector, item)
    }

    /// Remove this item from the system tray.
    static func removeSystemTrayItem(_ item: NSTouchBarItem) {
        let selector = NSSelectorFromString("removeSystemTrayItem:")

        guard NSTouchBarItem.responds(to: selector) else { return }
        guard let method = class_getClassMethod(NSTouchBarItem.self, selector) else { return }

        typealias RemoveFunc = @convention(c) (
            AnyClass, Selector, NSTouchBarItem
        ) -> Void

        let imp = method_getImplementation(method)
        let remove = unsafeBitCast(imp, to: RemoveFunc.self)
        remove(NSTouchBarItem.self, selector, item)
    }
}
