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
    string status;
    string message;
    string timestamp;
|};

service / on new http:Listener(9003) {

    resource function post pay(@http:Payload ProviderPayRequest req)
            returns ProviderPayResponse {

        // ✅ Always SUCCESS (no random to avoid version issue)
        string status = "SUCCESS";

        return {
            provider: "bank",
            providerTxnId: uuid:createType1AsString(),
            status: status,
            message: "Bank transfer success",
            timestamp: time:utcToString(time:utcNow())
        };
    }

    resource function get health() returns map<string> {
        return { "status": "UP", "provider": "bank" };
    }
}
