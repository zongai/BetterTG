// BetterTG.Windows — translation engine contract

using System.Threading;
using System.Threading.Tasks;
using BetterTG.Windows.Models;

namespace BetterTG.Windows.Services.Translation.Engines
{
    public interface ITranslationEngine
    {
        TranslationEngineId Id { get; }
        string DisplayName { get; }
        /// <summary>True when the engine needs a user-supplied API key.</summary>
        bool RequiresApiKey { get; }
        /// <summary>Whether this engine can run with current settings (key present if required).</summary>
        bool IsConfigured { get; }

        Task<TranslationResult> TranslateAsync(TranslationRequest request, CancellationToken cancellationToken = default);
    }
}
