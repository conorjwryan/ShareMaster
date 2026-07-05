//
//  StatusOverlay.swift
//  ShareMasterIOS
//
//  Hosts the upload/download status bars in their own UIWindow, floating
//  above the whole app — including sheets — like Instagram's download
//  toast. A plain safeAreaInset bar disappears the moment a sheet covers
//  the NavigationStack; a separate window at a raised level doesn't.
//
//  The window passes touches through everywhere except the bars
//  themselves, so it never blocks the UI underneath.
//

import SwiftUI
import UIKit

@MainActor
final class StatusOverlay {
    static let shared = StatusOverlay()
    private var window: PassThroughWindow?

    private init() {}

    /// Idempotent; called when the root view appears.
    func attach() {
        guard window == nil,
              let scene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first else { return }
        let host = UIHostingController(rootView: OverlayRoot())
        host.view.backgroundColor = .clear
        let overlay = PassThroughWindow(windowScene: scene)
        overlay.rootViewController = host
        // Above the main window (and its sheets), below system alerts.
        overlay.windowLevel = UIWindow.Level(UIWindow.Level.alert.rawValue - 1)
        overlay.isHidden = false
        window = overlay
    }
}

/// The overlay's content: both status bars pinned to the bottom.
private struct OverlayRoot: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            DownloadStatusBar()
            UploadStatusBar()
        }
    }
}

/// A window that only intercepts touches landing on its actual content.
private final class PassThroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hitView = super.hitTest(point, with: event),
              let rootView = rootViewController?.view else { return nil }
        if #available(iOS 18, *) {
            // iOS 18+: the hosting view hit-tests to itself even for empty
            // space, so check whether any of its subviews (the actual
            // SwiftUI content) took the touch.
            for subview in rootView.subviews.reversed() {
                let converted = subview.convert(point, from: rootView)
                if subview.hitTest(converted, with: event) != nil {
                    return hitView
                }
            }
            return nil
        }
        return hitView == rootView ? nil : hitView
    }
}
