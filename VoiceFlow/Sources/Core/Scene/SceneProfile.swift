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
        ],

        .legal: [
            // Legal Terms of Art
            GlossaryEntry(term: "plaintiff", replacement: "plaintiff"),
            GlossaryEntry(term: "defendant", replacement: "defendant"),
            GlossaryEntry(term: "affidavit", replacement: "affidavit"),
            GlossaryEntry(term: "deposition", replacement: "deposition"),
            GlossaryEntry(term: "subpoena", replacement: "subpoena"),
            GlossaryEntry(term: "habeas corpus", replacement: "habeas corpus"),
            GlossaryEntry(term: "res judicata", replacement: "res judicata"),
            GlossaryEntry(term: "stare decisis", replacement: "stare decisis"),
            GlossaryEntry(term: "prima facie", replacement: "prima facie"),
            GlossaryEntry(term: "voir dire", replacement: "voir dire"),
            GlossaryEntry(term: "amicus curiae", replacement: "amicus curiae"),
            GlossaryEntry(term: "pro bono", replacement: "pro bono"),
            GlossaryEntry(term: "pro se", replacement: "pro se"),
            GlossaryEntry(term: "in camera", replacement: "in camera"),
            GlossaryEntry(term: "ex parte", replacement: "ex parte"),

            // Court Procedures
            GlossaryEntry(term: "summary judgment", replacement: "summary judgment"),
            GlossaryEntry(term: "motion to dismiss", replacement: "motion to dismiss"),
            GlossaryEntry(term: "preliminary injunction", replacement: "preliminary injunction"),
            GlossaryEntry(term: "temporary restraining order", replacement: "temporary restraining order"),
            GlossaryEntry(term: "tro", replacement: "TRO"),
            GlossaryEntry(term: "discovery", replacement: "discovery"),
            GlossaryEntry(term: "interrogatory", replacement: "interrogatory"),
            GlossaryEntry(term: "admissibility", replacement: "admissibility"),
            GlossaryEntry(term: "hearsay", replacement: "hearsay"),
            GlossaryEntry(term: "impeachment", replacement: "impeachment"),
            GlossaryEntry(term: "cross examination", replacement: "cross-examination"),
            GlossaryEntry(term: "direct examination", replacement: "direct examination"),
            GlossaryEntry(term: "sustained", replacement: "sustained"),
            GlossaryEntry(term: "overruled", replacement: "overruled"),

            // Contract Law
            GlossaryEntry(term: "consideration", replacement: "consideration"),
            GlossaryEntry(term: "breach of contract", replacement: "breach of contract"),
            GlossaryEntry(term: "force majeure", replacement: "force majeure"),
            GlossaryEntry(term: "indemnification", replacement: "indemnification"),
            GlossaryEntry(term: "liquidated damages", replacement: "liquidated damages"),
            GlossaryEntry(term: "specific performance", replacement: "specific performance"),
            GlossaryEntry(term: "rescission", replacement: "rescission"),
            GlossaryEntry(term: "warranty", replacement: "warranty"),
            GlossaryEntry(term: "covenant", replacement: "covenant"),
            GlossaryEntry(term: "estoppel", replacement: "estoppel"),

            // Property Law
            GlossaryEntry(term: "easement", replacement: "easement"),
            GlossaryEntry(term: "lien", replacement: "lien"),
            GlossaryEntry(term: "encumbrance", replacement: "encumbrance"),
            GlossaryEntry(term: "adverse possession", replacement: "adverse possession"),
            GlossaryEntry(term: "eminent domain", replacement: "eminent domain"),
            GlossaryEntry(term: "fee simple", replacement: "fee simple"),
            GlossaryEntry(term: "life estate", replacement: "life estate"),
            GlossaryEntry(term: "tenancy in common", replacement: "tenancy in common"),
            GlossaryEntry(term: "joint tenancy", replacement: "joint tenancy"),

            // Criminal Law
            GlossaryEntry(term: "mens rea", replacement: "mens rea"),
            GlossaryEntry(term: "actus reus", replacement: "actus reus"),
            GlossaryEntry(term: "beyond reasonable doubt", replacement: "beyond reasonable doubt"),
            GlossaryEntry(term: "miranda rights", replacement: "Miranda rights"),
            GlossaryEntry(term: "probable cause", replacement: "probable cause"),
            GlossaryEntry(term: "grand jury", replacement: "grand jury"),
            GlossaryEntry(term: "indictment", replacement: "indictment"),
            GlossaryEntry(term: "arraignment", replacement: "arraignment"),
            GlossaryEntry(term: "plea bargain", replacement: "plea bargain"),
            GlossaryEntry(term: "acquittal", replacement: "acquittal"),
            GlossaryEntry(term: "conviction", replacement: "conviction")
        ],

        .technical: [
            // Technical Standards
            GlossaryEntry(term: "iso", replacement: "ISO"),
            GlossaryEntry(term: "ieee", replacement: "IEEE"),
            GlossaryEntry(term: "ansi", replacement: "ANSI"),
            GlossaryEntry(term: "nist", replacement: "NIST"),
            GlossaryEntry(term: "iec", replacement: "IEC"),
            GlossaryEntry(term: "astm", replacement: "ASTM"),
            GlossaryEntry(term: "din", replacement: "DIN"),
            GlossaryEntry(term: "jis", replacement: "JIS"),

            // Protocols & Standards
            GlossaryEntry(term: "tcp ip", replacement: "TCP/IP"),
            GlossaryEntry(term: "http", replacement: "HTTP"),
            GlossaryEntry(term: "https", replacement: "HTTPS"),
            GlossaryEntry(term: "ftp", replacement: "FTP"),
            GlossaryEntry(term: "smtp", replacement: "SMTP"),
            GlossaryEntry(term: "dns", replacement: "DNS"),
            GlossaryEntry(term: "dhcp", replacement: "DHCP"),
            GlossaryEntry(term: "ssh", replacement: "SSH"),
            GlossaryEntry(term: "tls", replacement: "TLS"),
            GlossaryEntry(term: "ssl", replacement: "SSL"),
            GlossaryEntry(term: "vpn", replacement: "VPN"),
            GlossaryEntry(term: "lan", replacement: "LAN"),
            GlossaryEntry(term: "wan", replacement: "WAN"),
            GlossaryEntry(term: "vlan", replacement: "VLAN"),

            // Hardware Components
            GlossaryEntry(term: "cpu", replacement: "CPU"),
            GlossaryEntry(term: "gpu", replacement: "GPU"),
            GlossaryEntry(term: "ram", replacement: "RAM"),
            GlossaryEntry(term: "rom", replacement: "ROM"),
            GlossaryEntry(term: "ssd", replacement: "SSD"),
            GlossaryEntry(term: "hdd", replacement: "HDD"),
            GlossaryEntry(term: "usb", replacement: "USB"),
            GlossaryEntry(term: "pci", replacement: "PCI"),
            GlossaryEntry(term: "bios", replacement: "BIOS"),
            GlossaryEntry(term: "uefi", replacement: "UEFI"),

            // Measurements & Units
            GlossaryEntry(term: "kilobyte", replacement: "kilobyte"),
            GlossaryEntry(term: "megabyte", replacement: "megabyte"),
            GlossaryEntry(term: "gigabyte", replacement: "gigabyte"),
            GlossaryEntry(term: "terabyte", replacement: "terabyte"),
            GlossaryEntry(term: "hertz", replacement: "hertz"),
            GlossaryEntry(term: "megahertz", replacement: "megahertz"),
            GlossaryEntry(term: "gigahertz", replacement: "gigahertz"),
            GlossaryEntry(term: "bandwidth", replacement: "bandwidth"),
            GlossaryEntry(term: "latency", replacement: "latency"),
            GlossaryEntry(term: "throughput", replacement: "throughput"),

            // Software & Systems
            GlossaryEntry(term: "operating system", replacement: "operating system"),
            GlossaryEntry(term: "firmware", replacement: "firmware"),
            GlossaryEntry(term: "middleware", replacement: "middleware"),
            GlossaryEntry(term: "virtualization", replacement: "virtualization"),
            GlossaryEntry(term: "hypervisor", replacement: "hypervisor"),
            GlossaryEntry(term: "container", replacement: "container"),
            GlossaryEntry(term: "microservices", replacement: "microservices"),
            GlossaryEntry(term: "api gateway", replacement: "API gateway"),
            GlossaryEntry(term: "load balancer", replacement: "load balancer"),
            GlossaryEntry(term: "proxy", replacement: "proxy"),
            GlossaryEntry(term: "cache", replacement: "cache"),
            GlossaryEntry(term: "database", replacement: "database"),
            GlossaryEntry(term: "redundancy", replacement: "redundancy"),
            GlossaryEntry(term: "failover", replacement: "failover"),
            GlossaryEntry(term: "scalability", replacement: "scalability"),
            GlossaryEntry(term: "encryption", replacement: "encryption"),
            GlossaryEntry(term: "authentication", replacement: "authentication"),
            GlossaryEntry(term: "authorization", replacement: "authorization")
        ],

        .finance: [
            // Financial Instruments
            GlossaryEntry(term: "stock", replacement: "stock"),
            GlossaryEntry(term: "bond", replacement: "bond"),
            GlossaryEntry(term: "equity", replacement: "equity"),
            GlossaryEntry(term: "derivative", replacement: "derivative"),
            GlossaryEntry(term: "option", replacement: "option"),
            GlossaryEntry(term: "futures", replacement: "futures"),
            GlossaryEntry(term: "swap", replacement: "swap"),
            GlossaryEntry(term: "warrant", replacement: "warrant"),
            GlossaryEntry(term: "mutual fund", replacement: "mutual fund"),
            GlossaryEntry(term: "etf", replacement: "ETF"),
            GlossaryEntry(term: "reit", replacement: "REIT"),
            GlossaryEntry(term: "hedge fund", replacement: "hedge fund"),
            GlossaryEntry(term: "private equity", replacement: "private equity"),
            GlossaryEntry(term: "venture capital", replacement: "venture capital"),

            // Accounting Terms
            GlossaryEntry(term: "assets", replacement: "assets"),
            GlossaryEntry(term: "liabilities", replacement: "liabilities"),
            GlossaryEntry(term: "equity", replacement: "equity"),
            GlossaryEntry(term: "revenue", replacement: "revenue"),
            GlossaryEntry(term: "expense", replacement: "expense"),
            GlossaryEntry(term: "depreciation", replacement: "depreciation"),
            GlossaryEntry(term: "amortization", replacement: "amortization"),
            GlossaryEntry(term: "accrual", replacement: "accrual"),
            GlossaryEntry(term: "deferred revenue", replacement: "deferred revenue"),
            GlossaryEntry(term: "accounts receivable", replacement: "accounts receivable"),
            GlossaryEntry(term: "accounts payable", replacement: "accounts payable"),
            GlossaryEntry(term: "balance sheet", replacement: "balance sheet"),
            GlossaryEntry(term: "income statement", replacement: "income statement"),
            GlossaryEntry(term: "cash flow statement", replacement: "cash flow statement"),
            GlossaryEntry(term: "gaap", replacement: "GAAP"),
            GlossaryEntry(term: "ifrs", replacement: "IFRS"),

            // Investment Terms
            GlossaryEntry(term: "portfolio", replacement: "portfolio"),
            GlossaryEntry(term: "diversification", replacement: "diversification"),
            GlossaryEntry(term: "asset allocation", replacement: "asset allocation"),
            GlossaryEntry(term: "market capitalization", replacement: "market capitalization"),
            GlossaryEntry(term: "dividend", replacement: "dividend"),
            GlossaryEntry(term: "yield", replacement: "yield"),
            GlossaryEntry(term: "return on investment", replacement: "return on investment"),
            GlossaryEntry(term: "roi", replacement: "ROI"),
            GlossaryEntry(term: "alpha", replacement: "alpha"),
            GlossaryEntry(term: "beta", replacement: "beta"),
            GlossaryEntry(term: "volatility", replacement: "volatility"),
            GlossaryEntry(term: "liquidity", replacement: "liquidity"),
            GlossaryEntry(term: "arbitrage", replacement: "arbitrage"),

            // Banking & Finance
            GlossaryEntry(term: "interest rate", replacement: "interest rate"),
            GlossaryEntry(term: "compound interest", replacement: "compound interest"),
            GlossaryEntry(term: "apr", replacement: "APR"),
            GlossaryEntry(term: "apy", replacement: "APY"),
            GlossaryEntry(term: "mortgage", replacement: "mortgage"),
            GlossaryEntry(term: "loan", replacement: "loan"),
            GlossaryEntry(term: "credit", replacement: "credit"),
            GlossaryEntry(term: "debt", replacement: "debt"),
            GlossaryEntry(term: "collateral", replacement: "collateral"),
            GlossaryEntry(term: "leverage", replacement: "leverage"),
            GlossaryEntry(term: "margin", replacement: "margin"),
            GlossaryEntry(term: "default", replacement: "default"),
            GlossaryEntry(term: "bankruptcy", replacement: "bankruptcy"),
            GlossaryEntry(term: "credit rating", replacement: "credit rating"),
            GlossaryEntry(term: "underwriting", replacement: "underwriting"),
            GlossaryEntry(term: "ipo", replacement: "IPO"),
            GlossaryEntry(term: "merger", replacement: "merger"),
            GlossaryEntry(term: "acquisition", replacement: "acquisition")
        ],

        .engineering: [
            // Engineering Disciplines
            GlossaryEntry(term: "mechanical engineering", replacement: "mechanical engineering"),
            GlossaryEntry(term: "electrical engineering", replacement: "electrical engineering"),
            GlossaryEntry(term: "civil engineering", replacement: "civil engineering"),
            GlossaryEntry(term: "chemical engineering", replacement: "chemical engineering"),
            GlossaryEntry(term: "structural engineering", replacement: "structural engineering"),
            GlossaryEntry(term: "aerospace engineering", replacement: "aerospace engineering"),
            GlossaryEntry(term: "automotive engineering", replacement: "automotive engineering"),
            GlossaryEntry(term: "industrial engineering", replacement: "industrial engineering"),

            // Materials
            GlossaryEntry(term: "steel", replacement: "steel"),
            GlossaryEntry(term: "aluminum", replacement: "aluminum"),
            GlossaryEntry(term: "titanium", replacement: "titanium"),
            GlossaryEntry(term: "composite", replacement: "composite"),
            GlossaryEntry(term: "polymer", replacement: "polymer"),
            GlossaryEntry(term: "ceramic", replacement: "ceramic"),
            GlossaryEntry(term: "alloy", replacement: "alloy"),
            GlossaryEntry(term: "carbon fiber", replacement: "carbon fiber"),
            GlossaryEntry(term: "reinforced concrete", replacement: "reinforced concrete"),
            GlossaryEntry(term: "prestressed concrete", replacement: "prestressed concrete"),

            // Processes & Methods
            GlossaryEntry(term: "machining", replacement: "machining"),
            GlossaryEntry(term: "welding", replacement: "welding"),
            GlossaryEntry(term: "casting", replacement: "casting"),
            GlossaryEntry(term: "forging", replacement: "forging"),
            GlossaryEntry(term: "stamping", replacement: "stamping"),
            GlossaryEntry(term: "extrusion", replacement: "extrusion"),
            GlossaryEntry(term: "injection molding", replacement: "injection molding"),
            GlossaryEntry(term: "cnc", replacement: "CNC"),
            GlossaryEntry(term: "cad", replacement: "CAD"),
            GlossaryEntry(term: "cam", replacement: "CAM"),
            GlossaryEntry(term: "finite element analysis", replacement: "finite element analysis"),
            GlossaryEntry(term: "fea", replacement: "FEA"),
            GlossaryEntry(term: "cfd", replacement: "CFD"),

            // Measurements & Specifications
            GlossaryEntry(term: "tolerance", replacement: "tolerance"),
            GlossaryEntry(term: "clearance", replacement: "clearance"),
            GlossaryEntry(term: "interference", replacement: "interference"),
            GlossaryEntry(term: "tensile strength", replacement: "tensile strength"),
            GlossaryEntry(term: "yield strength", replacement: "yield strength"),
            GlossaryEntry(term: "shear stress", replacement: "shear stress"),
            GlossaryEntry(term: "fatigue", replacement: "fatigue"),
            GlossaryEntry(term: "creep", replacement: "creep"),
            GlossaryEntry(term: "hardness", replacement: "hardness"),
            GlossaryEntry(term: "ductility", replacement: "ductility"),
            GlossaryEntry(term: "brittleness", replacement: "brittleness"),
            GlossaryEntry(term: "elasticity", replacement: "elasticity"),
            GlossaryEntry(term: "plasticity", replacement: "plasticity"),

            // Standards & Codes
            GlossaryEntry(term: "asme", replacement: "ASME"),
            GlossaryEntry(term: "sae", replacement: "SAE"),
            GlossaryEntry(term: "aws", replacement: "AWS"),
            GlossaryEntry(term: "aisc", replacement: "AISC"),
            GlossaryEntry(term: "asce", replacement: "ASCE"),
            GlossaryEntry(term: "ashrae", replacement: "ASHRAE"),

            // Systems & Components
            GlossaryEntry(term: "actuator", replacement: "actuator"),
            GlossaryEntry(term: "servo", replacement: "servo"),
            GlossaryEntry(term: "hydraulic", replacement: "hydraulic"),
            GlossaryEntry(term: "pneumatic", replacement: "pneumatic"),
            GlossaryEntry(term: "bearing", replacement: "bearing"),
            GlossaryEntry(term: "gear", replacement: "gear"),
            GlossaryEntry(term: "shaft", replacement: "shaft"),
            GlossaryEntry(term: "coupling", replacement: "coupling"),
            GlossaryEntry(term: "valve", replacement: "valve"),
            GlossaryEntry(term: "pump", replacement: "pump"),
            GlossaryEntry(term: "compressor", replacement: "compressor"),
            GlossaryEntry(term: "turbine", replacement: "turbine"),
            GlossaryEntry(term: "heat exchanger", replacement: "heat exchanger"),
            GlossaryEntry(term: "manifold", replacement: "manifold"),
            GlossaryEntry(term: "sensor", replacement: "sensor"),
            GlossaryEntry(term: "transducer", replacement: "transducer")
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
