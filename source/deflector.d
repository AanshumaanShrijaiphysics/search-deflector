module deflector;

import common: getConsoleArgs, getBrowserArgs, openUri, createErrorDialog, DeflectorSettings, WIKI_THANKS_URL;
import std.string: replace, indexOf, toLower, startsWith;
import std.uri: decodeComponent, encodeComponent;
import std.regex: matchFirst;
import std.array: split;
import std.conv: to;

version (free_version) {
    import core.thread: Thread;
    import core.time: seconds;
}

debug {
    import core.stdc.stdio: getchar;
    import std.stdio: writeln;
}

void main(string[] args) {
    if (args.length <= 1) {
        createErrorDialog(new Exception(
            "Expected one URI argument, recieved: \n" ~ args.to!string()));

        return;
    }

    try {
        DeflectorSettings.load();

        const string searchTerm = getSearchTerm(args[1]);
        const string browserArgs = getBrowserArgs();

        switch (searchTerm) {
            version (free_version) case "!DisableDonationRequest":
                DeflectorSettings.disableNag = true;
                DeflectorSettings.dump();

                break;
            default:
                openUri(DeflectorSettings.browserPath, browserArgs, rewriteUri(args[1], DeflectorSettings.engineURL));
                DeflectorSettings.searchCount++;
                DeflectorSettings.dump();
        }

        version (free_version) // Makes the donation prompt open on the 10th search and every 20 afterward
        if ((!DeflectorSettings.disableNag && (DeflectorSettings.searchCount - 10) % 20 == 0) || DeflectorSettings.searchCount == 10) {
            Thread.sleep(seconds(5));
            openUri(DeflectorSettings.browserPath, browserArgs, WIKI_THANKS_URL);
        }
    } catch (Exception error) {
        createErrorDialog(error);

        debug writeln(error);
    }

    debug getchar();
}

string getSearchTerm(const string uri) {
    if (!uri.toLower().startsWith("microsoft-edge:"))
        throw new Exception("Not a 'microsoft-edge' URI: " ~ uri);

    const string[string] queryParams = getQueryParams(uri);

    if (queryParams is null || "url" !in queryParams)
        return null;

    const string url = queryParams["url"].decodeComponent();

    if (url.matchFirst(`^https:\/\/.+\.bing.com`))
        return getQueryParams(url)["q"].decodeComponent();
    
    return null;
}

/// Rewrites a "microsoft-edge" URI to something browsers can use.
string rewriteUri(const string uri, const string engineUrl) {
    if (uri.toLower().startsWith("microsoft-edge:")) {
        const string[string] queryParams = getQueryParams(uri);

        if (queryParams !is null && "url" in queryParams) {
            const string url = queryParams["url"].decodeComponent();

            if (url.matchFirst(`^https:\/\/.+\.bing.com`))
                return "https://" ~ engineUrl.replace("{{query}}", getQueryParams(url)["q"]);
            else
                return url;
        } else // Didn't know what to do with the protocol URI, so just search the text same as Edge.
            return engineUrl.replace("{{query}}", uri[15 .. $].encodeComponent());
    } else
        throw new Exception("Not a 'microsoft-edge' URI: " ~ uri);
}

/// Parse the query parameters from a URI and return as an associative array.
string[string] getQueryParams(const string uri) {
    string[string] queryParams;

    const size_t queryStart = uri.indexOf('?');

    if (queryStart == -1)
        return null;

    const string[] paramStrings = uri[queryStart + 1 .. $].split('&');

    foreach (param; paramStrings) {
        const size_t equalsIndex = param.indexOf('=');
        const string key = param[0 .. equalsIndex];
        const string value = param[equalsIndex + 1 .. $];

        queryParams[key] = value;
    }

    return queryParams;
}
