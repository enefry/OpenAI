//
//  StreamingSession.swift
//
//
//  Created by Sergii Kryvoblotskyi on 18/04/2023.
//

import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

final class StreamingSession<ResultType: Codable>: NSObject, Identifiable, URLSessionDelegate, URLSessionDataDelegate {
    enum StreamingError: Error {
        case unknownContent
        case emptyContent
    }

    var onReceiveContent: ((StreamingSession, ResultType) -> Void)?
    var onProcessingError: ((StreamingSession, Error) -> Void)?
    var onComplete: ((StreamingSession, Error?) -> Void)?

    private let streamingCompletionMarker = "[DONE]"
    private let urlRequest: URLRequest
    private lazy var urlSession: URLSession = {
        let session = URLSession(configuration: sessionConfiguration ?? .default, delegate: self, delegateQueue: nil)
        return session
    }()

    private var previousChunkBuffer = ""
    private let sessionConfiguration: URLSessionConfiguration?
    private var task: URLSessionDataTask?
    init(urlRequest: URLRequest, configuration: URLSessionConfiguration? = nil) {
        sessionConfiguration = configuration
        self.urlRequest = urlRequest
    }

    func perform() {
        let task: URLSessionDataTask = urlSession.dataTask(with: urlRequest)
        task.resume()
        self.task = task
    }

    func cancel() {
        task?.cancel()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        onComplete?(self, error)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let stringContent = String(data: data, encoding: .utf8) else {
            onProcessingError?(self, StreamingError.unknownContent)
            return
        }
        processJSON(from: stringContent)
    }
}

extension StreamingSession {
    private func processJSON(from stringContent: String) {
        let jsonObjects = "\(previousChunkBuffer)\(stringContent)"
            .components(separatedBy: "data:")
            .filter { $0.isEmpty == false }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        previousChunkBuffer = ""

        guard jsonObjects.isEmpty == false, jsonObjects.first != streamingCompletionMarker else {
            return
        }
        jsonObjects.enumerated().forEach { index, jsonContent in
            guard jsonContent != streamingCompletionMarker else {
                return
            }
            guard let jsonData = jsonContent.data(using: .utf8) else {
                onProcessingError?(self, StreamingError.unknownContent)
                return
            }

            var apiError: Error?
            do {
                let decoder = JSONDecoder()
                let object = try decoder.decode(ResultType.self, from: jsonData)
                onReceiveContent?(self, object)
            } catch {
                apiError = error
            }

            if let apiError = apiError {
                do {
                    let decoded = try JSONDecoder().decode(APIErrorResponse.self, from: jsonData)
                    onProcessingError?(self, decoded)
                } catch {
                    if index == jsonObjects.count - 1 {
                        previousChunkBuffer = "data: \(jsonContent)" // Chunk ends in a partial JSON
                    } else {
                        onProcessingError?(self, apiError)
                    }
                }
            }
        }
    }
}
