//
//  AutoRefreshManager.swift
//  MangaDen
//
//  Created by Brody Wells on 10/1/25.
//

import Foundation


class AutoRefreshManager: ObservableObject {
    static let shared = AutoRefreshManager()
    
    private init() {}
    
    func shouldRefreshTitle(_ title: Title) -> Bool {
        // Only refresh titles that are still releasing
        guard title.status.lowercased() == "releasing" else { return false }
        
        let refreshPeriod = getRefreshPeriod()
        
        // For "On Open", always refresh
        if refreshPeriod == .onOpen {
            return true
        }
        
        // Check last refresh time
        let lastRefreshKey = "lastRefresh_\(title.id.uuidString)"
        let lastRefresh = UserDefaults.standard.double(forKey: lastRefreshKey)
        
        // If never refreshed, return true
        if lastRefresh == 0 {
            return true
        }
        
        let lastRefreshDate = Date(timeIntervalSince1970: lastRefresh)
        let timeSinceLastRefresh = Date().timeIntervalSince(lastRefreshDate)
        
        return timeSinceLastRefresh >= refreshPeriod.timeInterval
    }
    
    func markTitleRefreshed(_ title: Title) {
        let lastRefreshKey = "lastRefresh_\(title.id.uuidString)"
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastRefreshKey)
    }
    
    // Mark refresh attempt (regardless of success/failure)
    func markRefreshAttempt(_ title: Title) {
        markTitleRefreshed(title) 
    }
    
    func getRefreshPeriod() -> RefreshPeriod {
        if let savedPeriod = UserDefaults.standard.string(forKey: "defaultRefreshPeriod"),
           let period = RefreshPeriod(rawValue: savedPeriod) {
            return period
        }
        return .sevenDays // Default to 7 days
    }
    
    func setRefreshPeriod(_ period: RefreshPeriod) {
        UserDefaults.standard.set(period.rawValue, forKey: "defaultRefreshPeriod")
    }
}


// Refresh Periods
enum RefreshPeriod: String, CaseIterable {
    case onOpen = "onOpen"
    case oneDay = "oneDay"
    case sevenDays = "sevenDays"
    case oneMonth = "oneMonth"
    
    var displayName: String {
        switch self {
        case .onOpen: return "On Open"
        case .oneDay: return "1 Day"
        case .sevenDays: return "7 Days"
        case .oneMonth: return "1 Month"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .onOpen: return 0
        case .oneDay: return 24 * 60 * 60 // 1 day
        case .sevenDays: return 7 * 24 * 60 * 60 // 7 days
        case .oneMonth: return 30 * 24 * 60 * 60 // 30 days
        }
    }
}
