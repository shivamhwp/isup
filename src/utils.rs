
pub fn get_status_description(status_code: u16) -> &'static str {
    match status_code {
        // 1xx Informational
        100 => "Continue - The server has received the request headers and the client should proceed to send the request body",
        101 => "Switching Protocols - The requester has asked the server to switch protocols",
        102 => "Processing - The server is processing the request but no response is available yet",
        103 => "Early Hints - Used to return some response headers before final HTTP message",
        
        // 2xx Success
        200 => "OK - The request has succeeded",
        201 => "Created - The request has been fulfilled and a new resource has been created",
        202 => "Accepted - The request has been accepted for processing, but processing has not been completed",
        203 => "Non-Authoritative Information - The returned information is from a cached copy",
        204 => "No Content - The request has been successfully processed, but is not returning any content",
        205 => "Reset Content - The request has been successfully processed, the client should reset the document view",
        206 => "Partial Content - The server is delivering only part of the resource due to a range header",
        
        // 3xx Redirection
        300 => "Multiple Choices - The requested resource has multiple choices, each with different locations",
        301 => "Moved Permanently - The requested resource has been permanently moved to a new URL",
        302 => "Found - The requested resource has been temporarily moved to a different URL",
        303 => "See Other - The response to the request can be found under a different URL",
        304 => "Not Modified - The resource has not been modified since the last request",
        307 => "Temporary Redirect - The requested resource has been temporarily moved to a new URL",
        308 => "Permanent Redirect - The requested resource has been permanently moved to a new URL",
        
        // 4xx Client Errors
        400 => "Bad Request - The server cannot process the request due to a client error",
        401 => "Unauthorized - Authentication is required and has failed or not been provided",
        402 => "Payment Required - Reserved for future use",
        403 => "Forbidden - The server understood the request but refuses to authorize it",
        404 => "Not Found - The requested resource could not be found on the server",
        405 => "Method Not Allowed - The request method is not supported for the requested resource",
        406 => "Not Acceptable - The requested resource is capable of generating only content not acceptable according to the Accept headers",
        407 => "Proxy Authentication Required - Authentication with the proxy is required",
        408 => "Request Timeout - The server timed out waiting for the request",
        409 => "Conflict - The request could not be completed due to a conflict with the current state of the resource",
        410 => "Gone - The requested resource is no longer available and will not be available again",
        411 => "Length Required - The request did not specify the length of its content",
        412 => "Precondition Failed - The server does not meet one of the preconditions specified in the request",
        413 => "Payload Too Large - The request is larger than the server is willing or able to process",
        414 => "URI Too Long - The URI provided was too long for the server to process",
        415 => "Unsupported Media Type - The request entity has a media type which the server does not support",
        416 => "Range Not Satisfiable - The client has asked for a portion of the file, but the server cannot supply that portion",
        417 => "Expectation Failed - The server cannot meet the requirements of the Expect request-header field",
        418 => "I'm a teapot - The server refuses to brew coffee because it is a teapot",
        421 => "Misdirected Request - The request was directed at a server that is not able to produce a response",
        422 => "Unprocessable Entity - The request was well-formed but was unable to be followed due to semantic errors",
        423 => "Locked - The resource that is being accessed is locked",
        424 => "Failed Dependency - The request failed due to failure of a previous request",
        425 => "Too Early - The server is unwilling to risk processing a request that might be replayed",
        426 => "Upgrade Required - The client should switch to a different protocol",
        428 => "Precondition Required - The origin server requires the request to be conditional",
        429 => "Too Many Requests - The user has sent too many requests in a given amount of time",
        431 => "Request Header Fields Too Large - The server is unwilling to process the request because its header fields are too large",
        451 => "Unavailable For Legal Reasons - The requested resource is unavailable due to legal reasons",
        
        // 5xx Server Errors
        500 => "Internal Server Error - The server has encountered a situation it doesn't know how to handle",
        501 => "Not Implemented - The request method is not supported by the server",
        502 => "Bad Gateway - The server was acting as a gateway or proxy and received an invalid response from the upstream server",
        503 => "Service Unavailable - The server is currently unavailable (overloaded or down for maintenance)",
        504 => "Gateway Timeout - The server was acting as a gateway or proxy and did not receive a timely response from the upstream server",
        505 => "HTTP Version Not Supported - The server does not support the HTTP protocol version used in the request",
        506 => "Variant Also Negotiates - Transparent content negotiation for the request results in a circular reference",
        507 => "Insufficient Storage - The server is unable to store the representation needed to complete the request",
        508 => "Loop Detected - The server detected an infinite loop while processing the request",
        510 => "Not Extended - Further extensions to the request are required for the server to fulfill it",
        511 => "Network Authentication Required - The client needs to authenticate to gain network access",
        
        // Default for unknown status codes
        _ => "Unknown Status Code",
    }
}
