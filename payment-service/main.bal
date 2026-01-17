import ballerina/http;
import ballerina/time;
import ballerina/uuid;
import ballerina/log;

// --------------------
// Config
// --------------------
configurable string API_KEY = "govpay-secret-123";
configurable int RATE_LIMIT = 5;

// --------------------
// Models
// --------------------
type PaymentRequest record {|
    decimal amount;
    string currency;
    string provider;
    string reference;
|};

type PaymentRecord record {|
    string paymentId;
    string status;
    decimal amount;
    string currency;
    string provider;
    string reference;
    string createdAt;
    string? providerTxnId;
    string? providerMessage;
|};

type ProviderPayRequest record {|
    string paymentId;
    decimal amount;
    string currency;
    string reference;
|};

type ProviderPayResponse record {|
    string provider;
    string providerTxnId;
    string status;
    string message;
    string timestamp;
|};

// --------------------
// Stores
// --------------------
map<PaymentRecord> paymentStore = {};
map<int> rateStore = {}; // apiKey -> requestCount

// --------------------
// Provider clients
// --------------------
final http:Client dialogClient = check new ("http://localhost:9001");
final http:Client genieClient  = check new ("http://localhost:9002");
final http:Client bankClient   = check new ("http://localhost:9003");

// --------------------
// Helpers
// --------------------
function callProvider(string provider, ProviderPayRequest req)
        returns ProviderPayResponse|error {

    if provider == "dialog" {
        return check dialogClient->post("/pay", req);
    } else if provider == "genie" {
        return check genieClient->post("/pay", req);
    } else if provider == "bank" {
        return check bankClient->post("/pay", req);
    }
    return error("Unsupported provider: " + provider);
}

// ✅ safe get header (works in older Ballerina)
function getHeaderValue(http:Request req, string name) returns string? {
    string|http:HeaderNotFoundError v = req.getHeader(name);
    if v is http:HeaderNotFoundError {
        return ();
    }
    return v;
}

// ✅ correlation id
function getCorrelationId(http:Request req) returns string {
    string? cid = getHeaderValue(req, "x-correlation-id");
    if cid is () {
        return uuid:createType1AsString();
    }
    return cid;
}

// ✅ API key validate
function validateApiKey(http:Request req) returns boolean {
    string? key = getHeaderValue(req, "x-api-key");
    if key is () {
        return false;
    }
    return key == API_KEY;
}

// ✅ simple rate limit: max RATE_LIMIT requests total per key (for demo)
function rateLimitOk(string apiKey) returns boolean {
    int count = rateStore[apiKey] ?: 0;
    if count >= RATE_LIMIT {
        return false;
    }
    rateStore[apiKey] = count + 1;
    return true;
}

// --------------------
// Service
// --------------------
service / on new http:Listener(8080) {

    resource function post pay(http:Request request, @http:Payload PaymentRequest req)
            returns PaymentRecord|http:Response|http:BadRequest {

        string cid = getCorrelationId(request);

        // ✅ API key security
        if !validateApiKey(request) {
            http:Response res = new;
            res.statusCode = 401;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Unauthorized. Missing/invalid x-api-key" });
            return res;
        }

        string apiKey = getHeaderValue(request, "x-api-key") ?: "";

        // ✅ rate limit
        if !rateLimitOk(apiKey) {
            http:Response res = new;
            res.statusCode = 429;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Too Many Requests. Rate limit exceeded." });
            return res;
        }

        // ✅ Validate payload
        if req.amount <= 0d {
            return <http:BadRequest>{ body: { "error": "Amount must be > 0" } };
        }
        if req.currency.trim().length() == 0 || req.provider.trim().length() == 0 || req.reference.trim().length() == 0 {
            return <http:BadRequest>{ body: { "error": "currency, provider, reference are required" } };
        }

        string provider = req.provider.trim().toLowerAscii();

        string paymentId = uuid:createType1AsString();
        string createdAt = time:utcToString(time:utcNow());

        PaymentRecord rec = {
            paymentId,
            status: "PENDING",
            amount: req.amount,
            currency: req.currency,
            provider: provider,
            reference: req.reference,
            createdAt: createdAt,
            providerTxnId: (),
            providerMessage: ()
        };

        paymentStore[paymentId] = rec;

        log:printInfo("[" + cid + "] /pay request => provider=" + provider);

        ProviderPayRequest pReq = {
            paymentId,
            amount: req.amount,
            currency: req.currency,
            reference: req.reference
        };

        ProviderPayResponse|error pRes = callProvider(provider, pReq);

        if pRes is error {
            log:printError("[" + cid + "] Provider call failed", 'error = pRes);

            rec.status = "FAILED";
            rec.providerMessage = pRes.message();
            paymentStore[paymentId] = rec;

            return rec;
        }

        rec.status = pRes.status;
        rec.providerTxnId = pRes.providerTxnId;
        rec.providerMessage = pRes.message;
        paymentStore[paymentId] = rec;

        return rec;
    }

    resource function get payments/[string id](http:Request request)
            returns PaymentRecord|http:Response|http:NotFound {

        string cid = getCorrelationId(request);

        if !validateApiKey(request) {
            http:Response res = new;
            res.statusCode = 401;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Unauthorized. Missing/invalid x-api-key" });
            return res;
        }

        PaymentRecord? rec = paymentStore[id];
        if rec is () {
            return <http:NotFound>{ body: { "error": "Payment not found", "paymentId": id } };
        }

        return rec;
    }

    resource function get health() returns map<string> {
        return { "status": "UP", "service": "GovPay Integrator - Payment Service (Secured)" };
    }
}
