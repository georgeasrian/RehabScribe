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
        """
        Task: Read the patient note and mark which symptoms are mentioned.
        Output ONLY valid JSON. No explanations.
        
        Example:
        Patient note: "I felt chest pain while resting and was dizzy when I stood up"
        JSON output:
        {"Chest pain at rest": true, "Chest pain on exertion": false, "Chest discomfort": false, "Palpitations": false, "Fatigue at rest": false, "Exertional fatigue": false, "Dyspnea": false, "Orthopnea": false, "Paroxysmal nocturnal dyspnea": false, "Syncope": false, "Lightheadedness": false, "Peripheral edema": false, "Cough / wheezing": false, "Abdominal pain": false, "Early satiety": false, "Diaphoresis": false, "Nausea / vomiting": false, "Anxiety / restlessness": false, "Feeling irregularity of HR": false, "Pulse deficit": false, "Tachycardia": false, "Bradycardia": false, "Dizziness at rest": false, "Dizziness upon standing": true, "Nocturia": false}
        
        Now do this task:
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
            }
        }
        
        return nil
    }
}
