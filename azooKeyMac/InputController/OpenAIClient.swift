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

    func sendRequest(_ request: OpenAIRequest, apiKey: String) async throws -> String {
        // OpenAI APIのエンドポイント
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "Invalid URL", code: 0, userInfo: nil)
        }

        // リクエストの作成
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // リクエストボディの設定
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "user", "content": request.prompt]
            ],
            "temperature": 0.7
        ]

        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // URLSessionを使用してリクエストを送信
        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // HTTPステータスコードのチェック
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorResponse = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API Error", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorResponse])
        }

        // レスポンスの解析
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let choices = jsonResponse?["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            throw NSError(domain: "Invalid Response", code: 0, userInfo: nil)
        }
    }
}

