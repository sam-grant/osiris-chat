// Default model for the UI
// Change to any model listed by 'ollama list'
const MODEL_NAME = 'llama3.1:latest'; 

// Get elements
const chatMessages = document.getElementById('messages');
const messageInput = document.getElementById('input');
const sendButton = document.getElementById('send');

// Conversation history (for context, really important!)
let conversationHistory = [];

// Add a message to the display
function addMessage(role, content) {
    const chatMessage = document.createElement('div');
    chatMessage.className = `message ${role}`;
    chatMessage.textContent = content;
    chatMessages.appendChild(chatMessage);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

// AI thinking indicator
function setThinking(isThinking) {
    let indicator = document.getElementById('thinking');
    if (!indicator) {
        indicator = document.createElement('div');
        indicator.id = 'thinking';
        indicator.className = 'message system';
        chatMessages.appendChild(indicator);
    }
    indicator.style.display = isThinking ? 'block' : 'none';
    indicator.textContent = 'AI is thinking...';
}

// Fetch search context from backend
async function fetchSearchContext(query) {
    try {
        // Set search proxy URL
        const SEARCH_PROXY_URL = `${window.location.protocol}//${window.location.hostname}:8001`;
        
        // Send POST request to /context endpoint
        const response = await fetch(`${SEARCH_PROXY_URL}/context`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ prompt: query })
        });

        // Check for HTTP errors
        if (!response.ok) {
            console.error('Search proxy error:', response.status);
            return null;
        }

        // Parse and return context
        const data = await response.json();
        return data.context;
    } catch (error) {
        // Log error and return null
        console.error('Failed to fetch search context:', error);
        return null;
    }
}

// Send message to Ollama
async function sendMessage() {
    const userMessage = messageInput.value.trim();
    if (!userMessage) return;

    // Display user message
    addMessage('user', userMessage);
    messageInput.value = '';

    // Start thinking indicator
    setThinking(true);

    // Check if search is needed based on keywords
    const searchKeywords = [
        // Explicit search requests
        'search', 'web', 'google', 'look up', 'find', 'search for',
        
        // Time-sensitive
        'weather', 'current', 'today', 'latest', 'news', 'now', 'recent',
        'yesterday', 'tomorrow', 'this week', 'currently',
        
        // Question words
        'who is', 'what is', 'when is', 'where is', 'how is',
        "who's", "what's", "where's", "how's",
        'who are', 'what are', 'where are',
        
        // Real-time data
        'price', 'stock', 'score', 'exchange rate', 'currency',
        
        // Events
        'when does', 'when did', 'won', 'winner', 'election', 'appointed'
    ];

    const needsSearch = searchKeywords.some(keyword => userMessage.toLowerCase().includes(keyword));
    console.log('User message:', userMessage);
    console.log('Needs search?', needsSearch);

    // Fetch search context if needed
    let enhancedMessage = userMessage;
    if (needsSearch) {
        const searchContext = await fetchSearchContext(userMessage);
        if (searchContext) {
            // Prepend search results to user question
            enhancedMessage = `${searchContext}\n\nUser question: ${userMessage}`;
            console.log('Replying with search context');
        } else {
            console.log('Search failed, replying with AI knowledge only');
        }
    } else {
        console.log('Replying with AI knowledge only');
    }

    // Add enhanced message to conversation history
    conversationHistory.push({ role: 'user', content: enhancedMessage });   

    try {
        // Set API URL
        let API_URL = `${window.location.protocol}//${window.location.hostname}:11434`;

        // Get the raw response from Ollama API
        const response = await fetch(`${API_URL}/api/chat`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({
                model: MODEL_NAME,
                messages: conversationHistory,
                stream: true
            })
        });

        // Stop the thinking indicator
        setThinking(false);

        // Check for HTTP errors
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        // Stream the response

        // Setup for streaming
        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        
        // Init assistant message
        let assistantMessage = '';

        // Init display for assistant message
        const chatMessage = document.createElement('div');
        chatMessage.className = 'message assistant';
        chatMessages.appendChild(chatMessage);

        // Read the stream
        while (true) {
            // Read a chunk from the stream
            const { done, value } = await reader.read();
            if (done) break; // Exit loop if stream is done

            // Decode and process the chunk
            
            // Split chunk into lines (in case multiple JSON objects are sent)
            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');
            
            // Process each line
            for (const line of lines) {
                // Ignore empty lines
                if (line.trim()) {
                    try { // Parse JSON line
                        const json = JSON.parse(line);
                        if (json.message && json.message.content) {
                            // Append content to assistant message
                            assistantMessage += json.message.content;
                            // Update the message display
                            chatMessage.textContent = assistantMessage;
                            // With markdown support
                            // chatMessage.innerHTML = marked.parse(assistantMessage);
                            // Scroll to bottom
                            chatMessages.scrollTop = chatMessages.scrollHeight;
                        }
                    } catch (e) {
                        console.error('Error parsing JSON:', e);
                    }
                }
            }
        }
        // Final rendering of assistant message
        conversationHistory.push({ role: 'assistant', content: assistantMessage });

    } catch (error) {
        // Stop the thinking indicator
        setThinking(false);
        // Log and display error
        console.error('Error:', error);
        // Display error message in chat
        const errorDiv = document.createElement('div');
        errorDiv.className = 'message error';
        errorDiv.textContent = `ERROR: ${error.message}. Check connection.`;
        chatMessages.appendChild(errorDiv);
    } finally {
        // Re-enable input
        messageInput.disabled = false;
        // Focus input
        messageInput.focus();
    }
}

// Initialise
addMessage('assistant', `Ready... Model: ${MODEL_NAME}`);

// Send on button click
sendButton.addEventListener('click', sendMessage);

// Send on Enter
messageInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        e.preventDefault();
        sendMessage();
    }
});