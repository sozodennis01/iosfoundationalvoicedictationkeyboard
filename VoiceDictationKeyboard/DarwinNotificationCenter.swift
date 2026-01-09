//
//  DarwinNotificationCenter.swift
//  localspeechtotext_keyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//  Based on: https://www.nonstrict.eu/blog/2023/Darwin-Notifications-App-Extensions
//

import Foundation
import Combine

private let center = CFNotificationCenterGetDarwinNotifyCenter()

/// Wrapper for CFNotificationCenter (Darwin notifications) for cross-process communication
/// Darwin notifications work between app extensions and host apps via the system notification center
public final class DarwinNotificationCenter {
    private init() {}
    public static let shared = DarwinNotificationCenter()

    /// Post a Darwin notification (from host app)
    public func post(name: String) {
        CFNotificationCenterPostNotification(center, CFNotificationName(rawValue: name as CFString), nil, nil, true)
    }

    /// Observe a Darwin notification (from keyboard extension)
    public func addObserver(name: String, callback: @escaping () -> Void) -> DarwinNotificationObservation {
        let observation = DarwinNotificationObservation(callback: callback)

        let pointer = UnsafeRawPointer(Unmanaged.passUnretained(observation.closure).toOpaque())

        CFNotificationCenterAddObserver(center, pointer, notificationCallback, name as CFString, nil, .deliverImmediately)

        return observation
    }
}

/// Cancellable observation object
public final class DarwinNotificationObservation: Cancellable {
    fileprivate class Closure {
        let invoke: () -> Void
        init(callback: @escaping () -> Void) {
            self.invoke = callback
        }
    }

    fileprivate let closure: Closure

    fileprivate init(callback: @escaping () -> Void) {
        self.closure = Closure(callback: callback)
    }

    deinit {
        cancel()
    }

    public func cancel() {
        DispatchQueue.main.async { [closure] in
            let pointer = UnsafeRawPointer(Unmanaged.passUnretained(closure).toOpaque())
            CFNotificationCenterRemoveObserver(center, pointer, nil, nil)
        }
    }
}

private func notificationCallback(center: CFNotificationCenter?, observation: UnsafeMutableRawPointer?, name: CFNotificationName?, object _: UnsafeRawPointer?, userInfo _: CFDictionary?) {
    guard let pointer = observation else { return }

    let closure = Unmanaged<DarwinNotificationObservation.Closure>.fromOpaque(pointer).takeUnretainedValue()

    closure.invoke()
}
