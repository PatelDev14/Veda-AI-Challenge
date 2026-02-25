import Foundation

enum PromptBuilder {
    static func buildFullPrompt(from messages: [Message], latestUserInput: String) -> String {
        var fullText = ""
        
        for msg in messages {
            let prefix = msg.isUser ? "User: " : "Veda: "
            fullText += prefix + msg.content + "\n\n"
        }
        
        fullText += "User: " + latestUserInput + "\nVeda: "
        return fullText
    }
}
