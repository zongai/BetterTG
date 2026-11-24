using BetterTG.Windows.ViewModels.Settings;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace BetterTG.Windows.Views.Settings
{
    public sealed partial class AutoTranslateSettingsPage : Page
    {
        public AutoTranslateSettingsViewModel ViewModel { get; } = new AutoTranslateSettingsViewModel();

        public AutoTranslateSettingsPage()
        {
            InitializeComponent();
            DataContext = ViewModel;
        }

        private void OnMoveUp(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement fe && fe.Tag is EngineItemViewModel item)
                ViewModel.MoveEngineUp(item);
        }

        private void OnMoveDown(object sender, RoutedEventArgs e)
        {
            if (sender is FrameworkElement fe && fe.Tag is EngineItemViewModel item)
                ViewModel.MoveEngineDown(item);
        }
    }
}
