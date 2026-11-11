//
//  CleanMeTests.swift
//  Clean MeTests
//
//  CM-F-01 label->path regression suite (Academy, 2026-11-11).
//
//  Before the fix, `ViewController.cleanBtnClicked` and the storyboard
//  folder-open tags used a second numbering (skipping 9, running to 16)
//  resolved through the packed `PATHkey` (0-15): selecting "System Logs"
//  deleted /tmp, "Global Temp" deleted ~/Library/Preferences as root,
//  "User Preferences" deleted ~/Downloads, "Downloads" attempted
//  /.Spotlight-V100, "Spotlight" deleted /.DocumentRevisions-V100 as
//  root, "Document Revisions" deleted iMessage attachments as root, and
//  "iMessage" (16) crashed the app. These tests pin every label to the
//  path it denotes so that class of defect cannot return.
//

import XCTest
@testable import Clean_Me

class CleanMeTests: XCTestCase {

    /// The full expected label -> path table, in UI/model order.
    /// Paths are the exact strings from `Paths.swift` (the values Analyse
    /// measures and `CleanMe.createDeleteCmd` deletes the contents of).
    let expected: [(key: String, displayName: String, path: String, requiresRoot: Bool)] = [
        ("trash",        "Empty the Trash",               "~/.Trash/",                                                              false),
        ("mails",        "Downloaded Mail Attachments",   "~/Library/Containers/com.apple.mail/Data/Library/Mail\\ Downloads/",     false),
        ("xcode",        "Xcode DerivedData and Archives", "~/Library/Developer/Xcode/iOS\\ Device\\ Logs/ ~/Library/Developer/Xcode/DerivedData/", false),
        ("bash",         "Bash History",                  "~/.bash_sessions/ ~/.bash_history",                                      false),
        ("terminal",     "Terminal Cache",                "/private/var/log/asl/*.asl",                                             true),
        ("userAppLogs",  "User Application Logs",         "~/Library/Containers/*/Data/Library/Logs/",                              false),
        ("userAppCache", "User Application Caches",       "~/Library/Containers/*/Data/Library/Caches/",                            false),
        ("userCache",    "User Cache",                    "~/Library/Caches/",                                                      false),
        ("userLogs",     "User Logs",                     "~/Library/logs/",                                                        false),
        ("systemLogs",   "System Logs",                   "/Library/logs/ /var/log/",                                               true),
        ("globalTemp",   "Global Temp Files",             "/tmp/",                                                                  true),
        ("userPrefs",    "User Preferences",              "~/Library/Preferences/",                                                 true),
        ("downloads",    "Empty the Downloads Folder",    "~/Downloads/",                                                           false),
        ("spotlight",    "Spotlight indexing files",      "/.Spotlight-V100/",                                                      false),
        ("docRev",       "Document Revisions",            "/.DocumentRevisions-V100/",                                             true),
        ("imessage",     "iMessage attachments",          "~/Library/Messages/Attachments/",                                        true)
    ]

    func testModelHasExactlyTheExpectedEntriesInOrder() {
        XCTAssertEqual(cleanLocations.count, expected.count)
        for (index, want) in expected.enumerated() {
            let got = cleanLocations[index]
            XCTAssertEqual(got.key, want.key, "entry \(index) key")
            XCTAssertEqual(got.displayName, want.displayName, "\(want.key) label")
            XCTAssertEqual(got.path, want.path, "\(want.key) path")
            XCTAssertEqual(got.requiresRoot, want.requiresRoot, "\(want.key) requiresRoot")
        }
    }

    func testLabelDenotesDeletedPathForEveryEntry() {
        for want in expected {
            let location = cleanLocation(forKey: want.key)
            XCTAssertNotNil(location, "\(want.key) must resolve")
            XCTAssertEqual(location?.displayName, want.displayName)
            XCTAssertEqual(location?.path, want.path,
                           "label '\(want.displayName)' must delete \(want.path)")
            XCTAssertEqual(PATH[want.key], want.path,
                           "derived PATH must agree for \(want.key)")
        }
    }

    func testDerivedTablesCannotDivergeFromModel() {
        XCTAssertEqual(PATHkey, cleanLocations.map { $0.key })
        XCTAssertEqual(PATH.count, cleanLocations.count)
        XCTAssertEqual(Set(PATHkey).count, PATHkey.count, "keys must be unique")
    }

    // MARK: - The entries CM-F-01 misaligned, covered by name

    func testSystemLogsDeletesSystemLogsNotGlobalTemp() {
        XCTAssertEqual(cleanLocation(forKey: "systemLogs")?.path, "/Library/logs/ /var/log/")
        XCTAssertEqual(cleanLocation(forTag: 9)?.key, "systemLogs")
    }

    func testGlobalTempDeletesTmpNotUserPreferences() {
        XCTAssertEqual(cleanLocation(forKey: "globalTemp")?.path, "/tmp/")
        XCTAssertEqual(cleanLocation(forTag: 10)?.key, "globalTemp")
    }

    func testUserPreferencesDeletesPreferencesNotDownloads() {
        XCTAssertEqual(cleanLocation(forKey: "userPrefs")?.path, "~/Library/Preferences/")
        XCTAssertEqual(cleanLocation(forTag: 11)?.key, "userPrefs")
    }

    func testDownloadsDeletesDownloadsNotSpotlight() {
        XCTAssertEqual(cleanLocation(forKey: "downloads")?.path, "~/Downloads/")
        XCTAssertEqual(cleanLocation(forTag: 12)?.key, "downloads")
    }

    func testSpotlightDeletesSpotlightNotDocumentRevisions() {
        XCTAssertEqual(cleanLocation(forKey: "spotlight")?.path, "/.Spotlight-V100/")
        XCTAssertEqual(cleanLocation(forTag: 13)?.key, "spotlight")
    }

    func testDocumentRevisionsDeletesRevisionsNotIMessage() {
        XCTAssertEqual(cleanLocation(forKey: "docRev")?.path, "/.DocumentRevisions-V100/")
        XCTAssertEqual(cleanLocation(forTag: 14)?.key, "docRev")
    }

    func testIMessageResolvesInsteadOfCrashing() {
        XCTAssertEqual(cleanLocation(forKey: "imessage")?.path, "~/Library/Messages/Attachments/")
        XCTAssertEqual(cleanLocation(forTag: 15)?.key, "imessage")
        XCTAssertNil(cleanLocation(forTag: 16), "the old UI index 16 must be out of range, not a crash")
        XCTAssertNil(cleanLocation(forTag: -1))
    }

    func testEveryStoryboardTagResolvesToItsOwnRow() {
        for (index, location) in cleanLocations.enumerated() {
            XCTAssertEqual(cleanLocation(forTag: index)?.key, location.key,
                           "storyboard tag \(index) must open \(location.displayName)")
        }
    }

    func testRootSetMatchesModel() {
        let rootKeys = Set(cleanLocations.filter { $0.requiresRoot }.map { $0.key })
        XCTAssertEqual(rootKeys, Set(["terminal", "systemLogs", "globalTemp", "userPrefs", "docRev", "imessage"]))
    }
}
