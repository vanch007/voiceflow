import Foundation

/// Glossary entry for terminology correction
struct GlossaryEntry: Codable, Equatable {
    let term: String        // Phonetic or common misspelling
    let replacement: String // Correct term

    init(term: String, replacement: String) {
        self.term = term
        self.replacement = replacement
    }
}

/// Profile configuration for a scene type
struct SceneProfile: Codable {
    let sceneType: SceneType
    let glossary: [GlossaryEntry]
    let enablePolish: Bool
    let polishStyle: PolishStyle
    let defaultPrompt: String?

    enum PolishStyle: String, Codable {
        case casual
        case formal
        case technical
    }

    /// Default glossaries for each scene type
    static let defaultGlossaries: [SceneType: [GlossaryEntry]] = [
        .general: [],
        .social: [],
        .writing: [],
        .coding: [
            // Programming languages
            GlossaryEntry(term: "python", replacement: "Python"),
            GlossaryEntry(term: "javascript", replacement: "JavaScript"),
            GlossaryEntry(term: "typescript", replacement: "TypeScript"),
            GlossaryEntry(term: "java script", replacement: "JavaScript"),
            GlossaryEntry(term: "type script", replacement: "TypeScript"),

            // Frameworks & Tools
            GlossaryEntry(term: "react", replacement: "React"),
            GlossaryEntry(term: "angular", replacement: "Angular"),
            GlossaryEntry(term: "vue", replacement: "Vue"),
            GlossaryEntry(term: "node", replacement: "Node.js"),
            GlossaryEntry(term: "docker", replacement: "Docker"),
            GlossaryEntry(term: "kubernetes", replacement: "Kubernetes"),
            GlossaryEntry(term: "kube", replacement: "Kubernetes"),

            // Concepts
            GlossaryEntry(term: "api", replacement: "API"),
            GlossaryEntry(term: "rest", replacement: "REST"),
            GlossaryEntry(term: "graphql", replacement: "GraphQL"),
            GlossaryEntry(term: "graph ql", replacement: "GraphQL"),
            GlossaryEntry(term: "json", replacement: "JSON"),
            GlossaryEntry(term: "html", replacement: "HTML"),
            GlossaryEntry(term: "css", replacement: "CSS"),
            GlossaryEntry(term: "sql", replacement: "SQL"),

            // Git & CI/CD
            GlossaryEntry(term: "git", replacement: "Git"),
            GlossaryEntry(term: "github", replacement: "GitHub"),
            GlossaryEntry(term: "gitlab", replacement: "GitLab"),
            GlossaryEntry(term: "ci cd", replacement: "CI/CD"),
            GlossaryEntry(term: "continuous integration", replacement: "continuous integration"),

            // Data structures
            GlossaryEntry(term: "array", replacement: "array"),
            GlossaryEntry(term: "object", replacement: "object"),
            GlossaryEntry(term: "hash map", replacement: "HashMap"),
            GlossaryEntry(term: "linked list", replacement: "linked list")
        ],

        .medical: [
            // Medications
            GlossaryEntry(term: "acetaminophen", replacement: "acetaminophen"),
            GlossaryEntry(term: "ibuprofen", replacement: "ibuprofen"),
            GlossaryEntry(term: "aspirin", replacement: "aspirin"),
            GlossaryEntry(term: "amoxicillin", replacement: "amoxicillin"),
            GlossaryEntry(term: "metformin", replacement: "metformin"),
            GlossaryEntry(term: "lisinopril", replacement: "lisinopril"),
            GlossaryEntry(term: "atorvastatin", replacement: "atorvastatin"),
            GlossaryEntry(term: "amlodipine", replacement: "amlodipine"),
            GlossaryEntry(term: "omeprazole", replacement: "omeprazole"),
            GlossaryEntry(term: "losartan", replacement: "losartan"),
            GlossaryEntry(term: "albuterol", replacement: "albuterol"),
            GlossaryEntry(term: "gabapentin", replacement: "gabapentin"),
            GlossaryEntry(term: "hydrochlorothiazide", replacement: "hydrochlorothiazide"),
            GlossaryEntry(term: "sertraline", replacement: "sertraline"),
            GlossaryEntry(term: "simvastatin", replacement: "simvastatin"),

            // Medical Conditions
            GlossaryEntry(term: "hypertension", replacement: "hypertension"),
            GlossaryEntry(term: "diabetes", replacement: "diabetes"),
            GlossaryEntry(term: "diabetes mellitus", replacement: "diabetes mellitus"),
            GlossaryEntry(term: "myocardial infarction", replacement: "myocardial infarction"),
            GlossaryEntry(term: "cerebrovascular accident", replacement: "cerebrovascular accident"),
            GlossaryEntry(term: "pneumonia", replacement: "pneumonia"),
            GlossaryEntry(term: "asthma", replacement: "asthma"),
            GlossaryEntry(term: "chronic obstructive pulmonary disease", replacement: "chronic obstructive pulmonary disease"),
            GlossaryEntry(term: "copd", replacement: "COPD"),
            GlossaryEntry(term: "congestive heart failure", replacement: "congestive heart failure"),
            GlossaryEntry(term: "atrial fibrillation", replacement: "atrial fibrillation"),
            GlossaryEntry(term: "gastroesophageal reflux disease", replacement: "gastroesophageal reflux disease"),
            GlossaryEntry(term: "gerd", replacement: "GERD"),
            GlossaryEntry(term: "osteoarthritis", replacement: "osteoarthritis"),
            GlossaryEntry(term: "rheumatoid arthritis", replacement: "rheumatoid arthritis"),

            // Anatomy
            GlossaryEntry(term: "myocardial", replacement: "myocardial"),
            GlossaryEntry(term: "cerebral", replacement: "cerebral"),
            GlossaryEntry(term: "pulmonary", replacement: "pulmonary"),
            GlossaryEntry(term: "cardiovascular", replacement: "cardiovascular"),
            GlossaryEntry(term: "gastrointestinal", replacement: "gastrointestinal"),
            GlossaryEntry(term: "respiratory", replacement: "respiratory"),
            GlossaryEntry(term: "hepatic", replacement: "hepatic"),
            GlossaryEntry(term: "renal", replacement: "renal"),
            GlossaryEntry(term: "endocrine", replacement: "endocrine"),
            GlossaryEntry(term: "neurological", replacement: "neurological"),

            // Medical Procedures
            GlossaryEntry(term: "angioplasty", replacement: "angioplasty"),
            GlossaryEntry(term: "catheterization", replacement: "catheterization"),
            GlossaryEntry(term: "endoscopy", replacement: "endoscopy"),
            GlossaryEntry(term: "colonoscopy", replacement: "colonoscopy"),
            GlossaryEntry(term: "bronchoscopy", replacement: "bronchoscopy"),
            GlossaryEntry(term: "intubation", replacement: "intubation"),
            GlossaryEntry(term: "tracheostomy", replacement: "tracheostomy"),
            GlossaryEntry(term: "thoracotomy", replacement: "thoracotomy"),
            GlossaryEntry(term: "laparoscopy", replacement: "laparoscopy"),
            GlossaryEntry(term: "appendectomy", replacement: "appendectomy"),

            // Medical Terms
            GlossaryEntry(term: "diagnosis", replacement: "diagnosis"),
            GlossaryEntry(term: "prognosis", replacement: "prognosis"),
            GlossaryEntry(term: "symptom", replacement: "symptom"),
            GlossaryEntry(term: "syndrome", replacement: "syndrome"),
            GlossaryEntry(term: "pathology", replacement: "pathology"),
            GlossaryEntry(term: "etiology", replacement: "etiology"),
            GlossaryEntry(term: "epidemiology", replacement: "epidemiology"),
            GlossaryEntry(term: "prophylaxis", replacement: "prophylaxis"),
            GlossaryEntry(term: "therapeutic", replacement: "therapeutic"),
            GlossaryEntry(term: "palliative", replacement: "palliative"),
            GlossaryEntry(term: "acute", replacement: "acute"),
            GlossaryEntry(term: "chronic", replacement: "chronic"),
            GlossaryEntry(term: "benign", replacement: "benign"),
            GlossaryEntry(term: "malignant", replacement: "malignant"),
            GlossaryEntry(term: "metastasis", replacement: "metastasis")
        ]
    ]

