import Foundation

struct PinboardResponse: Decodable {
    var resultCode: String

    enum CodingKeys: String, CodingKey {
        case resultCode = "result_code"
    }
}

let endpoint = "https://api.pinboard.in/v1"

enum PinboardClientError: Error {
    case InvalidURL
    case RequestFailed(_ statusCode: Int? = nil)
    case DecodingJSONFailed
    case AuthenticationError
    case UnexpectedResponseCode(_ responseCode: String)
}

@available(macOS 12.0, *)
public struct PinboardClient {
    private var authToken: String?

    public init(authToken: String? = nil) {
        self.authToken = authToken
    }

    func getURLString(path: String, queryArgs: [String: String]) -> String {
        assert(path.starts(with: "/"))
        var args = [
            "format": "json",
        ]
        if let authToken = authToken {
            args["auth_token"] = authToken
        }

        args.merge(queryArgs) {(first, _) in first}

        let argString = args.map({ (key: String, value: String?) in
            [key, value!].joined(separator: "=")
        })
            .sorted() // makes testing easier 😬
            .joined(separator: "&")
        return endpoint + path + "?" + argString
    }

    func sendRequest(path: String, queryArgs: [String: String]) async throws {
        let urlString = getURLString(path: path, queryArgs: queryArgs)
        guard let url = URL(string: urlString) else {
            throw PinboardClientError.InvalidURL
        }

        guard let (data, httpResponse) = try? await URLSession.shared.data(from: url) else {
            throw PinboardClientError.RequestFailed(999)
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

    public func addBookmark(url: String, title: String?, description: String?) async throws {
        // https://api.pinboard.in/v1/posts/add
        //    ?auth_token=TOKEN_HERE
        //    &toread=no
        //    &tags=tag1%20tag2%20tag3
        //    &extended=Description%20Is%20Here
        //    &url=https://netcetera.org/test
        //    &description=Title%20Goes%20Here
        //    &format=json

        var args = ["url": url]
        if let title = title {
            args["description"] = title
        }

        if let description = description {
            args["extended"] = description
        }

        try await sendRequest(path: "/posts/add", queryArgs: args)
    }
}
