package app.tickytacky.android

import org.json.JSONArray
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID

data class Session(val accessToken: String, val userId: String, val email: String?)
data class Inbox(val id: String)
data class RemoteTask(
    val id: String,
    val title: String,
    val isCompleted: Boolean,
    val dueDate: String?,
    val priority: String,
)

object TickytackySync {
    const val url = "https://fgdmonniblfzapdpxfxc.supabase.co"
    const val anonKey =
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZnZG1vbm5pYmxmemFwZHB4ZnhjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxOTUyOTgsImV4cCI6MjEwMjc3MTI5OH0.Rfk-NH5TFeaKObne2V9ildDRBKl3cH7Prtl0vu-EmBk"

    fun redeem(key: String): Session {
        val json = post(
            "/functions/v1/sync-key",
            JSONObject().put("action", "redeem").put("key", key),
            token = anonKey,
        )
        if (json.has("error") && json.getString("error").isNotBlank()) {
            throw IllegalStateException(json.getString("error"))
        }
        val access = json.getString("access_token")
        return Session(accessToken = access, userId = jwtSub(access), email = null)
    }

    fun ensureInbox(session: Session): Inbox {
        fun loadLive(): JSONArray =
            getArray("/rest/v1/lists?is_inbox=eq.true&deleted_at=is.null&select=*", session)
        val existing = loadLive()
        if (existing.length() > 0) {
            return Inbox(existing.getJSONObject(0).getString("id"))
        }
        val now = isoNow()
        val body = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("user_id", session.userId)
            .put("name", "Inbox")
            .put("is_inbox", true)
            .put("sort_order", 0)
            .put("created_at", now)
            .put("updated_at", now)
        return try {
            val created = post("/rest/v1/lists", body, session.accessToken)
            val row = if (created.has("id")) created else created.optJSONArray("0")?.optJSONObject(0)
                ?: JSONArray(created.toString()).getJSONObject(0)
            Inbox(row.getString("id"))
        } catch (err: Exception) {
            val retry = try { loadLive() } catch (_: Exception) { JSONArray() }
            if (retry.length() > 0) Inbox(retry.getJSONObject(0).getString("id"))
            else throw err
        }
    }

    fun fetchTasks(session: Session): List<RemoteTask> {
        val rows = getArray("/rest/v1/tasks?deleted_at=is.null&select=*&order=updated_at.desc", session)
        return buildList {
            for (i in 0 until rows.length()) {
                val row = rows.getJSONObject(i)
                add(
                    RemoteTask(
                        id = row.getString("id"),
                        title = row.getString("title"),
                        isCompleted = row.optBoolean("is_completed"),
                        dueDate = row.optString("due_date").ifBlank { null },
                        priority = row.optString("priority", "none"),
                    )
                )
            }
        }
    }

    fun addTask(session: Session, inboxId: String, title: String): RemoteTask {
        val trimmed = title.trim()
        require(trimmed.isNotEmpty()) { "Title cannot be empty." }
        requireUuid(inboxId)
        val now = isoNow()
        val body = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("user_id", session.userId)
            .put("list_id", inboxId)
            .put("title", trimmed)
            .put("is_completed", false)
            .put("priority", "none")
            .put("due_date", now.take(10))
            .put("sort_order", 0)
            .put("created_at", now)
            .put("updated_at", now)
        val created = post("/rest/v1/tasks", body, session.accessToken)
        val row = firstRow(created)
        return RemoteTask(
            id = row.getString("id"),
            title = row.getString("title"),
            isCompleted = row.optBoolean("is_completed"),
            dueDate = row.optString("due_date").ifBlank { null },
            priority = row.optString("priority", "none"),
        )
    }

    fun setCompleted(session: Session, task: RemoteTask): RemoteTask {
        requireUuid(task.id)
        val now = isoNow()
        val next = !task.isCompleted
        val body = JSONObject()
            .put("is_completed", next)
            .put("completed_at", if (next) now else JSONObject.NULL)
            .put("updated_at", now)
        request("PATCH", "/rest/v1/tasks?id=eq.${task.id}", body, session.accessToken)
        return task.copy(isCompleted = next)
    }

    private val uuidRegex =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")

    private fun requireUuid(id: String) {
        require(uuidRegex.matches(id)) { "Invalid id" }
    }

    private fun jwtSub(token: String): String {
        val payload = token.split(".")[1]
        val padded = payload + "=".repeat((4 - payload.length % 4) % 4)
        val json = String(android.util.Base64.decode(padded, android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP))
        return JSONObject(json).getString("sub")
    }

    private fun firstRow(json: JSONObject): JSONObject {
        if (json.has("id")) return json
        val raw = json.toString()
        if (raw.startsWith("[")) return JSONArray(raw).getJSONObject(0)
        return json
    }

    private fun getArray(path: String, session: Session): JSONArray {
        val text = request("GET", path, null, session.accessToken)
        return JSONArray(text.ifBlank { "[]" })
    }

    private fun post(path: String, body: JSONObject, token: String?): JSONObject {
        val text = request("POST", path, body, token)
        val trimmed = text.trim()
        if (trimmed.startsWith("[")) return JSONArray(trimmed).getJSONObject(0)
        return JSONObject(trimmed.ifBlank { "{}" })
    }

    private fun request(method: String, path: String, body: JSONObject?, token: String?): String {
        val connection = (URL("$url$path").openConnection() as HttpURLConnection).apply {
            applyMethod(if (method == "PATCH") "PATCH" else method)
            setRequestProperty("apikey", anonKey)
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Prefer", "return=representation")
            setRequestProperty("Authorization", "Bearer ${token ?: anonKey}")
            connectTimeout = 20_000
            readTimeout = 20_000
            if (body != null) {
                doOutput = true
                OutputStreamWriter(outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
            }
        }
        val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
        val text = stream?.bufferedReader()?.readText().orEmpty()
        if (connection.responseCode !in 200..299) {
            throw IllegalStateException(parseError(text).ifBlank { connection.responseMessage })
        }
        return text
    }

    private fun HttpURLConnection.applyMethod(method: String) {
        try {
            requestMethod = method
        } catch (_: java.net.ProtocolException) {
            val field = HttpURLConnection::class.java.getDeclaredField("method")
            field.isAccessible = true
            field.set(this, method)
        }
    }

    private fun parseError(text: String): String {
        return try {
            val json = JSONObject(text)
            json.optString("msg").ifBlank {
                json.optString("error_description").ifBlank { json.optString("message", text) }
            }
        } catch (_: Exception) {
            text
        }
    }

    private fun isoNow(): String {
        val millis = System.currentTimeMillis()
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", java.util.Locale.US)
        sdf.timeZone = java.util.TimeZone.getTimeZone("UTC")
        return sdf.format(java.util.Date(millis))
    }
}
