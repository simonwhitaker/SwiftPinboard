import Foundation

struct PinboardResponse: Decodable {
    var resultCode: String

    enum CodingKeys: String, CodingKey {
        case resultCode = "result_code"
    }
}

let endpoint = "https://api.pinboard.in/v1"

public enum PinboardClientError: Error {
    case InvalidURL
    case RequestFailed(_ statusCode: Int? = nil)
    case DecodingJSONFailed
    case AuthenticationError
    case UnexpectedResponseCode(_ responseCode: String)
    case UnencodableQueryParam(_ param: String?)
}

@available(macOS 12.0, *)
public struct PinboardClient {
    private var authToken: String?

    public init(authToken: String? = nil) {
        self.authToken = authToken
    }

    func getURLString(path: String, queryArgs: [String: String]) throws -> String {
        assert(path.starts(with: "/"))
        var args = [
            "format": "json",
        ]
        if let authToken = authToken {
            args["auth_token"] = authToken
        }

        args.merge(queryArgs) {(first, _) in first}

        let argString = try args.map({ (key: String, value: String?) in
            guard let encodedValue = value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                throw PinboardClientError.UnencodableQueryParam(value)
            }
            return key + "=" + encodedValue
        })
            .sorted() // makes testing easier 😬
            .joined(separator: "&")
        return endpoint + path + "?" + argString
    }

    func sendRequest(path: String, queryArgs: [String: String]) async throws {
        let urlString = try getURLString(path: path, queryArgs: queryArgs)
        guard let url = URL(string: urlString) else {
            throw PinboardClientError.InvalidURL
        }

        guard let (data, httpResponse) = try? await URLSession.shared.data(from: url) else {
            throw PinboardClientError.RequestFailed()
        }

        let statusCode = (httpResponse as! HTTPURLResponse).statusCode
        if statusCode == 401 {
            throw PinboardClientError.AuthenticationError
        } else if statusCode >= 400 {
            throw PinboardClientError.RequestFailed(statusCode)
        }

        let decoder = JSONDecoder()
        guard let response = try? decoder.decode(PinboardResponse.self, from: data) else {
            throw PinboardClientError.DecodingJSONFailed
        }

        if response.resultCode != "done" {
            throw PinboardClientError.UnexpectedResponseCode(response.resultCode)
        }
    }

    public func addBookmark(
        url: String,
        title: String? = nil,
        description: String? = nil,
        tags: String? = nil,
        isReadLater: Bool = false,
        isPrivate: Bool = true
    ) async throws {
        // https://api.pinboard.in/v1/posts/add
        //    ?auth_token=TOKEN_HERE
        //    &toread=no
        //    &shared=yes
        //    &tags=tag1%20tag2%20tag3
        //    &extended=Description%20Is%20Here
        //    &url=https://netcetera.org/test
        //    &description=Title%20Goes%20Here
        //    &format=json

        var args = [
            "url": url,
            "toread": isReadLater ? "yes" : "no",
            "shared": isPrivate ? "no" : "yes"
        ]
        
        if let title = title {
            args["description"] = title
        }

        if let description = description {
            args["extended"] = description
        }

        if let tags = tags {
            args["tags"] = tags
        }

        try await sendRequest(path: "/posts/add", queryArgs: args)
    }
}
