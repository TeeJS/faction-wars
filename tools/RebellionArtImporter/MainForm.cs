using System.Diagnostics;

namespace RebellionArtImporter;

/// <summary>One window: where the game is, where the pack is, Import.</summary>
public sealed class MainForm : Form
{
    private readonly TextBox _gameDir = new() { Width = 520 };
    private readonly TextBox _packDir = new() { Width = 520 };
    private readonly Button _import = new() { Text = "Import", Width = 120, Height = 32 };
    private readonly Button _open = new() { Text = "Open output folder", Width = 160, Height = 32, Enabled = false };
    private readonly TextBox _log = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Width = 640, Height = 260, Font = new Font("Consolas", 9f) };

    public MainForm()
    {
        Text = "Faction Wars - Rebellion Art Importer";
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        ClientSize = new Size(670, 470);
        AutoScaleMode = AutoScaleMode.Dpi;

        var intro = new Label
        {
            Text = "Copies the Encyclopedia pictures and descriptions from YOUR copy of Star Wars: Rebellion (GOG, Steam or the original CD) " +
                   "into the Faction Wars pack (packs\\star-wars-rebellion\\original). Nothing is downloaded and nothing leaves this machine.",
            AutoSize = false, Width = 640, Height = 48, Location = new Point(15, 12),
        };
        Controls.Add(intro);

        Controls.Add(Row("Game folder:", _gameDir, 64, () => Browse(_gameDir, "Pick the folder Star Wars: Rebellion is installed in (it holds REBEXE.EXE and EData), or the REBELLION folder on the CD")));
        Controls.Add(Row("Pack folder:", _packDir, 100, () => Browse(_packDir, "Pick packs\\star-wars-rebellion inside Faction Wars")));

        _import.Location = new Point(15, 140);
        _import.Click += (_, _) => RunImport();
        Controls.Add(_import);
        _open.Location = new Point(145, 140);
        _open.Click += (_, _) => Process.Start(new ProcessStartInfo(Path.Combine(_packDir.Text, "original")) { UseShellExecute = true });
        Controls.Add(_open);

        _log.Location = new Point(15, 185);
        Controls.Add(_log);

        _gameDir.Text = Defaults.GameDir();
        _packDir.Text = Defaults.PackDir();
    }

    private Control Row(string caption, TextBox box, int y, Action browse)
    {
        var panel = new Panel { Location = new Point(15, y), Width = 640, Height = 30 };
        panel.Controls.Add(new Label { Text = caption, Location = new Point(0, 6), AutoSize = true });
        box.Location = new Point(105, 3);
        box.Width = 450;
        panel.Controls.Add(box);
        var b = new Button { Text = "Browse...", Location = new Point(562, 1), Width = 78, Height = 26 };
        b.Click += (_, _) => browse();
        panel.Controls.Add(b);
        return panel;
    }

    private void Browse(TextBox box, string description)
    {
        using var dlg = new FolderBrowserDialog { Description = description, UseDescriptionForTitle = true, InitialDirectory = Directory.Exists(box.Text) ? box.Text : "" };
        if (dlg.ShowDialog(this) == DialogResult.OK)
            box.Text = dlg.SelectedPath;
    }

    private void RunImport()
    {
        _log.Clear();
        var problem = Importer.Problem(_gameDir.Text, _packDir.Text);
        if (problem != null)
        {
            _log.Text = problem;
            return;
        }
        _import.Enabled = false;
        try
        {
            var importer = new Importer(_gameDir.Text, _packDir.Text, line => { _log.AppendText(line + Environment.NewLine); Application.DoEvents(); });
            var result = importer.Run();
            foreach (var m in result.Missing)
                _log.AppendText("  - " + m + Environment.NewLine);
            _log.AppendText(Environment.NewLine + "Done." + Environment.NewLine);
            _log.SelectionStart = _log.TextLength;
            _log.ScrollToCaret();
            _open.Enabled = true;
        }
        catch (Exception ex)
        {
            _log.AppendText("FAILED: " + ex.Message + Environment.NewLine);
        }
        finally
        {
            _import.Enabled = true;
        }
    }
}

public static class Defaults
{
    /// <summary>GOG, any Steam library, an old CD install, or a CD in a drive - see GameFolders.</summary>
    public static string GameDir() => GameFolders.Find();

    /// <summary>The pack folder, searched upward from where the exe sits (build/, tools/, the repo root).</summary>
    public static string PackDir()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        for (int i = 0; i < 6 && dir != null; i++, dir = dir.Parent)
        {
            var candidate = Path.Combine(dir.FullName, "packs", "star-wars-rebellion");
            if (File.Exists(Path.Combine(candidate, "pack.json")))
                return candidate;
        }
        return "";
    }
}
