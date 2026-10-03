//
//  RecursiveDirectoryWatcher.swift
//  SimBridgeFileProvider
//
//  Intentionally empty: FSEvents is blocked inside the sandboxed File Provider
//  extension for the CoreSimulator path. Live-update watching now lives in the
//  app (see MountWatcher in the SimBridge app target), which has FSEvents access
//  to the user-granted Simulator folder and calls signalEnumerator on the domain.
//
