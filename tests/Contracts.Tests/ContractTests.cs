extern alias Producer;
extern alias Consumer;
using System.Reflection;
using System.Text.Json;
using System.Text.RegularExpressions;
using MassTransit;
using Xunit;
using P = Producer::FiapCloudGames.Contracts.V1;
using C = Consumer::FiapCloudGames.Contracts.V1;

namespace FiapCloudGames.Infrastructure.Tests;

public class ContractTests
{
    internal static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public static TheoryData<Type, Type, string> Contracts => new()
    {
        { typeof(P.UserCreatedEvent), typeof(C.UserCreatedEvent), "user-created-v1.md" },
        { typeof(P.OrderPlacedEvent), typeof(C.OrderPlacedEvent), "order-placed-v1.md" },
        { typeof(P.PaymentProcessedEvent), typeof(C.PaymentProcessedEvent), "payment-processed-v1.md" }
    };

    internal static string Example(string file) => Regex.Match(
        File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Contracts", file)),
        @"```json\s*(.*?)\s*```", RegexOptions.Singleline).Groups[1].Value;

    [Theory]
    [MemberData(nameof(Contracts))]
    public void Independent_assemblies_match_documented_schema_and_message_identity(Type producer, Type consumer, string file)
    {
        Assert.NotEqual(producer.Assembly, consumer.Assembly);
        Assert.Equal(producer.FullName, consumer.FullName);
        var urn = $"urn:message:FiapCloudGames.Contracts.V1:{producer.Name}";
        Assert.Equal(urn, MessageUrn.ForTypeString(producer));
        Assert.Equal(urn, MessageUrn.ForTypeString(consumer));
        var markdown = File.ReadAllText(Path.Combine(AppContext.BaseDirectory, "Contracts", file));
        var rows = Regex.Matches(markdown, @"\| `(?<name>\w+)` \| `(?<type>[^`]+)` \| Sim \|");
        foreach (var type in new[] { producer, consumer })
        {
            Assert.Equal(rows.Count, type.GetProperties().Length);
            foreach (Match row in rows)
            {
                var expected = row.Groups["type"].Value.Split(':')[0].Split(' ')[0] switch
                {
                    "Guid" => typeof(Guid), "DateTimeOffset" => typeof(DateTimeOffset),
                    "decimal" => typeof(decimal), "string" => typeof(string),
                    _ => throw new InvalidOperationException("Tipo canônico desconhecido")
                };
                Assert.Equal(expected, type.GetProperty(row.Groups["name"].Value)!.PropertyType);
            }
        }
        var message = JsonSerializer.Deserialize(Example(file), producer, Json)!;
        var wire = JsonSerializer.Serialize(message, producer, Json);
        var received = JsonSerializer.Deserialize(wire, consumer, Json)!;
        Assert.Equal(wire, JsonSerializer.Serialize(received, consumer, Json));
        using var document = JsonDocument.Parse(wire);
        var expectedNames = rows.Select(r => JsonNamingPolicy.CamelCase.ConvertName(r.Groups["name"].Value)).Order();
        Assert.Equal(expectedNames, document.RootElement.EnumerateObject().Select(p => p.Name).Order());
        Assert.Equal(TimeSpan.Zero, ((DateTimeOffset)consumer.GetProperty("OccurredAt")!.GetValue(received)!).Offset);
        if (consumer.GetProperty("Price") is PropertyInfo price)
        {
            Assert.Equal(59.9m, price.GetValue(received));
            Assert.Equal(JsonValueKind.Number, document.RootElement.GetProperty("price").ValueKind);
            Assert.Equal("BRL", document.RootElement.GetProperty("currency").GetString());
        }
    }

    [Theory]
    [MemberData(nameof(Contracts))]
    public void Missing_required_fields_are_rejected(Type producer, Type consumer, string file)
    {
        var payload = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(Example(file))!;
        foreach (var field in payload.Keys)
        {
            var incomplete = payload.Where(p => p.Key != field).ToDictionary(p => p.Key, p => p.Value);
            var wire = JsonSerializer.Serialize(incomplete);
            Assert.Throws<JsonException>(() => JsonSerializer.Deserialize(wire, producer, Json));
            Assert.Throws<JsonException>(() => JsonSerializer.Deserialize(wire, consumer, Json));
        }
    }
}
