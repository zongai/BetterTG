// BetterTG.Windows — auto-translate detailed settings

using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows.Input;
using BetterTG.Windows.Models;
using BetterTG.Windows.Services;
using BetterTG.Windows.Services.Translation;

namespace BetterTG.Windows.ViewModels.Settings
{
    public sealed class EngineItemViewModel : INotifyPropertyChanged
    {
        public TranslationEngineId Id { get; init; }
        public string DisplayName { get; init; } = string.Empty;
        public bool RequiresApiKey { get; init; }

        private bool _enabled;
        public bool Enabled
        {
            get => _enabled;
            set
            {
                if (_enabled == value) return;
                _enabled = value;
                PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(Enabled)));
                BetterTGSettings.Current.SetEngineEnabled(Id, value);
            }
        }

        public event PropertyChangedEventHandler? PropertyChanged;
    }

    public sealed class AutoTranslateSettingsViewModel : INotifyPropertyChanged
    {
        private readonly BetterTGSettings _settings = BetterTGSettings.Current;

        public event PropertyChangedEventHandler? PropertyChanged;

        public AutoTranslateSettingsViewModel()
        {
            ReloadEngines();
            ClearCacheCommand = new RelayCommand(_ =>
            {
                TranslationService.Current.ClearCache();
                CacheCount = TranslationCache.Current.Count;
                OnPropertyChanged(nameof(CacheCount));
            });
        }

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

        public bool ShowBilingual
        {
            get => _settings.ShowBilingual;
            set
            {
                if (_settings.ShowBilingual == value) return;
                _settings.ShowBilingual = value;
                OnPropertyChanged();
            }
        }

        public string TargetLanguage
        {
            get => _settings.TargetLanguage;
            set
            {
                if (_settings.TargetLanguage == value) return;
                _settings.TargetLanguage = value ?? BetterTGConstants.DefaultTargetLanguage;
                OnPropertyChanged();
            }
        }

        public bool TranslationCacheEnabled
        {
            get => _settings.TranslationCacheEnabled;
            set
            {
                if (_settings.TranslationCacheEnabled == value) return;
                _settings.TranslationCacheEnabled = value;
                OnPropertyChanged();
            }
        }

        public string DeepLKeys
        {
            get => _settings.DeepLKeys;
            set
            {
                if (_settings.DeepLKeys == value) return;
                _settings.DeepLKeys = value ?? string.Empty;
                OnPropertyChanged();
            }
        }

        public string AzureKey
        {
            get => _settings.AzureKey;
            set
            {
                if (_settings.AzureKey == value) return;
                _settings.AzureKey = value ?? string.Empty;
                OnPropertyChanged();
            }
        }

        public string AzureRegion
        {
            get => _settings.AzureRegion;
            set
            {
                if (_settings.AzureRegion == value) return;
                _settings.AzureRegion = value ?? "eastasia";
                OnPropertyChanged();
            }
        }

        public ObservableCollection<EngineItemViewModel> Engines { get; } = new();

        public int CacheCount { get; private set; } = TranslationCache.Current.Count;

        public ICommand ClearCacheCommand { get; }

        public void ReloadEngines()
        {
            Engines.Clear();
            var order = _settings.GetEngineOrderList();
            foreach (var id in order)
            {
                var engine = TranslationService.Current.Engines.FirstOrDefault(e => e.Id == id);
                Engines.Add(new EngineItemViewModel
                {
                    Id = id,
                    DisplayName = engine?.DisplayName ?? id.ToString(),
                    RequiresApiKey = engine?.RequiresApiKey ?? false,
                    Enabled = _settings.IsEngineEnabled(id)
                });
            }
        }

        /// <summary>Persist current Engines collection order.</summary>
        public void SaveEngineOrder()
        {
            _settings.SetEngineOrderList(Engines.Select(e => e.Id));
        }

        public void MoveEngineUp(EngineItemViewModel item)
        {
            var i = Engines.IndexOf(item);
            if (i <= 0) return;
            Engines.Move(i, i - 1);
            SaveEngineOrder();
        }

        public void MoveEngineDown(EngineItemViewModel item)
        {
            var i = Engines.IndexOf(item);
            if (i < 0 || i >= Engines.Count - 1) return;
            Engines.Move(i, i + 1);
            SaveEngineOrder();
        }

        private void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }

    /// <summary>Minimal ICommand for settings actions without CommunityToolkit dependency.</summary>
    public sealed class RelayCommand : ICommand
    {
        private readonly System.Action<object?> _execute;
        private readonly System.Func<object?, bool>? _can;

        public RelayCommand(System.Action<object?> execute, System.Func<object?, bool>? can = null)
        {
            _execute = execute;
            _can = can;
        }

        public bool CanExecute(object? parameter) => _can?.Invoke(parameter) ?? true;
        public void Execute(object? parameter) => _execute(parameter);
#pragma warning disable CS0067
        public event System.EventHandler? CanExecuteChanged;
#pragma warning restore CS0067
    }
}
