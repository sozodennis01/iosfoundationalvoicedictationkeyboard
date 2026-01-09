//
//  RecordingActivityAttributes.swift
//  localspeechtotext_keyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import ActivityKit
import Foundation

/// Activity attributes for Live Activities / Dynamic Island integration
@available(iOS 26.0, *)
struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Current status text (e.g., "Listening...", "Processing...")
        var status: String
        
        /// Recording duration in seconds
        var duration: Int
        
        /// Whether recording is active
        var isRecording: Bool
    }
    
    /// Display name for the activity
    var name: String
}
