package app.tickytacky.android

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val Canvas = Color(0xFFF3EBDD)
private val Surface = Color(0xFFFBF6EC)
private val SurfaceInk = Color(0xFFFFFCF6)
private val Ink = Color(0xFF2A2622)
private val InkMuted = Color(0xFF7A7268)
private val InkFaint = Color(0xFFA39A8E)
private val Rule = Color(0xFFD4CBBA)
private val Sage = Color(0xFF7FAF98)
private val SageSoft = Color(0xFFE2F0E8)
private val Overdue = Color(0xFFC47A6C)
private val OnSage = Color(0xFF1F2E28)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent { TickytackyAndroidApp() }
    }
}

@Composable
fun TickytackyAndroidApp() {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var session by remember { mutableStateOf<Session?>(null) }
    var inboxId by remember { mutableStateOf<String?>(null) }
    var tasks by remember { mutableStateOf(listOf<RemoteTask>()) }
    var status by remember { mutableStateOf("") }
    var error by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    val tabs = listOf("Today", "Calendar", "Focus", "Settings")

    fun fail(ex: Exception) {
        error = ex.message ?: "Sync failed"
    }

    fun refresh(current: Session) {
        scope.launch {
            try {
                error = ""
                val loaded = withContext(Dispatchers.IO) {
                    val inbox = TickytackySync.ensureInbox(current)
                    inbox to TickytackySync.fetchTasks(current)
                }
                inboxId = loaded.first.id
                tasks = loaded.second
                status = "Loaded ${loaded.second.size} tasks"
            } catch (ex: Exception) {
                fail(ex)
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Canvas)
            .systemBarsPadding()
            .imePadding()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(6.dp)
                .background(Sage)
        )
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(Surface)
                .padding(horizontal = 20.dp, vertical = 14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Tickytacky Android",
                    color = Ink,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "ANDROID",
                    color = OnSage,
                    fontSize = 11.sp,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier
                        .clip(RoundedCornerShape(999.dp))
                        .background(SageSoft)
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                )
            }
            Text(
                text = "Native Android prototype · syncs via Supabase · not apps/ios",
                color = InkMuted,
                fontSize = 13.sp
            )
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(1.dp)
                .background(Rule)
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(20.dp)
        ) {
            Text(tabs[tab], color = Ink, fontSize = 24.sp, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(6.dp))
            if (error.isNotBlank()) {
                Text(error, color = Overdue, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
            }
            if (status.isNotBlank()) {
                Text(status, color = InkMuted, fontSize = 13.sp)
                Spacer(Modifier.height(8.dp))
            }
            when (tab) {
                0 -> TodayPane(
                    session = session,
                    tasks = tasks,
                    onAdd = { title ->
                        val current = session
                        val inbox = inboxId
                        if (current == null || inbox == null) return@TodayPane
                        scope.launch {
                            try {
                                error = ""
                                val next = withContext(Dispatchers.IO) {
                                    TickytackySync.addTask(current, inbox, title)
                                    TickytackySync.fetchTasks(current)
                                }
                                tasks = next
                                status = "Saved to Supabase"
                            } catch (ex: Exception) {
                                fail(ex)
                            }
                        }
                    },
                    onToggle = { task ->
                        val current = session ?: return@TodayPane
                        scope.launch {
                            try {
                                error = ""
                                val next = withContext(Dispatchers.IO) {
                                    TickytackySync.setCompleted(current, task)
                                    TickytackySync.fetchTasks(current)
                                }
                                tasks = next
                            } catch (ex: Exception) {
                                fail(ex)
                            }
                        }
                    }
                )
                1 -> StubPane("Calendar views are not built on Android yet.")
                2 -> StubPane("Focus timer is not on Android yet. Use the Apple app for Pomodoro.")
                else -> SettingsPane(
                    session = session,
                    onError = { fail(Exception(it)) },
                    onSignedIn = { next ->
                        session = next
                        refresh(next)
                        tab = 0
                    },
                    onSignOut = {
                        session = null
                        inboxId = null
                        tasks = emptyList()
                        status = "Signed out"
                    }
                )
            }
        }
        NavigationBar(containerColor = Surface, contentColor = Ink) {
            tabs.forEachIndexed { index, label ->
                NavigationBarItem(
                    selected = tab == index,
                    onClick = { tab = index },
                    icon = {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(if (tab == index) Sage else InkMuted.copy(alpha = 0.35f))
                        )
                    },
                    label = { Text(label) },
                    colors = NavigationBarItemDefaults.colors(
                        selectedTextColor = Ink,
                        unselectedTextColor = InkMuted,
                        indicatorColor = SageSoft
                    )
                )
            }
        }
    }
}

