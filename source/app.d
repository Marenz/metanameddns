import std.stdio;



void main ( string[] args )
{
    import vibe.vibe;
    import vibe.http.common;
    import vibe.data.json;
    import std.algorithm;

    if (args.length != 6)
    {
        stderr.writefln("Parameters: %s account_reference api_key tld subdomain new_ip", args[0]);
        return;
    }

    Json rec_map;
    string acc_ref = args[1];
    string api_key = args[2];
    string domain = args[3];
    string subdomain = args[4];
    string myip = args[5];

    auto prepared ( )
    {
        auto obj = Json.emptyObject;

        obj["jsonrpc"] = "2.0";
        obj["id"] = "id";
        obj["params"] = Json.emptyObject;
        obj["params"]["account_reference"] = acc_ref;
        obj["params"]["api_key"] = api_key;

        return obj;
    }

    requestHTTP("https://metaname.net/api/1.1",
            (scope HTTPClientRequest req)
            {
                req.method = HTTPMethod.POST;
                req.contentType = "application/json";

                Json data = prepared();
                data["method"] = "dns_zone";
                data["params"]["domain_name"] = domain;

                req.writeJsonBody(data);
            },
            (scope HTTPClientResponse res)
            {
                auto response = res.bodyReader.readAllUTF8();
                auto json = parseJsonString(response);

                logInfo("Response: %s", json);

                auto rec = json["result"].byValue
                    .find!(a=>a["name"].to!string == subdomain);

                if (rec.empty)
                {
                    logInfo("Couldn't find record %s", args[4]);
                    return;
                }

                logInfo("Found record: %s", rec.front);

                rec_map = rec.front;
            }
            );

    requestHTTP("https://metaname.net/api/1.1",
            (scope HTTPClientRequest req)
            {
                req.method = HTTPMethod.POST;
                req.contentType = "application/json";


                rec_map["data"] = myip;

                Json data = prepared();

                data["method"] = "update_dns_record";
                data["params"]["domain_name"] = domain;
                data["params"]["reference"] = rec_map["reference"];

                rec_map.remove("reference");
                rec_map.remove("aux");
                data["params"]["record"] = rec_map;

                logInfo("Sending: %s", data);
                req.writeJsonBody(data);
            },
            (scope HTTPClientResponse res)
            {
                auto response = res.bodyReader.readAllUTF8();
                auto json = parseJsonString(response);

                logInfo("Response: %s", json);
            }
            );
}
