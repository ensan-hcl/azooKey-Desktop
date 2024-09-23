//
//  OpenAIClient.swift
//  azooKeyMac
//
//  Created by 高橋直希 on 2024/09/21.
//

import Foundation

struct OpenAIRequest {
    let prompt: String
}

class OpenAIClient {
    static let shared = OpenAIClient()

    private init() {}

    func sendRequest(_ request: OpenAIRequest, apiKey: String, segmentsManager: SegmentsManager) async throws -> String {
        // ChatRequest の作成
        let chatRequest = ChatRequest(
            model: "gpt-4o-mini", // 必要に応じて正しいモデル名を設定
            messages: [Message(role: .user, content: request.prompt)]
        )

        // リクエスト送信
        return try await withCheckedThrowingContinuation { continuation in
            performChatRequest(chatRequest, apiKey: apiKey, segmentsManager: segmentsManager) { result in
                switch result {
                case .success(let response):
                    // 成功レスポンスからメッセージを取得
                    if let messageContent = response.choices.first?.message.content {
                        continuation.resume(returning: messageContent.trimmingCharacters(in: .whitespacesAndNewlines))
                    } else {
                        continuation.resume(throwing: NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid Response"]))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

func performChatRequest(_ request: ChatRequest, apiKey: String, segmentsManager: SegmentsManager, handler: @escaping (Result<ChatSuccessResponse, any Error>) -> ()) {
    let encodeResult = Result { try JSONEncoder().encode(request) }
    guard case let .success(encoded) = encodeResult else {
        handler(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode request"])))
        return
    }

    guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
        handler(.failure(NSError(domain: "OpenAIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
        return
    }

    var urlRequest = URLRequest(url: url)
    urlRequest.httpBody = encoded
    urlRequest.httpMethod = "POST"
    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: urlRequest) { data, response, error in
           if let error = error {
               segmentsManager.appendDebugMessage("Error: \(error.localizedDescription)")
               handler(.failure(error))
               return
           }

           if let httpResponse = response as? HTTPURLResponse {
               segmentsManager.appendDebugMessage("Status code: \(httpResponse.statusCode)")
           }

           if let data = data {
               let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
               segmentsManager.appendDebugMessage("Response: \(responseString)")
            do {
                let response = try JSONDecoder().decode(ChatSuccessResponse.self, from: data)
                handler(.success(response))
            } catch let firstError {
                do {
                    let response = try JSONDecoder().decode(ChatFailureResponse.self, from: data)
                    handler(.failure(response))
                } catch let secondError {
                    print("Decoding errors: \(firstError.localizedDescription), \(secondError.localizedDescription)")
                    handler(.failure(ErrorUnion.double(firstError, secondError)))
                }
            }
        } else {
            handler(.failure(ErrorUnion.nullError))
        }
    }.resume()
}


enum ErrorUnion: Error {
    case nullError
    case double(any Error, any Error)
}

struct ChatRequest: Codable {
    var model: String = "gpt-4"
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
        var finish_reason: String
        var message: Message
    }

    struct Usage: Codable {
        var prompt_tokens: Int
        var completion_tokens: Int
        var total_tokens: Int
    }
}

struct ChatFailureResponse: Codable, Error {
    var error: ErrorResponse
    struct ErrorResponse: Codable {
        var message: String
        var type: String
    }
}
