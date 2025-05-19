import Foundation

public struct AssistantModel {
    public let name: String
    public let modelId: String
    public let description: String
    public let size: String
}

extension AssistantModel {
    public static let all = [
        AssistantModel(name: "Flash", modelId: "qwen3:0.6b", description: "Ultra-light, speedy assistant for brief sessions", size: "523MB, 40K context window"),
        AssistantModel(name: "Scout", modelId: "gemma3:1b", description: "Fast & light, perfect for quick notes & smaller tasks", size: "815MB, 32K context window"),
        AssistantModel(name: "Runner", modelId: "qwen3:1.7b", description: "Agile, balances speed and context size", size: "1.4GB, 40K context window"),
        AssistantModel(name: "Focus", modelId: "granite3.3:2b", description: "Strong contextual understanding, ideal for complex cases", size: "1.5GB, 128K context window"),
        AssistantModel(name: "Sage", modelId: "gemma3:4b", description: "Balanced memory & smarts for in-depth note generation", size: "3.3GB, 128K context window"),
        AssistantModel(name: "Deep Thought", modelId: "granite3.3:8b", description: "Powerful, for deep insights and detailed notes", size: "4.9GB, 128K context window")
    ]
    
    public static func nameFor(modelId: String) -> String {
        return all.first(where: { $0.modelId.lowercased() == modelId.lowercased() })?.name ?? modelId
    }
} 