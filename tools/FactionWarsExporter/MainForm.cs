namespace FactionWarsExporter;

/// <summary>One window: where the game is, where the file goes, Export. Two
/// more for authors: the art set as a folder, and a faction pack built from a
/// folder. Nothing here starts another program (no "open folder"): the log
/// says where the file is.</summary>
public sealed class MainForm : Form
{
    private readonly TextBox _gameDir = new() { Width = 450 };
    private readonly TextBox _outFile = new() { Width = 450 };
    private readonly Button _export = new() { Text = "Export", Width = 120, Height = 32 };
    private readonly Button _exportFolder = new() { Text = "Export as folder...", Width = 160, Height = 32 };
    private readonly Button _build = new() { Text = "Build faction pack...", Width = 170, Height = 32 };
    private readonly TextBox _log = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Width = 640, Height = 260, Font = new Font("Consolas", 9f) };

    public MainForm()
    {
        Text = "Faction Wars Exporter " + (typeof(MainForm).Assembly.GetName().Version?.ToString(3) ?? "");
        StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        ClientSize = new Size(670, 490);
        AutoScaleMode = AutoScaleMode.Dpi;

        var intro = new Label
        {
            Text = "Exports the original artwork from YOUR copy of Star Wars: Rebellion (GOG, Steam or the CD) into one file. " +
                   "Import that file into Faction Wars, in the browser or on the desktop. Keep it: if your browser ever forgets " +
                   "the artwork, import the same file again. Nothing is downloaded and nothing leaves this machine.",
            AutoSize = false, Width = 640, Height = 64, Location = new Point(15, 12),
        };
        Controls.Add(intro);

        Controls.Add(Row("Game folder:", _gameDir, 80, () => BrowseFolder(_gameDir,
            "Pick the folder Star Wars: Rebellion is installed in (it holds REBEXE.EXE and EData), or the REBELLION folder on the CD")));
        Controls.Add(Row("Save to:", _outFile, 116, BrowseOutFile));

        _export.Location = new Point(15, 158);
        _export.Click += (_, _) =>
        {
            if (ConfirmReplace(_outFile.Text))
                Run(() => ExportTo(() => new ZipSink(_outFile.Text), _outFile.Text));
        };
        Controls.Add(_export);
        _exportFolder.Location = new Point(145, 158);
        _exportFolder.Click += (_, _) => Run(ExportFolder);
        Controls.Add(_exportFolder);
        _build.Location = new Point(485, 158);
        _build.Click += (_, _) => Run(BuildPack);
        Controls.Add(_build);

        _log.Location = new Point(15, 205);
        Controls.Add(_log);

        _gameDir.Text = GameFolders.Find();
        _outFile.Text = Exporter.DefaultArtFile;
        AcceptButton = _export;
        ActiveControl = _export;
    }

    private Control Row(string caption, TextBox box, int y, Action browse)
    {
        var panel = new Panel { Location = new Point(15, y), Width = 640, Height = 30 };
        panel.Controls.Add(new Label { Text = caption, Location = new Point(0, 6), AutoSize = true });
        box.Location = new Point(105, 3);
        panel.Controls.Add(box);
        var b = new Button { Text = "Browse...", Location = new Point(562, 1), Width = 78, Height = 26 };
        b.Click += (_, _) => browse();
        panel.Controls.Add(b);
        return panel;
    }

    private string? PickFolder(string description, string start)
    {
        using var dlg = new FolderBrowserDialog { Description = description, UseDescriptionForTitle = true, InitialDirectory = Directory.Exists(start) ? start : "" };
        return dlg.ShowDialog(this) == DialogResult.OK ? dlg.SelectedPath : null;
    }

    private string? PickZip(string title, string start)
    {
        using var dlg = new SaveFileDialog
        {
            Title = title, Filter = "Faction Wars file (*.zip)|*.zip", DefaultExt = "zip", OverwritePrompt = true,
            FileName = Path.GetFileName(start), InitialDirectory = Path.GetDirectoryName(start) ?? "",
        };
        return dlg.ShowDialog(this) == DialogResult.OK ? dlg.FileName : null;
    }

    private void BrowseFolder(TextBox box, string description)
    {
        if (PickFolder(description, box.Text) is string picked)
            box.Text = picked;
    }

    private void BrowseOutFile()
    {
        if (PickZip("Save the art set as", _outFile.Text) is string picked)
            _outFile.Text = picked;
    }

    /// <summary>An art set already at the "Save to" path is the player's backup:
    /// ask before Export replaces it (TeeJ, 2026-09-24). Browse's dialog asks
    /// already; typing or keeping the default path went straight over it. "No"
    /// is the default, as in Windows' own prompt. The file is replaced only
    /// once the new one is complete (ZipSink), so a failed export keeps it.</summary>
    private bool ConfirmReplace(string path)
    {
        if (!File.Exists(path))
            return true;
        var answer = MessageBox.Show(this,
            $"{Path.GetFileName(path)} already exists in {Path.GetDirectoryName(Path.GetFullPath(path))}.\n\nReplace it with a new export?",
            "Replace the art set?", MessageBoxButtons.YesNo, MessageBoxIcon.Question, MessageBoxDefaultButton.Button2);
        if (answer == DialogResult.Yes)
            return true;
        _log.Clear();
        Say($"Not exported: {path} was kept. Pick another file with Browse... to export beside it.");
        return false;
    }

    private void Say(string line)
    {
        _log.AppendText(line + Environment.NewLine);
        Application.DoEvents();
    }

    private void Run(Action job)
    {
        _log.Clear();
        _export.Enabled = _exportFolder.Enabled = _build.Enabled = false;
        try { job(); }
        catch (Exception ex) { Say("FAILED: " + ex.Message); }
        finally
        {
            _export.Enabled = _exportFolder.Enabled = _build.Enabled = true;
            _log.SelectionStart = _log.TextLength;
            _log.ScrollToCaret();
        }
    }

    private void ExportTo(Func<ArtSink> sinkFor, string where)
    {
        var problem = Importer.Problem(_gameDir.Text, Importer.BundledRows);
        if (problem != null) { Say(problem); return; }
        using (var sink = sinkFor())
        {
            var result = Exporter.ExportArtSet(_gameDir.Text, Importer.BundledRows, sink, Say);
            foreach (var m in result.Missing)
                Say("  - " + m);
        }
        Say("");
        Say($"Saved: {where}");
        Say("Import it into Faction Wars: press Play on Star Wars: Rebellion, then Import artwork file... (or drag it onto the game). Keep it as your backup.");
    }

    private void ExportFolder()
    {
        if (PickFolder("Pick an EMPTY folder for the art set", Path.GetDirectoryName(_outFile.Text) ?? "") is not string folder)
            return;
        if (Directory.EnumerateFileSystemEntries(folder).Any() && !File.Exists(Path.Combine(folder, Manifest.FileName)))
        {
            Say($"{folder} is not empty. Pick an empty folder (or an art-set folder to refresh).");
            return;
        }
        ExportTo(() => new FolderSink(folder), folder);
    }

    private void BuildPack()
    {
        if (PickFolder("Pick your faction pack's folder (it holds pack.json)", "") is not string folder)
            return;
        var start = Path.Combine(Path.GetDirectoryName(_outFile.Text) ?? "", Path.GetFileName(folder) + ".zip");
        if (PickZip("Save the faction pack as", start) is not string outZip)
            return;
        var result = PackBuilder.Build(folder, outZip, Say);
        Say(result.Message);
    }
}
