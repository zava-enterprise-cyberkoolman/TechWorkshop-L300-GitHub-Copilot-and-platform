namespace ZavaStorefront.Models
{
    public class ChatMessage
    {
        public string Role { get; set; } = string.Empty;
        public string Content { get; set; } = string.Empty;
    }

    public class ChatViewModel
    {
        public List<ChatMessage> History { get; set; } = new();
        public string? UserInput { get; set; }
        public string? ErrorMessage { get; set; }
    }
}
