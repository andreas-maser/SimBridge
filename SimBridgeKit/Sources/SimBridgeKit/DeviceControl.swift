//
//  DeviceControl.swift
//  SimBridgeKit
//
//  Intentionally empty. Physical-device discovery via `xcrun devicectl` was
//  rolled back: `devicectl` cannot run inside the App Sandbox
//  ("xcrun: error: cannot be used within an App Sandbox"), so the sandboxed app
//  cannot enumerate real devices. A future device feature would require a
//  non-sandboxed privileged helper (SMAppService) that runs `devicectl` on the
//  app's behalf. Kept as a placeholder file so the synchronized project group
//  stays stable; safe to delete from the project in Xcode.
//
