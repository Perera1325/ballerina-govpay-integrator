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

service / on new http:Listener(9002) {

    resource function post pay(@http:Payload ProviderPayRequest req)
            returns ProviderPayResponse {

        // ✅ mock rule: if reference contains "CEB" => success
        boolean ok = req.reference.toUpperAscii().includes("CEB");
        string status = ok ? "SUCCESS" : "FAILED";

        return {
            provider: "genie",
            providerTxnId: uuid:createType1AsString(),
            status: status,
            message: status == "SUCCESS" ? "Genie payment successful" : "Genie rejected reference",
            timestamp: time:utcToString(time:utcNow())
        };
    }

    resource function get health() returns map<string> {
        return { "status": "UP", "provider": "genie" };
    }
}
