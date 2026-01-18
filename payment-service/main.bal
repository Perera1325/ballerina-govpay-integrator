import ballerina/http;
import ballerina/time;
import ballerina/uuid;
import ballerina/log;
import ballerina/io;

// --------------------
// Config
// --------------------
configurable string API_KEY = "govpay-secret-123";
configurable int RATE_LIMIT = 50;

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
    string providerTxnId;
    string providerMessage;
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
string[] paymentIds = []; // keep insert order
map<int> rateStore = {};
final string DATA_FILE = "payments.json";

// --------------------
// Provider clients
// --------------------
final http:Client dialogClient = check new ("http://localhost:9001");
final http:Client genieClient  = check new ("http://localhost:9002");
final http:Client bankClient   = check new ("http://localhost:9003");

// --------------------
// Provider routing
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

// --------------------
// Header helpers
// --------------------
function getHeaderValue(http:Request req, string name) returns string? {
    string|http:HeaderNotFoundError v = req.getHeader(name);
    if v is http:HeaderNotFoundError {
        return ();
    }
    return v;
}

function validateApiKey(http:Request req) returns boolean {
    string? key = getHeaderValue(req, "x-api-key");
    return key is string && key == API_KEY;
}

function rateLimitOk(string apiKey) returns boolean {
    int count = rateStore[apiKey] ?: 0;
    if count >= RATE_LIMIT {
        return false;
    }
    rateStore[apiKey] = count + 1;
    return true;
}

function getCorrelationId(http:Request req) returns string {
    string? cid = getHeaderValue(req, "x-correlation-id");
    if cid is () {
        return uuid:createType1AsString();
    }
    return cid;
}

// --------------------
// Persistence: load/save payments.json
// --------------------
function loadFromFile() {
    string|error content = io:fileReadString(DATA_FILE);
    if content is error {
        log:printInfo("No payments.json found. Starting new.");
        return;
    }

    json|error j = content.fromJsonString();
    if j is error {
        log:printError("payments.json invalid JSON. Starting new.");
        return;
    }

    // Must be json array
    if j is json[] {
        int i = 0;
        while i < j.length() {
            json item = j[i];

            PaymentRecord|error rec = item.cloneWithType(PaymentRecord);
            if rec is PaymentRecord {
                paymentStore[rec.paymentId] = rec;
                paymentIds.push(rec.paymentId);
            }

            i += 1;
        }

        log:printInfo("✅ Loaded payments: " + paymentIds.length().toString());
        return;
    }

    log:printInfo("payments.json not array. Starting new.");
}

function saveToFile() {
    // Convert store -> PaymentRecord[] using paymentIds
    PaymentRecord[] arr = [];

    int i = 0;
    while i < paymentIds.length() {
        string id = paymentIds[i];
        PaymentRecord? rec = paymentStore[id];

        if rec is PaymentRecord {
            arr.push(rec);
        }

        i += 1;
    }

    json j = arr;
    var w = io:fileWriteString(DATA_FILE, j.toJsonString());
    if w is error {
        log:printError("Failed to write payments.json", 'error = w);
    }
}

// --------------------
// Utility: list payments latest first (max 20)
// --------------------
function listPayments(string? provider) returns PaymentRecord[] {
    PaymentRecord[] out = [];

    int i = paymentIds.length() - 1;
    while i >= 0 {
        string id = paymentIds[i];
        PaymentRecord? rec = paymentStore[id];

        if rec is PaymentRecord {
            if provider is string {
                if rec.provider == provider {
                    out.push(rec);
                }
            } else {
                out.push(rec);
            }
        }

        if out.length() >= 20 {
            break;
        }

        i -= 1;
    }

    return out;
}

// --------------------
// Service
// --------------------
service / on new http:Listener(8080) {

    function init() {
        loadFromFile();
    }

    // POST /pay
    resource function post pay(http:Request request, @http:Payload PaymentRequest req)
            returns PaymentRecord|http:Response|http:BadRequest {

        string cid = getCorrelationId(request);

        // Security
        if !validateApiKey(request) {
            http:Response res = new;
            res.statusCode = 401;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Unauthorized. Send x-api-key" });
            return res;
        }

        // Rate limit
        string apiKey = getHeaderValue(request, "x-api-key") ?: "";
        if !rateLimitOk(apiKey) {
            http:Response res = new;
            res.statusCode = 429;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Rate limit exceeded" });
            return res;
        }

        // Validate request
        if req.amount <= 0d {
            return <http:BadRequest>{ body: { "error": "Amount must be > 0" } };
        }

        if req.currency.trim().length() == 0 || req.provider.trim().length() == 0 || req.reference.trim().length() == 0 {
            return <http:BadRequest>{ body: { "error": "currency, provider, reference required" } };
        }

        string provider = req.provider.trim().toLowerAscii();

        string paymentId = uuid:createType1AsString();
        string createdAt = time:utcToString(time:utcNow());

        PaymentRecord rec = {
            paymentId: paymentId,
            status: "PENDING",
            amount: req.amount,
            currency: req.currency,
            provider: provider,
            reference: req.reference,
            createdAt: createdAt,
            providerTxnId: "",
            providerMessage: ""
        };

        // Save initial
        paymentStore[paymentId] = rec;
        paymentIds.push(paymentId);
        saveToFile();

        // Call provider
        ProviderPayRequest pReq = {
            paymentId: paymentId,
            amount: req.amount,
            currency: req.currency,
            reference: req.reference
        };

        ProviderPayResponse|error pRes = callProvider(provider, pReq);

        if pRes is error {
            rec.status = "FAILED";
            rec.providerMessage = pRes.message();

            paymentStore[paymentId] = rec;
            saveToFile();
            return rec;
        }

        // Update record
        rec.status = pRes.status;
        rec.providerTxnId = pRes.providerTxnId;
        rec.providerMessage = pRes.message;

        paymentStore[paymentId] = rec;
        saveToFile();

        log:printInfo("[" + cid + "] Payment saved: " + paymentId);

        return rec;
    }

    // GET /payments/{id}
    resource function get payments/[string id](http:Request request)
            returns PaymentRecord|http:Response|http:NotFound {

        string cid = getCorrelationId(request);

        if !validateApiKey(request) {
            http:Response res = new;
            res.statusCode = 401;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Unauthorized. Send x-api-key" });
            return res;
        }

        PaymentRecord? rec = paymentStore[id];
        if rec is () {
            return <http:NotFound>{ body: { "error": "Payment not found", "paymentId": id } };
        }

        return rec;
    }

    // GET /payments?provider=dialog
    resource function get payments(http:Request request, string? provider)
            returns PaymentRecord[]|http:Response {

        string cid = getCorrelationId(request);

        if !validateApiKey(request) {
            http:Response res = new;
            res.statusCode = 401;
            res.setHeader("x-correlation-id", cid);
            res.setPayload({ "error": "Unauthorized. Send x-api-key" });
            return res;
        }

        return listPayments(provider);
    }

    resource function get health() returns map<string> {
        return { "status": "UP", "service": "GovPay Integrator - Payment Service (Day 5 File Persistence)" };
    }
}
