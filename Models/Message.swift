import Foundation
import UIKit

enum MessageRole {
    case user
    case assistant
    case system
}

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    var content: String
    let timestamp: Date = Date()
    var attachedImage: UIImage? = nil
    var isError: Bool = false

    var isUser: Bool { role == .user }

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.id == rhs.id &&
        lhs.content == rhs.content &&
        lhs.isError == rhs.isError
    }
}
