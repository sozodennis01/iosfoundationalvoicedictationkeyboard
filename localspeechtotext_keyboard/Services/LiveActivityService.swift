//
//  LiveActivityService.swift
//  localspeechtotext_keyboard
//
//  Created by Dennis Sarsozo on 1/8/26.
//

import ActivityKit
import Foundation

@available(iOS 26.0, *)
class LiveActivityService {
    private var currentActivity: Activity<RecordingActivityAttributes>?
    private var startTime: Date?
    
    /// Start a new Live Activity for voice recording
    func startActivity() async throws {
        // End any existing activity first
        await endActivity()
        
        let attributes = RecordingActivityAttributes(name: "Voice Dictation")
        let initialState = RecordingActivityAttributes.ContentState(
            status: "Listening...",
            duration: 0,
            isRecording: true
        )
        
        let activity = try Activity.request(
            attributes: attributes,
            content: .init(state: initialState, staleDate: nil)
        )
        
        currentActivity = activity
        startTime = Date()
        
        // Start timer to update duration
        startDurationTimer()
    }
    
    /// Update the Live Activity status
    func updateStatus(_ status: String, isRecording: Bool = true) async {
        guard let activity = currentActivity else { return }
        
        let duration = startTime.map { Int(Date().timeIntervalSince($0)) } ?? 0
        let updatedState = RecordingActivityAttributes.ContentState(
            status: status,
            duration: duration,
            isRecording: isRecording
        )
        
        await activity.update(
            .init(state: updatedState, staleDate: nil)
        )
    }
    
    /// End the current Live Activity
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        let finalState = RecordingActivityAttributes.ContentState(
            status: "Complete",
            duration: startTime.map { Int(Date().timeIntervalSince($0)) } ?? 0,
            isRecording: false
        )
        
        await activity.end(
            .init(state: finalState, staleDate: nil),
            dismissalPolicy: .immediate
        )
        
        currentActivity = nil
        startTime = nil
    }
    
    /// Start a timer to update duration every second
    private func startDurationTimer() {
        Task {
            while currentActivity != nil, let start = startTime {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                guard let activity = currentActivity else { break }
                
                let duration = Int(Date().timeIntervalSince(start))
                let currentState = await activity.content.state
                
                let updatedState = RecordingActivityAttributes.ContentState(
                    status: currentState.status,
                    duration: duration,
                    isRecording: currentState.isRecording
                )
                
                await activity.update(
                    .init(state: updatedState, staleDate: nil)
                )
            }
        }
    }
}
