import Foundation

struct Client: Identifiable, Equatable, Codable {
    let id: UUID
    var identifier: String
    var name: String
    var gender: String
    var dateOfBirth: Date
    var startOfCare: Date
    var presentingConcerns: String
    var relevantHistory: String
    var presentingSymptoms: String
    var insuranceDiagnosis: String
    var strengths: String
    var obstacles: String
    var longTermGoals: String
    var shortTermGoals: String
    var culturalFactors: String
    var riskAssessment: String
    var additionalNotes: String
    var activities: [ClientActivity]

    init(
        identifier: String,
        name: String = "",
        gender: String = "",
        dateOfBirth: Date = Date(),
        startOfCare: Date = Date(),
        presentingConcerns: String = "",
        relevantHistory: String = "",
        presentingSymptoms: String = "",
        insuranceDiagnosis: String = "",
        strengths: String = "",
        obstacles: String = "",
        longTermGoals: String = "",
        shortTermGoals: String = "",
        culturalFactors: String = "",
        riskAssessment: String = "",
        additionalNotes: String = "",
        activities: [ClientActivity] = []
    ) {
        self.id = UUID()
        self.identifier = identifier
        self.name = name
        self.gender = gender
        self.dateOfBirth = dateOfBirth
        self.startOfCare = startOfCare
        self.presentingConcerns = presentingConcerns
        self.relevantHistory = relevantHistory
        self.presentingSymptoms = presentingSymptoms
        self.insuranceDiagnosis = insuranceDiagnosis
        self.strengths = strengths
        self.obstacles = obstacles
        self.longTermGoals = longTermGoals
        self.shortTermGoals = shortTermGoals
        self.culturalFactors = culturalFactors
        self.riskAssessment = riskAssessment
        self.additionalNotes = additionalNotes
        self.activities = activities
    }
} 