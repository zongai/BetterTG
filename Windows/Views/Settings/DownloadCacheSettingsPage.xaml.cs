using BetterTG.Windows.ViewModels.Settings;
using Microsoft.UI.Xaml.Controls;

namespace BetterTG.Windows.Views.Settings
{
    public sealed partial class DownloadCacheSettingsPage : Page
    {
        public DownloadCacheSettingsViewModel ViewModel { get; } = new DownloadCacheSettingsViewModel();

        public DownloadCacheSettingsPage()
        {
            InitializeComponent();
            DataContext = ViewModel;
            // Host should assign media cache directories, e.g.:
            // ViewModel.CacheRoots = new[] { ApplicationData.Current.LocalFolder.Path + "\\temp" };
        }
    }
}
