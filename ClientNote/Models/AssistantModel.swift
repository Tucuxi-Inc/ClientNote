import Foundation

public struct AssistantModel {
    public let name: String
    public let modelId: String // For OllamaKit
    public let description: String
    public let size: String
    public let downloadURL: String? // For LlamaKit downloads
    public let llamaKitFileName: String? // The actual filename for LlamaKit
}

extension AssistantModel {
    public static let all = [
        AssistantModel(
            name: "Flash", 
            modelId: "qwen3:0.6b", 
            description: "Ultra-light, speedy assistant for brief sessions", 
            size: "523MB, 40K context window",
            downloadURL: "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_0.gguf?download=true",
            llamaKitFileName: "Qwen3-0.6B-Q4_0.gguf"
        ),
        AssistantModel(
            name: "Scout", 
            modelId: "gemma3:1b", 
            description: "Fast & light, perfect for quick notes & smaller tasks", 
            size: "815MB, 32K context window",
            downloadURL: "https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_0.gguf?download=true",
            llamaKitFileName: "gemma-3-1b-it-Q4_0.gguf"
        ),
        AssistantModel(
            name: "Runner", 
            modelId: "qwen3:1.7b", 
            description: "Agile, balances speed and context size", 
            size: "1.4GB, 40K context window",
            downloadURL: "https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_0.gguf?download=true",
            llamaKitFileName: "Qwen3-1.7B-Q4_0.gguf"
        ),
        AssistantModel(
            name: "Focus", 
            modelId: "granite3.3:2b", 
            description: "Strong contextual understanding, ideal for complex cases", 
            size: "1.5GB, 128K context window",
            downloadURL: "https://huggingface.co/ibm-granite/granite-3.3-2b-instruct-GGUF/resolve/main/granite-3.3-2b-instruct-Q4_0.gguf?download=true",
            llamaKitFileName: "granite-3.3-2b-instruct-Q4_0.gguf"
        ),
        AssistantModel(
            name: "Sage", 
            modelId: "gemma3:4b", 
            description: "Balanced memory & smarts for in-depth note generation", 
            size: "3.3GB, 128K context window",
            downloadURL: "https://huggingface.co/unsloth/gemma-3-4b-it-GGUF/resolve/main/gemma-3-4b-it-Q4_0.gguf?download=true",
            llamaKitFileName: "gemma-3-4b-it-Q4_0.gguf"
        ),
        AssistantModel(
            name: "Deep Thought", 
            modelId: "granite3.3:8b", 
            description: "Powerful, for deep insights and detailed notes", 
            size: "4.9GB, 128K context window",
            downloadURL: "https://huggingface.co/ibm-granite/granite-3.3-8b-instruct-GGUF/resolve/main/granite-3.3-8b-instruct-Q4_0.gguf?download=true",
            llamaKitFileName: "granite-3.3-8b-instruct-Q4_0.gguf"
        )
    ]
    
    public static func nameFor(modelId: String) -> String {
        return all.first(where: { $0.modelId.lowercased() == modelId.lowercased() })?.name ?? modelId
    }
    
    public static func nameFor(fileName: String) -> String {
        return all.first(where: { $0.llamaKitFileName == fileName })?.name ?? fileName
    }
    
    public static func modelIdFor(name: String) -> String {
        return all.first(where: { $0.name == name })?.modelId ?? name
    }
    
    public static func fileNameFor(name: String) -> String? {
        return all.first(where: { $0.name == name })?.llamaKitFileName
    }
    
    public static func modelFor(fileName: String) -> AssistantModel? {
        return all.first(where: { $0.llamaKitFileName == fileName })
    }
} 