@Composable
private fun TodayPane(
    session: Session?,
    tasks: List<RemoteTask>,
    onAdd: (String) -> Unit,
    onToggle: (RemoteTask) -> Unit,
) {
    if (session == null) {
        StubPane("Sign in under Settings to load tasks from Supabase.")
        return
    }
    var draft by remember { mutableStateOf("") }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = draft,
            onValueChange = { draft = it },
            modifier = Modifier.weight(1f),
            placeholder = { Text("New task") }
        )
        Button(
            onClick = {
                val title = draft.trim()
                if (title.isNotEmpty()) {
                    onAdd(title)
                    draft = ""
                }
            },
            colors = ButtonDefaults.buttonColors(containerColor = Sage, contentColor = OnSage)
        ) { Text("Add") }
    }
    SectionLabel("Inbox")
    if (tasks.isEmpty()) {
        StubPane("No tasks yet. Add one above.")
    } else {
        tasks.forEach { task ->
            TaskRow(
                title = task.title,
                meta = "${task.dueDate ?: "No date"} · ${task.priority}",
                done = task.isCompleted,
                onClick = { onToggle(task) }
            )
        }
    }
}

@Composable
private fun SettingsPane(
    session: Session?,
    onError: (String) -> Unit,
    onSignedIn: (Session) -> Unit,
    onSignOut: () -> Unit,
) {
    if (session != null) {
        Text("Linked with the Apple-device sync key.", color = Ink)
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = onSignOut,
            colors = ButtonDefaults.buttonColors(containerColor = Sage, contentColor = OnSage)
        ) { Text("Sign out") }
        return
    }
    var key by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    OutlinedTextField(
        value = key,
        onValueChange = { key = it },
        label = { Text("Sync key") },
        modifier = Modifier.fillMaxWidth()
    )
    Spacer(Modifier.height(12.dp))
    Button(
        onClick = {
            scope.launch {
                try {
                    val next = withContext(Dispatchers.IO) { TickytackySync.redeem(key) }
                    onSignedIn(next)
                } catch (ex: Exception) {
                    onError(ex.message ?: "Could not use sync key")
                }
            }
        },
        colors = ButtonDefaults.buttonColors(containerColor = Sage, contentColor = OnSage)
    ) { Text("Connect") }
    Spacer(Modifier.height(8.dp))
    Text("Create the key in Tickytacky on iPhone or Mac (Settings → Create sync key).", color = InkMuted, fontSize = 13.sp)
}

@Composable
private fun StubPane(message: String) {
    Text(
        text = message,
        color = InkMuted,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(Surface)
            .padding(20.dp)
    )
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text = text.uppercase(),
        color = InkMuted,
        fontSize = 12.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier.padding(top = 18.dp, bottom = 8.dp)
    )
}

@Composable
private fun TaskRow(title: String, meta: String, done: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(SurfaceInk)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .padding(top = 2.dp)
                .size(18.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(if (done) Sage else Color.Transparent)
                .border(2.dp, Sage, RoundedCornerShape(4.dp))
        )
        Column {
            Text(
                title,
                color = if (done) InkFaint else Ink,
                fontWeight = FontWeight.Medium,
                textDecoration = if (done) TextDecoration.LineThrough else TextDecoration.None
            )
            Text(meta, color = InkMuted, fontSize = 13.sp)
        }
    }
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp)
            .background(Rule)
    )
}
