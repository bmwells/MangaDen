//
//  Notifications.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import Foundation

extension Notification.Name {
    
    // MARK: - WebView & Chapter Management
    static let didUpdateWebViewNav = Notification.Name("didUpdateWebViewNav")
    static let didFindChapterWord = Notification.Name("didFindChapterWord")
    static let didUpdateChapterRange = Notification.Name("didUpdateChapterRange")
    static let chapterReadStatusChanged = Notification.Name("chapterReadStatusChanged")
    static let jsonViewerRefreshRequested = Notification.Name("jsonViewerRefreshRequested")
    
    // MARK: - Title Management
    static let titleAdded = Notification.Name("titleAdded")
    static let titleAddedSuccess = Notification.Name("titleAddedSuccess")
    static let titleDeleted = Notification.Name("titleDeleted")
    static let titleUpdated = Notification.Name("titleUpdated")
    
    // MARK: - Download Operations
    static let downloadStarted = Notification.Name("downloadStarted")
    static let downloadProgress = Notification.Name("downloadProgress")
    static let downloadCompleted = Notification.Name("downloadCompleted")
    static let downloadFailed = Notification.Name("downloadFailed")
    
    // MARK: - Download Queue Management
    static let downloadQueueUpdated = Notification.Name("downloadQueueUpdated")
    static let downloadsPaused = Notification.Name("downloadsPaused")
    static let downloadsResumed = Notification.Name("downloadsResumed")
    
    static let openChapterInReader = Notification.Name("openChapterInReader")
}
