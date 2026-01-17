import ballerina/http;
import ballerina/time;
import ballerina/uuid;

type ProviderPayRequest record {|
    string paymentId;
    decimal amount;
    string currency;
    string reference;
|};

type ProviderPayResponse record {|
    string provider;
    string providerTxnId;
    string status;     // SUCCESS | FAILED
    string message;
    string timestamp;
|};

service / on new http:Listener(9001) {

    resource function post pay(@http:Payload ProviderPayRequest req)
            returns ProviderPayResponse {

        // ✅ mock rule: amounts <= 5000 succeed, else fail
        string status = req.amount <= 5000d ? "SUCCESS" : "FAILED";

        return {
            provider: "dialog",
            providerTxnId: uuid:createType1AsString(),
            status: status,
            message: status == "SUCCESS" ? "Dialog payment successful" : "Dialog payment rejected",
            timestamp: time:utcToString(time:utcNow())
        };
    }

    resource function get health() returns map<string> {
        return { "status": "UP", "provider": "dialog" };
    }
}