    /// Default prompts for AI polish
    static let defaultPrompts: [SceneType: String] = [
        .general: "Polish this text for clarity and natural flow.",
        .social: "Make this text casual and conversational, suitable for social media.",
        .coding: "Preserve all technical terminology, code snippets, and version numbers exactly.",
        .writing: "Polish this text for professional writing, improving flow and clarity.",
        .medical: "Preserve all medical terminology exactly. Use formal, professional language appropriate for medical documentation. Ensure accuracy of drug names, conditions, and procedures.",
        .legal: "Preserve all legal terms of art exactly. Use formal, precise language appropriate for legal documentation. Maintain strict accuracy.",
        .technical: "Preserve all technical terminology, acronyms, specifications, and measurements exactly. Use clear, precise technical language.",
        .finance: "Preserve all financial terminology and numerical values exactly. Use formal, precise language appropriate for financial documentation.",
        .engineering: "Preserve all engineering terminology, specifications, measurements, and technical notation exactly. Use precise technical language."
    ]

    /// Get default profile for a scene type
    static func defaultProfile(for sceneType: SceneType) -> SceneProfile {
        let glossary = defaultGlossaries[sceneType] ?? []
        let prompt = defaultPrompts[sceneType]

        switch sceneType {
        case .general:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: true,
                polishStyle: .casual,
                defaultPrompt: prompt
            )
        case .social:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: true,
                polishStyle: .casual,
                defaultPrompt: prompt
            )
        case .coding:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: false,
                polishStyle: .technical,
                defaultPrompt: prompt
            )
        case .writing:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: true,
                polishStyle: .formal,
                defaultPrompt: prompt
            )
        case .medical:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: true,
                polishStyle: .formal,
                defaultPrompt: prompt
            )
        case .legal:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: true,
                polishStyle: .formal,
                defaultPrompt: prompt
            )
        case .technical:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: false,
                polishStyle: .technical,
                defaultPrompt: prompt
            )
        case .finance:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: true,
                polishStyle: .formal,
                defaultPrompt: prompt
            )
        case .engineering:
            return SceneProfile(
                sceneType: sceneType,
                glossary: glossary,
                enablePolish: false,
                polishStyle: .technical,
                defaultPrompt: prompt
            )
        }
    }
}
