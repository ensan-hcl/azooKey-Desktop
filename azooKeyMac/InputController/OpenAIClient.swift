//
//  OpenAIClient.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Foundation

// OpenAIへのリクエストを表す構造体
struct OpenAIRequest {
    let prompt: String

    // リクエストをJSON形式に変換する関数
    func toJSON() -> [String: Any] {
        [
            "model": "gpt-4o-mini", // Structured Outputs対応モデル
            "messages": [
                ["role": "system", "content": "You are an assistant that predicts the continuation of short text."],
                ["role": "user", "content": """
                I want you to generate possible sentence completions for a given sentence fragment. The output should be a list of different possible endings for the fragment. For example, if I provide "りんごは", you should respond with a list of three possible sentence completions in Japanese, like ["赤いです。", "美味しいです。", "果物です。"]. Keep the completions short and natural. Here is the sentence fragment:

            `\(prompt)`
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
                                    "description": "Predicted continuation of the given text."
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

// OpenAI APIクライアントをenumで実装
enum OpenAIClient {
    // APIリクエストを送信する静的メソッド
    static func sendRequest(_ request: OpenAIRequest, apiKey: String, segmentsManager: SegmentsManager) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = request.toJSON()
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        // 非同期でリクエストを送信
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // レスポンスの検証
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response from server"])
        }

        guard httpResponse.statusCode == 200 else {
            let responseBody = String(decoding: data, as: UTF8.self)
            throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server. Status code: \(httpResponse.statusCode), Response body: \(responseBody)"])
        }

        // レスポンスデータの解析
        return try parseResponseData(data, segmentsManager: segmentsManager)
    }

    // レスポンスデータのパースを行う静的メソッド
    private static func parseResponseData(_ data: Data, segmentsManager: SegmentsManager) throws -> [String] {
        segmentsManager.appendDebugMessage("Received JSON response")

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
        } catch {
            segmentsManager.appendDebugMessage("Failed to parse JSON response")
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }

        guard let jsonDict = jsonObject as? [String: Any],
              let choices = jsonDict["choices"] as? [[String: Any]] else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response structure. Received: \(jsonObject)"])
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
                guard let parsedContent = try JSONSerialization.jsonObject(with: contentData, options: []) as? [String: [String]],
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
