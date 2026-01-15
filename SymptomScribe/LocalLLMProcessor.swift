import Foundation
import LLM  // The eastriverlee/LLM.swift package

class LocalLLMProcessor {
    static let shared = LocalLLMProcessor()
    private var llm: LLM?
    
    // All 25 cardiac symptoms
    static let allSymptoms = [
        "Chest pain at rest",
        "Chest pain on exertion",
        "Chest discomfort",
        "Palpitations",
        "Fatigue at rest",
        "Exertional fatigue",
        "Dyspnea",
        "Orthopnea",
        "Paroxysmal nocturnal dyspnea",
        "Syncope",
        "Lightheadedness",
        "Peripheral edema",
        "Cough / wheezing",
        "Abdominal pain",
        "Early satiety",
        "Diaphoresis",
        "Nausea / vomiting",
        "Anxiety / restlessness",
        "Feeling irregularity of HR",
        "Pulse deficit",
        "Tachycardia",
        "Bradycardia",
        "Dizziness at rest",
        "Dizziness upon standing",
        "Nocturia"
    ]
    
    private let systemPrompt = """
    You extract symptoms from medical notes and output only JSON.
    """
    
    private init() {
        loadModel()
    }
    
    private func loadModel() {
        guard let url = Bundle.main.url(
            forResource: "phi-2.Q4_K_M",
            withExtension: "gguf"
        ) else {
            print("phi-2.Q4_K_M.gguf not found in bundle")
            return
        }
        
        llm = LLM(
            from: url,
            template: .chatML(systemPrompt),
            maxTokenCount: 2048
        )
        print("Phi-2 model loaded successfully")
    }
    
    /// Analyzes transcript and returns JSON with detected symptoms
    func analyzeText(_ transcript: String, completion: @escaping (String?) -> Void) {
        // Reload model to reset state
        loadModel()
        
        guard let llm = llm else {
            print("LLM not yet loaded")
            completion(nil)
            return
        }
        
        let userMessage = buildPrompt(transcript: transcript)
        
        Task.detached {
            let inputSeq = llm.preprocess(userMessage, [])
            let rawOutput = await llm.getCompletion(from: inputSeq)
            
            print("=== RAW LLM OUTPUT ===")
            print(rawOutput)
            print("======================")
            
            let cleanedOutput = self.extractValidJSON(from: rawOutput)
            
            print("=== CLEANED JSON ===")
            print(cleanedOutput ?? "nil")
            print("====================")
            
            DispatchQueue.main.async {
                completion(cleanedOutput)
            }
        }
    }
    
    private func buildPrompt(transcript: String) -> String {
        let symptomsList = allSymptoms.map { "\"\($0)\"" }.joined(separator: ", ")
        return """
        Task: Read the patient note and extract cardiac symptoms with their severity (1-10 scale, where 1 is mild and 10 is severe).
        Output ONLY valid JSON. No explanations.
        
        CRITICAL RULES:
        1. You MUST ONLY use symptom names from the predefined list below. NEVER create new symptom names.
        2. Phrases like "seven out of ten", "8/10", "rating it 5", etc. are SEVERITY RATINGS, NOT symptom names.
        3. Map natural language descriptions to the exact symptom names from the list (e.g., "chest pain" → "Chest pain at rest" or "Chest pain on exertion").
        4. Extract severity numbers from phrases like "seven out of ten" = 7, "8/10" = 8, "rating it 5" = 5.
        
        For each symptom that is mentioned, include:
        - "isPresent": true
        - "severity": a number from 1-10 (or null if severity cannot be determined)
        
        For symptoms NOT mentioned, do NOT include them in the output (they will be marked as absent automatically).
        
        Available symptoms to check (USE ONLY THESE EXACT NAMES):
        [\(symptomsList)]
        
        Example:
        Patient note: "I just had chest pain seven out of ten"
        JSON output:
        {"Chest pain at rest": {"isPresent": true, "severity": 7}}
        
        Example:
        Patient note: "I felt severe chest pain while resting, rating it 8 out of 10, and had mild dizziness when I stood up, maybe a 3"
        JSON output:
        {"Chest pain at rest": {"isPresent": true, "severity": 8}, "Dizziness upon standing": {"isPresent": true, "severity": 3}}
        
        Example:
        Patient note: "Some chest discomfort when walking, not too bad"
        JSON output:
        {"Chest pain on exertion": {"isPresent": true, "severity": null}, "Chest discomfort": {"isPresent": true, "severity": null}}
        
        That was just the example. Now do that process, but for this task:
        Patient note: "\(transcript)"
        JSON output:
        """
    }
    
    // Extract valid JSON object from LLM output
    func extractValidJSON(from rawOutput: String) -> String? {
        let trimmed = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Look for JSON object starting with '{'
        if let startIdx = trimmed.firstIndex(of: "{") {
            var braceCount = 0
            var endIdx: String.Index? = nil
            
            for idx in trimmed[startIdx...].indices {
                if trimmed[idx] == "{" { braceCount += 1 }
                else if trimmed[idx] == "}" { braceCount -= 1 }
                
                if braceCount == 0 {
                    endIdx = idx
                    break
                }
            }
            
            if let endIdx = endIdx {
                return String(trimmed[startIdx...endIdx])
            } else {
                // JSON is incomplete - try to fix it
                print("⚠️ JSON incomplete, attempting repair...")
                var partial = String(trimmed[startIdx...])
                
                // Remove trailing comma if present
                if partial.hasSuffix(",") {
                    partial = String(partial.dropLast())
                }
                
                // Add missing closing brace
                partial += "\n}"
                
                print("🔧 Repaired JSON: \(partial)")
                return partial
            }
        }
        
        return nil
    }
}
