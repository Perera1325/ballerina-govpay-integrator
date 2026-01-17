import ballerina/http;
import ballerina/time;
import ballerina/uuid;
import ballerina/log;

// --------------------
// Models
// --------------------
type PaymentRequest record {|
    decimal amount;
    string currency;
    string provider;   // dialog | genie | bank
    string reference;
|};

type PaymentRecord record {|
    string paymentId;
    string status;     // PENDING | SUCCESS | FAILED
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
// In-memory store
// --------------------
map<PaymentRecord> paymentStore = {};

// --------------------
// Provider clients
// --------------------
final http:Client dialogClient = check new ("http://localhost:9001");
final http:Client genieClient  = check new ("http://localhost:9002");
final http:Client bankClient   = check new ("http://localhost:9003");

// --------------------
// Helper
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
// Service
// --------------------
service / on new http:Listener(8080) {

    resource function post pay(@http:Payload PaymentRequest req)
            returns PaymentRecord|http:BadRequest {

        // Validate
        if req.amount <= 0d {
            return <http:BadRequest>{ body: { "error": "Amount must be > 0" } };
        }

        if req.currency.trim().length() == 0 || req.provider.trim().length() == 0 || req.reference.trim().length() == 0 {
            return <http:BadRequest>{
                body: { "error": "currency, provider, reference are required" }
            };
        }

        string provider = req.provider.trim().toLowerAscii();

        // Create record
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
            providerTxnId: (),       // ✅ FIX
            providerMessage: ()      // ✅ FIX
        };

        paymentStore[paymentId] = rec;

        // Call provider
        ProviderPayRequest pReq = {
            paymentId,
            amount: req.amount,
            currency: req.currency,
            reference: req.reference
        };

        ProviderPayResponse|error pRes = callProvider(provider, pReq);

        if pRes is error {
            log:printError("Provider call failed", 'error = pRes);

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

    resource function get payments/[string id]()
            returns PaymentRecord|http:NotFound {

        PaymentRecord? rec = paymentStore[id];

        if rec is () {
            return <http:NotFound>{
                body: { "error": "Payment not found", "paymentId": id }
            };
        }

        return rec;
    }

    resource function get health() returns map<string> {
        return { "status": "UP", "service": "GovPay Integrator - Payment Service" };
    }
}
