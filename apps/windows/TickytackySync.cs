using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Tickytacky.Windows;

public sealed record Session(string AccessToken, string UserId, string? Email);
public sealed record Inbox(string Id);
public sealed record RemoteTask(string Id, string Title, bool IsCompleted, string? DueDate, string Priority);

public static class TickytackySync
{
    public const string Url = "https://fgdmonniblfzapdpxfxc.supabase.co";
    public const string AnonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnZG1vbm5pYmxmemFwZHB4ZnhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxOTUyOTgsImV4cCI6MjEwMjc3MTI5OH0.Rfk-NH5TFeaKObne2V9ildDRBKl3cH7Prtl0vu-EmBk";

    private static readonly HttpClient Http = new();

    public static async Task<Session> Redeem(string key)
    {
        var json = await Post("/functions/v1/sync-key", new { action = "redeem", key }, AnonKey);
        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.TryGetProperty("error", out var err) && err.ValueKind == JsonValueKind.String)
        {
            throw new InvalidOperationException(err.GetString());
        }
        var access = doc.RootElement.GetProperty("access_token").GetString()!;
        return new Session(access, JwtSub(access), null);
    }

    public static async Task<Inbox> EnsureInbox(Session session)
    {
        using var existing = JsonDocument.Parse(
            await Get("/rest/v1/lists?is_inbox=eq.true&deleted_at=is.null&select=*", session)
        );
        if (existing.RootElement.GetArrayLength() > 0)
        {
            return new Inbox(existing.RootElement[0].GetProperty("id").GetString()!);
        }

        var now = DateTime.UtcNow.ToString("o");
        var created = await Post("/rest/v1/lists", new
        {
            id = Guid.NewGuid(),
            user_id = session.UserId,
            name = "Inbox",
            is_inbox = true,
            sort_order = 0,
            created_at = now,
            updated_at = now
        }, session.AccessToken);
        using var doc = JsonDocument.Parse(WrapArray(created));
        return new Inbox(doc.RootElement[0].GetProperty("id").GetString()!);
    }

    public static async Task<IReadOnlyList<RemoteTask>> FetchTasks(Session session)
    {
        using var doc = JsonDocument.Parse(
            await Get("/rest/v1/tasks?deleted_at=is.null&select=*&order=updated_at.desc", session)
        );
        var list = new List<RemoteTask>();
        foreach (var row in doc.RootElement.EnumerateArray())
        {
            list.Add(new RemoteTask(
                row.GetProperty("id").GetString()!,
                row.GetProperty("title").GetString()!,
                row.GetProperty("is_completed").GetBoolean(),
                row.TryGetProperty("due_date", out var due) && due.ValueKind != JsonValueKind.Null ? due.GetString() : null,
                row.TryGetProperty("priority", out var pri) ? pri.GetString() ?? "none" : "none"
            ));
        }
        return list;
    }

    public static async Task AddTask(Session session, string inboxId, string title)
    {
        var now = DateTime.UtcNow.ToString("o");
        await Post("/rest/v1/tasks", new
        {
            id = Guid.NewGuid(),
            user_id = session.UserId,
            list_id = inboxId,
            title = title.Trim(),
            is_completed = false,
            priority = "none",
            due_date = DateTime.UtcNow.ToString("yyyy-MM-dd"),
            sort_order = 0,
            created_at = now,
            updated_at = now
        }, session.AccessToken);
    }

    public static async Task SetCompleted(Session session, RemoteTask task)
    {
        var now = DateTime.UtcNow.ToString("o");
        var next = !task.IsCompleted;
        await Send(HttpMethod.Patch, $"/rest/v1/tasks?id=eq.{task.Id}", new
        {
            is_completed = next,
            completed_at = next ? now : (string?)null,
            updated_at = now
        }, session.AccessToken);
    }

    private static string WrapArray(string json) =>
        json.TrimStart().StartsWith('[') ? json : $"[{json}]";

    private static async Task<string> Get(string path, Session session) =>
        await Send(HttpMethod.Get, path, null, session.AccessToken);

    private static Task<string> Post(string path, object body, string? token) =>
        Send(HttpMethod.Post, path, body, token);

    private static async Task<string> Send(HttpMethod method, string path, object? body, string? token)
    {
        using var request = new HttpRequestMessage(method, Url + path);
        request.Headers.TryAddWithoutValidation("apikey", AnonKey);
        request.Headers.TryAddWithoutValidation("Prefer", "return=representation");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token ?? AnonKey);
        if (body != null)
        {
            request.Content = new StringContent(JsonSerializer.Serialize(body), Encoding.UTF8, "application/json");
        }
        using var response = await Http.SendAsync(request);
        var text = await response.Content.ReadAsStringAsync();
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException(ParseError(text) ?? response.ReasonPhrase ?? "Request failed");
        }
        return text;
    }

    private static string? ParseError(string text)
    {
        try
        {
            using var doc = JsonDocument.Parse(text);
            if (doc.RootElement.TryGetProperty("error", out var err)) return err.GetString();
            if (doc.RootElement.TryGetProperty("msg", out var msg)) return msg.GetString();
            if (doc.RootElement.TryGetProperty("error_description", out var desc)) return desc.GetString();
            if (doc.RootElement.TryGetProperty("message", out var message)) return message.GetString();
        }
        catch
        {
            // raw body
        }
        return string.IsNullOrWhiteSpace(text) ? null : text;
    }

    private static string JwtSub(string accessToken)
    {
        var payload = accessToken.Split('.')[1];
        var padded = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
        var json = Encoding.UTF8.GetString(Convert.FromBase64String(padded.Replace('-', '+').Replace('_', '/')));
        using var doc = JsonDocument.Parse(json);
        return doc.RootElement.GetProperty("sub").GetString()!;
    }
}
