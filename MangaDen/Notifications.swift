//
//  Notifications.swift
//  MangaDen
//
//  Created by Brody Wells on 9/2/25.
//

import Foundation

extension Notification.Name {
    
    static let didUpdateWebViewNav = Notification.Name("didUpdateWebViewNav")
    static let didFindChapterWord = Notification.Name("didFindChapterWord")
    static let didUpdateChapterRange = Notification.Name("didUpdateChapterRange")
    
    static let titleAdded = Notification.Name("titleAdded")
    static let titleAddedSuccess = Notification.Name("titleAddedSuccess")
    static let titleDeleted = Notification.Name("titleDeleted")
}
