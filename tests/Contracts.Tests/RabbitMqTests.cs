extern alias Producer;
extern alias Consumer;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using MassTransit;
using Xunit;
using P = Producer::FiapCloudGames.Contracts.V1;
using C = Consumer::FiapCloudGames.Contracts.V1;

namespace FiapCloudGames.Infrastructure.Tests;

[Trait("Category", "Infrastructure")]
public class RabbitMqTests : IAsyncLifetime
{
    private const string TestVirtualHost = "fcg_g1_tests";
    private static HttpClient Management()
    {
        var http = new HttpClient { BaseAddress = new Uri($"http://127.0.0.1:{LocalEnvironment.Get("RABBITMQ_MANAGEMENT_PORT")}/api/"), Timeout = TimeSpan.FromSeconds(15) };
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", Convert.ToBase64String(Encoding.UTF8.GetBytes($"fcg_local:{LocalEnvironment.Get("RABBITMQ_PASSWORD")}")));
        return http;
    }

    public async Task InitializeAsync()
    {
        using var http = Management();
        (await http.PutAsJsonAsync($"vhosts/{TestVirtualHost}", new { })).EnsureSuccessStatusCode();
        (await http.PutAsJsonAsync($"permissions/{TestVirtualHost}/fcg_local", new { configure = ".*", write = ".*", read = ".*" })).EnsureSuccessStatusCode();
    }

    public Task DisposeAsync() => Task.CompletedTask;

    private static IBusControl Bus(Action<IRabbitMqBusFactoryConfigurator>? configure = null) => MassTransit.Bus.Factory.CreateUsingRabbitMq(cfg =>
    {
        cfg.Host("127.0.0.1", ushort.Parse(LocalEnvironment.Get("RABBITMQ_PORT")), TestVirtualHost, h =>
        {
            h.Username("fcg_local"); h.Password(LocalEnvironment.Get("RABBITMQ_PASSWORD"));
        });
        configure?.Invoke(cfg);
    });

    [Theory]
    [InlineData("Approved")]
    [InlineData("Rejected")]
    public async Task Independent_contracts_cross_real_broker_and_payment_reaches_two_queues(string status)
    {
        var user = new TaskCompletionSource<C.UserCreatedEvent>(TaskCreationOptions.RunContinuationsAsynchronously);
        var order = new TaskCompletionSource<C.OrderPlacedEvent>(TaskCreationOptions.RunContinuationsAsynchronously);
        var catalog = new TaskCompletionSource<C.PaymentProcessedEvent>(TaskCreationOptions.RunContinuationsAsynchronously);
        var notifications = new TaskCompletionSource<C.PaymentProcessedEvent>(TaskCreationOptions.RunContinuationsAsynchronously);
        var suffix = Guid.NewGuid().ToString("N");
        var receiver = Bus(cfg =>
        {
            cfg.ReceiveEndpoint($"g1-notifications-{suffix}", e =>
            {
                e.Durable = false; e.AutoDelete = true;
                e.Handler<C.UserCreatedEvent>(ctx => { user.TrySetResult(ctx.Message); return Task.CompletedTask; });
                e.Handler<C.PaymentProcessedEvent>(ctx => { notifications.TrySetResult(ctx.Message); return Task.CompletedTask; });
            });
            cfg.ReceiveEndpoint($"g1-payments-{suffix}", e =>
            {
                e.Durable = false; e.AutoDelete = true;
                e.Handler<C.OrderPlacedEvent>(ctx => { order.TrySetResult(ctx.Message); return Task.CompletedTask; });
            });
            cfg.ReceiveEndpoint($"g1-catalog-{suffix}", e =>
            {
                e.Durable = false; e.AutoDelete = true;
                e.Handler<C.PaymentProcessedEvent>(ctx => { catalog.TrySetResult(ctx.Message); return Task.CompletedTask; });
            });
        });
        var sender = Bus();
        using var timeout = new CancellationTokenSource(TimeSpan.FromSeconds(45));
        try
        {
            await receiver.StartAsync(timeout.Token);
            await sender.StartAsync(timeout.Token);
            var u = JsonSerializer.Deserialize<P.UserCreatedEvent>(ContractTests.Example("user-created-v1.md"), ContractTests.Json)!;
            var o = JsonSerializer.Deserialize<P.OrderPlacedEvent>(ContractTests.Example("order-placed-v1.md"), ContractTests.Json)!;
            var p = JsonSerializer.Deserialize<P.PaymentProcessedEvent>(ContractTests.Example("payment-processed-v1.md"), ContractTests.Json)! with { Status = status };
            await sender.Publish(u, timeout.Token);
            await sender.Publish(o, timeout.Token);
            await sender.Publish(p, timeout.Token);
            Assert.Equal(u.Email, (await user.Task.WaitAsync(timeout.Token)).Email);
            Assert.Equal(o.Price, (await order.Task.WaitAsync(timeout.Token)).Price);
            var c = await catalog.Task.WaitAsync(timeout.Token);
            var n = await notifications.Task.WaitAsync(timeout.Token);
            Assert.Equal(p.OrderId, c.OrderId);
            Assert.Equal(p.PaymentId, c.PaymentId);
            Assert.Equal(status, c.Status);
            Assert.Equal(c, n);
        }
        finally
        {
            using var stop = new CancellationTokenSource(TimeSpan.FromSeconds(15));
            await sender.StopAsync(stop.Token);
            await receiver.StopAsync(stop.Token);
        }
    }

    [Fact]
    [Trait("Phase", "Persistence")]
    public async Task Durable_message_survives_container_restart()
    {
        using var http = Management();
        const string queue = $"queues/{TestVirtualHost}/g1-validation-persistence";
        if (!LocalEnvironment.VerifyPersistence)
        {
            (await http.PutAsJsonAsync(queue, new { durable = true, auto_delete = false, arguments = new { } })).EnsureSuccessStatusCode();
            // Limpa apenas a fila técnica deste teste antes de semear a próxima verificação.
            (await http.DeleteAsync(queue + "/contents")).EnsureSuccessStatusCode();
            var response = await http.PostAsJsonAsync($"exchanges/{TestVirtualHost}/amq.default/publish", new
            {
                properties = new { delivery_mode = 2 }, routing_key = "g1-validation-persistence",
                payload = "g1-persistence-marker", payload_encoding = "string"
            });
            response.EnsureSuccessStatusCode();
            var result = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.True(result.GetProperty("routed").GetBoolean());
        }
        else
        {
            var response = await http.PostAsJsonAsync(queue + "/get", new { count = 1, ackmode = "ack_requeue_false", encoding = "auto" });
            response.EnsureSuccessStatusCode();
            var messages = await response.Content.ReadFromJsonAsync<JsonElement>();
            Assert.Equal(1, messages.GetArrayLength());
            Assert.Equal("g1-persistence-marker", messages[0].GetProperty("payload").GetString());
        }
    }
}
