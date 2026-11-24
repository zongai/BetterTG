// BetterTG.Windows — content filter settings ViewModel

using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Windows.Input;
using BetterTG.Windows.Services;

namespace BetterTG.Windows.ViewModels.Settings
{
    public sealed class ContentFilterSettingsViewModel : INotifyPropertyChanged
    {
        private readonly BetterTGSettings _settings = BetterTGSettings.Current;

        public event PropertyChangedEventHandler? PropertyChanged;

        public ContentFilterSettingsViewModel()
        {
            ReloadLists();
            AddBlacklistCommand = new RelayCommand(_ => AddKeyword(Blacklist, NewBlacklistItem, v => NewBlacklistItem = v, PersistBlacklist));
            AddWhitelistCommand = new RelayCommand(_ => AddKeyword(Whitelist, NewWhitelistItem, v => NewWhitelistItem = v, PersistWhitelist));
            RemoveBlacklistCommand = new RelayCommand(p =>
            {
                if (p is string s) { Blacklist.Remove(s); PersistBlacklist(); }
            });
            RemoveWhitelistCommand = new RelayCommand(p =>
            {
                if (p is string s) { Whitelist.Remove(s); PersistWhitelist(); }
            });
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

        public ObservableCollection<string> Blacklist { get; } = new();
        public ObservableCollection<string> Whitelist { get; } = new();

        private string _newBlacklistItem = string.Empty;
        public string NewBlacklistItem
        {
            get => _newBlacklistItem;
            set { _newBlacklistItem = value ?? string.Empty; OnPropertyChanged(); }
        }

        private string _newWhitelistItem = string.Empty;
        public string NewWhitelistItem
        {
            get => _newWhitelistItem;
            set { _newWhitelistItem = value ?? string.Empty; OnPropertyChanged(); }
        }

        public ICommand AddBlacklistCommand { get; }
        public ICommand AddWhitelistCommand { get; }
        public ICommand RemoveBlacklistCommand { get; }
        public ICommand RemoveWhitelistCommand { get; }

        public void ReloadLists()
        {
            Blacklist.Clear();
            foreach (var s in _settings.GetBlacklist()) Blacklist.Add(s);
            Whitelist.Clear();
            foreach (var s in _settings.GetWhitelist()) Whitelist.Add(s);
        }

        public void MoveBlacklist(int from, int to)
        {
            if (from < 0 || to < 0 || from >= Blacklist.Count || to >= Blacklist.Count) return;
            Blacklist.Move(from, to);
            PersistBlacklist();
        }

        public void MoveWhitelist(int from, int to)
        {
            if (from < 0 || to < 0 || from >= Whitelist.Count || to >= Whitelist.Count) return;
            Whitelist.Move(from, to);
            PersistWhitelist();
        }

        private void PersistBlacklist() => _settings.SetBlacklist(Blacklist);
        private void PersistWhitelist() => _settings.SetWhitelist(Whitelist);

        private static void AddKeyword(
            ObservableCollection<string> list,
            string value,
            Action<string> clear,
            Action persist)
        {
            var t = (value ?? string.Empty).Trim();
            if (t.Length == 0) return;
            if (list.Any(x => string.Equals(x, t, StringComparison.OrdinalIgnoreCase))) return;
            list.Add(t);
            clear(string.Empty);
            persist();
        }

        private void OnPropertyChanged([CallerMemberName] string? name = null) =>
            PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    }
}
