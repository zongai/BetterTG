using BetterTG.Windows.ViewModels.Settings;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace BetterTG.Windows.Views.Settings
{
    public sealed partial class ContentFilterSettingsPage : Page
    {
        public ContentFilterSettingsViewModel ViewModel { get; } = new ContentFilterSettingsViewModel();

        public ContentFilterSettingsPage()
        {
            InitializeComponent();
            DataContext = ViewModel;
        }

        private void OnRemoveWhitelist(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement fe && fe.Tag is string s)
                ViewModel.RemoveWhitelistCommand.Execute(s);
        }

        private void OnRemoveBlacklist(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement fe && fe.Tag is string s)
                ViewModel.RemoveBlacklistCommand.Execute(s);
        }
    }
}
