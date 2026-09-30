using System;
using Godot;
using SpacetimeDB;
using SpacetimeDB.Types;

// PROTOTYPE (glacialis #141): does SpacetimeDB.ClientSDK.Godot build and run
// unchanged under Godot.NET.Sdk/4.7.2? Connects to a local `spacetime start`
// server, subscribes to `greeting`, inserts a row, and reports a pass/fail
// marker so a headless run can be graded from stdout alone.
public partial class Connect : Node
{
    private const string Uri = "http://127.0.0.1:3000";
    private const string ModuleName = "proto";
    private const string SeedText = "hello from the seed row";
    private const string OwnText = "hello from the studio seat prototype (glacialis #141)";
    private const double TimeoutSeconds = 30.0;

    private DbConnection? _conn;
    private bool _sawSeed;
    private bool _sawOwn;
    private bool _inserted;
    private bool _done;
    private double _elapsed;

    public override void _Ready()
    {
        GD.Print($"Connect: connecting to {Uri} / {ModuleName}");
        _conn = DbConnection.Builder()
            .WithUri(Uri)
            .WithDatabaseName(ModuleName)
            .OnConnect(OnConnected)
            .OnConnectError(OnConnectError)
            .OnDisconnect(OnDisconnected)
            .Build();
    }

    private void OnConnected(DbConnection conn, Identity identity, string token)
    {
        GD.Print($"Connect: connected as {identity}");
        conn.Db.Greeting.OnInsert += OnGreetingInsert;
        conn.SubscriptionBuilder()
            .OnApplied(OnSubscriptionApplied)
            .Subscribe(new[] { "SELECT * FROM greeting" });
    }

    private void OnConnectError(Exception e)
    {
        GD.PrintErr($"Connect: connect error: {e}");
        Finish(false, "could not connect");
    }

    private void OnDisconnected(DbConnection conn, Exception? e)
    {
        if (e != null)
        {
            GD.PrintErr($"Connect: disconnected abnormally: {e}");
        }
    }

    private void OnSubscriptionApplied(SubscriptionEventContext ctx)
    {
        if (_done)
        {
            return;
        }
        GD.Print("Connect: subscription applied");
        foreach (var row in ctx.Db.Greeting.Iter())
        {
            GD.Print($"Connect: row #{row.Id}: {row.Text}");
            NoteRow(row.Text);
        }

        if (!_inserted)
        {
            _inserted = true;
            GD.Print("Connect: calling AddGreeting");
            ctx.Reducers.AddGreeting(OwnText);
        }

        CheckDone();
    }

    private void OnGreetingInsert(EventContext ctx, Greeting row)
    {
        if (_done)
        {
            return;
        }
        GD.Print($"Connect: row #{row.Id}: {row.Text}");
        NoteRow(row.Text);
        CheckDone();
    }

    private void NoteRow(string text)
    {
        if (text == SeedText)
        {
            _sawSeed = true;
        }
        if (text == OwnText)
        {
            _sawOwn = true;
        }
    }

    private void CheckDone()
    {
        if (_sawSeed && _sawOwn)
        {
            Finish(true, "saw the seed row and our own inserted row");
        }
    }

    private void Finish(bool success, string reason)
    {
        if (_done)
        {
            return;
        }
        _done = true;
        if (success)
        {
            GD.Print($"SUCCESS: {reason}");
        }
        else
        {
            GD.PrintErr($"FAILURE: {reason}");
        }
        _conn?.Disconnect();
        GetTree().Quit(success ? 0 : 1);
    }

    public override void _Process(double delta)
    {
        _conn?.FrameTick();

        if (_done)
        {
            return;
        }

        _elapsed += delta;
        if (_elapsed >= TimeoutSeconds)
        {
            Finish(false, "timed out waiting for the seed row and our own inserted row");
        }
    }
}
