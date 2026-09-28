//
//  AgentControllerDelegate.swift
//  Clippy macOS
//
//  Created by Devran on 08.09.19.
//  Copyright © 2019 Devran. All rights reserved.
//

import Cocoa

@MainActor
protocol AgentControllerDelegate {
    func willLoadAgent(agent: Agent)
    func didLoadAgent(agent: Agent)
    
    func handleHide()
    func handleShow()
    func handleScaleChange()
}
