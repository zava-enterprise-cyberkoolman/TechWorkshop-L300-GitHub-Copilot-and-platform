using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using ZavaStorefront.Models;

namespace ZavaStorefront.Services
{
    public class ChatService
    {
        private readonly HttpClient _httpClient;
        private readonly string _endpoint;
        private readonly string _apiKey;
        private readonly string _deploymentName;
        private readonly ILogger<ChatService> _logger;

        public ChatService(IHttpClientFactory httpClientFactory, IConfiguration configuration, ILogger<ChatService> logger)
        {
            _httpClient = httpClientFactory.CreateClient();
            _endpoint = configuration["AzureFoundry:Endpoint"] ?? string.Empty;
            _apiKey = configuration["AzureFoundry:ApiKey"] ?? string.Empty;
            _deploymentName = configuration["AzureFoundry:DeploymentName"] ?? "phi-4";
            _logger = logger;
        }

        public async Task<string> SendMessageAsync(List<ChatMessage> history, string userMessage)
        {
            if (string.IsNullOrWhiteSpace(_endpoint))
            {
                throw new InvalidOperationException("Azure Foundry endpoint is not configured. Set 'AzureFoundry:Endpoint' in configuration.");
            }

            var messages = history
                .Select(m => new { role = m.Role, content = m.Content })
                .Append(new { role = "user", content = userMessage })
                .ToList();

            var requestBody = new
            {
                messages,
                max_tokens = 1024,
                temperature = 0.7
            };

            var json = JsonSerializer.Serialize(requestBody);
            var requestUrl = $"{_endpoint.TrimEnd('/')}/openai/deployments/{_deploymentName}/chat/completions?api-version=2024-05-01-preview";

            using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
            request.Content = new StringContent(json, Encoding.UTF8, "application/json");
            request.Headers.Add("api-key", _apiKey);

            _logger.LogInformation("Sending chat request to Phi4 endpoint for deployment '{Deployment}'", _deploymentName);

            var response = await _httpClient.SendAsync(request);
            var responseContent = await response.Content.ReadAsStringAsync();

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("Phi4 endpoint returned {StatusCode}: {Body}", response.StatusCode, responseContent);
                throw new HttpRequestException($"Phi4 endpoint returned {(int)response.StatusCode}: {responseContent}");
            }

            using var doc = JsonDocument.Parse(responseContent);
            var content = doc.RootElement
                .GetProperty("choices")[0]
                .GetProperty("message")
                .GetProperty("content")
                .GetString() ?? string.Empty;

            return content;
        }
    }
}
