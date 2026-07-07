using System.Net;
using EndpointMonitorService.Services;

namespace EndpointMonitorService.Hosted;

internal static class LocalPairPage
{
    internal static string Render(string code, DateTime expiresAtLocal, int httpPort, IReadOnlyList<string> lanIps)
    {
        var lan = WebUtility.HtmlEncode(
            lanIps.Count > 0 ? string.Join(", ", lanIps) : "Detect in Windows network settings");
        var safeCode = WebUtility.HtmlEncode(code);
        var expiry = WebUtility.HtmlEncode(expiresAtLocal.ToString("HH:mm · yyyy-MM-dd"));
        return """
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Endpoint Monitor — Pairing</title>
  <style>
    :root { color-scheme: light dark; font-family: "Segoe UI", system-ui, sans-serif; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f4f6fb; color: #1e2332; }
    main { width: min(420px, 92vw); background: #fff; border-radius: 16px; padding: 28px 24px 24px; box-shadow: 0 12px 40px rgba(20,30,60,.12); }
    h1 { margin: 0 0 8px; font-size: 1.25rem; }
    p { margin: 0 0 16px; color: #5a6070; line-height: 1.45; font-size: .95rem; }
    .code { font: 700 2rem/1.2 Consolas, monospace; letter-spacing: .35em; text-align: center; padding: 14px; border: 1px solid #d8deea; border-radius: 10px; background: #fafbfe; color: #19285a; }
    .meta { margin-top: 14px; font-size: .85rem; color: #6a7080; }
    button { margin-top: 18px; border: 0; border-radius: 10px; padding: 10px 14px; background: #1a3f8f; color: #fff; font-weight: 600; cursor: pointer; }
    button.secondary { background: #e8ecf5; color: #1e2332; margin-left: 8px; }
    .ok { color: #0a7a3d; min-height: 1.2em; margin-top: 8px; font-size: .85rem; }
  </style>
</head>
<body>
  <main>
    <h1>Pair your phone</h1>
    <p>Enter this code in the Endpoint Monitor app (Connect screen). This page is only available on this PC.</p>
    <div class="code" id="code">__CODE__</div>
    <div class="meta">Valid until __EXPIRY__<br />LAN IP for the app: __LAN__<br />Agent port: __PORT__</div>
    <div>
      <button type="button" id="copyBtn">Copy code</button>
      <button type="button" class="secondary" onclick="location.reload()">New code</button>
    </div>
    <div class="ok" id="codeMsg"></div>
  </main>
  <script>
    const codeValue = "__CODE_JS__";
    document.getElementById("copyBtn").addEventListener("click", function() {
      navigator.clipboard.writeText(codeValue).then(function() {
        document.getElementById("codeMsg").textContent = "Copied to clipboard.";
      }).catch(function() {
        document.getElementById("codeMsg").textContent = "Copy failed — select the code manually.";
      });
    });
  </script>
</body>
</html>
"""
            .Replace("__CODE__", safeCode, StringComparison.Ordinal)
            .Replace("__EXPIRY__", expiry, StringComparison.Ordinal)
            .Replace("__LAN__", lan, StringComparison.Ordinal)
            .Replace("__PORT__", httpPort.ToString(), StringComparison.Ordinal)
            .Replace("__CODE_JS__", code.Replace("\\", "\\\\").Replace("\"", "\\\""), StringComparison.Ordinal);
    }
}
