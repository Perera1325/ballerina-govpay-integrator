import ballerina/http;
import ballerina/time;
import ballerina/uuid;

// --------------------
// Models
// --------------------
type PaymentRequest record {|
    decimal amount;
    string currency;
    string provider;   // dialog | genie | bank (Day 3 we implement routing)
    string reference;  // BILL123 / ORDER999
|};

type PaymentRecord record {|
    string paymentId;
    string status;     // PENDING | SUCCESS | FAILED
    decimal amount;
    string currency;
    string provider;
    string reference;
    string createdAt;
|};

// --------------------
// In-memory store (Day 5 we replace with DB)
// --------------------
map<PaymentRecord> paymentStore = {};

// --------------------
// Service
// --------------------
service / on new http:Listener(8080) {

    // ✅ POST /pay  -> Create a payment request
    resource function post pay(@http:Payload PaymentRequest req)
            returns PaymentRecord|http:BadRequest {

        // ✅ Validate amount (decimal comparison must use decimal literal 0d)
        if req.amount <= 0d {
            return <http:BadRequest>{
                body: { "error": "Invalid amount. Amount must be greater than 0." }
            };
        }

        // ✅ Validate required fields
        if req.currency.trim().length() == 0 {
            return <http:BadRequest>{
                body: { "error": "Currency is required. Example: LKR" }
            };
        }

        if req.provider.trim().length() == 0 {
            return <http:BadRequest>{
                body: { "error": "Provider is required. Example: dialog/genie/bank" }
            };
        }

        if req.reference.trim().length() == 0 {
            return <http:BadRequest>{
                body: { "error": "Reference is required. Example: BILL_CEB_10023" }
            };
        }

        // ✅ Generate paymentId
        string paymentId = uuid:createType1AsString();

        // ✅ Create record
        string createdAt = time:utcToString(time:utcNow());

        PaymentRecord rec = {
            paymentId,
            status: "PENDING",
            amount: req.amount,
            currency: req.currency,
            provider: req.provider,
            reference: req.reference,
            createdAt
        };

        // ✅ Store record
        paymentStore[paymentId] = rec;

        return rec;
    }

    // ✅ GET /payments/{id} -> Fetch payment details
    resource function get payments/[string id]()
            returns PaymentRecord|http:NotFound {

        PaymentRecord? rec = paymentStore[id];

        if rec is () {
            return <http:NotFound>{
                body: {
                    "error": "Payment not found",
                    "paymentId": id
                }
            };
        }

        return rec;
    }

    // ✅ GET /health -> Health check
    resource function get health() returns map<string> {
        return {
            "status": "UP",
            "service": "GovPay Integrator - Payment Service"
        };
    }
}
