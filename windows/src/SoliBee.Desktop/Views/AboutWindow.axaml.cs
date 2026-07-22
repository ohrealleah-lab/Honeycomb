using System.Reflection;
using Avalonia.Controls;
using Avalonia.Interactivity;

namespace SoliBee.Desktop.Views;

public partial class AboutWindow : Window
{
    public AboutWindow()
    {
        InitializeComponent();

        var version = Assembly.GetExecutingAssembly()
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion
            ?? Assembly.GetExecutingAssembly().GetName().Version?.ToString(3)
            ?? "1.0.0";

        VersionText.Text = $"Version {version}";
    }

    private void Close_Click(object? sender, RoutedEventArgs e) => Close();
}
