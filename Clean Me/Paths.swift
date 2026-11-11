//
//  Commands.swift
//  Clean Me
//
//  Created by Kevin De Koninck on 18/01/2017.
//  Copyright © 2017 Kevin De Koninck. All rights reserved.
//

import Foundation

let globalTempFilesPath     = "/tmp/"
let userCachePath           = "~/Library/Caches/"
let userLogsPath            = "~/Library/logs/"
let userPreferencesPath     = "~/Library/Preferences/"
let systemLogs1Path         = "/Library/logs/"
let systemLogs2Path         = "/var/log/"
let mailAttachementsPath    = "~/Library/Containers/com.apple.mail/Data/Library/Mail\\ Downloads/"
let trashPath               = "~/.Trash/"
let xcodeDerivedDataPath    = "~/Library/Developer/Xcode/DerivedData/"
let xcodeArchivesPath       = "~/Library/Developer/Xcode/Archives/"
let xcodeDeviceLogsPath     = "~/Library/Developer/Xcode/iOS\\ Device\\ Logs/"
let terminalCacheFilesPath  = "/private/var/log/asl/*.asl"
let terminalCachePath       = "/private/var/log/asl/" // used for open func
let bashHistoryFile         = "~/.bash_history"
let bashHistoryPath         = "~/.bash_sessions/"
let downloadsPath           = "~/Downloads/"
let userAppLogsPath         = "~/Library/Containers/*/Data/Library/Logs/"
let userAppCachePath        = "~/Library/Containers/*/Data/Library/Caches/"
let spotlightPath           = "/.Spotlight-V100/"
let docRevPath              = "/.DocumentRevisions-V100/"
let imessageAttachmentsPath = "~/Library/Messages/Attachments/"
//Folder for symbolic links this app creates
let symbolicUserAppLogsPath = "~/.AppLogsSymLinksForCleanMe/"
let symbolicUserAppCachePath = "~/.AppCacheSymLinksForCleanMe/"

// MARK: - CM-F-01 fix (Academy, 2026-11-11): single source of truth
//
// One `CleanLocation` entry carries its stable key, the label the UI shows
// (verbatim from Main.storyboard), the path that Analyse measures and Clean
// deletes, and whether deletion runs as root. `PATH` and `PATHkey` are
// DERIVED from `cleanLocations` below — there are no parallel arrays joined
// by index anymore, so a label can no longer resolve to a different path.
// The storyboard folder-open buttons use the entry's index in
// `cleanLocations` as their tag; `cleanLocation(forTag:)` is the only
// tag -> location resolution and it is bounds-checked (no crash).

struct CleanLocation {
    let key: String
    let displayName: String
    let path: String
    let requiresRoot: Bool
}

let cleanLocations: [CleanLocation] = [
    CleanLocation(key: "trash",        displayName: "Empty the Trash",              path: trashPath,                                                              requiresRoot: false),
    CleanLocation(key: "mails",        displayName: "Downloaded Mail Attachments",  path: mailAttachementsPath,                                                   requiresRoot: false),
    CleanLocation(key: "xcode",        displayName: "Xcode DerivedData and Archives", path: /* xcodeArchivesPath + " " + */ xcodeDeviceLogsPath + " " + xcodeDerivedDataPath, requiresRoot: false),
    CleanLocation(key: "bash",         displayName: "Bash History",                 path: bashHistoryPath + " " + bashHistoryFile,                                requiresRoot: false),
    CleanLocation(key: "terminal",     displayName: "Terminal Cache",               path: terminalCacheFilesPath,                                                 requiresRoot: true),
    CleanLocation(key: "userAppLogs",  displayName: "User Application Logs",        path: userAppLogsPath,                                                        requiresRoot: false),
    CleanLocation(key: "userAppCache", displayName: "User Application Caches",      path: userAppCachePath,                                                       requiresRoot: false),
    CleanLocation(key: "userCache",    displayName: "User Cache",                   path: userCachePath,                                                          requiresRoot: false),
    CleanLocation(key: "userLogs",     displayName: "User Logs",                    path: userLogsPath,                                                           requiresRoot: false),
    CleanLocation(key: "systemLogs",   displayName: "System Logs",                  path: systemLogs1Path + " " + systemLogs2Path,                                requiresRoot: true),
    CleanLocation(key: "globalTemp",   displayName: "Global Temp Files",            path: globalTempFilesPath,                                                    requiresRoot: true),
    CleanLocation(key: "userPrefs",    displayName: "User Preferences",             path: userPreferencesPath,                                                    requiresRoot: true),
    CleanLocation(key: "downloads",    displayName: "Empty the Downloads Folder",   path: downloadsPath,                                                          requiresRoot: false),
    CleanLocation(key: "spotlight",    displayName: "Spotlight indexing files",     path: spotlightPath,                                                          requiresRoot: false),
    CleanLocation(key: "docRev",       displayName: "Document Revisions",           path: docRevPath,                                                             requiresRoot: true),
    CleanLocation(key: "imessage",     displayName: "iMessage attachments",         path: imessageAttachmentsPath,                                                requiresRoot: true)
]

func cleanLocation(forKey key: String) -> CleanLocation? {
    return cleanLocations.first(where: { $0.key == key })
}

func cleanLocation(forTag tag: Int) -> CleanLocation? {
    guard cleanLocations.indices.contains(tag) else { return nil }
    return cleanLocations[tag]
}

// Derived views over `cleanLocations` (kept for the existing string-key
// callers in `CleanMe.calculateSizes` / `ViewController` size lookups).
let PATH: [String: String] = {
    var dict: [String: String] = [:]
    for location in cleanLocations { dict[location.key] = location.path }
    return dict
}()
let PATHkey: [String] = cleanLocations.map { $0.key } //helper, derived — do not hand-edit
