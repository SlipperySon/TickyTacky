using System.Linq;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;

namespace Tickytacky.Windows;

public partial class MainWindow : Window
{
    private Session? _session;
    private string? _inboxId;
    private IReadOnlyList<RemoteTask> _tasks = [];
    private string _status = "";
    private string _error = "";

    public MainWindow()
    {
        InitializeComponent();
        ShowToday();
    }

    private async void Nav_OnSelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (Pane is null) return;
        var label = (Nav.SelectedItem as ListBoxItem)?.Content?.ToString();
        switch (label)
        {
            case "Today":
                if (_session != null) await RefreshTasks();
                ShowToday();
                break;
            case "Calendar":
                ShowStub("Calendar", "Calendar views are not built on Windows yet.");
                break;
            case "Focus":
                ShowStub("Focus", "Focus timer is not on Windows yet. Use the Apple app for Pomodoro.");
                break;
            default:
                ShowSettings();
                break;
        }
    }

    private void ShowToday()
    {
        Pane.Children.Clear();
        Pane.Children.Add(Heading("Today"));
        Pane.Children.Add(Muted("Inbox tasks from Supabase (same backend as Apple)."));
        AddStatus();
        if (_session is null)
        {
            Pane.Children.Add(Placeholder("Sign in under Settings to load tasks from Supabase."));
            return;
        }

        var row = new DockPanel { Margin = new Thickness(0, 0, 0, 12) };
        var add = new Button { Content = "Add", Margin = new Thickness(8, 0, 0, 0), Padding = new Thickness(12, 6, 12, 6) };
        DockPanel.SetDock(add, Dock.Right);
        var input = new TextBox { MinHeight = 28, Padding = new Thickness(6) };
        add.Click += async (_, _) =>
        {
            if (_session is null || _inboxId is null || string.IsNullOrWhiteSpace(input.Text)) return;
            await Run(async () =>
            {
                await TickytackySync.AddTask(_session, _inboxId, input.Text);
                await RefreshTasks();
                _status = "Saved to Supabase";
            });
            input.Text = "";
            ShowToday();
        };
        row.Children.Add(add);
        row.Children.Add(input);
        Pane.Children.Add(row);
        Pane.Children.Add(Section("Inbox"));
        if (_tasks.Count == 0)
        {
            Pane.Children.Add(Placeholder("No tasks yet. Add one above."));
            return;
        }
        foreach (var task in _tasks)
        {
            var captured = task;
            var card = TaskRow(captured.Title, $"{captured.DueDate ?? "No date"} · {captured.Priority}", captured.IsCompleted);
            card.MouseLeftButtonUp += async (_, _) =>
            {
                if (_session is null) return;
                await Run(async () =>
                {
                    await TickytackySync.SetCompleted(_session, captured);
                    await RefreshTasks();
                });
                ShowToday();
            };
            Pane.Children.Add(card);
        }
    }

    private void ShowSettings()
    {
        Pane.Children.Clear();
        Pane.Children.Add(Heading("Settings"));
        Pane.Children.Add(Muted("Paste the sync key from the Apple app."));
        AddStatus();
        if (_session != null)
        {
            Pane.Children.Add(Muted("Linked with the Apple-device sync key."));
            var signOut = new Button { Content = "Sign out", Margin = new Thickness(0, 12, 0, 0), Padding = new Thickness(12, 6, 12, 6) };
            signOut.Click += (_, _) =>
            {
                _session = null;
                _inboxId = null;
                _tasks = [];
                _status = "Signed out";
                ShowSettings();
            };
            Pane.Children.Add(signOut);
            return;
        }

        var keyBox = new TextBox { MinHeight = 28, Padding = new Thickness(6) };
        var connect = new Button { Content = "Connect", Padding = new Thickness(12, 6, 12, 6), Margin = new Thickness(0, 12, 0, 0) };
        connect.Click += async (_, _) =>
        {
            await Run(async () =>
            {
                _session = await TickytackySync.Redeem(keyBox.Text);
                await RefreshTasks();
                _status = $"Connected · {_tasks.Count} tasks";
            });
            if (_session != null && string.IsNullOrEmpty(_error))
            {
                ShowToday();
                SelectNav("Today");
            }
            else
            {
                ShowSettings();
            }
        };
        Pane.Children.Add(LabelOf("Sync key"));
        Pane.Children.Add(keyBox);
        Pane.Children.Add(connect);
        Pane.Children.Add(Muted("Create the key in Tickytacky on iPhone or Mac (Settings → Create sync key)."));
    }

    private void SelectNav(string label)
    {
        foreach (var item in Nav.Items.OfType<ListBoxItem>())
        {
            if (Equals(item.Content, label))
            {
                Nav.SelectedItem = item;
                break;
            }
        }
    }

    private async Task RefreshTasks()
    {
        if (_session is null) return;
        var inbox = await TickytackySync.EnsureInbox(_session);
        _inboxId = inbox.Id;
        _tasks = await TickytackySync.FetchTasks(_session);
    }

    private async Task Run(Func<Task> work)
    {
        try
        {
            _error = "";
            await work();
        }
        catch (Exception ex)
        {
            _error = ex.Message;
        }
    }

    private void AddStatus()
    {
        if (!string.IsNullOrWhiteSpace(_error))
        {
            Pane.Children.Add(new TextBlock { Text = _error, Foreground = (Brush)FindResource("OverdueBrush"), FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 0, 0, 8) });
        }
        if (!string.IsNullOrWhiteSpace(_status))
        {
            Pane.Children.Add(Muted(_status));
        }
    }

    private void ShowStub(string title, string message)
    {
        Pane.Children.Clear();
        Pane.Children.Add(Heading(title));
        AddStatus();
        Pane.Children.Add(Placeholder(message));
    }

    private Border Placeholder(string message) => new()
    {
        Background = (Brush)FindResource("SurfaceBrush"),
        BorderBrush = (Brush)FindResource("RuleBrush"),
        BorderThickness = new Thickness(1),
        Padding = new Thickness(16),
        CornerRadius = new CornerRadius(8),
        Child = new TextBlock { Text = message, Foreground = (Brush)FindResource("InkMutedBrush"), TextWrapping = TextWrapping.Wrap }
    };

    private static TextBlock Heading(string text) => new()
    {
        Text = text,
        FontSize = 24,
        FontWeight = FontWeights.SemiBold,
        Margin = new Thickness(0, 0, 0, 6)
    };

    private TextBlock Muted(string text) => new()
    {
        Text = text,
        Foreground = (Brush)FindResource("InkMutedBrush"),
        Margin = new Thickness(0, 0, 0, 8),
        TextWrapping = TextWrapping.Wrap
    };

    private TextBlock Section(string text) => new()
    {
        Text = text.ToUpperInvariant(),
        FontSize = 12,
        FontWeight = FontWeights.Bold,
        Foreground = (Brush)FindResource("InkMutedBrush"),
        Margin = new Thickness(0, 16, 0, 8)
    };

    private static TextBlock LabelOf(string text) => new()
    {
        Text = text,
        Margin = new Thickness(0, 8, 0, 4)
    };

    private Border TaskRow(string title, string meta, bool done)
    {
        var check = new Border
        {
            Width = 18,
            Height = 18,
            CornerRadius = new CornerRadius(4),
            BorderBrush = (Brush)FindResource("SageBrush"),
            BorderThickness = new Thickness(2),
            Background = done ? (Brush)FindResource("SageBrush") : Brushes.Transparent,
            Margin = new Thickness(0, 2, 0, 0),
            VerticalAlignment = VerticalAlignment.Top
        };
        var titleBlock = new TextBlock
        {
            Text = title,
            FontWeight = FontWeights.Medium,
            Foreground = done ? (Brush)FindResource("InkFaintBrush") : (Brush)FindResource("InkBrush"),
            TextWrapping = TextWrapping.Wrap
        };
        if (done)
        {
            titleBlock.TextDecorations = TextDecorations.Strikethrough;
        }
        var text = new StackPanel();
        text.Children.Add(titleBlock);
        text.Children.Add(new TextBlock
        {
            Text = meta,
            Foreground = (Brush)FindResource("InkMutedBrush"),
            FontSize = 13
        });
        var row = new DockPanel();
        DockPanel.SetDock(check, Dock.Left);
        row.Children.Add(check);
        row.Children.Add(text);
        check.Margin = new Thickness(0, 2, 12, 0);
        return new Border
        {
            Background = (Brush)FindResource("SurfaceInkBrush"),
            BorderBrush = (Brush)FindResource("RuleBrush"),
            BorderThickness = new Thickness(0, 0, 0, 1),
            Padding = new Thickness(12, 10, 12, 10),
            Cursor = Cursors.Hand,
            Child = row
        };
    }
}
