// BetterTG.Windows — code-behind for extensions hub page

using BetterTG.Windows.ViewModels.Settings;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace BetterTG.Windows.Views.Settings
{
    public sealed partial class BetterTGExtensionsPage : Page
    {
        public BetterTGExtensionsViewModel ViewModel { get; } = new BetterTGExtensionsViewModel();

        public BetterTGExtensionsPage()
        {
            InitializeComponent();
            DataContext = ViewModel;
        }

        /// <summary>Slider binds 85–150; ViewModel stores 0.85–1.50.</summary>
        public double FontScalePercent
        {
            get => ViewModel.MessageFontScale * 100.0;
            set => ViewModel.MessageFontScale = value / 100.0;
        }

        private void OnAutoTranslateClick(object sender, RoutedEventArgs e)
        {
            // Host should navigate to AutoTranslateSettingsPage.
            // Example: Frame.Navigate(typeof(AutoTranslateSettingsPage));
            Frame?.Navigate(typeof(AutoTranslateSettingsPage));
        }

        private void OnContentFilterClick(object sender, RoutedEventArgs e)
        {
            Frame?.Navigate(typeof(ContentFilterSettingsPage));
        }

        private void OnDownloadCacheClick(object sender, RoutedEventArgs e)
        {
            Frame?.Navigate(typeof(DownloadCacheSettingsPage));
        }
    }
}
