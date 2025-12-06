// Configuration
const MODEL_NAME = 'llama3.2:latest';

// Get HTML elements
const chatMessages = document.getElementById('messages');
const messageInput = document.getElementById('input');
const sendButton = document.getElementById('send');

// Store conversation history for context
let conversationHistory = [];

// Display a message in the chat
function addMessage(role, content) {
    // Create message element and add to chat
    const chatMessage = document.createElement('div');
    chatMessage.className = `message ${role}`;
    chatMessage.textContent = content;
    chatMessages.appendChild(chatMessage);
}

// Main function: send user message
async function sendMessage() {
    const userMessage = messageInput.value.trim();
    if (!userMessage) return;

    // Display user message
    addMessage('user', userMessage);
    messageInput.value = '';

    // Add to conversation history
    conversationHistory.push({ role: 'user', content: userMessage });

    // Send to Ollama API
    const response = await fetch('http://localhost:11434/api/chat', {
        method: 'POST',
        body: JSON.stringify({
            model: MODEL_NAME,
            messages: conversationHistory,
            stream: false
        })
    });

    // Parse response and display
    const data = await response.json();
    const assistantMessage = data.message.content;
    addMessage('assistant', assistantMessage);

    // Save to history
    conversationHistory.push({ role: 'assistant', content: assistantMessage });
}

// Event listeners
sendButton.addEventListener('click', sendMessage);
messageInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') sendMessage();
});

// Initialise
addMessage('assistant', `Ready... Model: ${MODEL_NAME}`);
