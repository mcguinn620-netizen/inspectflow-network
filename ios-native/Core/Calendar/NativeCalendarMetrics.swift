//
//  NativeCalendarMetrics.swift
//  AutoInspectorNetwork
//
//  Created by Matt McGuinn on 6/22/26.
//

import Foundation
import SwiftUI

enum NativeCalendarMetrics {
    static let startHour: Int = 0
    static let endHour: Int = 24
    
    static let railWidth: CGFloat = 56
    static let hourHeight: CGFloat = 72
    
    static let laneGap: CGFloat = 2
    static let eventCornerRadius: CGFloat = 8
    static let eventMinimumHeight: CGFloat = 24
    
    static let monthCellMinimumHeight: CGFloat = 58
    static let monthCellPadding: CGFloat = 4
    
    static let majorLineOpacity: CGFloat = 0.16
    static let minorLineOpacity: CGFloat = 0.08
    
    static let dayHeaderPadding: CGFloat = 14
    
    static let subtleBackground = Color(.systemBackground)
    static let sidebarBackground = Color(.systemGroupedBackground)
}
