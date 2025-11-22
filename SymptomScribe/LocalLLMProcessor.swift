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
    You are a helpful assistant that extracts structured workout information in JSON format from the given transcript.
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
            maxTokenCount: 512
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
        Extract all workout-related information from the transcript below and return the results as ONLY ONE JSON object.

        Each array element must be a JSON object with the following keys and types:
          - "exercise": the name of the exercise.
          - "muscle_group": the main muscle group(s) used for the exercise (e.g., Chest, Back, Shoulders, etc.).
          - "sets": number of sets performed.
          - "reps": number of repetitions per set, or null if unspecified.
          - "weight": number of pounds, otherwise "body weight".
          - "until_failure": true if user went to failure on any set, otherwise false.
          - "pain_felt": body part where pain was felt (e.g., "shoulder"), or null if none.
          - "matched_exercise": boolean (true only if exercise matches one of these or is close to one of these:
            Supine heel slides, Supine hamstring stretch, Long sitting calf stretch, Quad sets, Sit to stands)

        Transcript:
        \"\"\"
        \(transcript)
        \"\"\"

        Output:
        """

        Task.detached {
            let inputSeq = llm.preprocess(userMessage, [])
            let rawOutput = await llm.getCompletion(from: inputSeq)
            print("THE RAW OUTPUT:")
            print(rawOutput)

            DispatchQueue.main.async {
                completion(rawOutput)
            }
        }
    }
}
