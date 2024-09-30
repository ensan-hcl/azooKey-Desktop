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
// OpenAI APIクライアントクラス
final class OpenAIClient {
    static let shared = OpenAIClient() // シングルトンのインスタンス

    private init() {} // プライベートな初期化子で外部からのインスタンス化を防止

    // APIリクエストを送信するメソッド
    func sendRequest(_ request: OpenAIRequest, apiKey: String, segmentsManager: SegmentsManager) async throws -> [String] {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // JSONボディの設定
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

    // レスポンスデータのパースを行う関数
    private func parseResponseData(_ data: Data, segmentsManager: SegmentsManager) throws -> [String] {
        segmentsManager.appendDebugMessage("Received JSON response") // レスポンスの中身を確認するためのデバッグ出力
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])

            guard let jsonObject = json as? [String: Any],
                  let choices = jsonObject["choices"] as? [[String: Any]] else {
                throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response structure. Received: \(json)"])
            }

            // `content`をJSONとしてパースして`predictions`を抽出
            var allPredictions: [String] = []
            for choice in choices {
                if let message = choice["message"] as? [String: Any],
                   let contentString = message["content"] as? String {

                    segmentsManager.appendDebugMessage("Raw content string: \(contentString)") // 受け取ったcontentの生データを表示

                    // `content`をJSON文字列としてパース
                    // contentString = {"prediction" : [String]}
                    if let contentData = contentString.data(using: .utf8) {
                        do {
                            // JSONオブジェクトをパースし、辞書型[String: [String]]として抽出
                            if let jsonObject = try JSONSerialization.jsonObject(with: contentData, options: []) as? [String: [String]] {
                                // "prediction"キーから予測リストを取得
                                if let predictions = jsonObject["predictions"] {
                                    segmentsManager.appendDebugMessage("Parsed predictions: \(predictions)") // パース成功時のpredictionsを表示
                                    allPredictions.append(contentsOf: predictions)
                                } else {
                                    segmentsManager.appendDebugMessage("Key 'predictions' not found in JSON: \(contentString)")
                                }
                            } else {
                                segmentsManager.appendDebugMessage("Failed to parse `content` as expected JSON dictionary: \(contentString)")
                            }
                        } catch {
                            segmentsManager.appendDebugMessage("Error parsing JSON from `content`: \(error.localizedDescription)")
                        }
                    } else {
                        segmentsManager.appendDebugMessage("Failed to convert `content` string to data")
                    }
                }
            }

            // 予測結果を返す
            return allPredictions
        } catch {
            segmentsManager.appendDebugMessage("Failed to parse JSON response") // エラーメッセージにレスポンスの内容を含める
            throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
    }
}

enum ErrorUnion: Error {
    case nullError
    case double(any Error, any Error)
}

struct ChatRequest: Codable {
    var model: String = "gpt-4o"
    var messages: [Message] = []
}

struct Message: Codable {
    enum Role: String, Codable {
        case user
        case system
        case assistant
    }
    var role: Role
    var content: String
}

struct ChatSuccessResponse: Codable {
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

struct ChatFailureResponse: Codable, Error {
    var error: ErrorResponse
    struct ErrorResponse: Codable {
        var message: String
        var type: String
    }
}
