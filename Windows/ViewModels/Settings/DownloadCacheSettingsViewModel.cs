// BetterTG.Windows — download chunks + cache cleanup settings

using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using System.Windows.Input;
using BetterTG.Windows.Services;
using BetterTG.Windows.Services.Download;

namespace BetterTG.Windows.ViewModels.Settings
{
    public sealed class DownloadCacheSettingsViewModel : INotifyPropertyChanged
    {
        private readonly BetterTGSettings _settings = BetterTGSettings.Current;

        public event PropertyChangedEventHandler? PropertyChanged;

        public DownloadCacheSettingsViewModel()
        {
            RunCleanupCommand = new RelayCommand(async _ => await RunCleanupAsync());
        }

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

        public int CacheMaxAgeDays
        {
            get => _settings.CacheMaxAgeDays;
            set
            {
                if (_settings.CacheMaxAgeDays == value) return;
                _settings.CacheMaxAgeDays = value;
                OnPropertyChanged();
            }
        }

        public int CacheMaxSizeMb
        {
            get => _settings.CacheMaxSizeMb;
            set
            {
                if (_settings.CacheMaxSizeMb == value) return;
                _settings.CacheMaxSizeMb = value;
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

        private string _status = string.Empty;
        public string Status
        {
            get => _status;
            set { _status = value ?? string.Empty; OnPropertyChanged(); }
        }

        private bool _isBusy;
        public bool IsBusy
        {
            get => _isBusy;
            set { _isBusy = value; OnPropertyChanged(); }
        }

        /// <summary>
        /// Host must set these to Unigram media/cache folder paths before cleanup.
        /// </summary>
        public string[]? CacheRoots { get; set; }

        public ICommand RunCleanupCommand { get; }

        public async Task RunCleanupAsync()
        {
            if (IsBusy) return;
            IsBusy = true;
            Status = "清理中…";
            try
            {
                var roots = CacheRoots ?? System.Array.Empty<string>();
                var result = await CacheCleanupService.Current.CleanupAsync(roots).ConfigureAwait(true);
                Status = $"已删除 {result.FilesRemoved} 个文件，释放 {FormatBytes(result.BytesFreed)}";
            }
            catch (System.Exception ex)
            {
                Status = "清理失败: " + ex.Message;
            }
            finally
            {
                IsBusy = false;
            }
        }

        private static string FormatBytes(long bytes)
        {
            if (bytes < 1024) return bytes + " B";
            if (bytes < 1024 * 1024) return (bytes / 1024.0).ToString("0.#") + " KB";
            if (bytes < 1024L * 1024 * 1024) return (bytes / (1024.0 * 1024)).ToString("0.#") + " MB";
            return (bytes / (1024.0 * 1024 * 1024)).ToString("0.##") + " GB";
        }

        private void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
