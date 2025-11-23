//
//  LocalLLMProcessor.swift
//  SymptomScribe
//
//  Created by Samay Prabhu on 7/13/25
//

import Foundation
import LLM  // The eastriverlee/LLM.swift package

class LocalLLMProcessor {
    static let shared = LocalLLMProcessor()
    private var llm: LLM?
    
    // Clear, focused system-level instructions
    private let systemPrompt = """
    You are an assistant that extracts symptoms from UserMessage.
    Respond only with ONE valid JSON OBJECT, nothing more. IMPORTANT: return ONLY ONE JSON
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
        
        // Initialize LLM with system prompt
        llm = LLM(
            from: url,
            template: .chatML(systemPrompt),
            maxTokenCount: 1024
        )
        print("Phi-2 model loaded successfully")
    }
    
    /// Sends `transcript` through the model and returns the JSON list string via the completion handler.
    func analyzeText(_ transcript: String, completion: @escaping (String?) -> Void) {
        
        // future edit: reloading everytime is inefficient, so need to find another way to reset
        loadModel()
        
        guard let llm = llm else {
            print("LLM not yet loaded")
            completion(nil)
            return
        }
        
        // User-specific instructions and task
        let userMessage = """
        Extract ONLY symptoms that are verbatim in UserMessage below.
        
        Each array element must be a JSON object with the following keys and types:
          -Chest pain at rest: boolean (true ONLY if mentioned in UserMessage)
          -Chest pain on exertion: boolean (true ONLY if mentioned in UserMessage)
          -Chest discomfort: boolean (true ONLY if mentioned in UserMessage)
          -Palpitations: boolean (true ONLY if mentioned in UserMessage)
          -Fatigue at rest: boolean (true ONLY if mentioned in UserMessage)
          -Exertional fatigue: boolean (true ONLY if mentioned in UserMessage)
          -shortness of breath: boolean (true ONLY if mentioned in UserMessage)
          -lightheadedness: boolean (true ONLY if mentioned in UserMessage)
          -Cough / wheezing: boolean (true ONLY if mentioned in UserMessage)
          -Abdominal pain: boolean (true ONLY if mentioned in UserMessage)
          -sweating: boolean (true ONLY if mentioned in UserMessage)
          -Nausea / vomiting: boolean (true ONLY if mentioned in UserMessage)
          -Anxiety / restlessness: boolean (true ONLY if mentioned in UserMessage)
          -Feeling irregularity of Heart Rate: boolean (true ONLY if mentioned in UserMessage)
          -Pulse deficit: boolean (true ONLY if mentioned in UserMessage)
          -Dizziness at rest: boolean (true ONLY if mentioned in UserMessage)
          -Dizziness upon standing: boolean (true ONLY if mentioned in UserMessage)
        
        UserMessage:
        \"\"\"
        Earlier today when I was resting I felt chest pain and discomfort, later I felt dizzy when I stood up.
        \"\"\"
        
        Output:
        """
        // UserMessage is currently a manually typed transcript rather than the actual transcript for testing purposes. Eventually to be changed back to \(transcript).
        
        Task.detached {
            let inputSeq = llm.preprocess(userMessage, [])
            let rawOutput = await llm.getCompletion(from: inputSeq)
            print("THE RAW OUTPUT:")
            print(rawOutput)
            
            // --- POST-PROCESSING: extract only the first JSON object ---
            var cleanedOutput: String? = nil
            if let startIdx = rawOutput.firstIndex(of: "{") {
                var braceCount = 0
                var endIdx: String.Index? = nil
                for idx in rawOutput[startIdx...].indices {
                    if rawOutput[idx] == "{" {
                        braceCount += 1
                    } else if rawOutput[idx] == "}" {
                        braceCount -= 1
                        if braceCount == 0 {
                            endIdx = idx
                            break
                        }
                    }
                }
                if let endIdx = endIdx {
                    cleanedOutput = String(rawOutput[startIdx...endIdx])
                }
            }
            
            print("CLEANED OUTPUT: ")
            print(cleanedOutput)
            DispatchQueue.main.async {
                completion(cleanedOutput)
            }
        }
    }
}
