using System.Text.Json;

namespace EndpointMonitorService.Commands;

public sealed record CommandResult(bool Success, string Command, string Message, JsonElement? Data = null, int? Pid = null);
