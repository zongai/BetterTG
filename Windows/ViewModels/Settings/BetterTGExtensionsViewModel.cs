// BetterTG.Windows — root "BetterTG 扩展" settings ViewModel

using System.ComponentModel;
using System.Runtime.CompilerServices;
using BetterTG.Windows.Services;

namespace BetterTG.Windows.ViewModels.Settings
{
    /// <summary>
    /// Hub page for all fork settings. Navigate from Unigram Settings to this page.
    /// </summary>
    public sealed class BetterTGExtensionsViewModel : INotifyPropertyChanged
    {
        private readonly BetterTGSettings _settings = BetterTGSettings.Current;

        public event PropertyChangedEventHandler? PropertyChanged;

        public bool AutoTranslateEnabled
        {
            get => _settings.AutoTranslateEnabled;
            set
            {
                if (_settings.AutoTranslateEnabled == value) return;
                _settings.AutoTranslateEnabled = value;
                OnPropertyChanged();
            }
        }

        public bool ContentFilterEnabled
        {
            get => _settings.ContentFilterEnabled;
            set
            {
                if (_settings.ContentFilterEnabled == value) return;
                _settings.ContentFilterEnabled = value;
                OnPropertyChanged();
            }
        }

        public bool HideAds
        {
            get => _settings.HideAds;
            set
            {
                if (_settings.HideAds == value) return;
                _settings.HideAds = value;
                OnPropertyChanged();
            }
        }

        public bool FullWidthBubblesInGroups
        {
            get => _settings.FullWidthBubblesInGroups;
            set
            {
                if (_settings.FullWidthBubblesInGroups == value) return;
                _settings.FullWidthBubblesInGroups = value;
                OnPropertyChanged();
            }
        }

        public bool HideChannelShareButton
        {
            get => _settings.HideChannelShareButton;
            set
            {
                if (_settings.HideChannelShareButton == value) return;
                _settings.HideChannelShareButton = value;
                OnPropertyChanged();
            }
        }

        public double MessageFontScale
        {
            get => _settings.MessageFontScale;
            set
            {
                var v = value;
                if (System.Math.Abs(_settings.MessageFontScale - v) < 0.001) return;
                _settings.MessageFontScale = v;
                OnPropertyChanged();
                OnPropertyChanged(nameof(MessageFontScalePercent));
            }
        }

        public int MessageFontScalePercent => (int)System.Math.Round(MessageFontScale * 100);

        public int DownloadChunkCount
        {
            get => _settings.DownloadChunkCount;
            set
            {
                if (_settings.DownloadChunkCount == value) return;
                _settings.DownloadChunkCount = value;
                OnPropertyChanged();
            }
        }

        public bool ShowDownloadSpeed
        {
            get => _settings.ShowDownloadSpeed;
            set
            {
                if (_settings.ShowDownloadSpeed == value) return;
                _settings.ShowDownloadSpeed = value;
                OnPropertyChanged();
            }
        }

        private void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
