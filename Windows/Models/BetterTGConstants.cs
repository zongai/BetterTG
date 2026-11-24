// BetterTG.Windows — fork extension constants
// Isolated from iOS BetterTG. Does not modify any iOS sources.

namespace BetterTG.Windows.Models
{
    /// <summary>
    /// Persistence key prefix and shared constants for the Windows fork extensions.
    /// Mirrors iOS UserDefaults prefix BetterTG.fork.* with ApplicationData LocalSettings.
    /// </summary>
    public static class BetterTGConstants
    {
        public const string SettingsContainerName = "BetterTG.Fork";
        public const string KeyPrefix = "BetterTG.fork.";

        // Auto-translate
        public const string AutoTranslateEnabled = KeyPrefix + "autoTranslate.enabled";
        public const string ShowBilingual = KeyPrefix + "autoTranslate.bilingual";
        public const string TargetLanguage = KeyPrefix + "autoTranslate.targetLanguage";
        public const string EngineOrder = KeyPrefix + "autoTranslate.engineOrder";
        public const string EngineEnabled = KeyPrefix + "autoTranslate.engineEnabled."; // + engine id
        public const string DeepLKeys = KeyPrefix + "autoTranslate.deeplKeys";
        public const string AzureKey = KeyPrefix + "autoTranslate.azureKey";
        public const string AzureRegion = KeyPrefix + "autoTranslate.azureRegion";
        public const string ChatExceptions = KeyPrefix + "autoTranslate.chatExceptions"; // JSON: chatId -> bool?
        public const string TranslationCacheEnabled = KeyPrefix + "autoTranslate.cacheEnabled";
        public const string MessageFontScale = KeyPrefix + "message.fontScale"; // 0.85–1.50

        // Content filter
        public const string ContentFilterEnabled = KeyPrefix + "contentFilter.enabled";
        public const string HideAds = KeyPrefix + "contentFilter.hideAds";
        public const string Blacklist = KeyPrefix + "contentFilter.blacklist";
        public const string Whitelist = KeyPrefix + "contentFilter.whitelist";

        // Download / cache
        public const string DownloadChunkCount = KeyPrefix + "download.chunkCount";
        public const string CacheMaxAgeDays = KeyPrefix + "cache.maxAgeDays";
        public const string CacheMaxSizeMb = KeyPrefix + "cache.maxSizeMb";
        public const string ShowDownloadSpeed = KeyPrefix + "download.showSpeed";

        // UI
        public const string FullWidthBubblesInGroups = KeyPrefix + "ui.fullWidthBubblesInGroups";
        public const string HideChannelShareButton = KeyPrefix + "ui.hideChannelShareButton";

        // Defaults
        public const int DefaultChunkCount = 16;
        public const int MinChunkCount = 4;
        public const int MaxChunkCount = 32;
        public const double DefaultFontScale = 1.0;
        public const double MinFontScale = 0.85;
        public const double MaxFontScale = 1.50;
        public const string DefaultTargetLanguage = "zh";
        public const string DefaultEngineOrder = "google,bing,deepl,azure,mymemory";
    }

    public enum TranslationEngineId
    {
        Google,
        Bing,
        DeepL,
        Azure,
        MyMemory
    }

    public enum TranslationDisplayMode
    {
        /// <summary>Show only translation; tap to toggle original.</summary>
        TranslationOnly,
        /// <summary>Show original + translation stacked.</summary>
        Bilingual
    }
}
