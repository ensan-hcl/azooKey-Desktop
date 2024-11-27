//
//  OpenAIClient.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Foundation

private struct Prompt {
    static let dictionary: [String: String] = [
        "えもじ": "Replace the text enclosed in <> in the article with the most suitable emoji for the previous sentence. Output only the emoji to be replaced.",
        "きごう": "Replace the text enclosed in <> in the article with the most suitable symbol for the previous sentence. Output only the symbol to be replaced.",
        "えいご": "Replace the text enclosed in <> in the article with the most suitable english text for the previous sentence. Output only the english text to be replaced.",
        "てふ": "Replace the text enclosed in <> in the article with the most suitable tex command for the previous sentence. Output only the tex command to be replaced."
    ]

    static let sharedText = " Output multiple candidates."

    static let defaultPrompt = """
        Replace the text enclosed in <> in the article with the most suitable form for the previous sentence. \
        If the same content as the preceding text is received, convert it into a different format \
        (such as symbols, rephrasing, or changing the overall linguistic style) while preserving its meaning. \
        If the text enclosed in <> is a language name, convert the text before the <> to that language. \
        OUTPUT ONLY THE TEXT TO BE REPLACED.
        """

    static func getPromptText(for target: String) -> String {
        let basePrompt = dictionary[target] ?? defaultPrompt
        return basePrompt + sharedText
    }
}

// OpenAIへのリクエストを表す構造体
struct OpenAIRequest {
    let prompt: String
    let target: String

    // リクエストをJSON形式に変換する関数
    func toJSON() -> [String: Any] {
        [
            "model": "gpt-4o-mini", // Structured Outputs対応モデル
            "messages": [
                ["role": "system", "content": "You are an assistant that predicts the continuation of short text."],
                ["role": "user", "content": """
                    \(Prompt.getPromptText(for: target))

                    `\(prompt)<\(target)>`
                    """]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": [
                    "name": "PredictionResponse", // 必須のnameフィールド
                    "schema": [ // 必須のschemaフィールド
                        "type": "object",
                        "properties": [
                            "predictions": [
                                "type": "array",
                                "items": [
                                    "type": "string",
                                    "description": "Replaced text"
                                ]
                            ]
                        ],
                        "required": ["predictions"],
                        "additionalProperties": false
                    ]
                ]
            ]
        ]
    }
}

enum OpenAIError: LocalizedError {
    case invalidURL
    case noServerResponse
    case invalidResponseStatus(code: Int, body: String)
    case parseError(String)
    case invalidResponseStructure(Any)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noServerResponse:
            return "No response from server"
        case .invalidResponseStatus(let code, let body):
            return "Invalid response from server. Status code: \(code), Response body: \(body)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .invalidResponseStructure(let received):
            return "Failed to parse response structure. Received: \(received)"
        }
    }
}

// OpenAI APIクライアント
enum OpenAIClient {
    // APIリクエストを送信する静的メソッド
    static func sendRequest(_ request: OpenAIRequest, apiKey: String, segmentsManager: SegmentsManager) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw OpenAIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = request.toJSON()
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.noServerResponse
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(decoding: data, as: UTF8.self)
            throw OpenAIError.invalidResponseStatus(code: httpResponse.statusCode, body: responseBody)
        }

        return try parseResponseData(data, segmentsManager: segmentsManager)
    }

    // レスポンスデータのパースを行う静的メソッド
    private static func parseResponseData(_ data: Data, segmentsManager: SegmentsManager) throws -> [String] {
        segmentsManager.appendDebugMessage("Received JSON response")

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            segmentsManager.appendDebugMessage("Failed to parse JSON response")
            throw OpenAIError.parseError("Failed to parse response")
        }

        guard let jsonDict = jsonObject as? [String: Any],
              let choices = jsonDict["choices"] as? [[String: Any]] else {
            throw OpenAIError.invalidResponseStructure(jsonObject)
        }

        var allPredictions: [String] = []
        for choice in choices {
            guard let message = choice["message"] as? [String: Any],
                  let contentString = message["content"] as? String else {
                continue
            }

            segmentsManager.appendDebugMessage("Raw content string: \(contentString)")

            guard let contentData = contentString.data(using: .utf8) else {
                segmentsManager.appendDebugMessage("Failed to convert `content` string to data")
                continue
            }

            do {
                guard let parsedContent = try JSONSerialization.jsonObject(with: contentData) as? [String: [String]],
                      let predictions = parsedContent["predictions"] else {
                    segmentsManager.appendDebugMessage("Failed to parse `content` as expected JSON dictionary: \(contentString)")
                    continue
                }

                segmentsManager.appendDebugMessage("Parsed predictions: \(predictions)")
                allPredictions.append(contentsOf: predictions)
            } catch {
                segmentsManager.appendDebugMessage("Error parsing JSON from `content`: \(error.localizedDescription)")
            }
        }

        return allPredictions
    }
}

private enum ErrorUnion: Error {
    case nullError
    case double(any Error, any Error)
}

private struct ChatRequest: Codable {
    var model: String = "gpt-4o-mini"
    var messages: [Message] = []
}

private struct Message: Codable {
    enum Role: String, Codable {
        case user
        case system
        case assistant
    }
    var role: Role
    var content: String
}

private struct ChatSuccessResponse: Codable {
    var id: String
    var object: String
    var created: Int
    var model: String
    var choices: [Choice]

    struct Choice: Codable {
        var index: Int
        var logprobs: Double?
        var finishReason: String
        var message: Message
    }

    struct Usage: Codable {
        var promptTokens: Int
        var completionTokens: Int
        var totalTokens: Int
    }
}

private struct ChatFailureResponse: Codable, Error {
    var error: ErrorResponse
    struct ErrorResponse: Codable {
        var message: String
        var type: String
    }
}
