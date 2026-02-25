using Microsoft.AspNetCore.Mvc;
using ZavaStorefront.Models;
using ZavaStorefront.Services;

namespace ZavaStorefront.Controllers;

public class ChatController : Controller
{
    private readonly ChatService _chatService;
    private readonly ILogger<ChatController> _logger;
    private const string SessionKey = "ChatHistory";

    public ChatController(ChatService chatService, ILogger<ChatController> logger)
    {
        _chatService = chatService;
        _logger = logger;
    }

    public IActionResult Index()
    {
        var history = GetHistoryFromSession();
        return View(new ChatViewModel { History = history });
    }

    [HttpPost]
    public async Task<IActionResult> Send(string userInput)
    {
        var history = GetHistoryFromSession();
        var model = new ChatViewModel { History = history };

        if (string.IsNullOrWhiteSpace(userInput))
        {
            model.ErrorMessage = "Please enter a message.";
            return View("Index", model);
        }

        try
        {
            _logger.LogInformation("Sending user message to Phi4 endpoint");
            var reply = await _chatService.SendMessageAsync(history, userInput);

            history.Add(new ChatMessage { Role = "user", Content = userInput });
            history.Add(new ChatMessage { Role = "assistant", Content = reply });
            SaveHistoryToSession(history);

            model.History = history;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error communicating with Phi4 endpoint");
            model.ErrorMessage = $"Error: {ex.Message}";
        }

        return View("Index", model);
    }

    [HttpPost]
    public IActionResult Clear()
    {
        HttpContext.Session.Remove(SessionKey);
        return RedirectToAction("Index");
    }

    private List<ChatMessage> GetHistoryFromSession()
    {
        var json = HttpContext.Session.GetString(SessionKey);
        if (string.IsNullOrEmpty(json))
            return new List<ChatMessage>();

        return System.Text.Json.JsonSerializer.Deserialize<List<ChatMessage>>(json) ?? new List<ChatMessage>();
    }

    private void SaveHistoryToSession(List<ChatMessage> history)
    {
        var json = System.Text.Json.JsonSerializer.Serialize(history);
        HttpContext.Session.SetString(SessionKey, json);
    }
}
