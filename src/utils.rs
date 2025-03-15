use std::collections::HashMap;
use std::sync::OnceLock;

// Get a description for HTTP status codes
pub fn get_status_description(code: u16) -> String {
    static STATUS_DESCRIPTIONS: OnceLock<HashMap<u16, &'static str>> = OnceLock::new();
    
    let descriptions = STATUS_DESCRIPTIONS.get_or_init(|| {
        let mut map = HashMap::new();
        
        // 1xx: Informational
        map.insert(100, "continue");
        map.insert(101, "switching protocols");
        map.insert(102, "processing");
        map.insert(103, "early hints");
        
        // 2xx: Success
        map.insert(200, "ok");
        map.insert(201, "created");
        map.insert(202, "accepted");
        map.insert(203, "non-authoritative");
        map.insert(204, "no content");
        map.insert(205, "reset");
        map.insert(206, "partial");
        map.insert(207, "multi-status");
        map.insert(208, "reported");
        map.insert(226, "im used");
        
        // 3xx: Redirection
        map.insert(300, "multiple choices");
        map.insert(301, "moved");
        map.insert(302, "found");
        map.insert(303, "see other");
        map.insert(304, "not modified");
        map.insert(305, "use proxy");
        map.insert(306, "switch proxy");
        map.insert(307, "temp redirect");
        map.insert(308, "perm redirect");
        
        // 4xx: Client Error
        map.insert(400, "bad request");
        map.insert(401, "unauthorized");
        map.insert(402, "payment required");
        map.insert(403, "forbidden");
        map.insert(404, "not found");
        map.insert(405, "method not allowed");
        map.insert(406, "not acceptable");
        map.insert(407, "proxy auth required");
        map.insert(408, "timeout");
        map.insert(409, "conflict");
        map.insert(410, "gone");
        map.insert(411, "length required");
        map.insert(412, "precondition failed");
        map.insert(413, "payload too large");
        map.insert(414, "uri too long");
        map.insert(415, "unsupported media");
        map.insert(416, "range error");
        map.insert(417, "expectation failed");
        map.insert(418, "teapot");
        map.insert(421, "misdirected");
        map.insert(422, "unprocessable");
        map.insert(423, "locked");
        map.insert(424, "failed dependency");
        map.insert(425, "too early");
        map.insert(426, "upgrade required");
        map.insert(428, "precondition required");
        map.insert(429, "too many requests");
        map.insert(431, "headers too large");
        map.insert(451, "legal reasons");
        
        // 5xx: Server Error
        map.insert(500, "server error");
        map.insert(501, "not implemented");
        map.insert(502, "bad gateway");
        map.insert(503, "unavailable");
        map.insert(504, "gateway timeout");
        map.insert(505, "http version");
        map.insert(506, "variant negotiates");
        map.insert(507, "insufficient storage");
        map.insert(508, "loop detected");
        map.insert(510, "not extended");
        map.insert(511, "network auth");
        
        map
    });
    
    descriptions.get(&code)
        .map(|desc| desc.to_string())
        .unwrap_or_else(|| format!("Unknown Status Code {}", code))
}
