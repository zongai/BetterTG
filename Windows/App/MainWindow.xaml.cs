using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows;
using BetterTG.Windows.Services;
using BetterTG.Windows.Services.Translation;

namespace BetterTG.Windows.App
{
    public partial class MainWindow : Window
    {
        public MainWindow()
        {
            InitializeComponent();
            DataContext = new HostSettingsModel();
            StatusText.Text = "设置已绑定到 BetterTGSettings（进程内持久化：非 WinRT 环境使用内存存储）。";
        }

        private void OnClearCache(object sender, RoutedEventArgs e)
        {
            TranslationService.Current.ClearCache();
            StatusText.Text = "翻译缓存已清空。";
        }
    }

    /// <summary>
    /// Thin bindable facade over BetterTGSettings for the host window.
    /// </summary>
    public sealed class HostSettingsModel : INotifyPropertyChanged
    {
        private readonly BetterTGSettings _s = BetterTGSettings.Current;

        public event PropertyChangedEventHandler? PropertyChanged;

        public bool AutoTranslateEnabled
        {
            get => _s.AutoTranslateEnabled;
            set { _s.AutoTranslateEnabled = value; OnPropertyChanged(); }
        }

        public bool ShowBilingual
        {
            get => _s.ShowBilingual;
            set { _s.ShowBilingual = value; OnPropertyChanged(); }
        }

        public string TargetLanguage
        {
            get => _s.TargetLanguage;
            set { _s.TargetLanguage = value; OnPropertyChanged(); }
        }

        public string EngineOrder
        {
            get => _s.EngineOrder;
            set { _s.EngineOrder = value; OnPropertyChanged(); }
        }

        public string DeepLKeys
        {
            get => _s.DeepLKeys;
            set { _s.DeepLKeys = value; OnPropertyChanged(); }
        }

        public string AzureKey
        {
            get => _s.AzureKey;
            set { _s.AzureKey = value; OnPropertyChanged(); }
        }

        public bool TranslationCacheEnabled
        {
            get => _s.TranslationCacheEnabled;
            set { _s.TranslationCacheEnabled = value; OnPropertyChanged(); }
        }

        public bool ContentFilterEnabled
        {
            get => _s.ContentFilterEnabled;
            set { _s.ContentFilterEnabled = value; OnPropertyChanged(); }
        }

        public bool HideAds
        {
            get => _s.HideAds;
            set { _s.HideAds = value; OnPropertyChanged(); }
        }

        public string BlacklistRaw
        {
            get => _s.BlacklistRaw;
            set { _s.BlacklistRaw = value; OnPropertyChanged(); }
        }

        public string WhitelistRaw
        {
            get => _s.WhitelistRaw;
            set { _s.WhitelistRaw = value; OnPropertyChanged(); }
        }

        public double DownloadChunkCount
        {
            get => _s.DownloadChunkCount;
            set
            {
                _s.DownloadChunkCount = (int)value;
                OnPropertyChanged();
                OnPropertyChanged(nameof(ChunkLabel));
            }
        }

        public string ChunkLabel => $"分片数: {_s.DownloadChunkCount}（4–32）";

        public bool ShowDownloadSpeed
        {
            get => _s.ShowDownloadSpeed;
            set { _s.ShowDownloadSpeed = value; OnPropertyChanged(); }
        }

        public string CacheMaxAgeDays
        {
            get => _s.CacheMaxAgeDays.ToString();
            set
            {
                if (int.TryParse(value, out var v))
                    _s.CacheMaxAgeDays = v;
                OnPropertyChanged();
            }
        }

        public string CacheMaxSizeMb
        {
            get => _s.CacheMaxSizeMb.ToString();
            set
            {
                if (int.TryParse(value, out var v))
                    _s.CacheMaxSizeMb = v;
                OnPropertyChanged();
            }
        }

        public bool FullWidthBubblesInGroups
        {
            get => _s.FullWidthBubblesInGroups;
            set { _s.FullWidthBubblesInGroups = value; OnPropertyChanged(); }
        }

        public bool HideChannelShareButton
        {
            get => _s.HideChannelShareButton;
            set { _s.HideChannelShareButton = value; OnPropertyChanged(); }
        }

        public double FontScalePercent
        {
            get => _s.MessageFontScale * 100.0;
            set
            {
                _s.MessageFontScale = value / 100.0;
                OnPropertyChanged();
                OnPropertyChanged(nameof(FontScaleLabel));
            }
        }

        public string FontScaleLabel => $"消息文字大小: {(int)System.Math.Round(_s.MessageFontScale * 100)}%";

        private void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
