//
//  ActionCommand.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2023-11-20.
//
//  ---------------------------------------------------------------------------
//
//  © 2023 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AppKit

struct ActionCommand: Identifiable {
    
    enum Kind {
        
        case command
        case outline
        case script
    }
    
    let id = UUID()
    
    var kind: Kind
    var title: String
    var paths: [String] = []
    var shortcut: Shortcut?
    
    var action: Selector
    var tag: Int = 0
    var representedObject: Any?
    
    
    /// Perform the original menu action.
    @discardableResult
    func perform() -> Bool {
        
        let sender = NSMenuItem()
        sender.title = self.title
        sender.action = self.action
        sender.tag = self.tag
        sender.representedObject = self.representedObject
        
        return NSApp.sendAction(self.action, to: nil, from: sender)
    }
}


extension ActionCommand {
    
    struct MatchedPath {
        
        var string: String
        var ranges: [Range<String.Index>]
    }
    
    
    func match(command: String) -> (result: [MatchedPath], score: Int)? {
        
        guard !command.isEmpty else { return nil }
        
        var matches: [MatchedPath] = []
        var score = 0
        var remaining = command
        for string in (self.paths[1...] + [self.title]) {
            let match = string.abbreviatedMatch(with: remaining)
            
            if matches.isEmpty, match == nil { continue }
            
            matches.append(.init(string: string, ranges: match?.ranges ?? []))
            score += match?.score ?? 0
            remaining = match?.remaining ?? remaining
        }
        
        guard remaining.isEmpty else { return nil }
        
        return (matches, score)
    }
}


extension NSMenuItem {
    
    /// The flat collection of `ActionCommand` representation including  descendant items.
    var actionCommands: [ActionCommand] {
        
        self.validate()
        
        return if let submenu = self.submenu {
            submenu.items
                .flatMap { $0.actionCommands }
                .map {
                    var command = $0
                    command.paths.insert(self.title, at: 0)
                    return command
                }
            
        } else if self.isEnabled, !self.isHidden, let action = self.action, !ActionCommand.unsupportedActions.contains(action) {
            [ActionCommand(kind: (action == #selector(ScriptManager.launchScript)) ? .script : .command,
                           title: self.title, paths: [], shortcut: self.shortcut, action: action, tag: self.tag, representedObject: self.representedObject)]
            
        } else {
            []
        }
    }
    
    
    /// Validate the menu item so that the menu item properties, such as title, are updated to fit to the latest states.
    private func validate() {
        
        guard
            let validator = self.target
                ?? self.action.flatMap({ NSApp.target(forAction: $0, to: self.target, from: self) }) as AnyObject?
        else { return }
        
        switch validator {
            case let validator as any NSMenuItemValidation:
                validator.validateMenuItem(self)
            case let validator as any NSUserInterfaceValidations:
                validator.validateUserInterfaceItem(self)
            default:
                break
        }
    }
}


private extension ActionCommand {
    
    static let unsupportedActions: [Selector] = [
        #selector(AppDelegate.showQuickActions),
    ]
}
