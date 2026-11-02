using Npgsql;

namespace FiapCloudGames.Infrastructure.Tests;

internal static class LocalEnvironment
{
    private static readonly Lazy<Dictionary<string, string>> Values = new(() =>
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "compose.yaml")))
            directory = directory.Parent;
        var path = Path.Combine(directory?.FullName ?? throw new InvalidOperationException("Raiz não encontrada"), ".env");
        if (!File.Exists(path)) throw new InvalidOperationException("Execute scripts/Initialize-Local.ps1 e suba o Compose antes dos testes de integração.");
        return File.ReadAllLines(path).Where(l => !string.IsNullOrWhiteSpace(l) && !l.StartsWith('#'))
            .Select(l => l.Split('=', 2)).ToDictionary(p => p[0], p => p[1]);
    });

    public static string Get(string name) => Values.Value[name];
    public static bool VerifyPersistence => Environment.GetEnvironmentVariable("G1_VERIFY_PERSISTENCE") == "1";
    public static NpgsqlConnection Connection(string service, string database, string? password = null) => new(
        new NpgsqlConnectionStringBuilder
        {
            Host = "127.0.0.1", Port = int.Parse(Get("POSTGRES_PORT")),
            Username = $"fcg_{service}", Database = database,
            Password = password ?? Get($"{service.ToUpperInvariant()}_DB_PASSWORD"),
            Timeout = 5, Pooling = false, IncludeErrorDetail = false
        }.ConnectionString);
}
