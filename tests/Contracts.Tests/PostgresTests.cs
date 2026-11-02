using Npgsql;
using Xunit;

namespace FiapCloudGames.Infrastructure.Tests;

[Trait("Category", "Infrastructure")]
public class PostgresTests
{
    private static readonly string[] Services = ["users", "catalog", "payments", "notifications"];
    public static IEnumerable<object[]> IsolationCases => Services.SelectMany(user => Services
        .Concat(["postgres", "template1"]).Where(db => db != user)
        .Select(db => new object[] { user, db is "postgres" or "template1" ? db : $"fcg_{db}" }));

    [Theory]
    [MemberData(nameof(IsolationCases))]
    public async Task Service_cannot_connect_to_other_database(string service, string database)
    {
        await using var connection = LocalEnvironment.Connection(service, database);
        var error = await Assert.ThrowsAsync<PostgresException>(() => connection.OpenAsync());
        Assert.Equal("42501", error.SqlState);
    }

    [Theory]
    [InlineData("users")]
    [InlineData("catalog")]
    [InlineData("payments")]
    [InlineData("notifications")]
    public async Task Own_database_allows_ddl_but_role_has_no_cluster_privileges(string service)
    {
        await using var connection = LocalEnvironment.Connection(service, $"fcg_{service}");
        await connection.OpenAsync();
        await using var privileges = new NpgsqlCommand("SELECT rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication FROM pg_roles WHERE rolname = current_user", connection);
        Assert.Equal(false, await privileges.ExecuteScalarAsync());
        await using var transaction = await connection.BeginTransactionAsync();
        await using var ddl = new NpgsqlCommand("CREATE TABLE g1_transaction_probe(id integer PRIMARY KEY); INSERT INTO g1_transaction_probe VALUES (1); SELECT count(*) FROM g1_transaction_probe", connection, transaction);
        Assert.Equal(1L, await ddl.ExecuteScalarAsync());
        await transaction.RollbackAsync();
    }

    [Fact]
    public async Task Wrong_password_is_rejected()
    {
        await using var connection = LocalEnvironment.Connection("users", "fcg_users", "deliberately-invalid");
        var error = await Assert.ThrowsAsync<PostgresException>(() => connection.OpenAsync());
        Assert.Equal("28P01", error.SqlState);
    }

    [Theory]
    [Trait("Phase", "Persistence")]
    [InlineData("users")]
    [InlineData("catalog")]
    [InlineData("payments")]
    [InlineData("notifications")]
    public async Task Persistence_marker_survives_container_restart(string service)
    {
        await using var connection = LocalEnvironment.Connection(service, $"fcg_{service}");
        await connection.OpenAsync();
        if (!LocalEnvironment.VerifyPersistence)
        {
            await using var seed = new NpgsqlCommand("CREATE SCHEMA IF NOT EXISTS g1_validation; CREATE TABLE IF NOT EXISTS g1_validation.persistence(id integer PRIMARY KEY); INSERT INTO g1_validation.persistence VALUES (1) ON CONFLICT DO NOTHING", connection);
            await seed.ExecuteNonQueryAsync();
        }
        await using var verify = new NpgsqlCommand("SELECT count(*) FROM g1_validation.persistence WHERE id = 1", connection);
        Assert.Equal(1L, await verify.ExecuteScalarAsync());
    }
}
