import Foundation

enum ActivityType: String, CaseIterable, Identifiable, Codable {
    case all = "All"
    case sessionNote = "Session Note"
    case treatmentPlan = "Treatment Plan"
    case brainstorm = "Brainstorm"

    var id: String { self.rawValue }
}

struct ClientActivity: Identifiable, Equatable, Codable {
    let id: UUID
    var type: ActivityType
    var date: Date
    var content: String
    var title: String?
    
    var displayTitle: String {
        if let customTitle = title, !customTitle.isEmpty {
            return customTitle
        }
        
        // Generate title from content
        if !content.isEmpty {
            let firstLine = content.components(separatedBy: .newlines).first ?? ""
            if !firstLine.isEmpty {
                return String(firstLine.prefix(50)) // Limit to 50 characters
            }
        }
        
        // Fallback to type and date
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        return "\(type.rawValue) - \(dateFormatter.string(from: date))"
    }

    init(type: ActivityType, date: Date = Date(), content: String = "", title: String? = nil) {
        self.id = UUID()
        self.type = type
        self.date = date
        self.content = content
        self.title = title
    }
} 