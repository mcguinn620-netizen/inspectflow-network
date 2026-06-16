//
//  AgendaWidgetExtensionBundle.swift
//  AgendaWidgetExtension
//
//  Created by Matt McGuinn on 6/15/26.
//

import WidgetKit
import SwiftUI

@main
struct AgendaWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        AgendaWidgetExtension()
        AgendaWidgetExtensionLiveActivity()
    }
}
